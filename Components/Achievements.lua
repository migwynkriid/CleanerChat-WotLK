local Addon, ns = ...

local Module = ns:NewModule("Achievements")

-- Addon Localization
local L = LibStub("AceLocale-3.0"):GetLocale((...))

-- Lua API
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match

-- WoW Globals
local G = {
	ACHIEVEMENT_BROADCAST = ACHIEVEMENT_BROADCAST -- "%s has earned the achievement %s!"
}

-- Convert a WoW global string to a search pattern
local makePattern = ns.MakePattern

-- Search Pattern Cache.
-- This will generate the pattern on the first lookup.
local P = setmetatable({}, { __index = function(t,k)
	if (k == nil) or (k == "") then return nil end
	rawset(t,k,makePattern(k))
	return rawget(t,k)
end })

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	if (ns:IsProtectedMessage(message)) then return end

	local player_name, achievement = string_match(message, P[G.ACHIEVEMENT_BROADCAST])
	if (player_name and achievement) then

		-- Sometime personal achievements are posted
		-- both personally and as a guild achievement.
		-- We only need to see them once.
		if (self.lastMessage == message) then
			return true
		end

		-- Store the previous achievement message.
		self.lastMessage = message

		-- kill brackets
		player_name = string_gsub(player_name, "[%[/%]]", "")
		achievement = string_gsub(achievement, "[%[/%]]", "")

		return false, string_format(ns.out.achievement, player_name, achievement), author, ...
	end
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

Module.OnEnable = function(self)
	self:RegisterMessageEventFilter("CHAT_MSG_ACHIEVEMENT", onChatEventProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_GUILD_ACHIEVEMENT", onChatEventProxy)
end

Module.OnDisable = function(self)
	self:UnregisterMessageEventFilter("CHAT_MSG_ACHIEVEMENT", onChatEventProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_GUILD_ACHIEVEMENT", onChatEventProxy)
end
