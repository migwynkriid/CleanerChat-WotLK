local Core, Constants = unpack(select(2, ...))
local C = Core:GetModule("Config")

local AceDBOptions = Core.Libs.AceDBOptions
local LSM = Core.Libs.LSM

-- Localization
local L = LibStub("AceLocale-3.0"):GetLocale("CleanerChat")

local UnlockMover = Constants.ACTIONS.UnlockMover
local LockMover = Constants.ACTIONS.LockMover
local UpdateConfig = Constants.ACTIONS.UpdateConfig

-- Multi-window: each category in /cc shows window tabs (Main, Window 2, ...).
-- ProfileFor() resolves which window's settings a control edits from the
-- AceConfig info path (the window-tab key is one of the path segments).
C.selectedWindowId = "Main"

-- True if a window with this id currently exists (Main always does).
local function WindowExists(windowId)
	if windowId == "Main" then
		return true
	end
	local UIManager = Core:GetModule("UIManager", true)
	return (UIManager and UIManager.windows and UIManager.windows[windowId]) ~= nil
end

-- Resolve the profile a control should read/write from the AceConfig info path.
-- The window-tab group key ("Main" / "Window2" / ...) appears in the path, so we
-- scan for it. Falls back to the selected/Main profile (e.g. for build-time
-- desc strings where no info is available).
local function ProfileFor(info)
	if info then
		for i = 1, #info do
			local key = info[i]
			if key == "Main" then
				return Core.db.profile
			elseif type(key) == "string" and key:match("^Window%d+$") then
				-- GetWindowProfile now creates the profile on-demand if needed
				return Core:GetWindowProfile(key)
			end
		end
	end
	return Core:GetWindowProfile(C.selectedWindowId or "Main")
end

-- Extract the window ID from the AceConfig info path.
local function WindowIdFor(info)
	if info then
		for i = 1, #info do
			local key = info[i]
			if key == "Main" then
				return "Main"
			elseif type(key) == "string" and key:match("^Window%d+$") then
				return key
			end
		end
	end
	return C.selectedWindowId or "Main"
end

-- Build one child "tab" group per window for a category. `builder` returns a
-- fresh copy of the category's controls (their get/set resolve the window from
-- the info path via ProfileFor, so the same builder works for every window).
-- Tabs for windows that don't exist yet are hidden until they're created.
local function buildWindowTabs(builder)
	local tabs = {
		Main = { name = "Main", type = "group", order = 1, args = builder() },
	}
	local maxWindows = _G.NUM_CHAT_WINDOWS or 10
	for n = 2, maxWindows do
		local wid = "Window" .. n
		tabs[wid] = {
			name = "Window " .. n,
			type = "group",
			order = n,
			hidden = function()
				return not WindowExists(wid)
			end,
			args = builder(),
		}
	end
	return tabs
end

local ANCHORS = {
	["TOPLEFT"] = L["Top left"],
	["TOPRIGHT"] = L["Top right"],
	["BOTTOMLEFT"] = L["Bottom left"],
	["BOTTOMRIGHT"] = L["Bottom right"],
}
local FLAGS = {
	[""] = L["None"],
	["OUTLINE"] = L["Outline"],
	["THICKOUTLINE"] = L["Thick Outline"],
	["MONOCHROME"] = L["Monochrome"],
	["MONOCHROME, OUTLINE"] = L["Monochrome Outline"],
	["MONOCHROME, THICKOUTLINE"] = L["Monochrome Thick Outline"],
	["OUTLINE, MONOCHROME"] = L["Outline Monochrome"],
}

-- Option factories -----------------------------------------------------------
--
-- Almost every Glass setting is a flat profile key edited through the same
-- get/set pair: read ProfileFor(info)[key], write it, then dispatch an
-- UPDATE_CONFIG event. These factories build the AceConfig option table for
-- that common shape so the option list stays declarative. `o` fields:
--   key       (required) profile key to read/write
--   dispatch  event key to fire on set; defaults to `key`, pass false for none
--   default   value get returns when the stored value is nil
--   plus the usual name/desc/order/width/min/max/softMin/softMax/step/values/
--   hidden/disabled pass-throughs.

local function optionGet(key, default)
	if default ~= nil then
		return function(info)
			return ProfileFor(info)[key] or default
		end
	end
	return function(info)
		return ProfileFor(info)[key]
	end
end

local function optionSet(key, dispatch)
	return function(info, input)
		ProfileFor(info)[key] = input
		if dispatch ~= false then
			Core:Dispatch(UpdateConfig(dispatch or key, WindowIdFor(info)))
		end
	end
end

local function rangeOption(o)
	return {
		type = "range",
		name = o.name,
		desc = o.desc,
		order = o.order,
		width = o.width,
		min = o.min,
		max = o.max,
		softMin = o.softMin,
		softMax = o.softMax,
		step = o.step,
		hidden = o.hidden,
		disabled = o.disabled,
		get = optionGet(o.key, o.default),
		set = optionSet(o.key, o.dispatch),
	}
end

local function selectOption(o)
	return {
		type = "select",
		name = o.name,
		desc = o.desc,
		order = o.order,
		width = o.width,
		values = o.values,
		dialogControl = o.dialogControl,
		hidden = o.hidden,
		disabled = o.disabled,
		get = optionGet(o.key, o.default),
		set = optionSet(o.key, o.dispatch),
	}
end

