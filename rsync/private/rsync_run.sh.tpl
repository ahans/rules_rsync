#!/usr/bin/env bash
set -euo pipefail

deploy="@DEPLOY@"
bin_name="@BIN_NAME@"
host="${RSYNC_DEPLOY_HOST:-@HOST@}"
dest="${RSYNC_DEPLOY_DEST:-@DEST@}"

if [[ -d "$0.runfiles" ]]; then
    runfiles="$0.runfiles"
elif [[ -n "${RUNFILES_DIR:-}" ]]; then
    runfiles="$RUNFILES_DIR"
else
    echo "rules_rsync: cannot find runfiles of $0" >&2
    exit 2
fi

# Keep stdout clean for the deployed binary
RUNFILES_DIR="$runfiles" "$runfiles/$deploy" >&2

if [[ -z "$host" ]]; then
    exec "$dest/$bin_name" "$@"
fi

# Allocate a TTY when interactive so that Ctrl-C reaches the remote process
ssh_opts=""
[[ -t 0 ]] && ssh_opts="-t"
exec ssh $ssh_opts "$host" "$(printf '%q ' "$dest/$bin_name" "$@")"
