-- More Players: menu and HUD side.
--
-- Loaded by the extra line at the end of ui/t7/utility/codutilityrequire.lua,
-- which the game reads both in the menus and at the start of every match.
--
-- Four things live here, because script on the server can not reach them:
--   1. the lobby size (the lobby exists before any map or game script loads),
--   2. the per-player colour of the HUD score, which stock only has for 4 players,
--   3. the number of rows on the scoreboard,
--   4. the number of rows in the score list at the bottom left of the HUD,
--   5. the revive icon above a downed player.
--
-- Everything is wrapped so that a part that fails leaves the game as it was.

if CoD.MorePlayers ~= nil then
	return
end

CoD.MorePlayers = {}

local MorePlayers = CoD.MorePlayers

-- Keep in step with MORE_PLAYERS_MAX in scripts/zm/zm_more_players.gsc.
local MAX_PLAYERS = 8
local STOCK_MAX_PLAYERS = 4

MorePlayers.MAX_PLAYERS = MAX_PLAYERS

local function Try( func, ... )
	local ok, result = pcall( func, ... )
	if ok then
		return result
	end
	return nil
end

--------------------------------------------------------------------------------
-- 1. Lobby size
--------------------------------------------------------------------------------

-- The lobby types zombies uses. Each is 4 in lua/Shared/LobbyData.lua.
local zombiesLobbyNames = {
	"UI_ZMLOBBYONLINE",
	"UI_ZMLOBBYONLINEPUBLICGAME",
	"UI_ZMLOBBYONLINECUSTOMGAME",
	"UI_ZMLOBBYLANGAME"
}

-- This is the menu's copy of the table. The PLAYER LIMIT list under
-- Social > Party is built from it, so that list now goes up to 8.
-- (UITargets is read-only, but only one level deep: its entries are plain tables.)
local function RaiseLobbyTable()
	if LobbyData == nil or LobbyData.UITargets == nil then
		return
	end

	for _, name in ipairs( zombiesLobbyNames ) do
		local target = LobbyData.UITargets[name]
		if target ~= nil and type( target.maxClients ) == "number" and target.maxClients < MAX_PLAYERS then
			target.maxClients = MAX_PLAYERS
		end
	end
end

local function CurrentLobbyScreen()
	return Engine.GetLobbyUIScreen()
end

local function IsZombiesLobby()
	if LobbyData == nil or Enum.LobbyMainMode == nil then
		return false
	end

	local screen = CurrentLobbyScreen()
	if screen == nil then
		return false
	end

	local target = LobbyData:UITargetFromId( screen )
	return target ~= nil and target.mainMode == Enum.LobbyMainMode.LOBBY_MAINMODE_ZM
end

local function RaiseDvar( name )
	local value = Engine.DvarInt( nil, name )
	if type( value ) == "number" and value >= 1 and value < MAX_PLAYERS then
		Engine.SetDvar( name, MAX_PLAYERS )
	end
end

local stockGetLobbyMaxClients = Engine.GetLobbyMaxClients
local stockSetLobbyMaxClients = Engine.SetLobbyMaxClients
local raising = false

-- The lobby itself is opened by the game's second Lua environment (the "lobby
-- VM"), which starts with the game and keeps its own copy of the table with 4
-- in it. A mod is loaded later and can not change that copy. What a mod can do
-- is what the PLAYER LIMIT option does: tell the engine a new size for a lobby
-- this player hosts. So whenever a zombies lobby hosted here is smaller than
-- 8, it is set to 8. A limit the host picks by hand in PLAYER LIMIT is left
-- alone until the lobby screen changes.
local function RaiseLobby()
	if raising or stockGetLobbyMaxClients == nil or stockSetLobbyMaxClients == nil then
		return
	end

	if not IsZombiesLobby() then
		return
	end

	local screen = CurrentLobbyScreen()
	if MorePlayers.pickedOnScreen ~= nil and MorePlayers.pickedOnScreen == screen then
		return
	end
	MorePlayers.pickedOnScreen = nil

	raising = true

	Try( function ()
		-- The lobby VM reads party_maxplayers when it sizes a lobby, and the
		-- match reads com_maxclients. Stock sets both to 4 for zombies.
		RaiseDvar( "party_maxplayers" )
		RaiseDvar( "com_maxclients" )

		for _, lobbyType in ipairs( { Enum.LobbyType.LOBBY_TYPE_PRIVATE, Enum.LobbyType.LOBBY_TYPE_GAME } ) do
			if Engine.IsLobbyActive( lobbyType ) and Engine.IsLobbyHost( lobbyType ) then
				local current = stockGetLobbyMaxClients( lobbyType )
				if type( current ) == "number" and current >= 1 and current < MAX_PLAYERS then
					stockSetLobbyMaxClients( lobbyType, MAX_PLAYERS )
				end
			end
		end
	end )

	raising = false
