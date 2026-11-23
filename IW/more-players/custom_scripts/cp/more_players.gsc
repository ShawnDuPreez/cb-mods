// More Players - Infinite Warfare zombies with more than 4 players.
//
// A custom script for the iw7-mod client, run by the host. The player cap is
// the party_maxplayers dvar; ui_scripts/MorePlayers makes that 8 in zombies
// lobbies. This script patches the places in the stock zombies scripts that
// only work for 4 players:
//
//   1. characters    - the pool holds 4 characters; player 5 got none
//   2. start spawns  - picked by client slot from 4 points; slot 5+ got none
//   3. HUD portraits - 4 portrait slots, written by client slot
//   4. revive bars   - 2 world progress bars; a 3rd revive at once errored
//   5. threat groups - only "player1".."player4" exist
//   6. arcade console teleports (Ghosts 'n Skulls) - picked by client slot
//   7. Spaceland team doors - donation counters unset above 4 players
//   9. end-of-game stats - a table with 4 rows, written by client slot; for
//      slots 5 to 7 every money change errored halfway, so buys failed, and
//      slot 4 wrote over player 1's row
//  10. Rave in the Redwoods - challenge stations and boat seats and exits,
//      picked by client slot from 4
//  11. Spaceland roller coaster - exits picked by client slot from 4, and
//      score displays for 4 players
//  12. Director's Cut straight-to-boss start - picked by client slot
//
//  13. interaction triggers - buying, doors, perks, windows, everything used
//      with the use button goes through one map trigger per player, and each
//      map has 4; players 5 and up got none
//
// And one addition for games with more than 4 players:
//
//   8. wonder weapons - on Spaceland and Rave each one exists once, so built
//      ones are added to the Magic Wheel while more than 4 players are in
//
// And one check at the start of every match:
//
//   0. player slots - a match that started with fewer than 8 says so to the
//      host and in the log
//
// replacefunc() swaps a stock function for ours. The original can not be
// called afterwards, so every stub below is a full re-implementation.
//
// Only names that exist in the stock scripts are used on stock objects.
// Keep it that way: a misspelt stock field compiles fine and reads undefined.

main()
{
    replacefunc( scripts\cp\zombies\zombies_loadout::get_player_character_num, ::get_player_character_num_stub );
    replacefunc( scripts\cp\zombies\zombies_loadout::release_character_number, ::release_character_number_stub );
    replacefunc( scripts\cp\zombies\zombies_loadout::setplayerinside, ::setplayerinside_stub );
    replacefunc( scripts\cp\cp_globallogic::getassignedspawnpoint, ::getassignedspawnpoint_stub );
    replacefunc( scripts\cp\gametypes\zombie::add_player_to_threatbias_group, ::add_player_to_threatbias_group_stub );
    replacefunc( scripts\cp\cp_laststand::enable_on_world_progress_bar_for_other_players, ::enable_revive_bar_stub );
    replacefunc( scripts\cp\cp_laststand::disable_on_world_progress_bar_for_other_players, ::disable_revive_bar_stub );
    replacefunc( scripts\cp\cp_laststand::update_players_revive_progress_bar, ::update_revive_bar_stub );
    replacefunc( scripts\cp\maps\cp_zmb\cp_zmb_ghost_wave::teleport_into_arcade_console, ::teleport_into_arcade_console_stub );
    replacefunc( scripts\cp\maps\cp_zmb\cp_zmb_ghost_wave::teleport_out_of_arcade_console, ::teleport_out_of_arcade_console_stub );
    replacefunc( scripts\cp\cp_persistence::eog_player_tracking_init, ::eog_player_tracking_init_stub );
    replacefunc( scripts\cp\cp_persistence::eog_player_update_stat, ::eog_player_update_stat_stub );
    replacefunc( scripts\cp\cp_persistence::setcoopplayerdata_for_everyone, ::setcoopplayerdata_for_everyone_stub );
    replacefunc( scripts\cp\zombies\direct_boss_fight::get_direct_to_boss_spawn_point, ::get_direct_to_boss_spawn_point_stub );
    replacefunc( scripts\cp\cp_interaction::get_player_interaction_trigger, ::get_player_interaction_trigger_stub );

    // Functions in one map's own scripts are looked up by name while that map
    // is running: a direct reference to a script the map has not loaded stops
    // the server at "Loaded custom gsc" (seen with the coaster on Rave).
    mapname = getdvar( "mapname" );

    if ( mapname == "cp_rave" )
    {
        replace_map_function( "scripts/cp/maps/cp_rave/cp_rave_challenges", "get_client_challenge_station", ::get_client_challenge_station_stub );
        replace_map_function( "scripts/cp/maps/cp_rave/cp_rave_challenges", "challenge_station_visibility_monitor", ::challenge_station_visibility_monitor_stub );
        replace_map_function( "scripts/cp/maps/cp_rave/cp_rave_boat", "link_player_to_boat", ::link_player_to_boat_stub );
        replace_map_function( "scripts/cp/maps/cp_rave/cp_rave_boat", "drop_off_player", ::drop_off_player_stub );
        replace_map_function( "scripts/cp/maps/cp_rave/cp_rave_boat", "boat_last_stand_monitor", ::boat_last_stand_monitor_stub );
        replace_map_function( "scripts/cp/maps/cp_rave/cp_rave_boat", "move_player_to_shore", ::move_player_to_shore_stub );
    }

    if ( mapname == "cp_zmb" )
    {
        replace_map_function( "scripts/cp/maps/cp_zmb/cp_zmb_coaster", "turn_on_coaster_anims", ::turn_on_coaster_anims_stub );
        replace_map_function( "scripts/cp/maps/cp_zmb/cp_zmb_coaster", "coaster_last_stand_monitor", ::coaster_last_stand_monitor_stub );
        replace_map_function( "scripts/cp/maps/cp_zmb/cp_zmb_coaster", "unlink_players_from_coaster", ::unlink_players_from_coaster_stub );
        replace_map_function( "scripts/cp/maps/cp_zmb/cp_zmb_coaster", "target_wait_for_damage", ::target_wait_for_damage_stub );
    }
}

// replacefunc for a function found by name; logs it when there is none.
replace_map_function( file, name, with )
{
    func = getfunction( file, name );

    if ( isdefined( func ) )
        replacefunc( func, with );
    else
        print( "More Players: " + file + "::" + name + " not found, not replaced" );
}

