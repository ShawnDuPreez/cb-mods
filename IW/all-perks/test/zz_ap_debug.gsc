// Test helper for bot-test.sh. Not part of the mod: never install it for normal play.
// Adds bots (dvar apdbg_bots), prints which perks every player holds, then takes one
// player through the game's own "went down, got back up" perk handling and prints again.
init()
{
    level thread ap_debug_bots();
    level thread ap_debug_run();
}

ap_debug_bots()
{
    level endon( "game_ended" );
    wait 12;
    count = getdvarint( "apdbg_bots", 0 );

    for ( i = 0; i < count; i++ )
    {
        bot = addbot( "", 0, 0, 0 );

        if ( !isdefined( bot ) )
        {
            print( "[apdbg] addbot " + i + " failed" );
            wait 1;
            continue;
        }

        bot thread ap_debug_spawn_bot( i );
        wait 1;
    }
}

ap_debug_spawn_bot( i )
{
    self endon( "disconnect" );
    waited = 0;

    while ( !self canspawntestclient() )
    {
        wait 0.05;
        waited += 0.05;

        if ( waited > 20 )
        {
            print( "[apdbg] bot " + i + " never became spawnable" );
            return;
        }
    }

    wait 0.5;
    self spawntestclient();
}

ap_debug_perks( player )
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

ap_debug_dump( label )
{
    list = "stock default";

    if ( isdefined( level.all_perk_list ) )
        list = "level.all_perk_list, " + level.all_perk_list.size + " perks";

    print( "[apdbg] " + label + " players=" + level.players.size + " map list=" + list );

    foreach ( player in level.players )
    {
        permanent = "no";

        if ( scripts\engine\utility::is_true( player.have_permanent_perks ) )
            permanent = "yes";

        down = "no";

        if ( scripts\engine\utility::is_true( player.inlaststand ) )
            down = "yes";

        print( "[apdbg]   slot " + player getentitynumber() + " permanent " + permanent + " down " + down + " maxhealth " + player.maxhealth + " perks " + ap_debug_perks( player ) );
    }
}

ap_debug_by_slot( slot )
{
    foreach ( player in level.players )
    {
        if ( player getentitynumber() == slot )
            return player;
    }

    return undefined;
}

// Bots stand still, so zombies would down them and the game would take their
// perks for that reason. Keep zombies off them.
ap_debug_keep_zombies_away()
{
    level endon( "game_ended" );

    for (;;)
    {
        if ( isdefined( level.players ) )
        {
            foreach ( player in level.players )
                player.ignoreme = 1;
        }

        wait 1;
    }
}

// apdbg_solo 1, with one bot and the server started with
// party_partyPlayerCountNum 1: the game then treats the match as one player
// alone, where Up 'N Atoms is a self revive that can be had three times.
ap_debug_solo()
{
    level endon( "game_ended" );
    level thread ap_debug_keep_zombies_away();
    wait 14;
    a = ap_debug_by_slot( 0 );

    if ( !isdefined( a ) )
    {
        print( "[apdbg] TEST solo: no player in slot 0" );
        print( "[apdbg] DONE" );
        return;
    }

    // What the game sets for a real player when they connect. Bots skip that.
    a.self_revives_purchased = 0;
    a.max_self_revive_machine_use = 3;
    wait 36;
    alone = "no";

    if ( scripts\engine\utility::is_true( level.only_one_player ) )
        alone = "yes";

    print( "[apdbg] TEST solo: game sees one player alone " + alone + " (expect yes), self revives had " + a.self_revives_purchased + " (expect 1), perks (expect all) " + ap_debug_perks( a ) );

    // Alone, a player who goes down holding Up 'N Atoms is sent to the
    // afterlife arcade and walks out through its self revive door. A bot can
    // not walk, so the door's own code is called for it.
    for ( round = 1; round <= 3; round++ )
    {
        a dodamage( a.health + 1000, a.origin );
        wait 8;
        arcade = "no";

        if ( scripts\cp\zombies\zombie_afterlife_arcade::is_in_afterlife_arcade( a ) )
            arcade = "yes";

        print( "[apdbg] TEST solo: down " + round + ": in the afterlife arcade " + arcade + " (expect yes), perks (expect 0) " + ap_debug_perks( a ) );
        a.ignoreselfrevive = 1;
        level thread scripts\cp\zombies\zombie_afterlife_arcade::use_selfrevive_door( undefined, a );
        wait 8;
        down = "no";

        if ( scripts\engine\utility::is_true( a.inlaststand ) )
            down = "yes";

        print( "[apdbg] TEST solo: back from down " + round + ": still down " + down + " (expect no), self revives had " + a.self_revives_purchased + ", perks " + ap_debug_perks( a ) );
    }

    print( "[apdbg] TEST solo: expected: back from down 1 with all perks (2 had), from down 2 with all perks (3 had), from down 3 with all but revive (3 had, the game sells no more)" );
    print( "[apdbg] DONE" );
}

