local Addon, ns = ...

local Module = ns:NewModule("Reputation")

-- Addon Localization
local L = LibStub("AceLocale-3.0"):GetLocale((...))
-- GLOBALS: GetNumFactions, GetFactionInfo, CollapseFactionHeader, ExpandFactionHeader

-- Lua API
local ipairs = ipairs
local next = next
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local string_format = string.format
local string_match = string.match
local table_concat = table.concat
local table_insert = table.insert
local tonumber = tonumber
local type = type

-- WoW Globals
local G = {
	INCREASED = FACTION_STANDING_INCREASED, -- "Your %s reputation has increased by %d."
	DECREASED = FACTION_STANDING_DECREASED, -- "Your %s reputation has decreased by %d."
	INCREASED_GENERIC = FACTION_STANDING_INCREASED_GENERIC, -- "Reputation with %s increased."
	DECREASED_GENERIC = FACTION_STANDING_DECREASED_GENERIC, -- "Reputation with %s decreased."
	REPUTATION = REPUTATION
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

local fix = function(...)
	local string,number,n
	for i,v in next,{...} do
		n = tonumber(v)
		if (n) and (n > 0) then
			number = n
		elseif (not n) then
			string = v
		end
	end
	return string,number
end

-- Reputation grouping.
-- Quest turn-ins and other bursts fire one CHAT_MSG_COMBAT_FACTION_CHANGE per
-- faction, all within the same frame. Instead of printing a separate
-- "+N Reputation: Faction" line for each, we collect every gain that shares the
-- same amount and emit a single "+N Reputation: A, B, C" line per amount. Gains
-- are buffered per chat frame and flushed on the next frame via C_Timer.
local repPending = {} -- [chatFrame] = { order = {value,...}, byValue = {[value]={faction,...}}, scheduled = bool }

local function getRepBuffer(chatFrame)
	local buf = repPending[chatFrame]
	if (not buf) then
		buf = { order = {}, byValue = {}, scheduled = false }
		repPending[chatFrame] = buf
	end
	return buf
end

local function flushRepBuffer(chatFrame)
	local buf = repPending[chatFrame]
	if (not buf) then return end

	buf.scheduled = false

	-- Snapshot and reset first, so anything printed below starts a fresh batch.
	local order, byValue = buf.order, buf.byValue
	buf.order = {}
	buf.byValue = {}

	-- Match the colour these messages normally display with.
	local info = ChatTypeInfo and ChatTypeInfo["COMBAT_FACTION_CHANGE"]
	local r, g, b
	if (info) then r, g, b = info.r, info.g, info.b end

	for i = 1, #order do
		local value = order[i]
		local factions = byValue[value]
		if (factions) then
			local text = string_format(ns.out.standing, value, G.REPUTATION, table_concat(factions, ", "))
			if (r) then
				chatFrame:AddMessage(text, r, g, b)
			else
				chatFrame:AddMessage(text)
			end
		end
	end
end

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	local faction,value

	faction,value = fix(string_match(message,P[G.INCREASED]))
	if (faction) then
		if (value) then
			-- Group same-amount gains from this burst (e.g. a quest turn-in) into
			-- a single "+N Reputation: A, B, C" line. Buffer per frame and flush on
			-- the next frame; suppress the individual line here.
			if (C_Timer and C_Timer.After and chatFrame and chatFrame.AddMessage) then
				local buf = getRepBuffer(chatFrame)
				if (not buf.byValue[value]) then
					buf.byValue[value] = {}
					buf.order[#buf.order + 1] = value
				end
				table_insert(buf.byValue[value], faction)
				if (not buf.scheduled) then
					buf.scheduled = true
					C_Timer.After(0, function() flushRepBuffer(chatFrame) end)
				end
				return true
			end
			return false, string_format(ns.out.standing, value, G.REPUTATION, faction), author, ...
		else
			return false, string_format(ns.out.standing_generic, G.REPUTATION, faction), author, ...
		end
	end

	faction,value = fix(string_match(message,P[G.DECREASED]))
	if (faction) then
		if (value) then
			return false, string_format(ns.out.standing_deficit, value, G.REPUTATION, faction), author, ...
		else
			return false, string_format(ns.out.standing_deficit_generic, G.REPUTATION, faction), author, ...
		end
	end

	faction = fix(string_match(message,P[G.INCREASED_GENERIC]))
	if (faction) then
		return false, string_format(ns.out.standing_generic, G.REPUTATION, faction), author, ...
	end

	faction = fix(string_match(message,P[G.DECREASED_GENERIC]))
	if (faction) then
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
