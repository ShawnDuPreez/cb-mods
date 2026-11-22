// Test aid, not part of the mod. Used by test/bot-test.sh on the BOIII client.
//
// Adds bots to a zombies match hosted from the menus or with devmap, writes what
// it sees to the game log (lines starting with MPDBG), and runs a fixed set of
// checks. Controlled by settings given on the game's command line:
//
//   mpdbg_bots <n>      players wanted in total, host included (0 = do nothing)
//   mpdbg_tests <0|1>   run the scripted checks (down and revive, gums)
//   mpdbg_rounds <n>    kill zombies as they spawn until this round is reached
//
// Written in the plain subset that Atian Tools compiles for BO3: no macros with
// arguments, no foreach, no [] literals.

#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_bgb;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_utility;

#namespace zz_mp_debug;

function autoexec __init__sytem__()
{
	system::register( "zz_mp_debug", &__init__, undefined, undefined );
}

function __init__()
{
	level.mpdbg_bots = GetDvarInt( "mpdbg_bots" );
	level.mpdbg_tests = GetDvarInt( "mpdbg_tests" );
	level.mpdbg_rounds = GetDvarInt( "mpdbg_rounds" );

	out( "init map=" + GetDvarString( "mapname" ) + " bots=" + level.mpdbg_bots + " tests=" + level.mpdbg_tests + " rounds=" + level.mpdbg_rounds
		+ " com_maxclients=" + GetDvarInt( "com_maxclients" ) + " party_maxplayers=" + GetDvarInt( "party_maxplayers" ) + " sv_maxclients=" + GetDvarInt( "sv_maxclients" ) );

	if ( level.mpdbg_bots <= 1 )
	{
		return;
	}

	// Stock: with this set and one player connected, the game adds one bot itself
	// and starts the match as a co-op game instead of a solo one (_zm.gsc).
	SetDvar( "scr_zm_enable_bots", "1" );

	callback::on_connect( &on_connect );
	callback::on_spawned( &on_spawned );

	level thread run();
}

// IPrintLn lines reach the console log (console_mp.log, as "[msg]MPDBG ...") when the
// game runs with +set logfile 2. LogPrint is kept for clients that write a game log.
function out( str_line )
{
	LogPrint( "MPDBG " + str_line + "\n" );
	IPrintLn( "MPDBG " + str_line );
}

function on_connect()
{
	out( "connect slot=" + self GetEntityNumber() + " name=" + self.name + " players=" + GetPlayers().size );
}

function on_spawned()
{
	self thread report_spawn();
}

function report_spawn()
{
	self endon( "disconnect" );

	out( "spawn slot=" + self GetEntityNumber() + " at=" + self.origin + " state=" + self.sessionstate );

	// after the mod has had its turn
	wait 0.3;

	if ( !isdefined( self ) )
	{
		return;
	}

	n_char = -1;

	if ( isdefined( self.characterindex ) )
	{
		n_char = self.characterindex;
	}

	out( "placed slot=" + self GetEntityNumber() + " at=" + self.origin + " char=" + n_char + " nearest=" + self nearest_player_dist() );

	if ( level.mpdbg_tests || level.mpdbg_rounds > 0 )
	{
		// nobody is at the keyboard
		self EnableInvulnerability();
	}
}

function nearest_player_dist()
{
	a_players = GetPlayers();
	n_best = 99999;

	for ( i = 0; i < a_players.size; i++ )
	{
		if ( a_players[ i ] == self || a_players[ i ].sessionstate != "playing" )
		{
			continue;
		}

		n_dist = Distance2D( self.origin, a_players[ i ].origin );

		if ( n_dist < n_best )
		{
			n_best = n_dist;
		}
	}

	return int( n_best );
}

function run()
{
	// The stock start-up counts connected players against the lobby's count and
	// never finishes if bots arrive early, so wait for it to be through.
	while ( !level flag::exists( "initial_players_connected" ) || !level flag::get( "initial_players_connected" ) )
	{
		wait 0.05;
	}

	out( "start-up done, players=" + GetPlayers().size + " com_maxclients=" + GetDvarInt( "com_maxclients" ) );

	// the game adds one bot by itself about 4 seconds from now
	n_failed = 0;

	for ( i = 2; i < level.mpdbg_bots; i++ )
	{
		bot = AddTestClient();

		if ( !isdefined( bot ) )
		{
			n_failed++;
			out( "AddTestClient failed for player " + ( i + 1 ) );
		}
		else
		{
			bot.pers[ "isBot" ] = true;
		}

		wait 0.25;
	}

	wait 8;

	out( "bots added, failed=" + n_failed + " players=" + GetPlayers().size );
	status( "after-start" );

	level thread report_rounds();

	if ( level.mpdbg_tests )
	{
		run_tests();
	}

	level thread tick();

	if ( level.mpdbg_rounds > 0 )
	{
		fast_forward();
	}

	// test/zz_mp_autostart.lua sees this and quits the game
	wait 5;
	out( "finished" );
	SetDvar( "mpdbg_quit", "1" );
}

