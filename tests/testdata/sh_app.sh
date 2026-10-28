#!/usr/bin/env bash
# Prints a data file, its environment and arguments, then exits with $APP_EXIT.
cat "$0.runfiles/_main/tests/testdata/greeting.txt"
echo "env: ${APP_ENV:-}"
for arg in "$@"; do
  echo "arg: <$arg>"
done
exit "${APP_EXIT:-0}"
