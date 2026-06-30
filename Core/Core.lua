local Addon, ns = ...

ns = LibStub("AceAddon-3.0"):NewAddon(ns, Addon, "LibMoreEvents-1.0", "AceConsole-3.0", "AceHook-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale(Addon)

-- GLOBALS: CHAT_FRAMES, FCF_GetCurrentChatFrame, GetChatTypeIndex

-- Lua API
local _G = _G
local ipairs = ipairs
local next = next
local setmetatable = setmetatable
local string_find = string.find
local string_format = string.format
local string_match = string.match
local string_gsub = string.gsub
local string_lower = string.lower
local string_upper = string.upper
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local type = type

-- These channels will be ignored by the general parsing.
-- This does not affect the chat event filters,
-- and is only meant to avoid normal chat messages
-- giving off false positives as system messages.
local ignoredIDs = {}
for _, index in ipairs({

	--"SYSTEM",
	"SAY",
	"PARTY",
	"RAID",
	"GUILD",
	"OFFICER",
	"YELL",
	"WHISPER",
	"SMART_WHISPER",
	"WHISPER_INFORM",
	"REPLY",
	"EMOTE",
	"TEXT_EMOTE",
	"MONSTER_SAY",
	"MONSTER_PARTY",
	"MONSTER_YELL",
	"MONSTER_WHISPER",
	"MONSTER_EMOTE",
	"CHANNEL",
	"CHANNEL_JOIN",
	"CHANNEL_LEAVE",
	"CHANNEL_LIST",
	"CHANNEL_NOTICE",
	"CHANNEL_NOTICE_USER",
	"TARGETICONS",
	"AFK",
	"DND",
	"IGNORED",
	--"SKILL",
	--"LOOT",
	--"CURRENCY",
	--"MONEY",
	--"OPENING",
	--"TRADESKILLS",
	"PET_INFO",
	"COMBAT_MISC_INFO",
	--"COMBAT_XP_GAIN",
	--"COMBAT_HONOR_GAIN",
	--"COMBAT_FACTION_CHANGE",
	"BG_SYSTEM_NEUTRAL",
	"BG_SYSTEM_ALLIANCE",
	"BG_SYSTEM_HORDE",
	"RAID_LEADER",
	"RAID_WARNING",
	"RAID_BOSS_WHISPER",
	"RAID_BOSS_EMOTE",
	"QUEST_BOSS_EMOTE",
	"FILTERED",
	"INSTANCE_CHAT",
	"INSTANCE_CHAT_LEADER",
	"RESTRICTED",
	"CHANNEL1",
	"CHANNEL2",
	"CHANNEL3",
	"CHANNEL4",
	"CHANNEL5",
	"CHANNEL6",
	"CHANNEL7",
	"CHANNEL8",
	"CHANNEL9",
	"CHANNEL10",
	"CHANNEL11",
	"CHANNEL12",
	"CHANNEL13",
	"CHANNEL14",
	"CHANNEL15",
	"CHANNEL16",
	"CHANNEL17",
	"CHANNEL18",
	"CHANNEL19",
	"CHANNEL20",
	"ACHIEVEMENT",
	"PARTY_LEADER",
	"BN_WHISPER",
	"BN_WHISPER_INFORM",
	"BN_ALERT",
	"BN_BROADCAST",
	"BN_BROADCAST_INFORM",
	"BN_INLINE_TOAST_ALERT",
	"BN_INLINE_TOAST_BROADCAST",
	"BN_INLINE_TOAST_BROADCAST_INFORM",
	"BN_WHISPER_PLAYER_OFFLINE",
	"COMMUNITIES_CHANNEL",
	"VOICE_TEXT",
}) do
	local id = GetChatTypeIndex(index)
	if id then
		ignoredIDs[id] = true
	end
end

local blacklist = setmetatable({}, {
	__call = function(self, ...)
		for _, func in next, self do
			if func(...) then
				return true
			end
		end
	end,
})

-- Factory for a callable replacement-set container. Invoking the returned table
-- runs `msg` through every registered set, where a set is either a table of
-- { pattern, replacement } pairs or a function. Both the regular and the
-- special (blacklist-ignoring) groups are built from this, so their iteration
-- logic can never drift apart.
local function makeReplacementSet()
	return setmetatable({}, {
		__call = function(self, msg, ...)
			if not msg then
				return msg
			end

			-- Iterate all registered replacement sets.
			for i, set in next, self do
				-- Check if the module has supplied
				-- a table of string replacements or a func.
				if type(set) == "table" then
					-- The module has supplied a table, iterate it.
					for k, data in ipairs(set) do
						if data[1] and data[2] and (string_match(msg, data[1])) then
							-- string_gsub handles function replacements by passing captures
							msg = string_gsub(msg, data[1], data[2])
						end
					end
				elseif type(set) == "function" then
					msg = set(msg, ...) or msg
				end
			end

			return msg, ...
		end,
	})
end

local replacements = makeReplacementSet()
local specialreplacements = makeReplacementSet()

local modulePrototype = {

	-- @input event <string>
	-- @input method <string,func>
	RegisterMessageEventFilter = function(self, event, method)
		local func = (type(method) == "string") and self[method]
		ChatFrame_AddMessageEventFilter(event, func or method)
	end,

	-- @input event <string>
	-- @input method <string,func>
	UnregisterMessageEventFilter = function(self, event, method)
		local func = (type(method) == "string") and self[method]
		ChatFrame_RemoveMessageEventFilter(event, func or method)
	end,

	-- @input set <table,func>
	RegisterBlacklistFilter = function(self, method)
		local func = (type(method) == "string") and self[method]
		ns:AddBlacklistMethod(func or method)
	end,

	-- @input set <table,func>
	UnregisterBlacklistFilter = function(self, method)
		local func = (type(method) == "string") and self[method]
		ns:RemoveBlacklistMethod(func or method)
	end,

	-- @input set <table,func>
	RegisterMessageReplacement = function(self, set, ignoreBlacklist)
		ns:AddReplacementSet(set, ignoreBlacklist)
	end,

	-- @input set <table,func>
	UnregisterMessageReplacement = function(self, set)
		ns:RemoveReplacementSet(set)
	end,
}

-- Setup the module defaults.
ns:SetDefaultModuleState(false)
ns:SetDefaultModulePrototype(modulePrototype)

-- Addon default settings.
local defaults = {
	channelNameMode = "initial", -- "initial" shows the first letter (e.g. "[G]"), "full" shows the whole name
	channelNumber = true, -- prefix the channel display with its number, e.g. "1. "
	channelCapitalize = true, -- capitalize the channel name/initial
	capitalizeNames = true, -- capitalize the first letter of player names
	moneyPrettify = true, -- use spaces in large gold amounts (e.g. "1 234" instead of "1234")
	hideOtherCrafts = false, -- hide other players' "<name> creates <item>" craft broadcasts
	hideUIErrors = true, -- hide the server's "UI Error: an interface error occured" chat notification
	showStartupMessage = true, -- print "Use /cc for settings" on addon load
	rawDebug = false, -- /ccdebug chat raw/event capture (persists across /reload)
	oneLineQuestRewards = true, -- combine quest rewards (items, currency, xp) into one line
	showItemDestruction = true, -- show "- item" when destroying items
	showVendorSales = true, -- show "- item" when selling to vendors
	prettifyGuildStatus = true, -- prettify guild online/offline messages
	filters = {
		achievements = true,
		auctions = true,
		channels = true,
		experience = true,
		loot = true,
		names = true,
		quests = true,
		reputation = true,
		spells = true,
		status = true,
		tradeskills = true,
	},
}

-- Expose defaults for external reset functionality
ns.defaults = defaults

CleanerChat_DB = CopyTable(defaults)

-- Reset CleanerChat settings to defaults and update module states
ns.ResetCleanerChatSettings = function(self)
	for key, value in next, defaults do
		if type(value) == "table" then
			CleanerChat_DB[key] = CopyTable(value)
		else
			CleanerChat_DB[key] = value
		end
	end
	self.db = CleanerChat_DB

	-- Update module enable/disable states based on new filter values
	for setting, value in next, self.db.filters do
		local moduleName = self:GetModuleNameFromFilter(setting)
		local module = self:GetModule(moduleName, true)
		if module then
			if value and not module:IsEnabled() then
				module:Enable()
			elseif not value and module:IsEnabled() then
				module:Disable()
			end
		end
	end
end

ns.IsProtectedMessage = function(self, msg)
	if not msg or msg == "" then
		return
	end
	if string_find(msg, "|Hquestie") then
		return true
	end
end

-- Run a message through CleanerChat's special replacements, blacklists and
-- replacements. Returns the cleaned message, or nil if the message was
-- blacklisted and should be dropped entirely.
-- This is pure (it doesn't render anything), so other display layers such as
-- the Glass chat UI can reuse it to show identically formatted messages.
ns.FilterMessage = function(self, chatFrame, msg, r, g, b, chatID, ...)
	if not msg or msg == "" then
		return msg
	end

	-- TODO:
	-- *Encode Questie links, parse encoded string, decode Questie link.
	--  This will ensure their links is uncorrupted but the line parsed in full.
	if not ns:IsProtectedMessage(msg) then
		-- Parse replacements that ignore the blacklists.
		if next(specialreplacements) then
			msg = specialreplacements(msg, r, g, b, chatID, ...)
		end

		-- Parse regular blacklists and replacements.
		if not (chatID and ignoredIDs[chatID]) then
			-- Completely filter out matches.
			if next(blacklist) then
				if blacklist(chatFrame, msg, r, g, b, chatID, ...) then
					return nil
				end
			end

			-- Return a modified string.
			if next(replacements) then
				msg = replacements(msg, r, g, b, chatID, ...)
			end
		end
	end

	return msg
end

ns.AddMessageFiltered = function(self, chatFrame, msg, r, g, b, chatID, ...)
	if not msg or msg == "" then
		return
	end

	-- Blacklisted messages return nil and are dropped entirely.
	local filtered = self:FilterMessage(chatFrame, msg, r, g, b, chatID, ...)
	if filtered == nil then
		return
	end

	return self.MethodCache[chatFrame](chatFrame, filtered, r, g, b)
end

ns.CacheMessageMethod = function(self, chatFrame)
	if not self.MethodCache then
		self.MethodCache = {}
	end

	if not self.MethodCache[chatFrame] then
		-- Copy the current AddMessage method from the frame.
		-- *this also functions as our "has been handled" indicator.
		self.MethodCache[chatFrame] = chatFrame.AddMessage

		-- Replace with our filtered AddMessage method.
		chatFrame.AddMessage = function(...)
			self:AddMessageFiltered(...)
		end
	end
end

ns.AddBlacklistMethod = function(self, func)
	-- Make sure the function isn't in our database already.
	for _, infunc in next, blacklist do
		if infunc == func then
			return
		end
	end
	table_insert(blacklist, func)
end

ns.RemoveBlacklistMethod = function(self, func)
	for k = #blacklist, 1, -1 do
		if blacklist[k] == func then
			table_remove(blacklist, k)
			break
		end
	end
end

ns.AddReplacementSet = function(self, set, ignoreBlacklist)
	local group = ignoreBlacklist and specialreplacements or replacements

	-- Make sure the replacement set hasn't already been added.
	for _, inset in next, group do
		if inset == set then
			return
		end
	end

	table_insert(group, set)
end

ns.RemoveReplacementSet = function(self, set)
	for k = #replacements, 1, -1 do
		if replacements[k] == set then
			table_remove(replacements, k)
			break
		end
	end
	for k = #specialreplacements, 1, -1 do
		if specialreplacements[k] == set then
			table_remove(specialreplacements, k)
			break
		end
	end
end

local messageProxy = function()
	ns:CacheMessageMethod((FCF_GetCurrentChatFrame()))
end

ns.CacheAllMessageMethods = function(self)
	for _, chatFrameName in ipairs(CHAT_FRAMES) do
		self:CacheMessageMethod(_G[chatFrameName])
	end
	if not self:IsHooked("FCF_OpenTemporaryWindow", messageProxy) then
		self:SecureHook("FCF_OpenTemporaryWindow", messageProxy)
	end
end

-- Convert a stored filter key (e.g. "achievements") to its
-- corresponding module name (e.g. "Achievements").
ns.GetModuleNameFromFilter = function(self, key)
	return (string_gsub(key, "^%l", string_upper))
end

ns.UpgradeSettings = function(self)
	-- Have the db been upgraded?
	if not CleanerChat_DB.configversion or CleanerChat_DB.configversion < 2 then
		-- Work on a clone.
		local old = CopyTable(CleanerChat_DB)

		-- Replace missing entries with the defaults
		for setting, value in next, defaults do
			if CleanerChat_DB[setting] == nil then
				CleanerChat_DB[setting] = value
			end
		end

		-- Parse the cloned db for outdated entries.
		for setting, value in next, old do
			-- Only parse old filter settings.
			local moduleName = string_match(setting, "DisableFilter:(.*)")
			if moduleName then
				-- Old settings are true when the filter is disabled,
				-- new settings are true when filter is enabled.
				-- The old setting naming scheme has also been replaced.
				CleanerChat_DB[setting] = nil
				CleanerChat_DB.filters[string_lower(moduleName)] = not value
			end
		end

		-- Replace missing filter settings with their defaults.
		for setting, value in next, defaults.filters do
			if CleanerChat_DB.filters[setting] == nil then
				CleanerChat_DB.filters[setting] = value
			end
		end

		-- Store the new settings version
		-- so we never have to do this again.
		CleanerChat_DB.configversion = 2
	end

	-- Always backfill any newly added default settings,
	-- so existing users get sane values for new options.
	for setting, value in next, defaults do
		if type(value) ~= "table" and CleanerChat_DB[setting] == nil then
			CleanerChat_DB[setting] = value
		end
	end
	if CleanerChat_DB.filters then
		for setting, value in next, defaults.filters do
			if CleanerChat_DB.filters[setting] == nil then
				CleanerChat_DB.filters[setting] = value
			end
		end
	end

	-- Return a more sane db.
	return CleanerChat_DB
end

-- Quest Reward Buffering System
-- When oneLineQuestRewards is enabled, collect items, currency, and XP
-- that fire in the same frame (e.g. quest turn-in) and output as one line.
-- Batching (per chat frame + next-frame flush) is handled by ns.CreateFrameBuffer.
local questRewardBuffer = ns.CreateFrameBuffer(function()
	return { items = {}, xp = nil, money = nil }
end, function(chatFrame, buf)
	-- Build the combined output
	local parts = {}

	-- Add items (already formatted with color and count)
	for _, itemText in ipairs(buf.items) do
		parts[#parts + 1] = itemText
	end

	-- Add money (already formatted)
	if buf.money then
		parts[#parts + 1] = buf.money
	end

	-- Add XP
	if buf.xp then
		parts[#parts + 1] = buf.xp
	end

	if #parts > 0 then
		local text = ns.out.quest_rewards_combined
		if text then
			text = string_format(text, table_concat(parts, ", "))
		else
			-- Fallback if output format not yet loaded
			text = "|cff00ff00+|r " .. table_concat(parts, ", ")
		end

		-- Match the colour these messages normally display with.
		ns.PrintToFrame(chatFrame, text, "LOOT")
	end
end)

-- Public API for modules to add rewards to the buffer
ns.AddQuestReward = function(self, chatFrame, rewardType, rewardText)
	if not self.db or not self.db.oneLineQuestRewards then
		return false -- Not buffering, let module handle normally
	end

	if not chatFrame or not chatFrame.AddMessage then
		return false
	end

	local buf = questRewardBuffer.Get(chatFrame)

	if rewardType == "item" then
		buf.items[#buf.items + 1] = rewardText
	elseif rewardType == "xp" then
		buf.xp = rewardText
	elseif rewardType == "money" then
		buf.money = rewardText
	else
		return false
	end

	-- Defer the combined flush to the next frame (idempotent per frame).
	questRewardBuffer.Schedule(chatFrame)

	return true -- Reward was buffered
end

ns.OnInitialize = function(self)
	self.db = self:UpgradeSettings()

	-- Always enable the options menu module.
	self:GetModule("Options"):Enable()
end

ns.OnEnable = function(self)
	-- Sanitize nil chat args to prevent strlen crashes from malformed server messages
	local function sanitizeSystemMessage(frame, event, ...)
		local args = { ... }
		for i = 1, 12 do
			if args[i] == nil then
				args[i] = ""
			end
		end
		return false, unpack(args)
	end
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", sanitizeSystemMessage)

	-- Initial caching of all chat frame message methods.
	self:CacheAllMessageMethods()

	-- Enable modules.
	for setting, value in next, self.db.filters do
		local moduleName = self:GetModuleNameFromFilter(setting)
		local module = ns:GetModule(moduleName, true)
		if module then
			if value and not module:IsEnabled() then
				module:Enable()
			elseif not value and module:IsEnabled() then
				module:Disable()
			end
		end
	end

	-- Always enabled modules.
	self:GetModule("Money"):Enable()
	self:GetModule("ClassColors"):Enable()
	self:GetModule("QualityColors"):Enable()
	self:GetModule("Blacklist"):Enable()
	self:GetModule("Empty"):Enable()
	self:GetModule("VersionCheck"):Enable()

	-- Print startup message (delayed so it's visible after login spam)
	if self.db.showStartupMessage then
		-- Use internal ns.Timer (or native C_Timer if available)
		if ns.Timer and ns.Timer.After then
			ns.Timer.After(2, function()
				print("|cffDFBA69CleanerChat|r: " .. string_format(L["Use %s for settings."], "|cffffd200/cc|r"))
			end)
		elseif C_Timer and C_Timer.After then
			C_Timer.After(2, function()
				print("|cffDFBA69CleanerChat|r: " .. string_format(L["Use %s for settings."], "|cffffd200/cc|r"))
			end)
		else
			print("|cffDFBA69CleanerChat|r: " .. string_format(L["Use %s for settings."], "|cffffd200/cc|r"))
		end
	end
end
