#!/usr/bin/env bash
# Integration tests for rsync_deploy and rsync_run against a fake ssh.
set -euo pipefail

rf() { echo "$RUNFILES_DIR/$1"; }
DEPLOY="$(rf "$DEPLOY")"
RUN="$(rf "$RUN")"
FAKE_SSH="$(rf "$FAKE_SSH")"
RSYNC="$(rf "$RSYNC")"

# The fake remote runs in $HOME and needs rsync on its PATH.
export HOME="$TEST_TMPDIR/home"
export PATH="$(dirname "$RSYNC"):$PATH"
export FAKE_SSH_LOG="$TEST_TMPDIR/ssh.log"
export RULES_RSYNC_SSH="$FAKE_SSH -o BatchMode=yes"
mkdir -p "$HOME"
unset RULES_RSYNC_HOST RULES_RSYNC_DEST

failures=0
fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}
expect_eq() {
  [[ "$1" == "$2" ]] || fail "$3: expected <$2>, got <$1>"
}
# Lines of rsync --itemize-changes output that transfer or delete a file.
transfers() {
  grep -E '^([<>]f|\*deleting)' || true
}
# Runs a deployed binary outside of Bazel.
run_deployed() {
  (cd "$1" && env -u RUNFILES_DIR -u RUNFILES_MANIFEST_FILE ./sh_app "${@:2}")
}

DEFAULT_DEST="$HOME/rules_rsync/tests/testdata/sh_app.deploy"

test_deploy_to_attr_host() {
  : >"$FAKE_SSH_LOG"
  "$DEPLOY"
  expect_eq "$(sort -u "$FAKE_SSH_LOG")" "attr-host" "host from attribute"
  expect_eq "$(run_deployed "$DEFAULT_DEST" | head -1)" "hello from sh_app" "deployed binary output"
  [[ -f "$DEFAULT_DEST/sh_app.runfiles/_repo_mapping" ]] || fail "_repo_mapping not deployed"
}

test_redeploy_without_changes_transfers_nothing() {
  "$DEPLOY"
  expect_eq "$("$DEPLOY" --verbose | transfers)" "" "transfers on unchanged redeploy"
}

test_host_precedence() {
  : >"$FAKE_SSH_LOG"
  RULES_RSYNC_HOST=env-host "$DEPLOY"
  expect_eq "$(sort -u "$FAKE_SSH_LOG")" "env-host" "env overrides attribute"
  : >"$FAKE_SSH_LOG"
  RULES_RSYNC_HOST=env-host "$DEPLOY" --host=cli-host
  expect_eq "$(sort -u "$FAKE_SSH_LOG")" "cli-host" "command line overrides env"
}

test_dest_with_spaces_and_tilde() {
  "$DEPLOY" --dest="~/with space/app"
  expect_eq "$(run_deployed "$HOME/with space/app" | head -1)" "hello from sh_app" "dest with spaces"
}

test_local_destination() {
  : >"$FAKE_SSH_LOG"
  local dest="$TEST_TMPDIR/local dest"
  "$DEPLOY" --host= --dest="$dest"
  expect_eq "$(run_deployed "$dest" | head -1)" "hello from sh_app" "local deploy"
  expect_eq "$(cat "$FAKE_SSH_LOG")" "" "ssh used for local deploy"
}

test_incremental_update_delete_and_dry_run() {
  # Work on a writable copy of the runfiles so the inputs can change.
  local copy="$TEST_TMPDIR/runfiles_copy" dest="$HOME/incremental"
  cp -RL "$RUNFILES_DIR" "$copy"
  local deploy=("$copy/${DEPLOY#"$RUNFILES_DIR/"}" --dest="$dest" --verbose)
  local greeting="$copy/_main/tests/testdata/greeting.txt"
  RUNFILES_DIR="$copy" "${deploy[@]}" >/dev/null

  mkdir -p "$dest/../sibling" "$dest/sh_app.runfiles/_main/stale_dir"
  touch "$dest/../sibling/keep" "$dest/sh_app.runfiles/_main/stale_dir/stale"
  echo "changed greeting" >"$greeting"

  local out
  out="$(RUNFILES_DIR="$copy" "${deploy[@]}" --dry-run | transfers)"
  expect_eq "$(run_deployed "$dest" | head -1)" "hello from sh_app" "dry run changed files"
  [[ -f "$dest/sh_app.runfiles/_main/stale_dir/stale" ]] || fail "dry run deleted a file"
  [[ "$out" == *greeting.txt* ]] || fail "dry run does not list greeting.txt: $out"

  out="$(RUNFILES_DIR="$copy" "${deploy[@]}" | transfers)"
  expect_eq "$(echo "$out" | grep -c '^[<>]f')" "1" "files transferred after one change ($out)"
  [[ "$out" == *"_main/tests/testdata/greeting.txt"* ]] || fail "greeting.txt not transferred: $out"
  expect_eq "$(run_deployed "$dest" | head -1)" "changed greeting" "updated output"
  [[ ! -e "$dest/sh_app.runfiles/_main/stale_dir" ]] || fail "stale files not deleted"
  [[ -f "$dest/../sibling/keep" ]] || fail "sibling of dest was touched"
}

test_run_passes_args_env_and_exit_code() {
  local out status=0
  out="$(APP_EXIT=3 "$RUN" "a b" "it's" '$HOME' "--host=not-for-launcher")" || status=$?
  expect_eq "$status" "3" "exit code"
  expect_eq "$out" "hello from sh_app
env: set by rsync_run
arg: <from attr>
arg: <a b>
arg: <it's>
arg: <\$HOME>
arg: <--host=not-for-launcher>" "run output"
}

test_run_launcher_options_before_separator() {
  local dest="$TEST_TMPDIR/run dest" out
  : >"$FAKE_SSH_LOG"
  out="$("$RUN" --host=run-host --dest="$dest" -- x 2>/dev/null)"
  expect_eq "$(sort -u "$FAKE_SSH_LOG")" "run-host" "run host option"
  [[ "$out" == *"arg: <x>" ]] || fail "args after -- not passed: $out"
  [[ -x "$dest/sh_app" ]] || fail "run did not deploy to --dest"

  rm -rf "$dest/sh_app.runfiles"
  out="$("$RUN" --dest="$dest" --no-deploy -- 2>&1)" || true
  [[ ! -e "$dest/sh_app.runfiles" ]] || fail "--no-deploy deployed"
}

for t in $(declare -F | awk '$3 ~ /^test_/ {print $3}'); do
  echo "=== $t"
  "$t" || fail "$t exited with $?"
done
((failures == 0)) || { echo "$failures failure(s)" >&2; exit 1; }
echo "PASSED"
