#!/usr/bin/env bash
# Builds dist/all-perks-iw7.zip: the always-on files under iw7-mod/, laid out so
# that extracting the zip into the game folder puts every file where the
# client looks for it. Only the host needs it.
#
#   ./make-zip.sh

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$here/dist/all-perks-iw7.zip"

files=(
    "custom_scripts/cp/all_perks.gsc"
)

for file in "${files[@]}"; do
    if [[ ! -f "$here/$file" ]]; then
        echo "Missing $file" >&2
        exit 1
    fi
done

stage="$(mktemp -d)"
cleanup() {
    rm -rf -- "$stage"
    return 0
}
trap cleanup EXIT

for file in "${files[@]}"; do
    install -D -m 644 -- "$here/$file" "$stage/iw7-mod/$file"
done
install -m 644 -- "$here/zip-readme.txt" "$stage/iw7-mod/all-perks-readme.txt"

mkdir -p -- "$here/dist"
rm -f -- "$out"
(cd "$stage" && zip -q -r -X "$out" iw7-mod)

echo "Built $out"
unzip -l "$out" | tail -n +4 | awk '{print $1, $4}' | grep -v '/$'