init()
{
    level thread check_player_slots();
    level thread send_extra_portraits();
    level thread wheel_wonder_weapons();

    if ( getdvar( "ui_mapname" ) == "cp_zmb" )
        level thread fix_team_door_donations();
}

// ---------------------------------------------------------------------------
// 0. Player slots
// ---------------------------------------------------------------------------

// How many players a match holds is settled the moment it starts: the game
// takes the host's lobby size (party_maxplayers) then, and nothing can add a
// slot while the match runs. A player who joins a full match is turned away
// with "Server is full." The menu scripts make the lobby size 8. A match that
// started before they were loaded has the game's own 4, which is what happens
// in the first match after picking the mod on a PC without the menu scripts
// in iw7-mod/ui_scripts (README.md, "As a mod you pick in the game").
//
// This can not repair such a match. It writes the slot count to the log in
// every match, and when there are fewer than 8 it tells the host, three
// times, how to get 8. One slot is a Solo match and is left alone.
check_player_slots()
{
    level endon( "game_ended" );

    slots = getmaxclients();
    print( "More Players: this match has " + slots + " player slots" );

    if ( slots <= 1 || slots >= 8 )
        return;

    print( "More Players: fewer than 8, because the lobby size was not 8 when the match started. With " + slots + " players in, the next one to join gets Server is full." );
    print( "More Players: for 8, end the match, go back to the Zombies menu and host the Custom Game again." );

    shown = 0;

    // The first one comes 20 seconds in, when the host is past the loading
    // screen. A dedicated server has no host player: give up after 5 minutes.
    for ( tries = 0; tries < 15 && shown < 3; tries++ )
    {
        wait 20;

        foreach ( player in level.players )
        {
            if ( isbot( player ) || !player ishost() )
                continue;

            player iprintlnbold( "More Players: this match has " + slots + " player slots, not 8." );
            player iprintlnbold( "For 8, go back to the Zombies menu and host again." );
            shown++;
            break;
        }
    }
}

// ---------------------------------------------------------------------------
// 1. Characters
// ---------------------------------------------------------------------------

// self = player. Stock: random pick from level.available_player_characters,
// which is empty once four players have joined.
get_player_character_num_stub()
{
    if ( isdefined( self.player_character_num ) )
        return self.player_character_num;

    num = get_selected_guest_character();

    if ( !isdefined( num ) )
    {
        if ( level.available_player_characters.size > 0 )
            num = scripts\engine\utility::random( level.available_player_characters );
        else
            num = pick_extra_character();
    }

    level.available_player_characters = scripts\engine\utility::array_remove( level.available_player_characters, num );
    self.player_character_num = num;
    return num;
}

// Stock behaviour, unchanged: a player who picked the map's guest star in the
// menu gets it, and the pick is used up.
get_selected_guest_character()
{
    num = undefined;

    switch ( getdvar( "ui_mapname" ) )
    {
        case "cp_zmb":
            selected = self getrankedplayerdata( "cp", "zombiePlayerLoadout", "characterSelect" );

            if ( selected == 1 )
                num = 5;
            else if ( selected == 5 )
                num = 6;

            break;
        case "cp_rave":
            if ( self getrankedplayerdata( "cp", "zombiePlayerLoadout", "characterSelect" ) == 2 )
                num = 5;

            break;
        case "cp_disco":
            if ( self getrankedplayerdata( "cp", "zombiePlayerLoadout", "characterSelect" ) == 3 )
                num = 5;

            break;
        case "cp_town":
            if ( self getrankedplayerdata( "cp", "zombiePlayerLoadout", "characterSelect" ) == 4 )
                num = 5;

            break;
        default:
            break;
    }

    if ( !isdefined( num ) )
        return undefined;

    if ( !isdefined( level.player_character_info[num] ) )
        return undefined;

    self setplayerdata( "cp", "zombiePlayerLoadout", "characterSelect", 0 );
    return num;
}

// The pool is empty: give this player the character the fewest connected
// players are using. Guest stars (5 and 6) count as candidates unless
// more_players_guest_stars is 0, so they are handed out before duplicates.
pick_extra_character()
{
    use_guests = getdvarint( "more_players_guest_stars", 1 );
    candidates = [];
    usage = [];

    foreach ( num, info in level.player_character_info )
    {
        if ( !isdefined( info ) )
            continue;

        if ( num > 4 && !use_guests )
            continue;

        candidates[candidates.size] = num;
        usage[num] = 0;
    }

    foreach ( player in level.players )
    {
        if ( player == self )
            continue;

        used = player.player_character_num;

        if ( isdefined( used ) && isdefined( usage[used] ) )
            usage[used]++;
    }

    lowest = undefined;
    best = [];

    foreach ( num in candidates )
    {
        if ( !isdefined( lowest ) || usage[num] < lowest )
        {
            lowest = usage[num];
            best = [];
        }

        if ( usage[num] == lowest )
            best[best.size] = num;
    }

    if ( best.size == 0 )
        return 1;

    // On a tie, double up one of the four main characters, not a guest star.
    mains = [];

    foreach ( num in best )
    {
        if ( num <= 4 )
            mains[mains.size] = num;
    }

    if ( mains.size > 0 )
        best = mains;

    return scripts\engine\utility::random( best );
}

// Stock: puts the leaving player's character back in the pool. With
// duplicates it must stay out while another player still uses it.
release_character_number_stub( player )
{
    num = player.player_character_num;

    if ( !isdefined( num ) )
        return;

    if ( num > 4 )
        return;

    foreach ( other in level.players )
    {
        if ( other == player )
            continue;

        if ( isdefined( other.player_character_num ) && other.player_character_num == num )
            return;
    }

    if ( !scripts\engine\utility::array_contains( level.available_player_characters, num ) )
        level.available_player_characters = scripts\engine\utility::array_add( level.available_player_characters, num );
}

// ---------------------------------------------------------------------------
// 3. HUD portraits
// ---------------------------------------------------------------------------

