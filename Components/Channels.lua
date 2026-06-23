local _, ns = ...

local Module = ns:NewModule("Channels")

-- Addon Localization
local L = LibStub("AceLocale-3.0"):GetLocale((...))

-- Lua API
local string_match = string.match
local string_sub = string.sub
local string_upper = string.upper
local table_insert = table.insert

-- Rebuilds a channel link from its captured pieces according to the
-- user's preferences:
--   * channelNameMode  -> "initial" shows the first letter (e.g. "[G]"),
--                         "full" shows the whole name (e.g. "[General]").
--   * channelNumber    -> when true, prefixes the channel number, e.g. "1. ".
--   * channelCapitalize-> when true, capitalizes the first letter.
-- e.g. "|Hchannel:CHANNEL:1|h[1. General - The Barrens]|h" -> "1. [G]"
local formatChannelTag = function(channel, number, displaynum, name)
	-- Guard against nil captures - return nil to skip replacement
	if not channel or not number or not displaynum or not name then
		return nil
	end

	local db = ns.db
	local mode = (db and db.channelNameMode) or "initial"
	local showNumber = (db == nil) or db.channelNumber
	local capitalize = (db == nil) or db.channelCapitalize

	local label
	if (mode == "full") then
		label = name or ""
		if (capitalize and label ~= "") then
			label = string_upper(string_sub(label, 1, 1))..string_sub(label, 2)
		end
	else
		label = string_sub(name or "", 1, 1)
		if (capitalize) then
			label = string_upper(label)
		end
	end

	-- Both modes are wrapped in brackets, e.g. "[G]" or "[General]".
	label = "["..label.."]"

	local prefix = ""
	if (showNumber and displaynum) then
		prefix = displaynum..". "
	end

	return "|Hchannel:"..channel..":"..number.."|h"..prefix..label.."|h"
end

-- WoW Globals (some may be nil in older clients like 3.3.5)
local G = {
	CHAT_BATTLEGROUND_GET = CHAT_BATTLEGROUND_GET,
	CHAT_BATTLEGROUND_LEADER_GET = CHAT_BATTLEGROUND_LEADER_GET,
	CHAT_GUILD_GET = CHAT_GUILD_GET,
	CHAT_INSTANCE_CHAT_GET = CHAT_INSTANCE_CHAT_GET, -- May be nil in 3.3.5
	CHAT_INSTANCE_CHAT_LEADER_GET = CHAT_INSTANCE_CHAT_LEADER_GET, -- May be nil in 3.3.5
	CHAT_PARTY_GET = CHAT_PARTY_GET,
	CHAT_PARTY_LEADER_GET = CHAT_PARTY_LEADER_GET,
	CHAT_RAID_GET = CHAT_RAID_GET,
	CHAT_RAID_LEADER_GET = CHAT_RAID_LEADER_GET,
	CHAT_RAID_WARNING_GET = CHAT_RAID_WARNING_GET,
	CHAT_OFFICER_GET = CHAT_OFFICER_GET,
	CHAT_YOU_CHANGED_NOTICE =  CHAT_YOU_CHANGED_NOTICE, -- "Changed Channel: |Hchannel:%d|h[%s]|h"
	CHAT_YOU_CHANGED_NOTICE_BN =  CHAT_YOU_CHANGED_NOTICE_BN -- "Changed Channel: |Hchannel:CHANNEL:%d|h[%s]|h" (may be nil in 3.3.5)
}

