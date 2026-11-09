#!/usr/bin/env bash
set -euo pipefail

fail() {
    echo "error: $1"
    exit 1
}

rsync_rlocation="@RSYNC@"
binary="@BIN@"
label="@LABEL@"
host="${RSYNC_DEPLOY_HOST:-@HOST@}"
dest="${RSYNC_DEPLOY_DEST:-@DEST@}"

[[ "$dest" != "" ]] || fail "either dest attribute or RSYNC_DEPLOY_DEST env variable need to be set"

[[ ! "$dest" =~ [[:space:]] ]] || fail "destination path must not contain whitespace"
[[ ! "$host" =~ [[:space:]] ]] || fail "host must not contain whitespace"

bin_name=$(basename "$binary")
dst_path="${host:+$host:}$dest"

if [[ -d "$0.runfiles" ]]; then
    runfiles="$0.runfiles"
elif [[ -n "${RUNFILES_DIR:-}" ]]; then
    runfiles="$RUNFILES_DIR"
else
    echo "rules_rsync: cannot find runfiles of $0" >&2
    exit 2
fi

[[ -z "$host" ]] && mkdir -p "$dest"

rsync="$runfiles/$rsync_rlocation"

# Deploy runfiles tree, excluding /MANIFEST (has absolute paths from build host) and the host-built rsync
"$rsync" --recursive --links --copy-unsafe-links \
    --exclude=/MANIFEST --exclude="/${rsync_rlocation%%/*}/" \
    --mkpath --delete "$@" \
    "$runfiles/" "$dst_path/$bin_name.runfiles/"

# Deploy the launcher living next to the `.runfiles`
"$rsync" --copy-links "$@" "$runfiles/$binary" "$dst_path/$bin_name"

echo "Deployed $label to $dst_path."
