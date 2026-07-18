local Addon, ns = ...

local Module = ns:NewModule("AltNames", "AceEvent-3.0")
local _G = _G
local string_match = string.match
local string_gsub = string.gsub
local GetNumGuildMembers = GetNumGuildMembers
local GetGuildRosterInfo = GetGuildRosterInfo

local altMap = {}

local function ScanGuildNotes()
	if not IsInGuild() then return end
	local numMembers = GetNumGuildMembers()
	for i = 1, numMembers do
		local name, rank, rankIndex, level, class, zone, note, officerNote = GetGuildRosterInfo(i)
		if name then
			local cleanName = string_match(name, "([^%-]+)") or name
			local main = string_match(note or "", "main:%s*(%a+)") or string_match(note or "", "alt of%s*(%a+)") or string_match(note or "", "^(%a+)$")
			if not main and officerNote and officerNote ~= "" then
				main = string_match(officerNote, "main:%s*(%a+)") or string_match(officerNote, "alt of%s*(%a+)") or string_match(officerNote, "^(%a+)$")
			end
			if main and main ~= cleanName then
				altMap[cleanName] = main
			end
		end
	end
end

local function FormatAltNames(msg)
	if not msg or not next(altMap) then return msg end
	msg = string_gsub(msg, "|Hplayer:(.-)|h%[(.-)%]|h", function(playerData, name)
		local cleanName = string_match(name, "^|c%x%x%x%x%x%x%x%x(.-)|r$") or name
		local main = altMap[cleanName]
		if main then
			return "|Hplayer:" .. playerData .. "|h[" .. name .. " (" .. main .. ")]|h"
		end
		return "|Hplayer:" .. playerData .. "|h[" .. name .. "]|h"
	end)
	return msg
end

function Module:OnEnable()
	self:RegisterEvent("GUILD_ROSTER_UPDATE", ScanGuildNotes)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		if IsInGuild() then GuildRoster() end
	end)
	self:RegisterMessageReplacement(FormatAltNames, true)
end

function Module:OnDisable()
	self:UnregisterAllEvents()
	self:UnregisterMessageReplacement(FormatAltNames)
end
