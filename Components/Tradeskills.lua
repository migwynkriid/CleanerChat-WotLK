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

local Module = ns:NewModule("Tradeskills")

-- Addon Localization
local L = LibStub("AceLocale-3.0"):GetLocale((...))

-- Lua API
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local string_format = string.format
local string_match = string.match
local table_insert = table.insert
local tonumber = tonumber

-- WoW Globals (some may be nil in older clients like 3.3.5)
local G = {
	SKILL_RANK_UP = SKILL_RANK_UP, -- "Your skill in %s has increased to %d."
	LEARN_RECIPE = ERR_LEARN_RECIPE_S, -- "You have learned how to create a new item: %s."
	LEARNED = TRADE_SKILLS_LEARNED_TAB or "Learned", -- "Learned"
	UNLEARNED = TRADE_SKILLS_UNLEARNED_TAB or "Unlearned" -- "Unlearned"
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

-- Anchored patterns for "<player> creates <item>." craft broadcasts.
-- On Ascension these are printed DIRECTLY to the chat frame (no CHAT_MSG_*
-- event fires), so they are matched at the AddMessage-replacement layer in
-- OnReplacementSet below. The name is %S+ (character names have no spaces),
-- the colon is optional ("creates" or "creates:"), and the whole line is
-- anchored to limit false positives on normal chat.
local CREATE_MULTIPLE_PATTERN = "^(%S+) creates:? (.+)x(%d+)%.$"
local CREATE_SINGLE_PATTERN = "^(%S+) creates:? (.+)%.$"

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)

	local skill, gain = safeMatch(message, P[G.SKILL_RANK_UP])
	if (skill and gain) then
		gain = tonumber(gain)
		if (gain) then
			return false, string_format(ns.out.item_multiple, skill, gain), author, ...
		end
	end

	local craft = safeMatch(message, P[G.LEARN_RECIPE])
	if (craft) then
		return false, string_format(ns.out.objective_status, G.LEARNED, craft), author, ...
	end

end

Module.OnReplacementSet = function(self, msg, r, g, b, chatID, ...)
	-- Loot spec changed, or just reported
	-- This one will fire at the initial PLAYER_ENTERING_WORLD,
	-- as the chat frames haven't yet been registered for user events at that point.
	local craft = string_match(msg, P[G.LEARN_RECIPE])
	if (craft) then
		return string_format(ns.out.objective_status, G.LEARNED, craft)
	end

	-- "<player> creates <item>." craft broadcasts (direct-printed, no event).
	-- Reformat them like other players' loot: "<player>: <item>".
	local who, item, count = string_match(msg, CREATE_MULTIPLE_PATTERN)
	if (who and item and count) then
		return string_format(ns.out.item_multiple_other, who, item, tonumber(count))
	end

	who, item = string_match(msg, CREATE_SINGLE_PATTERN)
	if (who and item) then
		return string_format(ns.out.item_single_other, who, item)
	end
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

local onReplacementSetProxy = function(...)
	return Module:OnReplacementSet(...)
end

Module.OnEnable = function(self)
	self:RegisterMessageReplacement(onReplacementSetProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_SKILL", onChatEventProxy)
end

Module.OnDisable = function(self)
	self:UnregisterMessageReplacement(onReplacementSetProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_SKILL", onChatEventProxy)
end
