#!/usr/bin/env bash
# Deploys to a local directory and runs the deployed binary.
set -euo pipefail

out="$("$RUNFILES_DIR/$RUN" --host= --dest="$TEST_TMPDIR/dest" -- world)"
[[ "$out" == "hello world" ]] || { echo "unexpected output: $out" >&2; exit 1; }
[[ -x "$TEST_TMPDIR/dest/hello" ]] || { echo "binary not deployed" >&2; exit 1; }
