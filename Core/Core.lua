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

ns = LibStub("AceAddon-3.0"):NewAddon(ns, Addon, "LibMoreEvents-1.0", "AceConsole-3.0", "AceHook-3.0")

-- GLOBALS: CHAT_FRAMES, FCF_GetCurrentChatFrame, GetChatTypeIndex

-- Lua API
local _G = _G
local ipairs = ipairs
local next = next
local pairs = pairs
local rawset = rawset
local setmetatable = setmetatable
local string_find = string.find
local string_match = string.match
local string_gsub = string.gsub
local string_lower = string.lower
local string_upper = string.upper
local table_insert = table.insert
local table_remove = table.remove
local type = type
local unpack = unpack

-- These channels will be ignored by the general parsing.
-- This does not affect the chat event filters,
-- and is only meant to avoid normal chat messages
-- giving off false positives as system messages.
local ignoredIDs = {}
for _,index in ipairs({

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
	"VOICE_TEXT"

}) do
	local id = GetChatTypeIndex(index)
	if (id) then
		ignoredIDs[id] = true
	end
end

local blacklist = setmetatable({}, {
	__call = function(self, ...)
		for _,func in next,self do
			if (func(...)) then
				return true
			end
		end
	end
})

local replacements = setmetatable({}, {
	__call = function(self, msg, ...)

		-- Iterate all registered replacement sets.
		for i,set in next,self do

			-- Check if the module has supplied
			-- a table of string replacements or a func.
			if (type(set) == "table") then

				-- The module has supplied a table, iterate it.
				for k,data in ipairs(set) do
					if (string_match(msg, data[1])) then
						msg = string_gsub(msg, data[1], data[2])
					end
				end

			elseif (type(set == "func")) then
				msg = set(msg, ...) or msg
			end
		end

		return msg, ...
	end
})

local specialreplacements
specialreplacements = setmetatable({}, {
	__call = function(self, msg, ...)

		-- Iterate all registered replacement sets.
		for i,set in next,self do

			-- Check if the module has supplied
			-- a table of string replacements or a func.
			if (type(set) == "table") then

				-- The module has supplied a table, iterate it.
				for k,data in ipairs(set) do
					if (string_match(msg, data[1])) then
						msg = string_gsub(msg, data[1], data[2])
					end
				end

			elseif (type(set == "func")) then
				msg = set(msg, ...) or msg
			end
		end

		return msg, ...
	end
})

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
	end
}

-- Setup the module defaults.
ns:SetDefaultModuleState(false)
ns:SetDefaultModulePrototype(modulePrototype)

-- Addon default settings.
local defaults = {
	styling = true, -- will be ignored when conflicting addons are detected
	channelNameMode = "initial", -- "initial" shows the first letter (e.g. "[G]"), "full" shows the whole name
	channelNumber = true, -- prefix the channel display with its number, e.g. "1. "
	channelCapitalize = true, -- capitalize the channel name/initial
	capitalizeNames = true, -- capitalize the first letter of player names
	filters = {
		achievements = true,
		auctions = true,
		channels = true,
		empty = true,
		experience = true,
		loot = true,
		names = true,
		quests = true,
		reputation = true,
		spells = true,
		status = true,
		tradeskills = true
	}
}

CleanerChat_DB = CopyTable(defaults)

ns.IsProtectedMessage = function(self, msg)
	if (not msg or msg == "") then return end
	if (string_find(msg, "|Hquestie")) then
		return true
	end
end

