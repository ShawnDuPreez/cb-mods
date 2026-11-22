// Test helper for bot-test.sh. Not part of the mod: never install it for normal play.
// Adds bots (dvar mpdbg_bots), prints who got which slot, character and spawn, and with
// mpdbg_tests 1 exercises revive bars, the arcade teleport, and leave/rejoin.
// mpdbg_tests 2 instead exercises the wonder weapons in the Magic Wheel.
init()
{
    level thread mp_debug_report();
    level thread mp_debug_bots();
    level thread mp_debug_tests();
    level thread mp_debug_wheel_tests();
}

mp_debug_bots()
{
    level endon( "game_ended" );
    wait 12;
    count = getdvarint( "mpdbg_bots", 0 );

    for ( i = 0; i < count; i++ )
    {
        bot = addbot( "", 0, 0, 0 );

        if ( !isdefined( bot ) )
        {
            print( "[mpdbg] addbot " + i + " failed" );
            wait 1;
            continue;
        }

        print( "[mpdbg] addbot " + i + " -> slot " + bot getentitynumber() );
        bot thread mp_debug_spawn_bot( i );
        wait 1;
    }
}

mp_debug_spawn_bot( i )
{
    self endon( "disconnect" );
    waited = 0;

    while ( !self canspawntestclient() )
    {
        wait 0.05;
        waited += 0.05;

        if ( waited > 20 )
        {
            print( "[mpdbg] bot " + i + " never became spawnable" );
            return;
        }
    }

    wait 0.5;
    self spawntestclient();
    print( "[mpdbg] bot " + i + " spawntestclient done, slot " + self getentitynumber() );
}

mp_debug_report()
{
    level endon( "game_ended" );

    for ( i = 1; i <= 200; i++ )
    {
        wait 5;
        print( "[mpdbg] t=" + ( i * 5 ) + " players=" + level.players.size + " maxclients=" + getmaxclients() + " pool=" + level.available_player_characters.size );

        foreach ( player in level.players )
        {
            num = "none";

            if ( isdefined( player.player_character_num ) )
                num = player.player_character_num;

            idx = "none";

            if ( isdefined( player.player_character_index ) )
                idx = player.player_character_index;

            vo = "none";

            if ( isdefined( player.vo_prefix ) )
                vo = player.vo_prefix;

            bits = "no";

            if ( isdefined( player.bit_position ) )
                bits = "yes";

            print( "[mpdbg]   slot " + player getentitynumber() + " char " + num + " portrait " + idx + " hudbits " + bits + " vo " + vo + " model " + player.model + " state " + player.sessionstate + " origin " + player.origin );
        }
    }
}

mp_debug_dump( label )
{
    print( "[mpdbg] " + label + " players=" + level.players.size + " pool=" + level.available_player_characters.size );

    foreach ( player in level.players )
    {
        num = "none";

        if ( isdefined( player.player_character_num ) )
            num = player.player_character_num;

        bar = "none";

        if ( isdefined( player.revive_progress_bar_id ) )
            bar = player.revive_progress_bar_id;

        print( "[mpdbg]   slot " + player getentitynumber() + " char " + num + " bar " + bar + " threat '" + player getthreatbiasgroup() + "' origin " + player.origin );
    }
}

mp_debug_by_slot( slot )
{
    foreach ( player in level.players )
    {
        if ( player getentitynumber() == slot )
            return player;
    }

    return undefined;
}