// The zm_player_* omnvars hold 4 portraits, 3 bits each, by client slot.
// Stock folded slot 4 onto slot 0 and gave slots above that no bit positions,
// which made every later portrait update a script error. Slots 4+ are kept
// out of the omnvars: with bit_position undefined, set_player_photo_option
// skips them. Their portraits go to the clients in a dvar instead, below.
// They still get photosetup, which the intro waits for before showing the HUD.
setplayerinside_stub( player, photo_index )
{
    player endon( "disconnect" );
    player.player_character_index = photo_index;
    slot = player getentitynumber();

    if ( slot > 3 )
    {
        player.bit_position = undefined;

        // Stock sets photosetup inside set_player_photo_option, which skips
        // a player with no bit position. The intro waits for photosetup
        // before it shows the HUD (zombie.gsc, ui_hide_hud), so without this
        // slots 4+ never got a HUD. Set it at the same moment stock would.
        wait 5.0;
        player.photosetup = 1;
        return;
    }

    player.bit_position = scripts\cp\zombies\zombies_loadout::get_bit_position( slot );
    wait 5.0;
    scripts\cp\zombies\zombies_loadout::set_player_photo_option( player, "zm_player_character", scripts\cp\zombies\zombies_loadout::get_character_bit_value( photo_index ) );
    scripts\cp\zombies\zombies_loadout::set_player_photo_status( player, "healthy" );
}

// Sends "slot:portrait slot:portrait " for every player in slot 4 and up to
// each client, where ui_scripts/MorePlayers turns it into the HUD portrait.
// Sent only when it changes, checked once a second. No health status is sent:
// those portraits always show the healthy picture.
send_extra_portraits()
{
    level endon( "game_ended" );

    for (;;)
    {
        wait 1;
        text = "";

        foreach ( player in level.players )
        {
            slot = player getentitynumber();

            if ( slot < 4 || !isdefined( player.player_character_index ) )
                continue;

            text += slot + ":" + player.player_character_index + " ";
        }

        foreach ( player in level.players )
        {
            if ( isbot( player ) )
                continue;

            // Nothing was ever sent and there is nothing to send: stay silent.
            // A client without ui_scripts/MorePlayers has no ui_cp_characters
            // dvar, and the game crashed about a second into a match when it
            // was sent one anyway.
            if ( !isdefined( player.more_players_portraits ) && text == "" )
                continue;

            if ( isdefined( player.more_players_portraits ) && player.more_players_portraits == text )
                continue;

            player.more_players_portraits = text;
            player setclientdvar( "ui_cp_characters", text );
        }
    }
}

// ---------------------------------------------------------------------------
// 2. Start spawns
// ---------------------------------------------------------------------------

// self = player. Stock: points[client slot], with slot 4 folded onto point 1.
// Slots past the last point reuse the points in order, moved off the point so
// two players do not start inside each other. The stock points can sit in a
// row closer together than the move (47 units on Spaceland), so a fixed
// direction lands on a neighbour: eight directions are tried and the one with
// the most room wins. Every candidate is snapped to the navmesh here, because
// on cp_disco the caller uses the point as-is. A candidate the snap moved to
// another floor, or put behind a wall or a players-only barrier, is dropped;
// if all are, the player starts on the stock point.
getassignedspawnpoint_stub( points )
{
    if ( !isdefined( points ) || points.size == 0 )
        return undefined;

    slot = self getentitynumber();

    if ( slot < points.size )
        return points[slot];

    base = points[slot % points.size];
    angles = ( 0, 0, 0 );

    if ( isdefined( base.angles ) )
        angles = base.angles;

    reach = 56 * int( slot / points.size );
    best = base.origin;
    best_room = -1;
    walls = scripts\common\trace::create_world_contents() + scripts\common\trace::create_playerclip_contents();
    lift = ( 0, 0, 16 );

    for ( step = 0; step < 8; step++ )
    {
        direction = anglestoforward( ( 0, angles[1] + step * 45, 0 ) );
        candidate = getclosestpointonnavmesh( base.origin + direction * reach );

        if ( abs( candidate[2] - base.origin[2] ) > 48 )
            continue;

        // The navmesh also covers rooms only zombies use, such as the ones
        // behind boarded windows. Keep a candidate only if this player could
        // walk to it from the stock point in a straight line.
        if ( !self scripts\common\trace::player_trace_passed( base.origin + lift, candidate + lift, angles, undefined, walls ) )
            continue;

        room = get_spawn_room( candidate, points );

        if ( room > best_room )
        {
            best_room = room;
            best = candidate;
        }
    }

    spot = spawnstruct();
    spot.origin = best;
    spot.angles = angles;
    return spot;
}

// Distance from origin to the nearest stock start point or spawned player.
get_spawn_room( origin, points )
{
    room = 100000;

    foreach ( point in points )
    {
        gap = distance2d( origin, point.origin );

        if ( gap < room )
            room = gap;
    }

    foreach ( player in level.players )
    {
        if ( player == self )
            continue;

        if ( !isdefined( player.hasspawned ) || !player.hasspawned )
            continue;

        gap = distance2d( origin, player.origin );

        if ( gap < room )
            room = gap;
    }

    return room;
}

// ---------------------------------------------------------------------------
// 5. Threat groups
// ---------------------------------------------------------------------------

// self = player. Only "player1".."player4" are created. Stock picked the
// group from the player's position in level.players, so the 6th player asked
// for "player6", a script error. Each player now takes the first of the four
// groups nobody else holds. When all four are taken the player gets none, and
// zombies target them by the normal rules.
add_player_to_threatbias_group_stub()
{
    for ( n = 1; n <= 4; n++ )
    {
        group = "player" + n;
        taken = 0;

        foreach ( player in level.players )
        {
            if ( player != self && player getthreatbiasgroup() == group )
            {
                taken = 1;
                break;
            }
        }

        if ( !taken )
        {
            self setthreatbiasgroup( group );
            return;
        }
    }
}

// ---------------------------------------------------------------------------
// 4. Revive bars
// ---------------------------------------------------------------------------

// Onlookers see a world progress bar over a player being revived. There are
// two bars. Stock built an omnvar name from an undefined id when a third
// revive started, which killed the revive itself. A third revive now simply
// has no bar for onlookers.
enable_revive_bar_stub( downed, reviver )
{
    id = scripts\cp\cp_laststand::add_to_players_being_revived( downed );

    if ( !isdefined( id ) )
        return;

    omnvar = "zm_revive_bar_" + id + "_target";

    foreach ( player in level.players )
    {
        if ( player == downed || player == reviver )
            continue;

        player setclientomnvar( omnvar, downed );
    }
}

