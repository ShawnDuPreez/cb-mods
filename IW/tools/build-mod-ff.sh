#!/usr/bin/env bash
# Builds <mod folder>/mod/mod.ff with zonetool (x64-zt) through Proton.
#
#   tools/build-mod-ff.sh <mod folder> <zone name>
#   tools/build-mod-ff.sh perk-limit perk_limit
#
# Needs, in the mod folder:
#   zone_source/<zone name>.csv     the list of assets
#   zonetool/<zone name>/...        the raw files the list names
#   ui_scripts/...                  (optional) copied in for "luafile" lines
#
# zonetool.exe is not part of this project. Download Release.zonetool.zip from
# the x64-zt releases page, unpack it, and point IW7_ZONETOOL at zonetool.exe
# (default: the copy an earlier session unpacked under /var/tmp). The first
# run makes a patched copy next to the game-file links: under Proton the stock
# exe crashes at start, because it looks up the ntdll function
# DbgPrintReturnControlC, which Wine does not have. The copy asks for DbgPrint
# instead.
#
# Every player needs the identical mod.ff. Rebuild only when the list or the
# packed files changed, then hand the new zip to everyone.

set -euo pipefail

mod="$(cd "${1:?usage: build-mod-ff.sh <mod folder> <zone name>}" && pwd)"
zone="${2:?missing zone name}"

game="${IW7_GAME_DIR:-$HOME/Games/Infinite-Warfare/iw_game_files}"
prefix="${IW7_COMPAT_DATA:-$HOME/.local/share/Steam/steamapps/compatdata/3991105417}"
proton="${IW7_PROTON:-$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/proton}"
work="${IW7_TEST_DIR:-/var/tmp/iw7-more-players-test}"
stock_tool="${IW7_ZONETOOL:-$work/zonetool-dl/zonetool.exe}"
run="$work/game"

if [[ ! -f "$mod/zone_source/$zone.csv" ]]; then
    echo "Missing $mod/zone_source/$zone.csv" >&2
    exit 1
fi

mkdir -p "$run"
for file in "$game"/*; do
    name="$(basename "$file")"
    if [[ "$name" == "iw7-mod" || "$name" == "mods" ]]; then
        continue
    fi
    ln -sfn "$file" "$run/$name"
done

if [[ ! -f "$run/zonetool.exe" ]]; then
    if [[ ! -f "$stock_tool" ]]; then
        echo "No zonetool.exe at $stock_tool (set IW7_ZONETOOL). See the top of this script." >&2
        exit 1
    fi
    python3 -I - "$stock_tool" "$run/zonetool.exe" <<'PY'
import sys
data = bytearray(open(sys.argv[1], "rb").read())
old = b"DbgPrintReturnControlC\0"
at = data.find(old)
if at < 0 or data.find(old, at + 1) >= 0:
    sys.exit("expected exactly one DbgPrintReturnControlC in zonetool.exe")
data[at:at + len(old)] = b"DbgPrint".ljust(len(old), b"\0")
open(sys.argv[2], "wb").write(data)
print("patched copy written:", sys.argv[2])
PY
fi

# Stage this zone's sources from scratch.
mkdir -p "$run/zone_source" "$run/zonetool"
stage="$run/zonetool/$zone"
if [[ -d "$stage" ]]; then
    find "$stage" -type f -delete
fi
mkdir -p "$stage"
cp -- "$mod/zone_source/$zone.csv" "$run/zone_source/$zone.csv"
if [[ -d "$mod/zonetool/$zone" ]]; then
    cp -r -- "$mod/zonetool/$zone/." "$stage/"
fi
if [[ -d "$mod/ui_scripts" ]]; then
    cp -r -- "$mod/ui_scripts" "$stage/"
fi

# Every file the list names must be staged, or zonetool quietly leaves it out.
while IFS=, read -r kind asset _; do
    [[ -z "$kind" || "$kind" == \#* ]] && continue
    if [[ ! -f "$stage/$asset" ]]; then
        echo "Listed in $zone.csv but not staged: $asset" >&2
        exit 1
    fi
done < "$mod/zone_source/$zone.csv"

rm -f -- "$run/$zone.ff"
(
    cd "$run"
    STEAM_COMPAT_DATA_PATH="$prefix" STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam" \
        timeout 300 "$proton" run ./zonetool.exe -buildzone "$zone" > "$work/zonetool.out" 2>&1
) || true

if [[ ! -s "$run/$zone.ff" ]]; then
    echo "zonetool wrote no $zone.ff. Its output:" >&2
    tail -n 30 "$work/zonetool.out" >&2
    exit 1
fi

mkdir -p "$mod/mod"
cp -- "$run/$zone.ff" "$mod/mod/mod.ff"
echo "Built $mod/mod/mod.ff"
stat -c '%s bytes' "$mod/mod/mod.ff"
sha256sum "$mod/mod/mod.ff" | cut -d' ' -f1
