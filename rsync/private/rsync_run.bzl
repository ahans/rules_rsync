"""Implementation of rsync_run rule."""

load("//rsync/private:rsync_deploy.bzl", "RsyncDeployInfo", "rlocation")

visibility(["//rsync/..."])

def _rsync_run_impl(ctx):
    info = ctx.attr.deploy[RsyncDeployInfo]

    launcher = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = launcher,
        is_executable = True,
        substitutions = {
            "@HOST@": info.host,
            "@DEST@": info.dest,
            "@BIN_NAME@": info.bin_name,
            "@DEPLOY@": rlocation(ctx.executable.deploy),
        },
    )
    return DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = [ctx.executable.deploy]).merge(
            ctx.attr.deploy[DefaultInfo].default_runfiles,
        ),
    )

rsync_run = rule(
    implementation = _rsync_run_impl,
    executable = True,
    attrs = {
        "deploy": attr.label(
            mandatory = True,
            executable = True,
            cfg = "target",
            providers = [RsyncDeployInfo],
        ),
        "_template": attr.label(default = ":rsync_run.sh.tpl", allow_single_file = True),
    },
)
