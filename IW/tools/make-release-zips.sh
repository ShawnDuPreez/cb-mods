#!/usr/bin/env bash
# Builds the zips that go on the GitHub release, one per mod, into IW/release/.
# Each is laid out from the game folder (the one that holds iw7-mod.exe):
#
#   mods/<mod>/...                    the mod, for every player
#   iw7-mod/ui_scripts/<Name>/...     menu and HUD scripts that must load from the
#                                     game's own folder (More Players: for every
#                                     player; Perk Limit: the host's menu row)
#
# so extracting a zip into the game folder installs the whole mod, and the CB
# launcher can install it the same way from one archive.
#
#   tools/make-release-zips.sh
#
# Also prints each zip's size, which the launcher entries in
# IW/launcher-entries/ have to match.

set -euo pipefail

tools="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
iw="$(dirname "$tools")"
out="$iw/release"

stage="$(mktemp -d)"
cleanup() {
    rm -rf -- "$stage"
    return 0
}
trap cleanup EXIT

# build <zip name> <project folder> <mod folder name> [host file]...
build() {
    local name="$1" zip="$out/$1" project="$iw/$2" mod="$3"
    shift 3
    local root="$stage/$mod" file
    mkdir -p "$root/mods/$mod"
    install -m 644 -- "$project/mod/mod.ff" "$project/mod/desc.txt" "$root/mods/$mod/"
    while IFS= read -r file; do
        install -D -m 644 -- "$project/$file" "$root/mods/$mod/$file"
    done < <(cd "$project" && find custom_scripts -type f -name '*.gsc' | sort)
    for file in "$@"; do
        install -D -m 644 -- "$project/$file" "$root/iw7-mod/$file"
    done
    mkdir -p "$out"
    rm -f -- "$zip"
    (cd "$root" && find . -type f | sed 's|^\./||' | sort | zip -q -X "$zip" -@)
    echo "$name  $(stat -c %s "$zip") bytes"
    unzip -Z1 "$zip" | sed 's/^/    /'
}

build iw-more-players.zip more-players more_players "ui_scripts/MorePlayers/__init__.lua" "ui_scripts/ZombiesPlayers/__init__.lua"
build iw-all-perks.zip all-perks all_perks
build iw-perk-limit.zip perk-limit perk_limit "ui_scripts/PerkLimit/__init__.lua"