disable_revive_bar_stub( downed, reviver )
{
    if ( !isdefined( downed.revive_progress_bar_id ) )
        return;

    omnvar = "zm_revive_bar_" + downed.revive_progress_bar_id + "_target";
    scripts\cp\cp_laststand::remove_from_players_being_revived( downed );

    foreach ( player in level.players )
    {
        if ( player == downed || player == reviver )
            continue;

        player setclientomnvar( omnvar, undefined );
    }
}

update_revive_bar_stub( downed, reviver, progress )
{
    foreach ( player in level.players )
    {
        if ( player == downed || player == reviver )
        {
            player setclientomnvar( "ui_securing_progress", progress );
            continue;
        }

        if ( isdefined( downed.revive_progress_bar_id ) )
            player setclientomnvar( "zm_revive_bar_" + downed.revive_progress_bar_id + "_progress", progress );
    }
}

// ---------------------------------------------------------------------------
// 6. Arcade console teleports
// ---------------------------------------------------------------------------

// Stock: structs[client slot], undefined for slots past the last struct.
teleport_into_arcade_console_stub( player )
{
    spot = get_struct_for_slot( scripts\engine\utility::getstructarray( "ghost_wave_player_start", "targetname" ), player );

    if ( !isdefined( spot ) )
        return;

    player setorigin( spot.origin );
    player setplayerangles( spot.angles );
}

teleport_out_of_arcade_console_stub( player )
{
    spot = get_struct_for_slot( scripts\engine\utility::getstructarray( "ghost_wave_player_end", "targetname" ), player );

    if ( !isdefined( spot ) )
        return;

    player setorigin( scripts\engine\utility::drop_to_ground( spot.origin, 50, -300 ) );
    player setplayerangles( spot.angles );
}

get_struct_for_slot( structs, player )
{
    if ( !isdefined( structs ) || structs.size == 0 )
        return undefined;

    return structs[player getentitynumber() % structs.size];
}

// ---------------------------------------------------------------------------
// 7. Spaceland team doors
// ---------------------------------------------------------------------------

// The door setup only sets the three donation counters for 1 to 4 players.
// Above that they stay undefined and the next player to join decrements
// undefined. Treat 5+ players like 4, which is what the donation code itself
// assumes when a counter is missing.
fix_team_door_donations()
{
    level endon( "game_ended" );

    while ( !isdefined( level.team_door_adjusted_for ) )
        wait 1;

    if ( !isdefined( level.moon_donations ) )
        level.moon_donations = -1;

    if ( !isdefined( level.kepler_donations ) )
        level.kepler_donations = -1;

    if ( !isdefined( level.triton_donations ) )
        level.triton_donations = -1;
}

// ---------------------------------------------------------------------------
// 8. Wonder weapons from the Magic Wheel
// ---------------------------------------------------------------------------

// Spaceland's four wonder weapons each sit once on a stand, and each of
// Rave's four statues upgrades one harpoon gun per match, so at most four
// players can hold one. With more than 4 players in the game, a wonder weapon
// that has been built is also put in the Magic Wheel's weapon list, which is
// what Director's Cut does for all of them from the start.
//
// The other maps need nothing: every player can already get the M.A.D.
// (Radioactive Thing), the Venom-X (Beast from Beyond) and the nunchucks and
// katana (Shaolin Shuffle) once the team has done the quest step.
//
// "Built" means: all three parts are on the weapon's stand (Spaceland), or a
// player has held the weapon in this match (both maps).
//
// The wheel never offers a weapon the spinning player already holds, so
// nobody gets a second copy of the same one. Turn this off with
// set more_players_wheel_wonder_weapons 0
wheel_wonder_weapons()
{
    level endon( "game_ended" );
    weapons = get_wheel_wonder_weapons();

    if ( weapons.size == 0 )
        return;

    built = [];
    added = [];

    for (;;)
    {
        wait 1;

        // Director's Cut has its own entries under the same names.
        if ( scripts\engine\utility::is_true( level.directors_cut_is_activated ) )
            continue;

        if ( !isdefined( level.magic_weapons ) || !isdefined( level._id_B163 ) )
            continue;

        allowed = level.players.size > 4 && getdvarint( "more_players_wheel_wonder_weapons", 1 ) != 0;
        changed = 0;

        foreach ( name, info in weapons )
        {
            if ( !isdefined( built[name] ) && wonder_weapon_is_built( info ) )
                built[name] = 1;

            wanted = allowed && isdefined( built[name] );

            if ( wanted && !isdefined( added[name] ) && !isdefined( level.magic_weapons[name] ) )
            {
                level.magic_weapons[name] = info.weapon;
                added[name] = 1;
                changed = 1;
            }
            else if ( !wanted && isdefined( added[name] ) )
            {
                level.magic_weapons[name] = undefined;
                added[name] = undefined;
                changed = 1;
            }
        }

        if ( !changed )
            continue;

        // Each wheel keeps its own shuffled copy of the list and reshuffles
        // it after every spin. A wheel that is spinning is left alone: the
        // spin reads its copy by position.
        foreach ( wheel in level._id_B163 )
        {
            if ( scripts\engine\utility::is_true( wheel.inuse ) )
                continue;

            wheel._id_13C25 = scripts\cp\zombies\interaction_magicwheel::_id_7ABF();
        }
    }
}

// Names are the ones Director's Cut uses in level.magic_weapons. "weapon" is
// what the wheel hands out, "held" is how to spot it in a player's weapons,
// "stand" is the Spaceland stand it is built on.
get_wheel_wonder_weapons()
{
    weapons = [];

    switch ( getdvar( "ui_mapname" ) )
    {
        case "cp_zmb":
            weapons["dischord"] = wonder_weapon( "iw7_dischord_zm", "dischord", "iw7_dischord_zm" );
            weapons["facemelter"] = wonder_weapon( "iw7_facemelter_zm", "facemelter", "iw7_facemelter_zm" );
            weapons["headcutter"] = wonder_weapon( "iw7_headcutter_zm", "headcutter", "iw7_headcutter_zm" );
            weapons["shredder"] = wonder_weapon( "iw7_shredder_zm", "shredder", "iw7_shredder_zm" );
            break;
        case "cp_rave":
            weapons["acidrain"] = wonder_weapon( "iw7_harpoon1_zm", "harpoon1", undefined );
            weapons["benfranklin"] = wonder_weapon( "iw7_harpoon2_zm", "harpoon2", undefined );
            weapons["trapomatic"] = wonder_weapon( "iw7_harpoon3_zm+akimbo", "harpoon3", undefined );
            weapons["whirlwind"] = wonder_weapon( "iw7_harpoon4_zm", "harpoon4", undefined );
            break;
        default:
            break;
    }

    return weapons;
}

