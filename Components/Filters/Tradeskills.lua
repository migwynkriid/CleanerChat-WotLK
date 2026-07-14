local _, ns = ...

local Module = ns:NewModule("Tradeskills")

-- Lua API
local ipairs = ipairs
local string_format = string.format
local string_match = string.match
local tonumber = tonumber

-- WoW API
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitName = UnitName

-- WoW Globals (some may be nil in older clients like 3.3.5)
local G = {
	SKILL_RANK_UP = SKILL_RANK_UP, -- "Your skill in %s has increased to %d."
	LEARN_RECIPE = ERR_LEARN_RECIPE_S, -- "You have learned how to create a new item: %s."
	LEARNED = TRADE_SKILLS_LEARNED_TAB or "Learned", -- "Learned"
	UNLEARNED = TRADE_SKILLS_UNLEARNED_TAB or "Unlearned", -- "Unlearned"
}

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

-- Safe pattern match that tolerates a nil pattern (shared helper).
local safeMatch = ns.SafeMatch

-- Anchored patterns for "<name> creates <item>." craft broadcasts.
-- On Ascension these are printed DIRECTLY to the chat frame (no CHAT_MSG_*
-- event fires), so they are matched at the AddMessage-replacement layer in
-- OnReplacementSet below. The name can contain spaces (e.g. "Innkeeper Farley"),
-- the colon is optional ("creates" or "creates:"), and the whole line is
-- anchored to limit false positives on normal chat.
local CREATE_MULTIPLE_PATTERN = "^(.+) creates:? (.+)x(%d+)%.$"
local CREATE_SINGLE_PATTERN = "^(.+) creates:? (.+)%.$"

-- Best-effort class colour for a crafter's name. There is no API to look up an
-- arbitrary player's class in 3.3.5, but we can read it from any unit that
-- currently matches the name (the player, target, focus, mouseover, party or
-- raid) -- like inspecting /target without actually targeting them.
local function GetClassColoredName(name)
	if (not name) or (name == "") then
		return name
	end

	local colors = ns.Colors
	if (not colors) or not colors.class then
		return name
	end

	local units = { "player", "target", "targettarget", "focus", "focustarget", "mouseover" }
	for i = 1, 4 do
		units[#units + 1] = "party" .. i
	end
	for i = 1, 40 do
		units[#units + 1] = "raid" .. i
	end

	for _, unit in ipairs(units) do
		if UnitExists(unit) and UnitIsPlayer(unit) and UnitName(unit) == name then
			local _, class = UnitClass(unit)
			local color = class and colors.class[class]
			if color and color.colorCode then
				return color.colorCode .. name .. "|r"
			end
		end
	end

	return name
end

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	local skill, gain = safeMatch(message, P[G.SKILL_RANK_UP])
	if skill and gain then
		gain = tonumber(gain)
		if gain then
			return false, string_format(ns.out.item_multiple, skill, gain), author, ...
		end
	end

	local craft = safeMatch(message, P[G.LEARN_RECIPE])
	if craft then
		return false, string_format(ns.out.objective_status, G.LEARNED, craft), author, ...
	end
end

Module.OnReplacementSet = function(self, msg, r, g, b, chatID, ...)
	-- Loot spec changed, or just reported
	-- This one will fire at the initial PLAYER_ENTERING_WORLD,
	-- as the chat frames haven't yet been registered for user events at that point.
	local craft = string_match(msg, P[G.LEARN_RECIPE])
	if craft then
		return string_format(ns.out.objective_status, G.LEARNED, craft)
	end

	-- "<player> creates <item>." craft broadcasts (direct-printed, no event).
	-- Reformat them as: "<player>" created: <item>, class-colouring the name.
	local who, item, count = string_match(msg, CREATE_MULTIPLE_PATTERN)
	if who and item and count then
		return string_format(ns.out.craft_multiple_other, GetClassColoredName(who), item, tonumber(count))
	end

	who, item = string_match(msg, CREATE_SINGLE_PATTERN)
	if who and item then
		return string_format(ns.out.craft_single_other, GetClassColoredName(who), item)
	end
end

-- Blacklist filter: when the option is enabled, hide other players'
-- "<player> creates <item>" craft broadcasts entirely instead of letting
-- OnReplacementSet reformat them. Blacklists run BEFORE replacements, so a
-- dropped line is never reformatted.
Module.OnAddMessage = function(self, chatFrame, msg, r, g, b, chatID, ...)
	if (not ns.db) or not ns.db.hideOtherCrafts then
		return
	end
	if not msg then
		return
	end

	if (string_match(msg, CREATE_MULTIPLE_PATTERN)) or (string_match(msg, CREATE_SINGLE_PATTERN)) then
		return true
	end
end

local onAddMessageProxy = function(...)
	return Module:OnAddMessage(...)
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

local onReplacementSetProxy = function(...)
	return Module:OnReplacementSet(...)
end

Module.OnEnable = function(self)
	self:RegisterBlacklistFilter(onAddMessageProxy)
	self:RegisterMessageReplacement(onReplacementSetProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_SKILL", onChatEventProxy)
end

Module.OnDisable = function(self)
	self:UnregisterBlacklistFilter(onAddMessageProxy)
	self:UnregisterMessageReplacement(onReplacementSetProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_SKILL", onChatEventProxy)
end
