local _, ns = ...

local Module = ns:NewModule("Reputation")

-- GLOBALS: GetNumFactions, GetFactionInfo, CollapseFactionHeader, ExpandFactionHeader

-- Lua API
local next = next
local string_format = string.format
local string_match = string.match
local table_concat = table.concat
local table_insert = table.insert
local tonumber = tonumber

-- WoW Globals
local G = {
	INCREASED = FACTION_STANDING_INCREASED, -- "Your %s reputation has increased by %d."
	DECREASED = FACTION_STANDING_DECREASED, -- "Your %s reputation has decreased by %d."
	INCREASED_GENERIC = FACTION_STANDING_INCREASED_GENERIC, -- "Reputation with %s increased."
	DECREASED_GENERIC = FACTION_STANDING_DECREASED_GENERIC, -- "Reputation with %s decreased."
	REPUTATION = REPUTATION,
}

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

local fix = function(...)
	local string, number, n
	for i, v in next, { ... } do
		n = tonumber(v)
		if n and (n > 0) then
			number = n
		elseif not n then
			string = v
		end
	end
	return string, number
end

-- Reputation grouping.
-- Quest turn-ins and other bursts fire one CHAT_MSG_COMBAT_FACTION_CHANGE per
-- faction, all within the same frame. Instead of printing a separate
-- "+N Reputation: Faction" line for each, we collect every gain that shares the
-- same amount and emit a single "+N Reputation: A, B, C" line per amount. Gains
-- are buffered per chat frame and flushed on the next frame (ns.CreateFrameBuffer).
local repBuffer = ns.CreateFrameBuffer(function()
	return { order = {}, byValue = {} } -- order = {value,...}, byValue = {[value]={faction,...}}
end, function(chatFrame, buf)
	for i = 1, #buf.order do
		local value = buf.order[i]
		local factions = buf.byValue[value]
		if factions then
			local text = string_format(ns.out.standing, value, G.REPUTATION, table_concat(factions, ", "))
			-- Match the colour these messages normally display with.
			ns.PrintToFrame(chatFrame, text, "COMBAT_FACTION_CHANGE")
		end
	end
end)

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	local faction, value

	faction, value = fix(string_match(message, P[G.INCREASED]))
	if faction then
		if value then
			-- Group same-amount gains from this burst (e.g. a quest turn-in) into
			-- a single "+N Reputation: A, B, C" line. Buffer per frame and flush on
			-- the next frame; suppress the individual line here.
			if C_Timer and C_Timer.After and chatFrame and chatFrame.AddMessage then
				local buf = repBuffer.Get(chatFrame)
				if not buf.byValue[value] then
					buf.byValue[value] = {}
					buf.order[#buf.order + 1] = value
				end
				table_insert(buf.byValue[value], faction)
				repBuffer.Schedule(chatFrame)
				return true
			end
			return false, string_format(ns.out.standing, value, G.REPUTATION, faction), author, ...
		else
			return false, string_format(ns.out.standing_generic, G.REPUTATION, faction), author, ...
		end
	end

	faction, value = fix(string_match(message, P[G.DECREASED]))
	if faction then
		if value then
			return false, string_format(ns.out.standing_deficit, value, G.REPUTATION, faction), author, ...
		else
			return false, string_format(ns.out.standing_deficit_generic, G.REPUTATION, faction), author, ...
		end
	end

	faction = fix(string_match(message, P[G.INCREASED_GENERIC]))
	if faction then
		return false, string_format(ns.out.standing_generic, G.REPUTATION, faction), author, ...
	end

	faction = fix(string_match(message, P[G.DECREASED_GENERIC]))
	if faction then
		return false, string_format(ns.out.standing_deficit_generic, G.REPUTATION, faction), author, ...
	end
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

Module.OnEnable = function(self)
	self:RegisterMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", onChatEventProxy)
end

Module.OnDisable = function(self)
	self:UnregisterMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", onChatEventProxy)
end
