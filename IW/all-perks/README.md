# All Perks (Infinite Warfare zombies)

Every player starts a zombies match holding all of the map's perks, on the
[iw7-mod](https://github.com/auroramod/iw7-mod) client. The perks come back after a revive,
after the afterlife arcade and after a respawn.

**Status: tested with bots on all five maps on 2026-11-22. Not yet tried in the real game.**
See [What was tested](#what-was-tested).

## What you get

About 10 seconds after you spawn (14 on Attack of the Radioactive Thing, where the intro is
longer), the perks arrive one every half second.

| Map | Perks |
| --- | --- |
| Zombies in Spaceland | 10 |
| Rave in the Redwoods | 10 |
| Shaolin Shuffle | 10 (Deadeye Dewdrops instead of Slappy Taffy) |
| Attack of the Radioactive Thing | 12 (adds Change Chews and Deadeye Dewdrops) |
| The Beast from Beyond | 12 |

These are the same lists the game itself uses for Director's Cut. On the last two maps the
list has one perk more than the map has machines for: Trail Blazers on Radioactive Thing,
Slappy Taffy on Beast from Beyond. You get those too.

- **Going down:** the game takes your perks, as always. When you are back up, by a revive,
  the afterlife arcade or the next round, it hands the whole set back about a second later.
- **Playing alone:** Up 'N Atoms is the self revive. It goes with the others when you go
  down and comes back with them, three times a match in all, counting the one you start
  with. That is as many as the machine would sell you. After the third it stays gone.
- **Joining late:** a player who joins mid-match gets the perks the same way.
- **Perk machines:** a machine can not take a perk off you. Using the machine of a perk you
  hold removes it, and it is handed straight back.
- **Rave's Slasher:** his hit that knocks a perk off you has no lasting effect, for the same
  reason.

## Install

**The normal way: a mod you pick in the game.** Download `iw-all-perks.zip` from the
[releases page](https://github.com/ShawnDuPreez/cb-mods/releases) and extract it into your game folder, the one that holds
`iw7-mod.exe` (in the CB Servers launcher: Infinite Warfare > Browse Local Files). It adds
`mods/all_perks/`. Start the game, open the Mods menu and pick ALL_PERKS, then host a
zombies match.

The Mods menu loads one mod at a time, so this is used on its own. Every player needs the
mod, because the game only lets players join a mod they also have.

**As always-on files (optional).** The same script, placed in the game's `iw7-mod` folder.
It is then on in every zombies match you host, beside whichever mod is picked, and only the
host needs it.

```bash
./install.sh
```

`./install.sh --remove` takes it out. Pass another game folder as the first argument if
yours is not `~/Games/Infinite-Warfare/iw_game_files`. To switch it off for one match, type
`set all_perks 0` in the console before the match starts. Use one form, not both.

## With the other mods

The mods here are meant to be used one at a time, picked in the Mods menu.

If you do want two at once, the always-on files are the way: they were tested running beside
[More Players](../more-players/README.md) loaded as a mod, with
[Perk Limit](../perk-limit/README.md) always-on too. In that case All Perks wins over the
limit: you hold every perk whatever the limit says.

## What it changes

The game already has this feature. Director's Cut gives each player every perk shortly after
they spawn and marks the player as having permanent perks. With that mark, the game's own
code returns the perks whenever a last stand ends, and perk machines stop counting perk
slots for that player.

`all_perks.gsc` sets the same mark and gives the same perks, for every player, without
Director's Cut. It replaces no game function. It does not give Director's Cut's other
benefits: no unlimited self revives, no upgraded Pack-a-Punch, no wonder weapons in the
Magic Wheel.

Two things are added on top, both to close one gap. For a player with that mark, a perk
machine takes the price of a perk and then does not hand it over. Director's Cut hides this
by also lifting the perk limit, which comes bundled with unlimited self revives. Instead:

- A perk that is taken on its own (a machine, the Slasher) is given back on the next frame.
  When the game takes all of them at once (a down, the Ghosts 'n Skulls arcade, the
  Radioactive Thing's bomb step), the script leaves it to the game to return them.
- Playing alone, Up 'N Atoms is given back after a revive, as long as the game would still
  sell it.

If Director's Cut or the Ghosts 'n Skulls reward already gave a player permanent perks, the
script leaves that player alone.

## What was tested

On the CB Servers build of iw7-mod (v1.2.0), on 2026-11-22, on a private server with bots
standing in for players.

**All five maps, six bots each:**

- Every bot ends up holding every perk on the map's list (10, 10, 10, 12, 12), and its
  health goes from 100 to 200, so the perks are really applied, not just listed.
- After the game's own "take this player's perks" step the bot has none, and still has none
  half a second later: the mod does not fight the game. After the game's own "last stand is
  over" step it has all of them again.
- A bot really knocked down goes into last stand with no perks. Revived, it has all of them.
- A bot that uses the Tuff 'Nuff machine while holding Tuff 'Nuff still has every perk and
  200 health half a second later. The same after the game takes one single perk from it.
- A bot that joins a minute into the match gets every perk too.
- No script error is raised inside `all_perks.gsc`. Each run logs 21 errors from the game's
  own Bang Bangs code, because a bot has no pistol; real players do not cause those.

**Alone, on Spaceland:** one bot, on a server told to treat the match as one player alone.
It starts with every perk. Knocked down, it lands in the afterlife arcade with none. Sent
back through the arcade's self revive door, it has all ten again after the first and second
down, and nine (no Up 'N Atoms) after the third.

**Together with the other two mods, on Spaceland and Radioactive Thing:** More Players loaded
as a mod from its mod folder, All Perks and Perk Limit as always-on files, 8 bots, and the
perk limit set to 3. All three scripts load. More Players' own checks pass (characters,
spawns, three revives at once, the arcade teleport, leave and rejoin). Every player still
gets every perk, so All Perks wins over the limit. No script error is raised inside any of
the three mods' files.

To repeat the test after changing the script (about two minutes, one map per run):

```bash
test/bot-test.sh cp_zmb
```

**Not tested:**

- The real game with a real player: the perk icons on the HUD, the half-second hand-out as
  it looks on screen, and that nothing gets in the way of the intro.
- A real Solo Match. The solo rule was run with one bot on a server told to treat the
  match as one player alone.
- A long game, boss fights, Ghosts 'n Skulls.
- The launcher's Import of `dist/all_perks.zip`, and picking ALL_PERKS in the Mods menu.
  The script was run from the always-on place and, in the combined test, beside a mod
  folder. More Players is loaded the same way and works, so this is expected to, but it has
  not been done.

## Known limits

- **Stats:** each perk handed out counts as a perk used in your career stats, the same as
  in Director's Cut.
- **You can not drop a perk.** In the normal game a perk machine lets you get rid of a perk
  you hold. With this mod it comes straight back.

## How it works

iw7-mod loads every `.gsc` in `custom_scripts/cp/` when a zombies match starts and runs its
`init()`. The script checks the player list once a second, and for each new player waits
until they are alive and the intro is over, waits as long again as Director's Cut does, then
sets `have_permanent_perks` and calls the game's own `give_zombies_perk` for each perk in
`level.all_perk_list` (or the default ten where the map has no list). The game announces
every perk it takes with a message to the player; one such message in a frame means a single
perk was taken, several mean the game took them all.

The stock scripts were read from the public decompile
[mjkzy/iw7-gsc-dump](https://github.com/mjkzy/iw7-gsc-dump). `../tools/check-stock-names.py`
checks every stock name the script uses against it.

`mod/mod.ff` holds one small text file and exists only so the launcher accepts the folder
as a mod. `../tools/build-mod-ff.sh all-perks all_perks` rebuilds it.
