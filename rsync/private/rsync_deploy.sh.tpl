#!/usr/bin/env bash
set -euo pipefail

fail() {
    echo "error: $1"
    exit 1
}

binary="@BIN@"
rsync_rlocation="@RSYNC@"
label="@LABEL@"
# No colon: a set but empty RSYNC_DEPLOY_HOST overrides the attribute (local deployment).
host="${RSYNC_DEPLOY_HOST-@HOST@}"
dest="${RSYNC_DEPLOY_DEST:-@DEST@}"

[[ "$dest" != "" ]] || fail "either dest attribute or RSYNC_DEPLOY_DEST env variable need to be set"

[[ ! "$dest" =~ [[:space:]] ]] || fail "destination path must not contain whitespace"
[[ ! "$host" =~ [[:space:]] ]] || fail "host must not contain whitespace"

# `bazel run` starts in the runfiles tree, so a relative local path would end up there.
[[ -n "$host" || "$dest" == /* ]] || fail "dest must be an absolute path for a local deployment, got '$dest'"

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

# The runfiles tree also contains our own rsync, which must not be deployed. Excluding
# its whole repo directory avoids leaving an empty directory behind.
"$rsync" --recursive --links --copy-unsafe-links --exclude=/MANIFEST --exclude="/${rsync_rlocation%%/*}/" \
    --mkpath --delete "$@" "$runfiles/" "$dst_path/$bin_name.runfiles/"
"$rsync" --copy-links "$@" "$runfiles/$binary" "$dst_path/$bin_name"

echo "Deployed $label to $dst_path."
