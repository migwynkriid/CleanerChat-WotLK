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

local Module = ns:NewModule("Spells")

-- Lua API
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local string_match = string.match

-- WoW Globals (with 3.3.5 fallbacks)
local G = {
	LEARN_ABILITY = ERR_LEARN_ABILITY_S or "You have learned a new ability: %s.",
	LEARN_PASSIVE = ERR_LEARN_PASSIVE_S or "You have learned a new passive effect: %s.",
	LEARN_SPELL = ERR_LEARN_SPELL_S or "You have learned a new spell: %s.",
	SPELL_UNLEARNED = ERR_SPELL_UNLEARNED_S or "You have unlearned %s."
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

Module.OnAddMessage = function(self, chatFrame, msg, r, g, b, chatID, ...)

	local ability = safeMatch(msg,P[G.LEARN_ABILITY])
	if (ability) then
		return true
	end

	local passive = safeMatch(msg,P[G.LEARN_PASSIVE])
	if (passive) then
		return true
	end

	local spell = safeMatch(msg,P[G.LEARN_SPELL])
	if (spell) then
		return true
	end

	local unlearned = safeMatch(msg,P[G.SPELL_UNLEARNED])
	if (unlearned) then
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
