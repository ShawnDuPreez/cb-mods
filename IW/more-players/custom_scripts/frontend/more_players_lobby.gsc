// More Players - keeps the zombies lobby at 8 from the menu side.
//
// ui_scripts/MorePlayers does the same job in Lua, but when the mod is loaded
// from the Mods menu the menu's Lua starts before the mod's file has finished
// loading, so the Lua part is missing in the menus until after the first
// match. This script runs in the menu level itself and does not depend on it.
//
// The zombies main menu sets party_maxplayers to 4 every time it opens. Solo
// sets it to 1 and is left alone.

init()
{
    level thread keep_zombies_lobby_at_eight();
}

keep_zombies_lobby_at_eight()
{
    for (;;)
    {
        wait 0.5;

        if ( !issubstr( getdvar( "ui_mapname" ), "cp_" ) )
            continue;

        if ( getdvarint( "party_maxplayers" ) == 4 )
            setdvar( "party_maxplayers", 8 );
    }
}
