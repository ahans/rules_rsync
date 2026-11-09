#!/usr/bin/env bash
set -uo pipefail

failures=0

fail() {
    echo "FAIL: $*";
    failures=$((failures + 1));
}

test_deploy_aarch64_app() {
    local deploy_target="$1"

    RSYNC_DEPLOY_DEST="$TEST_TMPDIR" "$deploy_target"

    local python_binary=$(find "$TEST_TMPDIR" -name "python3" | head -n1)
    [ -f "$python_binary" ] || fail "python3 binary not found in deployment target ($TEST_TMPDIR)"
    (file -b "$python_binary" | grep "aarch64") || fail "deployed file is not an aarch64 binary"
}

deploy_target="$1"
test_deploy_aarch64_app "$deploy_target"

[ $failures == 0 ] || exit 1
