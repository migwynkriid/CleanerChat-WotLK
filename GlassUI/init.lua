local _G = _G

local AceAddon = _G.LibStub("AceAddon-3.0")

-- Integrated into CleanerChat: this file is loaded by the CleanerChat .toc, so the
-- "..." vararg carries CleanerChat's name/namespace. Use a fixed identity for the
-- Glass UI so it registers its own AceAddon object and "Glass" global, while still
-- sharing Core/Constants/Utils with the other Glass files via the vararg table.
local _, AddonVars = ...
local AddonName = "Glass"
local Core = AceAddon:NewAddon(AddonName)
local Constants = {}
local Utils = {}
AddonVars[1] = Core
AddonVars[2] = Constants
AddonVars[3] = Utils
_G[AddonName] = Core

-- Core
Core.Libs = {
	AceDB = _G.LibStub("AceDB-3.0"),
	AceDBOptions = _G.LibStub("AceDBOptions-3.0"),
	AceHook = _G.LibStub("AceHook-3.0"),
	LSM = _G.LibStub("LibSharedMedia-3.0"),
	LibEasing = _G.LibStub("LibEasing-1.0"),
	lodash = _G.LibStub("lodash.wow"),
}
Core.Components = {}
Core.Version = "1.7.0-wotlk"
--[===[@debug@--
Core.Version = "DEBUG"
--@end-debug@]===]
--

-- Modules
Core:NewModule("Config", "AceConsole-3.0")
Core:NewModule("Fonts")
Core:NewModule("Hyperlinks")
Core:NewModule("TextProcessing")
Core:NewModule("UIManager", "AceHook-3.0")

-- Default settings
Core.defaults = {
	profile = {
		-- General
		frameWidth = 520,
		frameHeight = 340,
		positionAnchor = {
			point = "BOTTOMLEFT",
			xOfs = 20,
			yOfs = 230,
		},

		-- Edit box
		editBoxFont = "Friz Quadrata TT",
		editBoxFontSize = 12,
		editBoxFontFlags = "OUTLINE",
		editBoxBackgroundOpacity = 0.6,
		editBoxBackgroundColor = { r = 17 / 255, g = 17 / 255, b = 17 / 255 }, -- codGray
		editBoxAnchor = {
			position = "BELOW",
			yOfs = -5,
		},
		showOnEditFocus = true, -- When ON (default), opening the edit box reveals the chat messages.

		-- Messages
		messageFont = "Friz Quadrata TT",
		messageFontSize = 12,
		messageFontFlags = "OUTLINE",
		messageAnimations = true,
		messagesAlwaysVisible = false,
		chatBackgroundOpacity = 0.15,
		chatBackgroundColor = { r = 17 / 255, g = 17 / 255, b = 17 / 255 }, -- codGray
		messageLeading = 3,
		messageLinePadding = 0.25,
		messageLeftPadding = 15,
		messageHistoryLimit = 128,

		chatHoldTime = 14,
		chatFadeInDuration = 0.6,
		chatFadeOutDuration = 0.6,
		chatSlideInDuration = 0.35,

		-- Top bar (chat tabs dock)
		dockFont = "Friz Quadrata TT",
		dockFontSize = 12,
		dockFontFlags = "OUTLINE",
		dockAnimations = true,
		tabsAlwaysVisible = false,
		dockBackgroundOpacity = 0,
		dockBackgroundColor = { r = 0, g = 0, b = 0 }, -- black
		dockHoldTime = 10,
		dockFadeOutDuration = 0.6,
		dockFadeInDuration = 0.3,
		tabsOnHover = true, -- When ON (default), tabs fade out and appear on hover. When OFF, tabs are always visible.

		-- Tab button skin style
		tabStyle = "minimal", -- "minimal" = text only, "outline" = border only
		tabCornerStyle = "rounded", -- "square" or "rounded" (only applies when tabStyle is not minimal)
		tabActiveColor = { r = 1.0, g = 191 / 255, b = 0 }, -- amber for selected tab
		tabInactiveColor = { r = 1.0, g = 191 / 255, b = 0 }, -- amber for unselected tabs
		tabBackgroundOpacity = 1.0, -- background/border opacity (full for active, multiplied for inactive)
		tabSpacing = 5, -- spacing between tabs
		tabBorderThickness = 1, -- border line thickness (1-5)
		tabPadding = 5, -- padding from dock edge

		indentWordWrap = true,
		mouseOverTooltips = true,
		iconTextureYOffset = 4,
		messagesOnHover = true, -- When ON (default), hovering reveals faded messages. When OFF, only scrolling reveals them.
		showTimestamps = false, -- When ON, prepend timestamps to messages in [HH:MM] format.

		-- Scroll indicator ("Unread messages" / "Bring me to the present")
		scrollIndicatorColor = { r = 223 / 255, g = 186 / 255, b = 105 / 255 }, -- apache (gold)
		scrollIndicatorOpacity = 1, -- fully solid
		scrollIndicatorBgColor = { r = 17 / 255, g = 17 / 255, b = 17 / 255 }, -- codGray (same as chat bg)
		scrollIndicatorBgOpacity = 0.65, -- slightly transparent
		hideScrollIndicator = false, -- when true, hides the "Unread messages" / "Bring me to the present" indicator

		-- Buttons (native Blizzard chat buttons)
		hideChatMenuButton = true, -- when true, hides the Chat Menu (speech bubble) button
		hideSocialButton = true, -- when true, hides the Social (friends) button left of chat

		-- Per-window settings (multi-window). The default ("Main") window uses the
		-- flat keys above; each additional window stores its own full copy of the
		-- window-scoped style settings here, keyed by window id (see Core:GetWindowProfile).
		windows = {},
	},
}

