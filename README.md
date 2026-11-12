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
If `RSYNC_DEPLOY_HOST`/`host` is empty, deployment happens on the local machine.

### Deploy and run

`rsync_run` wraps an `rsync_deploy` target. It deploys first and then runs the binary on the target (via `ssh` if a host is set):

```starlark
load("@rules_rsync//rsync:defs.bzl", "rsync_run")

rsync_run(
    name = "app_run",
    deploy = ":app_deploy",
)
```

Arguments are passed on to the binary: `bazel run //foo/bar:app_run -- --some-flag`.
`RSYNC_DEPLOY_HOST` and `RSYNC_DEPLOY_DEST` work the same as for `rsync_deploy`.

`rsync_deploy_and_run` creates both targets at once, `<name>_deploy` and `<name>_run`. It takes the same attributes as `rsync_deploy`:

```starlark
load("@rules_rsync//rsync:defs.bzl", "rsync_deploy_and_run")

rsync_deploy_and_run(
    name = "app",
    binary = ":app",
    host = "robot.domain.tld",
    dest = "/home/user/deployments",
)
```

See [test/BUILD.bazel](test/BUILD.bazel) for more examples.

## Current limitations

* `rsync` 3.2.3 or newer needs to be installed on the deployment target (locally, a hermetic `rsync` built by Bazel is used)
* only Linux and macOS are tested; Windows won't work
