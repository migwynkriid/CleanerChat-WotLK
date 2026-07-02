local _, ns = ...

local Module = ns:NewModule("Honor")

-- Lua API
local string_format = string.format
local tonumber = tonumber

-- WoW Globals
local G = {
	-- "You have been awarded %d honor points."
	HONOR_AWARD = COMBATLOG_HONORAWARD,
	-- "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"
	HONOR_GAIN = COMBATLOG_HONORGAIN,
	-- "%s dies, honorable kill (Estimated Honor Points: %d)"
	HONOR_GAIN_NO_RANK = COMBATLOG_HONORGAIN_NO_RANK,
	HONOR = HONOR_POINTS or "Honor",
}

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

-- Safe pattern match that tolerates a nil pattern (shared helper).
local safeMatch = ns.SafeMatch

Module.OnChatEvent = function(_, _, _, message, author, ...)
	-- Honor award (from BG wins, etc.)
	local amount = safeMatch(message, P[G.HONOR_AWARD])
	if amount then
		amount = tonumber(amount)
		if amount then
			return false, string_format(ns.out.honor, amount, G.HONOR), author, ...
		end
	end

	-- Honor gain from kills (with rank)
	local target, _, honor = safeMatch(message, P[G.HONOR_GAIN])
	if target then
		honor = tonumber(honor)
		if honor then
			return false, string_format(ns.out.honor_kill, honor, G.HONOR, target), author, ...
		end
	end

	-- Honor gain from kills (no rank)
	target, honor = safeMatch(message, P[G.HONOR_GAIN_NO_RANK])
	if target then
		honor = tonumber(honor)
		if honor then
			return false, string_format(ns.out.honor_kill, honor, G.HONOR, target), author, ...
		end
	end
end

Module.OnEnable = function(self)
	self:RegisterChatEvent("CHAT_MSG_COMBAT_HONOR_GAIN", "OnChatEvent")
end

Module.OnDisable = function(self)
	self:UnregisterChatEvent("CHAT_MSG_COMBAT_HONOR_GAIN", "OnChatEvent")
end
