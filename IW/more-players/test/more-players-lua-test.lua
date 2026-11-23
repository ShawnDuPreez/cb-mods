-- Runs ui_scripts/MorePlayers/__init__.lua against stand-ins for the game's
-- functions: the lobby size (only with the mod loaded) and the name tag list.
--
--   lua5.1 test/more-players-lua-test.lua
--
-- This can not show whether the real game draws the tags. Only the game can.

local here = (arg[0] or ""):match("^(.*)/[^/]*$") or "."
local script_path = arg[1] or (here .. "/../ui_scripts/MorePlayers/__init__.lua")
local checks, failures = 0, 0

local function check(name, got, want)
	checks = checks + 1
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	end
end

-- opts: fs_game, zombies, frontend, maxclients, prebuilt (nameplate list exists)
local function new_game(opts)
	local game = { set = {}, dvars = { fs_game = opts.fs_game, ui_maxclients = opts.maxclients or 4 } }
	local env = setmetatable({}, { __index = _G })
	local function list(count)
		return { count = count }
	end
	env.LUI = {
		DataSourceFromList = { new = list },
		DataSourceInControllerModel = { new = function(path) return path end },
		DataSourceInGlobalModel = { new = function(path) return path end },
	}
	env.Game = {}
	env.DataSources = { inGame = { MP = { players = {} } } }
	if opts.prebuilt then
		env.DataSources.inGame.MP.players.nameplate = list(4)
	end
	env.Engine = {
		GetDvarString = function(name) return game.dvars[name] end,
		GetDvarInt = function(name) return game.dvars[name] end,
		IsAliensMode = function() return opts.zombies end,
		InFrontend = function() return opts.frontend end,
		Exec = function() end,
		SetDvarInt = function(name, value)
			game.set[name] = value
		end,
	}
	local chunk = assert(loadfile(script_path))
	setfenv(chunk, env)
	chunk()
	game.env = env
	return game
end

-- lobby size
do
	local game = new_game({ fs_game = "mods/more_players", zombies = true, frontend = true })
	game.env.Engine.SetDvarInt("party_maxplayers", 4)
	check("mod loaded: lobby 4 becomes 8", game.set.party_maxplayers, 8)
	game.env.Engine.SetDvarInt("party_maxplayers", 1)
	check("mod loaded: solo stays 1", game.set.party_maxplayers, 1)
end

for _, fs_game in ipairs({ "", "mods/perk_limit" }) do
	local game = new_game({ fs_game = fs_game, zombies = true, frontend = true })
	game.env.Engine.SetDvarInt("party_maxplayers", 4)
	check("mod '" .. fs_game .. "': lobby stays 4", game.set.party_maxplayers, 4)
end

-- name tags: what the menu scripts read
do
	local game = new_game({ fs_game = "", zombies = true, frontend = false, maxclients = 4 })
	check("zombies match: ui_maxclients reads 8", game.env.Engine.GetDvarInt("ui_maxclients"), 8)
	check("zombies match: real dvar unchanged", game.dvars.ui_maxclients, 4)
	check("zombies match: other dvars untouched", game.env.Engine.GetDvarInt("fs_game"), "")
	game.dvars.ui_maxclients = 12
	check("zombies match: larger value kept", game.env.Engine.GetDvarInt("ui_maxclients"), 12)
end

do
	local game = new_game({ fs_game = "", zombies = true, frontend = true, maxclients = 4 })
	check("zombies menus: ui_maxclients stays 4", game.env.Engine.GetDvarInt("ui_maxclients"), 4)
end

do
	local game = new_game({ fs_game = "", zombies = false, frontend = false, maxclients = 12 })
	game.dvars.ui_maxclients = 6
	check("multiplayer match: untouched", game.env.Engine.GetDvarInt("ui_maxclients"), 6)
end

-- name tags: the list itself
do
	local game = new_game({ zombies = true, frontend = false, maxclients = 4, prebuilt = true })
	local list = game.env.DataSources.inGame.MP.players.nameplate
	check("list built before load: rebuilt for 8", list.count, 8)
	local entry = list.MakeDataSourceAtIndex(list, 6, 0)
	check("entry 6 name model", entry.name, "cg.players.nameplate.name.6")
	check("entry 6 health model", entry.health, "cg.players.nameplate.health.6")
end

do
	local game = new_game({ zombies = true, frontend = false, maxclients = 4, prebuilt = false })
	check("list not built yet: left for the game", game.env.DataSources.inGame.MP.players.nameplate, nil)
end

do
	local game = new_game({ zombies = true, frontend = true, maxclients = 4, prebuilt = true })
	check("menus: list untouched", game.env.DataSources.inGame.MP.players.nameplate.count, 4)
end

print(("%d checks, %d failed"):format(checks, failures))
if failures == 0 then
	print("ALL PASSED")
end
os.exit(failures == 0 and 0 or 1)
