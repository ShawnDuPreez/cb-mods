#!/usr/bin/env bash
# Builds dist/perk_limit.zip: the mod as a folder with mod.ff, for the CB
# launcher's Mods > Import > Install from .zip, or to extract into <game>/mods/.
#
#   ./make-mod-zip.sh
#
# mod/mod.ff is kept in this project and reused. Every player must have the
# same mod.ff as the host, so do not rebuild it unless you have to: a rebuilt
# file means everyone imports the mod again. ../tools/build-mod-ff.sh builds it.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
name="perk_limit"
out="$here/dist/$name.zip"

files=(
    "custom_scripts/cp/perk_limit.gsc"
)

for file in "${files[@]}" "mod/mod.ff" "mod/desc.txt"; do
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
    install -D -m 644 -- "$here/$file" "$stage/$name/$file"
done
install -m 644 -- "$here/mod/mod.ff" "$here/mod/desc.txt" "$stage/$name/"

mkdir -p -- "$here/dist"
rm -f -- "$out"
(cd "$stage" && zip -q -r -X "$out" "$name")

echo "Built $out"
unzip -l "$out" | tail -n +4 | awk '{print $1, $4}' | grep -v '/$'
