# rules_rsync

Bazel rules that deploy any runnable target (`py_binary`, `cc_binary`,
`sh_binary`, …) to a remote host with rsync and run it there over ssh. After
the first deploy, only changed files are transferred, so the edit, deploy and
run loop stays fast.

## Setup

```starlark
# MODULE.bazel
bazel_dep(name = "rules_rsync", version = "...")
```

rsync is built hermetically from source for the local machine. The remote host
needs `rsync` on its `PATH` and an ssh server.

## Usage

```starlark
load("@rules_rsync//rsync:defs.bzl", "rsync_deploy", "rsync_run")

py_binary(
    name = "server",
    srcs = ["server.py"],
    data = ["config.yaml"],
)

rsync_deploy(
    name = "server.deploy",
    target = ":server",
    host = "robot@jetson-01",  # optional, see "Choosing the host"
)

rsync_run(
    name = "server.remote",
    deploy = ":server.deploy",
    remote_args = ["--config=config.yaml"],
    remote_env = {"LOG_LEVEL": "debug"},
)
```

```sh
bazel run //app:server.deploy                    # sync to the host
bazel run //app:server.deploy -- --dry-run       # show what would change
bazel run //app:server.remote                    # sync, then run remotely
bazel run //app:server.remote -- --port=8080     # arguments for the binary
bazel run //app:server.remote -- --host=robot2 -- --port=8080
```

For `rsync_run`, all arguments go to the remote binary unless there is a `--`.
In that case the arguments before the `--` are launcher options. The binary's
stdin, stdout, stderr and exit code are connected to your terminal. A tty is
allocated when you run interactively, so Ctrl-C stops the remote process.

### Launcher options

| Option | Meaning |
| --- | --- |
| `--host=[USER@]HOST` | Host to deploy to. Empty means a directory on the local machine. |
| `--dest=DIR` | Destination directory. Relative paths and `~/…` are relative to the remote home. |
| `--ssh=COMMAND` | ssh command, e.g. `--ssh="ssh -J bastion"`. Also `RULES_RSYNC_SSH`. |
| `--dry-run` | List what would be transferred without changing anything. |
| `--verbose` | List transferred and deleted files. |
| `--no-deploy` | (`rsync_run` only) Run the already deployed binary. |

### Choosing the host

The host and destination come from the first of these sources that sets them:

1. The command line: `--host=…` / `--dest=…`
2. The environment: `RULES_RSYNC_HOST` / `RULES_RSYNC_DEST`
3. Build flags: `--@rules_rsync//:host=…` / `--@rules_rsync//:dest=…`, e.g. in your `.bazelrc` or `user.bazelrc`.
4. The `host` / `dest` attributes

`dest` defaults to `rules_rsync/<package>/<rsync_deploy name>`, under the
remote home directory.

### Remote layout

The remote layout mirrors what `bazel run` uses locally, so runfiles libraries
and Python's bootstrap find their files without any setup:

```
<dest>/server                     # the executable
<dest>/server.runfiles/_repo_mapping
<dest>/server.runfiles/_main/...  # data, sources, external repositories
```

You can run `<dest>/server` on the remote by hand from any directory.

### A different CPU architecture on the remote

Set `platform` to build the target for the remote, e.g. an aarch64 board
deployed from an x86_64 laptop:

```starlark
rsync_deploy(
    name = "server.deploy",
    target = ":server",
    platform = "//platforms:linux_aarch64",
)
```

Only `target` is built for that platform. rsync itself is still built for your
machine. You have to register toolchains that can build for the platform, such
as a C++ cross toolchain (e.g. `toolchains_llvm`) or a `rules_python`
interpreter for the remote architecture.

## How it works

- At analysis time, `rsync_deploy` writes an rsync filter file that includes
  exactly the target's runfiles: files, symlinks, root symlinks and the repo
  mapping.
- The launcher then syncs the local runfiles tree with
  `rsync --copy-unsafe-links --delete --delete-excluded`:
  - Bazel's runfiles symlinks point outside the tree, so they are copied as
    real files.
  - Relative symlinks inside the tree, such as a Python venv's interpreter,
    stay symlinks.
  - Remote files that are no longer part of the runfiles are deleted, but only
    inside `<dest>/<name>.runfiles`.
- ssh connections are shared (`ControlMaster`), so a deploy and a run open only
  one connection.

## Development

```sh
bazel test //...                     # analysis and integration tests
(cd e2e/smoke && bazel test //...)   # uses the rules as an external module
```

The integration tests replace ssh with `tests/integration/fake_ssh.sh`. It
runs the "remote" side locally, so the `host:path` code path of rsync gets
tested without a network.
