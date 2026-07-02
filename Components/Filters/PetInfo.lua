local _, ns = ...

local Module = ns:NewModule("PetInfo")

-- Lua API
local string_find = string.find

-- WoW Globals - Pet related messages
local G = {
	-- Pet ability messages (patterns)
	PET_LEARN_ABILITY = "Your pet has learned %s.",
	PET_UNLEARN_ABILITY = "Your pet has unlearned %s.",
	-- "Your pet is now happy."
	PET_HAPPY = "happy",
	-- "Your pet is now content."
	PET_CONTENT = "content",
	-- "Your pet is now unhappy."
	PET_UNHAPPY = "unhappy",
}

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

-- Safe pattern match that tolerates a nil pattern (shared helper).
local safeMatch = ns.SafeMatch

-- Filter out pet spam messages (happiness changes, etc.)
Module.OnAddMessage = function(_, _, msg, ...)
	if not msg then return end
	
	-- Filter pet happiness messages
	if string_find(msg, "pet") or string_find(msg, "Pet") then
		if string_find(msg, G.PET_HAPPY) or string_find(msg, G.PET_CONTENT) or string_find(msg, G.PET_UNHAPPY) then
			return true -- Suppress the message
		end
	end
	
	-- Filter pet ability learn/unlearn messages
	local ability = safeMatch(msg, P[G.PET_LEARN_ABILITY])
	if ability then
		return true
	end
	
	ability = safeMatch(msg, P[G.PET_UNLEARN_ABILITY])
	if ability then
		return true
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
