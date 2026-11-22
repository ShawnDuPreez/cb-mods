// More Players: client script.
//
// Loaded on every zombies map through the #using in scripts/zm/_zm_score.csc.

#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_utility;

// No #insert and no macros with arguments in this file on purpose: it then builds
// unchanged with the Mod Tools linker and with other BO3 script compilers.

#namespace zm_more_players;

// Keep in step with zm_more_players.gsc.
#define MORE_PLAYERS_MAX			8
#define MORE_PLAYERS_STOCK_MAX		4
// VERSION_SHIP in scripts/shared/version.gsh.
#define MORE_PLAYERS_VERSION_SHIP	1

// zm_laststand is named as a requirement so that its own setup, which starts
// level.laststands from an empty list, has run before slots are added to it.
// (This is what the stock REGISTER_SYSTEM macro expands to; the misspelling is stock.)
function autoexec __init__sytem__()
{
	system::register( "zm_more_players", &__init__, undefined, "zm_laststand" );
}

function __init__()
{
	if ( !isdefined( level.laststands ) )
	{
		level.laststands = array();
	}

	// The revive countdown for player slots 4-7: the same per-slot record and
	// world field that _zm_laststand.csc makes for slots 0-3, handled by its
	// own callback (it reads the slot number out of the field name). The server
	// half is in zm_more_players.gsc; name, version, size and type must match.
	for ( i = MORE_PLAYERS_STOCK_MAX; i < MORE_PLAYERS_MAX; i++ )
	{
		level.laststands[ i ] = SpawnStruct();
		level.laststands[ i ].bleedoutTime = 0;
		level.laststands[ i ].laststand_update_clientfields = "laststand_update" + i;
		level.laststands[ i ].lastBleedoutTime = 0;

		clientfield::register( "world", level.laststands[ i ].laststand_update_clientfields, MORE_PLAYERS_VERSION_SHIP, 5, "counter", &zm_laststand::update_bleedout_timer, false, false );
	}

	register_map_slot_fields();
}

// The fields of their own per player slot that five maps have (see
// zm_more_players.gsc, which must list the same maps with the same numbers).
// The item icons use the stock callback, which writes the value to the HUD
// model named after the field. The Zetsubou No Shima fields drive the four
// challenge pillars and ending portals that exist in the map; there is none
// for a fifth player, so those are registered with nothing to call.
function private register_map_slot_fields()
{
	str_map = ToLower( GetDvarString( "mapname" ) );

	if ( str_map == "zm_castle" )
	{
		register_slot_fields( "player", "hasItem", 1, 1, &zm_utility::setSharedInventoryUIModels );
	}
	else if ( str_map == "zm_stalingrad" )
	{
		register_slot_fields( "player", "wearableItem", 12000, 2, &zm_utility::setSharedInventoryUIModels );
	}
	else if ( str_map == "zm_genesis" )
	{
		register_slot_fields( "player", "wearableItem", 15000, 4, &zm_utility::setSharedInventoryUIModels );
	}
	else if ( str_map == "zm_moon" )
	{
		register_slot_fields( "player", "wearableItem", 21000, 1, &zm_utility::setSharedInventoryUIModels );
	}
	else if ( str_map == "zm_island" )
	{
		register_slot_fields( "pillar_challenge_", "_1", 9000, GetMinBitCountForNum( 4 ), undefined );
		register_slot_fields( "pillar_challenge_", "_2", 9000, GetMinBitCountForNum( 4 ), undefined );
		register_slot_fields( "pillar_challenge_", "_3", 9000, GetMinBitCountForNum( 4 ), undefined );
		register_slot_fields( "portal_state_ending_", "", 9000, 1, undefined );
	}
}

// One world field per extra slot, named <prefix><slot><suffix>.
function private register_slot_fields( str_prefix, str_suffix, n_version, n_bits, func_callback )
{
	for ( i = MORE_PLAYERS_STOCK_MAX; i < MORE_PLAYERS_MAX; i++ )
	{
		clientfield::register( "world", str_prefix + i + str_suffix, n_version, n_bits, "int", func_callback, false, false );
	}
}
