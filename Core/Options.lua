local Addon, ns = ...

local Options = ns:NewModule("Options", "LibMoreEvents-1.0", "AceConsole-3.0")

-- Addon Localization
local L = LibStub("AceLocale-3.0"):GetLocale((...))

-- Libraries
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- GLOBALS: CopyTable, ReloadUI

-- Lua API
local ipairs = ipairs
local next = next
local table_sort = table.sort
local type = type

-- Utility
-------------------------------------------------------
local setter = function(info, val)
	ns.db.filters[info[#info]] = val
	local moduleName = ns:GetModuleNameFromFilter(info[#info])
	local module = ns:GetModule(moduleName, true)
	if module then
		if val and not module:IsEnabled() then
			module:Enable()
		elseif not val and module:IsEnabled() then
			module:Disable()
		end
	end
	-- Sync with Blizzard's chat filter settings
	if ns.SyncFilterToBlizzard then
		ns.SyncFilterToBlizzard(info[#info], val)
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
			name = L["Numbered Channel Style"],
			desc = L["How to display numbered channels like General, Trade, LocalDefense. Requires the Chat Channel Names filter."],
			width = 1.25,
			type = "select",
			values = {
				initial = L['Shortened (e.g. "[G]")'],
				full = L['Full name (e.g. "[General]")'],
				none = L['Number only (e.g. "1.")'],
			},
			disabled = function(info)
				return not ns.db.filters.channels
			end,
			set = function(info, value)
				ns.db.channelNameMode = value
				Options:UpdateReloadStatus()
			end,
			get = function(info)
				return ns.db.channelNameMode
			end,
		},
		groupChannelNameMode = {
			order = 10.5,
			name = L["Group Channel Style"],
			desc = L["How to display group channels like Guild, Party, Raid, Officer. Requires the Chat Channel Names filter."],
			width = 1.25,
			type = "select",
			values = {
				initial = L['Shortened (e.g. "[G]", "[P]")'],
				full = L['Full name (e.g. "[Guild]", "[Party]")'],
			},
			disabled = function(info)
				return not ns.db.filters.channels
			end,
			set = function(info, value)
				ns.db.groupChannelNameMode = value
				Options:UpdateReloadStatus()
			end,
			get = function(info)
				return ns.db.groupChannelNameMode
			end,
		},
		channelNumber = {
			order = 11,
			name = L["Show Channel Number"],
			desc = L['Prefix the channel display with its number, e.g. "1. ". Requires the Chat Channel Names filter.'],
			width = "full",
			type = "toggle",
			disabled = function(info)
				return not ns.db.filters.channels
			end,
			set = function(info, value)
				ns.db.channelNumber = value
				Options:UpdateReloadStatus()
			end,
			get = function(info)
				return ns.db.channelNumber
			end,
		},
		channelCapitalize = {
			order = 12,
			name = L["Capitalize Channel Name"],
			desc = L["Capitalize the first letter of the channel name or initial. Requires the Chat Channel Names filter."],
			width = "full",
			type = "toggle",
			disabled = function(info)
				return not ns.db.filters.channels
			end,
			set = function(info, value)
				ns.db.channelCapitalize = value
				Options:UpdateReloadStatus()
			end,
			get = function(info)
				return ns.db.channelCapitalize
			end,
		},
		capitalizeNames = {
			order = 20,
			name = L["Capitalize Player Names"],
			desc = L["Capitalize the first letter of player names shown in chat. Requires the Player Names filter."],
			width = "full",
			type = "toggle",
			disabled = function(info)
				return not ns.db.filters.names
			end,
			set = function(info, value)
				ns.db.capitalizeNames = value
				Options:UpdateReloadStatus()
			end,
			get = function(info)
				return ns.db.capitalizeNames
			end,
		},
		forceClassColors = {
			order = 25,
			name = L["Force Class Colors"],
			desc = L["Enable class-colored names for all chat types (Guild, Party, Raid, Whisper, etc.) on login. This overrides Blizzard's default settings."],
			width = "full",
			type = "toggle",
			set = function(info, value)
				ns.db.forceClassColors = value
				if value then
					ns:ApplyClassColors()
				end
			end,
			get = function(info)
				return ns.db.forceClassColors
			end,
		},
		hideOtherCrafts = {
			order = 30,
			name = L["Hide Crafting Broadcasts"],
			desc = L['Hide the "<name> created: <item>" messages shown when other players craft items nearby. Requires the Learning (Crafting) filter.'],
			width = "full",
			type = "toggle",
			disabled = function(info)
				return not ns.db.filters.tradeskills
			end,
			set = function(info, value)
				ns.db.hideOtherCrafts = value
				Options:UpdateReloadStatus()
			end,
			get = function(info)
				return ns.db.hideOtherCrafts
			end,
		},
		showStartupMessage = {
			order = 45,
			name = L["Show Startup Message"],
			desc = L["Print a message on login showing how to open CleanerChat settings."],
			width = "full",
			type = "toggle",
			set = function(info, value)
				ns.db.showStartupMessage = value
			end,
			get = function(info)
				return ns.db.showStartupMessage
			end,
		},
		filterHeader = {
			order = 100,
			type = "header",
			name = L["Filter Selection"],
		},
		moneyPrettify = {
			order = 105,
			name = L["Prettify Money"],
			desc = L['Display money gains and losses with coin icons (e.g. "+ 28"). When off, uses the default Blizzard text format.'],
			width = 1.5,
			type = "toggle",
			set = function(info, value)
				ns.db.moneyPrettify = value
				Options:UpdateReloadStatus()
			end,
			get = function(info)
				return ns.db.moneyPrettify
			end,
		},
		oneLineQuestRewards = {
			order = 106,
			name = L["One Line Quest Rewards"],
			desc = L["Combine quest rewards (items, currency, experience) into a single line. Reputation gains remain separate per faction."],
			width = 1.5,
			type = "toggle",
			set = function(info, value)
				ns.db.oneLineQuestRewards = value
				Options:UpdateReloadStatus()
			end,
			get = function(info)
				return ns.db.oneLineQuestRewards
			end,
		},
		showItemDestruction = {
			order = 107,
			name = L["Show Item Destruction"],
			desc = L["Display a message when you destroy (delete) an item."],
			width = 1.5,
			type = "toggle",
			set = function(info, value)
				ns.db.showItemDestruction = value
			end,
			get = function(info)
				return ns.db.showItemDestruction
			end,
		},
		showVendorSales = {
			order = 108,
			name = L["Show Vendor Sales"],
			desc = L["Display a message when you sell an item to a vendor."],
			width = 1.5,
			type = "toggle",
			set = function(info, value)
				ns.db.showVendorSales = value
			end,
			get = function(info)
				return ns.db.showVendorSales
			end,
		},
		prettifyGuildStatus = {
			order = 109,
			name = L["Prettify Guild Status"],
			desc = L["Simplify guild online/offline messages to show just the player name."],
			width = 1.5,
			type = "toggle",
			set = function(info, value)
				ns.db.prettifyGuildStatus = value
			end,
			get = function(info)
				return ns.db.prettifyGuildStatus
			end,
		},
	},
}

local filterDB = {
	achievements = {
		name = L["Achievements"],
		desc = L["Simplify Achievement messages."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	auctions = {
		name = L["Auctions"],
		desc = L["Simplify auction house messages: listings created, cancelled, sold, won and bids placed."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	channels = {
		name = L["Chat Channel Names"],
		desc = L["Abbreviate and simplify chat channel display names."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	experience = {
		name = L["Experience"],
		desc = L["Abbreviate and simplify experience- and level gains."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	loot = {
		name = L["Loot"],
		desc = L["Abbreviate and simplify loot-, currency- and received item messages."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	names = {
		name = L["Player Names"],
		desc = L["Remove brackets from player names."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	quests = {
		name = L["Quests"],
		desc = L["Simplify quest completion- and progress messages."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	reputation = {
		name = L["Reputation"],
		desc = L["Simplify messages about reputation gain and loss."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	spells = {
		name = L["Learning (Spells)"],
		desc = L["Blacklist messages about new or removed spells, typically spammed on specialization changes."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	status = {
		name = L["Player Status"],
		desc = L["Simplify status messages about AFK, DND and being rested."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	tradeskills = {
		name = L["Learning (Crafting)"],
		desc = L["Simplify messages about new or improved trade skills."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	honor = {
		name = L["Honor"],
		desc = L["Simplify PvP honor gain messages."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	opening = {
		name = L["Opening"],
		desc = L["Hide opening and unlocking messages (lockpicking, chests)."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	petinfo = {
		name = L["Pet Info"],
		desc = L["Hide pet happiness and ability messages."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	miscinfo = {
		name = L["Misc Info"],
		desc = L["Hide miscellaneous combat info like combo points and small power gains."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	systemmessages = {
		name = L["System Messages"],
		desc = L["Hide repetitive system messages like session started."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
	bossmessages = {
		name = L["Boss Messages"],
		desc = L["Format boss emotes and whispers with distinct colors."],
		width = 1.5,
		type = "toggle",
		set = setter,
		get = getter,
	},
}

Options.GenerateOptionsMenu = function(self)
	-- Sort filter entries by localized name.
	local sorted = {}
	for name, item in next, filterDB do
		if item then
			sorted[#sorted + 1] = { name = name, item = item }
		end
	end
	table_sort(sorted, function(a, b)
		return a.item.name < b.item.name
	end)

	-- Build the CleanerChat "Filters" category from optionDB + the filter toggles.
	local ccGroup = CopyTable(optionDB)
	ccGroup.name = "Filters"
	ccGroup.order = 1
	local order, count = 0, 0
	for i, data in ipairs(sorted) do
		local item
		if type(data.item) == "function" then
			item = data.item()
		else
			item = data.item
		end
		if item then
			count = count + 1
			order = order + 10
			item.order = 100 + order
			ccGroup.args[data.name] = item
		end
	end

	-- Top-level tree. The Glass UI settings are merged in as additional
	-- categories so everything lives under /cc (Glass no longer has /glass).
	-- The version is read live from the .toc so the header always matches it.
	local tocVersion = GetAddOnMetadata(Addon, "Version")
	local title = tocVersion and ("CleanerChat V" .. tocVersion) or "CleanerChat"
	local options = {
		name = title,
		type = "group",
		args = {
			cleanerchat = ccGroup,
		},
	}

	local glass = _G.Glass
	if glass and glass.configGroups then
		-- Order them after the Filters tab; keep Profiles last.
		local glassOrders = {
			general = 2,
			editBox = 3,
			messages = 4,
			topBar = 5,
			profile = 100,
		}
		for key, group in next, glass.configGroups do
			if type(group) == "table" then
				group.order = glassOrders[key] or 50
				options.args[key] = group
			end
		end
	end

	-- Inject the CleanerChat "/ccdebug" chat-capture toggle into the General
	-- tab. The state lives in ns.db (so it survives /reload) and is applied
	-- through ns.SetRawDebug. Defined here (not in Glass) so it stays a
	-- CleanerChat-owned setting; idempotent on rebuild.
	local generalTab = options.args.general
	-- Glass's General category is now a per-window tab group (its args are the
	-- window tabs: Main, Window 2, ...). This global debug toggle isn't
	-- per-window, so place it on the Main window's tab. Fall back to the
	-- category args directly if Glass isn't tabbed (older layout).
	local debugTarget
	if generalTab and generalTab.args then
		if generalTab.args.Main and generalTab.args.Main.args then
			debugTarget = generalTab.args.Main.args
		else
			debugTarget = generalTab.args
		end
	end
	if debugTarget then
		debugTarget.ccDebugSection = {
			name = "Debugging",
			type = "group",
			inline = true,
			order = 90,
			args = {
				rawDebug = {
					name = L["Chat Debug Capture"],
					desc = L["Print the raw text and underlying event for every chat line, for diagnosing filters (same as /ccdebug). Stays on across /reload."],
					type = "toggle",
					width = "full",
					order = 1,
					get = function()
						return ns.GetRawDebug and ns.GetRawDebug()
					end,
					set = function(info, val)
						if ns.SetRawDebug then
							ns.SetRawDebug(val)
						end
					end,
				},
			},
		}
	end

	AceConfigRegistry:RegisterOptionsTable(Addon, options)
	AceConfigDialog:SetDefaultSize(Addon, 900, 650)
end

-- Reload-on-close tracking
-------------------------------------------------------
-- Snapshot of the settings as they were when the window was opened.
-- Used to detect whether the user actually changed anything.
-- Note: Only include settings that REQUIRE a reload to take effect.
-- Settings that apply immediately (like channelNameMode) should NOT be here.
Options.TakeSettingsSnapshot = function(self)
	self.snapshot = {
		filters = CopyTable(ns.db.filters),
	}
end

-- Returns true if the current settings differ from the snapshot.
-- Reverting all changes back to the saved values makes this false again.
-- Only checks settings that require a reload - dynamic settings are excluded.
Options.IsDirty = function(self)
	local snapshot = self.snapshot
	if not snapshot then
		return false
	end
	for key, value in next, snapshot.filters do
		if ns.db.filters[key] ~= value then
			return true
		end
	end
	return false
end

-- Updates the status text shown left of the Close button.
Options.UpdateReloadStatus = function(self)
	local frame = AceConfigDialog.OpenFrames[Addon]
	if not frame or not frame.SetStatusText then
		return
	end
	-- Get the status bar background (parent of statustext)
	local statusbg = frame.statustext and frame.statustext:GetParent()
	if self:IsDirty() then
		frame:SetStatusText(
			"|cffffd200" .. L["Settings changed - the UI will reload when you close this window."] .. "|r"
		)
		if statusbg then
			statusbg:Show()
		end
	else
		frame:SetStatusText("")
		if statusbg then
			statusbg:Hide()
		end
	end
end

Options.OpenOptionsMenu = function(self, input)
	-- "/cc lock" unlocks the Glass frame (mirrors the old "/glass lock").
	if input == "lock" then
		if _G.Glass and _G.Glass.UnlockFrame then
			_G.Glass.UnlockFrame()
		end
		return
	end

	-- Always rebuild so categories that load later (e.g. the Glass UI tabs)
	-- are picked up, and so the table reflects the latest settings.
	local genOk, genErr = pcall(self.GenerateOptionsMenu, self)
	if not genOk then
		print("|cffff7d0aCleanerChat|r: failed to build the options menu.")
		print("|cffff0000" .. tostring(genErr) .. "|r")
		return
	end

	if AceConfigRegistry:GetOptionsTable(Addon) then
		local ok, err = pcall(AceConfigDialog.Open, AceConfigDialog, Addon)
		if not ok then
			print("|cffff7d0aCleanerChat|r: failed to open the options window.")
			print("|cffff0000" .. tostring(err) .. "|r")
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

	if frame and frame.frame and not frame.frame.ccReloadHooked then
		frame.frame.ccReloadHooked = true
		frame.frame:HookScript("OnHide", function()
			if Options:IsDirty() then
				ReloadUI()
			end
		end)
	end

	self:UpdateReloadStatus()
end

Options.OnEvent = function(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = ...
		if isInitialLogin or isReloadingUi then
			local ok, err = pcall(self.GenerateOptionsMenu, self)
			if not ok then
				print("|cffff7d0aCleanerChat|r: failed to build the options menu.")
				print("|cffff0000" .. tostring(err) .. "|r")
			end
			self:UnregisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
		end
	end
end

Options.OnInitialize = function(self)
	self:RegisterChatCommand("cc", "OpenOptionsMenu")
	self:RegisterChatCommand("cleanerchat", "OpenOptionsMenu")
	-- TEMPORARY DIAGNOSTIC command (see Components/_Debug.lua).
	self:RegisterChatCommand("ccdebug", function()
		if ns.ToggleRawDebug then
			ns.ToggleRawDebug()
		end
	end)
end

Options.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end