mp_debug_tests()
{
    level endon( "game_ended" );
    wait 40;

    if ( getdvarint( "mpdbg_tests", 0 ) != 1 )
        return;

    mp_debug_dump( "TEST start" );

    if ( level.players.size < 7 )
    {
        print( "[mpdbg] TEST skipped, not enough players" );
        print( "[mpdbg] DONE" );
        return;
    }

    a = mp_debug_by_slot( 0 );
    b = mp_debug_by_slot( 1 );
    c = mp_debug_by_slot( 2 );
    x = mp_debug_by_slot( 4 );
    y = mp_debug_by_slot( 5 );
    z = mp_debug_by_slot( 6 );

    // three revives at once: stock errors on the third
    scripts\cp\cp_laststand::enable_on_world_progress_bar_for_other_players( a, x );
    scripts\cp\cp_laststand::enable_on_world_progress_bar_for_other_players( b, y );
    scripts\cp\cp_laststand::enable_on_world_progress_bar_for_other_players( c, z );
    scripts\cp\cp_laststand::update_players_revive_progress_bar( a, x, 0.5 );
    scripts\cp\cp_laststand::update_players_revive_progress_bar( c, z, 0.5 );
    mp_debug_dump( "TEST revive bars on (expect bar 1, 2, none)" );
    scripts\cp\cp_laststand::disable_on_world_progress_bar_for_other_players( c, z );
    scripts\cp\cp_laststand::disable_on_world_progress_bar_for_other_players( a, x );
    scripts\cp\cp_laststand::disable_on_world_progress_bar_for_other_players( b, y );
    mp_debug_dump( "TEST revive bars off (expect none)" );

    // arcade console teleport for a high slot
    before = z.origin;
    scripts\cp\maps\cp_zmb\cp_zmb_ghost_wave::teleport_into_arcade_console( z );
    print( "[mpdbg] TEST teleport in: slot 6 from " + before + " to " + z.origin );
    scripts\cp\maps\cp_zmb\cp_zmb_ghost_wave::teleport_out_of_arcade_console( z );
    print( "[mpdbg] TEST teleport out: slot 6 now " + z.origin );
    z setorigin( before );

    // leave and rejoin
    kick( 7 );
    wait 3;
    mp_debug_dump( "TEST after kick slot 7" );
    kick( 3 );
    wait 3;
    mp_debug_dump( "TEST after kick slot 3" );
    bot = addbot( "", 0, 0, 0 );

    if ( isdefined( bot ) )
        bot thread mp_debug_spawn_bot( 99 );

    wait 8;
    mp_debug_dump( "TEST after one rejoin" );
    print( "[mpdbg] DONE" );
}

mp_debug_nav()
{
    level endon( "game_ended" );
    wait 8;
    points = scripts\engine\utility::getstructarray( "default_player_start", "targetname" );
    print( "[mpdbg] NAV start points: " + points.size );

    foreach ( index, point in points )
    {
        snapped = getclosestpointonnavmesh( point.origin );
        print( "[mpdbg] NAV point " + index + " origin " + point.origin + " angles " + point.angles + " snapped " + snapped + " moved " + distance( point.origin, snapped ) );

        for ( step = 0; step < 8; step++ )
        {
            want = point.origin + anglestoforward( ( 0, point.angles[1] + step * 45, 0 ) ) * 56;
            got = getclosestpointonnavmesh( want );
            print( "[mpdbg] NAV   dir " + ( step * 45 ) + " want " + want + " got " + got + " off " + distance2d( want, got ) + " dz " + ( got[2] - point.origin[2] ) );
        }
    }
}

// ---------------------------------------------------------------------------
// mpdbg_tests 2: wonder weapons in the Magic Wheel
// ---------------------------------------------------------------------------

mp_debug_wheel_names()
{
    switch ( getdvar( "ui_mapname" ) )
    {
        case "cp_zmb":
            return [ "dischord", "facemelter", "headcutter", "shredder" ];
        case "cp_rave":
            return [ "acidrain", "benfranklin", "trapomatic", "whirlwind" ];
        default:
            return [ "nunchucks", "cutie", "venomx", "dischord", "acidrain" ];
    }
}

mp_debug_wheel_dump( label )
{
    text = "";

    foreach ( name in mp_debug_wheel_names() )
    {
        if ( isdefined( level.magic_weapons[name] ) )
            text += name + "=" + level.magic_weapons[name] + " ";
    }

    sizes = "";

    foreach ( wheel in level._id_B163 )
        sizes += wheel._id_13C25.size + " ";

    print( "[mpdbg] TEST wheel " + label + ": players=" + level.players.size + " wheel weapons=" + level.magic_weapons.size + " (per wheel: " + sizes + ") wonder weapons in it: " + text );
}

mp_debug_holds( player, part )
{
    text = "";

    foreach ( weapon in player getweaponslistall() )
    {
        if ( issubstr( weapon, part ) )
            text += weapon + " ";
    }

    if ( text == "" )
        return "nothing";

    return text;
}

