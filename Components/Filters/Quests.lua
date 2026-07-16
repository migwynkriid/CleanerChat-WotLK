local _, ns = ...

local Module = ns:NewModule("Quests")

-- GLOBALS: hooksecurefunc, AcceptQuest, GetQuestReward, GetTitleText

-- Lua API
local string_format = string.format
local string_match = string.match
local GetTime = GetTime

-- WoW Globals (keep as nil if missing - empty string patterns match everything!)
local G = {
	SET_COMPLETE = ERR_COMPLETED_TRANSMOG_SET_S, -- "You've completed the set %s." (retail only)
	QUEST_ACCEPTED = ERR_QUEST_ACCEPTED_S, -- "Quest accepted: %s"
	QUEST_ALREADY_DONE = ERR_QUEST_ALREADY_DONE, -- "You have completed that quest."
	QUEST_ALREADY_DONE_DAILY = ERR_QUEST_ALREADY_DONE_DAILY, -- "You have completed that daily quest today."
	QUEST_FAILED_TOO_MANY_DAILY = ERR_QUEST_FAILED_TOO_MANY_DAILY_QUESTS_I, -- "You have already completed %d daily quests today"
	NO_DAILY_QUESTS_REMAINING = NO_DAILY_QUESTS_REMAINING, -- "You cannot complete any more daily quests today."
	QUEST_COMPLETE = ERR_QUEST_COMPLETE_S, -- "%s completed."
	QUEST = BATTLE_PET_SOURCE_2 or QUEST_LOG or "Quest", -- "Quest"
	ACCEPTED = CALENDAR_STATUS_ACCEPTED or "Accepted", -- "Accepted"
	COMPLETE = COMPLETE or "Complete", -- "Complete"
}

-- Convert a WoW global string to a search pattern
local makePattern = ns.MakePattern

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

-- Safe pattern match that tolerates a nil pattern (shared helper).
local safeMatch = ns.SafeMatch

-- A real quest completion is ALWAYS the entire system line ("<name> completed."),
-- so we anchor the pattern to the whole message with ^...$. Without anchoring,
-- the greedy "(.+) completed." swallows any line that merely contains the word
-- "completed" -- e.g. Ascension's custom "<icons> <player> has completed ..."
-- Adventure Mode / Prestige broadcasts -- and reformats them into a bogus
-- "+ Complete: ..." line with the words out of order.
local QUEST_COMPLETE_ANCHORED = G.QUEST_COMPLETE and ("^" .. makePattern(G.QUEST_COMPLETE) .. "$")

-- If a real (server-sent) or a synthetic quest line was shown within this many
-- seconds, treat another as a duplicate (see synthetic accept/complete below).
local QUEST_DEDUP_WINDOW = 1.0
-- Print the synthetic line on the next frame (effectively instant). We no longer
-- wait for a real system message first; instead, on cores that DO send one, the
-- OnChatEvent filter suppresses it if it lands within QUEST_DEDUP_WINDOW after
-- our synthetic line -- so there's still never a duplicate.
local SYNTHETIC_QUEST_DELAY = 0

-- Timestamps of the last accept/complete line shown (real or synthetic).
Module.lastAcceptAt = 0
Module.lastCompleteAt = 0

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	if ns:IsProtectedMessage(message) then
		return
	end

	local name

	-- Adding completed transmog sets here,
	-- to make sure they don't fire as completed quests.
	name = safeMatch(message, P[G.SET_COMPLETE])
	if name then
		name = ns.StripBrackets(name)
		return false, string_format(ns.out.set_complete, G.COMPLETE, name), author, ...
	end

	name = safeMatch(message, P[G.QUEST_ACCEPTED])
	if name then
		-- A synthetic "Accepted" line was just shown for this quest -> drop the dup.
		if (GetTime() - self.lastAcceptAt) < QUEST_DEDUP_WINDOW then
			return true
		end
		self.lastAcceptAt = GetTime()
		name = ns.StripBrackets(name)
		return false, string_format(ns.out.quest_accepted, G.ACCEPTED, name), author, ...
	end

	-- Avoid false positives on quest completion.
	if
		not safeMatch(message, P[G.QUEST_ALREADY_DONE])
		and not safeMatch(message, P[G.QUEST_ALREADY_DONE_DAILY])
		and not safeMatch(message, P[G.QUEST_FAILED_TOO_MANY_DAILY])
		and not safeMatch(message, P[G.NO_DAILY_QUESTS_REMAINING])
	then
		name = QUEST_COMPLETE_ANCHORED and string_match(message, QUEST_COMPLETE_ANCHORED)
		if name then
			-- A synthetic "Complete" line was just shown for this quest -> drop the dup.
			if (GetTime() - self.lastCompleteAt) < QUEST_DEDUP_WINDOW then
				return true
			end
			self.lastCompleteAt = GetTime()
			name = ns.StripBrackets(name)
			return false, string_format(ns.out.quest_complete, G.COMPLETE, name), author, ...
		end
	end
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

-- Some 3.3.5 cores (notably Ascension-based servers) don't broadcast the
-- ERR_QUEST_ACCEPTED_S ("Quest accepted: <name>") or ERR_QUEST_COMPLETE_S
-- ("<name> completed.") system messages, so the filter above never sees a line
-- to reformat. Synthesize the line ourselves from the actual accept/turn-in,
-- deduping against a real system message via the timestamps above.
local schedule = function(delay, fn)
	if ns.Timer and ns.Timer.After then
		ns.Timer.After(delay, fn)
	elseif C_Timer and C_Timer.After then
		C_Timer.After(delay, fn)
	else
		fn()
	end
end

local printSynthetic = function(stampKey, template, label, title)
	-- A real server-sent line already showed within the window -> skip duplicate.
	if (GetTime() - (Module[stampKey] or 0)) < QUEST_DEDUP_WINDOW then
		return
	end
	Module[stampKey] = GetTime()
	ns.PrintToFrame(DEFAULT_CHAT_FRAME or ChatFrame1, string_format(template, label, title))
end

local onQuestAction = function(stampKey, template, label)
	if not Module:IsEnabled() then
		return
	end
	-- The quest frame is still shown while AcceptQuest/GetQuestReward run, so the
	-- title is valid here; capture it before the frame closes on a later frame.
	local title = GetTitleText and GetTitleText()
	title = title and ns.StripBrackets(title)
	if (not title) or (title == "") then
		return
	end
	schedule(SYNTHETIC_QUEST_DELAY, function()
		printSynthetic(stampKey, template, label, title)
	end)
end

Module.OnEnable = function(self)
	self:RegisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_CHANNEL", onChatEventProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_WHISPER", onChatEventProxy)

	-- Synthesize accept/complete lines on cores that don't broadcast them.
	-- hooksecurefunc is a post-hook (no taint) and cannot be removed, so install
	-- once and gate the body on Module:IsEnabled().
	if not self.questHooksInstalled then
		self.questHooksInstalled = true
		if type(AcceptQuest) == "function" then
			hooksecurefunc("AcceptQuest", function()
				onQuestAction("lastAcceptAt", ns.out.quest_accepted, G.ACCEPTED)
			end)
		end
		if type(GetQuestReward) == "function" then
			hooksecurefunc("GetQuestReward", function()
				onQuestAction("lastCompleteAt", ns.out.quest_complete, G.COMPLETE)
			end)
		end
	end
end

Module.OnDisable = function(self)
	self:UnregisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_CHANNEL", onChatEventProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_WHISPER", onChatEventProxy)
end
