local _, ns = ...

local Module = ns:NewModule("Empty")

-- Lua API
local ipairs = ipairs
local string_match = string.match

-- Suppress chat lines that contain no actual text (empty or whitespace only).
-- Some servers and cross-faction relay addons emit these "ghost" messages
-- even though players can't normally send an empty message.
Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	if (not message) or (not string_match(message, "%S")) then
		return true
	end
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

local events = {
	"CHAT_MSG_CHANNEL",
	"CHAT_MSG_SAY",
	"CHAT_MSG_YELL",
	"CHAT_MSG_GUILD",
	"CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_WHISPER",
	"CHAT_MSG_WHISPER_INFORM",
}

Module.OnEnable = function(self)
	for _, event in ipairs(events) do
		self:RegisterMessageEventFilter(event, onChatEventProxy)
	end
end

Module.OnDisable = function(self)
	for _, event in ipairs(events) do
		self:UnregisterMessageEventFilter(event, onChatEventProxy)
	end
end
