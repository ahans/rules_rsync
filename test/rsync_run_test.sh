#!/usr/bin/env bash
set -uo pipefail

failures=0

fail() {
    echo "FAIL: $*";
    failures=$((failures + 1));
}

test_run_app() {
    local run_target="$1"
    local app_target="$2"
    local expected_output_file="$3"

    output_file="$TEST_TMPDIR/$app_target.output"
    RSYNC_DEPLOY_DEST="$TEST_TMPDIR/deploy" "$run_target" > "$output_file" || fail "$run_target did not run successfully"

    [[ -x "$TEST_TMPDIR/deploy/$app_target" ]] || fail "${app_target} was not deployed"
    diff -u "$output_file" "$expected_output_file" || fail "${app_target} didn't produce the expected output"
}

test_run_with_dest_unset() {
    local run_target="$1"

    env -u RSYNC_DEPLOY_DEST -u RSYNC_DEPLOY_HOST "$run_target"
    [ $? != 0 ] || fail "$run_target did not return non-zero exit code"
}

run_target="$1"
app_target="$2"
expected_output_file="$3"

test_run_app "$run_target" "$app_target" "$expected_output_file"
test_run_with_dest_unset "$run_target"

[ $failures == 0 ] || exit 1
