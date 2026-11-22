-- More Players: the host's lobby script, for the mod picked in the Mods menu.
--
-- Right after a mod is picked, the game runs nothing from the mod's folder and
-- starts its menus before the mod's mod.ff is ready. ui_scripts/MorePlayers,
-- which is packed in mod.ff and makes the zombies lobby hold 8, is therefore
-- missing from the menus until one match has been played, and the first match
-- after picking the mod started with 4 slots.
--
-- This file sits in the game's own iw7-mod/ui_scripts folder on the host's
-- PC, which the menus do load from at that moment. It does the one thing the
-- lobby needs and nothing else. It does nothing unless More Players is the
-- loaded mod, so it can stay installed for good.
--
-- Not needed with the always-on files: there ui_scripts/MorePlayers itself is
-- in iw7-mod/ui_scripts.

local MAX_PLAYERS = 8

local function mod_loaded()
	local loaded = string.lower(Engine.GetDvarString("fs_game") or "")
	return string.find(loaded, "more_players", 1, true) ~= nil
end

-- The zombies main menu sets party_maxplayers to 4 every time it opens.
-- Solo sets it to 1 and is left alone. Once mod.ff's own script is loaded as
-- well it does the same change first; this one then sees 8 and passes it on.
local set_dvar_int = Engine.SetDvarInt
Engine.SetDvarInt = function(name, value, ...)
	if name == "party_maxplayers" and value == 4 and Engine.IsAliensMode() and mod_loaded() then
		value = MAX_PLAYERS
	end
	return set_dvar_int(name, value, ...)
end