ap_debug_run()
{
    level endon( "game_ended" );

    if ( getdvarint( "apdbg_solo", 0 ) )
    {
        ap_debug_solo();
        return;
    }

    level thread ap_debug_keep_zombies_away();
    wait 30;
    ap_debug_dump( "TEST early (perks may still be arriving)" );
    wait 35;
    ap_debug_dump( "TEST after start (expect every map perk on every player)" );

    // What the game does to a player's perks when they go down, and when
    // they are back up: the two stock calls, on slot 1.
    a = ap_debug_by_slot( 1 );

    if ( isdefined( a ) )
    {
        a scripts\cp\zombies\zombies_perk_machines::remove_perks_from_player();
        wait 0.5;
        print( "[apdbg] TEST slot 1 half a second after the game's perk removal (expect 0): " + ap_debug_perks( a ) );
        a [[ level.laststand_exit_gamemodespecificaction ]]( a );
        wait 4;
        print( "[apdbg] TEST slot 1 after the game's last stand exit (expect all): " + ap_debug_perks( a ) );
    }

    // One perk removed on its own, on slot 3: by a perk machine (the game's
    // own machine code, used by a player who holds the perk), and by the
    // game's "take one perk" call that Rave's Slasher uses.
    c = ap_debug_by_slot( 3 );

    if ( isdefined( c ) )
    {
        machines = scripts\engine\utility::getstructarray( "perk_machine_tough", "script_noteworthy" );

        if ( machines.size > 0 )
        {
            if ( !isdefined( c.self_revives_purchased ) )
                c.self_revives_purchased = 0;

            level thread scripts\cp\zombies\zombies_perk_machines::activate_perk_machine( machines[0], c );
            wait 0.5;
            print( "[apdbg] TEST slot 3 used the Tuff 'Nuff machine while holding it (expect all, maxhealth 200): maxhealth " + c.maxhealth + " perks " + ap_debug_perks( c ) );
        }
        else
            print( "[apdbg] TEST no Tuff 'Nuff machine found on this map" );

        c scripts\cp\zombies\zombies_perk_machines::take_zombies_perk( "perk_machine_run" );
        wait 0.5;
        print( "[apdbg] TEST slot 3 had one perk taken by the game (expect all): " + ap_debug_perks( c ) );
    }

    // A real down and revive, on slot 2.
    b = ap_debug_by_slot( 2 );

    if ( isdefined( b ) )
    {
        b dodamage( b.health + 1000, b.origin );
        wait 3;
        laststand = "no";

        if ( scripts\engine\utility::is_true( b.inlaststand ) )
            laststand = "yes";

        print( "[apdbg] TEST slot 2 damaged, in last stand " + laststand + " (expect yes), perks (expect 0): " + ap_debug_perks( b ) );
        scripts\cp\cp_laststand::instant_revive( b );
        wait 5;
        laststand = "no";

        if ( scripts\engine\utility::is_true( b.inlaststand ) )
            laststand = "yes";

        print( "[apdbg] TEST slot 2 revived, in last stand " + laststand + " (expect no), perks (expect all): " + ap_debug_perks( b ) );
    }

    // A player who joins late.
    bot = addbot( "", 0, 0, 0 );

    if ( isdefined( bot ) )
    {
        bot thread ap_debug_spawn_bot( 99 );
        wait 28;
        ap_debug_dump( "TEST after a late join (expect the new player to have every perk too)" );
    }

    print( "[apdbg] DONE" );
}
