#!/usr/bin/env bash
# Runs one hands-off 8-player zombies match with bots on the BOIII client and prints
# what happened. Nobody has to touch the game: a small Lua script walks the menus
# (Zombies > Private Game > map > Start) and quits the game at the end.
#
#   test/bot-test.sh [options]
#     --map <name>      map to play, default zm_factory (The Giant)
#     --players <n>     players in total, host included, default 8
#     --rounds <n>      kill zombies as they spawn until this round, default 0 (off)
#     --no-tests        skip the scripted checks (down and revive, gums, item icons)
#     --stock           leave the mod out, to see what the game does on its own
#     --seconds <n>     give up waiting after this long, default 300
#     --keep            leave the test files in the game folder afterwards
#
# Needs, besides the game:
#   - Atian Tools (acts.zip from github.com/ate47/atian-cod-tools/releases), unpacked.
#     Set ACTS_DIR to the folder that holds bin/acts.exe.
#     It stands in for the Mod Tools here: it compiles the scripts and packs them
#     into a mod file (tools/acts-build.sh, the same build build-boiii.sh makes).
#     It can not pack Lua, so the mod's Lua is given to BOIII directly
#     (boiii/ui_scripts).
#   - Proton, to run acts.exe and the game. Paths are in the settings below.
#
# The test build goes into the game folder as the mod "mp_test", next to a
# More Players you installed with build-boiii.sh, and is taken out at the end.
# The Lua shares its place with the installed one (boiii/ui_scripts/more_players):
# the test puts the project's current Lua there and, if one was installed before,
# leaves it there afterwards.
#
# The game window opens and takes keyboard focus while the test runs.
# If the game freezes, close its window by hand; this script only waits.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT=$(cd "$HERE/.." && pwd)

GAME=${GAME:-$HOME/Games/Bo3/bo3_game_files}
ACTS_DIR=${ACTS_DIR:-/var/tmp/bo3-acts/acts/acts}
PROTON=${PROTON:-$HOME/.local/share/Steam/steamapps/common/Proton - Experimental}
GAME_PREFIX=${GAME_PREFIX:-$HOME/.local/share/Steam/steamapps/compatdata/3991105417}
WORK=${WORK:-/var/tmp/more-players-bot-test}
# the folder name the test build gets under <game>/mods
MOD_FOLDER=${MOD_FOLDER:-mp_test}

map=zm_factory; players=8; rounds=0; tests=1; stock=0; seconds=300; keep=0
while [[ $# -gt 0 ]]; do
	case $1 in
		--map) map=$2; shift 2 ;;
		--players) players=$2; shift 2 ;;
		--rounds) rounds=$2; shift 2 ;;
		--seconds) seconds=$2; shift 2 ;;
		--no-tests) tests=0; shift ;;
		--stock) stock=1; shift ;;
		--keep) keep=1; shift ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done

[[ -f "$GAME/boiii.exe" ]] || { echo "No boiii.exe in $GAME (set GAME)." >&2; exit 1; }
[[ -x "$PROTON/proton" ]] || { echo "No proton in $PROTON (set PROTON)." >&2; exit 1; }
if pgrep -f '^\./boiii\.exe' >/dev/null; then echo "The game is already running. Close it first." >&2; exit 1; fi

# shellcheck source=../tools/acts-build.sh
source "$PROJECT/tools/acts-build.sh"

# ---------------------------------------------------------------------------
# Build: the mod as build-boiii.sh builds it, plus the debug script
# ---------------------------------------------------------------------------
B="$WORK/build"
echo "== building"
build_mod "$B" || exit 1
prep "$HERE/zz_mp_debug.gsc" "$B/scripts/zm/zz_mp_debug.gsc"
( cd "$B" && acts gscc scripts/zm/zz_mp_debug.gsc -g bo3 -p pc -o zz_mp_debug --name scripts/zm/zz_mp_debug.gsc ) > "$B/build.log.debug"
grep -q '^Done into' "$B/build.log.debug" || { echo "BUILD FAILED (debug script):"; cat "$B/build.log.debug"; exit 1; }
echo "built: 5 mod scripts and the debug script"

# ---------------------------------------------------------------------------
# Put the test files into the game folder
# ---------------------------------------------------------------------------
mkdir -p "$GAME/mods/$MOD_FOLDER/zone" "$GAME/boiii/custom_scripts/zm" \
	"$GAME/boiii/ui_scripts/more_players" "$GAME/boiii/ui_scripts/zz_mp_autostart"
