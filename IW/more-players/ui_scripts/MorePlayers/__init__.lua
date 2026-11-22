-- More Players: menu and HUD side of the mod. Every player needs this file,
-- not only the host.
--
--   1. Zombies lobbies hold 8 players instead of 4.
--   2. Players in slot 5 and up get their own character portrait.
--   3. Creates the two dvars the host sends HUD data in.

local MAX_PLAYERS = 8

-- The zombies main menu sets party_maxplayers to 4 every time it opens.
-- Solo sets it to 1 and is left alone.
local set_dvar_int = Engine.SetDvarInt
Engine.SetDvarInt = function(name, value, ...)
	if name == "party_maxplayers" and value == 4 and Engine.IsAliensMode() then
		value = MAX_PLAYERS
	end
	return set_dvar_int(name, value, ...)
end

-- The host sends two strings with setclientdvar. The client only accepts a
-- value for a dvar that already exists by name:
--   ui_cp_scoreboard  every player's stats (read by iw7-mod's ZombiesPlayers)
--   ui_cp_characters  "slot:portrait slot:portrait" for slots 4 and up
-- iw7-mod registers the first one itself in builds that ship ZombiesPlayers.
local function ensure_dvar(name)
	local value = Engine.GetDvarString(name)
	if value == nil or value == "" then
		Engine.Exec("set " .. name .. " \"\"")
	end
end

ensure_dvar("ui_cp_scoreboard")
ensure_dvar("ui_cp_characters")

-- ZombiesPlayers looks up each player's microphone state with the multiplayer
-- scoreboard call, once per scoreboard row, about once a second. In zombies
-- that call fails for most rows. The failure is caught, but the client writes
-- a blank error line to the log every time: about 15 a second with 8 players.
-- While a slot above 3 is in the game the call is skipped, and the scoreboard
-- shows no microphone icons. With 4 players or fewer nothing changes.
local function has_high_slot()
	for index = 0, Game.GetNumPlayersOnTeam(Teams.allies) - 1 do
		if Game.GetTeamPlayerAtIndex(Teams.allies, index) > 3 then
			return true
		end
	end
	return false
end

local scoreboard_row = Game.GetScoreboardRowData
if type(scoreboard_row) == "function" then
	Game.GetScoreboardRowData = function(...)
		if Engine.IsAliensMode() and not Engine.InFrontend() and has_high_slot() then
			return nil
		end
		return scoreboard_row(...)
	end
end

if type(ZombiesUtils) ~= "table" then
	return
end

-- Portraits. The game keeps every player's character in one number, 3 bits
-- per slot, with room for slots 0 to 3. For a higher slot those bits are
-- always 0, which is the first character. The host sends the real portrait
-- index for those slots in ui_cp_characters.
local function extra_portrait(client)
	for slot, index in string.gmatch(Engine.GetDvarString("ui_cp_characters") or "", "(%d+):(%d+)") do
		if tonumber(slot) == client then
			return tonumber(index)
		end
	end
	return nil
end

-- Both stock functions read 3 bits at client * 3. Handing them the portrait
-- index as the whole number, with client 0, makes them read exactly it.
local player_photo = ZombiesUtils.GetZombiesPlayerPhoto
if type(player_photo) == "function" then
	ZombiesUtils.GetZombiesPlayerPhoto = function(characters, statuses, client)
		if type(client) == "number" and client > 3 then
			local index = extra_portrait(client)
			if index then
				return player_photo(index, 0, 0)
			end
		end
		return player_photo(characters, statuses, client)
	end
end

local big_photo = ZombiesUtils.GetZombiesBigPhoto
if type(big_photo) == "function" then
	ZombiesUtils.GetZombiesBigPhoto = function(characters, client)
		if type(client) == "number" and client > 3 then
			local index = extra_portrait(client)
			if index then
				return big_photo(index, 0)
			end
		end
		return big_photo(characters, client)
	end
end
