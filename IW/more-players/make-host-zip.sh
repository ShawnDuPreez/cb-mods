#!/usr/bin/env bash
# Builds dist/more-players-host-iw7.zip: the host's lobby script under
# iw7-mod/, to extract into the game folder. It goes with the mod picked in
# the Mods menu (dist/more_players.zip); only the host needs it.
#
#   ./make-host-zip.sh

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$here/dist/more-players-host-iw7.zip"
file="ui_scripts/MorePlayersLobby/__init__.lua"

if [[ ! -f "$here/$file" ]]; then
    echo "Missing $file" >&2
    exit 1
fi

stage="$(mktemp -d)"
cleanup() {
    rm -rf -- "$stage"
    return 0
}
trap cleanup EXIT

install -D -m 644 -- "$here/$file" "$stage/iw7-mod/$file"
install -m 644 -- "$here/zip-readme-host.txt" "$stage/iw7-mod/more-players-host-readme.txt"

mkdir -p -- "$here/dist"
rm -f -- "$out"
(cd "$stage" && zip -q -r -X "$out" iw7-mod)

echo "Built $out"
unzip -l "$out" | tail -n +4 | awk '{print $1, $4}' | grep -v '/$'