for zone in zm_mod en_zm_mod core_mod en_core_mod; do
	cp "$B/output_ff/zone/$zone.ff" "$GAME/mods/$MOD_FOLDER/zone/$zone.ff"
done
cat > "$GAME/mods/$MOD_FOLDER/zone/workshop.json" <<JSON
{
    "Description": "more_players test build",
    "FolderName": "$MOD_FOLDER",
    "PublisherID": "$MOD_FOLDER",
    "Tags": "Mod",
    "Thumbnail": "",
    "Title": "more_players test",
    "Type": "mod"
}
JSON
lua_was_installed=0
[[ -f "$GAME/boiii/ui_scripts/more_players/__init__.lua" && -d "$GAME/mods/more_players" ]] && lua_was_installed=1
cp "$B/zz_mp_debug.gscc" "$GAME/boiii/custom_scripts/zm/zz_mp_debug.gsc"
# the lobby has to hold the bots in a stock run too, so the Lua always goes in
cp "$PROJECT/more_players/ui/more_players/more_players.lua" "$GAME/boiii/ui_scripts/more_players/__init__.lua"
cp "$HERE/zz_mp_autostart.lua" "$GAME/boiii/ui_scripts/zz_mp_autostart/__init__.lua"

cleanup() {
	[[ $keep -eq 1 ]] && return
	rm -f -- "${GAME:?}/boiii/custom_scripts/zm/zz_mp_debug.gsc" \
		"${GAME:?}/boiii/ui_scripts/zz_mp_autostart/__init__.lua"
	rmdir -- "${GAME:?}/boiii/ui_scripts/zz_mp_autostart" "${GAME:?}/boiii/custom_scripts/zm" "${GAME:?}/boiii/custom_scripts" 2>/dev/null
	if [[ $lua_was_installed -eq 0 ]]; then
		rm -f -- "${GAME:?}/boiii/ui_scripts/more_players/__init__.lua"
		rmdir -- "${GAME:?}/boiii/ui_scripts/more_players" 2>/dev/null
	fi
	for zone in zm_mod en_zm_mod core_mod en_core_mod; do rm -f -- "${GAME:?}/mods/$MOD_FOLDER/zone/$zone.ff"; done
	rm -f -- "${GAME:?}/mods/$MOD_FOLDER/zone/workshop.json"
	rmdir -- "${GAME:?}/mods/$MOD_FOLDER/zone" "${GAME:?}/mods/$MOD_FOLDER" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
args=(+set logfile 2 +set mpdbg_map "$map" +set mpdbg_bots "$players" +set mpdbg_tests "$tests" +set mpdbg_rounds "$rounds")
[[ $stock -eq 0 ]] && args+=(+set mpdbg_mod "$MOD_FOLDER")

dumps_before=$(ls "$GAME/minidumps" 2>/dev/null | wc -l)
echo "== starting the game: map=$map players=$players rounds=$rounds tests=$tests mod=$((1 - stock))"
(
	cd "$GAME" || exit 1
	STEAM_COMPAT_DATA_PATH="$GAME_PREFIX" STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam" \
		nohup "$PROTON/proton" run ./boiii.exe -launch -nointro "${args[@]}" > "$WORK/game.out" 2>&1 &
)

sleep 20
waited=20
while pgrep -f '^\./boiii\.exe' >/dev/null && [[ $waited -lt $seconds ]]; do sleep 5; waited=$((waited + 5)); done

log="$WORK/console-$map.log"
cp "$GAME/console_mp.log" "$log" 2>/dev/null
dumps_after=$(ls "$GAME/minidumps" 2>/dev/null | wc -l)

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
echo "== result"
if pgrep -f '^\./boiii\.exe' >/dev/null; then
	echo "The game is STILL RUNNING after ${waited}s. Close its window by hand. Test files were left in the game folder."
	keep=1
else
	echo "The game exited after about ${waited}s."
fi
crashes=$((dumps_after - dumps_before))
echo "new crash dumps: $crashes"
grep -a 'MPDBG' "$log" | sed -e 's/^\[msg\]//' -e 's/\^7//g' | grep -v 'MPDBG connect\|MPDBG spawn\| gums=' | cut -c1-200
mod_errors=$(grep -a -c "file 'scripts/zm/zm_more_players\|file 'scripts/zm/gametypes/_clientids" "$log")
echo "script errors with one of the mod's files in the call stack: $mod_errors"
echo "full console log: $log"

cleanup

if [[ $crashes -eq 0 && $mod_errors -eq 0 ]] && grep -a -q 'MPDBG finished' "$log"; then
	echo "ALL PASSED"
	exit 0
fi
echo "FAILED"
exit 1
