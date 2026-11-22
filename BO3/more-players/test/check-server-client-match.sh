#!/usr/bin/env bash
# The server script and the client script each register fields for player slots
# 4-7. The two lists must be the same, or the game stops with a field mismatch.
# This compares them: the limits, the revive field, and the per-map item fields.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
gsc="$HERE/../more_players/scripts/zm/zm_more_players.gsc"
csc="$HERE/../more_players/scripts/zm/zm_more_players.csc"

# name, version and size of every field, in source order, with spaces removed
fields() {
	{
		grep -E '^#define MORE_PLAYERS_(MAX|STOCK_MAX|VERSION_SHIP)\b' "$1" | tr -s '\t ' ' '
		# the client's extra last argument (what to call) is not part of the comparison
		grep -E 'str_map == "|register_slot_fields\( "' "$1" | tr -d '\t ' | sed 's/^elseif/if/' \
			| sed -E 's/^(register_slot_fields\("[^"]*","[^"]*",[0-9]+,[^,]*(\([0-9]+\))?)(,[^;]*)?\);/\1);/'
		grep -E 'clientfield::register\(' "$1" | tr -d '\t ' \
			| sed -E 's/level\.laststands\[i\]\.laststand_update_clientfields/"laststand_update"+i/' \
			| sed -E 's/^clientfield::register\(("[a-z]+",[^,]+,[^,]+,[^,]+,"[a-z]+").*/\1/'
	} | sort
}

if diff <(fields "$gsc") <(fields "$csc"); then
	echo "ALL PASSED ($(fields "$gsc" | wc -l) lines compared)"
else
	echo "FAILED: the lines above differ between zm_more_players.gsc (<) and zm_more_players.csc (>)"
	exit 1
fi
