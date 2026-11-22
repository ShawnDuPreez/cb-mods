#!/usr/bin/env bash
# Downloads iw7-mod's own HUD fix for more than four zombies players into
# this folder. Two small text files, about 8 KB together, from
# github.com/auroramod/iw7-mod at one fixed commit, each checked against a
# known SHA-256 before it is kept.
#
# They come from iw7-mod pull request 714, merged on 2026-11-08, which is not
# in the v1.1.0 release. iw7-mod is licensed GPL-3.0; so are these two files.
#
#   ./fetch-hud-fix.sh

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
commit="22281d41d51cb2fbd9775bf0102df86cb180ea0d"
base="https://raw.githubusercontent.com/auroramod/iw7-mod/$commit/data/cdata"

# fetch <path under cdata> <sha256>
fetch() {
    local path="$1" want="$2"
    local target="$here/$path"
    local tmp
    tmp="$(mktemp)"

    if ! curl -fsSL --max-time 60 -o "$tmp" "$base/$path"; then
        rm -f -- "$tmp"
        echo "Download failed: $base/$path" >&2
        return 1
    fi

    local got
    got="$(sha256sum "$tmp" | cut -d ' ' -f 1)"

    if [[ "$got" != "$want" ]]; then
        rm -f -- "$tmp"
        echo "Checksum mismatch for $path, file not kept." >&2
        echo "  expected $want" >&2
        echo "  got      $got" >&2
        return 1
    fi

    mkdir -p -- "$(dirname "$target")"
    mv -- "$tmp" "$target"
    chmod 644 -- "$target"
    echo "Fetched $path"
    return 0
}

fetch "ui_scripts/ZombiesPlayers/__init__.lua" "52b5248ab70c7610a0553691d4c4417bb622784ee11c5e3237a0b50087b1acc8"
fetch "custom_scripts/cp/scoreboard.gsc" "c8e333a98f9c08afd9c003409544133a8afad0d840e86f62144059d523c99a44"
