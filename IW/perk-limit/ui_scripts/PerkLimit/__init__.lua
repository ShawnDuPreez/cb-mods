-- Perk Limit: the PERK LIMIT control in the zombies lobby, for the host. It
-- only sets the dvar perk_limit; the game script
-- custom_scripts/cp/perk_limit.gsc reads it in the match and enforces it.
--
--   perk_limit 5      the game's own limit
--   perk_limit 1-11   that many perks
--   perk_limit 0      no limit
--
-- Where the control is:
--   Custom Game   a PERK LIMIT row inside the client's MATCH SETTINGS popup,
--                 under OPEN TO FRIENDS
--   Solo Match    the client shows no MATCH SETTINGS there, so the lobby gets
--                 its own PERK LIMIT button, which opens a small popup
--
-- The dvar is made with "set", so the choice lasts until the game is closed.
--
-- This file can sit in two places. Packed inside the mod's mod.ff it only
-- loads once a match has been played, because right after a mod is picked the
-- game starts its menus before mod.ff is ready and runs nothing from the mod's
-- folder. Installed on the host's side, in iw7-mod/ui_scripts/PerkLimit/, it
-- loads with every menu start, so the control is there as soon as the mod is
-- picked. For that it stays out of sight unless the mod is the loaded one.

if not Engine.InFrontend() then
	return
end

local DVAR = "perk_limit"
local DEFAULT_LIMIT = 5
local POPUP_ID = "PerkLimitPopup"
local POPUP_WIDTH = _1080p * 500
local ROW_STEP = _1080p * 40

-- The choices, in the order the arrows step through them. 0 is "no limit".
-- No map has more than 12 perks, so 11 is the highest limit that still limits.
local CHOICES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0 }

-- The limit is enforced by the game script, so the control is only shown
-- when that script will run in the match: the Perk Limit mod is the one
-- loaded in the Mods menu, or the game script is installed as an always-on
-- file. Checked each time a menu is built, since the loaded mod can change.
local GAME_SCRIPT = "iw7-mod/custom_scripts/cp/perk_limit.gsc"

local function mod_active()
	local loaded = string.lower(Engine.GetDvarString("fs_game") or "")
	if string.find(loaded, "perk_limit", 1, true) then
		return true
	end
	local ok, exists = pcall(function()
		return io.fileexists(GAME_SCRIPT)
	end)
	return ok and exists == true
end

local function read_limit()
	local value = tonumber(Engine.GetDvarString(DVAR) or "")
	if value == nil then
		return DEFAULT_LIMIT
	end
	value = math.floor(value)
	if value <= 0 then
		return 0
	end
	if value > 11 then
		return 0
	end
	return value
end

-- Engine.Exec runs on the next frame, so the value is also kept here.
local current_limit = read_limit()

local function write_limit(value)
	current_limit = value
	Engine.Exec("set " .. DVAR .. " " .. value)
end

local function limit_label(value)
	if value == 0 then
		return "No limit"
	end
	if value == DEFAULT_LIMIT then
		return value .. " (game default)"
	end
	return tostring(value)
end

local function choice_index(value)
	for index, choice in ipairs(CHOICES) do
		if choice == value then
			return index
		end
	end
	return DEFAULT_LIMIT
end

local function button_text()
	return ToUpperCase("Perk Limit: " .. limit_label(current_limit))
end

-- The lobby button currently on screen, so the popup can update its text.
local lobby_button = nil

local function fit_to_popup(element, height)
	element:SetAnchors(0, 1, 1, 0, 0)
	element:SetLeft(0, 0)
	element:SetRight(POPUP_WIDTH, 0)
	element:SetTop(0, 0)
	element:SetBottom(height, 0)
end

local function build_description(text)
	local container = LUI.UIElement.new()
	container.id = "Description"
	fit_to_popup(container, _1080p * 90)

	local label = LUI.UIText.new()
	label:SetFont(FONTS.GetFont(FONTS.MainCondensed.File))
	label:SetFontSize(22 * _1080p)
	label:SetAlignment(LUI.Alignment.Left)
	label:SetWordWrap(true)
	label:SetRGBFromTable(SWATCHES.Popups.bodyTxt, 0)
	label:SetAlpha(0.8, 0)
	label:SetAnchorsAndPosition(0, 1, 0, 1, _1080p * 12, POPUP_WIDTH - _1080p * 12, _1080p * 8, _1080p * 30)
	label:setText(text)
	container:addElement(label)

	return container
