"""Implementation of rsync_deploy and rsync_run."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load(":transition.bzl", "platform_transition")

RsyncDeployInfo = provider(
    doc = "Everything an rsync_run needs to deploy and start the binary of an rsync_deploy.",
    fields = {
        "bin_name": "Base name of the executable on the remote host.",
        "bin_rlocation": "Runfiles path of the executable.",
        "dest": "Default destination directory, possibly relative to the remote $HOME.",
        "filter": "File with rsync filter rules selecting the target's runfiles.",
        "host": "Default host ([user@]host), empty for a local destination.",
        "label": "Label of the deployed target, for messages.",
        "rsync": "The rsync executable run on the local machine.",
        "rsync_opts": "Extra rsync options.",
        "runfiles": "Runfiles the launcher needs: the target's plus rsync and the filter.",
        "ssh_opts": "Extra ssh options.",
    },
)

# With Bzlmod, the main repository's runfiles directory is always named _main.
_MAIN_REPO = "_main"

def _rlocation(short_path):
    if short_path.startswith("../"):
        return short_path[len("../"):]
    return _MAIN_REPO + "/" + short_path

def _escape(path):
    # rsync only honors backslash escapes in patterns that contain a wildcard,
    # which is exactly when escaping is needed.
    for c in ["\\", "*", "?", "["]:
        path = path.replace(c, "\\" + c)
    return path

def _include_rules(rlocation, is_directory = False):
    parts = rlocation.split("/")
    rules = ["+ /" + _escape("/".join(parts[:i])) + "/" for i in range(1, len(parts))]
    rules.append("+ /" + _escape(rlocation) + ("/***" if is_directory else ""))
    return rules

def _file_rules(f):
    return _include_rules(_rlocation(f.short_path))

def _empty_file_rules(short_path):
    return _include_rules(_rlocation(short_path))

def _write_filter(ctx, runfiles):
    args = ctx.actions.args()
    args.set_param_file_format("multiline")
    args.add("+ /_repo_mapping")
    args.add_all(runfiles.files, map_each = _file_rules, uniquify = True)
    args.add_all(runfiles.empty_filenames, map_each = _empty_file_rules, uniquify = True)
    for entry in runfiles.symlinks.to_list():
        args.add_all(_include_rules(_MAIN_REPO + "/" + entry.path, entry.target_file.is_directory))
    for entry in runfiles.root_symlinks.to_list():
        args.add_all(_include_rules(entry.path, entry.target_file.is_directory))
    args.add("- *")

    out = ctx.actions.declare_file(ctx.label.name + ".rsync_filter")
    ctx.actions.write(out, args)
    return out

def _display_label(label):
    if label.repo_name:
        return str(label)
    return "//%s:%s" % (label.package, label.name)

def _sh_quote(s):
    return "'" + s.replace("'", "'\\''") + "'"

def _sh_words(values):
    return " ".join([_sh_quote(v) for v in values])

def _write_launcher(ctx, info, run = False, run_args = [], run_env = {}):
    launcher = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.expand_template(
        template = ctx.file._launcher_template,
        output = launcher,
        is_executable = True,
        substitutions = {
            "%BIN_NAME%": _sh_quote(info.bin_name),
            "%BIN_RLOCATION%": _sh_quote(info.bin_rlocation),
            "%DEST%": _sh_quote(info.dest),
            "%FILTER_RLOCATION%": _sh_quote(_rlocation(info.filter.short_path)),
            "%HOST%": _sh_quote(info.host),
            "%LABEL%": _sh_quote(info.label),
            "%RSYNC_OPTS%": _sh_words(info.rsync_opts),
            "%RSYNC_RLOCATION%": _sh_quote(_rlocation(info.rsync.short_path)),
            "%RUN%": "1" if run else "0",
            "%RUN_ARGS%": _sh_words(run_args),
            "%RUN_ENV%": _sh_words(["%s=%s" % (k, v) for k, v in run_env.items()]),
            "%SSH_OPTS%": _sh_words(info.ssh_opts),
        },
    )
    return launcher

def _rsync_deploy_impl(ctx):
    # Attributes with an outgoing transition are always lists.
    target = ctx.attr.target[0]
    target_info = target[DefaultInfo]
    executable = target_info.files_to_run.executable
    if not executable:
        fail("%s must be an executable target" % target.label)
    target_runfiles = target_info.default_runfiles

    filter = _write_filter(ctx, target_runfiles)
    rsync = ctx.executable.rsync

    host = ctx.attr._host_flag[BuildSettingInfo].value or ctx.attr.host
    dest = (ctx.attr._dest_flag[BuildSettingInfo].value or ctx.attr.dest or
            "/".join([p for p in ["rules_rsync", ctx.label.package, ctx.label.name] if p]))

    runfiles = ctx.runfiles(files = [filter, rsync, executable]).merge_all([
        target_runfiles,
        ctx.attr.rsync[DefaultInfo].default_runfiles,
    ])
    info = RsyncDeployInfo(
        bin_name = executable.basename,
        bin_rlocation = _rlocation(executable.short_path),
        dest = dest,
        filter = filter,
        host = host,
        label = _display_label(target.label),
        rsync = rsync,
        rsync_opts = ctx.attr.rsync_opts,
        runfiles = runfiles,
        ssh_opts = ctx.attr.ssh_opts,
    )
    launcher = _write_launcher(ctx, info)
    return [
        DefaultInfo(executable = launcher, runfiles = runfiles),
        info,
    ]

rsync_deploy = rule(
    implementation = _rsync_deploy_impl,
    executable = True,
    doc = """Deploys an executable target and its runfiles with rsync.

