// More Players: server script.
//
// Loaded on every zombies map through the #using in scripts/zm/gametypes/_clientids.gsc.
// It changes nothing while 4 or fewer players are in the match. Every stock
// behaviour it touches is reached through a level variable the stock scripts
// already offer, so no other stock script is replaced (the one exception,
// _zm_score.gsc, has a single added guard and is explained in the README).

#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;

#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_utility;

// No #insert, no macros with arguments, no foreach and no [] in this file on purpose:
// it then builds unchanged with the Mod Tools linker and with Atian Tools, the
// compiler build-boiii.sh and the bot tests use (tools/acts-build.sh).

#namespace zm_more_players;

// Players the mod allows. Keep in step with MAX_PLAYERS in
// ui/more_players/more_players.lua, the loop in zm_more_players.csc and the two
// values in gamedata/configs/zm/zm_default_gamesettings.cfg.
#define MORE_PLAYERS_MAX			8
// What the stock scripts were written for.
#define MORE_PLAYERS_STOCK_MAX		4
// VERSION_SHIP in scripts/shared/version.gsh.
#define MORE_PLAYERS_VERSION_SHIP	1
// World objective that marks a downed player in slot 4-7: this number plus the
// slot. Keep in step with REVIVE_OBJECTIVE_BASE in more_players.lua. The game
// has 128 objectives and hands them out from 0 up; these sit near the top.
#define MORE_PLAYERS_REVIVE_OBJECTIVE_BASE	116

// Two players closer than this (and on the same floor) count as standing in
// each other. A player is 30 units wide.
#define MORE_PLAYERS_STACKED_DIST	34
// Free room wanted around a spot before a player is moved onto it.
#define MORE_PLAYERS_CLEAR_DIST		44
// How far from the stock spawn point a replacement spot may be.
#define MORE_PLAYERS_SEARCH_MIN		40
#define MORE_PLAYERS_SEARCH_MAX		200
// Stock: players within 60 units of height are "on the same floor".
#define MORE_PLAYERS_FLOOR_HEIGHT	60
// After a failed search the two players get this long to walk apart before the
// stock "players standing in each other" damage applies to them again.
#define MORE_PLAYERS_STACK_GRACE_MS	10000

// What the stock REGISTER_SYSTEM_EX macro expands to (the misspelling is stock).
function autoexec __init__sytem__()
{
	system::register( "zm_more_players", &__init__, &__main__, undefined );
}

function __init__()
{
	// The revive countdown is one world field per player slot, and stock
	// registers slots 0-3 only (_zm_laststand.gsc). Slots 4-7 are added here
	// and, with the same name and size, in zm_more_players.csc.
	// Both sides have to know a field: one that only the server registers is a
	// mismatch, and setting one that was never registered takes the server down.
	for ( i = MORE_PLAYERS_STOCK_MAX; i < MORE_PLAYERS_MAX; i++ )
	{
		clientfield::register( "world", "laststand_update" + i, MORE_PLAYERS_VERSION_SHIP, 5, "counter" );
	}

	register_map_slot_fields();

	callback::on_connect( &on_player_connect );
	callback::on_spawned( &on_player_spawned );
}

function __main__()
{
	extend_player_name_directives();
}