function tick()
{
	while ( true )
	{
		wait 30;
		status( "tick" );
	}
}

function status( str_tag )
{
	a_players = GetPlayers();
	n_zombies = zombie_utility::get_current_zombie_count();
	n_round = -1;

	if ( isdefined( level.round_number ) )
	{
		n_round = level.round_number;
	}

	out( "ui: " + GetDvarString( "mpdbg_ui" ) );
	out( "status " + str_tag + " players=" + a_players.size + " round=" + n_round + " zombies=" + n_zombies + " ai_limit=" + level.zombie_ai_limit
		+ " too_many_check=" + level.player_too_many_players_check + " time=" + GetTime() );

	for ( i = 0; i < a_players.size; i++ )
	{
		player = a_players[ i ];
		n_char = -1;

		if ( isdefined( player.characterindex ) )
		{
			n_char = player.characterindex;
		}

		str_gums = "undefined";

		if ( isdefined( player.bgb_pack ) )
		{
			str_gums = "" + player.bgb_pack.size + ":";

			for ( j = 0; j < player.bgb_pack.size; j++ )
			{
				str_gums = str_gums + player.bgb_pack[ j ] + ",";
			}
		}

		out( " p" + player GetEntityNumber() + " " + player.name + " " + player.sessionstate + " char=" + n_char
			+ " down=" + player laststand::player_is_in_laststand() + " score=" + player.score + " near=" + player nearest_player_dist() );
		out( " p" + player GetEntityNumber() + " gums=" + str_gums );
	}
}

function report_rounds()
{
	while ( true )
	{
		level waittill( "start_of_round" );
		// what the game would use as the time between spawns this round
		n_delay = [[ level.func_get_zombie_spawn_delay ]]( level.round_number );
		out( "round " + level.round_number + " start players=" + GetPlayers().size + " total=" + level.zombie_total + " delay=" + n_delay + " time=" + GetTime() );
	}
}

function player_in_slot( n_slot )
{
	a_players = GetPlayers();

	for ( i = 0; i < a_players.size; i++ )
	{
		if ( a_players[ i ] GetEntityNumber() == n_slot )
		{
			return a_players[ i ];
		}
	}

	return undefined;
}

function run_tests()
{
	wait 5;

	// 1. A player in slot 5 goes down and is revived (slot 1 as the control).
	// Not slot 7: the last bot is the one the game adds by itself (add_bots in
	// _zm.gsc), in the same moment as it starts the round logic. The game treats
	// it as a late joiner, so it watches round 1 as a spectator and spawns in
	// round 2, as any late joiner does with or without the mod.
	down_and_revive( 1 );
	down_and_revive( 5 );
	down_and_revive( 6 );

	// 2. A gum for a player in slot 0, 1 and 5.
	give_gum( 0, "zm_bgb_always_done_swiftly" );
	give_gum( 1, "zm_bgb_always_done_swiftly" );
	give_gum( 5, "zm_bgb_always_done_swiftly" );
	give_gum( 6, "zm_bgb_stock_option" );

	// 3. On the four maps with an item icon per player slot: set it for slot 5.
	set_slot_item_field( 5 );

	status( "after-tests" );
	out( "tests done" );
}

function set_slot_item_field( n_slot )
{
	str_map = ToLower( GetDvarString( "mapname" ) );
	str_field = undefined;

	if ( str_map == "zm_castle" )
	{
		str_field = "player" + n_slot + "hasItem";
	}
	else if ( str_map == "zm_stalingrad" || str_map == "zm_genesis" || str_map == "zm_moon" )
	{
		str_field = "player" + n_slot + "wearableItem";
	}

	else if ( str_map == "zm_island" )
	{
		str_field = "pillar_challenge_" + n_slot + "_1";
	}

	if ( !isdefined( str_field ) )
	{
		return;
	}

	out( "slot field: setting " + str_field );
	wait 0.5;
	level clientfield::set( str_field, 1 );
	wait 1;
	out( "slot field: " + str_field + " is now " + level clientfield::get( str_field ) );
	level clientfield::set( str_field, 0 );
}