end

MorePlayers.RaiseLobby = RaiseLobby

-- The menus ask for the lobby size whenever they draw the member list, the
-- start button and the invite prompts, which makes this the place to check it.
-- The answer itself is the engine's own, read after the check.
if stockGetLobbyMaxClients ~= nil then
	Engine.GetLobbyMaxClients = function ( ... )
		Try( RaiseLobby )
		return stockGetLobbyMaxClients( ... )
	end
end

-- The only menu code that sets a lobby size is the PLAYER LIMIT option.
if stockSetLobbyMaxClients ~= nil then
	Engine.SetLobbyMaxClients = function ( ... )
		if not raising then
			MorePlayers.pickedOnScreen = Try( CurrentLobbyScreen )
		end
		return stockSetLobbyMaxClients( ... )
	end
end

--------------------------------------------------------------------------------
-- 2. HUD score colours
--------------------------------------------------------------------------------

-- The score list at the bottom left colours each player with the game setting
-- cg_ScoresColor_Gamertag_<slot>. Only slots 0 to 3 exist. For slot 4 and up
-- the stock function does arithmetic on a missing value, which is a UI error
-- for every player who has such a player in their list (themselves included).
-- Slots 0 to 3 keep the game's own colours.
local extraColours = {
	[4] = { 0.96, 0.58, 0.31 },
	[5] = { 0.93, 0.55, 0.80 },
	[6] = { 0.70, 0.62, 0.95 },
	[7] = { 0.55, 0.90, 0.88 }
}

-- Defined in parts 3 and 4.
local PatchScoreboardRows
local PatchScoreList

local function ExtraColour( clientNum )
	local colour = extraColours[clientNum]
	if colour == nil then
		colour = extraColours[STOCK_MAX_PLAYERS + clientNum % STOCK_MAX_PLAYERS]
	end
	return colour
end

local function PatchScoreColours()
	if MorePlayers.coloursPatched or type( ZombieClientScoreboardColor ) ~= "function" or type( ZombieClientScoreboardGlowColor ) ~= "function" then
		return
	end

	MorePlayers.coloursPatched = true

	local stockColour = ZombieClientScoreboardColor
	local stockGlowColour = ZombieClientScoreboardGlowColor

	ZombieClientScoreboardColor = function ( clientNum )
		-- The HUD is being built when this is called. If the scoreboard could
		-- not be patched at load, this catches it for the next HUD build.
		if not MorePlayers.scoreboardPatched then
			Try( PatchScoreboardRows )
		end
		if not MorePlayers.scoreListPatched then
			Try( PatchScoreList )
		end

		local slot = tonumber( clientNum )
		if slot == nil or slot < STOCK_MAX_PLAYERS then
			return stockColour( clientNum )
		end
		local colour = ExtraColour( slot )
		return colour[1], colour[2], colour[3]
	end

	ZombieClientScoreboardGlowColor = function ( clientNum )
		local slot = tonumber( clientNum )
		if slot == nil or slot < STOCK_MAX_PLAYERS then
			return stockGlowColour( clientNum )
		end
		local colour = ExtraColour( slot )
		return colour[1] * 0.75, colour[2] * 0.75, colour[3] * 0.75
	end
end

--------------------------------------------------------------------------------
-- 3. Scoreboard rows
--------------------------------------------------------------------------------

-- Zombies uses the co-op scoreboard, which cuts its player list to 4 rows.
-- The list itself is built for 9, so 8 fit without moving anything.
-- (The name is declared in part 2, which calls this as a fallback.)
PatchScoreboardRows = function ()
	if MorePlayers.scoreboardPatched or CoD.ScoreboardWidgetCP == nil or type( CoD.ScoreboardWidgetCP.new ) ~= "function" then
		return
	end

	MorePlayers.scoreboardPatched = true

	local stockNew = CoD.ScoreboardWidgetCP.new

	CoD.ScoreboardWidgetCP.new = function ( menu, controller )
		local widget = stockNew( menu, controller )

		Try( function ()
			local scores = widget.ScoreboardFactionScoresListCP0
			if scores ~= nil and scores.Team1 ~= nil then
				scores.Team1:setVerticalCount( MAX_PLAYERS )
			end
		end )

		return widget
	end
