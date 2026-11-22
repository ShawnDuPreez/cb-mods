#!/usr/bin/env bash
# Builds the two zips that are extracted into the game folder (everything
# sits under iw7-mod/, where the client looks for it). Only the host needs
# either of them.
#
#   dist/perk-limit-menu-iw7.zip   the menu script alone: the host's side of
#                                  the mod picked in the Mods menu
#   dist/perk-limit-iw7.zip        the always-on form: menu script and game
#                                  script, no mod to pick
#
#   ./make-zip.sh

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

stage="$(mktemp -d)"
cleanup() {
    rm -rf -- "$stage"
    return 0
}
trap cleanup EXIT

# build <zip name> <readme source> <readme name in zip> <file>...
build() {
    local out="$here/dist/$1" readme="$2" readme_name="$3"
    shift 3
    local root="$stage/$(basename "$out" .zip)" file
    for file in "$@"; do
        if [[ ! -f "$here/$file" ]]; then
            echo "Missing $file" >&2
            exit 1
        fi
        install -D -m 644 -- "$here/$file" "$root/iw7-mod/$file"
    done
    install -m 644 -- "$here/$readme" "$root/iw7-mod/$readme_name"
    mkdir -p -- "$here/dist"
    rm -f -- "$out"
    (cd "$root" && zip -q -r -X "$out" iw7-mod)
    echo "Built $out"
    unzip -l "$out" | tail -n +4 | awk '{print $1, $4}' | grep -v '/$'
}

build perk-limit-menu-iw7.zip zip-readme-menu.txt perk-limit-menu-readme.txt \
    "ui_scripts/PerkLimit/__init__.lua"

build perk-limit-iw7.zip zip-readme.txt perk-limit-readme.txt \
    "custom_scripts/cp/perk_limit.gsc" \
    "ui_scripts/PerkLimit/__init__.lua"
