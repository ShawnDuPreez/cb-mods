#!/usr/bin/env bash
# Copies the mod into the game's iw7-mod folder as always-on files, or removes it.
#
#   ./install.sh                 install into the default game folder
#   ./install.sh /path/to/game   install into another game folder
#   ./install.sh --remove [dir]  remove it again
#
# The game folder is the one that holds iw7-mod.exe. Only the host needs these
# files. They work beside any mod picked in the game's Mods menu.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

files=(
    "custom_scripts/cp/all_perks.gsc"
)
dirs=(

)

remove=0
if [[ "${1:-}" == "--remove" ]]; then
    remove=1
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

echo "Done. The script loads when the next match starts."
