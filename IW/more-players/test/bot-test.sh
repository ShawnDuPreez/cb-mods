#!/usr/bin/env bash
# Runs a private headless zombies server with 8 bots on one map and checks the mod.
#
#   test/bot-test.sh cp_zmb        (cp_zmb cp_rave cp_disco cp_town cp_final)
#   test/bot-test.sh cp_zmb 2      the wonder weapons in the Magic Wheel instead
#
# The server is not listed publicly (sv_lanOnly). It runs from a folder of links to the
# game files, so its log and settings stay out of the real game folder. Takes about 90 s.
#
# Never type iw7-mod's own spawnBot command in zombies: it crash-loops the server and
# fills <game folder>/minidumps.

set -euo pipefail

map="${1:?usage: bot-test.sh <map> [1|2]}"
tests="${2:-1}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mod="$(dirname "$here")"
game="${IW7_GAME_DIR:-$HOME/Games/Infinite-Warfare/iw_game_files}"
prefix="${IW7_COMPAT_DATA:-$HOME/.local/share/Steam/steamapps/compatdata/3991105417}"
proton="${IW7_PROTON:-$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/proton}"
work="${IW7_TEST_DIR:-/var/tmp/iw7-more-players-test}"
port="${IW7_TEST_PORT:-27040}"
run="$work/game"
log="$run/iw7-mod/logs/console.log"

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
cp "$mod/custom_scripts/cp/more_players.gsc" "$mod/custom_scripts/cp/scoreboard.gsc" "$here/zz_mp_debug.gsc" "$run/iw7-mod/custom_scripts/cp/"

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
        timeout 300 "$proton" run ./iw7-mod.exe -dedicated -zombies -noupdate \
        +set sv_lanOnly 1 +set net_port "$port" +set party_maxplayers 8 +set developer_script 1 \
        +set mpdbg_bots 8 +set mpdbg_tests "$tests" +map "$map" > "$work/server.out" 2>&1
) &

result="timed out"
for _ in $(seq 1 120); do
    sleep 2
    [[ -f "$log" ]] || continue
    new="$(tail -n +"$((start + 1))" "$log")"
    if grep -q '\[mpdbg\] DONE' <<<"$new"; then
        result="finished"
        break
    fi
    if grep -q 'script compile error' <<<"$new"; then
        result="script compile error"
        break
    fi
done

tail -n +"$((start + 1))" "$log" > "$work/last-run.log"
echo "$map: $result"
python3 -I "$here/summary.py" "$work/last-run.log"

if [[ "$result" != "finished" ]]; then
    exit 1
fi
