// Test helper for bot-test.sh. Not part of the mod: never install it for normal play.
// Adds bots (dvar pldbg_bots), then for each limit in pldbg_limits walks one bot past
// every perk machine on the map through the game's own machine code and prints how
// many perks it ended up with. "keep" in the list means: do not touch the dvar, use
// whatever the server was started with.
init()
{
    level thread pl_debug_bots();
    level thread pl_debug_run();
}

pl_debug_bots()
{
    level endon( "game_ended" );
    wait 12;
    count = getdvarint( "pldbg_bots", 0 );

    for ( i = 0; i < count; i++ )
    {
        bot = addbot( "", 0, 0, 0 );

        if ( !isdefined( bot ) )
        {
            print( "[pldbg] addbot " + i + " failed" );
            wait 1;
            continue;
        }

        bot thread pl_debug_spawn_bot( i );
        wait 1;
    }
}

pl_debug_spawn_bot( i )
{
    self endon( "disconnect" );
    waited = 0;

    while ( !self canspawntestclient() )
    {
        wait 0.05;
        waited += 0.05;

        if ( waited > 20 )
        {
            print( "[pldbg] bot " + i + " never became spawnable" );
            return;
        }
    }

    wait 0.5;
    self spawntestclient();
}

pl_debug_perks( player )
{
    text = "";
    count = 0;

    if ( isdefined( player.zombies_perks ) )
    {
        foreach ( perk, value in player.zombies_perks )
        {
            text += getsubstr( perk, 13 ) + " ";
            count++;
        }
    }

    return count + ": " + text;
}

pl_debug_map_perks()
{
    if ( isdefined( level.all_perk_list ) )
        return level.all_perk_list;

    return [ "perk_machine_boom", "perk_machine_flash", "perk_machine_fwoosh", "perk_machine_more", "perk_machine_rat_a_tat", "perk_machine_revive", "perk_machine_run", "perk_machine_smack", "perk_machine_tough", "perk_machine_zap" ];
}

// A perk machine plays a "eat the candy" gesture and gives the perk when the
// gesture is over. A bot never finishes a gesture, so the first machine it
// used would wait forever. Taking the candy out of its hand ends the gesture.
pl_debug_finish_gestures( player )
{
    level endon( "game_ended" );
    player endon( "disconnect" );

    for (;;)
    {
        offhand = player getcurrentoffhand();

        if ( isdefined( offhand ) && issubstr( offhand, "candy" ) )
            player takeweapon( offhand );

        wait 0.05;
    }
}

pl_debug_run()
{
    level endon( "game_ended" );
    wait 40;

    player = undefined;

    foreach ( candidate in level.players )
    {
        if ( candidate getentitynumber() == 1 )
            player = candidate;
    }

    if ( !isdefined( player ) )
    {
        print( "[pldbg] TEST no player in slot 1" );
        print( "[pldbg] DONE" );
        return;
    }

    // What the game sets for a real player when they connect. Bots skip that.
    if ( !isdefined( player.self_revives_purchased ) )
        player.self_revives_purchased = 0;

    if ( !isdefined( player.max_self_revive_machine_use ) )
        player.max_self_revive_machine_use = 3;

    perks = pl_debug_map_perks();
    machines = [];
    missing = "";

    foreach ( perk in perks )
    {
        found = scripts\engine\utility::getstructarray( perk, "script_noteworthy" );

        if ( found.size == 0 )
        {
            missing += getsubstr( perk, 13 ) + " ";
            continue;
        }

        // Unpowered machines only say "requires power". Switch them on.
        found[0].powered_on = 1;
        machines[machines.size] = found[0];
    }

    level thread pl_debug_finish_gestures( player );

    print( "[pldbg] TEST map has " + perks.size + " perks, machines found for " + machines.size + ", none for: " + missing );

    foreach ( limit in strtok( getdvar( "pldbg_limits" ), " " ) )
    {
        if ( limit != "keep" )
            setdvar( "perk_limit", limit );

        // Empty the bot's hands first, through the game's own "take perk" call.
        if ( isdefined( player.zombies_perks ) )
        {
            foreach ( perk in perks )
                player scripts\cp\zombies\zombies_perk_machines::take_zombies_perk( perk );
        }

        full_text_at = "never";
        free_at = "never";

        foreach ( index, machine in machines )
        {
            before = 0;

            if ( isdefined( player.zombies_perks ) )
                before = player.zombies_perks.size;

            if ( full_text_at == "never" && scripts\cp\zombies\zombies_perk_machines::hint_string_func( machine, player ) == &"COOP_PERK_MACHINES_PERK_SLOTS_FULL" )
                full_text_at = "" + before;

            if ( free_at == "never" && !player scripts\cp\cp_interaction::can_use_perk( machine ) )
                free_at = "" + before;

            if ( machine.perk_type == "perk_machine_rat_a_tat" )
                level thread scripts\cp\zombies\zombies_perk_machines::activate_perk_machine_gesture_second( machine, player );
            else
                level thread scripts\cp\zombies\zombies_perk_machines::activate_perk_machine( machine, player );

            wait 0.5;
        }

        wait 1.5;
        print( "[pldbg] TEST perk_limit '" + getdvar( "perk_limit" ) + "' (asked: " + limit + ") -> holds " + pl_debug_perks( player ) );
        print( "[pldbg] TEST   'slots full' text first shown with " + full_text_at + " perks held, machine first refused with " + free_at );
        wait 2.5;
    }

    print( "[pldbg] DONE" );
}