end

--------------------------------------------------------------------------------
-- 4. Score list rows
--------------------------------------------------------------------------------

-- The score list at the bottom left (ui/uieditor/widgets/HUD/ZM_Score/ZMScr.lua)
-- is you in the big row plus three fixed small rows, fed from places 1 to 3 of
-- the player list. Places 4 to 7 exist in that list as soon as the match allows
-- 8 players; nothing draws them. This adds four more small rows, stacked upwards
-- with the spacing the stock rows have, and makes them appear and disappear
-- together with the stock ones. A row with no player in it stays invisible, as
-- the stock rows do.
local ROW_STEP = 26
local ROW_HEIGHT = 35
local ROW_LEFT = 16.28
local ROW_RIGHT = 101.28

local function AddScoreRows( widget, menu, controller )
	if widget == nil or CoD.ZMScr_ListingSm == nil or DataSources.ZMPlayerList == nil then
		return
	end

	local playerList = DataSources.ZMPlayerList.getModel( controller )
	local rows = {}

	for place = STOCK_MAX_PLAYERS, MAX_PLAYERS - 1 do
		-- the same starting values the stock widget gives places 0 to 3
		local entry = Engine.CreateModel( playerList, place )
		Engine.SetModelValue( Engine.CreateModel( entry, "zombieInventoryIcon" ), "blacktransparent" )
		Engine.SetModelValue( Engine.CreateModel( entry, "zombieWearableIcon" ), "blacktransparent" )

		local row = CoD.ZMScr_ListingSm.new( menu, controller )
		local top = -ROW_STEP * ( place - STOCK_MAX_PLAYERS + 1 )
		row:setLeftRight( true, false, ROW_LEFT, ROW_RIGHT )
		row:setTopBottom( true, false, top, top + ROW_HEIGHT )
		row:setAlpha( 0 )
		row:subscribeToGlobalModel( controller, "ZMPlayerList", tostring( place ), function ( model )
			row:setModel( model, controller )
		end )
		widget:addElement( row )
		widget["Listing" .. ( place + 1 )] = row
		rows[#rows + 1] = row
	end

	widget.morePlayersRows = rows

	local function setRowsAlpha( alpha )
		for _, row in ipairs( rows ) do
			row:completeAnimation()
			row:setAlpha( alpha )
		end
	end

	-- The widget fades its rows in and out with the rest of the HUD through four
	-- clips. Each is followed here with the value it leaves the stock rows at.
	local clipAlpha = {
		DefaultState = { DefaultClip = 0, HudStart = 1 },
		HudStart = { DefaultClip = 1, DefaultState = 0 }
	}

	if widget.clipsPerState ~= nil then
		for stateName, clips in pairs( clipAlpha ) do
			local stateClips = widget.clipsPerState[stateName]
			if stateClips ~= nil then
				for clipName, alpha in pairs( clips ) do
					local stockClip = stateClips[clipName]
					if type( stockClip ) == "function" then
						stateClips[clipName] = function ( ... )
							stockClip( ... )
							Try( setRowsAlpha, alpha )
						end
					end
				end
			end
		end
	end

	LUI.OverrideFunction_CallOriginalSecond( widget, "close", function ()
		for _, row in ipairs( rows ) do
			row:close()
		end
	end )
end

--------------------------------------------------------------------------------
-- 5. Revive icons
--------------------------------------------------------------------------------

-- The icon above a downed player is drawn by the engine, which keeps four of
-- them and no more: the HUD makes one widget per slot in a loop and the engine
-- stops that loop after the fourth (PostLoadFunc in
-- ui/uieditor/menus/hud/T7Hud_ZM.lua and the per-map HUDs). Widgets made for
-- slots 4 to 7 the same way exist but never light up.
--
-- So for slots 4 to 7 the mod draws the icon itself, from two things it does
-- have on every player's side:
--   where   the server script keeps a world objective at the position of a
--           downed player in one of those slots (objective number =
--           REVIVE_OBJECTIVE_BASE + slot, see zm_more_players.gsc). A widget
--           can be placed on an objective, and the engine then keeps it on
--           screen, at the edge if need be.
--   when    the same objective: the server script switches it on while the
--           player is down and off when they are revived or bleed out.
--   revive  the objective's progress value, which the server script sets to
--           how far a revive in progress has got.
-- What is drawn is the stock icon widget, fed with the same kind of model the
-- engine feeds its own: the mod sets the "bleeding out" and "being revived"
-- flags and the revive progress, and the game's own client script writes the
-- bleed-out time left into bleedOutModel<slot>.bleedOutPercent as soon as that
-- model exists. What is missing compared with the engine's icons: the arrow
-- when the player is off screen (the icon itself still stops at the edge).
local REVIVE_OBJECTIVE_BASE = 116
local REVIVE_HEIGHT = 40
local REVIVE_SCALE = 0.3
local REVIVE_TICK_MS = 100

MorePlayers.reviveShown = {}
MorePlayers.reviveReviving = {}

local function AddReviveIcons( hud, controller )
	local container = hud.fullscreenContainer
	if container == nil or CoD.ZM_Revive == nil or DataSources.WorldSpaceIndicators == nil then
		MorePlayers.reviveInfo = "no container"
		return
	end

	-- the slots the engine already looks after
	local have = {}
	local stock = 0
	local child = container:getFirstChild()
	while child ~= nil do
		if child.bleedOutClient ~= nil then
			have[child.bleedOutClient] = true
			stock = stock + 1
		end
		child = child:getNextSibling()
	end

	local indicators = DataSources.WorldSpaceIndicators.getModel( controller )
	if indicators == nil then
		MorePlayers.reviveInfo = "no indicator model"
		return
	end

	-- stateFlags is a set of bits; these are "bleeding out" and "being revived"
	local bleedingOutFlag = 2 ^ Enum.BleedOutStateFlags.BLEEDOUT_STATE_FLAG_BLEEDING_OUT
	local beingRevivedFlag = 2 ^ Enum.BleedOutStateFlags.BLEEDOUT_STATE_FLAG_BEING_REVIVED
	local added = 0
	local icons = {}

	for client = STOCK_MAX_PLAYERS, MAX_PLAYERS - 1 do
		if not have[client] then
			-- the same model, with the same starting values, as the stock loop makes
			local model = Engine.CreateModel( indicators, "bleedOutModel" .. client )
			Engine.SetModelValue( Engine.CreateModel( model, "playerName" ), Engine.GetGamertagForClient( controller, client ) )
			Engine.SetModelValue( Engine.CreateModel( model, "prompt" ), "ZMUI_REVIVE" )
			local clock = Engine.CreateModel( model, "clockPercent" )
			Engine.SetModelValue( clock, 0 )
			Engine.SetModelValue( Engine.CreateModel( model, "arrowAngle" ), 0 )
			local flags = Engine.CreateModel( model, "stateFlags" )
			Engine.SetModelValue( flags, 0 )
			local percent = Engine.CreateModel( model, "bleedOutPercent" )
			Engine.SetModelValue( percent, 0 )

			local icon = LUI.UIElement.new()
			icon.bleedOutClient = client
			icon.id = "bleedOutItem" .. client
			icon:setLeftRight( true, false, 0, 0 )
			icon:setTopBottom( true, false, 0, 0 )
			icon:setModel( model )
			icon:setAlpha( 0 )

			-- The stock icon itself goes inside: ring, skull, name and prompt,
			-- all fed from the model and switched by its stateFlags.
			local stockIcon = CoD.ZM_Revive.new( hud, controller )
			stockIcon:setLeftRight( true, false, 0, 0 )
			stockIcon:setTopBottom( true, false, 0, 0 )
			stockIcon:setScale( REVIVE_SCALE )
			stockIcon:setModel( model )
			stockIcon:processEvent( { name = "update_state", menu = hud } )
			icon:addElement( stockIcon )
			icon.stockIcon = stockIcon

			local objective = REVIVE_OBJECTIVE_BASE + client
			local shownFlags = 0

			-- Runs several times a second. The server script switches the
			-- objective on while the player is down and off again afterwards.
			icon.morePlayersUpdate = function ()
				local down = Engine.GetObjectiveState( controller, objective ) == CoD.OBJECTIVESTATE_ACTIVE

				if down then
					-- Put the icon where the objective is, the way the stock code
					-- places a marker on an objective that is a point in the world
					-- (ui_mp/T6/HUD/ObjectiveWaypoint.lua). Done on every run, so
					-- the icon follows if the player is moved.
					-- Two things that were tried and do not work here: giving this
					-- call an offset from the objective's entity leaves the icon
					-- at the map's origin, and setupWaypointContainer, which the
					-- newer stock waypoints use, ends in a UI error because the
					-- engine then calls functions a waypoint widget is expected
					-- to have.
					local x, y, z = Engine.GetObjectivePosition( controller, objective )
					if x ~= nil and y ~= nil and z ~= nil then
						icon:setupEntityContainer( objective, x, y, z + REVIVE_HEIGHT )
						icon:setEntityContainerClamp( true )
						-- read by test/zz_mp_autostart.lua
						MorePlayers.reviveDetail = "slot " .. client .. " objective " .. objective .. " at " .. math.floor( x ) .. " " .. math.floor( y ) .. " " .. math.floor( z )
					end
				end

				-- The objective's progress is the revive progress: above zero
				-- means somebody is reviving this player right now.
				local progress = 0
				if down then
					progress = tonumber( Engine.GetObjectiveProgress( controller, objective ) ) or 0
				end

				-- The stock icon keeps all its parts hidden until these flags
				-- are set, which the engine does for its own four icons only.
				local wanted = 0
				if down and progress > 0 then
					wanted = bleedingOutFlag + beingRevivedFlag
					Engine.SetModelValue( clock, progress )
				elseif down then
					wanted = bleedingOutFlag
				end

				if wanted ~= shownFlags then
					shownFlags = wanted
					icon:setAlpha( down and 1 or 0 )
					Engine.SetModelValue( flags, wanted )
					MorePlayers.reviveShown[client] = down
					MorePlayers.reviveReviving[client] = wanted == bleedingOutFlag + beingRevivedFlag
				end
			end

			icons[#icons + 1] = icon
			container:addElement( icon )
			added = added + 1
		end
	end

	if #icons > 0 then
		hud:registerEventHandler( "more_players_revive_tick", function ()
			for _, icon in ipairs( icons ) do
				Try( icon.morePlayersUpdate )
			end
		end )
		hud:addElement( LUI.UITimer.new( REVIVE_TICK_MS, { name = "more_players_revive_tick" }, false, hud ) )
	end

	-- read by test/zz_mp_autostart.lua
	MorePlayers.reviveInfo = "engine has " .. stock .. ", mod added " .. added
end

-- Called while the HUD is still being built (see the score list below), so the
-- stock loop has not run yet. A one-shot timer on the HUD waits for it.
local function AddReviveIconsLater( hud, controller )
	if hud == nil or hud.morePlayersRevive or LUI.UITimer == nil then
		return
	end

	hud.morePlayersRevive = true
	hud:registerEventHandler( "more_players_revive", function ()
		Try( AddReviveIcons, hud, controller )
	end )
	hud:addElement( LUI.UITimer.new( 1000, { name = "more_players_revive" }, true, hud ) )
end

PatchScoreList = function ()
	if MorePlayers.scoreListPatched or CoD.ZMScr == nil or type( CoD.ZMScr.new ) ~= "function" then
		return
	end

	MorePlayers.scoreListPatched = true

	local stockNew = CoD.ZMScr.new

	CoD.ZMScr.new = function ( menu, controller )
		local widget = stockNew( menu, controller )
		Try( AddScoreRows, widget, menu, controller )
		-- menu is the HUD itself: every zombies HUD builds its score list this way
		Try( AddReviveIconsLater, menu, controller )
		return widget
	end
end

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------

Try( RaiseLobbyTable )
Try( RaiseLobby )

-- The two functions patched below come from this file. Loading it here only
-- makes sure it has run; the game keeps one copy however often it is asked for.
Try( require, "ui.uieditor.modifyFunctions" )
Try( PatchScoreColours )

local inZombiesMatch = CoD.isZombie == true and Engine.GetCurrentMap() ~= "core_frontend"

if inZombiesMatch then
	Try( require, "ui.uieditor.widgets.Scoreboard.CP.ScoreboardWidgetCP" )
	Try( PatchScoreboardRows )
	Try( require, "ui.uieditor.widgets.HUD.ZM_Score.ZMScr" )
	Try( PatchScoreList )
end
