#!/usr/bin/env sh
set -euo pipefail

fail() {
    echo "error: $1"
    exit 1
}

which rsync > /dev/null 2>&1 || fail "rsync not found"

binary="@BIN@"
label="@LABEL@"
host="${HOST:-@HOST@}"
dest="${DEST:-@DEST@}"

[ "$dest" != "" ] || fail "either dest attribute or DEST env variable need to be set"

bin_name=$(basename "$binary")
dst_path="${host:+$host:}$dest"

if [ -d "$0.runfiles" ]; then
    runfiles="$0.runfiles"
elif [ -n "${RUNFILES_DIR:-}" ]; then
    runfiles="$RUNFILES_DIR"
else
    echo "rules_rsync: cannot find runfiles of $0" >&2
    exit 2
fi

[ -z "$host" ] && mkdir -p "$dest"

rsync --recursive --links --copy-unsafe-links --exclude=/MANIFEST --mkpath --delete "$@" "$runfiles/" "$dst_path/$bin_name.runfiles/"
rsync --copy-links "$@" "$runfiles/$binary" "$dst_path/$bin_name"

echo "Deployed $label to $dst_path."
