local _, ns = ...

local Module = ns:NewModule("Experience")

-- Lua API
local next = next
local string_find = string.find
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
}

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

-- Safe pattern match that tolerates a nil pattern (shared helper).
local safeMatch = ns.SafeMatch

-- Special handling for LEVEL_UP. We capture the entire colored, clickable level link.
if G.LEVEL_UP then
	P[G.LEVEL_UP] = string_gsub(G.LEVEL_UP, "(|.+|r)", "(.+)")
end

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
	return number, string
end

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	local value, source

	if event == "CHAT_MSG_COMBAT_XP_GAIN" then
		value, source = fix(string_match(message, P[G.NAMED]))
		if value then
			return false, string_format(ns.out.xp_named, value, G.XP, source), author, ...
		end

		value = string_match(message, P[G.UNNAMED])
		if value then
			-- Check if we should buffer for one-line quest rewards
			-- Only buffer unnamed XP (quest rewards), not named XP (mob kills)
			if ns.db and ns.db.oneLineQuestRewards and chatFrame then
				local rewardText = string_format("|cffffffff%s|r |cffffffff%s|r", value, G.XP)
				if ns:AddQuestReward(chatFrame, "xp", rewardText) then
					return true -- Suppress, will be output with combined rewards
				end
			end
			return false, string_format(ns.out.xp_unnamed, value, G.XP), author, ...
		end
	elseif event == "CHAT_MSG_SYSTEM" then
		-- Area discovery
		value, source = fix(safeMatch(message, P[G.ERR_ZONE_EXPLORED_XP]))
		if value then
			return false, string_format(ns.out.xp_named, value, G.XP, source), author, ...
		end

		-- Level up (retail format with clickable link)
		if G.LEVEL_UP then
			value = safeMatch(message, P[G.LEVEL_UP])
			if value then
				value = ns.StripBrackets(value)
				return false, string_format(ns.out.xp_levelup, value), author, ...
			end
		end

		-- Level up (3.3.5 plain text format) - use string.find for robustness
		if string_find(message, "Congratulations, you have reached level") then
			local level = string_match(message, "level (%d+)")
			if level then
				return false, string_format(ns.out.levelup_ding, tonumber(level)), author, ...
			end
		end

		-- Hit points gained on level up
		if string_find(message, "You have gained") and string_find(message, "hit points") then
			local hp = string_match(message, "gained (%d+)")
			if hp then
				return false, string_format(ns.out.levelup_hp, tonumber(hp)), author, ...
			end
		end

		-- Talent point(s) gained on level up - hidden entirely so only the
		-- Ascension "Unspent Talent Essence" line is shown below.
		if string_find(message, "You have gained") and string_find(message, "talent point") then
			return true
		end

		-- Stat increases on level up: "Your Strength increases by 1."
		if string_find(message, "increases by") then
			local stat, amount = string_match(message, "Your (%a+) increases by (%d+)")
			if stat and amount then
				return false, string_format(ns.out.levelup_stat, tonumber(amount), stat), author, ...
			end
		end

		-- Unspent Talent Essence (Ascension-specific)
		if string_find(message, "Unspent Talent Essence") then
			return false, ns.out.levelup_essence, author, ...
		end

		-- Quest Completed (also reported in the XP channel)
		if safeMatch(message, P[G.ERR_QUEST_REWARD_EXP_I]) then
			return true
		end
	end
end

-- Replacement-layer handler for level up lines.
-- On some servers these are printed directly to the chat frame instead of
-- firing CHAT_MSG_SYSTEM, so the event filter above never sees them. Handling
-- them here (at the AddMessage layer) catches them no matter how they arrive.
local levelupReplacement = function(msg)
	if not msg then
		return
	end

	-- "Congratulations, you have reached level 21!"
	if string_find(msg, "Congratulations, you have reached level") then
		local level = string_match(msg, "level (%d+)")
		if level then
			return string_format(ns.out.levelup_ding, tonumber(level))
		end
	end

	-- "You have gained 15 hit points."
	if string_find(msg, "gained") and string_find(msg, "hit points") then
		local hp = string_match(msg, "gained (%d+)")
		if hp then
			return string_format(ns.out.levelup_hp, tonumber(hp))
		end
	end

	-- "Your Strength increases by 1."
	if string_find(msg, "increases by") then
		local stat, amount = string_match(msg, "Your (%a+) increases by (%d+)")
		if stat and amount then
			return string_format(ns.out.levelup_stat, tonumber(amount), stat)
		end
	end

	-- "You have unspent Talent Essence!" (case varies, Ascension-specific)
	if string_find(msg, "nspent Talent Essence") then
		return ns.out.levelup_essence
	end

	return msg
end

-- Blacklist: drop the "You have gained X talent point(s)." line entirely.
-- On Ascension, talent progression is shown by the "Unspent Talent Essence"
-- line instead, so the redundant talent-point message is hidden here. This runs
-- at the AddMessage layer, catching it no matter how the server prints it.
Module.OnAddMessage = function(self, chatFrame, msg, r, g, b, chatID, ...)
	if msg and string_find(msg, "You have gained") and string_find(msg, "talent point") then
		return true
	end
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

local onAddMessageProxy = function(...)
	return Module:OnAddMessage(...)
end

Module.OnEnable = function(self)
	self:RegisterBlacklistFilter(onAddMessageProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", onChatEventProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
	self:RegisterMessageReplacement(levelupReplacement, true)
end

Module.OnDisable = function(self)
	self:UnregisterBlacklistFilter(onAddMessageProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", onChatEventProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
	self:UnregisterMessageReplacement(levelupReplacement)
end
