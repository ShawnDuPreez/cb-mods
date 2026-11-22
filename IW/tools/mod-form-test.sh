#!/usr/bin/env bash
# Runs All Perks or Perk Limit the way the game's Mods menu loads it: from its
# mod folder (dist/<name>.zip unpacked under mods/, fs_game set), with nothing
# of the mod in iw7-mod/. Only the mod's debug script is loose.
#
#   tools/mod-form-test.sh all-perks cp_zmb
#   tools/mod-form-test.sh perk-limit cp_zmb
#
# Shows that the game script loads from the mod folder and that the server
# accepts the mod's mod.ff, then runs the mod's usual bot checks.

set -euo pipefail

which="${1:?usage: mod-form-test.sh all-perks|perk-limit <map>}"
map="${2:?missing map}"
tools="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$tools")"
work="${IW7_TEST_DIR:-/var/tmp/iw7-more-players-test}"

case "$which" in
    all-perks)
        name=all_perks; debug="$root/all-perks/test/zz_ap_debug.gsc"; prefix="[apdbg]"
        args=(+set apdbg_bots 6) ;;
    perk-limit)
        name=perk_limit; debug="$root/perk-limit/test/zz_pl_debug.gsc"; prefix="[pldbg]"
        args=(+set pldbg_bots 3 +set pldbg_limits "keep 0 3" +set perk_limit 7) ;;
    *)
        echo "unknown mod: $which" >&2; exit 1 ;;
esac

staged="$work/game/mods/$name"
mkdir -p "$work/game/mods"
if [[ -d "$staged" ]]; then
    find "$staged" -type f -delete
fi
unzip -q -o "$root/$which/dist/$name.zip" -d "$work/game/mods/"

status=0
"$tools/run-test-server.sh" "$map" "$prefix DONE" "$debug" \
    -- +set fs_game "mods/$name" "${args[@]}" || status=$?

log="$work/last-run.log"
echo "--- loaded from"
grep -i "mods/$name\|Loaded custom gsc 'custom_scripts/cp/$name\|zone mod\|Loaded mod" "$log" | cut -c1-160 | sort -u | head -8 || true
grep -F "[perk_limit]" "$log" | head -1 || true
python3 -I "$tools/summary.py" "$log" "$prefix TEST" "custom_scripts/cp/$name"
grep -F "$prefix DONE" "$log" | head -1 || echo "!! checks did not finish"
exit "$status"
