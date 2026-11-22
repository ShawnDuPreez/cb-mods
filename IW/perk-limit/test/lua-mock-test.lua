-- Runs ui_scripts/PerkLimit/__init__.lua against stand-ins for the game's menu
-- functions and checks its own logic: reading and writing the dvar, the
-- labels, the rows it slips into the client's MATCH SETTINGS popup, and the
-- lobby button it adds where there is no Match Settings (Solo Match).
--
--   lua5.1 test/lua-mock-test.lua
--
-- This can not show whether the real game draws the control. Only the game can.

-- The script under test: the one beside this test folder, or the path given.
local here = (arg[0] or ""):match("^(.*)/[^/]*$") or "."
local script_path = arg[1] or (here .. "/../ui_scripts/PerkLimit/__init__.lua")
local checks, failures = 0, 0

local function check(name, got, want)
	checks = checks + 1
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	end
end

-- One fresh pretend game per scenario.
local function new_game(options)
	local game = { dvars = options.dvars or {}, executed = {}, popups = {}, printed = {}, files = options.files or {} }
	if game.dvars.fs_game == nil and options.mod_loaded ~= false then
		game.dvars.fs_game = "mods/perk_limit"
	end

	local function element(kind)
		local self = { kind = kind, children = {}, handlers = {}, rect = { 0, 0, 0, 0 } }
		function self:SetAnchorsAndPosition(_, _, _, _, left, right, top, bottom)
			self.rect = { left, top, right, bottom }
		end
		function self:getLocalRect()
			return self.rect[1], self.rect[2], self.rect[3], self.rect[4]
		end
		function self:SetTop(value) self.rect[2] = value end
		function self:SetBottom(value) self.rect[4] = value end
		function self:SetLeft(value) self.rect[1] = value end
		function self:SetRight(value) self.rect[3] = value end
		function self:SetAnchors() end
		function self:addElement(child) table.insert(self.children, child); child.parent = self end
		function self:addElementBefore(sibling)
			local parent = sibling.parent
			for index, child in ipairs(parent.children) do
				if child == sibling then
					table.insert(parent.children, index, self)
					self.parent = parent
					return
				end
			end
			error("sibling not found")
		end
		function self:addEventHandler(name, handler) self.handlers[name] = handler end
		function self:SetButtonDisabled(value) self.disabled = value end
		function self:SubscribeToModel(_, callback) self.subscription = callback end
		function self:AddButtonHelperTextToElement() end
		function self:setText(text) self.text = text end
		function self:SetFont() end
		function self:SetFontSize() end
		function self:SetAlignment() end
		function self:SetWordWrap() end
		function self:SetRGBFromTable() end
		function self:SetAlpha() end
		self.Text = { setText = function(text_self, text) self.text = text end }
		self.Title = { setText = function(title_self, text) self.title = text end }
		return self
	end
	game.element = element

	local env = setmetatable({}, { __index = _G })
	env._1080p = 1
	if options.no_io ~= true then
		env.io = { fileexists = function(path) return game.files[path] == true end }
	else
		env.io = nil
	end
	env.ToUpperCase = string.upper
	env.print = function(text) table.insert(game.printed, text) end
	env.FONTS = { GetFont = function() return "font" end, MainCondensed = { File = "f" } }
	env.SWATCHES = { Popups = { bodyTxt = {} } }
	env.GenericFooterDims = { Height = 40 }
	if options.solo ~= nil then
		env.isAliensSolo = function() return options.solo end
	end
	env.Engine = {
		InFrontend = function() return options.in_frontend ~= false end,
		GetDvarString = function(name) return game.dvars[name] end,
		Exec = function(command)
			table.insert(game.executed, command)
			local name, value = command:match("^set (%S+) (%S+)$")
			if name then game.dvars[name] = value end
		end,
		GetFirstActiveController = function() return 0 end,
		IsAliensMode = function() return options.zombies ~= false end,
		Localize = function(text) return text end,
	}
	env.LUI = {
		UIElement = { new = function() return element("UIElement") end },
		UIText = { new = function() return element("UIText") end },
		Alignment = { Left = 1 },
		DataSourceInGlobalModel = {
			new = function()
				return {
					GetValue = function() return game.is_host ~= false end,
					GetModel = function() return "model" end,
				}
			end,
		},
		AddUIArrowTextButtonLogic = function(button, _, props) button.arrow = props end,
		FlowManager = {
			RequestPopupMenu = function(_, id) table.insert(game.popups, id) end,
		},
	}

	local function lobby_buttons(with_match_settings)
		local list = element("CPPrivateMatchButtons")
		local function row(name, top, bottom)
			local child = element(name)
			child.rect = { 0, top, 340, bottom }
			list:addElement(child)
			list[name] = child
			return child
		end
		row("StartMatch", 0, 30)
		row("Armory", 200, 230)
		local shift = 0
		if with_match_settings then
			row("MatchSettings", 240, 270)
			shift = 40
		end
		row("ForSpacing", 240 + shift, 245 + shift)
		row("ButtonDescription", 310 + shift, 375 + shift)
		row("ContractsButton", 240 + shift, 300 + shift)
		if options.no_spacer then
			list.ForSpacing = nil
		end
		return list
	end

	local types = {}
	types.MenuButton = function() return element("MenuButton") end
	types.GenericArrowButton = function() return element("GenericArrowButton") end
	types.button_helper_text_main = function() return element("helper") end
	types.PopupList = function(_, props) local popup = element("PopupList"); popup.props = props; return popup end
	types.CPPrivateMatchButtons = function() return lobby_buttons(options.match_settings) end
	if options.menu_type ~= false then
		types.CPPrivateMatchMenu = function(_, props)
			local menu = element("CPPrivateMatchMenu")
			menu.CPPrivateMatchButtons = types.CPPrivateMatchButtons(nil, props)
			return menu
		end
	end
	env.MenuBuilder = {
		m_types = types,
		BuildRegisteredType = function(name, props) return types[name](nil, props) end,
	}

	local chunk = assert(loadfile(script_path))
	setfenv(chunk, env)
	chunk()

	-- The client's Match Settings script loaded after ours: it wraps our
	-- wrapper, puts its row under Survival Depot and moves the rest down.
	if options.match_settings_wraps_later then
		local wrapped = types.CPPrivateMatchButtons
		types.CPPrivateMatchButtons = function(menu, props)
			local list = wrapped(menu, props)
			local _, top, _, bottom = list.Armory:getLocalRect()
			local row = element("MatchSettings")
			row.id = "MatchSettings"
			row.rect = { 0, top + 40, 340, bottom + 40 }
			row:addElementBefore(list.ForSpacing)
			list.MatchSettings = row
			for _, child in ipairs({ list.ForSpacing, list.ButtonDescription, list.ContractsButton }) do
				child.rect[2] = child.rect[2] + 40
				child.rect[4] = child.rect[4] + 40
			end
			return list
		end
	end

	game.env = env
	game.types = types
	return game
