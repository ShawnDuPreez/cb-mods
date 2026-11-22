// Perk Limit - the host chooses how many perks a player may hold.
//
// A custom script for the iw7-mod client, run by the host. The number comes
// from the dvar perk_limit, which ui_scripts/PerkLimit sets from the PERK
// LIMIT control in the zombies lobby:
//
//   perk_limit 5     the game's own limit (also used when the dvar is unset)
//   perk_limit 1-12  that many perks
//   perk_limit 0     no limit
//
// The stock scripts hard-code the limit as "zombies_perks.size > 4" in each
// place a perk can be taken. replacefunc() swaps those functions for the ones
// below. A replaced function can not be called again, so each one is a full
// copy of the original with only the limit check changed.
//
// Not changed: the perk crates in the Rat King and Rhino boss fights (they
// keep the game's 5), and Director's Cut straight-to-boss mode (its own
// limit is 20).

main()
{
    replacefunc( scripts\cp\zombies\zombies_perk_machines::activate_perk_machine, ::activate_perk_machine_stub );
    replacefunc( scripts\cp\zombies\zombies_perk_machines::activate_perk_machine_gesture_second, ::activate_perk_machine_gesture_second_stub );
    replacefunc( scripts\cp\zombies\zombies_perk_machines::hint_string_func, ::hint_string_func_stub );
    replacefunc( scripts\cp\cp_interaction::can_use_perk, ::can_use_perk_stub );
    replacefunc( scripts\cp\cp_weaponpassives::trackkillsforrandomperks, ::trackkillsforrandomperks_stub );
}

init()
{
    print( "[perk_limit] perk limit this match: " + get_perk_limit_text() );
}

get_perk_limit()
{
    return getdvarint( "perk_limit", 5 );
}

get_perk_limit_text()
{
    limit = get_perk_limit();

    if ( limit <= 0 )
        return "none";

    return "" + limit;
}

// Stock: isdefined( player.zombies_perks ) && player.zombies_perks.size > 4
//
// The game lifts the limit for players it has given every perk (Director's
// Cut, the Ghosts 'n Skulls reward). It marks them with two flags and checks
// a different one in different places: the price is decided by one, the perk
// is handed over by the other, and Bang Bangs checks neither. A player with
// only one flag is charged and gets nothing. Here either flag lifts the
// limit, everywhere.
perk_slots_full( player )
{
    if ( scripts\engine\utility::is_true( player.have_gns_perk ) || scripts\engine\utility::is_true( player.have_permanent_perks ) )
        return 0;

    limit = get_perk_limit();

    if ( limit <= 0 )
        return 0;

    return isdefined( player.zombies_perks ) && player.zombies_perks.size >= limit;
}

// ---------------------------------------------------------------------------
// Perk machines
// ---------------------------------------------------------------------------

// Every perk machine except Bang Bangs.
activate_perk_machine_stub( machine, player )
{
    player endon( "disconnect" );
    tokens = [];

    if ( isdefined( machine.script_noteworthy ) )
        tokens = strtok( machine.script_noteworthy, "_" );

    if ( isdefined( machine.last_time_used ) && isdefined( machine.last_time_used[player.name] ) )
        return;

    crafted = scripts\engine\utility::is_true( tokens[0] == "crafted" );

    if ( !crafted && player scripts\cp\utility::has_zombie_perk( machine.perk_type ) )
    {
        if ( soundexists( "perk_machine_remove_perk" ) )
            player playlocalsound( "perk_machine_remove_perk" );

        if ( machine.perk_type == "perk_machine_revive" )
            player.self_revives_purchased--;

        player scripts\cp\zombies\zombies_perk_machines::take_zombies_perk( machine.perk_type );
        player scripts\cp\cp_interaction::refresh_interaction();
        return;
    }

    if ( perk_slots_full( player ) )
        return;

    if ( player scripts\cp\utility::has_zombie_perk( machine.perk_type ) )
        return;

    level thread scripts\cp\zombies\zombies_perk_machines::turn_off_interaction_for_time( machine, player, 2000 );
    level thread scripts\cp\zombies\zombies_perk_machines::play_perk_machine_purchase_sound( machine, player );
    scripts\cp\cp_vo::remove_from_nag_vo( "dj_perkstation_use_nag" );

    if ( player scripts\cp\utility::is_consumable_active( "perk_refund" ) && !crafted )
    {
        player scripts\cp\cp_persistence::give_player_currency( 1000, undefined, undefined, 1, "bonus" );
        player scripts\cp\utility::notify_used_consumable( "perk_refund" );
    }

    player scripts\cp\zombies\zombies_perk_machines::play_perk_gesture( machine.perk_type );
    player scripts\cp\zombies\zombies_perk_machines::give_zombies_perk( machine.perk_type, 1 );
}