mp_debug_wheel_tests()
{
    level endon( "game_ended" );
    wait 40;

    if ( getdvarint( "mpdbg_tests", 0 ) != 2 )
        return;

    map = getdvar( "ui_mapname" );
    mp_debug_wheel_dump( "start (expect none)" );

    if ( map != "cp_zmb" && map != "cp_rave" )
    {
        print( "[mpdbg] TEST wheel: the mod adds nothing on this map" );
        wait 5;
        mp_debug_wheel_dump( "after 5 s (expect the same)" );
        print( "[mpdbg] DONE" );
        return;
    }

    holder = mp_debug_by_slot( 2 );
    spinner = mp_debug_by_slot( 3 );

    if ( map == "cp_zmb" )
    {
        // built the Spaceland way: three parts on the stand
        level.wor_items_placed["iw7_dischord_zm"]["toy"] = 1;
        level.wor_items_placed["iw7_dischord_zm"]["battery"] = 1;
        wait 2.5;
        mp_debug_wheel_dump( "two of three dischord parts placed (expect none)" );
        level.wor_items_placed["iw7_dischord_zm"]["crystal"] = 1;
        wait 2.5;
        mp_debug_wheel_dump( "all three dischord parts placed (expect dischord)" );
        held_weapon = "iw7_facemelter_zm";
        held_part = "facemelter";
        spin_weapon = "iw7_dischord_zm";
        spin_part = "dischord";
    }
    else
    {
        held_weapon = "iw7_harpoon2_zm";
        held_part = "harpoon2";
        spin_weapon = "iw7_harpoon2_zm";
        spin_part = "harpoon2";
    }

    // built the other way: a player holds it
    holder scripts\cp\utility::_giveweapon( held_weapon, undefined, undefined, 0 );
    wait 2.5;
    mp_debug_wheel_dump( "slot 2 holds " + held_weapon + " (expect it added)" );

    // A real spin by slot 3. The wheel's list is narrowed to the one weapon so
    // the result is known; the boss-fight flag makes the spin free and stops
    // the wheel from moving away.
    wheel = level.current_active_wheel;

    if ( isdefined( wheel ) && isdefined( spinner ) )
    {
        only = [];

        for ( i = 0; i < 8; i++ )
            only[i] = spin_weapon;

        wheel._id_13C25 = only;
        level.meph_fight_started = 1;
        wheel notify( "trigger", spinner );
        wait 8;
        shown = "nothing";

        if ( isdefined( wheel.weapon ) && isdefined( wheel.weapon._id_8293 ) )
            shown = wheel.weapon._id_8293;

        print( "[mpdbg] TEST wheel spin by slot 3: wheel shows " + shown + " (expect " + spin_weapon + ")" );

        if ( isdefined( wheel.weapon ) )
            wheel.weapon notify( "trigger", spinner );

        wait 2;
        print( "[mpdbg] TEST wheel spin by slot 3: after taking it the player holds " + mp_debug_holds( spinner, spin_part ) + " (expect " + spin_weapon + ")" );
        level.meph_fight_started = undefined;
        wait 3;

        // The wheel must not offer it to someone who already holds it.
        offered = 0;
        owned = spinner getweaponslistall();

        foreach ( entry in level.magic_weapons )
        {
            if ( !issubstr( entry, spin_part ) )
                continue;

            base = scripts\cp\utility::getbaseweaponname( entry );
            has = 0;

            foreach ( weapon in owned )
            {
                if ( issubstr( scripts\cp\utility::getbaseweaponname( weapon ), base ) )
                    has = 1;
            }

            if ( !has )
                offered = 1;
        }

        print( "[mpdbg] TEST wheel: would the wheel's own filter still offer " + spin_part + " to slot 3: " + offered + " (expect 0)" );
    }
    else
        print( "[mpdbg] TEST wheel spin skipped: no active wheel or no slot 3" );

    // down to 4 players, then back to 5
    kick( 7 );
    kick( 6 );
    kick( 5 );
    wait 3;
    mp_debug_wheel_dump( "5 players left (expect still added)" );
    kick( 4 );
    wait 3;
    mp_debug_wheel_dump( "4 players left (expect none)" );
    bot = addbot( "", 0, 0, 0 );

    if ( isdefined( bot ) )
        bot thread mp_debug_spawn_bot( 99 );

    wait 8;
    mp_debug_wheel_dump( "5 players again (expect them back)" );
    setdvar( "more_players_wheel_wonder_weapons", 0 );
    wait 2.5;
    mp_debug_wheel_dump( "switched off by dvar (expect none)" );
    print( "[mpdbg] DONE" );
}