wonder_weapon( weapon, held, stand )
{
    info = spawnstruct();
    info.weapon = weapon;
    info.held = held;
    info.stand = stand;
    return info;
}

wonder_weapon_is_built( info )
{
    if ( isdefined( info.stand ) && isdefined( level.wor_items_placed ) && isdefined( level.wor_items_placed[info.stand] ) )
    {
        placed = level.wor_items_placed[info.stand];

        if ( scripts\engine\utility::is_true( placed["toy"] ) && scripts\engine\utility::is_true( placed["battery"] ) && scripts\engine\utility::is_true( placed["crystal"] ) )
            return 1;
    }

    foreach ( player in level.players )
    {
        foreach ( weapon in player getweaponslistall() )
        {
            if ( issubstr( weapon, info.held ) )
                return 1;
        }
    }

    return 0;
}

// ---------------------------------------------------------------------------
// 9. End-of-game stats
// ---------------------------------------------------------------------------

// The end-of-game screen reads a table in every player's saved data with 4
// rows, "EoGPlayer" 0 to 3, one per client slot. Stock folds slot 4 onto row 0
// (player 1's) and uses slots 5 to 7 as rows that do not exist. Writing such a
// row is a script error, which ends the function that asked for it. Every
// money change writes the table (set_player_currency, give_player_currency,
// take_player_currency), so for slots 5 to 7 money given never arrived, and a
// buy took the money and then stopped before handing anything over. Slot 4
// wrote its money, kills and name over player 1's row.
//
// The stubs give slots 0 to 3 their rows as before. Slot 4 gets row 0 only
// while no player is in slot 0, as stock meant it. Every other slot has no
// row: its stats are kept on the player for the leaderboard part and left off
// the table. The end screen keeps listing at most 4 players, as before.

// The player's row in the table, or undefined.
eog_row( player )
{
    slot = player getentitynumber();

    if ( slot < 4 )
        return slot;

    if ( slot > 4 )
        return undefined;

    foreach ( other in level.players )
    {
        if ( other != player && other getentitynumber() == 0 )
            return undefined;
    }

    return 0;
}

eog_fields()
{
    return [ "name", "kills", "score", "assists", "revives", "drillrestarts", "drillplants", "downs", "deaths", "hivesdestroyed", "currency", "currencyspent", "currencytotal", "tickets", "ticketsspent", "tickettotal", "traps", "deployables", "deployablesused", "consumablesearned", "headShots", "connected" ];
}

// self = player. Stock: announce the new player in everyone's table and copy
// everyone else's row into the new player's table.
eog_player_tracking_init_stub()
{
    self endon( "disconnect" );
    wait 0.5;
    row = eog_row( self );

    if ( !isdefined( row ) )
        return;

    name = "unknownPlayer";

    if ( isdefined( self.name ) )
        name = self.name;

    if ( !level.console )
        name = getsubstr( name, 0, 19 );
    else if ( scripts\cp\cp_persistence::have_clan_tag( name ) )
        name = scripts\cp\cp_persistence::remove_clan_tag( name );

    for ( i = 0; i < 4; i++ )
        self setplayerdata( "cp", "EoGPlayer", i, "connected", 0 );

    foreach ( player in level.players )
    {
        player scripts\cp\cp_persistence::reset_eog_stats( row );
        player setplayerdata( "cp", "EoGPlayer", row, "connected", 1 );
        player setplayerdata( "cp", "EoGPlayer", row, "name", name );
        player setplayerdata( "common", "round", "totalXp", 0 );
        player setplayerdata( "common", "aarUnlockCount", 0 );
    }

    used = [ 0, 0, 0, 0 ];
    fields = eog_fields();

    foreach ( player in level.players )
    {
        other_row = eog_row( player );

        if ( !isdefined( other_row ) )
            continue;

        used[other_row] = 1;

        if ( player == self )
            continue;

        foreach ( field in fields )
            self setplayerdata( "cp", "EoGPlayer", other_row, field, player getrankedplayerdata( "cp", "EoGPlayer", other_row, field ) );
    }

    for ( i = 0; i < 4; i++ )
    {
        if ( !used[i] )
            scripts\cp\cp_persistence::reset_eog_stats( i );
    }
}

// self = player. Stock: add to (or with absolute set) one stat, in the
// leaderboard data and in everyone's table.
eog_player_update_stat_stub( stat, value, absolute )
{
    row = eog_row( self );
    total = value;

    if ( !isdefined( absolute ) || !absolute )
    {
        if ( isdefined( row ) )
        {
            total = int( self getrankedplayerdata( "cp", "EoGPlayer", row, stat ) ) + int( value );
        }
        else
        {
            if ( !isdefined( self.more_players_eog ) )
                self.more_players_eog = [];

            if ( !isdefined( self.more_players_eog[stat] ) )
                self.more_players_eog[stat] = 0;

            self.more_players_eog[stat] = self.more_players_eog[stat] + int( value );
            total = self.more_players_eog[stat];
        }
    }

    scripts\cp\cp_persistence::try_update_lb_playerdata( stat, total, 1 );

    if ( isdefined( row ) )
        setcoopplayerdata_for_everyone_stub( "EoGPlayer", row, stat, total );
}

// Stock writes one value into every player's saved data, skipping whoever is
// 5th in level.players. With more than 4 players that skip only left one
// player's end screen out of date, so it is gone. A table row above 3 does not
// exist (eog_update_on_player_disconnect passes the raw client slot, and a
// script error there cut a player's disconnect handling short), so those
// writes are dropped.
setcoopplayerdata_for_everyone_stub( a, b, c, d, e )
{
    if ( isdefined( a ) && a == "EoGPlayer" && isdefined( b ) && b > 3 )
        return;

    foreach ( player in level.players )
    {
        if ( isdefined( a ) && isdefined( b ) && isdefined( c ) && isdefined( d ) && isdefined( e ) )
            player setplayerdata( "cp", a, b, c, d, e );
        else if ( isdefined( a ) && isdefined( b ) && isdefined( c ) && isdefined( d ) )
            player setplayerdata( "cp", a, b, c, d );
        else if ( isdefined( a ) && isdefined( b ) && isdefined( c ) )
            player setplayerdata( "cp", a, b, c );
        else if ( isdefined( a ) && isdefined( b ) )
            player setplayerdata( "cp", a, b );
    }
}