end

local DESCRIPTION = "How many perks each player can hold in this match. The game's own limit is 5. "
	.. "Goes back to 5 when you restart the game."

-- The row with the arrows: PERK LIMIT  < 5 (game default) >
local function build_limit_row(controllerIndex)
	local labels = {}
	for index, choice in ipairs(CHOICES) do
		labels[index] = limit_label(choice)
	end

	local row = MenuBuilder.BuildRegisteredType("GenericArrowButton", {
		controllerIndex = controllerIndex
	})
	row.id = "PerkLimit"
	row.Title:setText(ToUpperCase("Perk Limit"), 0)
	fit_to_popup(row, _1080p * 35)
	LUI.AddUIArrowTextButtonLogic(row, controllerIndex, {
		labels = labels,
		wrapAround = true,
		defaultValue = choice_index(current_limit),
		action = function(valueIndex)
			local value = CHOICES[valueIndex]
			if value == nil then
				return
			end
			write_limit(value)
			if lobby_button ~= nil then
				pcall(function()
					lobby_button.Text:setText(button_text(), 0)
				end)
			end
		end
	})
	return row
end

-- Custom Game: the client builds its MATCH SETTINGS popup as a "PopupList"
-- with a list of rows, the last one being the footer with BACK. The two
-- rows are slipped into that list just above the footer, so whatever the
-- client puts in the popup stays as it is.
local SETTINGS_TITLE = "MATCH SETTINGS"
local build_popup_list = MenuBuilder.m_types["PopupList"]

local function add_rows_to_match_settings(props)
	local rows = props.listContent
	current_limit = read_limit()
	local controllerIndex = Engine.GetFirstActiveController()
	local limit_row = build_limit_row(controllerIndex)
	local description = build_description(DESCRIPTION)
	description.id = "PerkLimitDescription"

	local at = #rows + 1
	for index, element in ipairs(rows) do
		if element.id == "ButtonHelperBar" then
			at = index
			break
		end
	end
	table.insert(rows, at, limit_row)
	table.insert(rows, at + 1, description)
end

if type(build_popup_list) == "function" then
	MenuBuilder.m_types["PopupList"] = function(menu, props, ...)
		if type(props) == "table" and props.title == SETTINGS_TITLE and type(props.listContent) == "table"
			and Engine.IsAliensMode() and mod_active() then
			local ok, err = pcall(add_rows_to_match_settings, props)
			if not ok then
				print("PerkLimit: " .. tostring(err))
			end
		end
		return build_popup_list(menu, props, ...)
	end
else
	print("PerkLimit: popup type not found, no row added to Match Settings")
end

-- Solo Match: a popup of its own, with the same two rows.
MenuBuilder.m_types[POPUP_ID] = function(menu, props)
	local controllerIndex = props.controllerIndex or Engine.GetFirstActiveController()

	local PerkLimit = build_limit_row(controllerIndex)
	local Description = build_description(DESCRIPTION)

	local ButtonHelperBar = MenuBuilder.BuildRegisteredType("button_helper_text_main", {
		left_inset = 0,
		right_inset = -30,
		top_margin = 0,
		bottom_margin = 0,
		height = GenericFooterDims.Height,
		spacing = 5,
		background_alpha = 1,
		list_left_inset = 0,
		controllerIndex = controllerIndex
	})
	ButtonHelperBar.id = "ButtonHelperBar"
	fit_to_popup(ButtonHelperBar, 0)
	ButtonHelperBar:SetTop(_1080p * -50, 0)

	local popup = MenuBuilder.BuildRegisteredType("PopupList", {
		title = "PERK LIMIT",
		width = POPUP_WIDTH,
		defaultFocusIndex = 1,
		cancelClosesPopup = true,
		listContent = { PerkLimit, Description, ButtonHelperBar }
	})
	popup.id = POPUP_ID
	popup:AddButtonHelperTextToElement(ButtonHelperBar, {
		helper_text = Engine.Localize("MENU_BACK"),
		button_ref = "button_secondary",
		side = "left",
		priority = 1,
		clickable = true
	})

	return popup
end

