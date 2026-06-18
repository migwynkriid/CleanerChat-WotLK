--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local Addon, ns = ...

local Module = ns:NewModule("Experience")

-- Addon Localization
local L = LibStub("AceLocale-3.0"):GetLocale((...))

-- Lua API
local next = next
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local tonumber = tonumber

-- WoW Globals
local G = {
	ERR_ZONE_EXPLORED_XP = ERR_ZONE_EXPLORED_XP, -- "Discovered %s: %d experience gained"
	ERR_QUEST_REWARD_EXP_I = ERR_QUEST_REWARD_EXP_I, -- "Experience gained: %d."
	XP = XP,

	-- All of these contain the first pattern,
	-- and the first pattern contains all we wish to show.
	NAMED = COMBATLOG_XPGAIN_FIRSTPERSON, -- "%s dies, you gain %d experience."
	-- COMBATLOG_XPGAIN_FIRSTPERSON_GROUP					-- "%s dies, you gain %d experience. (+%d group bonus)"
	-- COMBATLOG_XPGAIN_FIRSTPERSON_RAID 					-- "%s dies, you gain %d experience. (-%d raid penalty)"
	-- COMBATLOG_XPGAIN_EXHAUSTION1 						-- "%s dies, you gain %d experience. (%s exp %s bonus)"
	-- COMBATLOG_XPGAIN_EXHAUSTION1_GROUP 					-- "%s dies, you gain %d experience. (%s exp %s bonus, +%d group bonus)"
	-- COMBATLOG_XPGAIN_EXHAUSTION1_RAID 					-- "%s dies, you gain %d experience. (%s exp %s bonus, -%d raid penalty)"
	-- COMBATLOG_XPGAIN_EXHAUSTION2 						-- "%s dies, you gain %d experience. (%s exp %s bonus)"
	-- COMBATLOG_XPGAIN_EXHAUSTION2_GROUP 					-- "%s dies, you gain %d experience. (%s exp %s bonus, +%d group bonus)"
	-- COMBATLOG_XPGAIN_EXHAUSTION2_RAID 					-- "%s dies, you gain %d experience. (%s exp %s bonus, -%d raid penalty)"
	-- COMBATLOG_XPGAIN_EXHAUSTION4 						-- "%s dies, you gain %d experience. (%s exp %s penalty)"
	-- COMBATLOG_XPGAIN_EXHAUSTION4_GROUP 					-- "%s dies, you gain %d experience. (%s exp %s penalty, +%d group bonus)"
	-- COMBATLOG_XPGAIN_EXHAUSTION4_RAID 					-- "%s dies, you gain %d experience. (%s exp %s penalty, -%d raid penalty)"
	-- COMBATLOG_XPGAIN_EXHAUSTION5 						-- "%s dies, you gain %d experience. (%s exp %s penalty)"
	-- COMBATLOG_XPGAIN_EXHAUSTION5_GROUP 					-- "%s dies, you gain %d experience. (%s exp %s penalty, +%d group bonus)"
	-- COMBATLOG_XPGAIN_EXHAUSTION5_RAID 					-- "%s dies, you gain %d experience. (%s exp %s penalty, -%d raid penalty)"

	-- Same applies here as above. A single pattern is enough.
	UNNAMED = COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED, -- "You gain %d experience."
	-- COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_GROUP 			-- "You gain %d experience. (+%d group bonus)"
	-- COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_RAID 			-- "You gain %d experience. (-%d raid penalty)"
	-- COMBATLOG_XPGAIN_QUEST 								-- "You gain %d experience. (%s exp %s bonus)"

	-- "Congratulations, you have reached |cffFF4E00|Hlevelup:%d:LEVEL_UP_TYPE_CHARACTER|h[Level %d]|h|r!"
	LEVEL_UP = LEVEL_UP,

	-- 3.3.5 level up messages (plain text format)
	LEVEL_UP_335 = "Congratulations, you have reached level %d!",
	GAINED_HP = "You have gained %d hit points.",
	GAINED_TALENT = "You have gained %d talent point.",
	GAINED_TALENTS = "You have gained %d talent points.",
	STAT_INCREASE = "Your %s increases by %d.",
	UNSPENT_TALENT_ESSENCE = "You have unspent Talent Essence!"
}


