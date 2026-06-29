local _, ns = ...

local Module = ns:NewModule("Status")

-- Lua API
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match

-- WoW Globals
local CLEARED_AFK = CLEARED_AFK -- "You are no longer AFK."
local CLEARED_DND = CLEARED_DND -- "You are no longer marked DND."
local DEFAULT_AFK_MESSAGE = DEFAULT_AFK_MESSAGE -- "Away from Keyboard"
local DEFAULT_DND_MESSAGE = DEFAULT_DND_MESSAGE -- "Do not Disturb"
local MARKED_AFK = MARKED_AFK -- "You are now AFK."
local MARKED_AFK_MESSAGE = MARKED_AFK_MESSAGE -- "You are now AFK: %s"
local MARKED_DND = MARKED_DND -- "You are now DND: %s."
local EXHAUSTION_NORMAL = ERR_EXHAUSTION_NORMAL -- "You feel normal."
local EXHAUSTION_WELLRESTED = ERR_EXHAUSTION_WELLRESTED -- "You feel well rested."

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)

	-- AFK
	if (message == MARKED_AFK) then
		return false, ns.out.afk_added, author, ...
	end
	if (message == CLEARED_AFK) then
		return false, ns.out.afk_cleared, author, ...
	end
	local afk_message = string_match(message, P[MARKED_AFK_MESSAGE])
	if (afk_message) then
		if (afk_message == DEFAULT_AFK_MESSAGE) then
			return false, ns.out.afk_added, author, ...
		end
		return false, string_format(ns.out.afk_added_message, afk_message), author, ...
	end

	-- DND
	if (message == CLEARED_DND) then
		return false, ns.out.dnd_cleared, author, ...
	end
	local dnd_message = string_match(message, P[MARKED_DND] )
	if (dnd_message) then
		if (dnd_message == DEFAULT_DND_MESSAGE) then
			return false, ns.out.dnd_added, author, ...
		end
		return false, string_format(ns.out.dnd_added_message, dnd_message), author, ...
	end

	-- Rested TODO: Move to XP!
	if (message == EXHAUSTION_WELLRESTED) then
		return false, ns.out.rested_added, author, ...
	end
	if (message == EXHAUSTION_NORMAL) then
		return false, ns.out.rested_cleared, author, ...
	end

	-- Arena Points (Ascension): "You've received 25 Arena Points. Current Points: (25) Cap: (25/110000)"
	if (string_find(message, "Arena Points")) then
		local amount = string_match(message, "received (%d+) Arena Points")
		local current, cap = string_match(message, "Cap: %((%d+)/(%d+)%)")
		if (amount and current and cap) then
			local line1 = string_format(ns.out.arena_points, tonumber(amount))
			local line2 = string_format(ns.out.arena_points_status, tonumber(current), tonumber(cap))
			return false, line1 .. "\n" .. line2, author, ...
		end
	end

	-- Guild online: "|Hplayer:Name|h[Name]|h has come online."
	-- Guild offline: "Name has gone offline." (plain text, no player link)
	if (ns.db == nil or ns.db.prettifyGuildStatus) then
		local onlineName = string_match(message, "|Hplayer:([^|]+)|h.-has come online")
		if (onlineName) then
			return false, string_format(ns.out.guild_online, onlineName), author, ...
		end

		local offlineName = string_match(message, "^(%S+) has gone offline")
		if (offlineName) then
			return false, string_format(ns.out.guild_offline, offlineName), author, ...
		end
	end

	-- Glory (Ascension): "|CFF1CB619 You gained 50 Glory for winning a battleground. 5502 Glory needed to reach the next rank|r."
	-- Strip color codes (both |c and |C formats) before parsing
	local cleanMessage = string_gsub(message, "|[cC]%x%x%x%x%x%x%x%x", "")
	cleanMessage = string_gsub(cleanMessage, "|r", "")
	if (string_find(cleanMessage, "Glory")) then
		local amount = string_match(cleanMessage, "gained (%d+) Glory")
		local needed = string_match(cleanMessage, "(%d+) Glory needed")
		if (amount) then
			local line1 = string_format(ns.out.glory, tonumber(amount))
			if (needed) then
				local line2 = string_format(ns.out.glory_progress, tonumber(needed))
				return false, line1 .. "\n" .. line2, author, ...
			end
			return false, line1, author, ...
		end
	end

end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

-- Suppress Ascension "Added as:" guild status messages that bypass CHAT_MSG_* events
-- Format: "|cff..Name|r |cff..Added as:|r (Name) has come/gone online/offline"
Module.OnAddMessage = function(self, chatFrame, msg, r, g, b, chatID, ...)
	if (ns.db and not ns.db.prettifyGuildStatus) then return end
	if (not msg) then return end
	if (string_find(msg, "Added as:")) then
		return true  -- suppress this message
	end
end

local onAddMessageProxy = function(...)
	return Module:OnAddMessage(...)
end

Module.OnEnable = function(self)
	self:RegisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
	self:RegisterBlacklistFilter(onAddMessageProxy)
end

Module.OnDisable = function(self)
	self:UnregisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
	self:UnregisterBlacklistFilter(onAddMessageProxy)
end
