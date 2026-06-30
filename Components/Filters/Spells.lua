local _, ns = ...

local Module = ns:NewModule("Spells")

-- WoW Globals (with 3.3.5 fallbacks)
local G = {
	LEARN_ABILITY = ERR_LEARN_ABILITY_S or "You have learned a new ability: %s.",
	LEARN_PASSIVE = ERR_LEARN_PASSIVE_S or "You have learned a new passive effect: %s.",
	LEARN_SPELL = ERR_LEARN_SPELL_S or "You have learned a new spell: %s.",
	SPELL_UNLEARNED = ERR_SPELL_UNLEARNED_S or "You have unlearned %s.",
}

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

-- Safe pattern match that tolerates a nil pattern (shared helper).
local safeMatch = ns.SafeMatch

Module.OnAddMessage = function(self, chatFrame, msg, r, g, b, chatID, ...)
	local ability = safeMatch(msg, P[G.LEARN_ABILITY])
	if ability then
		return true
	end

	local passive = safeMatch(msg, P[G.LEARN_PASSIVE])
	if passive then
		return true
	end

	local spell = safeMatch(msg, P[G.LEARN_SPELL])
	if spell then
		return true
	end

	local unlearned = safeMatch(msg, P[G.SPELL_UNLEARNED])
	if unlearned then
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