function down_and_revive( n_slot )
{
	player = player_in_slot( n_slot );

	if ( !isdefined( player ) )
	{
		out( "down: no player in slot " + n_slot );
		return;
	}

	out( "down: slot " + n_slot + " health=" + player.health );
	player DisableInvulnerability();
	wait 0.1;
	player DoDamage( player.health + 100, player.origin );
	wait 2;
	out( "down: slot " + n_slot + " in laststand=" + player laststand::player_is_in_laststand() + " state=" + player.sessionstate + " at=" + player.origin );
	// long enough for a screenshot of the revive icon
	wait 5;
	out( "ui while slot " + n_slot + " is down: " + GetDvarString( "mpdbg_ui" ) );

	// Pretend somebody is reviving this player for a moment: the flag the
	// stock revive sets while it runs. Bots can not hold the use button.
	if ( isdefined( player.revivetrigger ) )
	{
		player.revivetrigger.beingrevived = 1;
		wait 2;
		out( "ui while slot " + n_slot + " is being revived: " + GetDvarString( "mpdbg_ui" ) );
		wait 0.5;

		if ( isdefined( player.revivetrigger ) )
		{
			player.revivetrigger.beingrevived = 0;
		}
	}

	// and time for a person at the keyboard to walk over and revive for real
	n_waited = 0;

	while ( n_waited < 20 && player laststand::player_is_in_laststand() )
	{
		wait 1;
		n_waited++;
	}

	out( "ui after " + n_waited + " more seconds, slot " + n_slot + " in laststand=" + player laststand::player_is_in_laststand() + ": " + GetDvarString( "mpdbg_ui" ) );

	if ( player laststand::player_is_in_laststand() )
	{
		player zm_laststand::auto_revive( player );
		wait 1.5;
		out( "revive: slot " + n_slot + " in laststand=" + player laststand::player_is_in_laststand() + " health=" + player.health );
	}

	player EnableInvulnerability();
}

function give_gum( n_slot, str_gum )
{
	player = player_in_slot( n_slot );

	if ( !isdefined( player ) )
	{
		out( "gum: no player in slot " + n_slot );
		return;
	}

	out( "gum: giving " + str_gum + " to slot " + n_slot );
	player thread bgb::give( str_gum );
	wait 2;

	str_now = "undefined";

	if ( isdefined( player.bgb ) )
	{
		str_now = player.bgb;
	}

	out( "gum: slot " + n_slot + " now holds " + str_now + " enabled=" + player bgb::is_enabled( str_gum ) );
}

// Kills zombies as they appear, so rounds pass in seconds.
function fast_forward()
{
	out( "fast forward to round " + level.mpdbg_rounds );
	n_kills = 0;

	n_last_round = -1;
	n_same_round = 0;

	while ( isdefined( level.round_number ) && level.round_number < level.mpdbg_rounds )
	{
		// Some maps do not move on by kills alone (Moon while everyone is on
		// Earth). Give up when a round has not changed for two minutes.
		if ( level.round_number != n_last_round )
		{
			n_last_round = level.round_number;
			n_same_round = 0;
		}

		n_same_round++;

		if ( n_same_round > 240 )
		{
			out( "fast forward gave up: round " + level.round_number + " did not end in two minutes" );
			break;
		}

		// spawn as fast as the game allows, so a round takes seconds
		level.zombie_vars[ "zombie_spawn_delay" ] = 0.1;

		a_ai = GetAITeamArray( "axis" );

		for ( i = 0; i < a_ai.size; i++ )
		{
			if ( isdefined( a_ai[ i ] ) && IsAlive( a_ai[ i ] ) )
			{
				// kills are shared out, so players in every slot score
				a_players = GetPlayers();
				attacker = a_players[ n_kills % a_players.size ];
				n_kills++;
				a_ai[ i ] DoDamage( a_ai[ i ].health + 666, a_ai[ i ].origin, attacker );
			}
		}

		wait 0.5;
	}

	out( "fast forward done at round " + level.round_number );
	status( "after-rounds" );
}
