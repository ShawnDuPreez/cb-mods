-- Runs ui/more_players/more_players.lua against a stand-in for the game's UI
-- functions and checks what it does. Needs Lua 5.1 (the game's Lua is 5.1 based):
--
--     lua5.1 test/lua-mock-test.lua
--
-- The stand-ins copy the behaviour of the game's own Lua as decompiled from the
-- current PC build (github.com/KingslayerKyle/T7LuaRepo, Dumps/PC_Ship_2025-05-31):
-- LobbyData and its read-only wrapper, the two score colour functions, and the
-- co-op scoreboard widget, the score list and the revive icons' surroundings.
-- This proves the mod's logic, not the game's reaction.

local here = arg[0]:match( "^(.*)/[^/]*$" ) or "."
local modRoot = here .. "/../more_players/"

local failures = 0
local checks = 0

local function check( condition, what )
	checks = checks + 1
	if condition then
		print( "  ok    " .. what )
	else
		failures = failures + 1
		print( "  FAIL  " .. what )
	end
end

-- Builds a fresh fake game and loads the mod's Lua into it.
-- options: map, isZombie, screen, host, maxClients = { [lobbyType] = n }, dvars,
--          engineIcons = how many revive icons the engine made itself (default 4),
--          noReviveWidget = the stock revive icon widget is missing
local function load( options )
	local world = {
		screen = options.screen,
		host = options.host,
		maxClients = options.maxClients or {},
		dvars = options.dvars or {},
		required = {},
		setCalls = 0
	}

	local env = setmetatable( {}, { __index = _G } )

	env.Enum = {
		LobbyType = { LOBBY_TYPE_PRIVATE = 0, LOBBY_TYPE_GAME = 1 },
		LobbyMainMode = { LOBBY_MAINMODE_INVALID = -1, LOBBY_MAINMODE_CP = 0, LOBBY_MAINMODE_MP = 1, LOBBY_MAINMODE_ZM = 2 },
		LobbyModule = { LOBBY_MODULE_CLIENT = 1 },
		-- bit numbers; the real ones live in the engine, the mod only reads the names
		BleedOutStateFlags = { BLEEDOUT_STATE_FLAG_BLEEDING_OUT = 1, BLEEDOUT_STATE_FLAG_BEING_REVIVED = 2, BLEEDOUT_STATE_FLAG_CLAMPED = 3 }
	}

	-- lua/Shared/LuaReadOnlyTables.lua
	local function ReadOnlyTable( original )
		local proxy = { _originalTable = original }
		setmetatable( proxy, {
			__index = original,
			__newindex = function ()
				error( "Attempt to modify a value in a readonly table." )
			end
		} )
		return proxy
	end

	-- lua/Shared/LobbyData.lua (the ids and sizes are the game's)
	local targets = {
		UI_MODESELECT = { id = 1, maxClients = 18, mainMode = env.Enum.LobbyMainMode.LOBBY_MAINMODE_INVALID },
		UI_CPLOBBYONLINE = { id = 100, maxClients = 4, mainMode = env.Enum.LobbyMainMode.LOBBY_MAINMODE_CP },
		UI_MPLOBBYONLINE = { id = 201, maxClients = 18, mainMode = env.Enum.LobbyMainMode.LOBBY_MAINMODE_MP },
		UI_ZMLOBBYONLINE = { id = 400, maxClients = 4, mainMode = env.Enum.LobbyMainMode.LOBBY_MAINMODE_ZM },
		UI_ZMLOBBYONLINEPUBLICGAME = { id = 401, maxClients = 4, mainMode = env.Enum.LobbyMainMode.LOBBY_MAINMODE_ZM },
		UI_ZMLOBBYONLINECUSTOMGAME = { id = 402, maxClients = 4, mainMode = env.Enum.LobbyMainMode.LOBBY_MAINMODE_ZM },
		UI_ZMLOBBYONLINETHEATER = { id = 403, maxClients = 1, mainMode = env.Enum.LobbyMainMode.LOBBY_MAINMODE_ZM },
		UI_ZMLOBBYLANGAME = { id = 404, maxClients = 4, mainMode = env.Enum.LobbyMainMode.LOBBY_MAINMODE_ZM }
	}
	env.LobbyData = {
		UITargets = ReadOnlyTable( targets ),
		UITargetFromId = function ( self, id )
			for _, target in pairs( self.UITargets._originalTable ) do
				if target.id == id then
					return target
				end
			end
			return nil
		end
	}

	env.Engine = {
		GetCurrentMap = function ()
			return options.map
		end,
		GetLobbyUIScreen = function ()
			return world.screen
		end,
		IsLobbyActive = function ( lobbyType )
			return world.maxClients[lobbyType] ~= nil
		end,
		IsLobbyHost = function ()
			return world.host
		end,
		-- The game calls this with ( lobbyType ) and with ( module, lobbyType ).
		GetLobbyMaxClients = function ( a, b )
			return world.maxClients[b or a]
		end,
		SetLobbyMaxClients = function ( lobbyType, count )
			world.setCalls = world.setCalls + 1
			world.maxClients[lobbyType] = count
		end,
		DvarInt = function ( _, name )
			return world.dvars[name]
		end,
		SetDvar = function ( name, value )
			world.dvars[name] = value
		end
	}

	-- ui/T6/CoDBase.lua
	env.CoD = { isZombie = options.isZombie, isPC = true,
		OBJECTIVESTATE_EMPTY = 0, OBJECTIVESTATE_ACTIVE = 1, OBJECTIVESTATE_INVISIBLE = 2 }

	-- ui/uieditor/modifyFunctions.lua. Only cg_ScoresColor_Gamertag_0..3 exist
	-- in the game; a setting that does not exist gives no values.
	local stockColours = { [0] = { 1, 1, 1 }, { 0.49, 0.81, 0.93 }, { 0.96, 0.79, 0.31 }, { 0.51, 0.93, 0.53 } }
	env.Dvar = setmetatable( {}, {
		__index = function ( _, name )
			local slot = tonumber( name:match( "^cg_ScoresColor_Gamertag_(%d+)$" ) )
			return {
				get = function ()
					local colour = slot and stockColours[slot]
					if colour then
						return colour[1], colour[2], colour[3], 1
					end
				end
			}
		end
	} )
	local function stockColour( clientNum )
		local r, g, b = env.Dvar["cg_ScoresColor_Gamertag_" .. clientNum].get( env.Dvar["cg_ScoresColor_Gamertag_" .. clientNum] )
		return r, g, b
	end
	local function stockGlowColour( clientNum )
		local r, g, b = env.Dvar["cg_ScoresColor_Gamertag_" .. clientNum].get( env.Dvar["cg_ScoresColor_Gamertag_" .. clientNum] )
		return r * 0.75, g * 0.75, b * 0.75
	end
	local function defineModifyFunctions()
		env.ZombieClientScoreboardColor = stockColour
		env.ZombieClientScoreboardGlowColor = stockGlowColour
	end

	-- ui/uieditor/widgets/Scoreboard/CP/ScoreboardWidgetCP.lua
	local function defineScoreboard()
		env.CoD.ScoreboardWidgetCP = {
			new = function ()
				local list = { rows = 9 }
				function list:setVerticalCount( count )
					self.rows = count
				end
				local widget = { ScoreboardFactionScoresListCP0 = { Team1 = list } }
				widget.ScoreboardFactionScoresListCP0.Team1:setVerticalCount( 4 )
				return widget
			end
		}
	end

	-- ui/uieditor/widgets/HUD/ZM_Score/ZMScr.lua and ZMScr_ListingSm.lua
	world.models = {}
	env.Engine.CreateModel = function ( parent, name )
		local path = ( parent and parent.path .. "." or "" ) .. tostring( name )
		world.models[path] = world.models[path] or { path = path }
		return world.models[path]
	end
	env.Engine.SetModelValue = function ( model, value )
		model.value = value
	end
	env.DataSources = {}

	-- A stand-in for a UI element: keeps what it was told, and its children.
	local function newElement()
		local element = { children = {}, handlers = {}, alpha = 1 }
		function element:setLeftRight() end
		function element:setTopBottom() end
		function element:setScale( scale ) self.scale = scale end
		function element:setAlpha( alpha ) self.alpha = alpha end
		function element:setModel( model ) self.model = model end
		function element:processEvent() end
		function element:registerEventHandler( name, func ) self.handlers[name] = func end
		function element:addElement( child )
			child.parent = self
			child.index = #self.children + 1
			self.children[child.index] = child
		end
		function element:getFirstChild() return self.children[1] end
		function element:getNextSibling() return self.parent and self.parent.children[self.index + 1] or nil end
		function element:setupEntityContainer( objective, x, y, z ) self.pinned = { objective = objective, x = x, y = y, z = z } end
		function element:setEntityContainerClamp( clamp ) self.clamped = clamp end
		return element
	end

	env.LUI = {
		OverrideFunction_CallOriginalSecond = function ( element, name, func )
			local stock = element[name]
			element[name] = function ( ... )
				func( ... )
				return stock( ... )
			end
		end,
		UIElement = { new = newElement },
		-- a timer is only noted down; world.fire() plays its event
		UITimer = {
			new = function ( interval, event, oneShot, target )
				local timer = newElement()
				timer.isTimer, timer.interval, timer.event, timer.oneShot, timer.target = true, interval, event.name, oneShot, target
				return timer
			end
		}
	}

	-- world objectives, as the server script sets them: [number] = { state, x, y, z, progress }
	world.objectives = {}
	env.Engine.GetObjectiveState = function ( _, objective )
		local entry = world.objectives[objective]
		return entry and entry.state or env.CoD.OBJECTIVESTATE_EMPTY
	end
	env.Engine.GetObjectivePosition = function ( _, objective )
		local entry = world.objectives[objective]
		if entry then
			return entry.x, entry.y, entry.z
		end
	end
	env.Engine.GetObjectiveProgress = function ( _, objective )
		local entry = world.objectives[objective]
		return entry and entry.progress or 0
	end
	env.Engine.GetGamertagForClient = function ( _, client )
		return "player" .. client
	end

	-- ui/uieditor/menus/hud/T7Hud_ZM.lua: the HUD, its full-screen container and
	-- the revive icons the engine made (it stops after four)
	world.newHud = function ()
		local hud = newElement()
		hud.fullscreenContainer = newElement()
		for client = 0, ( options.engineIcons or 4 ) - 1 do
			local stockIcon = newElement()
			stockIcon.bleedOutClient = client
			stockIcon.id = "bleedOutItem" .. client
			hud.fullscreenContainer:addElement( stockIcon )
		end
		return hud
	end
	-- the timers on an element waiting to send this event
	world.timers = function ( element, name )
		local found = {}
		for _, child in ipairs( element.children ) do
			if child.isTimer and child.event == name then
				found[#found + 1] = child
			end
		end
		return found
	end
	world.fire = function ( element, name )
		element.handlers[name]()
	end
	env.DataSources.WorldSpaceIndicators = {
		getModel = function ()
			return env.Engine.CreateModel( nil, "WorldSpaceIndicators" )
		end
	}
	if not options.noReviveWidget then
		env.CoD.ZM_Revive = { new = newElement }
	end
	local function defineScoreList()
		env.DataSources.ZMPlayerList = {
			getModel = function ()
				return env.Engine.CreateModel( nil, "PlayerList" )
			end
		}
		env.CoD.ZMScr_ListingSm = {
			new = function ()
				if options.rowsFail then
					error( "row widget failed" )
				end
				local row = { alpha = 1, closed = false }
				function row:setLeftRight( _, _, left, right ) self.left, self.right = left, right end
				function row:setTopBottom( _, _, top, bottom ) self.top, self.bottom = top, bottom end
				function row:setAlpha( alpha ) self.alpha = alpha end
				function row:completeAnimation() end
				function row:subscribeToGlobalModel( _, source, place ) self.source, self.place = source, place end
				function row:setModel() end
				function row:close() self.closed = true end
				return row
			end
		}
		env.CoD.ZMScr = {
			new = function ()
				local widget = { children = {}, closed = false, stockAlpha = 0 }
				function widget:addElement( child ) self.children[#self.children + 1] = child end
				function widget:close() self.closed = true end
				widget.clipsPerState = {
					DefaultState = {
						DefaultClip = function () widget.stockAlpha = 0 end,
						HudStart = function () widget.stockAlpha = 1 end
					},
					HudStart = {
						DefaultClip = function () widget.stockAlpha = 1 end,
						DefaultState = function () widget.stockAlpha = 0 end
					}
				}
				return widget
			end
		}
	end

	env.require = function ( name )
		world.required[#world.required + 1] = name
		if name == "ui.uieditor.widgets.HUD.ZM_Score.ZMScr" and env.CoD.ZMScr == nil then
			defineScoreList()
		end
		if name == "ui.uieditor.modifyFunctions" and env.ZombieClientScoreboardColor == nil then
			defineModifyFunctions()
		elseif name == "ui.uieditor.widgets.Scoreboard.CP.ScoreboardWidgetCP" and env.CoD.ScoreboardWidgetCP == nil then
			if options.scoreboardLoadsLate then
				error( "not loadable yet" )
			end
			defineScoreboard()
		end
	end

	world.defineScoreboard = defineScoreboard
	world.stockGlowColour = stockGlowColour

	local chunk = assert( loadfile( modRoot .. "ui/more_players/more_players.lua" ) )
	setfenv( chunk, env )
	chunk()

	world.env = env
	world.targets = targets
	return world
end

local PRIVATE, GAME = 0, 1

print( "lobby table (menus)" )
do
	local w = load( { map = "core_frontend", isZombie = false, screen = 1, host = true, maxClients = { [PRIVATE] = 18 } } )
	check( w.targets.UI_ZMLOBBYONLINE.maxClients == 8, "online zombies lobby is 8" )
	check( w.targets.UI_ZMLOBBYONLINECUSTOMGAME.maxClients == 8, "custom game zombies lobby is 8" )
	check( w.targets.UI_ZMLOBBYLANGAME.maxClients == 8, "LAN zombies lobby is 8" )
	check( w.targets.UI_ZMLOBBYONLINEPUBLICGAME.maxClients == 8, "public zombies lobby is 8" )
	check( w.targets.UI_ZMLOBBYONLINETHEATER.maxClients == 1, "zombies theater stays 1" )
	check( w.targets.UI_CPLOBBYONLINE.maxClients == 4, "campaign lobby stays 4" )
	check( w.targets.UI_MPLOBBYONLINE.maxClients == 18, "multiplayer lobby stays 18" )
	check( w.env.Engine.GetLobbyMaxClients( PRIVATE ) == 18 and w.setCalls == 0, "mode select screen: lobby size untouched" )
end

print( "lobby size (host in a zombies lobby)" )
do
	local w = load( { map = "core_frontend", isZombie = true, screen = 400, host = true,
		maxClients = { [PRIVATE] = 4, [GAME] = 4 }, dvars = { party_maxplayers = 4, com_maxclients = 4 } } )
	check( w.maxClients[PRIVATE] == 8 and w.maxClients[GAME] == 8, "both lobbies raised to 8 as soon as the mod's Lua loads" )
	check( w.dvars.party_maxplayers == 8 and w.dvars.com_maxclients == 8, "party_maxplayers and com_maxclients raised to 8" )

	-- the lobby VM puts 4 back when the host moves to another zombies lobby
	w.screen = 402
	w.maxClients[GAME] = 4
	check( w.env.Engine.GetLobbyMaxClients( GAME ) == 8, "raised again after the game resets it on a screen change" )
	check( w.env.Engine.GetLobbyMaxClients( 1, GAME ) == 8, "two-argument form of GetLobbyMaxClients still answers" )

	-- PLAYER LIMIT under Social > Party
	w.env.Engine.SetLobbyMaxClients( GAME, 3 )
	check( w.env.Engine.GetLobbyMaxClients( GAME ) == 3, "a limit the host picks is kept" )
	w.screen = 400
	w.maxClients[GAME] = 4
	check( w.env.Engine.GetLobbyMaxClients( GAME ) == 8, "the pick is forgotten when the lobby screen changes" )
	w.screen = 402
	w.maxClients[GAME] = 4
	check( w.env.Engine.GetLobbyMaxClients( GAME ) == 8, "and stays forgotten on coming back to the screen it was made on" )

	local before = w.setCalls
	w.env.Engine.GetLobbyMaxClients( GAME )
	w.env.Engine.GetLobbyMaxClients( GAME )
	check( w.setCalls == before, "nothing is set again once the lobby is 8" )
end

print( "lobby size (not the host, or not zombies)" )
do
	local w = load( { map = "core_frontend", isZombie = true, screen = 400, host = false,
		maxClients = { [PRIVATE] = 4, [GAME] = 4 }, dvars = { party_maxplayers = 4, com_maxclients = 4 } } )
	check( w.env.Engine.GetLobbyMaxClients( GAME ) == 4 and w.setCalls == 0, "a joiner never sets the lobby size" )

	w = load( { map = "core_frontend", isZombie = false, screen = 100, host = true,
		maxClients = { [PRIVATE] = 4, [GAME] = 4 }, dvars = { party_maxplayers = 4, com_maxclients = 4 } } )
	check( w.env.Engine.GetLobbyMaxClients( GAME ) == 4 and w.setCalls == 0, "campaign lobby is left at 4" )
	check( w.dvars.com_maxclients == 4, "campaign com_maxclients is left at 4" )

	w = load( { map = "core_frontend", isZombie = false, screen = 201, host = true,
		maxClients = { [PRIVATE] = 18, [GAME] = 12 }, dvars = { party_maxplayers = 18, com_maxclients = 18 } } )
	check( w.env.Engine.GetLobbyMaxClients( GAME ) == 12 and w.setCalls == 0, "multiplayer lobby is left alone" )
end

print( "HUD score colours (in a match)" )
do
	local w = load( { map = "zm_factory", isZombie = true, screen = 402, host = true,
		maxClients = { [PRIVATE] = 8, [GAME] = 8 }, dvars = { party_maxplayers = 8, com_maxclients = 8 } } )

	local stockFails = not pcall( w.stockGlowColour, 5 )
	check( stockFails, "the stock glow colour function fails for slot 5 (the bug)" )

	local r, g, b = w.env.ZombieClientScoreboardColor( 2 )
	check( r == 0.96 and g == 0.79 and b == 0.31, "slot 2 keeps the game's own colour" )
	r, g, b = w.env.ZombieClientScoreboardGlowColor( 0 )
	check( r == 0.75 and g == 0.75 and b == 0.75, "slot 0 keeps the game's own glow colour" )

	local allFine = true
	local seen = {}
	for slot = 4, 7 do
		local ok, cr, cg, cb = pcall( w.env.ZombieClientScoreboardColor, slot )
		local ok2, gr, gg, gb = pcall( w.env.ZombieClientScoreboardGlowColor, slot )
		if not ( ok and ok2 and type( cr ) == "number" and type( cg ) == "number" and type( cb ) == "number"
			and gr == cr * 0.75 and gg == cg * 0.75 and gb == cb * 0.75 ) then
			allFine = false
		end
		seen[cr .. "/" .. cg .. "/" .. cb] = true
	end
	check( allFine, "slots 4 to 7 get a colour and a glow colour, no error" )
	local distinct = 0
	for _ in pairs( seen ) do
		distinct = distinct + 1
	end
	check( distinct == 4, "slots 4 to 7 get four different colours" )
	check( pcall( w.env.ZombieClientScoreboardColor, 11 ), "a slot above 7 still does not error" )
end

print( "scoreboard rows" )
do
	local w = load( { map = "zm_factory", isZombie = true, screen = 402, host = true,
		maxClients = { [GAME] = 8 }, dvars = { party_maxplayers = 8, com_maxclients = 8 } } )
	local widget = w.env.CoD.ScoreboardWidgetCP.new()
	check( widget.ScoreboardFactionScoresListCP0.Team1.rows == 8, "scoreboard list shows 8 rows in a zombies match" )

	-- the widget can not be loaded early: patched when the HUD asks for a colour
	w = load( { map = "zm_factory", isZombie = true, screen = 402, host = true, scoreboardLoadsLate = true,
		maxClients = { [GAME] = 8 }, dvars = { party_maxplayers = 8, com_maxclients = 8 } } )
	check( w.env.CoD.ScoreboardWidgetCP == nil, "a scoreboard that will not load early is left alone" )
	w.defineScoreboard()
	w.env.ZombieClientScoreboardColor( 0 )
	widget = w.env.CoD.ScoreboardWidgetCP.new()
	check( widget.ScoreboardFactionScoresListCP0.Team1.rows == 8, "and is patched later, once the game has loaded it" )

	w = load( { map = "core_frontend", isZombie = true, screen = 400, host = true,
		maxClients = { [PRIVATE] = 4 }, dvars = { party_maxplayers = 4, com_maxclients = 4 } } )
	local touched = false
	for _, name in ipairs( w.required ) do
		if name:find( "Scoreboard" ) then
			touched = true
		end
	end
	check( not touched, "the scoreboard is not loaded in the menus" )
end

print( "score list rows" )
do
	local w = load( { map = "zm_factory", isZombie = true, screen = 402, host = true,
		maxClients = { [GAME] = 8 }, dvars = { party_maxplayers = 8, com_maxclients = 8 } } )
	local widget = w.env.CoD.ZMScr.new()
	local rows = widget.morePlayersRows or {}
	check( #rows == 4 and #widget.children == 4, "four rows are added to the stock score list" )

	local places, tops, hidden = {}, {}, true
	for i, row in ipairs( rows ) do
		places[i] = row.place
		tops[i] = row.top
		if row.alpha ~= 0 or row.source ~= "ZMPlayerList" or row.bottom - row.top ~= 35 then
			hidden = false
		end
	end
	check( table.concat( places, "," ) == "4,5,6,7", "they show places 4 to 7 of the player list" )
	check( table.concat( tops, "," ) == "-26,-52,-78,-104", "they stack upwards, 26 apart like the stock rows" )
	check( hidden, "they start hidden, as the stock rows do" )
	check( w.models["PlayerList.4.zombieInventoryIcon"] ~= nil and w.models["PlayerList.7.zombieWearableIcon"] ~= nil
		and w.models["PlayerList.4.zombieInventoryIcon"].value == "blacktransparent", "places 4 to 7 get the stock starting icons" )

	local follows = true
	for _, step in ipairs( { { "DefaultState", "HudStart" }, { "HudStart", "DefaultClip" }, { "HudStart", "DefaultState" }, { "DefaultState", "DefaultClip" } } ) do
		widget.clipsPerState[step[1]][step[2]]()
		for _, row in ipairs( rows ) do
			if row.alpha ~= widget.stockAlpha then
				follows = false
			end
		end
	end
	check( follows, "they fade in and out with the stock rows" )

	widget:close()
	local allClosed = widget.closed
	for _, row in ipairs( rows ) do
		allClosed = allClosed and row.closed
	end
	check( allClosed, "closing the score list closes them too" )

	w = load( { map = "zm_factory", isZombie = true, screen = 402, host = true, rowsFail = true,
		maxClients = { [GAME] = 8 }, dvars = { party_maxplayers = 8, com_maxclients = 8 } } )
	local ok, plain = pcall( w.env.CoD.ZMScr.new )
	check( ok and plain ~= nil and plain.morePlayersRows == nil, "if a row can not be made, the stock score list still comes up" )

	w = load( { map = "core_frontend", isZombie = true, screen = 400, host = true,
		maxClients = { [PRIVATE] = 4 }, dvars = { party_maxplayers = 4, com_maxclients = 4 } } )
	check( w.env.CoD.ZMScr == nil, "the score list is not loaded in the menus" )
end

print( "revive icons for slots 4 to 7" )
do
	local options = { map = "zm_factory", isZombie = true, screen = 402, host = true,
		maxClients = { [GAME] = 8 }, dvars = { party_maxplayers = 8, com_maxclients = 8 } }
	local ACTIVE, INVISIBLE = 1, 2
	local BLEEDING, REVIVING = 2 ^ 1, 2 ^ 2

	local w = load( options )
	local hud = w.newHud()
	w.env.CoD.ZMScr.new( hud, 0 )

	local waiting = w.timers( hud, "more_players_revive" )
	check( #waiting == 1 and waiting[1].oneShot == true and waiting[1].interval == 1000 and #hud.fullscreenContainer.children == 4,
		"building the score list only sets a one-shot timer: the engine's own icons come first" )
	w.env.CoD.ZMScr.new( hud, 0 )
	check( #w.timers( hud, "more_players_revive" ) == 1, "a second score list on the same HUD does not set a second timer" )

	w.fire( hud, "more_players_revive" )
	local icons = {}
	for _, child in ipairs( hud.fullscreenContainer.children ) do
		if child.bleedOutClient ~= nil and child.bleedOutClient >= 4 then
			icons[child.bleedOutClient] = child
		end
	end
	local made = icons[4] ~= nil and icons[5] ~= nil and icons[6] ~= nil and icons[7] ~= nil and #hud.fullscreenContainer.children == 8
	check( made, "one icon each is added for slots 4 to 7, next to the engine's four" )
	check( w.env.CoD.MorePlayers.reviveInfo == "engine has 4, mod added 4", "and the mod notes what it found and added" )

	local hidden, stockInside = made, made
	for client = 4, 7 do
		local icon = icons[client]
		if icon == nil or icon.alpha ~= 0 or w.models["WorldSpaceIndicators.bleedOutModel" .. client .. ".stateFlags"].value ~= 0 then
			hidden = false
		end
		if icon == nil or #icon.children ~= 1 or icon.children[1].model ~= icon.model
			or icon.model ~= w.models["WorldSpaceIndicators.bleedOutModel" .. client] then
			stockInside = false
		end
	end
	check( hidden, "they start hidden, with no state set" )
	check( stockInside, "each holds the stock revive widget, fed from that slot's bleedOutModel" )
	check( w.models["WorldSpaceIndicators.bleedOutModel5.playerName"].value == "player5"
		and w.models["WorldSpaceIndicators.bleedOutModel5.prompt"].value == "ZMUI_REVIVE", "the model carries the player's name and the Revive prompt" )

	local ticking = w.timers( hud, "more_players_revive_tick" )
	check( #ticking == 1 and ticking[1].oneShot == false and ticking[1].interval == 100, "one repeating timer keeps them up to date" )

	local flags = w.models["WorldSpaceIndicators.bleedOutModel5.stateFlags"]
	local clock = w.models["WorldSpaceIndicators.bleedOutModel5.clockPercent"]

	w.fire( hud, "more_players_revive_tick" )
	check( icons[5].alpha == 0 and icons[5].pinned == nil, "nobody down: nothing shows" )

	-- the server script marks slot 5 (objective 116 + 5) as down
	w.objectives[121] = { state = ACTIVE, x = 100, y = 200, z = 300, progress = 0 }
	w.fire( hud, "more_players_revive_tick" )
	check( icons[5].alpha == 1 and flags.value == BLEEDING, "slot 5 goes down: its icon shows as bleeding out" )
	check( icons[5].pinned ~= nil and icons[5].pinned.objective == 121 and icons[5].pinned.x == 100 and icons[5].pinned.y == 200
		and icons[5].pinned.z == 340 and icons[5].clamped == true, "pinned above the player, kept on screen at the edge" )
	check( icons[4].alpha == 0 and icons[6].alpha == 0 and icons[7].alpha == 0, "the other slots stay hidden" )
	check( w.env.CoD.MorePlayers.reviveShown[5] == true and not w.env.CoD.MorePlayers.reviveReviving[5], "the mod notes slot 5 as shown, not being revived" )

	w.objectives[121].x = 150
	w.fire( hud, "more_players_revive_tick" )
	check( icons[5].pinned.x == 150, "the icon follows when the downed player is moved" )

	w.objectives[121].progress = 0.5
	w.fire( hud, "more_players_revive_tick" )
	check( flags.value == BLEEDING + REVIVING and clock.value == 0.5, "somebody starts reviving: the icon switches to being revived, ring half full" )
	check( w.env.CoD.MorePlayers.reviveReviving[5] == true, "the mod notes slot 5 as being revived" )
	w.objectives[121].progress = 0.8
	w.fire( hud, "more_players_revive_tick" )
	check( clock.value == 0.8, "the ring keeps filling as the revive goes on" )

	w.objectives[121].progress = 0
	w.fire( hud, "more_players_revive_tick" )
	check( icons[5].alpha == 1 and flags.value == BLEEDING, "the reviver lets go: back to bleeding out" )

	w.objectives[121].state = INVISIBLE
	w.fire( hud, "more_players_revive_tick" )
	check( icons[5].alpha == 0 and flags.value == 0 and w.env.CoD.MorePlayers.reviveShown[5] == false, "revived or bled out: the icon goes away" )

	w.objectives[123] = { state = ACTIVE, x = 1, y = 2, z = 3, progress = 0 }
	w.objectives[120] = { state = ACTIVE, x = 4, y = 5, z = 6, progress = 0 }
	w.fire( hud, "more_players_revive_tick" )
	check( icons[7].alpha == 1 and icons[4].alpha == 1 and icons[5].alpha == 0 and icons[6].alpha == 0
		and icons[7].pinned.objective == 123 and icons[4].pinned.objective == 120, "two players down at once each get their own icon" )

	-- an engine that looks after more slots itself must not get a second icon for them
	local five = { engineIcons = 5 }
	for key, value in pairs( options ) do
		five[key] = value
	end
	w = load( five )
	hud = w.newHud()
	w.env.CoD.ZMScr.new( hud, 0 )
	w.fire( hud, "more_players_revive" )
	check( #hud.fullscreenContainer.children == 8 and w.env.CoD.MorePlayers.reviveInfo == "engine has 5, mod added 3",
		"a slot the engine already has an icon for is left to the engine" )

	local none = { noReviveWidget = true }
	for key, value in pairs( options ) do
		none[key] = value
	end
	w = load( none )
	hud = w.newHud()
	local ok, widget = pcall( w.env.CoD.ZMScr.new, hud, 0 )
	local fired = ok and pcall( w.fire, hud, "more_players_revive" )
	check( ok and widget ~= nil and fired and #hud.fullscreenContainer.children == 4 and #w.timers( hud, "more_players_revive_tick" ) == 0,
		"without the stock revive widget nothing is added and nothing breaks" )
end

print( "" )
if failures == 0 then
	print( "ALL PASSED (" .. checks .. " checks)" )
	os.exit( 0 )
end
print( failures .. " of " .. checks .. " checks FAILED" )
os.exit( 1 )
