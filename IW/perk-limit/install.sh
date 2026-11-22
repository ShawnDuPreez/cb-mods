#!/usr/bin/env bash
# Copies files into the game's iw7-mod folder, or removes them.
#
#   ./install.sh --menu [dir]    the menu script only: the host's side of the
#                                mod you pick in the Mods menu. It shows
#                                nothing unless PERK_LIMIT is the loaded mod.
#   ./install.sh [dir]           the always-on form: menu script and game
#                                script, on in every match, no mod to pick
#   ./install.sh --remove [dir]  remove whichever of the two is there
#
# dir is the game folder, the one that holds iw7-mod.exe (default
# ~/Games/Infinite-Warfare/iw_game_files). Only the host needs these files.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

files=(
    "custom_scripts/cp/perk_limit.gsc"
    "ui_scripts/PerkLimit/__init__.lua"
)
dirs=(
    "ui_scripts/PerkLimit"
)

remove=0
if [[ "${1:-}" == "--remove" ]]; then
    remove=1
    shift
elif [[ "${1:-}" == "--menu" ]]; then
    files=("ui_scripts/PerkLimit/__init__.lua")
    shift
fi

game_dir="${1:-$HOME/Games/Infinite-Warfare/iw_game_files}"

if [[ ! -f "$game_dir/iw7-mod.exe" ]]; then
    echo "No iw7-mod.exe in: $game_dir" >&2
    echo "Pass the game folder as the first argument." >&2
    exit 1
fi

dest="$game_dir/iw7-mod"

if [[ "$remove" == 1 ]]; then
    for file in "${files[@]}"; do
        if [[ -f "$dest/$file" ]]; then
            rm -- "$dest/$file"
            echo "Removed $file"
        fi
    done

    for dir in "${dirs[@]}"; do
        if [[ -d "$dest/$dir" ]]; then
            rmdir -- "$dest/$dir" 2>/dev/null || true
        fi
    done

    exit 0
fi

for file in "${files[@]}"; do
    install -D -m 644 -- "$here/$file" "$dest/$file"
    echo "Installed $file"
done

echo "Done. Restart the game for the lobby control to load."