// Five maps have world fields of their own per player slot, again registered
// for slots 0-3 only. Setting a field that was never registered takes the
// server down, so slots 4-7 are added with the version and size the map uses:
//   Der Eisendrache        the fuse icon           _zm_powerup_castle_tram_token.gsc
//   Gorod Krovi, Revelations, Moon   the wearable icon   zm_stalingrad_wearables.gsc,
//                                     zm_genesis_wearables.gsc, zm_moon.gsc
//   Zetsubou No Shima      the three challenge pillars and the ending portal
//                          zm_island_challenges.gsc, zm_island_portals.gsc
// zm_more_players.csc holds the client half; test/check-server-client-match.sh
// compares the two.
function private register_map_slot_fields()
{
	str_map = ToLower( GetDvarString( "mapname" ) );

	if ( str_map == "zm_castle" )
	{
		register_slot_fields( "player", "hasItem", 1, 1 );
	}
	else if ( str_map == "zm_stalingrad" )
	{
		register_slot_fields( "player", "wearableItem", 12000, 2 );
	}
	else if ( str_map == "zm_genesis" )
	{
		register_slot_fields( "player", "wearableItem", 15000, 4 );
	}
	else if ( str_map == "zm_moon" )
	{
		register_slot_fields( "player", "wearableItem", 21000, 1 );
	}
	else if ( str_map == "zm_island" )
	{
		register_slot_fields( "pillar_challenge_", "_1", 9000, GetMinBitCountForNum( 4 ) );
		register_slot_fields( "pillar_challenge_", "_2", 9000, GetMinBitCountForNum( 4 ) );
		register_slot_fields( "pillar_challenge_", "_3", 9000, GetMinBitCountForNum( 4 ) );
		register_slot_fields( "portal_state_ending_", "", 9000, 1 );
	}
}

// One world field per extra slot, named <prefix><slot><suffix>.
function private register_slot_fields( str_prefix, str_suffix, n_version, n_bits )
{
	for ( i = MORE_PLAYERS_STOCK_MAX; i < MORE_PLAYERS_MAX; i++ )
	{
		clientfield::register( "world", str_prefix + i + str_suffix, n_version, n_bits, "int" );
	}
}

// ---------------------------------------------------------------------------
// Hooks into the stock scripts
// ---------------------------------------------------------------------------

function on_player_connect()
{
	// By now the map script and zm::init() have run, so every level variable
	// they set can be wrapped. A map restart builds a new level, which is why
	// this runs for every connect and guards itself.
	install_level_hooks();

	// zm::init() turns this on. With it on, a 5th player ends the game the
	// moment anyone spawns (_zm.gsc, player_too_many_players_check).
	level.player_too_many_players_check = false;

	self thread check_gum_pack();
	self thread mark_when_down();
}

function private install_level_hooks()
{
	if ( isdefined( level.more_players_hooks_installed ) && level.more_players_hooks_installed )
	{
		return;
	}

	level.more_players_hooks_installed = true;

	level.player_too_many_players_check = false;
	level.player_too_many_players_check_func = &too_many_players_check;

	extend_player_name_directives();

	// Seconds between zombie spawns. The stock function has cases for 1 to 4
	// players and no default, so with 5 it multiplies an undefined value.
	if ( isdefined( level.func_get_zombie_spawn_delay ) )
	{
		level.more_players_stock_spawn_delay = level.func_get_zombie_spawn_delay;
	}
	level.func_get_zombie_spawn_delay = &get_zombie_spawn_delay;

	// Which character a new player gets.
	if ( isdefined( level.givecustomcharacters ) )
	{
		level.more_players_stock_give_characters = level.givecustomcharacters;
		level.givecustomcharacters = &give_custom_characters;
	}

	// The stock "players standing in each other" damage (see the grace period
	// in unstack_after_spawn). Several maps set their own check; it is kept.
	if ( isdefined( level.player_intersection_tracker_override ) )
	{
		level.more_players_stock_intersection_override = level.player_intersection_tracker_override;
	}
	level.player_intersection_tracker_override = &intersection_tracker_override;

	// How often the GobbleGum machine moves: same story as the spawn delay,
	// cases for 1 to 4 players and no default. A map with its own rule keeps it.
	if ( !isdefined( level.bgb_machine_movement_frequency_override_func ) )
	{
		level.bgb_machine_movement_frequency_override_func = &bgb_machine_movement_frequency;
	}
}

// Stock: more than 4 players (8 in Grief) freezes everyone and ends the game.
// It is switched off above; this stays behind in case a map switches it back on.
function too_many_players_check()
{
}

