local _, ns = ...

local Module = ns:NewModule("Channeljoin")

-- Lua API
local string_find = string.find
local string_gsub = string.gsub

-- True if the line is a channel join/leave/change NOTICE (not player chat).
-- Anchored to the start of the line (after stripping any leading colour code) so
-- it matches the notice -- e.g. "Left Channel: <channel>" -- but never a normal
-- message that merely mentions the phrase, which renders as "[chan] Sender: ...".
local function isChannelNotice(msg)
	local text = string_gsub(msg, "^|c%x%x%x%x%x%x%x%x", "")
	if
		string_find(text, "^Joined Channel")
		or string_find(text, "^Left Channel")
		or string_find(text, "^Changed Channel")
	then
		return true
	end
	return false
end

-- Filter channel join/leave/change notices. On this client they render as a
-- direct AddMessage carrying the CHANNEL's own chat-type id, which is in
-- CleanerChat's ignoredIDs set -- so the normal (gated) blacklist skips them.
-- Registered as an UNCONDITIONAL blacklist (see ns.FilterMessage) so it runs
-- regardless of chatID.
Module.OnAddMessage = function(_, _, msg)
	if not msg then
		return
	end

	if isChannelNotice(msg) then
		return true
	end
end

local onAddMessageProxy = function(...)
	return Module:OnAddMessage(...)
end

-- Filter the actual CHAT_MSG_CHANNEL_NOTICE event
-- In WotLK 3.3.5, message is the notice type like "YOU_JOINED", "YOU_LEFT", "YOU_CHANGED"
Module.OnChatEvent = function(_, _, _, message)
	-- Filter all channel join/leave/change notices
	if message == "YOU_JOINED" or message == "YOU_LEFT" or message == "YOU_CHANGED" then
		return true
	end
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

Module.OnEnable = function(self)
	-- Unconditional: channel notices carry an ignored (channel) chatID, so the
	-- gated blacklist would never see them.
	self:RegisterUnconditionalBlacklistFilter(onAddMessageProxy)
	-- CHAT_MSG_CHANNEL_NOTICE fires with notice type as first arg
	self:RegisterMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", onChatEventProxy)
end

Module.OnDisable = function(self)
	self:UnregisterUnconditionalBlacklistFilter(onAddMessageProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", onChatEventProxy)
end