end

local function find(list, id)
	for index, child in ipairs(list.children) do
		if child.id == id then
			return child, index
		end
	end
end

local function count_rows(list, id)
	local count = 0
	for _, child in ipairs(list.children) do
		if child.id == id then count = count + 1 end
	end
	return count
end

-- The client's MATCH SETTINGS popup, as its script builds it: a "PopupList"
-- with the Open To Friends row, its description, and the footer.
local function open_match_settings(game, title)
	local open = game.element("GenericArrowButton"); open.id = "OpenToFriends"
	local text = game.element("UIElement"); text.id = "Description"
	local footer = game.element("helper"); footer.id = "ButtonHelperBar"
	local popup = game.env.MenuBuilder.BuildRegisteredType("PopupList", {
		title = title or "MATCH SETTINGS",
		listContent = { open, text, footer },
	})
	return popup, popup.props.listContent
end

local function ids(rows)
	local out = {}
	for index, row in ipairs(rows) do out[index] = tostring(row.id) end
	return table.concat(out, " ")
end

-- 1. In a match the script does nothing.
do
	local game = new_game({ in_frontend = false })
	check("in game: no popup type", game.types.PerkLimitPopup, nil)
	check("in game: nothing executed", #game.executed, 0)
	local _, rows = open_match_settings(game)
	check("in game: Match Settings untouched", #rows, 3)
end

-- 2. Custom Game: the limit is a row inside the client's MATCH SETTINGS popup.
do
	local game = new_game({ match_settings = true })
	check("loading the script runs no command", #game.executed, 0)

	local menu = game.env.MenuBuilder.BuildRegisteredType("CPPrivateMatchMenu", { controllerIndex = 0 })
	local list = menu.CPPrivateMatchButtons
	check("custom game: no lobby button of its own", count_rows(list, "PerkLimit"), 0)
	check("custom game: lobby rows not moved", list.ForSpacing.rect[2], 280)
	check("custom game: Match Settings description mentions perks",
		list.MatchSettings.buttonDescription:find("how many perks") ~= nil, true)

	local popup, rows = open_match_settings(game)
	check("popup: rows in order", ids(rows), "OpenToFriends Description PerkLimit PerkLimitDescription ButtonHelperBar")
	local row = rows[3]
	check("popup: row title", row.title, "PERK LIMIT")
	check("popup: 12 choices", #row.arrow.labels, 12)
	check("popup: first label", row.arrow.labels[1], "1")
	check("popup: default label", row.arrow.labels[5], "5 (game default)")
	check("popup: last label", row.arrow.labels[12], "No limit")
	check("popup: arrow starts on the default", row.arrow.defaultValue, 5)
	check("popup: arrows wrap around", row.arrow.wrapAround, true)

	row.arrow.action(8)
	check("choosing 8 writes the dvar", game.dvars.perk_limit, "8")
	local _, again = open_match_settings(game)
	check("reopened popup starts on 8", again[3].arrow.defaultValue, 8)
	row.arrow.action(12)
	check("choosing no limit writes 0", game.dvars.perk_limit, "0")
	row.arrow.action(99)
	check("a bad index changes nothing", game.dvars.perk_limit, "0")
	local _, third = open_match_settings(game)
	check("reopened popup starts on no limit", third[3].arrow.defaultValue, 12)

	-- the value was changed in the console meanwhile
	game.dvars.perk_limit = "2"
	local _, fourth = open_match_settings(game)
	check("reopened popup reads a console change", fourth[3].arrow.defaultValue, 2)

	-- other popups are left alone
	local _, other = open_match_settings(game, "LEAVE LOBBY")
	check("another popup is untouched", #other, 3)
end

-- 2b. Match Settings in the multiplayer lobby is left alone.
do
	local game = new_game({ match_settings = true, zombies = false })
	local _, rows = open_match_settings(game)
	check("multiplayer: Match Settings untouched", #rows, 3)
end

-- 2c. A Match Settings popup whose footer has another name: rows go last.
do
	local game = new_game({ match_settings = true })
	local a = game.element("GenericArrowButton"); a.id = "OpenToFriends"
	local popup = game.env.MenuBuilder.BuildRegisteredType("PopupList", { title = "MATCH SETTINGS", listContent = { a } })
	check("no footer: rows appended", ids(popup.props.listContent), "OpenToFriends PerkLimit PerkLimitDescription")
	local bare = game.env.MenuBuilder.BuildRegisteredType("PopupList", { title = "MATCH SETTINGS" })
	check("no list at all: popup still builds", bare ~= nil, true)
end

-- 2c2. If the row can not be built, Match Settings still opens, unchanged.
do
	local game = new_game({ match_settings = true })
	game.types.GenericArrowButton = function() error("no such widget") end
	local ok, popup = pcall(game.env.MenuBuilder.BuildRegisteredType, "PopupList", { title = "MATCH SETTINGS", listContent = {} })
	check("row fails: popup still builds", ok and popup ~= nil, true)
	check("row fails: nothing half-added", ok and #popup.props.listContent, 0)
	check("row fails: problem is logged", #game.printed > 0, true)
end

-- 2d. The client's Match Settings script was loaded after this one.
do
	local game = new_game({ match_settings = false, match_settings_wraps_later = true })
	local menu = game.env.MenuBuilder.BuildRegisteredType("CPPrivateMatchMenu", { controllerIndex = 0 })
	local list = menu.CPPrivateMatchButtons
	check("loaded first: no lobby button of its own", count_rows(list, "PerkLimit"), 0)
	check("loaded first: Match Settings under Survival Depot", list.MatchSettings.rect[2], 240)
	check("loaded first: lobby rows moved only by Match Settings", list.ForSpacing.rect[2], 280)
	local _, rows = open_match_settings(game)
	check("loaded first: row is in the popup", ids(rows), "OpenToFriends Description PerkLimit PerkLimitDescription ButtonHelperBar")
end

-- 2e. Installed on the host's side, but the mod is not the loaded one: nothing shows.
do
	for _, fs_game in ipairs({ "", "mods/more_players", "mods/all_perks" }) do
		local game = new_game({ match_settings = true, dvars = { fs_game = fs_game } })
		local menu = game.env.MenuBuilder.BuildRegisteredType("CPPrivateMatchMenu", { controllerIndex = 0 })
		local _, rows = open_match_settings(game)
		check("mod '" .. fs_game .. "' loaded: Match Settings untouched", #rows, 3)
		check("mod '" .. fs_game .. "' loaded: Match Settings description untouched",
			menu.CPPrivateMatchButtons.MatchSettings.buttonDescription, nil)
		local solo = new_game({ match_settings = false, solo = true, dvars = { fs_game = fs_game } })
		local solo_menu = solo.env.MenuBuilder.BuildRegisteredType("CPPrivateMatchMenu", { controllerIndex = 0 })
		check("mod '" .. fs_game .. "' loaded: no solo button", count_rows(solo_menu.CPPrivateMatchButtons, "PerkLimit"), 0)
	end
end

-- 2f. The mod is picked while the game is open: the row is there the next
-- time the popup is built, and gone again when the mod is unloaded.
do
	local game = new_game({ match_settings = true, dvars = { fs_game = "" } })
	local _, before = open_match_settings(game)
	check("before picking: untouched", #before, 3)
	game.dvars.fs_game = "mods/Perk_Limit"
	local _, picked = open_match_settings(game)
	check("after picking: row is there", #picked, 5)
	game.dvars.fs_game = ""
	local _, after = open_match_settings(game)
	check("after unloading: untouched", #after, 3)
end

-- 2g. No mod loaded, but the game script is installed as an always-on file.
do
	local game = new_game({ match_settings = true, dvars = { fs_game = "" },
		files = { ["iw7-mod/custom_scripts/cp/perk_limit.gsc"] = true } })
	local _, rows = open_match_settings(game)
	check("always-on game script: row is there", #rows, 5)
	local none = new_game({ match_settings = true, dvars = { fs_game = "" }, no_io = true })
	local _, plain = open_match_settings(none)
	check("no file check available and no mod: untouched", #plain, 3)
end

-- 3. Solo Match: no Match Settings there, so the lobby gets its own button.
do
	local game = new_game({ match_settings = false, solo = true })
	game.is_host = false
	local menu = game.env.MenuBuilder.BuildRegisteredType("CPPrivateMatchMenu", { controllerIndex = 0 })
	local list = menu.CPPrivateMatchButtons
	local button, index = find(list, "PerkLimit")
	check("solo: one button", count_rows(list, "PerkLimit"), 1)
	check("solo: button text, unset dvar", button.text, "PERK LIMIT: 5 (GAME DEFAULT)")
	check("solo: button under Survival Depot: top", button.rect[2], 240)
	check("solo: button under Survival Depot: bottom", button.rect[4], 270)
	check("solo: button width", button.rect[3], 340)
	check("solo: button sits before the spacer", list.children[index + 1], list.ForSpacing)
	check("solo: spacer moved down", list.ForSpacing.rect[2], 280)
	check("solo: description moved down", list.ButtonDescription.rect[2], 350)
	check("solo: contracts moved down", list.ContractsButton.rect[2], 280)
	check("solo: enabled", button.disabled, false)

	button.handlers.button_action(button, { controller = 0 })
	check("solo: press opens the popup", game.popups[1], "PerkLimitPopup")
	local popup = game.types.PerkLimitPopup(nil, { controllerIndex = 0 })
	check("solo: popup has three rows", ids(popup.props.listContent), "PerkLimit Description ButtonHelperBar")
	check("solo: popup title", popup.props.title, "PERK LIMIT")
	local arrow = popup.props.listContent[1]
	arrow.arrow.action(8)
	check("solo: choosing 8 writes the dvar", game.dvars.perk_limit, "8")
	check("solo: choosing 8 updates the button", button.text, "PERK LIMIT: 8")
	arrow.arrow.action(12)
	check("solo: choosing no limit updates the button", button.text, "PERK LIMIT: NO LIMIT")

	local menu2 = game.env.MenuBuilder.BuildRegisteredType("CPPrivateMatchMenu", { controllerIndex = 0 })
	check("solo: rebuilt lobby shows the chosen value", find(menu2.CPPrivateMatchButtons, "PerkLimit").text, "PERK LIMIT: NO LIMIT")
	game.dvars.perk_limit = "2"
	local menu3 = game.env.MenuBuilder.BuildRegisteredType("CPPrivateMatchMenu", { controllerIndex = 0 })
	check("solo: rebuilt lobby reads a console change", find(menu3.CPPrivateMatchButtons, "PerkLimit").text, "PERK LIMIT: 2")
end

-- 4. A Custom Game on a client with no Match Settings: own button, host only.
do
	local game = new_game({ match_settings = false, solo = false })
	local menu = game.env.MenuBuilder.BuildRegisteredType("CPPrivateMatchMenu", { controllerIndex = 0 })
	local button = find(menu.CPPrivateMatchButtons, "PerkLimit")
	check("no Match Settings: button under Survival Depot", button.rect[2], 240)
	check("no Match Settings: enabled for the host", button.disabled, false)

	game.is_host = false
	local menu2 = game.env.MenuBuilder.BuildRegisteredType("CPPrivateMatchMenu", { controllerIndex = 0 })
	local button2 = find(menu2.CPPrivateMatchButtons, "PerkLimit")
	check("no Match Settings: disabled for a non-host", button2.disabled, true)
	button2.handlers.button_action(button2, { controller = 0 })
	check("no Match Settings: a non-host press opens nothing", #game.popups, 0)
end

-- 5. Values already in the dvar.
do
	local cases = {
		{ "3", 3 }, { "0", 12 }, { "-4", 12 }, { "11", 11 }, { "12", 12 }, { "40", 12 },
		{ "", 5 }, { "abc", 5 }, { "7.9", 7 },
	}
	for _, case in ipairs(cases) do
		local game = new_game({ match_settings = true, dvars = { perk_limit = case[1] } })
		local _, rows = open_match_settings(game)
		check("dvar '" .. case[1] .. "' starts the arrows on choice", rows[3].arrow.defaultValue, case[2])
	end
end

-- 6. The lobby menu type is not there: the decision is made on the button list.
do
	local game = new_game({ match_settings = false, solo = true, menu_type = false })
	local list = game.env.MenuBuilder.BuildRegisteredType("CPPrivateMatchButtons", { controllerIndex = 0 })
	check("fallback, solo: button added to the list", count_rows(list, "PerkLimit"), 1)
	local game2 = new_game({ match_settings = true, menu_type = false })
	local list2 = game2.env.MenuBuilder.BuildRegisteredType("CPPrivateMatchButtons", { controllerIndex = 0 })
	check("fallback, Match Settings there: no button", count_rows(list2, "PerkLimit"), 0)
end

-- 7. A broken lobby (no spacer) must not break the menu.
do
	local game = new_game({ match_settings = false, solo = true, no_spacer = true })
	local ok, menu = pcall(game.env.MenuBuilder.BuildRegisteredType, "CPPrivateMatchMenu", { controllerIndex = 0 })
	check("broken lobby: menu still builds", ok and menu ~= nil, true)
	check("broken lobby: problem is logged", #game.printed > 0, true)
end

print(("%d checks, %d failed"):format(checks, failures))
if failures == 0 then
	print("ALL PASSED")
end
os.exit(failures == 0 and 0 or 1)
