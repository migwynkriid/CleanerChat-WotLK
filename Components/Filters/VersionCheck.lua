local Addon, ns = ...

local Module = ns:NewModule("VersionCheck", "AceEvent-3.0")

-- Lua API
local tonumber = tonumber
local string_match = string.match
local string_format = string.format
local string_gsub = string.gsub

-- WoW API
local CreateFrame = CreateFrame
local GetAddOnMetadata = GetAddOnMetadata
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local GetTime = GetTime
local IsInGuild = IsInGuild
local SendAddonMessage = SendAddonMessage
local UnitInBattleground = UnitInBattleground

-- Addon message prefix (max 16 chars)
local ADDON_PREFIX = "CleanerChat"

-- Current version from TOC
local CURRENT_VERSION = GetAddOnMetadata(Addon, "Version") or "0.0"

-- State
local hasNotifiedThisSession = false
local highestVersionSeen = CURRENT_VERSION
local lastBroadcastTime = 0
local BROADCAST_THROTTLE = 60 -- seconds between broadcasts

-- Parse version string to comparable number (e.g., "2.12" -> 212, "2.9" -> 209)
local function ParseVersion(versionStr)
	if not versionStr then
		return 0
	end
	local major, minor = string_match(versionStr, "^(%d+)%.(%d+)")
	if major and minor then
		return tonumber(major) * 100 + tonumber(minor)
	end
	-- Try single number
	local single = string_match(versionStr, "^(%d+)")
	if single then
		return tonumber(single) * 100
	end
	return 0
end

-- Compare two version strings, returns true if v1 > v2
local function IsNewerVersion(v1, v2)
	return ParseVersion(v1) > ParseVersion(v2)
end

-- Send version to a channel
local function SendVersion(channel)
	SendAddonMessage(ADDON_PREFIX, CURRENT_VERSION, channel)
end

-- Broadcast version to all available channels
local function BroadcastVersion()
	-- Throttle broadcasts to prevent spam
	local now = GetTime()
	if now - lastBroadcastTime < BROADCAST_THROTTLE then
		return
	end
	lastBroadcastTime = now

	-- Guild
	if IsInGuild() then
		SendVersion("GUILD")
	end

	-- Party/Raid (WotLK 3.3.5 uses GetNumRaidMembers/GetNumPartyMembers)
	local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
	local numParty = GetNumPartyMembers and GetNumPartyMembers() or 0

	if numRaid > 0 then
		SendVersion("RAID")
	elseif numParty > 0 then
		SendVersion("PARTY")
	end

	-- Battleground
	if UnitInBattleground and UnitInBattleground("player") then
		SendVersion("BATTLEGROUND")
	end
end

-- Handle incoming version messages
local function OnAddonMessage(prefix, message, _channel, _sender)
	if prefix ~= ADDON_PREFIX then
		return
	end
	if not message or message == "" then
		return
	end

	local incomingVersion = string_gsub(message, "%s+", "") -- trim whitespace

	-- Reject anything that isn't a bare "major.minor" version. This is untrusted
	-- input from another player's addon message; without this, a crafted version
	-- string (e.g. one containing |H links or |c colour codes) would be stored
	-- and later printed straight into the user's chat frame.
	if not string_match(incomingVersion, "^%d+%.%d+$") then
		return
	end

	-- Check if this is a newer version than we've seen
	if IsNewerVersion(incomingVersion, highestVersionSeen) then
		highestVersionSeen = incomingVersion
	end

	-- Notify user once per session if they're outdated
	if not hasNotifiedThisSession and IsNewerVersion(highestVersionSeen, CURRENT_VERSION) then
		hasNotifiedThisSession = true

		-- Print update notification to chat
		local msg = string_format(
			"|cffDFBA69CleanerChat|r: Update available! You have |cffFF6666v%s|r, latest is |cff66FF66v%s|r",
			CURRENT_VERSION,
			highestVersionSeen
		)
		DEFAULT_CHAT_FRAME:AddMessage(msg)
	end
end

function Module:OnEnable()
	-- Create event frame for addon messages
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("CHAT_MSG_ADDON")
	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED") -- WotLK 3.3.5
	eventFrame:RegisterEvent("RAID_ROSTER_UPDATE") -- WotLK 3.3.5
	eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

	eventFrame:SetScript("OnEvent", function(_frame, event, ...)
		if event == "CHAT_MSG_ADDON" then
			OnAddonMessage(...)
		elseif event == "PLAYER_ENTERING_WORLD" then
			-- Delay broadcast slightly to ensure channels are ready
			if ns.Timer and ns.Timer.After then
				ns.Timer.After(5, BroadcastVersion)
			elseif C_Timer and C_Timer.After then
				C_Timer.After(5, BroadcastVersion)
			else
				-- Fallback: use OnUpdate
				local delay = CreateFrame("Frame")
				local elapsed = 0
				delay:SetScript("OnUpdate", function(delayFrame, dt)
					elapsed = elapsed + dt
					if elapsed >= 5 then
						delayFrame:SetScript("OnUpdate", nil)
						BroadcastVersion()
					end
				end)
			end
		elseif event == "GROUP_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
			-- Send version when joining a group
			BroadcastVersion()
		elseif event == "GUILD_ROSTER_UPDATE" then
			-- Send version to guild occasionally
			if IsInGuild() then
				SendVersion("GUILD")
			end
		end
	end)

	-- Store reference
	self.eventFrame = eventFrame
end

-- Expose current version for other modules
Module.GetVersion = function()
	return CURRENT_VERSION
end

Module.GetHighestVersionSeen = function()
	return highestVersionSeen
end
