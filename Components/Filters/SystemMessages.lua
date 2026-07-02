local _, ns = ...

local Module = ns:NewModule("SystemMessages")

-- Lua API
local string_find = string.find

-- WoW Globals - System message strings
local G = {
	-- Session started messages
	SESSION_START = "Session started",
	-- Addon loaded messages  
	ADDON_LOADED = "AddOn",
}

-- Filter system message spam
Module.OnAddMessage = function(_, _, msg, ...)
	if not msg then return end
	
	-- Filter "Session started" spam
	if string_find(msg, G.SESSION_START) then
		return true
	end
	
	-- Filter addon loaded notifications (if they appear)
	if string_find(msg, G.ADDON_LOADED) and string_find(msg, "loaded") then
		return true
	end
end

local onAddMessageProxy = function(...)
	return Module:OnAddMessage(...)
end

Module.OnChatEvent = function(_, _, _, message, ...)
	if not message then return end
	
	-- Filter repetitive system messages
	if string_find(message, "Session started") then
		return true -- Suppress message
	end
end

Module.OnEnable = function(self)
	self:RegisterBlacklistFilter(onAddMessageProxy)
	self:RegisterChatEvent("CHAT_MSG_SYSTEM", "OnChatEvent")
end

Module.OnDisable = function(self)
	self:UnregisterBlacklistFilter(onAddMessageProxy)
	self:UnregisterChatEvent("CHAT_MSG_SYSTEM", "OnChatEvent")
end