-- Run a message through CleanerChat's special replacements, blacklists and
-- replacements. Returns the cleaned message, or nil if the message was
-- blacklisted and should be dropped entirely.
-- This is pure (it doesn't render anything), so other display layers such as
-- the Glass chat UI can reuse it to show identically formatted messages.
ns.FilterMessage = function(self, chatFrame, msg, r, g, b, chatID, ...)
	if (not msg or msg == "") then return msg end

	-- TODO:
	-- *Encode Questie links, parse encoded string, decode Questie link.
	--  This will ensure their links is uncorrupted but the line parsed in full.
	if (not ns:IsProtectedMessage(msg)) then

		-- Parse replacements that ignore the blacklists.
		if (next(specialreplacements)) then
			msg = specialreplacements(msg, r, g, b, chatID, ...)
		end

		-- Parse regular blacklists and replacements.
		if not(chatID and ignoredIDs[chatID]) then

			-- Completely filter out matches.
			if (next(blacklist)) then
				if (blacklist(chatFrame, msg, r, g, b, chatID, ...)) then
					return nil
				end
			end

			-- Return a modified string.
			if (next(replacements)) then
				msg = replacements(msg, r, g, b, chatID, ...)
			end
		end
	end

	return msg
end

ns.AddMessageFiltered = function(self, chatFrame, msg, r, g, b, chatID, ...)
	if (not msg or msg == "") then return end

	-- Blacklisted messages return nil and are dropped entirely.
	local filtered = self:FilterMessage(chatFrame, msg, r, g, b, chatID, ...)
	if (filtered == nil) then return end

	return self.MethodCache[chatFrame](chatFrame, filtered, r, g, b)
end

ns.CacheMessageMethod = function(self, chatFrame)
	if (not self.MethodCache) then
		self.MethodCache = {}
	end

	if (not self.MethodCache[chatFrame]) then
		-- Copy the current AddMessage method from the frame.
		-- *this also functions as our "has been handled" indicator.
		self.MethodCache[chatFrame] = chatFrame.AddMessage

		-- Replace with our filtered AddMessage method.
		chatFrame.AddMessage = function(...) self:AddMessageFiltered(...) end
	end
end

ns.AddBlacklistMethod = function(self, func)
	-- Make sure the function isn't in our database already.
	for _,infunc in next,blacklist do
		if (infunc == func) then
			return
		end
	end
	table_insert(blacklist, func)
end

ns.RemoveBlacklistMethod = function(self, func)
	for k = #blacklist, 1, -1 do
		if (blacklist[k] == func) then
			table_remove(blacklist, k)
			break
		end
	end
end

ns.AddReplacementSet = function(self, set, ignoreBlacklist)
	local group = ignoreBlacklist and specialreplacements or replacements

	-- Make sure the replacement set hasn't already been added.
	for _,inset in next,group do
		if (inset == set) then
			return
		end
	end

	table_insert(group, set)
end

ns.RemoveReplacementSet = function(self, set)
	for k = #replacements, 1, -1 do
		if (replacements[k] == set) then
			table_remove(replacements, k)
			break
		end
	end
	for k = #specialreplacements, 1, -1 do
		if (specialreplacements[k] == set) then
			table_remove(specialreplacements, k)
			break
		end
	end
end

local messageProxy = function()
	ns:CacheMessageMethod((FCF_GetCurrentChatFrame()))
end

ns.CacheAllMessageMethods = function(self)
	for _,chatFrameName in ipairs(CHAT_FRAMES) do
		self:CacheMessageMethod(_G[chatFrameName])
	end
	if (not self:IsHooked("FCF_OpenTemporaryWindow", messageProxy)) then
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
	if (not CleanerChat_DB.configversion or CleanerChat_DB.configversion < 2) then

		-- Work on a clone.
		local old = CopyTable(CleanerChat_DB)

		-- Replace missing entries with the defaults
		for setting,value in next,defaults do
			if (CleanerChat_DB[setting] == nil) then
				CleanerChat_DB[setting] = value
			end
		end

		-- Parse the cloned db for outdated entries.
		for setting,value in next,old do

			-- Only parse old filter settings.
			local moduleName = string_match(setting,"DisableFilter:(.*)")
			if (moduleName) then

				-- Old settings are true when the filter is disabled,
				-- new settings are true when filter is enabled.
				-- Also, old naming scheme was horrible.
				CleanerChat_DB[setting] = nil
				CleanerChat_DB.filters[string_lower(moduleName)] = not value
			end
		end

		-- Replace missing filter settings with their defaults.
		for setting,value in next,defaults.filters do
			if (CleanerChat_DB.filters[setting] == nil) then
				CleanerChat_DB.filters[setting] = value
			end
		end

		-- Store the new settings version
		-- so we never have to do this again.
		CleanerChat_DB.configversion = 2
	end

	-- Always backfill any newly added default settings,
	-- so existing users get sane values for new options.
	for setting,value in next,defaults do
		if (type(value) ~= "table" and CleanerChat_DB[setting] == nil) then
			CleanerChat_DB[setting] = value
		end
	end
	if (CleanerChat_DB.filters) then
		for setting,value in next,defaults.filters do
			if (CleanerChat_DB.filters[setting] == nil) then
				CleanerChat_DB.filters[setting] = value
			end
		end
	end

	-- Return a more sane db.
	return CleanerChat_DB
end

ns.OnInitialize = function(self)
	self.db = self:UpgradeSettings()

	-- Always enable the options menu module.
	self:GetModule("Options"):Enable()
end

ns.OnEnable = function(self)

	self.WAIT_FOR_EXTERNAL = ns.API.IsAddOnEnabled("AzeriteUI")

	-- Initial caching of all chat frame message methods.
	self:CacheAllMessageMethods()

	-- Enable modules.
	for setting,value in next,self.db.filters do
		local moduleName = self:GetModuleNameFromFilter(setting)
		local module = ns:GetModule(moduleName, true)
		if (module) then
			if (value and not module:IsEnabled()) then
				module:Enable()
			elseif (not value and module:IsEnabled()) then
				module:Disable()
			end
		end
	end

	-- Always enabled modules.
	self:GetModule("Money"):Enable()
	self:GetModule("ClassColors"):Enable()
	self:GetModule("QualityColors"):Enable()
	self:GetModule("Blacklist"):Enable()

	-- Enable development version modules.
	-- *not recommended for the public
	if (ns.Version == "Development") then
		self:GetModule("DevelopmentFilters"):Enable()
		self:GetModule("Creatures"):Enable()
	end

end

