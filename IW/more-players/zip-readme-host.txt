More Players - the host's lobby script (Infinite Warfare, iw7-mod)
==================================================================

This goes with the MORE_PLAYERS mod (more_players.zip). Only the player who
hosts needs it. Friends who join need only the mod.

Why: right after you pick a mod in the game's Mods menu, the game does not run
anything from that mod until a match has been played. Without this file the
first match after picking MORE_PLAYERS starts with 4 slots, and only the
second one with 8. This small file sits in the game's own iw7-mod folder
instead, so the lobby holds 8 from the first match. It does nothing while any
other mod, or no mod, is loaded.

Install
-------
1. Open your game folder, the one that holds iw7-mod.exe.
   In the CB Servers launcher: Infinite Warfare > Browse Local Files.
2. Extract this zip into that folder.
   It adds one file inside the iw7-mod folder that is already there.
3. Start the game, pick MORE_PLAYERS in the Mods menu, then
   Zombies > Custom Game.

Remove
------
Delete these from the game folder:

  iw7-mod\ui_scripts\MorePlayersLobby
  iw7-mod\more-players-host-readme.txt
