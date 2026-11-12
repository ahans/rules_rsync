"""Implementation of rsync_deploy_and_run macro."""

load("//rsync/private:rsync_deploy.bzl", "rsync_deploy")
load("//rsync/private:rsync_run.bzl", "rsync_run")

visibility(["//rsync/..."])

def _rsync_deploy_and_run_impl(name, visibility, **kwargs):
    rsync_deploy(
        name = name + "_deploy",
        visibility = visibility,
        **kwargs
    )
    rsync_run(
        name = name + "_run",
        deploy = ":" + name + "_deploy",
        visibility = visibility,
    )

rsync_deploy_and_run = macro(
    implementation = _rsync_deploy_and_run_impl,
    inherit_attrs = rsync_deploy,
)