local function fontOption(o)
	return selectOption({
		key = o.key,
		name = o.name or L["Font"],
		desc = o.desc,
		order = o.order,
		dialogControl = "LSM30_Font",
		values = LSM:HashTable("font"),
		dispatch = o.dispatch,
	})
end

local function colorOption(o)
	return {
		type = "color",
		name = o.name,
		desc = o.desc,
		order = o.order,
		width = o.width,
		hasAlpha = false,
		hidden = o.hidden,
		disabled = o.disabled,
		get = function(info)
			local c = ProfileFor(info)[o.key]
			return c.r, c.g, c.b
		end,
		set = function(info, r, g, b)
			local c = ProfileFor(info)[o.key]
			c.r, c.g, c.b = r, g, b
			if o.dispatch ~= false then
				Core:Dispatch(UpdateConfig(o.dispatch or o.key, WindowIdFor(info)))
			end
		end,
	}
end

function C:OnEnable()
	local options = {
		name = L["Glass"],
		handler = C,
		type = "group",
		args = {
			general = {
				name = L["General"],
				type = "group",
				childGroups = "tab",
				order = 1,
				args = buildWindowTabs(function()
					return {
						section1 = {
							name = L["Frame Position"],
							type = "group",
							inline = true,
							order = 2,
							args = {
								unlockFrame = {
									name = function()
										local UIManager = Core:GetModule("UIManager", true)
										if UIManager and UIManager.moverDialog and UIManager.moverDialog:IsShown() then
											return L["Lock frame"]
										end
										return L["Unlock frame"]
									end,
									type = "execute",
									func = function()
										local UIManager = Core:GetModule("UIManager", true)
										if UIManager and UIManager.moverDialog and UIManager.moverDialog:IsShown() then
											Core:Dispatch(LockMover())
										else
											Core:Dispatch(UnlockMover())
										end
									end,
									order = 2.1,
								},
							},
						},
						section3 = {
							name = L["Frame"],
							type = "group",
							inline = true,
							order = 4,
							args = {
								frameXOfs = {
									name = L["X offset"],
									desc = "Default: " .. Core.defaults.profile.positionAnchor.xOfs,
									type = "range",
									order = 4.1,
									min = -9999,
									max = 9999,
									softMin = -2000,
									softMax = 2000,
									step = 1,
									get = function(info)
										return ProfileFor(info).positionAnchor.xOfs
									end,
									set = function(info, input)
										ProfileFor(info).positionAnchor.xOfs = input
										Core:Dispatch(UpdateConfig("framePosition", WindowIdFor(info)))
									end,
								},
								frameWidth = {
									name = L["Width"],
									desc = "Default: " .. Core.defaults.profile.frameWidth .. "\nMin: 100",
									type = "range",
									order = 4.2,
									min = 100,
									max = 9999,
									softMin = 300,
									softMax = 800,
									step = 1,
									get = function(info)
										return ProfileFor(info).frameWidth
									end,
									set = function(info, input)
										ProfileFor(info).frameWidth = input
										Core:Dispatch(UpdateConfig("frameWidth", WindowIdFor(info)))
									end,
								},
								frameYOfs = {
									name = L["Y offset"],
									desc = "Default: " .. Core.defaults.profile.positionAnchor.yOfs,
									type = "range",
									order = 4.4,
									min = -9999,
									max = 9999,
									softMin = -2000,
									softMax = 2000,
									step = 1,
									get = function(info)
										return ProfileFor(info).positionAnchor.yOfs
									end,
									set = function(info, input)
										ProfileFor(info).positionAnchor.yOfs = input
										Core:Dispatch(UpdateConfig("framePosition", WindowIdFor(info)))
									end,
								},
								frameHeight = {
									name = L["Height"],
									desc = "Default: " .. Core.defaults.profile.frameHeight,
									type = "range",
									order = 4.5,
									min = 1,
									max = 9999,
									softMin = 200,
									softMax = 800,
									step = 1,
									get = function(info)
										return ProfileFor(info).frameHeight
									end,
									set = function(info, input)
										ProfileFor(info).frameHeight = input
										Core:Dispatch(UpdateConfig("frameHeight", WindowIdFor(info)))
									end,
								},
								frameAnchor = {
									name = L["Anchor"],
									desc = function(info)
										return "Default: " .. ProfileFor(info).positionAnchor.point
									end,
									type = "select",
									order = 4.3,
									values = ANCHORS,
									get = function(info)
										return ProfileFor(info).positionAnchor.point
									end,
									set = function(info, input)
										ProfileFor(info).positionAnchor.point = input
										Core:Dispatch(UpdateConfig("framePosition", WindowIdFor(info)))
									end,
								},
							},
						},
					}
				end),
			},
			editBox = {
				name = L["Edit box"],
				type = "group",
				childGroups = "tab",
				order = 2,
				args = buildWindowTabs(function()
					return {
						section1 = {
							name = L["Appearance"],
							type = "group",
							inline = true,
							order = 1,
							args = {
								editBoxFont = fontOption({
									key = "editBoxFont",
									desc = L["Font to use for the edit box text."],
									order = 1.0,
								}),
								editBoxFontSize = rangeOption({
									key = "editBoxFontSize",
									name = L["Font size"],
									desc = "Default: " .. Core.defaults.profile.editBoxFontSize .. "\nMin: 1\nMax: 100",
									order = 1.1,
									min = 1,
									max = 100,
									softMin = 6,
									softMax = 24,
									step = 1,
								}),
								editBoxFontFlags = selectOption({
									key = "editBoxFontFlags",
									name = L["Font style"],
									desc = L["Add an outline to the edit box text so it stands out instead of looking flat."],
									order = 1.3,
									values = FLAGS,
								}),
								editBoxBackgroundOpacity = rangeOption({
									key = "editBoxBackgroundOpacity",
									name = L["Background opacity"],
									desc = "Default: " .. Core.defaults.profile.editBoxBackgroundOpacity,
									order = 1.2,
									min = 0,
									max = 1,
									softMin = 0,
									softMax = 1,
									step = 0.01,
								}),
								editBoxBackgroundColor = colorOption({
									key = "editBoxBackgroundColor",
									name = L["Background color"],
									desc = L["The colour of the edit box background."],
									order = 1.4,
								}),
							},
						},
						section2 = {
							name = L["Position"],
							type = "group",
							inline = true,
							order = 2,
							args = {
								editBoxAnchorPosition = {
									name = L["Position"],
									desc = "Default: " .. Core.defaults.profile.editBoxAnchor.position,
									type = "select",
									order = 2.2,
									values = {
										ABOVE = L["Above"],
										BELOW = L["Below"],
									},
									get = function(info)
										return ProfileFor(info).editBoxAnchor.position
									end,
									set = function(info, input)
										ProfileFor(info).editBoxAnchor.position = input
										if input == "ABOVE" then
											ProfileFor(info).editBoxAnchor.yOfs = 5
										else
											ProfileFor(info).editBoxAnchor.yOfs = -5
										end
										Core:Dispatch(UpdateConfig("editBoxAnchor", WindowIdFor(info)))
									end,
								},
								editBoxAnchorYOfs = {
									name = L["Vertical offset"],
									desc = "Default: 5 or -5",
									type = "range",
									order = 2.1,
									min = -9999,
									max = 9999,
									softMin = -10,
									softMax = 10,
									step = 1,
									get = function(info)
										return ProfileFor(info).editBoxAnchor.yOfs
									end,
									set = function(info, input)
										ProfileFor(info).editBoxAnchor.yOfs = input
										Core:Dispatch(UpdateConfig("editBoxAnchor", WindowIdFor(info)))
									end,
								},
							},
						},
						section3 = {
							name = L["Behavior"],
							type = "group",
							inline = true,
							order = 3,
							args = {
								showOnEditFocus = {
									name = L["Show chat on focus"],
									desc = L["When enabled, opening the edit box (pressing Enter or clicking) reveals the chat messages."],
									type = "toggle",
									order = 3.1,
									get = function(info)
										return ProfileFor(info).showOnEditFocus
									end,
									set = function(info, input)
										ProfileFor(info).showOnEditFocus = input
									end,
								},
							},
						},
					}
				end),
			},
			messages = {
				name = L["Messages"],
				type = "group",
				childGroups = "tab",
				order = 3,
				args = buildWindowTabs(function()
					return {
						section1 = {
							name = L["Appearance"],
							type = "group",
							inline = true,
							order = 1,
							args = {
								messageFont = fontOption({
									key = "messageFont",
									desc = L["Font to use for chat messages."],
									order = 1.0,
								}),
								messageFontSize = rangeOption({
									key = "messageFontSize",
									name = L["Font size"],
									desc = "Default: " .. Core.defaults.profile.messageFontSize .. "\nMin: 1\nMax: 100",
									order = 1.2,
									min = 1,
									max = 100,
									softMin = 6,
									softMax = 24,
									step = 1,
								}),
								messageFontFlags = selectOption({
									key = "messageFontFlags",
									name = L["Font style"],
									desc = L["Add an outline to chat message text so it stands out instead of looking flat."],
									order = 1.6,
									values = FLAGS,
								}),
								chatBackgroundOpacity = rangeOption({
									key = "chatBackgroundOpacity",
									name = L["Background opacity"],
									desc = "Default: " .. Core.defaults.profile.chatBackgroundOpacity,
									order = 1.2,
									min = 0,
									max = 1,
									softMin = 0,
									softMax = 1,
									step = 0.01,
								}),
								chatBackgroundColor = colorOption({
									key = "chatBackgroundColor",
									name = L["Background color"],
									desc = L["The colour of the chat message background."],
									order = 1.7,
								}),
								messageLeading = rangeOption({
									key = "messageLeading",
									name = L["Leading"],
									desc = "Default: " .. Core.defaults.profile.messageLeading .. "\nMin: 0\nMax: 10",
									order = 1.3,
									min = 0,
									max = 10,
									softMin = 0,
									softMax = 5,
									step = 1,
								}),
								messageLinePadding = rangeOption({
									key = "messageLinePadding",
									name = L["Line padding"],
									desc = "Default: "
										.. Core.defaults.profile.messageLinePadding
										.. "\nMin: 0\nMax: 5",
									order = 1.4,
									min = 0,
									max = 5,
									softMin = 0,
									softMax = 1,
									step = 0.05,
								}),
								messageLeftPadding = rangeOption({
									key = "messageLeftPadding",
									name = L["Left padding"],
									desc = "Default: "
										.. Core.defaults.profile.messageLeftPadding
										.. "\nMin: 0\nMax: 50\n\n"
										.. L["Controls the blank space on the left side of messages."],
									order = 1.5,
									min = 0,
									max = 50,
									softMin = 0,
									softMax = 30,
									step = 1,
								}),
								messageHistoryLimit = {
									name = L["Message history"],
									desc = "Default: "
										.. Core.defaults.profile.messageHistoryLimit
										.. "\nMin: 128\nMax: 2048\n\n"
										.. L["Maximum number of messages to keep in memory per chat window. Higher values use more memory."],
									type = "range",
									min = 128,
									max = 2048,
									softMin = 128,
									softMax = 1024,
									step = 64,
									get = function(info)
										return ProfileFor(info).messageHistoryLimit
									end,
									set = function(info, input)
										ProfileFor(info).messageHistoryLimit = input
									end,
									order = 1.6,
								},
							},
						},
						section2 = {
							name = L["Animations"],
							type = "group",
							inline = true,
							order = 2,
							args = {
								disableAnimations = {
									name = L["Disable animations"],
									desc = L["Show messages instantly with no slide or fade -- the chat becomes static. The timing sliders below have no effect while this is on."],
									type = "toggle",
									order = 2.0,
									get = function(info)
										return ProfileFor(info).messageAnimations == false
									end,
									set = function(info, input)
										ProfileFor(info).messageAnimations = not input
										Core:Dispatch(UpdateConfig("messageAnimations", WindowIdFor(info)))
									end,
								},
								messagesAlwaysVisible = {
									name = L["Keep messages visible"],
									desc = L["Messages never fade out -- they stay on screen permanently. Overrides the fade out delay and duration below."],
									type = "toggle",
									order = 2.01,
									get = function(info)
										return ProfileFor(info).messagesAlwaysVisible
									end,
									set = function(info, input)
										ProfileFor(info).messagesAlwaysVisible = input
										Core:Dispatch(UpdateConfig("messagesAlwaysVisible", WindowIdFor(info)))
									end,
								},
								animationsSpacer = {
									name = "",
									type = "description",
									order = 2.05,
									width = "full",
								},
								chatHoldTime = {
									name = L["Fade out delay"],
									desc = "Default: " .. Core.defaults.profile.chatHoldTime .. "\nMin: 1\nMax: 180",
									type = "range",
									order = 2.1,
									min = 1,
									max = 180,
									softMin = 1,
									softMax = 20,
									step = 1,
									get = function(info)
										return ProfileFor(info).chatHoldTime
									end,
									set = function(info, input)
										ProfileFor(info).chatHoldTime = input
									end,
								},
								fadeInDuration = {
									name = L["Fade in duration"],
									desc = "Default: "
										.. Core.defaults.profile.chatFadeInDuration
										.. "\nMin: 0\nMax:30",
									type = "range",
									order = 2.3,
									min = 0,
									max = 30,
									softMin = 0,
									softMax = 10,
									step = 0.05,
									get = function(info)
										return ProfileFor(info).chatFadeInDuration
									end,
									set = function(info, input)
										ProfileFor(info).chatFadeInDuration = input
										Core:Dispatch(UpdateConfig("chatFadeInDuration", WindowIdFor(info)))
									end,
								},
								fadeOutDuration = {
									name = L["Fade out duration"],
									desc = "Default: "
										.. Core.defaults.profile.chatFadeOutDuration
										.. "\nMin: 0\nMax:30",
									type = "range",
									order = 2.4,
									min = 0,
									max = 30,
									softMin = 0,
									softMax = 10,
									step = 0.05,
									get = function(info)
										return ProfileFor(info).chatFadeOutDuration
									end,
									set = function(info, input)
										ProfileFor(info).chatFadeOutDuration = input
										Core:Dispatch(UpdateConfig("chatFadeOutDuration", WindowIdFor(info)))
									end,
								},
								slideInDuration = {
									name = L["Slide in duration"],
									desc = "Default: " .. Core.defaults.profile.chatSlideInDuration,
									type = "range",
									order = 2.3,
									min = 0,
									max = 30,
									softMin = 0,
									softMax = 5,
									step = 0.05,
									get = function(info)
										return ProfileFor(info).chatSlideInDuration
									end,
									set = function(info, input)
										ProfileFor(info).chatSlideInDuration = input
									end,
								},
							},
						},
						section3 = {
							name = L["Misc"],
							type = "group",
							inline = true,
							order = 3,
							args = {
								indentWordWrap = {
									name = L["Indent on line wrap"],
									desc = L["Adds an indent when a message wraps beyond a single line."],
									type = "toggle",
									order = 3.1,
									get = function(info)
										return ProfileFor(info).indentWordWrap
									end,
									set = function(info, input)
										ProfileFor(info).indentWordWrap = input
										Core:Dispatch(UpdateConfig("indentWordWrap", WindowIdFor(info)))
									end,
								},
								mouseOverTooltips = {
									name = L["Mouse over tooltips"],
									desc = L["Should tooltips appear when hovering over chat links."],
									type = "toggle",
									order = 3.2,
									get = function(info)
										return ProfileFor(info).mouseOverTooltips
									end,
									set = function(info, input)
										ProfileFor(info).mouseOverTooltips = input
									end,
								},
								iconTextureYOffset = {
									type = "range",
									name = L["Text icons Y offset"],
									desc = "Default: "
										.. Core.defaults.profile.iconTextureYOffset
										.. "\n"
										.. L["Adjust this if text icons aren't centered."],
									order = 3.4,
									min = 0,
									max = 12,
									softMin = 0,
									softMax = 12,
									step = 3.1,
									get = function(info)
										return ProfileFor(info).iconTextureYOffset
									end,
									set = function(info, input)
										-- TODO: Update messages dynamically
										ProfileFor(info).iconTextureYOffset = input
									end,
								},
								messagesOnHover = {
									name = L["Show messages on hover"],
									desc = L["When enabled, hovering over the chat reveals faded messages. When disabled, only scrolling reveals them."],
									type = "toggle",
									order = 3.3,
									get = function(info)
										return ProfileFor(info).messagesOnHover
									end,
									set = function(info, input)
										ProfileFor(info).messagesOnHover = input
										Core:Dispatch(UpdateConfig("messagesOnHover", WindowIdFor(info)))
									end,
								},
								showTimestamps = {
									name = L["Show timestamps"],
									desc = L["Prepend each message with a timestamp in [HH:MM] format."],
									type = "toggle",
									order = 3.35,
									get = function(info)
										return ProfileFor(info).showTimestamps
									end,
									set = function(info, input)
										ProfileFor(info).showTimestamps = input
									end,
								},
								scrollIndicatorHeader = {
									name = L["Scroll Indicator"],
									type = "header",
									order = 3.5,
								},
								hideScrollIndicator = {
									name = L["Hide scroll indicator"],
									desc = L['Hide the "Unread messages" and "Bring me to the present" indicator completely.'],
									type = "toggle",
									width = "full",
									order = 3.55,
									get = function(info)
										return ProfileFor(info).hideScrollIndicator
									end,
									set = function(info, input)
										ProfileFor(info).hideScrollIndicator = input
										Core:Dispatch(UpdateConfig("hideScrollIndicator", WindowIdFor(info)))
									end,
								},
								scrollIndicatorColor = {
									name = L["Indicator text color"],
									desc = L['Color of the "Unread messages" and "Bring me to the present" text.'],
									type = "color",
									hasAlpha = false,
									width = 1,
									order = 3.6,
									disabled = function(info)
										return ProfileFor(info).hideScrollIndicator
									end,
									get = function(info)
										local c = ProfileFor(info).scrollIndicatorColor
										return c.r, c.g, c.b
									end,
									set = function(info, r, g, b)
										local c = ProfileFor(info).scrollIndicatorColor
										c.r, c.g, c.b = r, g, b
										Core:Dispatch(UpdateConfig("scrollIndicatorColor", WindowIdFor(info)))
									end,
								},
								scrollIndicatorOpacity = {
									name = L["Indicator text opacity"],
									desc = "Default: "
										.. Core.defaults.profile.scrollIndicatorOpacity
										.. "\n"
										.. L["Opacity of the scroll indicator text."],
									type = "range",
									width = 1.5,
									order = 3.65,
									disabled = function(info)
										return ProfileFor(info).hideScrollIndicator
									end,
									min = 0,
									max = 1,
									step = 0.05,
									get = function(info)
										return ProfileFor(info).scrollIndicatorOpacity
									end,
									set = function(info, input)
										ProfileFor(info).scrollIndicatorOpacity = input
										Core:Dispatch(UpdateConfig("scrollIndicatorOpacity", WindowIdFor(info)))
									end,
								},
								scrollIndicatorBgColor = {
									name = L["Indicator background color"],
									desc = L["Background color behind the scroll indicator text."],
									type = "color",
									hasAlpha = false,
									width = 1,
									order = 3.7,
									disabled = function(info)
										return ProfileFor(info).hideScrollIndicator
									end,
									get = function(info)
										local c = ProfileFor(info).scrollIndicatorBgColor
										return c.r, c.g, c.b
									end,
									set = function(info, r, g, b)
										local c = ProfileFor(info).scrollIndicatorBgColor
										c.r, c.g, c.b = r, g, b
										Core:Dispatch(UpdateConfig("scrollIndicatorBgColor", WindowIdFor(info)))
									end,
								},
								scrollIndicatorBgOpacity = {
									name = L["Indicator background opacity"],
									desc = "Default: "
										.. Core.defaults.profile.scrollIndicatorBgOpacity
										.. "\n"
										.. L["Opacity of the scroll indicator background."],
									type = "range",
									width = 1.5,
									order = 3.75,
									disabled = function(info)
										return ProfileFor(info).hideScrollIndicator
									end,
									min = 0,
									max = 1,
									step = 0.05,
									get = function(info)
										return ProfileFor(info).scrollIndicatorBgOpacity
									end,
									set = function(info, input)
										ProfileFor(info).scrollIndicatorBgOpacity = input
										Core:Dispatch(UpdateConfig("scrollIndicatorBgOpacity", WindowIdFor(info)))
									end,
								},
							},
						},
					}
				end),
			},
			topBar = {
				name = L["Top bar"],
				type = "group",
				childGroups = "tab",
				order = 4,
				args = buildWindowTabs(function()
					return {
						section1 = {
							name = L["Appearance"],
							type = "group",
							inline = true,
							order = 1,
							args = {
								dockFont = fontOption({
									key = "dockFont",
									desc = L["Font to use for the chat tab text."],
									order = 1.0,
								}),
								dockFontSize = rangeOption({
									key = "dockFontSize",
									name = L["Font size"],
									desc = "Default: "
										.. Core.defaults.profile.dockFontSize
										.. "\nMin: 1\nMax: 100"
										.. "\n"
										.. L["Tab widths refit on /reload."],
									order = 1.1,
									min = 1,
									max = 100,
									softMin = 6,
									softMax = 24,
									step = 1,
								}),
								dockFontFlags = selectOption({
									key = "dockFontFlags",
									name = L["Font style"],
									desc = L["Add an outline to the chat tab text so it stands out instead of looking flat."],
									order = 1.15,
									values = FLAGS,
								}),
								dockBackgroundOpacity = rangeOption({
									key = "dockBackgroundOpacity",
									name = L["Background opacity"],
									desc = "Default: " .. Core.defaults.profile.dockBackgroundOpacity,
									order = 1.2,
									min = 0,
									max = 1,
									softMin = 0,
									softMax = 1,
									step = 0.01,
								}),
								dockBackgroundColor = colorOption({
									key = "dockBackgroundColor",
									name = L["Background color"],
									desc = L["The colour of the top bar background."],
									order = 1.3,
								}),
								tabStyleSpacer = {
									name = "",
									type = "description",
									order = 1.35,
									width = "full",
								},
								tabStyle = {
									name = L["Tab Style"],
									desc = L["Choose the visual style for chat tab buttons."],
									type = "select",
									order = 1.4,
									values = {
										["minimal"] = L["Minimal"],
										["outline"] = L["Outline"],
									},
									get = function(info)
										local style = ProfileFor(info).tabStyle or "minimal"
										-- Backward compatibility: map old styles to "outline"
										if style == "modern" or style == "filled" then
											style = "outline"
										end
										return style
									end,
									set = function(info, input)
										ProfileFor(info).tabStyle = input
										Core:Dispatch(UpdateConfig("tabStyle", WindowIdFor(info)))
									end,
								},
								tabCornerStyle = {
									name = L["Tab Corner Style"],
									desc = L["Shape of tab button corners."],
									type = "select",
									order = 1.45,
									values = {
										["square"] = L["Square"],
										["rounded"] = L["Rounded"],
									},
									hidden = function(info)
										local style = ProfileFor(info).tabStyle or "minimal"
										if style == "modern" or style == "filled" then
											style = "outline"
										end
										return style == "minimal"
									end,
									get = function(info)
										return ProfileFor(info).tabCornerStyle or "square"
									end,
									set = function(info, input)
										ProfileFor(info).tabCornerStyle = input
										Core:Dispatch(UpdateConfig("tabCornerStyle", WindowIdFor(info)))
									end,
								},
								tabActiveColor = {
									name = L["Tab active color"],
									desc = L["Color of the selected/active tab background and text."],
									type = "color",
									hasAlpha = false,
									order = 1.5,
									hidden = function(info)
										local style = ProfileFor(info).tabStyle or "minimal"
										if style == "modern" or style == "filled" then
											style = "outline"
										end
										return style == "minimal"
									end,
									get = function(info)
										local c = ProfileFor(info).tabActiveColor
										return c.r, c.g, c.b
									end,
									set = function(info, r, g, b)
										local c = ProfileFor(info).tabActiveColor
										c.r, c.g, c.b = r, g, b
										Core:Dispatch(UpdateConfig("tabActiveColor", WindowIdFor(info)))
									end,
								},
								tabInactiveColor = {
									name = L["Tab inactive color"],
									desc = L["Color of unselected tab backgrounds."],
									type = "color",
									hasAlpha = false,
									order = 1.6,
									hidden = function(info)
										local style = ProfileFor(info).tabStyle or "minimal"
										if style == "modern" or style == "filled" then
											style = "outline"
										end
										return style == "minimal"
									end,
									get = function(info)
										local c = ProfileFor(info).tabInactiveColor
										return c.r, c.g, c.b
									end,
									set = function(info, r, g, b)
										local c = ProfileFor(info).tabInactiveColor
										c.r, c.g, c.b = r, g, b
										Core:Dispatch(UpdateConfig("tabInactiveColor", WindowIdFor(info)))
									end,
								},
								tabBackgroundOpacity = {
									name = L["Tab background opacity"],
									desc = L["Opacity of the tab background and border."],
									type = "range",
									order = 1.9,
									min = 0,
									max = 1,
									step = 0.05,
									hidden = function(info)
										local style = ProfileFor(info).tabStyle or "minimal"
										if style == "modern" or style == "filled" then
											style = "outline"
										end
										return style == "minimal"
									end,
									get = function(info)
										return ProfileFor(info).tabBackgroundOpacity or 0.7
									end,
									set = function(info, input)
										ProfileFor(info).tabBackgroundOpacity = input
										Core:Dispatch(UpdateConfig("tabBackgroundOpacity", WindowIdFor(info)))
									end,
								},
								tabBorderThickness = {
									name = L["Tab border thickness"],
									desc = L["Thickness of the outline border."],
									type = "range",
									order = 1.95,
									min = 1,
									max = 5,
									step = 1,
									hidden = function(info)
										local style = ProfileFor(info).tabStyle or "minimal"
										if style == "modern" or style == "filled" then
											style = "outline"
										end
										local cornerStyle = ProfileFor(info).tabCornerStyle or "square"
										-- Only show for outline + square (rounded uses backdrop which has fixed border)
										return style == "minimal" or cornerStyle == "rounded"
									end,
									get = function(info)
										return ProfileFor(info).tabBorderThickness or 1
									end,
									set = function(info, input)
										ProfileFor(info).tabBorderThickness = input
										Core:Dispatch(UpdateConfig("tabBorderThickness", WindowIdFor(info)))
									end,
								},
								tabSpacing = {
									name = L["Tab spacing"],
									desc = L["Horizontal spacing between tab buttons."],
									type = "range",
									order = 1.96,
									min = 0,
									max = 20,
									step = 1,
									get = function(info)
										return ProfileFor(info).tabSpacing or 5
									end,
									set = function(info, input)
										ProfileFor(info).tabSpacing = input
										Core:Dispatch(UpdateConfig("tabSpacing", WindowIdFor(info)))
									end,
								},
								tabPadding = {
									name = L["Tab padding"],
									desc = L["Padding from the dock edge."],
									type = "range",
									order = 1.97,
									min = 0,
									max = 20,
									step = 1,
									get = function(info)
										return ProfileFor(info).tabPadding or 5
									end,
									set = function(info, input)
										ProfileFor(info).tabPadding = input
										Core:Dispatch(UpdateConfig("tabPadding", WindowIdFor(info)))
									end,
								},
							},
						},
						section2 = {
							name = L["Animations"],
							type = "group",
							inline = true,
							order = 2,
							args = {
								disableAnimations = {
									name = L["Disable animations"],
									desc = L["Show and hide the top bar instantly with no fade -- the tabs become static. The timing sliders below have no effect while this is on."],
									type = "toggle",
									order = 2.0,
									get = function(info)
										return ProfileFor(info).dockAnimations == false
									end,
									set = function(info, input)
										ProfileFor(info).dockAnimations = not input
										Core:Dispatch(UpdateConfig("dockAnimations", WindowIdFor(info)))
									end,
								},
								tabsAlwaysVisible = {
									name = L["Keep tabs visible"],
									desc = L["Chat tabs never fade out -- they stay on screen permanently. Overrides the fade out delay and duration below."],
									type = "toggle",
									order = 2.01,
									get = function(info)
										return ProfileFor(info).tabsAlwaysVisible
									end,
									set = function(info, input)
										ProfileFor(info).tabsAlwaysVisible = input
										Core:Dispatch(UpdateConfig("tabsAlwaysVisible", WindowIdFor(info)))
									end,
								},
								topBarAnimationsSpacer = {
									name = "",
									type = "description",
									order = 2.05,
									width = "full",
								},
								dockHoldTime = {
									name = L["Fade out delay"],
									desc = "Default: " .. Core.defaults.profile.dockHoldTime .. "\nMin: 1\nMax: 180",
									type = "range",
									order = 2.1,
									min = 1,
									max = 180,
									softMin = 1,
									softMax = 20,
									step = 1,
									get = function(info)
										return ProfileFor(info).dockHoldTime
									end,
									set = function(info, input)
										ProfileFor(info).dockHoldTime = input
									end,
								},
								dockFadeOutDuration = {
									name = L["Fade out duration"],
									desc = "Default: "
										.. Core.defaults.profile.dockFadeOutDuration
										.. "\nMin: 0\nMax: 30",
									type = "range",
									order = 2.2,
									min = 0,
									max = 30,
									softMin = 0,
									softMax = 10,
									step = 0.05,
									get = function(info)
										return ProfileFor(info).dockFadeOutDuration
									end,
									set = function(info, input)
										ProfileFor(info).dockFadeOutDuration = input
									end,
								},
								dockFadeInDuration = {
									name = L["Slide in duration"],
									desc = "Default: "
										.. Core.defaults.profile.dockFadeInDuration
										.. "\nMin: 0\nMax: 30",
									type = "range",
									order = 2.3,
									min = 0,
									max = 30,
									softMin = 0,
									softMax = 5,
									step = 0.05,
									get = function(info)
										return ProfileFor(info).dockFadeInDuration
									end,
									set = function(info, input)
										ProfileFor(info).dockFadeInDuration = input
									end,
								},
								tabsOnHover = {
									name = L["Show tabs on hover"],
									desc = L["When enabled, chat tabs fade out when idle and reappear on mouse hover. When disabled, tabs are always visible."],
									type = "toggle",
									order = 2.02,
									get = function(info)
										return ProfileFor(info).tabsOnHover
									end,
									set = function(info, input)
										ProfileFor(info).tabsOnHover = input
										Core:Dispatch(UpdateConfig("tabsOnHover", WindowIdFor(info)))
									end,
								},
							},
						},
					}
				end),
			},
			buttons = {
				name = L["Buttons"],
				type = "group",
				order = 5,
				args = {
					hideChatMenuButton = {
						name = L["Hide Chat Menu button"],
						desc = L["Hide the Chat Menu (speech bubble) button that provides access to languages and emotes."],
						type = "toggle",
						order = 1,
						width = "full",
						get = function()
							return Core.db.profile.hideChatMenuButton
						end,
						set = function(_, input)
							Core.db.profile.hideChatMenuButton = input
							Core:Dispatch(UpdateConfig("hideChatMenuButton"))
						end,
					},
					hideSocialButton = {
						name = L["Hide Social button"],
						desc = L["Hide the Social (friends) button that appears to the left of the chat frame."],
						type = "toggle",
						order = 2,
						width = "full",
						get = function()
							return Core.db.profile.hideSocialButton
						end,
						set = function(_, input)
							Core.db.profile.hideSocialButton = input
							Core:Dispatch(UpdateConfig("hideSocialButton"))
						end,
					},
				},
			},
			about = {
				name = L["About"],
				type = "group",
				order = 100,
				args = {
					version = {
						name = function()
							local version = GetAddOnMetadata("CleanerChat", "Version") or "?"
							return "|cffDFBA69CleanerChat|r v" .. version
						end,
						type = "description",
						order = 1,
						fontSize = "large",
					},
					author = {
						name = function()
							local author = GetAddOnMetadata("CleanerChat", "Author") or "Unknown"
							return L["Author"] .. ": |cffffffff" .. author .. "|r"
						end,
						type = "description",
						order = 2,
						fontSize = "medium",
					},
					spacer1 = {
						name = " ",
						type = "description",
						order = 3,
					},
					githubHeader = {
						name = "|cffDFBA69GitHub:|r",
						type = "description",
						order = 4,
						fontSize = "medium",
					},
					githubLink = {
						name = "",
						type = "input",
						order = 5,
						width = "double",
						get = function()
							return "https://github.com/migwynkriid/CleanerChat-WotLK"
						end,
						set = function() end, -- read-only
					},
					spacer2 = {
						name = " ",
						type = "description",
						order = 6,
					},
					creditsHeader = {
						name = "|cffDFBA69" .. L["Credits"] .. "|r",
						type = "description",
						order = 7,
						fontSize = "medium",
					},
					creditsDesc = {
						name = L["CleanerChat stands on the shoulders of two excellent addons. All credit for the original work belongs to their creators."],
						type = "description",
						order = 8,
						fontSize = "small",
					},
					spacer3 = {
						name = " ",
						type = "description",
						order = 9,
					},
					glassCredit = {
						name = "|cffFFFFFFGlass|r — "
							.. L["The immersive chat UI is built on Glass by mixxorz. This project keeps the spirit of Glass alive on 3.3.5."],
						type = "description",
						order = 10,
						fontSize = "small",
					},
					spacer4 = {
						name = " ",
						type = "description",
						order = 11,
					},
					chatcleanerCredit = {
						name = "|cffFFFFFFChatCleaner|r — "
							.. L["The message filtering is based on ChatCleaner by Lars Norberg (Goldpaw). Backported to 3.3.5."],
						type = "description",
						order = 12,
						fontSize = "small",
					},
				},
			},
			profile = AceDBOptions:GetOptionsTable(Core.db),
		},
	}

	-- Glass no longer owns its own options window or slash command -- its
	-- settings are embedded as categories in CleanerChat's /cc window. Expose the
	-- config groups for that, plus a helper so "/cc lock" can unlock the frame.
	Core.configGroups = options.args
	function Core.UnlockFrame()
		Core:Dispatch(UnlockMover())
	end

	Core.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	Core.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	Core.db.RegisterCallback(self, "OnProfileReset", "OnProfileReset")
