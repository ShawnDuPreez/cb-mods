#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

// more_players: this stock client script is loaded on every zombies map, so it
// is the way in for the mod's client script. Nothing else in this file is changed.
#using scripts\zm\zm_more_players;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace zm_score;

REGISTER_SYSTEM( "zm_score", &__init__, undefined )

function __init__()
{
}
