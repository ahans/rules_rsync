"""rules_rsync public API."""

load("//rsync/private:rsync_deploy.bzl", _rsync_deploy = "rsync_deploy")

visibility("public")

rsync_deploy = _rsync_deploy