-- The lobby's own PERK LIMIT button, for lobbies without Match Settings. The
-- zombies lobby's button list is positioned by hand, row by row: Start Match,
-- Loadout, ..., Survival Depot, then an invisible spacer, the description
-- text and the contracts button. The new row goes under the lowest button
-- and everything below it moves down one row.
local function add_lobby_button(list, controllerIndex)
	if list.PerkLimit ~= nil then
		return
	end

	-- In a Solo Match the player is always the one who decides.
	local host = LUI.DataSourceInGlobalModel.new("frontEnd.lobby.areWeGameHost")
	local is_host = function()
		if type(isAliensSolo) == "function" and isAliensSolo() then
			return true
		end
		return host:GetValue(controllerIndex) == true
	end

	local top = nil
	local bottom = nil
	for _, name in ipairs({ "Armory", "MatchSettings" }) do
		local element = list[name]
		if element ~= nil then
			local _, elementTop, _, elementBottom = element:getLocalRect()
			if bottom == nil or elementBottom > bottom then
				top = elementTop
				bottom = elementBottom
			end
		end
	end
	if bottom == nil then
		return
	end

	local button = MenuBuilder.BuildRegisteredType("MenuButton", {
		controllerIndex = controllerIndex
	})
	button.id = "PerkLimit"
	button.buttonDescription = "Choose how many perks each player can hold. Only the host can change it."
	button.Text:setText(button_text(), 0)
	button:addEventHandler("button_action", function(element, event)
		if is_host() then
			LUI.FlowManager.RequestPopupMenu(element, POPUP_ID, true, event.controller or controllerIndex, false, {})
		end
	end)
	button:SetAnchorsAndPosition(0, 1, 0, 1, 0, _1080p * 340, top + ROW_STEP, bottom + ROW_STEP)
	button:addElementBefore(list.ForSpacing)

	for _, element in ipairs({ list.ForSpacing, list.ButtonDescription, list.ContractsButton }) do
		local _, elementTop, _, elementBottom = element:getLocalRect()
		element:SetTop(elementTop + ROW_STEP, 0)
		element:SetBottom(elementBottom + ROW_STEP, 0)
	end

	button:SetButtonDisabled(not is_host())
	list:SubscribeToModel(host:GetModel(controllerIndex), function()
		button:SetButtonDisabled(not is_host())
	end)

	list.PerkLimit = button
	lobby_button = button
end

local function controller_index_of(controller)
	return (controller and controller.controllerIndex) or Engine.GetFirstActiveController()
end

local function add_guarded(list, controller)
	local ok, err = pcall(function()
		current_limit = read_limit()
		add_lobby_button(list, controller_index_of(controller))
	end)
	if not ok then
		print("PerkLimit: " .. tostring(err))
	end
end

-- A lobby that has the client's Match Settings button gets the limit inside
-- that popup (above) and no button of its own. The Match Settings row may be
-- added to the button list before or after this script has its turn at it,
-- depending on the order the scripts were loaded in, so the decision is made
-- on the whole lobby menu, which is built after the list is complete.
local SETTINGS_BUTTON_TEXT = "Choose whether friends can join as soon as the match starts, "
	.. "and how many perks each player can hold."

local function finish_lobby(list, controller)
	if not mod_active() then
		return
	end
	if list.MatchSettings ~= nil then
		list.MatchSettings.buttonDescription = SETTINGS_BUTTON_TEXT
		return
	end
	add_guarded(list, controller)
end

local build_buttons = MenuBuilder.m_types["CPPrivateMatchButtons"]
local build_menu = MenuBuilder.m_types["CPPrivateMatchMenu"]

if type(build_menu) == "function" then
	MenuBuilder.m_types["CPPrivateMatchMenu"] = function(menu, controller)
		local self = build_menu(menu, controller)
		if self.CPPrivateMatchButtons ~= nil then
			local ok, err = pcall(finish_lobby, self.CPPrivateMatchButtons, controller)
			if not ok then
				print("PerkLimit: " .. tostring(err))
			end
		end
		return self
	end
elseif type(build_buttons) == "function" then
	-- No lobby menu type to hook: decide on the list as it is now.
	MenuBuilder.m_types["CPPrivateMatchButtons"] = function(menu, controller)
		local self = build_buttons(menu, controller)
		local ok, err = pcall(finish_lobby, self, controller)
		if not ok then
			print("PerkLimit: " .. tostring(err))
		end
		return self
	end
else
	print("PerkLimit: zombies lobby menu not found, no lobby button added")
end
