local Addon, ns = ...

local Module = ns:NewModule("Highlight", "AceEvent-3.0")
local _G = _G
local string_find = string.find
local string_gsub = string.gsub
local string_lower = string.lower
local PlaySound = PlaySound
local UnitName = UnitName

local keywords = {}

local function HighlightText(msg)
	if not msg then return msg end
	local playerName = UnitName("player")
	if playerName and playerName ~= "" then
		local lowerMsg = string_lower(msg)
		local lowerName = string_lower(playerName)
		local startIdx = string_find(lowerMsg, lowerName, 1, true)
		if startIdx then
			local matchedName = msg:sub(startIdx, startIdx + #playerName - 1)
			msg = msg:sub(1, startIdx - 1) .. "|cffffcc00" .. matchedName .. "|r" .. msg:sub(startIdx + #playerName)
			PlaySound("RaidWarning")
		end
	end
	return msg
end

function Module:OnEnable()
	self:RegisterMessageReplacement(HighlightText, true)
end

function Module:OnDisable()
	self:UnregisterMessageReplacement(HighlightText)
end