// ---------------------------------------------------------------------------
// 10. Rave in the Redwoods: challenge stations and the boat
// ---------------------------------------------------------------------------

// Each challenge kiosk has 4 station models, one per client slot
// (script_noteworthy "0" to "3"); each player only sees their own, and its
// light shows that player's progress. Stock gave slots 4 to 7 no station: they
// saw none, and starting a challenge errored on the missing station. Here slot
// N uses station N % 4, so two players can share one. A shared station is lit
// when it would be lit for either of them.

// interaction = the kiosk's interaction struct.
get_client_challenge_station_stub( player, interaction )
{
    want = player getentitynumber() % 4;

    foreach ( station in interaction.challenge_stations )
    {
        if ( int( station.script_noteworthy ) == want )
            return station;
    }

    return undefined;
}

// self = one station model. Stock also errored when a player left during its
// 0.05 second waits; a player who is gone is skipped.
challenge_station_visibility_monitor_stub()
{
    for (;;)
    {
        lit = 0;
        players = level.players;

        foreach ( player in players )
        {
            if ( !isdefined( player ) )
                continue;

            if ( int( self.script_noteworthy ) != player getentitynumber() % 4 )
            {
                self hidefromplayer( player );
            }
            else
            {
                self showtoplayer( player );

                if ( isdefined( player.completed_challenges ) && scripts\engine\utility::array_contains( player.completed_challenges, self.interaction.script_type ) )
                    lit = 1;
                else if ( isdefined( player.current_challenge_kiosk ) && self == player.current_challenge_kiosk )
                    lit = 1;
            }

            wait 0.05;
        }

        if ( lit )
            self setscriptablepartstate( "light", "complete" );
        else
            self setscriptablepartstate( "light", "off" );

        wait 1;
    }
}

// The boat has 4 seats ("boat_player_0" to "_3", taken in boarding order) and
// each landing has 4 exit points (script_count 0 to 3, picked by client slot).
// A 5th boarder errored on the missing seat, and slots 4 to 7 errored on the
// missing exit after being unlinked, which left them stuck with the use button
// switched off. Extra boarders sit halfway between seat N % 4 and the next
// one; extra slots leave the boat at a free spot next to exit slot % 4.

// structs = the 4 exit points, script_count 0 to 3. Returns the point for
// player's slot; slots 4 to 7 get a free spot next to point slot % 4, found
// the same way as their start spawn (section 2).
rave_spot_for( structs, player )
{
    ordered = [];

    foreach ( point in structs )
    {
        if ( isdefined( point.script_count ) )
            ordered[int( point.script_count )] = point;
    }

    if ( ordered.size != structs.size || ordered.size == 0 )
        ordered = structs;

    return player getassignedspawnpoint_stub( ordered );
}

// Stock, with the seat picked by boarding order modulo 4.
link_player_to_boat_stub( player, unused, tag )
{
    count = level.boat_vehicle.linked_players.size;
    seat = scripts\engine\utility::getstruct( "boat_player_" + ( count % 4 ), "script_noteworthy" );
    seat.linked_player = player;
    spot = spawnstruct();
    spot.origin = seat.origin;
    spot.angles = seat.angles;

    if ( count > 3 )
    {
        next = scripts\engine\utility::getstruct( "boat_player_" + ( ( count + 1 ) % 4 ), "script_noteworthy" );

        if ( isdefined( next ) )
            spot.origin = ( seat.origin + next.origin ) * 0.5;
    }

    if ( isdefined( tag ) )
    {
        spot.origin = level.boat_vehicle gettagorigin( tag );
        spot.angles = level.boat_vehicle gettagangles( tag );
    }

    level.boat_vehicle.linked_players[level.boat_vehicle.linked_players.size] = player;
    player setorigin( spot.origin );
    player setplayerangles( spot.angles );
    player playerlinkto( level.boat_vehicle, undefined, 1, 45, 45, 30, 30, 0 );
    player playerlinkedoffsetenable();
    player.ignoreme = 1;

    if ( !isdefined( level.boat_vehicle.first_player ) )
        level.boat_vehicle.first_player = player;

    player setseatedanimconditional( "seat", 1 );
    player allowcrouch( 1 );
    player allowstand( 0 );
    player allowprone( 0 );
    player allowsprint( 0 );
    player.linked_to_boat = 1;
    player.disable_consumables = 1;
    player.interactions_disabled = 1;
    player.can_teleport = 0;
    player thread boat_last_stand_monitor_stub( player );
}

// Stock, with the exit picked by rave_spot_for.
drop_off_player_stub( player, targetname )
{
    player unlink();
    spot = rave_spot_for( scripts\engine\utility::getstructarray( targetname, "targetname" ), player );
    ground = getgroundposition( spot.origin, 8, 32, 32 );

    if ( !isdefined( ground ) )
        ground = spot.origin;

    player setorigin( ground + ( 0, 0, 1 ) );
    player setplayerangles( spot.angles );
    player allowstand( 1 );
    player allowprone( 1 );
    player allowcrouch( 1 );
    player allowsprint( 1 );
    player.ignoreme = 0;
    player.linked_to_boat = undefined;
    player.disable_consumables = undefined;
    player.interactions_disabled = undefined;
    player setseatedanimconditional( "seat", 0 );
    level.boat_vehicle.linked_players = scripts\engine\utility::array_remove( level.boat_vehicle.linked_players, player );
    player.can_teleport = 1;
    player notify( "ride_over" );
    level notify( "boatride_over" );
}

// Stock, with the exit picked by rave_spot_for.
boat_last_stand_monitor_stub( player )
{
    player endon( "ride_over" );
    player endon( "disconnect" );
    player waittill( "last_stand" );
    player unlink();
    spot = rave_spot_for( scripts\engine\utility::getstructarray( "packboat_player_exit", "targetname" ), player );
    player setorigin( spot.origin );
    player setplayerangles( spot.angles );
    player allowstand( 1 );
    player allowsprint( 1 );
    player.ignoreme = 0;
    player.linked_to_boat = undefined;
    player.disable_consumables = undefined;
    player.interactions_disabled = undefined;
    level.boat_vehicle.linked_players = scripts\engine\utility::array_remove( level.boat_vehicle.linked_players, player );
    player.ignoreme = 0;
    player.can_teleport = 1;
    player notify( "ride_over" );
}

