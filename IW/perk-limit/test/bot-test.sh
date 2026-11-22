#!/usr/bin/env bash
# Runs a private headless zombies server with bots on one map and checks the mod.
#
#   test/bot-test.sh cp_zmb                 limits: unset (5), 2, no limit, 9
#   test/bot-test.sh cp_rave "keep 0 3" 7   start the server with perk_limit 7,
#                                           test that, then no limit, then 3
#   add -v as a last argument to list every kind of script error
#
# For each limit a bot is walked past every perk machine on the map through
# the game's own machine code, and the perks it ends up with are printed.
# "keep" means: leave the dvar as the server was started.
# See ../tools/run-test-server.sh for how the server is run.

set -euo pipefail

map="${1:?usage: bot-test.sh <map> [\"<limits>\"] [<perk_limit at start>] [-v]}"
limits="${2:-keep 2 0 9}"
at_start="${3:-}"
verbose="${4:-}"
if [[ "$at_start" == "-v" ]]; then
    at_start=""
    verbose="-v"
fi
if [[ "$limits" == "-v" ]]; then
    limits="keep 2 0 9"
    verbose="-v"
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mod="$(dirname "$here")"
tools="$(dirname "$mod")/tools"
work="${IW7_TEST_DIR:-/var/tmp/iw7-more-players-test}"

server_args=(+set pldbg_bots 3 +set pldbg_limits "$limits")
if [[ -n "$at_start" ]]; then
    server_args+=(+set perk_limit "$at_start")
fi

status=0
"$tools/run-test-server.sh" "$map" "[pldbg] DONE" \
    "$mod/custom_scripts/cp/perk_limit.gsc" "$here/zz_pl_debug.gsc" \
    -- "${server_args[@]}" || status=$?

python3 -I "$tools/summary.py" "$work/last-run.log" "[pldbg]" custom_scripts/cp/perk_limit ${verbose:+"$verbose"}
grep -F "[perk_limit]" "$work/last-run.log" | head -3 || true
exit "$status"