end

function C:RefreshConfig()
	-- Profile changed/copied: broadcast to ALL windows (nil = no filter)
	-- General
	Core:Dispatch(UpdateConfig("frameHeight", nil))
	Core:Dispatch(UpdateConfig("frameWidth", nil))
	Core:Dispatch(UpdateConfig("framePosition", nil))

	-- Edit box
	Core:Dispatch(UpdateConfig("editBoxFont", nil))
	Core:Dispatch(UpdateConfig("editBoxFontSize", nil))
	Core:Dispatch(UpdateConfig("editBoxFontFlags", nil))
	Core:Dispatch(UpdateConfig("editBoxBackgroundOpacity", nil))
	Core:Dispatch(UpdateConfig("editBoxBackgroundColor", nil))
	Core:Dispatch(UpdateConfig("editBoxAnchor", nil))

	-- Messages
	Core:Dispatch(UpdateConfig("messageFont", nil))
	Core:Dispatch(UpdateConfig("messageFontSize", nil))
	Core:Dispatch(UpdateConfig("messageFontFlags", nil))
	Core:Dispatch(UpdateConfig("messageAnimations", nil))
	Core:Dispatch(UpdateConfig("messagesAlwaysVisible", nil))
	Core:Dispatch(UpdateConfig("chatBackgroundOpacity", nil))
	Core:Dispatch(UpdateConfig("chatBackgroundColor", nil))
	Core:Dispatch(UpdateConfig("chatFadeInDuration", nil))
	Core:Dispatch(UpdateConfig("chatFadeOutDuration", nil))
	Core:Dispatch(UpdateConfig("scrollIndicatorColor", nil))
	Core:Dispatch(UpdateConfig("scrollIndicatorOpacity", nil))
	Core:Dispatch(UpdateConfig("scrollIndicatorBgColor", nil))
	Core:Dispatch(UpdateConfig("scrollIndicatorBgOpacity", nil))
	Core:Dispatch(UpdateConfig("hideScrollIndicator", nil))

	-- Top bar (dock)
	Core:Dispatch(UpdateConfig("dockFont", nil))
	Core:Dispatch(UpdateConfig("dockFontSize", nil))
	Core:Dispatch(UpdateConfig("dockFontFlags", nil))
	Core:Dispatch(UpdateConfig("dockAnimations", nil))
	Core:Dispatch(UpdateConfig("tabsAlwaysVisible", nil))
	Core:Dispatch(UpdateConfig("dockBackgroundOpacity", nil))
	Core:Dispatch(UpdateConfig("dockBackgroundColor", nil))
	Core:Dispatch(UpdateConfig("tabsOnHover", nil))
end

function C:OnProfileReset()
	-- Also reset CleanerChat filter settings
	local CleanerChat = LibStub("AceAddon-3.0"):GetAddon("CleanerChat", true)
	if CleanerChat and CleanerChat.ResetCleanerChatSettings then
		CleanerChat:ResetCleanerChatSettings()
	end
	-- Refresh Glass UI config
	self:RefreshConfig()
end
