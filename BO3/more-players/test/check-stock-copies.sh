#!/usr/bin/env bash
# Three scripts in the mod are the game's own scripts with a few lines added.
# This compares each with the original in the installed Mod Tools and fails if
# anything other than added lines differs, so a Mod Tools update that changed
# one of them is noticed before the mod overrides it with an old copy.
#
#   test/check-stock-copies.sh <bo3 folder>
#
# <bo3 folder> is the Black Ops 3 folder with the Mod Tools in it (the originals
# are in share/raw/scripts). A folder that holds scripts/ directly works too.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MOD="$HERE/../more_players"

root=${1:-}
if [[ -z "$root" ]]; then
	echo "usage: $0 <bo3 folder>" >&2
	exit 2
fi

if [[ -d "$root/share/raw/scripts" ]]; then
	stock="$root/share/raw"
elif [[ -d "$root/scripts" ]]; then
	stock="$root"
else
	echo "No share/raw/scripts under $root. Are the Mod Tools installed there?" >&2
	exit 2
fi

files=(
	"scripts/zm/gametypes/_clientids.gsc"
	"scripts/zm/_zm_score.csc"
	"scripts/zm/_zm_score.gsc"
)

failed=0

for file in "${files[@]}"; do
	if [[ ! -f "$stock/$file" ]]; then
		echo "MISSING  $file is not in $stock"
		failed=1
		continue
	fi

	# -w -B: spaces, tabs and blank lines do not count. Lines only in the
	# original start with "<", lines only in the mod's copy with ">".
	changes=$(diff -w -B --strip-trailing-cr "$stock/$file" "$MOD/$file" || true)
	removed=$(grep -c '^<' <<<"$changes" || true)
	added=$(grep -c '^>' <<<"$changes" || true)

	if [[ "$removed" -ne 0 ]]; then
		echo "DIFFERS  $file: $removed line(s) of the original are missing or changed in the mod's copy"
		grep '^<' <<<"$changes" | head -20
		failed=1
	elif [[ "$added" -eq 0 ]]; then
		echo "DIFFERS  $file: the mod's copy has no added lines, so it is not the mod's version"
		failed=1
	else
		echo "ok       $file: original intact, $added line(s) added"
	fi
done

if [[ "$failed" -ne 0 ]]; then
	echo "FAILED"
	exit 1
fi

echo "ALL PASSED"
