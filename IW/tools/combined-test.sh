#!/usr/bin/env bash
# Tests the three mods together, the way they are meant to be combined:
# More Players loaded as a mod (fs_game mods/more_players, from its mod folder
# with mod.ff), All Perks and Perk Limit as always-on files in iw7-mod/.
#
#   tools/combined-test.sh cp_zmb        (cp_zmb cp_rave cp_disco cp_town cp_final)
#
# Runs More Players' own bot checks (8 bots: characters, spawns, revive bars,
# leave and rejoin) and All Perks' checks in the same match, with perk_limit 3
# set, and reports script errors that name any of the mods' files.

set -euo pipefail

map="${1:?usage: combined-test.sh <map>}"
tools="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$tools")"
work="${IW7_TEST_DIR:-/var/tmp/iw7-more-players-test}"
staged="$work/game/mods/more_players"

# The More Players mod folder, as make-mod-zip.sh would pack it.
mkdir -p "$staged"
find "$staged" -type f -delete
install -D -m 644 -- "$root/more-players/mod/mod.ff" "$staged/mod.ff"
install -D -m 644 -- "$root/more-players/mod/desc.txt" "$staged/desc.txt"
for file in custom_scripts/cp/more_players.gsc custom_scripts/cp/scoreboard.gsc custom_scripts/frontend/more_players_lobby.gsc; do
    install -D -m 644 -- "$root/more-players/$file" "$staged/$file"
done

status=0
"$tools/run-test-server.sh" "$map" "[apdbg] DONE" \
    "$root/all-perks/custom_scripts/cp/all_perks.gsc" \
    "$root/perk-limit/custom_scripts/cp/perk_limit.gsc" \
    "$root/all-perks/test/zz_ap_debug.gsc" \
    "$root/more-players/test/zz_mp_debug.gsc" \
    -- +set fs_game mods/more_players +set mpdbg_bots 8 +set mpdbg_tests 1 +set apdbg_bots 0 +set perk_limit 3 || status=$?

log="$work/last-run.log"
echo "--- which script files the server loaded"
grep -i "custom gsc\|Loading zone mod\|Loaded mod\|fs_game" "$log" | cut -c1-160 | sort -u | head -20 || true
grep -F "[perk_limit]" "$log" | head -2 || true
echo "--- More Players checks"
python3 -I "$tools/summary.py" "$log" "[mpdbg] TEST" custom_scripts/cp/more_players custom_scripts/cp/scoreboard | grep -v "^\[mpdbg\] TEST wheel" || true
grep -F "[mpdbg] DONE" "$log" | head -1 || echo "!! More Players checks did not finish"
echo "--- All Perks checks"
python3 -I "$tools/summary.py" "$log" "[apdbg]" custom_scripts/cp/all_perks custom_scripts/cp/perk_limit
exit "$status"