// "<name> is reviving you" takes its name from a table with entries for slots
// 0-3. An undefined entry would break the revive for a reviver in slot 4-7.
// The game has no strings for more slots, so the four existing ones are reused.
function private extend_player_name_directives()
{
	if ( !isdefined( level.player_name_directive ) )
	{
		return;
	}

	for ( i = MORE_PLAYERS_STOCK_MAX; i < MORE_PLAYERS_MAX; i++ )
	{
		if ( !isdefined( level.player_name_directive[ i ] ) && isdefined( level.player_name_directive[ i % MORE_PLAYERS_STOCK_MAX ] ) )
		{
			level.player_name_directive[ i ] = level.player_name_directive[ i % MORE_PLAYERS_STOCK_MAX ];
		}
	}
}

// ---------------------------------------------------------------------------
// Zombie spawn delay
// ---------------------------------------------------------------------------

function get_zombie_spawn_delay( n_round )
{
	if ( level.players.size <= MORE_PLAYERS_STOCK_MAX && isdefined( level.more_players_stock_spawn_delay ) )
	{
		return [[ level.more_players_stock_spawn_delay ]]( n_round );
	}

	// 5 or more players use the stock 4-player curve (_zm.gsc, get_zombie_spawn_delay).
	if ( n_round > 60 )
	{
		n_round = 60;
	}

	n_delay = 0.67;

	for ( i = 1; i < n_round; i++ )
	{
		n_delay *= 0.95;

		if ( n_delay <= 0.1 )
		{
			n_delay = 0.1;
			break;
		}
	}

	return n_delay;
}

// ---------------------------------------------------------------------------
// GobbleGum machine
// ---------------------------------------------------------------------------

// The stock table (_zm_bgb_machine.gsc), with 5 or more players counted as 4.
function bgb_machine_movement_frequency()
{
	switch ( level.players.size )
	{
		case 1:
			level.bgb_machine_min_uses_before_move = 1;
			level.bgb_machine_max_uses_before_move = 3;
			break;
		case 2:
			level.bgb_machine_min_uses_before_move = 1;
			level.bgb_machine_max_uses_before_move = 4;
			break;
		case 3:
			level.bgb_machine_min_uses_before_move = 3;
			level.bgb_machine_max_uses_before_move = 5;
			break;
		default:
			level.bgb_machine_min_uses_before_move = 3;
			level.bgb_machine_max_uses_before_move = 6;
			break;
	}
}

// A player's five GobbleGums are read from the engine when they connect
// (_zm_bgb.gsc: self.bgb_pack = self GetBubblegumPack()). If the engine has no
// pack for a player in slot 4-7, every entry comes back as "weapon_null" and
// the machine has nothing to hand out. Such a player gets the game's starter
// pack instead. A pack with any real gum in it is left alone, and so are
// slots 0-3, which stock already handles.
function private check_gum_pack()
{
	self endon( "disconnect" );

	if ( self GetEntityNumber() < MORE_PLAYERS_STOCK_MAX )
	{
		return;
	}

	// maps without gums never set the pack
	n_waited = 0;

	while ( !isdefined( self.bgb_pack ) )
	{
		wait 0.5;
		n_waited++;

		if ( n_waited > 40 )
		{
			return;
		}
	}

	if ( !isdefined( level.bgb ) )
	{
		return;
	}

	for ( i = 0; i < self.bgb_pack.size; i++ )
	{
		if ( isdefined( self.bgb_pack[ i ] ) && self.bgb_pack[ i ] != "weapon_null" )
		{
			return;
		}
	}

	// the five gums every profile starts with, all of the kind that is never used up
	a_starter = array( "zm_bgb_always_done_swiftly", "zm_bgb_arms_grace", "zm_bgb_coagulant", "zm_bgb_in_plain_sight", "zm_bgb_stock_option" );
	a_pack = array();

	for ( i = 0; i < a_starter.size; i++ )
	{
		if ( isdefined( level.bgb[ a_starter[ i ] ] ) )
		{
			a_pack[ a_pack.size ] = a_starter[ i ];
		}
	}

	if ( a_pack.size == 0 )
	{
		return;
	}

	self.bgb_pack = a_pack;
	self.bgb_pack_randomized = array();
}