function Core:OnInitialize()
	self.listeners = {}

	self.db = self.Libs.AceDB:New("GlassDB", self.defaults, true)
	self.printBuffer = {}
end

-- Per-window settings (multi-window) -----------------------------------------
--
-- The default ("Main") window reads the flat profile directly, so existing saved
-- settings keep working unchanged. Each additional window keeps its own copy of
-- the window-scoped style settings under profile.windows[id].

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Returns the settings table a window should read from. A nil/"Main" id returns
-- the shared main profile (unchanged behaviour for the default window).
-- For other windows, creates a profile copy on-demand if it doesn't exist.
function Core:GetWindowProfile(windowId)
	if not windowId or windowId == "Main" then
		return self.db.profile
	end

	local windows = self.db.profile.windows
	local w = windows and windows[windowId]
	if w then
		return w
	end

	-- Window profile doesn't exist - create it on-demand with a copy of main profile
	return self:CreateWindowProfile(windowId, "Main")
end

-- Creates settings for a new window by copying the source window's resolved
-- settings, so the new window starts identical and is then edited independently.
function Core:CreateWindowProfile(newId, sourceId)
	if not newId or newId == "Main" then
		return self.db.profile
	end

	self.db.profile.windows = self.db.profile.windows or {}
	local source = self:GetWindowProfile(sourceId)

	local copy = {}
	for key, value in pairs(self.db.profile) do
		if key ~= "windows" then
			local v = source[key]
			if v == nil then
				v = value
			end
			copy[key] = deepCopy(v)
		end
	end

	self.db.profile.windows[newId] = copy
	return self:GetWindowProfile(newId)
end

-- Removes a window's settings (used by the "Delete window" action).
function Core:DeleteWindowProfile(windowId)
	if not windowId or windowId == "Main" then
		return
	end
	if self.db.profile.windows then
		self.db.profile.windows[windowId] = nil
	end
end

function Core:OnEnable()
	-- Buffer print messages until ViragDevTool loads
	for _, item in ipairs(self.printBuffer) do
		Utils.print(unpack(item))
	end
	self.printBuffer = {}
end

function Core:Subscribe(messageType, listener)
	if self.listeners[messageType] == nil then
		self.listeners[messageType] = {}
	end

	local listeners = self.listeners[messageType]
	local index = #listeners + 1
	listeners[index] = listener

	return function()
		self.Libs.lodash.remove(listeners, function(val)
			return val == listener
		end)
	end
end

function Core:Dispatch(messageType, payload)
	--[===[@debug@--
  Utils.print('E: '..messageType, payload)
  --@end-debug@]===]
	--

	local listeners = self.listeners[messageType] or {}
	for _, listener in ipairs(listeners) do
		listener(payload)
	end
end

-- Resolve an UPDATE_CONFIG payload to the changed key for a given window.
-- The payload is either a bare key (legacy) or { key = ..., windowId = ... }.
-- Returns the key string, or nil when the update targets a different window and
-- this listener should ignore it. Centralizes the unwrap + window-match
-- boilerplate that was duplicated in every config subscriber.
function Core:ResolveConfigKey(payload, myWindowId)
	local key = type(payload) == "table" and payload.key or payload
	local targetWindowId = type(payload) == "table" and payload.windowId or nil
	if targetWindowId and myWindowId and targetWindowId ~= myWindowId then
		return nil
	end
	return key
end
