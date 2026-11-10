# rules_rsync

Simple ruleset to enable deployment via `rsync`.
Also supports cross-platform deployment (if the repo's toolchains support it).

## Usage

Add the following to `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_rsync", dev_dependency = True)

git_override(
    module_name = "rules_rsync",
    commit = "<COMMIT-ID>", # put the commit ID you want (mostly latest)
    remote = "https://github.com/ahans/rules_rsync.git",
)
```

Then you can use `rsync_deploy` to create a deployment target for an existing binary:

```starlark
load("@rules_rsync//rsync:defs.bzl", "rsync_deploy")

# Definition of some executable target `app`
# ...

# Regular deployment target, same architecture as build host
rsync_deploy(
    name = "app_deploy",
    binary = ":app",
    host = "robot.domain.tld",
    dest = "/home/user/deployments",
)
```

You can then `bazel run //foo/bar:app_deploy` to have Bazel build and sync the target using `rsync`.

`host` and `dest` are optional. They can be provided via `RSYNC_DEPLOY_HOST` and `RSYNC_DEPLOY_DEST` environment variables as well.
The following would be equivalent to the `bazel run` above:

```sh
RSYNC_DEPLOY_HOST=robot.domain.tld RSYNC_DEPLOY_DEST=/home/user/deployments bazel run //foo/bar:app_deploy
```

If both, attributes (`host`, `dest`) and environment variables (`RSYNC_DEPLOY_HOST`, `RSYNC_DEPLOY_DEST`), are given, the environment variables are used.
If the resulting host is empty, deployment happens on the local machine.
Setting `RSYNC_DEPLOY_HOST` to an empty string deploys locally even if the `host` attribute is set.
For a local deployment, `dest` must be an absolute path.

See [test/BUILD.bazel](test/BUILD.bazel) for more examples.

## Current limitations

* `rsync` needs to be available on the deployment target (locally, a hermetic `rsync` built by Bazel is used)
* only Linux is tested; macOS may work, Windows most probably won't
* we can only deploy; running the target needs to happen manually
