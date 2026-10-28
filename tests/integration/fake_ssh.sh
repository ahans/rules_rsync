#!/usr/bin/env bash
# Stands in for ssh: drops options, logs the host to $FAKE_SSH_LOG, and runs
# the remote command locally in $HOME, like sshd would.
set -euo pipefail

while (($#)); do
  case "$1" in
    -[bcDEeFIiJLlmOoPpQRSWw]) shift 2 ;;
    -*) shift ;;
    *) break ;;
  esac
done
host="$1"
shift
if [[ -n "${FAKE_SSH_LOG:-}" ]]; then
  echo "$host" >>"$FAKE_SSH_LOG"
fi
cd "$HOME"
exec sh -c "$*"
