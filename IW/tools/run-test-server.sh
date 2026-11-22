#!/usr/bin/env bash
# Runs a private headless zombies server on one map with some custom scripts
# and waits for a debug script to print its DONE line.
#
#   run-test-server.sh <map> <done marker> <script.gsc>... [-- <server args>...]
#
#   map           cp_zmb cp_rave cp_disco cp_town cp_final
#   done marker   text the debug script prints when it has finished
#   script.gsc    files copied into the server's custom_scripts/cp/
#   server args   extra command line, e.g. +set perk_limit 7
#
# The log of the run is written to $IW7_TEST_DIR/last-run.log.
# Two runs at once need their own IW7_TEST_DIR and IW7_TEST_PORT each.
#
# The server is not listed publicly (sv_lanOnly). It runs from a folder of
# links to the game files with its own iw7-mod folder, so its log and settings
# stay out of the real game folder, and nothing installed in the real game's
# iw7-mod folder is loaded. Takes one to two minutes.
#
# Never type iw7-mod's own spawnBot command in zombies: it crash-loops the
# server and fills <game folder>/minidumps.

set -euo pipefail

map="${1:?usage: run-test-server.sh <map> <done marker> <script.gsc>... [-- <server args>...]}"
marker="${2:?missing done marker}"
shift 2

scripts=()
while [[ $# -gt 0 && "$1" != "--" ]]; do
    scripts+=("$1")
    shift
done
if [[ "${1:-}" == "--" ]]; then
    shift
fi
extra=("$@")

game="${IW7_GAME_DIR:-$HOME/Games/Infinite-Warfare/iw_game_files}"
prefix="${IW7_COMPAT_DATA:-$HOME/.local/share/Steam/steamapps/compatdata/3991105417}"
proton="${IW7_PROTON:-$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/proton}"
work="${IW7_TEST_DIR:-/var/tmp/iw7-more-players-test}"
wait_seconds="${IW7_TEST_WAIT:-240}"
port="${IW7_TEST_PORT:-27040}"
run="$work/game"
log="$run/iw7-mod/logs/console.log"

if [[ ! -f "$game/iw7-mod.exe" ]]; then
    echo "No iw7-mod.exe in: $game (set IW7_GAME_DIR)" >&2
    exit 1
fi

mkdir -p "$run"
for file in "$game"/*; do
    ln -sfn "$file" "$run/$(basename "$file")"
done
if [[ -L "$run/iw7-mod" ]]; then
    unlink "$run/iw7-mod"
fi
mkdir -p "$run/iw7-mod/custom_scripts/cp" "$run/iw7-mod/logs"

# Start from an empty script folder, so a file left by another test is not loaded.
find "$run/iw7-mod/custom_scripts/cp" -maxdepth 1 -type f -name '*.gsc' -delete
for script in "${scripts[@]}"; do
    if [[ ! -f "$script" ]]; then
        echo "Missing script: $script" >&2
        exit 1
    fi
    cp -- "$script" "$run/iw7-mod/custom_scripts/cp/"
done

start=0
if [[ -f "$log" ]]; then
    start=$(wc -l < "$log")
fi

stop_server() {
    local pid
    for pid in $(ps -eo pid,args | awk -v port="net_port $port " '/iw7-mod\.exe -dedicated/ && !/awk/ && index($0, port) {print $1}'); do
        kill "$pid" 2>/dev/null || true
    done
    return 0
}
trap stop_server EXIT

(
    cd "$run"
    STEAM_COMPAT_DATA_PATH="$prefix" STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam" \
        timeout "$((wait_seconds + 60))" "$proton" run ./iw7-mod.exe -dedicated -zombies -noupdate \
        +set sv_lanOnly 1 +set net_port "$port" +set party_maxplayers 8 +set developer_script 1 \
        "${extra[@]}" +map "$map" > "$work/server.out" 2>&1
) &

result="timed out"
for _ in $(seq 1 "$((wait_seconds / 2))"); do
    sleep 2
    [[ -f "$log" ]] || continue
    new="$(tail -n +"$((start + 1))" "$log")"
    if grep -qF -- "$marker" <<<"$new"; then
        result="finished"
        break
    fi
    if grep -q 'script compile error\|failed to compile' <<<"$new"; then
        result="script compile error"
        break
    fi
done

tail -n +"$((start + 1))" "$log" > "$work/last-run.log"
echo "$map: $result"

if [[ "$result" != "finished" ]]; then
    exit 1
fi
