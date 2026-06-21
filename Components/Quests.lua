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

local Module = ns:NewModule("Quests")

-- Addon Localization
local L = LibStub("AceLocale-3.0"):GetLocale((...))

-- Lua API
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match

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
	COMPLETE = COMPLETE or "Complete" -- "Complete"
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

-- Safe pattern match that handles nil patterns
local safeMatch = function(msg, pattern)
	if (not pattern) then return nil end
	return string_match(msg, pattern)
end

-- A real quest completion is ALWAYS the entire system line ("<name> completed."),
-- so we anchor the pattern to the whole message with ^...$. Without anchoring,
-- the greedy "(.+) completed." swallows any line that merely contains the word
-- "completed" -- e.g. Ascension's custom "<icons> <player> has completed ..."
-- Adventure Mode / Prestige broadcasts -- and reformats them into a bogus
-- "+ Complete: ..." line with the words out of order.
local QUEST_COMPLETE_ANCHORED = G.QUEST_COMPLETE and ("^"..makePattern(G.QUEST_COMPLETE).."$")

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	if (ns:IsProtectedMessage(message)) then return end

	local name

	-- Adding completed transmog sets here,
	-- to make sure they don't fire as completed quests.
	name = safeMatch(message, P[G.SET_COMPLETE])
	if (name) then
		name = string_gsub(name, "[%[/%]]", "")
		return false, string_format(ns.out.set_complete, G.COMPLETE, name), author, ...
	end

	name = safeMatch(message, P[G.QUEST_ACCEPTED])
	if (name) then
		name = string_gsub(name, "[%[/%]]", "")
		return false, string_format(ns.out.quest_accepted, G.ACCEPTED, name), author, ...
	end


	-- Avoid false positives on quest completion.
	if (not safeMatch(message, P[G.QUEST_ALREADY_DONE]) and
		not safeMatch(message, P[G.QUEST_ALREADY_DONE_DAILY]) and
		not safeMatch(message, P[G.QUEST_FAILED_TOO_MANY_DAILY]) and
		not safeMatch(message, P[G.NO_DAILY_QUESTS_REMAINING])) then

		name = QUEST_COMPLETE_ANCHORED and string_match(message, QUEST_COMPLETE_ANCHORED)
		if (name) then
			name = string_gsub(name, "[%[/%]]", "")
			return false, string_format(ns.out.quest_complete, G.COMPLETE, name), author, ...
		end
	end

end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

Module.OnEnable = function(self)
	self:RegisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_CHANNEL", onChatEventProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_WHISPER", onChatEventProxy)
end

Module.OnDisable = function(self)
	self:UnregisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_CHANNEL", onChatEventProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_WHISPER", onChatEventProxy)
end