// ---------------------------------------------------------------------------
// Revive icon
// ---------------------------------------------------------------------------

// The engine draws the revive icon above a downed player for slots 0-3 only.
// For slots 4-7 the mod's Lua draws one (more_players.lua, part 5) and needs to
// know where the player is, when they are down and how far a revive has got.
// A world objective tells it all three: it is switched on at the player's
// position while they are down, its progress value is the revive progress, the
// engine sends objectives to every client, and a HUD widget can be placed on
// one. The objective has no name, so nothing else in the game shows it.
function private mark_when_down()
{
	n_slot = self GetEntityNumber();

	if ( n_slot < MORE_PLAYERS_STOCK_MAX || n_slot >= MORE_PLAYERS_MAX )
	{
		return;
	}

	n_objective = MORE_PLAYERS_REVIVE_OBJECTIVE_BASE + n_slot;
	self thread unmark_on_disconnect( n_objective );
	self endon( "disconnect" );

	b_marked = false;
	v_marked = ( 0, 0, 0 );
	b_reviving = false;
	n_revive_start = 0;
	n_revive_ms = 3000;
	n_progress_sent = 0;

	while ( true )
	{
		b_down = self laststand::player_is_in_laststand();

		if ( b_down && !b_marked )
		{
			v_marked = self.origin;
			Objective_Add( n_objective, "active", v_marked );
			Objective_SetProgress( n_objective, 0 );
			b_marked = true;
			b_reviving = false;
			n_progress_sent = 0;
		}
		else if ( b_down && DistanceSquared( v_marked, self.origin ) > 16 )
		{
			// a downed player can still be carried along, by a lift for one
			v_marked = self.origin;
			Objective_Position( n_objective, v_marked );
		}
		else if ( !b_down && b_marked )
		{
			Objective_State( n_objective, "invisible" );
			b_marked = false;
		}

		if ( b_marked )
		{
			// How far a revive in progress has got, 0 while nobody is reviving.
			// The stock revive runs a timer on the reviver and tells nobody
			// else; the objective carries it to the clients.
			n_progress = 0;

			if ( isdefined( self.revivetrigger ) && isdefined( self.revivetrigger.beingrevived ) && self.revivetrigger.beingrevived )
			{
				if ( !b_reviving )
				{
					b_reviving = true;
					n_revive_start = GetTime();
					n_revive_ms = self get_revive_time_ms();
				}

				n_progress = ( GetTime() - n_revive_start ) / n_revive_ms;

				if ( n_progress < 0.02 )
				{
					n_progress = 0.02;
				}
				else if ( n_progress > 1 )
				{
					n_progress = 1;
				}
			}
			else
			{
				b_reviving = false;
			}

			if ( n_progress != n_progress_sent )
			{
				Objective_SetProgress( n_objective, n_progress );
				n_progress_sent = n_progress;
			}
		}

		wait 0.05;
	}
}

// How long the revive of this player takes: the stock time of whoever is
// reviving them (3 seconds, half that with Quick Revive).
function private get_revive_time_ms()
{
	a_players = GetPlayers();

	for ( i = 0; i < a_players.size; i++ )
	{
		if ( a_players[ i ] != self && a_players[ i ] zm_laststand::is_reviving( self ) )
		{
			n_seconds = a_players[ i ] zm_laststand::revive_get_revive_time( self );

			if ( isdefined( n_seconds ) && n_seconds > 0 )
			{
				return n_seconds * 1000;
			}
		}
	}

	return 3000;
}

