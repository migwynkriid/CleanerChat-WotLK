local _, ns = ...

local Module = ns:NewModule("Achievements")

-- Lua API
local string_format = string.format
local string_match = string.match

-- WoW Globals
local G = {
	ACHIEVEMENT_BROADCAST = ACHIEVEMENT_BROADCAST, -- "%s has earned the achievement %s!"
}

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	if ns:IsProtectedMessage(message) then
		return
	end

	local player_name, achievement = string_match(message, P[G.ACHIEVEMENT_BROADCAST])
	if player_name and achievement then
		-- Sometime personal achievements are posted
		-- both personally and as a guild achievement.
		-- We only need to see them once.
		if self.lastMessage == message then
			return true
		end

		-- Store the previous achievement message.
		self.lastMessage = message

		-- kill brackets
		player_name = ns.StripBrackets(player_name)
		achievement = ns.StripBrackets(achievement)

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
