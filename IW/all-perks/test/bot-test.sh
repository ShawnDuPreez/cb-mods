#!/usr/bin/env bash
# Runs a private headless zombies server with bots on one map and checks the mod.
#
#   test/bot-test.sh cp_zmb        (cp_zmb cp_rave cp_disco cp_town cp_final)
#   test/bot-test.sh cp_zmb -v     also list every kind of script error
#   test/bot-test.sh cp_zmb solo   one bot alone, where Up 'N Atoms is a self revive
#
# Prints the perks every player holds after the start, after the game's own
# "went down, got back up" handling, and for a player who joins late, plus any
# script error that names this mod's file. Takes about two minutes.
# See ../tools/run-test-server.sh for how the server is run.

set -euo pipefail

map="${1:?usage: bot-test.sh <map> [-v]}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mod="$(dirname "$here")"
tools="$(dirname "$mod")/tools"
work="${IW7_TEST_DIR:-/var/tmp/iw7-more-players-test}"

server_args=(+set apdbg_bots 6)
verbose="${2:-}"
if [[ "$verbose" == "solo" ]]; then
    server_args=(+set apdbg_bots 1 +set apdbg_solo 1 +set party_partyPlayerCountNum 1)
    verbose=""
fi

status=0
"$tools/run-test-server.sh" "$map" "[apdbg] DONE" \
    "$mod/custom_scripts/cp/all_perks.gsc" "$here/zz_ap_debug.gsc" \
    -- "${server_args[@]}" || status=$?

python3 -I "$tools/summary.py" "$work/last-run.log" "[apdbg]" custom_scripts/cp/all_perks ${verbose:+"$verbose"}
exit "$status"
