#!/usr/bin/env bash
# Starts a private zombies server on this PC with bots in the first slots, so you
# can join it from your own game as player 5 (or any number up to 8) and try
# buying, doors, perks, the HUD and name tags in that slot yourself.
#
#   test/join-as-player.sh               Rave in the Redwoods, you are player 5
#   test/join-as-player.sh cp_zmb 8      Spaceland, you are player 8
#
# Maps: cp_zmb cp_rave cp_disco cp_town cp_final.
#
# The server runs the mod as installed in your game folder (mods/more_players),
# so install the zip you want to test first. It is not listed publicly
# (sv_lanOnly) and runs from its own folder of links to the game files, so its
# log and settings stay out of your game folder.
#
# When it prints "ready", in your game: Zombies menu, open the console (the key
# under Esc) and type the connect line it shows. Bots stand still and get eaten
# after a while; that is fine. Ctrl+C here stops the server.
#
# Never type iw7-mod's own spawnBot command in zombies: it crash-loops the game.

set -euo pipefail

map="${1:-cp_rave}"
slot="${2:-5}"
if ! [[ "$slot" =~ ^[1-8]$ ]]; then
    echo "Player number must be 1 to 8." >&2
    exit 1
fi
bots=$((slot - 1))

game="${IW7_GAME_DIR:-$HOME/Games/Infinite-Warfare/iw_game_files}"
# The server gets its own Wine prefix. Sharing the game's prefix while the game runs
# through the CB launcher (inside Steam's container) does not work: restarting the
# game killed the server, and joining hung (seen 2026-11-23).
game_prefix="${IW7_COMPAT_DATA:-$HOME/.local/share/Steam/steamapps/compatdata/3991105417}"
prefix="${IW7_JOIN_PREFIX:-/var/tmp/iw7-test-prefix}"
proton="${IW7_PROTON:-$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/proton}"
# The same folder bot-test.sh uses: a dedicated server started in a brand-new folder
# sat at its first start without writing a log (seen 2026-11-23), and this one is
# known to start. So the two can not run at the same time.
work="${IW7_JOIN_DIR:-/var/tmp/iw7-more-players-test}"
port="${IW7_JOIN_PORT:-27045}"
run="$work/game"
log="$run/iw7-mod/logs/console.log"

if [[ ! -f "$game/mods/more_players/mod.ff" ]]; then
    echo "MORE_PLAYERS is not installed in $game/mods/more_players. Install the zip first." >&2
    exit 1
fi

# Make the server's prefix once, and copy iw7-mod's own client files (its scripts and
# menus, in AppData) from the game's prefix every time, so they match the game.
if [[ ! -d "$prefix/pfx/drive_c" ]]; then
    echo "Making the server's own Wine prefix in $prefix ..."
    mkdir -p "$prefix"
    STEAM_COMPAT_DATA_PATH="$prefix" STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam" \
        "$proton" run cmd.exe /c exit > /dev/null 2>&1 || true
fi
appdata="pfx/drive_c/users/steamuser/AppData/Local"
if [[ ! -d "$game_prefix/$appdata/auroramod" ]]; then
    echo "No iw7-mod client files in $game_prefix/$appdata/auroramod (set IW7_COMPAT_DATA)." >&2
    exit 1
fi
mkdir -p "$prefix/$appdata"
cp -a -- "$game_prefix/$appdata/auroramod" "$prefix/$appdata/"

mkdir -p "$run"
for file in "$game"/*; do
    ln -sfn "$file" "$run/$(basename "$file")"
done
if [[ -L "$run/iw7-mod" ]]; then
    unlink "$run/iw7-mod"
fi
# The server must load the mod from your game folder. An old real "mods" folder left
# in the test folder by earlier tests made it load an old mod.ff, and joining then
# failed with "Download failed: Server doesn't have 'sv_wwwBaseUrl' dvar set."
if [[ ! -L "$run/mods" ]]; then
    echo "$run/mods is not a link to $game/mods. Move it away and run this again." >&2
    exit 1
fi
mkdir -p "$run/iw7-mod/custom_scripts/cp" "$run/iw7-mod/logs"
find "$run/iw7-mod/custom_scripts/cp" -maxdepth 1 -type f -name '*.gsc' -delete

# Adds the bots and says when they are in.
cat > "$run/iw7-mod/custom_scripts/cp/zz_join_bots.gsc" <<'GSC'
init()
{
    level thread join_bots();
}

join_bots()
{
    level endon( "game_ended" );
    wait 12;
    count = getdvarint( "join_bots", 0 );

    for ( i = 0; i < count; i++ )
    {
        bot = addbot( "", 0, 0, 0 );

        if ( isdefined( bot ) )
            bot thread join_spawn_bot();

        wait 1;
    }

    wait 3;
    print( "[join] ready, " + level.players.size + " bots in" );
}

join_spawn_bot()
{
    self endon( "disconnect" );
    waited = 0;

    while ( !self canspawntestclient() )
    {
        wait 0.05;
        waited += 0.05;

        if ( waited > 20 )
            return;
    }

    wait 0.5;
    self spawntestclient();
}
GSC

start=0
if [[ -f "$log" ]]; then
    start=$(wc -l < "$log")
fi

stop_server() {
    local pid
    for pid in $(ps -eo pid,args | awk -v port="net_port $port " '/iw7-mod\.exe -dedicated/ && !/awk/ && index($0, port) {print $1}'); do
        kill "$pid" 2>/dev/null || true
    done
    return 0
}
trap stop_server EXIT

echo "Starting the server on $map with $bots bots (you will be player $slot)..."
(
    cd "$run"
    STEAM_COMPAT_DATA_PATH="$prefix" STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam" \
        "$proton" run ./iw7-mod.exe -dedicated -zombies -noupdate \
        +set fs_game mods/more_players +set sv_lanOnly 1 +set net_port "$port" \
        +set party_maxplayers 8 +set join_bots "$bots" +map "$map" > "$work/server.out" 2>&1
) &

for _ in $(seq 1 120); do
    sleep 2
    [[ -f "$log" ]] || continue
    new="$(tail -n +"$((start + 1))" "$log")"
    if grep -q 'compile error' <<<"$new"; then
        echo "A script failed to compile. The log is $log" >&2
        exit 1
    fi
    if grep -q '\[join\] ready' <<<"$new"; then
        grep -E 'More Players:|\[join\]' <<<"$new" | sed 's/^/  /'
        echo
        echo "ready. In your game: Zombies menu, open the console and type:"
        echo
        echo "    connect 127.0.0.1:$port"
        echo
        echo "Ctrl+C here stops the server. Its log: $log"
        wait
        exit 0
    fi
done

echo "The server did not get ready in 4 minutes. The log is $log" >&2
exit 1