// Bang Bangs: the perk is given before the gesture.
activate_perk_machine_gesture_second_stub( machine, player )
{
    player endon( "disconnect" );
    tokens = [];

    if ( isdefined( machine.script_noteworthy ) )
        tokens = strtok( machine.script_noteworthy, "_" );

    if ( isdefined( machine.last_time_used ) && isdefined( machine.last_time_used[player.name] ) )
        return;

    crafted = scripts\engine\utility::is_true( tokens[0] == "crafted" );

    if ( !crafted && player scripts\cp\utility::has_zombie_perk( machine.perk_type ) )
    {
        if ( soundexists( "perk_machine_remove_perk" ) )
            player playlocalsound( "perk_machine_remove_perk" );

        if ( machine.perk_type == "perk_machine_revive" )
            player.self_revives_purchased--;

        player scripts\cp\zombies\zombies_perk_machines::take_zombies_perk( machine.perk_type );
        player scripts\cp\cp_interaction::refresh_interaction();
        return;
    }

    if ( perk_slots_full( player ) )
        return;

    if ( player scripts\cp\utility::has_zombie_perk( machine.perk_type ) )
        return;

    level thread scripts\cp\zombies\zombies_perk_machines::turn_off_interaction_for_time( machine, player, 2000 );
    level thread scripts\cp\zombies\zombies_perk_machines::play_perk_machine_purchase_sound( machine, player );
    scripts\cp\cp_vo::remove_from_nag_vo( "dj_perkstation_use_nag" );

    if ( player scripts\cp\utility::is_consumable_active( "perk_refund" ) && !crafted )
    {
        player scripts\cp\cp_persistence::give_player_currency( 1000, undefined, undefined, 1, "bonus" );
        player scripts\cp\utility::notify_used_consumable( "perk_refund" );
    }

    player scripts\cp\zombies\zombies_perk_machines::give_zombies_perk( machine.perk_type, 1 );
    wait 1;
    player scripts\cp\zombies\zombies_perk_machines::play_perk_gesture( machine.perk_type );
}

// The text a player sees when looking at a perk machine. Stock counted the
// perks of "self" here; the count is taken from the player argument, which
// is the player the text is for.
hint_string_func_stub( machine, player )
{
    if ( !scripts\engine\utility::is_true( machine.powered_on ) )
    {
        if ( isdefined( level.needspowerstring ) )
            return level.needspowerstring;
        else
            return &"COOP_INTERACTIONS_REQUIRES_POWER";
    }

    if ( isdefined( machine.last_time_used ) && isdefined( machine.last_time_used[player.name] ) )
        return "";

    if ( player scripts\cp\utility::has_zombie_perk( machine.perk_type ) )
        return &"COOP_PERK_MACHINES_REMOVE_PERK";

    if ( perk_slots_full( player ) )
        return &"COOP_PERK_MACHINES_PERK_SLOTS_FULL";

    if ( machine.script_noteworthy == "perk_machine_revive" && ( scripts\cp\utility::isplayingsolo() || level.only_one_player ) )
        return &"COOP_PERK_MACHINES_SELF_REVIVE";

    return level.interaction_hintstrings[machine.script_noteworthy];
}

// self = player. Decides whether a perk machine charges its price or nothing.
can_use_perk_stub( machine )
{
    if ( scripts\cp\utility::has_zombie_perk( machine.perk_type ) )
        return 0;
    else if ( self.self_revives_purchased >= self.max_self_revive_machine_use && machine.perk_type == "perk_machine_revive" )
        return 0;
    else if ( perk_slots_full( self ) )
        return 0;

    return 1;
}

// ---------------------------------------------------------------------------
// Weapon variants that hand out a random perk every 75 kills
// ---------------------------------------------------------------------------

// Stock looped forever once the player held every perk in level.perks, which
// the game's own limit of 5 made impossible. With a higher limit it can
// happen, so the loop stops when no perk is left to give.
trackkillsforrandomperks_stub( weapon, player, victim, means, hit, extra )
{
    player endon( "disconnect" );
    player endon( "last_stand" );
    player endon( "death" );
    player.passiverandomperkskillcount++;

    if ( player.passiverandomperkskillcount >= 75 )
    {
        candidates = level.perks;
        player.passiverandomperkskillcount = 0;

        if ( !perk_slots_full( player ) )
        {
            for (;;)
            {
                if ( candidates.size == 0 )
                    break;

                perk = scripts\engine\utility::random( candidates );

                if ( !player scripts\cp\utility::has_zombie_perk( perk ) )
                {
                    player scripts\cp\zombies\zombies_perk_machines::give_zombies_perk( perk, 0 );
                    break;
                }
                else
                    candidates = scripts\engine\utility::array_remove( candidates, perk );

                scripts\engine\utility::waitframe();
            }
        }
    }
}