function private unmark_on_disconnect( n_objective )
{
	self waittill( "disconnect" );
	Objective_State( n_objective, "invisible" );
}

// ---------------------------------------------------------------------------
// Characters
// ---------------------------------------------------------------------------

// Every map hands out its four characters with a function of its own, and each
// of those gives character 0 to anyone who arrives after all four are taken.
// This runs first and gives such a player the character the fewest players are
// using instead, so 8 players are two of each and not one of each plus five of
// the same. With a character still free it does nothing, so the first four
// players are picked exactly as stock picks them.
function give_custom_characters()
{
	if ( !isdefined( self.characterindex ) )
	{
		n_index = self pick_shared_character_index();

		if ( isdefined( n_index ) )
		{
			self.characterindex = n_index;
			self.more_players_shared_character = true;
		}
	}

	// The map function points two level variables at "the Richtofen player"
	// (character 2), and does so again on every spawn. A second Richtofen must
	// not take them over while the first is still in the game.
	e_rich_sq_player = level.rich_sq_player;
	e_sndradioa = level.sndradioa;

	self [[ level.more_players_stock_give_characters ]]();

	if ( isdefined( self.more_players_shared_character ) && self.more_players_shared_character )
	{
		if ( isdefined( e_rich_sq_player ) )
		{
			level.rich_sq_player = e_rich_sq_player;
		}

		if ( isdefined( e_sndradioa ) )
		{
			level.sndradioa = e_sndradioa;
		}
	}
}

// Returns undefined while any of the four characters is unused.
function private pick_shared_character_index()
{
	a_uses = array();

	for ( i = 0; i < MORE_PLAYERS_STOCK_MAX; i++ )
	{
		a_uses[ i ] = 0;
	}

	a_players = GetPlayers();

	for ( i = 0; i < a_players.size; i++ )
	{
		player = a_players[ i ];

		if ( player == self || !isdefined( player.characterindex ) )
		{
			continue;
		}

		if ( player.characterindex >= 0 && player.characterindex < MORE_PLAYERS_STOCK_MAX )
		{
			a_uses[ player.characterindex ]++;
		}
	}

	n_lowest = undefined;

	for ( i = 0; i < MORE_PLAYERS_STOCK_MAX; i++ )
	{
		if ( a_uses[ i ] == 0 )
		{
			return undefined;
		}

		if ( !isdefined( n_lowest ) || a_uses[ i ] < n_lowest )
		{
			n_lowest = a_uses[ i ];
		}
	}

	a_candidates = array();

	for ( i = 0; i < MORE_PLAYERS_STOCK_MAX; i++ )
	{
		if ( a_uses[ i ] == n_lowest )
		{
			a_candidates[ a_candidates.size ] = i;
		}
	}

	return a_candidates[ RandomInt( a_candidates.size ) ];
}

// ---------------------------------------------------------------------------
// Spawn points
// ---------------------------------------------------------------------------

// Stock picks a start point by player number and falls back to the first point
// when the map has fewer points than players (zm::getFreeSpawnPoint), and the
// respawn code falls back the same way (zm::get_valid_spawn_location). Either
// way the extra player lands inside another one, and the stock intersection
// check then downs both. So: after any spawn, a player who stands in another
// player is moved to the nearest free spot. This leaves the spawn code of the
// maps alone, including the maps that bring their own.
function on_player_spawned()
{
	self thread unstack_after_spawn();
}

function private unstack_after_spawn()
{
	self endon( "disconnect" );
	self endon( "death" );

	// Everyone who spawns this frame has been placed once this returns.
	wait 0.05;

	if ( !isdefined( self ) || !IsAlive( self ) || self.sessionstate != "playing" )
	{
		return;
	}

	// The player who just spawned is the one who moves. When several land on
	// one point in the same frame they run this one after another, each sees
	// where the earlier ones went, and the last of them keeps the point.
	if ( !self is_stacked() )
	{
		return;
	}

	v_spot = self find_free_spot( self.origin );

	if ( isdefined( v_spot ) )
	{
		self SetOrigin( v_spot );
		return;
	}

	// No room found. Give the players a moment to step apart before the stock
	// intersection damage is allowed to hit them.
	self.more_players_stack_grace_until = GetTime() + MORE_PLAYERS_STACK_GRACE_MS;
}

