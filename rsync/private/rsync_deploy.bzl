"""Implementation of rsync_deploy rule."""

load("//rsync/private:transition.bzl", "platform_transition")

visibility(["//rsync/..."])

def _rlocation(f):
    if f.short_path.startswith("../"):  # external repo
        return f.short_path[3:]
    return "_main/" + f.short_path

def _rsync_deploy_impl(ctx):
    binary = ctx.attr.binary[0]
    exe = binary[DefaultInfo].files_to_run.executable
    for v in [ctx.attr.host, ctx.attr.dest]:
        for c in ["'", "\"", "$", "`", "\\"]:
            if c in v:
                fail("character {} is not supported in dest/host".format(c))

    launcher = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = launcher,
        is_executable = True,
        substitutions = {
            "@HOST@": ctx.attr.host,
            "@DEST@": ctx.attr.dest,
            "@BIN@": _rlocation(exe),
            "@LABEL@": str(binary.label).replace("@@//", "//"),
        },
    )
    return DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles().merge(binary[DefaultInfo].default_runfiles),
    )

rsync_deploy = rule(
    implementation = _rsync_deploy_impl,
    executable = True,
    attrs = {
        "binary": attr.label(
            mandatory = True,
            executable = True,
            cfg = platform_transition,
        ),
        "platform": attr.label(providers = [platform_common.PlatformInfo]),
        "host": attr.string(),
        "dest": attr.string(),
        "_template": attr.label(default = ":rsync_deploy.sh.tpl", allow_single_file = True),
    },
)
