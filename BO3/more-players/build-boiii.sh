#!/usr/bin/env bash
# Builds the mod for the BOIII client (CB Servers) without the Mod Tools, and puts
# it into a BOIII game folder if asked.
#
#   ./build-boiii.sh                      build into dist/boiii and dist/more-players-boiii.zip
#   ./build-boiii.sh --install [folder]   build, then copy it into the BOIII game folder
#   ./build-boiii.sh --remove [folder]    take it out of the game folder again
#
# The game folder is the one that holds boiii.exe, default ~/Games/Bo3/bo3_game_files.
#
# What comes out, laid out as it sits in the game folder:
#   mods/more_players/zone/*.ff, workshop.json     the game scripts, as a mod
#   boiii/ui_scripts/more_players/__init__.lua     the menu and HUD part
# Every player in the lobby needs both. The zip holds the same two folders: a
# friend unpacks it into their game folder.
#
# Needs Atian Tools (acts.zip from github.com/ate47/atian-cod-tools/releases),
# unpacked, with ACTS_DIR set to the folder that holds bin/acts.exe, and Proton to
# run it. See tools/acts-build.sh.
#
# This build is for BOIII only. It leaves out the two things Atian Tools can not
# pack and BOIII does not need: the Lua (BOIII reads it from ui_scripts) and the
# game settings file (BOIII sets the player count from the lobby size). The Steam
# game needs the Mod Tools build described in the README.
set -uo pipefail

PROJECT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ACTS_DIR=${ACTS_DIR:-/var/tmp/bo3-acts/acts/acts}
PROTON=${PROTON:-$HOME/.local/share/Steam/steamapps/common/Proton - Experimental}
WORK=${WORK:-/var/tmp/more-players-boiii-build}
MOD_FOLDER=more_players
DIST="$PROJECT/dist"
OUT="$DIST/boiii"

mode=build
if [[ "${1:-}" == "--install" || "${1:-}" == "--remove" ]]; then
	mode=${1#--}
	shift
fi
game=${1:-$HOME/Games/Bo3/bo3_game_files}

if [[ $mode != build && ! -f "$game/boiii.exe" ]]; then
	echo "No boiii.exe in $game. Pass the BOIII game folder." >&2
	exit 1
fi

if [[ $mode == remove ]]; then
	rm -f -- "${game:?}/boiii/ui_scripts/$MOD_FOLDER/__init__.lua"
	rmdir -- "${game:?}/boiii/ui_scripts/$MOD_FOLDER" 2>/dev/null
	for name in zm_mod.ff en_zm_mod.ff core_mod.ff en_core_mod.ff workshop.json; do
		rm -f -- "${game:?}/mods/$MOD_FOLDER/zone/$name"
	done
	rmdir -- "${game:?}/mods/$MOD_FOLDER/zone" "${game:?}/mods/$MOD_FOLDER" 2>/dev/null
	echo "Removed More Players from $game"
	exit 0
fi

# shellcheck source=tools/acts-build.sh
source "$PROJECT/tools/acts-build.sh"

echo "== building"
build_mod "$WORK/build" || exit 1

rm -rf -- "${OUT:?}"
mkdir -p "$OUT/mods/$MOD_FOLDER/zone" "$OUT/boiii/ui_scripts/$MOD_FOLDER"
for zone in zm_mod en_zm_mod core_mod en_core_mod; do
	cp "$WORK/build/output_ff/zone/$zone.ff" "$OUT/mods/$MOD_FOLDER/zone/$zone.ff" || exit 1
done
# BOIII only lists a mod that has this file. PublisherID is the folder name for a
# mod that is not from the Workshop.
cat > "$OUT/mods/$MOD_FOLDER/zone/workshop.json" <<JSON
{
    "Description": "Zombies for up to 8 players. Nothing else is changed.",
    "FolderName": "$MOD_FOLDER",
    "PublisherID": "$MOD_FOLDER",
    "Tags": "Mod,Zombies",
    "Thumbnail": "",
    "Title": "More Players (8 player zombies)",
    "Type": "mod"
}
JSON
cp "$PROJECT/more_players/ui/more_players/more_players.lua" "$OUT/boiii/ui_scripts/$MOD_FOLDER/__init__.lua" || exit 1

rm -f -- "$DIST/more-players-boiii.zip"
( cd "$OUT" && zip -q -r "$DIST/more-players-boiii.zip" mods boiii ) || { echo "Could not make the zip." >&2; exit 1; }

echo "built:"
( cd "$DIST" && find boiii -type f | sort | sed 's|^|  dist/|' )
echo "  dist/more-players-boiii.zip"

if [[ $mode == install ]]; then
	mkdir -p "$game/mods" "$game/boiii/ui_scripts"
	cp -r "$OUT/mods/$MOD_FOLDER" "$game/mods/" && cp -r "$OUT/boiii/ui_scripts/$MOD_FOLDER" "$game/boiii/ui_scripts/" || exit 1
	echo "Installed into $game"
	echo "In the game: Mods on the main menu, pick More Players, then Zombies > Private Game."
fi
