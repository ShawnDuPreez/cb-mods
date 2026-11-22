-- Test aid for the BOIII client, not part of the mod. test/bot-test.sh copies it to
-- <game>/boiii/ui_scripts/zz_mp_autostart/__init__.lua.
--
-- It does what a person would do with the keyboard, so a test needs no typing
-- into the game window:
--   in the menus: Zombies > Private Game > pick the map > Start Game
--   anywhere:     quit the game when the test script sets mpdbg_quit to 1
--
-- It only acts when the game was started with +set mpdbg_map <map>.
-- Lines it prints start with MPDBG-UI and land in the game's console log.

local map = Engine.DvarString( nil, "mpdbg_map" )

if map == nil or map == "" then
	return
end

local function say( text )
	print( "MPDBG-UI " .. text )
end

local function root()
	if LUI == nil or LUI.roots == nil then
		return nil
	end
	return LUI.roots.UIRootFull or LUI.roots.UIRoot0
end

-- calls func every interval milliseconds until it returns true
local function every( interval, name, func )
	local element = root()
	if element == nil then
		say( "no UI root for " .. name )
		return
	end

	local timer
	element:registerEventHandler( name, function ()
		local ok, done = pcall( func )
		if not ok then
			say( name .. " failed: " .. tostring( done ) )
		end
		if ( not ok or done ) and timer ~= nil then
			timer:close()
			timer = nil
		end
	end )

	timer = LUI.UITimer.new( interval, { name = name }, false, element )
	element:addElement( timer )
end

-- the open menu with this name, or nil
local function findMenu( wanted )
	if LUI == nil or LUI.roots == nil then
		return nil
	end
	for _, element in pairs( LUI.roots ) do
		local child = element.getFirstChild ~= nil and element:getFirstChild() or nil
		while child ~= nil do
			if child.menuName == wanted then
				return child
			end
			child = child:getNextSibling()
		end
	end
	return nil
end

local function lobbySizes()
	local private = Engine.GetLobbyMaxClients( Enum.LobbyType.LOBBY_TYPE_PRIVATE )
	local game = Engine.GetLobbyMaxClients( Enum.LobbyType.LOBBY_TYPE_GAME )
	return "privateMax=" .. tostring( private ) .. " gameMax=" .. tostring( game )
		.. " party_maxplayers=" .. tostring( Engine.DvarInt( nil, "party_maxplayers" ) )
		.. " com_maxclients=" .. tostring( Engine.DvarInt( nil, "com_maxclients" ) )
end

-- quit on request, in the menus and in a match
every( 2000, "mpdbg_quit_check", function ()
	if Engine.DvarInt( nil, "mpdbg_quit" ) == 1 then
		say( "quitting" )
		Engine.Exec( Engine.GetPrimaryController(), "quit" )
		return true
	end
	return false
end )

if Engine.GetCurrentMap() ~= "core_frontend" then
	say( "in match on " .. tostring( Engine.GetCurrentMap() ) .. " " .. lobbySizes() )

	-- pass what the mod's Lua noted about itself on to the debug script, which logs it
	every( 1000, "mpdbg_ui_info", function ()
		if CoD.MorePlayers ~= nil and CoD.MorePlayers.reviveInfo ~= nil then
			local shown = ""
			for client = 0, 17 do
				if CoD.MorePlayers.reviveShown ~= nil and CoD.MorePlayers.reviveShown[client] then
					shown = shown .. client
					if CoD.MorePlayers.reviveReviving ~= nil and CoD.MorePlayers.reviveReviving[client] then
						shown = shown .. "(being revived)"
					end
					shown = shown .. " "
				end
			end
			Engine.SetDvar( "mpdbg_ui", "revive icons: " .. CoD.MorePlayers.reviveInfo .. "; mod's icon showing for slots: " .. shown
				.. "; last pinned: " .. tostring( CoD.MorePlayers.reviveDetail ) )
		end
		return false
	end )
	return
end

if Engine.DvarInt( nil, "mpdbg_launched" ) == 1 then
	-- back in the menus after the match: nothing more to do but quit
	say( "back in the menus after the match " .. lobbySizes() )
	Engine.SetDvar( "mpdbg_quit", 1 )
	return
end

-- +set mpdbg_mod <folder>: load that mod from <game>/mods first, as the Mods menu
-- would. Loading a mod restarts the menus, so this script then runs again.
local mod = Engine.DvarString( nil, "mpdbg_mod" )
local modAsked = false

local waited = 0
local onMain = 0

every( 3000, "mpdbg_walk", function ()
	local controller = Engine.GetPrimaryController()
	local target = LobbyData:UITargetFromId( Engine.GetLobbyUIScreen() )
	local name = target and target.name or "?"

	if LuaUtils.LobbyProcessQueueEmpty ~= nil and not LuaUtils.LobbyProcessQueueEmpty() then
		return false
	end

	say( "screen=" .. name .. " " .. lobbySizes() )

	if name == "Main" then
		-- The "Press ENTER to Start" screen. Do what ENTER does there
		-- (ui/uieditor/menus/Main.lua): sign in, then begin play. Going
		-- straight to the next menu instead skips the sign-in and leaves the
		-- game offline, where it unloads any mod. The menus also pass through
		-- this screen by themselves, so only act when it stays up.
		onMain = onMain + 1
		if onMain >= 3 and not Engine.IsCinematicPlaying() then
			local menu = findMenu( "Main" )
			if menu ~= nil and ( Engine.LiveIsControllerSignedIn( controller ) or Engine.SignIntoPlatformLiveSystem( controller ) ) then
				onMain = 0
				say( "starting from the title screen" )
				LobbyBeginPlay( menu, controller )
			end
		end
		return false
	end
	onMain = 0

	if mod ~= nil and mod ~= "" and not Mods_IsUsingMods() then
		if not modAsked and name == "ModeSelect" then
			modAsked = true
			say( "loading mod " .. mod )
			Engine.LobbyVM_CallFunc( "LoadMod", { ugcName = mod, ugcType = LuaEnums.MODS_BASE_PATH, ugcVersion = 1 } )
		end
		return false
	end

	if name == "ModeSelect" then
		Engine.LobbyVM_CallFunc( "GoForward", { controller = controller, navToMenu = "ZMLobbyOnline" } )
	elseif name == "ZMLobbyOnline" then
		Engine.LobbyVM_CallFunc( "GoForward", { controller = controller, navToMenu = "ZMLobbyOnlineCustomGame" } )
	elseif name == "ZMLobbyOnlineCustomGame" then
		-- give the menus one more round to settle, and the mod's Lua time to size the lobby
		waited = waited + 1
		if waited >= 2 then
			Engine.GameLobbySetMap( map )
			Engine.SetDvar( "ui_mapname", map )
			Engine.SetDvar( "mpdbg_launched", 1 )
			say( "launching " .. map .. " " .. lobbySizes() )
			Engine.LobbyVM_CallFunc( "LaunchGame", { controller = controller, lobbyType = Enum.LobbyType.LOBBY_TYPE_GAME } )
			return true
		end
	end

	return false
end )
