local _, ns = ...

local Module = ns:NewModule("MiscInfo")

-- Lua API
local string_find = string.find
local tonumber = tonumber

-- WoW Globals - Miscellaneous combat/info messages
local G = {
	-- Combo point messages (pattern fallback)
	COMBO_POINTS = "combo point",
	-- Energy/rage/mana messages
	POWER_GAIN = "You gain %d %s.",
}

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

-- Safe pattern match that tolerates a nil pattern (shared helper).
local safeMatch = ns.SafeMatch

-- Filter out misc combat info spam
Module.OnAddMessage = function(_, _, msg, ...)
	if not msg then return end
	
	-- Filter combo point messages
	if string_find(msg, G.COMBO_POINTS) then
		return true
	end
	
	-- Filter "You gain X energy/rage/mana" type spam messages
	-- These are typically redundant with the UI indicators
	local amount, power = safeMatch(msg, P[G.POWER_GAIN])
	if amount and power then
		-- Only filter small/spam gains, not significant ones
		local n = tonumber(amount)
		if n and n <= 30 then
			return true
		end
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
