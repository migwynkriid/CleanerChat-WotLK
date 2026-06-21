--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local Addon, ns = ...

local Options = ns:NewModule("Options", "LibMoreEvents-1.0", "AceConsole-3.0")

-- Addon Localization
local L = LibStub("AceLocale-3.0"):GetLocale((...))

-- Libraries
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceGUI = LibStub("AceGUI-3.0")

-- GLOBALS: CopyTable, ReloadUI

-- Lua API
local ipairs = ipairs
local next = next
local table_sort = table.sort
local type = type

-- Utility
-------------------------------------------------------
local setter = function(info,val)
	ns.db.filters[info[#info]] = val
	local moduleName = ns:GetModuleNameFromFilter(info[#info])
	local module = ns:GetModule(moduleName, true)
	if (module) then
		if (val and not module:IsEnabled()) then
			module:Enable()
		elseif (not val and module:IsEnabled()) then
			module:Disable()
		end
	end
	Options:UpdateReloadStatus()
end

local getter = function(info)
	return ns.db.filters[info[#info]]
end

-- OptionsDBs
-------------------------------------------------------
local optionDB = {
	type = "group",
	args = {
		channelNameMode = {
			order = 10,
			name = L["Channel Name Style"],
			desc = L["Choose whether to show the channel's full name or just its first letter. Requires the Chat Channel Names filter."],
			width = "full",
			type = "select",
			values = {
				initial = L["Shortened (e.g. \"[G]\")"],
				full = L["Full name (e.g. \"[General]\")"],
			},
			disabled = function(info) return not ns.db.filters.channels end,
			set = function(info,value) ns.db.channelNameMode = value; Options:UpdateReloadStatus() end,
			get = function(info) return ns.db.channelNameMode end,
		},
		channelNumber = {
			order = 11,
			name = L["Show Channel Number"],
			desc = L["Prefix the channel display with its number, e.g. \"1. \". Requires the Chat Channel Names filter."],
			width = "full",
			type = "toggle",
			disabled = function(info) return not ns.db.filters.channels end,
			set = function(info,value) ns.db.channelNumber = value; Options:UpdateReloadStatus() end,
			get = function(info) return ns.db.channelNumber end,
		},
		channelCapitalize = {
			order = 12,
			name = L["Capitalize Channel Name"],
			desc = L["Capitalize the first letter of the channel name or initial. Requires the Chat Channel Names filter."],
			width = "full",
			type = "toggle",
			disabled = function(info) return not ns.db.filters.channels end,
			set = function(info,value) ns.db.channelCapitalize = value; Options:UpdateReloadStatus() end,
			get = function(info) return ns.db.channelCapitalize end,
		},
		capitalizeNames = {
			order = 20,
			name = L["Capitalize Player Names"],
			desc = L["Capitalize the first letter of player names shown in chat. Requires the Player Names filter."],
			width = "full",
			type = "toggle",
			disabled = function(info) return not ns.db.filters.names end,
			set = function(info,value) ns.db.capitalizeNames = value; Options:UpdateReloadStatus() end,
			get = function(info) return ns.db.capitalizeNames end,
		},
		hideOtherCrafts = {
			order = 30,
			name = L["Hide Crafting Broadcasts"],
			desc = L["Hide the \"<name> created: <item>\" messages shown when other players craft items nearby. Requires the Learning (Crafting) filter."],
			width = "full",
			type = "toggle",
			disabled = function(info) return not ns.db.filters.tradeskills end,
			set = function(info,value) ns.db.hideOtherCrafts = value; Options:UpdateReloadStatus() end,
			get = function(info) return ns.db.hideOtherCrafts end,
		},
		hideUIErrors = {
			order = 40,
			name = L["Hide UI Error Messages on Login from CleanerChat"],
			desc = L["Hide the \"UI Error: an interface error occurred\" notifications the server prints to chat when a UI error happens."],
			width = "full",
			type = "toggle",
			set = function(info,value) ns.db.hideUIErrors = value; Options:UpdateReloadStatus() end,
			get = function(info) return ns.db.hideUIErrors end,
		},
		filterHeader = {
			order = 100,
			type = "header",
			name = L["Filter Selection"]
		},
		moneyPrettify = {
			order = 105,
			name = L["Prettify Money"],
			desc = L["Display money gains and losses with coin icons (e.g. \"+ 28\"). When off, uses the default Blizzard text format."],
			width = "full",
			type = "toggle",
			set = function(info,value) ns.db.moneyPrettify = value; Options:UpdateReloadStatus() end,
			get = function(info) return ns.db.moneyPrettify end,
		}
	}
}

local filterDB = {
	achievements = {
		name = L["Achievements"],
		desc = L["Simplify Achievement messages."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	},
	auctions = {
		name = L["Auctions"],
		desc = L["Suppress auction messages while auction frame is open, display summary after."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	},
	channels = {
		name = L["Chat Channel Names"],
		desc = L["Abbreviate and simplify chat channel display names."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	},
	empty = {
		name = L["Empty Messages"],
		desc = L["Hide chat messages that contain no text (empty or whitespace only)."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	},
	experience = {
		name = L["Experience"],
		desc = L["Abbreviate and simplify experience- and level gains."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	},
	loot = {
		name = L["Loot"],
		desc = L["Abbreviate and simplify loot-, currency- and received item messages."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	},
	names = {
		name = L["Player Names"],
		desc = L["Remove brackets from player names."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	},
	quests = {
		name = L["Quests"],
		desc = L["Simplify quest completion- and progress messages."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	},
	reputation = {
		name = L["Reputation"],
		desc = L["Simplify messages about reputation gain and loss."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	},
	spells = {
		name = L["Learning (Spells)"],
		desc = L["Blacklist messages about new or removed spells, typically spammed on specialization changes."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	},
	status = {
		name = L["Player Status"],
		desc = L["Simplify status messages about AFK, DND and being rested."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	},
	tradeskills = {
		name = L["Learning (Crafting)"],
		desc = L["Simplify messages about new or improved trade skills."],
		width = "full",
		type = "toggle",
		set = setter,
		get = getter
	}
}

Options.GenerateOptionsMenu = function(self)

	-- Sort filter entries by localized name.
	local sorted = {}
	for name,item in next,filterDB do
		if (item) then
			sorted[#sorted + 1] = { name = name, item = item }
		end
	end
	table_sort(sorted, function(a,b) return a.item.name < b.item.name end)

	-- Build the CleanerChat "Filters" category from optionDB + the filter toggles.
	local ccGroup = CopyTable(optionDB)
	ccGroup.name = "Filters"
	ccGroup.order = 1
	local order,count = 0,0
	for i,data in ipairs(sorted) do
		local item
		if (type(data.item) == "function") then
			item = data.item()
		else
			item = data.item
		end
		if (item) then
			count = count + 1
			order = order + 10
			item.order = 100 + order
			ccGroup.args[data.name] = item
		end
	end

	-- Top-level tree. The Glass UI settings are merged in as additional
	-- categories so everything lives under /cc (Glass no longer has /glass).
	local options = {
		name = "CleanerChat",
		type = "group",
		args = {
			cleanerchat = ccGroup,
		}
	}

	local glass = _G.Glass
	if (glass and glass.configGroups) then
		-- Order them after the Filters tab; keep Profiles last.
		local glassOrders = {
			general = 2, editBox = 3, messages = 4, topBar = 5, profile = 100
		}
		for key,group in next,glass.configGroups do
			if (type(group) == "table") then
				group.order = glassOrders[key] or 50
				options.args[key] = group
			end
		end
	end

	AceConfigRegistry:RegisterOptionsTable(Addon, options)
	AceConfigDialog:SetDefaultSize(Addon, 800, 520)
end

-- Reload-on-close tracking
-------------------------------------------------------
-- Snapshot of the settings as they were when the window was opened.
-- Used to detect whether the user actually changed anything.
Options.TakeSettingsSnapshot = function(self)
	self.snapshot = {
		channelNameMode = ns.db.channelNameMode,
		channelNumber = ns.db.channelNumber,
		channelCapitalize = ns.db.channelCapitalize,
		capitalizeNames = ns.db.capitalizeNames,
		moneyPrettify = ns.db.moneyPrettify,
		filters = CopyTable(ns.db.filters)
	}
end

-- Returns true if the current settings differ from the snapshot.
-- Reverting all changes back to the saved values makes this false again.
Options.IsDirty = function(self)
	local snapshot = self.snapshot
	if (not snapshot) then return false end
	if (snapshot.channelNameMode ~= ns.db.channelNameMode) then return true end
	if (snapshot.channelNumber ~= ns.db.channelNumber) then return true end
	if (snapshot.channelCapitalize ~= ns.db.channelCapitalize) then return true end
	if (snapshot.capitalizeNames ~= ns.db.capitalizeNames) then return true end
	if (snapshot.moneyPrettify ~= ns.db.moneyPrettify) then return true end
	for key,value in next,snapshot.filters do
		if (ns.db.filters[key] ~= value) then return true end
	end
	return false
end

-- Updates the status text shown left of the Close button.
Options.UpdateReloadStatus = function(self)
	local frame = AceConfigDialog.OpenFrames[Addon]
	if (not frame or not frame.SetStatusText) then return end
	if (self:IsDirty()) then
		frame:SetStatusText("|cffffd200"..L["Settings changed - the UI will reload when you close this window."].."|r")
	else
		frame:SetStatusText("")
	end
end

Options.OpenOptionsMenu = function(self, input)

	-- "/cc lock" unlocks the Glass frame (mirrors the old "/glass lock").
	if (input == "lock") then
		if (_G.Glass and _G.Glass.UnlockFrame) then
			_G.Glass.UnlockFrame()
		end
		return
	end

	-- Always rebuild so categories that load later (e.g. the Glass UI tabs)
	-- are picked up, and so the table reflects the latest settings.
	local genOk, genErr = pcall(self.GenerateOptionsMenu, self)
	if (not genOk) then
		print("|cffff7d0aCleanerChat|r: failed to build the options menu.")
		print("|cffff0000"..tostring(genErr).."|r")
		return
	end

	if (AceConfigRegistry:GetOptionsTable(Addon)) then
		local ok, err = pcall(AceConfigDialog.Open, AceConfigDialog, Addon)
		if (not ok) then
			print("|cffff7d0aCleanerChat|r: failed to open the options window.")
			print("|cffff0000"..tostring(err).."|r")
			return
		end
	else
		print("|cffff7d0aCleanerChat|r: the options table is missing after generation.")
		return
	end

	-- Remember the current settings so we can detect real changes,
	-- and reload the UI on close only if something actually changed.
	self:TakeSettingsSnapshot()

	local frame = AceConfigDialog.OpenFrames[Addon]
	if (frame and frame.frame and not frame.frame.ccReloadHooked) then
		frame.frame.ccReloadHooked = true
		frame.frame:HookScript("OnHide", function()
			if (Options:IsDirty()) then
				ReloadUI()
			end
		end)
	end

	self:UpdateReloadStatus()
end

Options.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then
		local isInitialLogin, isReloadingUi = ...
		if (isInitialLogin or isReloadingUi) then
			local ok, err = pcall(self.GenerateOptionsMenu, self)
			if (not ok) then
				print("|cffff7d0aCleanerChat|r: failed to build the options menu.")
				print("|cffff0000"..tostring(err).."|r")
			end
			self:UnregisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
		end
	end
end

Options.OnInitialize = function(self)
	self:RegisterChatCommand("cc", "OpenOptionsMenu")
	self:RegisterChatCommand("cleanerchat", "OpenOptionsMenu")
	-- TEMPORARY DIAGNOSTIC command (see Components/_Debug.lua).
	self:RegisterChatCommand("ccdebug", function() if (ns.ToggleRawDebug) then ns.ToggleRawDebug() end end)
end

Options.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end
