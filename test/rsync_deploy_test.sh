#!/usr/bin/env bash
set -uo pipefail

failures=0

fail() {
    echo "FAIL: $*";
    failures=$((failures + 1));
}

test_deploy_app() {
    local deploy_target="$1"
    local app_target="$2"
    local expected_output_file="$3"

    # An empty host also overrides a host attribute, so this always deploys locally.
    RSYNC_DEPLOY_HOST= RSYNC_DEPLOY_DEST="$TEST_TMPDIR" "$deploy_target" || fail "$deploy_target failed"
    output_file="$TEST_TMPDIR/$app_target.output"
    # Without unsetting these, the app's runfiles library would use the test's runfiles tree
    # instead of the deployed one, and the test would pass even if files were missing.
    env -u RUNFILES_DIR -u RUNFILES_MANIFEST_FILE "$TEST_TMPDIR/${app_target}" > "$output_file" \
        || fail "${app_target} did not run successfully"

    diff -u "$output_file" "$expected_output_file" || fail "${app_target} didn't produce the expected output"

    # no manifset
    [[ ! -e "$TEST_TMPDIR/$app_target.runfiles/MANIFEST" ]] || fail "MANIFEST file was deployed"

    # the launcher's own rsync is not deployed
    # (repository directories such as rsync+ are always at the top of the tree)
    deployed_rsync=$(find "$TEST_TMPDIR/$app_target.runfiles" -mindepth 1 -maxdepth 1 -name 'rsync*')
    [[ -z "$deployed_rsync" ]] || fail "rsync was deployed: $deployed_rsync"

    # no absolute symlinks
    absolute_links=$(find $TEST_TMPDIR -type l -lname '/*')
    [[ -z "$absolute_links" ]] || fail "absolute symlinks deployed:"$'\n'"$absolute_links"
}

test_deploy_with_dest_unset() {
    local deploy_target="$1"

    output=$(env -u RSYNC_DEPLOY_DEST -u RSYNC_DEPLOY_HOST "$deploy_target")
    [ $? != 0 ] || fail "$deploy_target did not return non-zero exit code"
    [ "$output" == "error: either dest attribute or RSYNC_DEPLOY_DEST env variable need to be set" ] || fail "$deploy_target did not print expected error message: $output"
}

test_local_deploy_with_relative_dest() {
    local deploy_target="$1"

    output=$(RSYNC_DEPLOY_HOST= RSYNC_DEPLOY_DEST=relative/path "$deploy_target" 2>&1)
    [ $? != 0 ] || fail "$deploy_target accepted a relative dest for a local deployment"
    [ "$output" == "error: dest must be an absolute path for a local deployment, got 'relative/path'" ] \
        || fail "$deploy_target did not print expected error message: $output"
}

deploy_target="$1"
app_target="$2"
expected_output_file="$3"

test_deploy_app "$deploy_target" "$app_target" "$expected_output_file"
test_deploy_with_dest_unset "$deploy_target" "$app_target" "$expected_output_file"
test_local_deploy_with_relative_dest "$deploy_target"

[ $failures == 0 ] || exit 1
