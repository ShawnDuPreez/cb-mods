-- Runs ui_scripts/MorePlayersLobby/__init__.lua against stand-ins for the
-- game's functions and checks when it turns the lobby size 4 into 8.
--
--   lua5.1 test/lobby-lua-test.lua
--
-- This can not show whether the real game loads the script. Only the game can.

local here = (arg[0] or ""):match("^(.*)/[^/]*$") or "."
local script_path = arg[1] or (here .. "/../ui_scripts/MorePlayersLobby/__init__.lua")
local checks, failures = 0, 0

local function check(name, got, want)
	checks = checks + 1
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	end
end

-- Loads the script into a pretend game and returns what a menu's
-- Engine.SetDvarInt(name, value) call ends up setting.
local function new_game(fs_game, zombies)
	local game = { fs_game = fs_game, zombies = zombies, set = {}, extra = nil }
	local env = setmetatable({}, { __index = _G })
	env.Engine = {
		GetDvarString = function(name)
			if name == "fs_game" then return game.fs_game end
			return ""
		end,
		IsAliensMode = function() return game.zombies end,
		SetDvarInt = function(name, value, more)
			game.set[name] = value
			game.extra = more
			return "result"
		end,
	}
	local chunk = assert(loadfile(script_path))
	setfenv(chunk, env)
	chunk()
	game.call = function(name, value, more)
		return env.Engine.SetDvarInt(name, value, more)
	end
	return game
end

do
	local game = new_game("mods/more_players", true)
	check("mod loaded: returns what the game returns", game.call("party_maxplayers", 4), "result")
	check("mod loaded: lobby of 4 becomes 8", game.set.party_maxplayers, 8)
	game.call("party_maxplayers", 1)
	check("mod loaded: solo stays 1", game.set.party_maxplayers, 1)
	game.call("party_maxplayers", 8)
	check("mod loaded: 8 stays 8", game.set.party_maxplayers, 8)
	game.call("party_maxplayers", 18)
	check("mod loaded: other sizes pass through", game.set.party_maxplayers, 18)
	game.call("some_other_dvar", 4, "x")
	check("mod loaded: other dvars pass through", game.set.some_other_dvar, 4)
	check("extra arguments are passed on", game.extra, "x")
end

do
	local game = new_game("mods/More_Players", true)
	game.call("party_maxplayers", 4)
	check("mod name in other letter case: 8", game.set.party_maxplayers, 8)
end

for _, fs_game in ipairs({ "", "mods/perk_limit", "mods/all_perks" }) do
	local game = new_game(fs_game, true)
	game.call("party_maxplayers", 4)
	check("mod '" .. fs_game .. "' loaded: lobby stays 4", game.set.party_maxplayers, 4)
end

do
	local game = new_game("mods/more_players", false)
	game.call("party_maxplayers", 4)
	check("multiplayer menus: stays 4", game.set.party_maxplayers, 4)
end

do
	-- the mod is picked, then unloaded, while the script stays loaded
	local game = new_game("", true)
	game.call("party_maxplayers", 4)
	check("before picking: 4", game.set.party_maxplayers, 4)
	game.fs_game = "mods/more_players"
	game.call("party_maxplayers", 4)
	check("after picking: 8", game.set.party_maxplayers, 8)
	game.fs_game = ""
	game.call("party_maxplayers", 4)
	check("after unloading: 4", game.set.party_maxplayers, 4)
end

do
	-- fs_game not readable at all
	local game = new_game(nil, true)
	game.call("party_maxplayers", 4)
	check("no fs_game value: stays 4", game.set.party_maxplayers, 4)
end

print(("%d checks, %d failed"):format(checks, failures))
if failures == 0 then
	print("ALL PASSED")
end
os.exit(failures == 0 and 0 or 1)
