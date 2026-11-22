#!/usr/bin/env bash
# Puts the mod folder into a Black Ops 3 folder's mods/ directory, as a link,
# so the Mod Tools build straight into this project and the game sees the result.
#
#   ./install.sh                 link into the first Black Ops 3 folder found
#   ./install.sh <bo3 folder>    link into that folder
#   ./install.sh --copy [...]    copy instead of link
#   ./install.sh --remove [...]  take the link (or copy) out again
#
# A Black Ops 3 folder is the one that holds BlackOps3.exe. The Mod Tools install
# into the same folder as the Steam game.
set -euo pipefail

MOD_NAME=more_players
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOURCE="$HERE/$MOD_NAME"

mode=link
if [[ "${1:-}" == "--copy" || "${1:-}" == "--remove" ]]; then
	mode=${1#--}
	shift
fi

game=${1:-}
if [[ -z "$game" ]]; then
	for candidate in \
		"$HOME/.local/share/Steam/steamapps/common/Call of Duty Black Ops III" \
		"$HOME/Games/Bo3/bo3_game_files"; do
		if [[ -f "$candidate/BlackOps3.exe" ]]; then
			game=$candidate
			break
		fi
	done
fi

if [[ -z "$game" || ! -f "$game/BlackOps3.exe" ]]; then
	echo "No Black Ops 3 folder found (looked for BlackOps3.exe). Pass the folder as an argument." >&2
	exit 1
fi

if [[ ! -d "$SOURCE/zone_source" ]]; then
	echo "Mod folder is missing: $SOURCE" >&2
	exit 1
fi

target="$game/mods/$MOD_NAME"

if [[ "$mode" == "remove" ]]; then
	if [[ -L "$target" ]]; then
		rm -- "$target"
		echo "Removed link $target"
	elif [[ -d "$target" ]]; then
		echo "$target is a real folder (a copy), not a link. Delete it yourself if you want it gone." >&2
		exit 1
	else
		echo "Nothing to remove at $target"
	fi
	exit 0
fi

if [[ -e "$target" || -L "$target" ]]; then
	if [[ -L "$target" && "$(readlink -f -- "$target")" == "$(readlink -f -- "$SOURCE")" ]]; then
		echo "Already linked: $target"
	else
		echo "$target already exists and is not this project's link. Remove it first." >&2
		exit 1
	fi
else
	mkdir -p "$game/mods"
	if [[ "$mode" == "copy" ]]; then
		cp -r -- "$SOURCE" "$target"
		echo "Copied to $target"
	else
		ln -s -- "$SOURCE" "$target"
		echo "Linked $target -> $SOURCE"
	fi
fi

if [[ -f "$game/bin/linker_modtools.exe" ]]; then
	echo "Mod Tools found in this folder. Build with the Mod Tools Launcher (see README.md)."
else
	echo "No Mod Tools in this folder (bin/linker_modtools.exe is missing), so it can only run a mod that is already built."
fi

if [[ ! -f "$SOURCE/zone/zm_mod.ff" ]]; then
	echo "The mod is not built yet: $SOURCE/zone has no zm_mod.ff."
fi