-- Convert a WoW global string to a search pattern
local makePattern = function(msg)
	if (not msg) or (msg == "") then return nil end
	msg = string_gsub(msg, "%%([%d%$]-)d", "(%%d+)")
	msg = string_gsub(msg, "%%([%d%$]-)s", "(.+)")
	return msg
end

-- Search Pattern Cache.
-- This will generate the pattern on the first lookup.
local P = setmetatable({}, { __index = function(t,k)
	if (k == nil) or (k == "") then return nil end
	rawset(t,k,makePattern(k))
	return rawget(t,k)
end })

-- Safe pattern match that handles nil patterns
local safeMatch = function(msg, pattern)
	if (not pattern) then return nil end
	return string_match(msg, pattern)
end

-- Special handling for LEVEL_UP. We capture the entire colored, clickable level link.
if (G.LEVEL_UP) then
	P[G.LEVEL_UP] = string_gsub(G.LEVEL_UP, "(|.+|r)", "(.+)")
end

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
	return number,string
end

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	local value,source

	if (event == "CHAT_MSG_COMBAT_XP_GAIN") then

		value,source = fix(string_match(message, P[G.NAMED]))
		if (value) then
			return false, string_format(ns.out.xp_named, value, G.XP, source), author, ...
		end

		value = string_match(message, P[G.UNNAMED])
		if (value) then
			return false, string_format(ns.out.xp_unnamed, value, G.XP), author, ...
		end

	elseif (event == "CHAT_MSG_SYSTEM") then

		-- Area discovery
		value,source = fix(safeMatch(message, P[G.ERR_ZONE_EXPLORED_XP]))
		if (value) then
			return false, string_format(ns.out.xp_named, value, G.XP, source), author, ...
		end

		-- Level up (retail format with clickable link)
		value = safeMatch(message, P[G.LEVEL_UP])
		if (value) then
			value = string_gsub(value, "[%[/%]]", "")
			return false, string_format(ns.out.xp_levelup, value), author, ...
		end

		-- Level up (3.3.5 plain text format)
		value = safeMatch(message, P[G.LEVEL_UP_335])
		if (value) then
			return false, string_format(ns.out.levelup_ding, tonumber(value)), author, ...
		end

		-- Hit points gained on level up
		value = safeMatch(message, P[G.GAINED_HP])
		if (value) then
			return false, string_format(ns.out.levelup_hp, tonumber(value)), author, ...
		end

		-- Talent point(s) gained on level up
		value = safeMatch(message, P[G.GAINED_TALENTS])
		if (value) then
			return false, string_format(ns.out.levelup_talents, tonumber(value)), author, ...
		end

		value = safeMatch(message, P[G.GAINED_TALENT])
		if (value) then
			return false, string_format(ns.out.levelup_talent, tonumber(value)), author, ...
		end

		-- Stat increases on level up
		local stat, amount = safeMatch(message, P[G.STAT_INCREASE])
		if (stat and amount) then
			return false, string_format(ns.out.levelup_stat, tonumber(amount), stat), author, ...
		end

		-- Unspent Talent Essence (Ascension-specific)
		if (message == G.UNSPENT_TALENT_ESSENCE) then
			return false, ns.out.levelup_essence, author, ...
		end

		-- Quest Completed (also reported in the XP channel)
		if (safeMatch(message, P[G.ERR_QUEST_REWARD_EXP_I])) then
			return true
		end
	end
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

Module.OnEnable = function(self)
	self:RegisterMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", onChatEventProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
end

Module.OnDisable = function(self)
	self:UnregisterMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", onChatEventProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
end