function private is_stacked()
{
	a_players = GetPlayers();

	for ( i = 0; i < a_players.size; i++ )
	{
		player = a_players[ i ];

		if ( player == self || player.sessionstate != "playing" )
		{
			continue;
		}

		if ( is_within_player( self.origin, player.origin, MORE_PLAYERS_STACKED_DIST ) )
		{
			return true;
		}
	}

	return false;
}

function private is_within_player( v_a, v_b, n_dist )
{
	if ( abs( v_a[ 2 ] - v_b[ 2 ] ) > MORE_PLAYERS_FLOOR_HEIGHT )
	{
		return false;
	}

	return Distance2DSquared( v_a, v_b ) < n_dist * n_dist;
}

// The closest walkable point around v_origin that is inside the play area, in
// sight of v_origin (so not behind a wall or a barrier) and clear of players.
function private find_free_spot( v_origin )
{
	s_query = PositionQuery_Source_Navigation( v_origin, MORE_PLAYERS_SEARCH_MIN, MORE_PLAYERS_SEARCH_MAX, MORE_PLAYERS_FLOOR_HEIGHT, 20 );

	if ( !isdefined( s_query ) || !isdefined( s_query.data ) )
	{
		return undefined;
	}

	// The area zombies come from is walkable too. Player volumes mark where
	// players belong; a map without any gets no such test.
	b_check_area = GetEntArray( "player_volume", "script_noteworthy" ).size > 0;
	a_players = GetPlayers();
	v_best = undefined;
	n_best_dist_sq = undefined;

	for ( i = 0; i < s_query.data.size; i++ )
	{
		v_point = s_query.data[ i ].origin;
		n_dist_sq = Distance2DSquared( v_origin, v_point );

		if ( isdefined( n_best_dist_sq ) && n_dist_sq >= n_best_dist_sq )
		{
			continue;
		}

		if ( abs( v_point[ 2 ] - v_origin[ 2 ] ) > MORE_PLAYERS_FLOOR_HEIGHT )
		{
			continue;
		}

		b_clear = true;

		for ( j = 0; j < a_players.size; j++ )
		{
			player = a_players[ j ];

			if ( player != self && player.sessionstate == "playing" && is_within_player( v_point, player.origin, MORE_PLAYERS_CLEAR_DIST ) )
			{
				b_clear = false;
				break;
			}
		}

		if ( !b_clear )
		{
			continue;
		}

		if ( PositionWouldTelefrag( v_point ) )
		{
			continue;
		}

		if ( b_check_area && !zm_utility::check_point_in_playable_area( v_point ) )
		{
			continue;
		}

		if ( !BulletTracePassed( v_origin + ( 0, 0, 40 ), v_point + ( 0, 0, 40 ), false, self ) )
		{
			continue;
		}

		v_best = v_point;
		n_best_dist_sq = n_dist_sq;
	}

	return v_best;
}

// Called by zm_utility::track_players_intersection_tracker for every pair of
// players; true means "leave this pair alone".
function intersection_tracker_override( other_player )
{
	n_time = GetTime();

	if ( isdefined( self.more_players_stack_grace_until ) && n_time < self.more_players_stack_grace_until )
	{
		return true;
	}

	if ( isdefined( other_player.more_players_stack_grace_until ) && n_time < other_player.more_players_stack_grace_until )
	{
		return true;
	}

	if ( isdefined( level.more_players_stock_intersection_override ) )
	{
		return self [[ level.more_players_stock_intersection_override ]]( other_player );
	}

	return false;
}
