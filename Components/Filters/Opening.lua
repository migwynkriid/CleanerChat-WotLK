local _, ns = ...

local Module = ns:NewModule("Opening")

-- Lua API
local string_match = string.match

-- WoW Globals - Opening messages for lockpicking, chests, etc.
-- In 3.3.5 these appear in CHAT_MSG_OPENING or via AddMessage
local G = {
	-- "Opening..."
	OPENING = "Opening",
	-- "Unlocking..."  
	UNLOCKING = "Unlocking",
}

-- Filter out opening/unlocking spam messages
Module.OnAddMessage = function(_, _, msg, ...)
	if not msg then return end
	
	if string_match(msg, "^" .. G.OPENING) or string_match(msg, "^" .. G.UNLOCKING) then
		return true -- Suppress the message
	end
end

local onAddMessageProxy = function(...)
	return Module:OnAddMessage(...)
end

Module.OnEnable = function(self)
	self:RegisterBlacklistFilter(onAddMessageProxy)
end

Module.OnDisable = function(self)
	self:UnregisterBlacklistFilter(onAddMessageProxy)
end
