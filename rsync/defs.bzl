"""rules_rsync public API."""

load("//rsync/private:rsync_deploy.bzl", _rsync_deploy = "rsync_deploy")
load("//rsync/private:rsync_deploy_and_run.bzl", _rsync_deploy_and_run = "rsync_deploy_and_run")
load("//rsync/private:rsync_run.bzl", _rsync_run = "rsync_run")

visibility("public")

rsync_deploy = _rsync_deploy
rsync_deploy_and_run = _rsync_deploy_and_run
rsync_run = _rsync_run