Module.OnInitialize = function(self)

	self.replacements = {}

	-- Helper for channels that respects channelNameMode setting
	-- fullName is the full channel name (e.g. "Guild"), shortName is the abbreviation (e.g. "G")
	local function safeAddDynamicReplacement(chatGlobal, fullName, shortName)
		if chatGlobal then
			local match = string_match(chatGlobal, "%[(.-)%]")
			if match then
				table_insert(self.replacements, {"%["..match.."%]", function()
					local mode = (ns.db and ns.db.channelNameMode) or "initial"
					if mode == "full" then
						return "[" .. fullName .. "]"
					else
						return "[" .. shortName .. "]"
					end
				end})
			end
		end
	end

	-- All channels respect the full/shortened channel name mode
	safeAddDynamicReplacement(G.CHAT_PARTY_LEADER_GET, "Party Leader", L["PL"])
	safeAddDynamicReplacement(G.CHAT_PARTY_GET, "Party", L["P"])
	safeAddDynamicReplacement(G.CHAT_RAID_LEADER_GET, "Raid Leader", L["RL"])
	safeAddDynamicReplacement(G.CHAT_RAID_GET, "Raid", L["R"])
	safeAddDynamicReplacement(G.CHAT_BATTLEGROUND_LEADER_GET, "Battleground Leader", L["BGL"])
	safeAddDynamicReplacement(G.CHAT_BATTLEGROUND_GET, "Battleground", L["BG"])

	-- Instance chat didn't exist in 3.3.5 - only add these replacements if the globals exist
	safeAddDynamicReplacement(G.CHAT_INSTANCE_CHAT_LEADER_GET, "Instance Leader", L["IL"])
	safeAddDynamicReplacement(G.CHAT_INSTANCE_CHAT_GET, "Instance", L["I"])

	-- Guild and Officer
	safeAddDynamicReplacement(G.CHAT_GUILD_GET, "Guild", L["G"])
	safeAddDynamicReplacement(G.CHAT_OFFICER_GET, "Officer", L["O"])

	-- Ascension-specific: Dungeon Guide (LFG party channel)
	-- Format: |Hchannel:PARTY|h[Dungeon Guide]|h
	table_insert(self.replacements, {"|Hchannel:PARTY|h%[Dungeon Guide%]|h", function()
		local mode = (ns.db and ns.db.channelNameMode) or "initial"
		if mode == "full" then
			return "|Hchannel:PARTY|h[Dungeon Guide]|h"
		else
			return "|Hchannel:PARTY|h[" .. L["DG"] .. "]|h"
		end
	end})
	
	-- Raid Warning gets special formatting - red exclamation mark (no brackets)
	if G.CHAT_RAID_WARNING_GET then
		local match = string_match(G.CHAT_RAID_WARNING_GET, "%[(.-)%]")
		if match then
			table_insert(self.replacements, {"%["..match.."%]", "|cffff0000!|r"})
		end
	end

	-- Turns "[1. General - The Barrens]" into "General"
	--table_insert(self.replacements, {"|Hchannel:(.-):(%d+)|h%[(%d)%. (.-)(%s%-%s.-)%]|h", "|Hchannel:%1:%2|h%4.|h"})

	-- Only works for English, will add a better solution later.
	--table_insert(self.replacements, { "^Changed Channel: |Hchannel:(.-):(%d+)|h%[(%d)%. (.-)(%s%-%s.-)%]|h", "|Hchannel:%1:%2|h%3. %5|h" })
	table_insert(self.replacements, { "^Changed Channel: |Hchannel:(.-):(%d+)|h%[(%d)%. (.-)%]|h", "|Hchannel:%1:%2|h%3. %4|h" })
	-- |Hchannel:%d|h[%s]|h

	-- Turns "[1. General - The Barrens]" into "1. [G]".
	-- The name and suffix captures explicitly exclude "]" and "|" so the
	-- pattern can never run past the channel link into a following player or
	-- item link. (An item like "[Keystone: Scarlet Monastery - Library (1)]"
	-- also contains " - ", which previously made the lazy ".-" swallow the
	-- whole line, deleting the sender's name and the item link.)
	table_insert(self.replacements, {"|Hchannel:([^|]-):(%d+)|h%[(%d+)%. ([^%]|]-)(%s%-%s[^%]|]-)%]|h", formatChannelTag})
	table_insert(self.replacements, {"|Hchannel:([^|]-):(%d+)|h%[(%d+)%. ([^%]|]-)%]|h", formatChannelTag})

end

Module.OnEnable = function(self)
	self:RegisterMessageReplacement(self.replacements, true)
end

Module.OnDisable = function(self)
	self:UnregisterMessageReplacement(self.replacements)
end
