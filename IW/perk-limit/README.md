# Perk Limit (Infinite Warfare zombies)

The host chooses how many perks a player may hold, from a PERK LIMIT row in the zombies
lobby's MATCH SETTINGS, on the [iw7-mod](https://github.com/auroramod/iw7-mod) client.

**Status: the game script is tested with bots on all five maps (2026-11-22). The PERK LIMIT
row has not been seen in the real game yet**, so that part is written but unproven. See
[What was tested](#what-was-tested).

## Use

1. Zombies, then Custom Game.
2. Open **MATCH SETTINGS**. Under OPEN TO FRIENDS there is a new row, **PERK LIMIT**.
3. Left and right step through 1 to 11 and No limit. Back closes it.
4. Start the match.

The game's own limit is 5, and that is what applies until you change it. The choice lasts
until you close the game. Only the host can open Match Settings.

In a **Solo Match** the client shows no Match Settings button, so the lobby gets a
**PERK LIMIT** button of its own there, last in the list, which opens a small popup with the
same row.

On a dedicated server there is no lobby: put `set perk_limit 7` in the server config
(`0` means no limit).

## Install

**The normal way: a mod you pick in the game.** Download `iw-perk-limit.zip` from the
[releases page](https://github.com/ShawnDuPreez/cb-mods/releases) and extract it into your game folder, the one that holds
`iw7-mod.exe` (in the CB Servers launcher: Infinite Warfare > Browse Local Files). Start
the game, open the Mods menu and pick PERK_LIMIT.

The zip puts two things in place:

- `mods/perk_limit/`, the mod itself. Every player needs it, because the game only lets
  players join a mod they also have.
- `iw7-mod/ui_scripts/PerkLimit/`, the menu script. Only the host uses it.

Why the second one: right after a mod is picked, the game runs nothing from that mod's
folder and starts its menus before the mod's `mod.ff` is ready. Only files in the game's own
`iw7-mod` folder are used at that point. So the menu script lives there. It shows nothing
unless PERK_LIMIT is the loaded mod. Without it the mod still works, but the PERK LIMIT row
only appears after you have played one match with the mod loaded.

The Mods menu loads one mod at a time, so this is used on its own.

From a copy of this repository, `./install.sh --menu` installs just the menu script.

**As always-on files (optional).** Menu script and game script both in the game's `iw7-mod`
folder: no mod to pick, the row is always in Match Settings, it does nothing until you change
it from 5, and only the host needs it.

```bash
./install.sh
```

Restart the game afterwards. Use this or the mod, not both. `./install.sh --remove` takes out
whichever files are there. Pass another game folder as the last argument if yours is not
`~/Games/Infinite-Warfare/iw_game_files`.

## With the other mods

The mods here are meant to be used one at a time, picked in the Mods menu.

If you do want two at once, the always-on files are the way: they were tested running beside
[More Players](../more-players/README.md) loaded as a mod, with
[All Perks](../all-perks/README.md) always-on too. In that case All Perks wins: its players
hold every perk whatever the limit says.

## What it changes

| Where a perk can be taken | With the mod |
| --- | --- |
| Perk machines, all maps | Refuse a new perk once you hold the chosen number, and show the game's "perk slots full" text. Removing a perk at its machine still works. |
| Weapon variants that hand out a random perk every 75 kills | Follow the chosen number. |
| Perk crates in the Rat King and Rhino boss fights | Unchanged: the game's 5. |
| Director's Cut straight-to-boss mode | Unchanged: its own limit of 20. |

Perks the game hands out as a reward (Director's Cut, the Ghosts 'n Skulls reward) never
counted against the limit and still do not.

Lowering the limit below what a player already holds takes nothing away. It only stops new
perks.

Two faults in the game's own code are fixed on the way, because the mod replaces the
functions they are in:

- A player the game has given every perk could be charged for a perk and not get it,
  depending on which machine it was. The game checks one flag when it sets the price and
  another when it hands the perk over, and the Bang Bangs machine checks neither. Now one
  check is used everywhere.
- The random-perk weapon variants looped forever for a player who already held every perk on
  the list. The game's limit of 5 made that impossible; a higher limit does not.

## What was tested

On the CB Servers build of iw7-mod (v1.2.0), on 2026-11-22.

**The game script, on a private server with bots, all five maps.** A bot was walked past
every perk machine on the map through the game's own machine code, once per setting:

| Setting | Perks the bot ended up with |
| --- | --- |
| not set | 5 |
| 2 | 2 |
| 3 | 3 |
| 7, given on the server's command line | 7 |
| 9 | 9 |
| no limit | every perk the map has a machine for: 10 on Spaceland, Rave and Shaolin Shuffle, 11 on Radioactive Thing and Beast from Beyond |

- "not set", 2 and 9 were run on Spaceland; 7, no limit and 3 on the other four maps; no
  limit on all five.
- In every case the machine's text switched to "perk slots full" and the machine stopped
  charging at exactly that number of perks.
- No script error was raised inside `perk_limit.gsc`. The log does show errors from the
  game's own Bang Bangs code, because a bot has no pistol; real players do not cause those.

**The menu script, against stand-ins for the game's menu functions** (`test/lua-mock-test.lua`,
81 checks): reading and writing the setting, the labels, that the two rows land in the
MATCH SETTINGS popup just above its footer and nowhere else (not in other popups, not in the
multiplayer lobby), that nothing shows while another mod or no mod is loaded and that it
follows the mod being picked and unloaded, that Match Settings still opens unchanged if the
row can not be built, the Solo Match button and its popup, the host-only rule, and that a
broken lobby does not stop the menu from opening. Each check was confirmed to fail when the
line it guards is broken on purpose.

**Loaded the way the Mods menu loads it**, on Spaceland: the mod folder from
`dist/perk_limit.zip` under `mods/`, nothing in `iw7-mod/`. The game script loads from the mod
folder and limits of 7, none and 3 hold, with the final `mod.ff`.

**Together with More Players and All Perks**: see
[All Perks, What was tested](../all-perks/README.md#what-was-tested).

`mod/mod.ff` was built with zonetool and is 6,692 bytes; with only its text file inside it
is about 430, so the menu script is in it.

To repeat the tests after a change:

```bash
test/bot-test.sh cp_zmb
```

```bash
lua5.1 test/lua-mock-test.lua
```

**Not tested:**

- **The PERK LIMIT row in the real game.** Whether it shows in Match Settings, sits under
  OPEN TO FRIENDS and steps through the values can only be seen in the game. The same goes
  for the Solo Match button.
- That the value chosen in the lobby reaches the match. The script reads the same kind of
  setting that More Players' bot count uses, which does carry over from the menus, but this
  exact path has not been run.
- A real player buying perks at real machines. The test calls the machines' code for a bot.
- **Picking PERK_LIMIT in the Mods menu and seeing the row**, which is the normal way to
  use it. The first try, on 2026-11-22 with an earlier build that had no host-side menu
  script, showed no row; the game's log from that try is what the two-part install is based
  on. Also the launcher's Import of `dist/perk_limit.zip`.

## Known limits

- **The host needs the menu script as well as the mod** (see Install). Read from the game's
  log on 2026-11-22: after a mod is picked the game loads `mod.ff` twice, starts the menus
  both times before it is ready, and reloads its menu-level game scripts from the `iw7-mod`
  folder only. The mod's own folder is first used when a match loads. A script inside the mod
  therefore can not draw a menu row, or restart the menus, at that moment.
- The row's text is English only.

## How it works

The game hard-codes the limit as "more than 4 perks held" in each place a perk can be taken.
iw7-mod's `replacefunc` swaps five of the game's functions for versions in `perk_limit.gsc`
that read the dvar `perk_limit` instead (unset means 5, 0 means no limit). A replaced
function can not be called again, so each one is a full copy of the original with only the
limit check changed.

`ui_scripts/PerkLimit` does not rebuild the client's MATCH SETTINGS popup. The client builds
that popup as a list of rows; the script steps in at the moment the list is handed over,
slips its two rows (the arrows and a line of text) in above the footer, and passes the list
on. Whatever else the client has in the popup stays. Choosing a value runs
`set perk_limit <n>`. Where a lobby has no Match Settings button (Solo Match), the script
adds one row to the lobby's button list instead and gives it a popup of its own.

Before showing anything the script checks that the game script will run in the match: the
`fs_game` setting names this mod, or `perk_limit.gsc` is installed as an always-on file. The
same script is also packed inside `mod.ff`; the game uses that copy only when there is no
copy in `iw7-mod/ui_scripts`, and only once a match has been played.

The stock scripts were read from public decompiles
([mjkzy/iw7-gsc-dump](https://github.com/mjkzy/iw7-gsc-dump) for game scripts,
[deshayu/iw7-dump](https://github.com/deshayu/iw7-dump) for menus).
`../tools/check-stock-names.py` checks every stock name the game script uses against the
first. `../tools/build-mod-ff.sh perk-limit perk_limit` rebuilds `mod/mod.ff`.

More Players and All Perks replace none of the functions this mod replaces, so the three do
not collide.