// Stock, with the landing spot picked by rave_spot_for.
move_player_to_shore_stub( player, targetname )
{
    player unlink();
    spot = rave_spot_for( scripts\engine\utility::getstructarray( targetname, "targetname" ), player );
    player setorigin( spot.origin );
    player setplayerangles( spot.angles );
    player allowstand( 1 );
    player allowprone( 1 );
    player allowsprint( 1 );
    player.linked_to_boat = undefined;
    player.disable_consumables = undefined;
    player.interactions_disabled = undefined;
    player setseatedanimconditional( "seat", 0 );
    level.boat_vehicle.linked_players = scripts\engine\utility::array_remove( level.boat_vehicle.linked_players, player );
    player.can_teleport = 1;
    player.ignoreme = 0;
    player notify( "ride_over" );
}

// ---------------------------------------------------------------------------
// 11. Spaceland roller coaster
// ---------------------------------------------------------------------------

// Riders leave at "coaster_exit0" to "coaster_exit3", picked by client slot,
// and the high score display has 4 places, "zm_coaster_hiscore_p1" to "_p4",
// also by slot. Slots 4 to 7 errored on the missing exit after being unlinked
// (stuck, with the use button switched off), and on the missing display
// whenever they hit a target. Here they leave at a free spot next to exit
// slot % 4, and their high score is kept but not displayed.

coaster_exit_spot( player )
{
    points = [];

    for ( i = 0; i < 4; i++ )
    {
        point = scripts\engine\utility::getstruct( "coaster_exit" + i, "targetname" );

        if ( isdefined( point ) )
            points[points.size] = point;
    }

    return player getassignedspawnpoint_stub( points );
}

// Stock, with the score displays limited to the 4 that exist.
turn_on_coaster_anims_stub()
{
    monsters = getentarray( "coaster_ice_monster", "targetname" );

    foreach ( monster in monsters )
    {
        if ( monster.script_noteworthy == "idle" )
        {
            monster setscriptablepartstate( "main", scripts\engine\utility::random( [ "idle1", "idle2" ] ) );
            continue;
        }

        if ( monster.script_noteworthy == "stoke" )
        {
            monster setscriptablepartstate( "main", "stoke" );
            continue;
        }

        if ( monster.script_noteworthy == "scare" )
        {
            monster setscriptablepartstate( "main", "scare1" );
            continue;
        }

        if ( monster.script_noteworthy == "sit" )
            monster setscriptablepartstate( "main", "sit" );
    }

    foreach ( index, player in level.players )
    {
        if ( index < 4 )
            setomnvar( "zm_coaster_hiscore_p" + ( index + 1 ), 0 );

        player.coaster_hi_score = 0;
        slot = player getentitynumber();

        if ( slot < 4 )
            setomnvar( "zm_coaster_pic_p" + int( slot + 1 ), player.player_character_num );
    }
}

// Stock, with the exit from coaster_exit_spot.
coaster_last_stand_monitor_stub( player )
{
    player endon( "ride_over" );
    player endon( "disconnect" );
    player waittill( "last_stand" );
    player stoplocalsound( "scn_rollercoaster_plr_lr_01" );
    player stoplocalsound( "scn_rollercoaster_plr_lsrs_01" );
    player stoplocalsound( "scn_rollercoaster_plr_lr_02" );
    player stoplocalsound( "scn_rollercoaster_plr_lsrs_02" );
    player stoplocalsound( "scn_rollercoaster_plr_lr_03" );
    player stoplocalsound( "scn_rollercoaster_plr_lsrs_03" );
    player thread scripts\cp\cp_vo::try_to_play_vo( "laststand_coaster", "zmb_comment_vo" );
    player unlink();
    scripts\cp\zombies\zombies_spawning::decrease_reserved_spawn_slots( 4 );
    spot = coaster_exit_spot( player );
    player setorigin( spot.origin );
    player setplayerangles( spot.angles );
    player allowstand( 1 );
    player allowprone( 1 );
    player allowsprint( 1 );
    player.linked_to_coaster = undefined;
    player.disable_consumables = undefined;

    if ( !player scripts\cp\utility::areinteractionsenabled() )
        player scripts\cp\utility::allow_player_interactions( 1 );

    player.linked_coaster.linked_players--;

    if ( player.linked_coaster.linked_players <= 0 )
        player.linked_coaster.linked_players = undefined;

    player.linked_coaster = undefined;
    player scripts\cp\powers\coop_powers::power_enablepower();
    player scripts\engine\utility::allow_weapon_switch( 1 );

    if ( !player scripts\engine\utility::isusabilityallowed() )
        player scripts\engine\utility::allow_usability( 1 );

    player setclientomnvar( "zombie_coaster_ticket_earned", -1 );
    player setclientomnvar( "zombie_arcade_game_time", -1 );

    if ( player scripts\cp\utility::isignoremeenabled() )
        player scripts\cp\utility::allow_player_ignore_me( 0 );

    if ( !player scripts\cp\utility::isteleportenabled() )
        player scripts\cp\utility::allow_player_teleport( 1 );

    tally = getfunction( "scripts/cp/maps/cp_zmb/cp_zmb_coaster", "show_score_tally" );

    if ( isdefined( tally ) )
        player thread [[ tally ]]();
    player notify( "ride_over" );
}

