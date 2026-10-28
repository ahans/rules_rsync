# Notes for agents working on rules_rsync

User-facing documentation is in README.md. This file covers what you need to
change the rules safely: design decisions and the reasons for them, pitfalls,
and the state of the work.

## Layout

- `rsync/defs.bzl`: public API (`rsync_deploy`, `rsync_run`, `RsyncDeployInfo`).
- `rsync/private/deploy.bzl`: both rules and the rsync filter generation.
- `rsync/private/launcher.sh.tpl`: one bash launcher for both rules. `%RUN%`
  switches between deploy and deploy+run.
- `rsync/private/transition.bzl`: the `platform` transition, applied to `target` only.
- `tests/analysis/`: rules_testing analysis tests. `fake_binary.bzl` is an
  executable rule without toolchains that controls its runfiles exactly.
- `tests/integration/`: sh_tests. `fake_ssh.sh` drops ssh options, logs the
  host to `$FAKE_SSH_LOG`, and runs the remote command locally in `$HOME`.
- `tests/testdata/`: sh/py/cc binaries and their deploy targets.
- `e2e/smoke/`: a separate module that uses the rules through
  `local_path_override`. It is excluded from the root via `.bazelignore`.

## Commands

```sh
bazel test //...                     # all tests, no network needed
(cd e2e/smoke && bazel test //...)   # consumer check; run after API changes
bazel run //tests/testdata:sh_app.remote -- --host= --dest=/tmp/x -- arg
```

The devcontainer has no `ssh`, no `docker` and no system `rsync`. Tests use the
hermetic `@rsync` binary on both sides and `fake_ssh.sh`. Nothing has been run
against a real ssh server yet.

## Design decisions (don't undo these without a reason)

- **`--copy-unsafe-links` instead of `-L`** for the runfiles tree. Bazel's
  runfiles entries are absolute symlinks into the output base and have to be
  copied as files. rules_python's venv has a *relative* symlink
  `bin/python3 -> ../../../../../<interpreter>` inside the tree. Dereferencing
  it breaks Python's stdlib lookup ("No module named 'encodings'"). The
  top-level executable is copied separately with `-L`.
- **The filter file selects exactly the target's runfiles**, combined with
  `--delete --delete-excluded`. The deploy's runfiles tree also contains rsync
  and the filter, and a test's tree contains more still. The filter keeps
  those out and deletes stale remote files, but only inside
  `<dest>/<bin>.runfiles`. `[`, `*`, `?` and `\` in paths are escaped, because
  rsync honors escapes only in patterns that contain wildcards.
- **`remote_args` / `remote_env`, not `args` / `env`**: those two are built-in
  attributes of every executable rule, and Bazel would apply them to the local
  launcher.
- **In `rsync_run`, launcher options only count before an explicit `--`.**
  Without `--`, every argument goes to the binary, so the binary's own
  `--host` or `--help` keeps working. In `rsync_deploy`, all arguments are
  launcher options.
- **Host/dest precedence**: CLI, then env, then build flag (`//:host`,
  `//:dest`), then attribute. The flag-over-attribute step is resolved at
  analysis time. The rest is resolved in the launcher.
- **Relative `dest` is relative to the home directory**, including for local
  deploys (empty host). A leading `~/` is stripped, because the destination is
  quoted for the remote shell and the quoting would stop `~` from expanding.
- **The remote dest is created through `--rsync-path="mkdir -p <dest> && rsync"`**
  instead of `--mkpath`, which older remote rsyncs lack.
- **The runfiles directory is found** at `$0.runfiles` (for `bazel run`), then
  `$RUNFILES_DIR` (in tests, or when one launcher calls another). The
  integration test's incremental case relies on the second: it runs a launcher
  from a writable `cp -RL` copy of the runfiles with `RUNFILES_DIR` pointing to
  the copy.
- **`_main` is hardcoded** as the main repo's runfiles directory. That is fixed
  under Bzlmod, which Bazel 8+ requires.

## Pitfalls

- An attribute with an outgoing transition is always a list: `ctx.attr.target[0]`.
- A `filegroup` with a single file counts as executable, so tests for
  non-executable targets need at least two files. Bazel reports the attribute
  error but still runs the implementation, so the rule `fail()`s on its own
  when `files_to_run.executable` is `None`.
- The launcher has to work with bash 3.2 (macOS):
  - Expand arrays that may be empty with `${a[@]+"${a[@]}"}`.
  - No `${x@Q}`, no `declare -n`.
- Quoting: `sh_quote` produces POSIX single quotes for remote commands.
  `printf %q` doesn't work there, because its output may be bash-only. rsync's
  `-e` option has its own rules (inside single quotes, a quote is doubled), so
  use `rsync_quote`.
- The rules_testing `DictSubject.get` needs `factory = subjects.str`. For
  `FileWrite` content written from `Args`, the tests read `action.content`
  directly.
- `fake_ssh.sh` inherits the test's environment. A real ssh doesn't, so check
  env-related behavior against a real host.

## Conventions

- Integration tests are `test_*` functions in a single script. They are
  discovered with `declare -F`, and failures are counted, not fatal.
- New analysis tests have to be added to the list in `deploy_test_suite`.
- When you add a dependency that only tests use, mark it `dev_dependency = True`.
- Work on a feature branch and commit each working intermediate state.

## Status and next steps

v1 is done: deploy and run, layered host/dest, platform transition, tests and
smoke module. Next, roughly in order of value:

1. A real-ssh test: an sshd container, `tags = ["manual", "requires-docker"]`.
   Alternatively, deploy and run once against a real host.
2. Bootstrapping rsync on the remote if it is missing: copy `@rsync//:rsync`,
   built for `platform`, to `~/.cache/rules_rsync/bin/rsync` and use
   `--rsync-path`.
3. `rsync_deploy_group`: several targets in one rsync/ssh session.
4. Detached runs (`systemd-run --user` / `nohup`) with `stop` and `logs` subcommands.
5. Port forwarding (`forward_ports` → `ssh -L`) and remote debugging
   (`gdbserver`, `debugpy`).
6. `rsync_test` (running tests remotely), deploying to several hosts at once,
   and pulling results back after a run.
