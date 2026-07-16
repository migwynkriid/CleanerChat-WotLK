--[[
	FilterSync.lua
	
	Bidirectional sync between CleanerChat filters and Blizzard's default
	chat filter settings in the Chat Settings UI.
	
	When you toggle a filter in /cc, it updates Blizzard's settings.
	When you toggle a filter in Blizzard's Chat Settings, it updates CleanerChat.
]]

local _, ns = ...

local FilterSync = {}
ns.FilterSync = FilterSync

-- Mapping: CleanerChat filter key -> Blizzard message group(s).
-- CONTRACT: this sync only ever ADDS (enables) a message group, never removes
-- one. CleanerChat reformats messages; it must never hide a whole Blizzard chat
-- category, because removing a message group unregisters that CHAT_MSG_* event
-- and breaks other addons / server modules that read it (issue #52). When a
-- filter is off we leave the category exactly as the user has it.
local CC_TO_BLIZZARD = {
	experience = { "COMBAT_XP_GAIN" },
	honor = { "COMBAT_HONOR_GAIN" },
	reputation = { "COMBAT_FACTION_CHANGE" },
	loot = { "LOOT", "MONEY" },
	tradeskills = { "SKILL", "TRADESKILLS" },
	opening = { "OPENING" },
	petinfo = { "PET_INFO" },
	miscinfo = { "COMBAT_MISC_INFO" },
	systemmessages = { "SYSTEM" },
	achievements = { "ACHIEVEMENT", "GUILD_ACHIEVEMENT" },
	bossmessages = { "MONSTER_EMOTE", "MONSTER_WHISPER", "RAID_BOSS_EMOTE", "RAID_BOSS_WHISPER" },
}

-- Reverse mapping: Blizzard message group -> CleanerChat filter key
local BLIZZARD_TO_CC = {}
for ccFilter, blizzGroups in pairs(CC_TO_BLIZZARD) do
	for _, group in ipairs(blizzGroups) do
		BLIZZARD_TO_CC[group] = ccFilter
	end
end

-- Track if we're currently syncing to prevent infinite loops
local isSyncing = false

-- Get the primary chat frame (ChatFrame1)
local function GetPrimaryChatFrame()
	return ChatFrame1
end

-- Enable a message group for the primary chat frame
local function EnableMessageGroup(group)
	local chatFrame = GetPrimaryChatFrame()
	if chatFrame and ChatFrame_AddMessageGroup then
		ChatFrame_AddMessageGroup(chatFrame, group)
	end
end

-- Sync a CleanerChat filter state TO Blizzard's settings.
-- ENABLE-ONLY: we never remove a group here. When a filter is turned off we leave
-- the Blizzard category untouched, so the raw messages keep showing and other
-- addons that read that channel keep working (see the CC_TO_BLIZZARD contract).
function FilterSync:SyncToBlizzard(filterKey, enabled)
	if not enabled then
		return
	end

	if isSyncing then
		return
	end

	local blizzGroups = CC_TO_BLIZZARD[filterKey]
	if not blizzGroups then
		return
	end

	isSyncing = true

	for _, group in ipairs(blizzGroups) do
		EnableMessageGroup(group)
	end

	isSyncing = false
end

-- Sync a Blizzard message group change TO CleanerChat
function FilterSync:SyncFromBlizzard(group, enabled)
	if isSyncing then
		return
	end

	local ccFilter = BLIZZARD_TO_CC[group]
	if not ccFilter then
		return
	end

	-- Only update if different from current state
	if ns.db and ns.db.filters and ns.db.filters[ccFilter] ~= nil then
		if ns.db.filters[ccFilter] ~= enabled then
			isSyncing = true

			ns.db.filters[ccFilter] = enabled

			-- Update module state
			local moduleName = ns:GetModuleNameFromFilter(ccFilter)
			local module = ns:GetModule(moduleName, true)
			if module then
				if enabled and not module:IsEnabled() then
					module:Enable()
				elseif not enabled and module:IsEnabled() then
					module:Disable()
				end
			end

			isSyncing = false
		end
	end
end

-- Sync ALL CleanerChat filters to Blizzard on load
function FilterSync:SyncAllToBlizzard()
	if not ns.db or not ns.db.filters then
		return
	end

	for filterKey, enabled in pairs(ns.db.filters) do
		self:SyncToBlizzard(filterKey, enabled)
	end
end

-- Hook Blizzard's message group functions to detect changes
function FilterSync:HookBlizzardFunctions()
	-- Hook ChatFrame_AddMessageGroup
	if ChatFrame_AddMessageGroup then
		hooksecurefunc("ChatFrame_AddMessageGroup", function(chatFrame, group)
			if chatFrame == GetPrimaryChatFrame() then
				FilterSync:SyncFromBlizzard(group, true)
			end
		end)
	end

	-- Hook ChatFrame_RemoveMessageGroup
	if ChatFrame_RemoveMessageGroup then
		hooksecurefunc("ChatFrame_RemoveMessageGroup", function(chatFrame, group)
			if chatFrame == GetPrimaryChatFrame() then
				FilterSync:SyncFromBlizzard(group, false)
			end
		end)
	end
end

-- One-time repair for profiles damaged by older versions, which used to REMOVE
-- Blizzard message groups whenever a filter was off (or defaulted off). That
-- unregistered the matching CHAT_MSG_* events and broke other addons / server
-- modules that read them (e.g. reagent-bank mods over CHAT_MSG_SYSTEM, issue #52).
-- Those removals are persisted in the saved chat layout, so re-add every group we
-- ever mapped, once, to restore visibility. Guarded by a saved flag so we don't
-- fight a user who later hides a category on purpose. isSyncing suppresses the
-- reverse-sync hook so re-adding a group doesn't flip a CleanerChat filter on.
function FilterSync:RepairMessageGroups()
	if ns.db and ns.db.chatGroupsRepaired then
		return
	end
	local chatFrame = GetPrimaryChatFrame()
	if chatFrame and ChatFrame_AddMessageGroup then
		isSyncing = true
		for _, blizzGroups in pairs(CC_TO_BLIZZARD) do
			for _, group in ipairs(blizzGroups) do
				ChatFrame_AddMessageGroup(chatFrame, group)
			end
		end
		isSyncing = false
	end
	if ns.db then
		ns.db.chatGroupsRepaired = true
	end
end

-- Initialize sync system
function FilterSync:Initialize()
	-- Hook Blizzard functions for reverse sync
	self:HookBlizzardFunctions()

	local function run()
		FilterSync:RepairMessageGroups()
		FilterSync:SyncAllToBlizzard()
	end

	-- Defer briefly so the chat frame and its saved layout are fully loaded.
	if C_Timer and C_Timer.After then
		C_Timer.After(1, run)
	elseif ns.Timer and ns.Timer.After then
		ns.Timer.After(1, run)
	else
		-- Fallback: use OnUpdate frame
		local frame = CreateFrame("Frame")
		local elapsed = 0
		frame:SetScript("OnUpdate", function(updateFrame, delta)
			elapsed = elapsed + delta
			if elapsed > 1 then
				run()
				updateFrame:SetScript("OnUpdate", nil)
			end
		end)
	end
end

-- Expose sync function for Options.lua to call when filters change
ns.SyncFilterToBlizzard = function(filterKey, enabled)
	FilterSync:SyncToBlizzard(filterKey, enabled)
end
