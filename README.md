# cb-mods

Mods for the Call of Duty clients in the CB Servers launcher.

## Infinite Warfare (`IW/`)

Zombies mods for the iw7-mod client. Each is picked on its own in the game's Mods menu.

| Mod | What it does | Download |
| --- | --- | --- |
| [More Players](IW/more-players/README.md) | 8-player zombies: lobby of 8, the game's 4-player assumptions patched, HUD and scoreboard for everyone, and with more than 4 players the Magic Wheel can hand out wonder weapons the team has already built. | `iw-more-players.zip` |
| [All Perks](IW/all-perks/README.md) | Every player starts with all of the map's perks and gets them back after going down. | `iw-all-perks.zip` |
| [Perk Limit](IW/perk-limit/README.md) | The host chooses how many perks a player may hold, from a PERK LIMIT row in the lobby's Match Settings. | `iw-perk-limit.zip` |

**Install:** download the zip from the [releases page](https://github.com/ShawnDuPreez/cb-mods/releases)
and extract it into your game folder, the one that holds `iw7-mod.exe` (in the CB Servers
launcher: Infinite Warfare > Browse Local Files). Start the game, open the Mods menu, pick the
mod, then host a zombies Custom Game. Everyone who joins needs the same mod.

Each zip adds a folder under `mods/`. More Players and Perk Limit also add one small menu
script under `iw7-mod/ui_scripts/`, which only the host uses and which does nothing unless
its mod is the loaded one. Each mod's README says why.

**Status:** the game scripts are tested on a private server with bots on all five zombies
maps. More Players has also been hosted in the real game with a full lobby of bots. All
Perks, the Perk Limit row and the wonder weapons in the wheel are new and had not been seen
in the real game when this was written. Each README has a "What was tested" section that
says exactly what was run.

Other things in `IW/`:

- `tools/`: the scripts used to test the mods on a private server, to check script names
  against a decompile of the game's scripts, and to build `mod.ff` and the release zips.
- `launcher-entries/`: ready-made entries for the CB Servers launcher's mod list.

Zips named under `dist/` in the READMEs are built by each mod's `make-*.sh` scripts and are
not stored in the repository.

## Black Ops 3 (`BO3/`)

[More Players](BO3/more-players/README.md): up to 8 players in one zombies match, with score
rows and revive icons for players 5 to 8. It works on the BOIII client (hosted with 7 bots on
all 14 maps). Not tried with real people in slots 5 to 8, and not built for the Steam game
or the Workshop.

**Install:** download `bo3-more-players.zip` from the
[releases page](https://github.com/ShawnDuPreez/cb-mods/releases) and extract it into your
BOIII game folder, the one that holds `boiii.exe`. Start the game, pick More Players under
Mods, then Zombies > Private Game. Every player needs it.

## License

GPL-3.0, see [LICENSE](LICENSE). Two files in More Players,
`custom_scripts/cp/scoreboard.gsc` and `ui_scripts/ZombiesPlayers/__init__.lua`, come from
[auroramod/iw7-mod](https://github.com/auroramod/iw7-mod) (pull request 714), which is
GPL-3.0 as well.

Four files in the Black Ops 3 mod are the game's own files with a few lines added, which is
how a Black Ops 3 mod changes them: `scripts/zm/_zm_score.gsc`, `scripts/zm/_zm_score.csc`,
`scripts/zm/gametypes/_clientids.gsc` and `ui/t7/utility/codutilityrequire.lua`. Those stay
the game publisher's and the GPL covers only the added lines.
