#!/usr/bin/env bash
# Copies files into the game's iw7-mod folder, or removes them.
#
#   ./install.sh --menu [dir]    the menu and HUD scripts only, for the mod
#                                picked in the Mods menu: everyone who plays
#                                needs them. The lobby part does nothing unless
#                                MORE_PLAYERS is the loaded mod.
#   ./install.sh [dir]           the always-on form: all the mod's files, on
#                                in every match, no mod to pick
#   ./install.sh --remove [dir]  remove whichever of the two is there
#
# dir is the game folder, the one that holds iw7-mod.exe (default
# ~/Games/Infinite-Warfare/iw_game_files).
#
# Two of the four files are iw7-mod's own HUD fix. If they are not in this
# folder yet, this runs fetch-hud-fix.sh, which downloads them from GitHub.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ours=(
    "custom_scripts/cp/more_players.gsc"
    "custom_scripts/frontend/more_players_lobby.gsc"
    "ui_scripts/MorePlayers/__init__.lua"
)
upstream=(
    "custom_scripts/cp/scoreboard.gsc"
    "ui_scripts/ZombiesPlayers/__init__.lua"
)
host_menu=(
    "ui_scripts/MorePlayers/__init__.lua"
    "ui_scripts/ZombiesPlayers/__init__.lua"
)
# Earlier versions installed this host-only lobby script; MorePlayers now does
# its job. --remove still takes it out.
retired=(
    "ui_scripts/MorePlayersLobby/__init__.lua"
)

remove=0
menu=0
if [[ "${1:-}" == "--remove" ]]; then
    remove=1
    shift
elif [[ "${1:-}" == "--menu" ]]; then
    menu=1
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
    for file in "${ours[@]}" "${upstream[@]}" "${host_menu[@]}" "${retired[@]}"; do
        if [[ -f "$dest/$file" ]]; then
            rm -- "$dest/$file"
            echo "Removed $file"
        fi
    done

    for dir in "ui_scripts/MorePlayers" "ui_scripts/ZombiesPlayers" "ui_scripts/MorePlayersLobby"; do
        if [[ -d "$dest/$dir" ]]; then
            rmdir -- "$dest/$dir" 2>/dev/null || true
        fi
    done

    exit 0
fi

if [[ "$menu" == 1 ]]; then
    for file in "${host_menu[@]}"; do
        install -D -m 644 -- "$here/$file" "$dest/$file"
        echo "Installed $file"
    done
    echo "Done. Restart the game for it to load."
    exit 0
fi

missing=0
for file in "${upstream[@]}"; do
    if [[ ! -f "$here/$file" ]]; then
        missing=1
    fi
done

if [[ "$missing" == 1 ]]; then
    echo "iw7-mod's HUD fix is not in this folder yet, downloading it."
    "$here/fetch-hud-fix.sh"
fi

for file in "${ours[@]}" "${upstream[@]}"; do
    install -D -m 644 -- "$here/$file" "$dest/$file"
    echo "Installed $file"
done

echo "Done. Restart the game for the menu and HUD scripts to load."
