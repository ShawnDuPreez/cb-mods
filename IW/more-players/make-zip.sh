#!/usr/bin/env bash
# Builds dist/more-players-iw7.zip: the four mod files under iw7-mod/, laid out
# so that extracting the zip into the game folder puts every file where the
# client looks for it.
#
#   ./make-zip.sh
#
# The CB launcher's Mods > Import can not take this zip. See README.md,
# "Why not the launcher's Import".

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$here/dist/more-players-iw7.zip"

files=(
    "custom_scripts/cp/more_players.gsc"
    "custom_scripts/cp/scoreboard.gsc"
    "custom_scripts/frontend/more_players_lobby.gsc"
    "ui_scripts/MorePlayers/__init__.lua"
    "ui_scripts/ZombiesPlayers/__init__.lua"
)

for file in "${files[@]}"; do
    if [[ ! -f "$here/$file" ]]; then
        echo "Missing $file. Run ./fetch-hud-fix.sh first." >&2
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
install -m 644 -- "$here/zip-readme.txt" "$stage/iw7-mod/more-players-readme.txt"

mkdir -p -- "$here/dist"
rm -f -- "$out"
(cd "$stage" && zip -q -r -X "$out" iw7-mod)

echo "Built $out"
unzip -l "$out"
