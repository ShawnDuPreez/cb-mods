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
//
// And one addition for games with more than 4 players:
//
//   8. wonder weapons - on Spaceland and Rave each one exists once, so built
//      ones are added to the Magic Wheel while more than 4 players are in
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
}

init()
{
    level thread send_extra_portraits();
    level thread wheel_wonder_weapons();

    if ( getdvar( "ui_mapname" ) == "cp_zmb" )
        level thread fix_team_door_donations();
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
setplayerinside_stub( player, photo_index )
{
    player endon( "disconnect" );
    player.player_character_index = photo_index;
    slot = player getentitynumber();

    if ( slot > 3 )
    {
        player.bit_position = undefined;
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
