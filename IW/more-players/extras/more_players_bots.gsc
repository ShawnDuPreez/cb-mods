// More Players - test bots. Optional, host only. Not part of the mod.
//
// In the console, before the match starts:   set more_players_bots 7
// The bots join about 12 seconds after the map loads. They stand still.
// Set it back to 0 to stop adding them.
//
// Never use iw7-mod's own spawnBot command in zombies: it crash-loops the game.

init()
{
    level thread add_test_bots();
}

add_test_bots()
{
    level endon( "game_ended" );
    wait 12;
    count = getdvarint( "more_players_bots", 0 );

    for ( i = 0; i < count; i++ )
    {
        if ( level.players.size >= getmaxclients() )
            return;

        bot = addbot( "", 0, 0, 0 );

        if ( isdefined( bot ) )
            bot thread spawn_test_bot();

        wait 1;
    }
}

spawn_test_bot()
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
