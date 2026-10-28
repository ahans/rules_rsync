#!/usr/bin/env bash
# Deploys real py_binary and cc_binary targets and runs them outside of Bazel.
set -euo pipefail

failures=0
check() {
  local launcher="$RUNFILES_DIR/$1" bin="$2" expected="$3"
  local dest="$TEST_TMPDIR/$bin" out
  "$launcher" --host= --dest="$dest"
  # Run from another directory, without any of the test's runfiles variables.
  out="$(cd / && env -u RUNFILES_DIR -u RUNFILES_MANIFEST_FILE -u PYTHON_RUNFILES \
    "$dest/$bin" extra)" || true
  if [[ "$out" != "$expected" ]]; then
    echo "FAIL: $bin: expected <$expected>, got <$out>" >&2
    failures=$((failures + 1))
  fi
}

check "$PY_DEPLOY" py_app "py: hello from sh_app extra"
check "$CC_DEPLOY" cc_app "cc: hello from sh_app"
((failures == 0)) || exit 1
echo "PASSED"