`bazel run` on this target syncs the executable to `<dest>/<name>` and its
runfiles to `<dest>/<name>.runfiles` on `host`, mirroring the layout `bazel
run` uses locally. Only changed files are transferred, and files that are no
longer part of the runfiles are deleted.

The launcher accepts `--host=`, `--dest=`, `--ssh=`, `--dry-run` and
`--verbose`. Host and destination are taken, from highest to lowest priority,
from the command line, `RULES_RSYNC_HOST`/`RULES_RSYNC_DEST`, the
`@rules_rsync//:host`/`@rules_rsync//:dest` flags, and the attributes.
""",
    attrs = {
        "dest": attr.string(
            doc = "Destination directory. Relative paths are relative to the remote user's home " +
                  "directory. Defaults to `rules_rsync/<package>/<name>`.",
        ),
        "host": attr.string(
            doc = "Host to deploy to, as `[user@]host` or an ssh config alias. If empty, `dest` " +
                  "is a directory on the local machine.",
        ),
        "platform": attr.label(
            doc = "Platform to build `target` for, e.g. the remote host's architecture.",
            providers = [platform_common.PlatformInfo],
        ),
        "rsync_opts": attr.string_list(doc = "Extra options for rsync."),
        "ssh_opts": attr.string_list(doc = "Extra options for ssh, e.g. `[\"-p\", \"2222\"]`."),
        "target": attr.label(
            doc = "Executable target to deploy.",
            mandatory = True,
            executable = True,
            cfg = platform_transition,
        ),
        "_dest_flag": attr.label(default = "//:dest"),
        "_host_flag": attr.label(default = "//:host"),
        "_launcher_template": attr.label(
            default = ":launcher.sh.tpl",
            allow_single_file = True,
        ),
        "rsync": attr.label(
            default = "@rsync//:rsync",
            executable = True,
            cfg = "target",
        ),
    },
)

def _rsync_run_impl(ctx):
    info = ctx.attr.deploy[RsyncDeployInfo]
    launcher = _write_launcher(
        ctx,
        info,
        run = True,
        run_args = ctx.attr.remote_args,
        run_env = ctx.attr.remote_env,
    )
    return [DefaultInfo(executable = launcher, runfiles = info.runfiles)]

rsync_run = rule(
    implementation = _rsync_run_impl,
    executable = True,
    doc = """Deploys the target of an rsync_deploy and runs it on the remote host.

Without `--`, all command line arguments are passed to the remote binary. To
pass launcher options (see rsync_deploy, plus `--no-deploy`), put them before
a `--`: `bazel run //app:server.remote -- --host=robot -- --port=8080`.
""",
    attrs = {
        "deploy": attr.label(
            doc = "The rsync_deploy target describing what to deploy where.",
            mandatory = True,
            providers = [RsyncDeployInfo],
        ),
        "remote_args": attr.string_list(
            doc = "Arguments passed to the binary, before those from the command line.",
        ),
        "remote_env": attr.string_dict(doc = "Environment variables set for the binary."),
        "_launcher_template": attr.label(
            default = ":launcher.sh.tpl",
            allow_single_file = True,
        ),
    },
)
