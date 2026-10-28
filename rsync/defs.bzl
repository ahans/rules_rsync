"""Public API of rules_rsync."""

load("//rsync/private:deploy.bzl", _RsyncDeployInfo = "RsyncDeployInfo", _rsync_deploy = "rsync_deploy", _rsync_run = "rsync_run")

RsyncDeployInfo = _RsyncDeployInfo
rsync_deploy = _rsync_deploy
rsync_run = _rsync_run
