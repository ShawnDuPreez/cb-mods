// All Perks - every player starts a zombies match holding all the map's perks.
//
// A custom script for the iw7-mod client, run by the host. Joining players
// need nothing.
//
// The game already has this feature: Director's Cut gives each player every
// perk about 9 seconds after they spawn and marks them with
// have_permanent_perks. With that mark set, the game's own code hands the
// perks back after a revive, after the afterlife arcade and after a respawn
// (zombie.gsc give_permanent_perks, called when last stand ends), and perk
// machines stop counting perk slots for that player. This script sets the
// same mark and gives the same perks, for everyone, without Director's Cut.
//
// It does not give Director's Cut's other benefits (unlimited self revives,
// upgraded Pack-a-Punch, wonder weapons in the Magic Wheel).
//
// One thing is added on top. Using a perk machine for a perk you hold removes
// that perk, and for a player with permanent perks the game then takes the
// price for buying it back without giving it (Director's Cut hides this by
// also lifting the perk limit, which comes bundled with unlimited self
// revives). So a perk that is removed on its own is handed straight back.
//
// Turn it off for a match without removing the file: in the console, before
// the match starts,   set all_perks 0

init()
{
    level thread watch_for_players();
}

// level.players is polled instead of waiting for "connected": this script's
// init() can run after the host has already connected.
watch_for_players()
{
    level endon( "game_ended" );

    for (;;)
    {
        if ( isdefined( level.players ) && getdvarint( "all_perks", 1 ) != 0 )
        {
            foreach ( player in level.players )
            {
                if ( isdefined( player.all_perks_started ) )
                    continue;

                player.all_perks_started = 1;
                player thread start_with_all_perks();
            }
        }

        wait 1;
    }
}

// self = player.
start_with_all_perks()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    while ( !isalive( self ) || self.sessionstate != "playing" )
        wait 0.25;

    scripts\engine\utility::flag_wait( "introscreen_over" );

    // Director's Cut waits this long after the spawn, for the intro to finish.
    if ( getdvar( "ui_mapname" ) == "cp_town" )
        wait 13;
    else
        wait 9;

    // Director's Cut or the Ghosts 'n Skulls reward got here first: the game
    // is already giving this player every perk.
    if ( scripts\engine\utility::is_true( self.have_permanent_perks ) )
        return;

    self.have_permanent_perks = 1;
    self thread give_all_perks();
    self thread return_perks_removed_one_at_a_time();
}

// self = player. If the player goes down while this runs, it stops, and the
// game gives the full set when they get back up.
give_all_perks()
{
    self endon( "disconnect" );
    self endon( "last_stand" );
    self endon( "death" );
    level endon( "game_ended" );

    foreach ( perk in get_map_perks() )
    {
        wait 0.5;

        if ( scripts\engine\utility::is_true( self.playing_ghosts_n_skulls ) )
            continue;

        if ( self scripts\cp\utility::has_zombie_perk( perk ) )
            continue;

        self scripts\cp\zombies\zombies_perk_machines::give_zombies_perk( perk, 0 );
    }
}

// self = player. The game takes perks in two ways. All at once: going down,
// the Ghosts 'n Skulls arcade, the Radioactive Thing's bomb step. It hands
// those back itself. Or one alone: a perk machine used by a player who holds
// that perk, the solo self revive being used up, the Slasher's hit on Rave.
// Those are handed back here, on the next frame. (Alone, the self revive is
// taken with the rest on a down; see the next function for that case.)
return_perks_removed_one_at_a_time()
{
    self.all_perks_removed = [];
    self thread note_last_stand_time();
    self thread return_solo_self_revive_after_revives();

    foreach ( perk in get_map_perks() )
        self thread watch_perk_removed( perk );
}

note_last_stand_time()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    for (;;)
    {
        self waittill( "last_stand" );
        self.all_perks_last_down = gettime();
    }
}

// Playing alone, Up 'N Atoms is a self revive. The game takes it with the
// other perks when the player goes down and leaves it out when it hands the
// rest back. The machine would sell it again, three times a match in all, but
// for a player with permanent perks it takes the money and gives nothing. So
// it is handed back here instead, as long as the game would still sell it.
return_solo_self_revive_after_revives()
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    for (;;)
    {
        self waittill( "revive" );
        self thread return_solo_self_revive();
    }
}

return_solo_self_revive()
{
    self endon( "disconnect" );
    self endon( "last_stand" );
    level endon( "game_ended" );

    // The game hands the other perks back one second after the revive.
    wait 2.5;

    if ( !scripts\cp\utility::isplayingsolo() && !scripts\engine\utility::is_true( level.only_one_player ) )
        return;

    if ( getdvarint( "all_perks", 1 ) == 0 || !scripts\engine\utility::is_true( self.have_permanent_perks ) )
        return;

    if ( !isalive( self ) || self.sessionstate != "playing" )
        return;

    if ( scripts\engine\utility::is_true( self.inlaststand ) || scripts\engine\utility::is_true( self.playing_ghosts_n_skulls ) )
        return;

    if ( !isdefined( self.self_revives_purchased ) || !isdefined( self.max_self_revive_machine_use ) )
        return;

    if ( self.self_revives_purchased >= self.max_self_revive_machine_use )
        return;

    if ( self scripts\cp\utility::has_zombie_perk( "perk_machine_revive" ) )
        return;

    self scripts\cp\zombies\zombies_perk_machines::give_zombies_perk( "perk_machine_revive", 0 );
}

// The game sends "remove_perk_icon_<perk>" to the player whenever it takes
// that perk away.
watch_perk_removed( perk )
{
    self endon( "disconnect" );
    level endon( "game_ended" );

    for (;;)
    {
        self waittill( "remove_perk_icon_" + perk );
        self.all_perks_removed[self.all_perks_removed.size] = perk;

        if ( self.all_perks_removed.size == 1 )
            self thread return_removed_perk();
    }
}

return_removed_perk()
{
    self endon( "disconnect" );
    level endon( "game_ended" );
    wait 0.05;
    removed = self.all_perks_removed;
    self.all_perks_removed = [];

    // More than one in the same frame: the game took them all and will give
    // them back when it is ready.
    if ( removed.size != 1 )
        return;

    if ( getdvarint( "all_perks", 1 ) == 0 || !scripts\engine\utility::is_true( self.have_permanent_perks ) )
        return;

    if ( !isalive( self ) || self.sessionstate != "playing" )
        return;

    if ( scripts\engine\utility::is_true( self.inlaststand ) || scripts\engine\utility::is_true( self.playing_ghosts_n_skulls ) )
        return;

    // A player who went down holding a single perk loses that one "alone".
    if ( isdefined( self.all_perks_last_down ) && gettime() - self.all_perks_last_down < 3000 )
        return;

    if ( self scripts\cp\utility::has_zombie_perk( removed[0] ) )
        return;

    self scripts\cp\zombies\zombies_perk_machines::give_zombies_perk( removed[0], 0 );
}

// The same list the game uses when it hands permanent perks back: the map's
// own list where it has one (Shaolin Shuffle, Radioactive Thing, Beast from
// Beyond), else the ten perks of Spaceland and Rave.
get_map_perks()
{
    if ( isdefined( level.all_perk_list ) )
        return level.all_perk_list;

    return [ "perk_machine_boom", "perk_machine_flash", "perk_machine_fwoosh", "perk_machine_more", "perk_machine_rat_a_tat", "perk_machine_revive", "perk_machine_run", "perk_machine_smack", "perk_machine_tough", "perk_machine_zap" ];
}