// Stock, with the exits from coaster_exit_spot.
unlink_players_from_coaster_stub( coaster )
{
    foreach ( player in level.players )
    {
        if ( !isdefined( player.linked_to_coaster ) )
            continue;

        if ( !isdefined( player.linked_coaster ) || player.linked_coaster != coaster )
            continue;

        spot = coaster_exit_spot( player );
        player setorigin( spot.origin );
        player setplayerangles( spot.angles );
        player unlink();
        player allowstand( 1 );
        player allowprone( 1 );
        player allowsprint( 1 );
        player.linked_to_coaster = undefined;
        player.disable_consumables = undefined;

        if ( !player scripts\cp\utility::areinteractionsenabled() )
            player scripts\cp\utility::allow_player_interactions( 1 );

        player.linked_coaster = undefined;
        player setstance( "stand" );
        player scripts\cp\powers\coop_powers::power_enablepower();
        player scripts\engine\utility::allow_weapon_switch( 1 );

        if ( !player scripts\engine\utility::isusabilityallowed() )
            player scripts\engine\utility::allow_usability( 1 );

        player takeweapon( "iw7_zm1coaster_zm" );
        player scripts\cp\zombies\arcade_game_utility::give_player_back_weapon( player );
        player setclientomnvar( "zombie_coaster_ticket_earned", -1 );
        player setclientomnvar( "zombie_arcade_game_time", -1 );

        if ( player scripts\cp\utility::isignoremeenabled() )
            player scripts\cp\utility::allow_player_ignore_me( 0 );

        if ( !player scripts\cp\utility::isteleportenabled() )
            player scripts\cp\utility::allow_player_teleport( 1 );

        player notify( "ride_over" );
    }

    coaster.linked_players = undefined;
}

// self = one coaster target. Stock, with the high score display skipped for
// slots that have none.
target_wait_for_damage_stub()
{
    self endon( "death" );

    if ( isdefined( self.struct.script_delay ) )
        wait( self.struct.script_delay );

    self playsound( "rollercoaster_sign_up" );
    self.og_angles = self.angles;
    up = scripts\engine\utility::getstruct( self.struct.target, "targetname" );
    self rotateto( up.angles, 0.25 );
    self.health = 999999;
    self setcandamage( 1 );
    tickets_per_hit = 5;

    for (;;)
    {
        self waittill( "damage", damage, attacker, damage_dir, damage_point, damage_type, damage_model, damage_tag, damage_part, damage_flags, weapon );

        if ( !isdefined( attacker ) || !isdefined( weapon ) || !isdefined( attacker.linked_to_coaster ) )
            continue;

        self.health = 999999;

        if ( weapon == "iw7_zm1coaster_zm" )
        {
            attacker setclientomnvar( "damage_feedback_kill", 1 );
            attacker setclientomnvar( "damage_feedback_notify", gettime() );
            attacker.targets_hit++;
            attacker.tickets_earned = attacker.targets_hit * tickets_per_hit;
            scripts\engine\utility::waitframe();
            attacker thread scripts\cp\cp_vo::try_to_play_vo( "coaster_ride_shot", "zmb_comment_vo", "low", 10, 0, 0, 1, 10 );
            coaster = attacker.linked_coaster;

            if ( coaster == level.roller_coasters[0] )
                setomnvar( "zm_coaster_score_p" + attacker.seat + "_c1", attacker.targets_hit );
            else
                setomnvar( "zm_coaster_score_p" + attacker.seat + "_c2", attacker.targets_hit );

            if ( !isdefined( attacker.coaster_hi_score ) )
                attacker.coaster_hi_score = 0;

            if ( attacker.targets_hit > attacker.coaster_hi_score )
            {
                slot = attacker getentitynumber();

                if ( slot < 4 )
                    setomnvar( "zm_coaster_hiscore_p" + int( slot + 1 ), attacker.targets_hit );

                attacker.coaster_hi_score = attacker.targets_hit;
            }

            attacker notify( "coaster_target_hit_notify" );
            self playsound( "rollercoaster_target_pings" );
            self rotateto( self.og_angles, 0.25 );
            return;
        }
    }
}

// ---------------------------------------------------------------------------
// 12. Director's Cut, straight to the boss
// ---------------------------------------------------------------------------

// self = player. Stock: the afterlife arcade start point at the client slot,
// undefined past the last point. Here extra slots get a free spot next to
// point slot % count, as in section 2.
get_direct_to_boss_spawn_point_stub()
{
    points = scripts\engine\utility::getstructarray( "afterlife_arcade", "targetname" );

    if ( isdefined( level.additional_afterlife_arcade_start_point ) )
        points = scripts\engine\utility::array_combine( points, level.additional_afterlife_arcade_start_point );

    return self getassignedspawnpoint_stub( points );
}

// ---------------------------------------------------------------------------
// 13. Interaction triggers
// ---------------------------------------------------------------------------

// Every interaction (buying, doors, perks, the box, rebuilding windows, ...)
// goes through one "player_use_trigger" per player: the scripts move it to
// whatever the player stands at, set its hint and wait for it to be used.
// Each map has exactly 4. Player 5 got none, so could not buy or use anything,
// and the stock loop that hands them out (assign_trigger_on_player_spawned)
// stops for good when none is free, so after that even players 1 to 4 got
// none when they respawned.
//
// When the map's 4 are taken, this hands out a usable script model instead.
// A script model takes every call the interaction scripts make on the
// trigger (hint, hint values, use field of view, per-player use, move,
// makeusable) except usetriggerrequirelookat, which is a trigger-only
// setting: that call logs an error with developer_script on and is otherwise
// skipped, and the script carries on (checked on a test server). A script
// model is always used by looking at it, like a trigger with "require look
// at" on. A map trigger can not be copied instead: two triggers with the same
// trigger model hang the map load (also checked).
get_player_interaction_trigger_stub()
{
    triggers = getentarray( "player_use_trigger", "targetname" );
    home = ( 0, 0, -10000 );

    foreach ( trigger in triggers )
    {
        if ( isdefined( trigger.realorigin ) )
            home = trigger.realorigin;

        if ( !trigger.in_use )
        {
            trigger.in_use = 1;
            trigger scripts\engine\utility::trigger_on();
            return trigger;
        }
    }

    if ( !isdefined( level.more_players_use_triggers ) )
        level.more_players_use_triggers = [];

    foreach ( trigger in level.more_players_use_triggers )
    {
        if ( !trigger.in_use )
        {
            trigger.in_use = 1;
            trigger scripts\engine\utility::trigger_on();
            return trigger;
        }
    }

    trigger = spawn( "script_model", home );
    trigger setmodel( "tag_origin" );
    trigger setcursorhint( "HINT_NOICON" );
    trigger setuserange( 100 );
    trigger makeunusable();
    trigger.in_use = 1;
    trigger.more_players_extra = 1;
    level.more_players_use_triggers[level.more_players_use_triggers.size] = trigger;
    print( "More Players: interaction trigger " + ( triggers.size + level.more_players_use_triggers.size ) + " made by script" );
    return trigger;
}
