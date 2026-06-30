local _, ns = ...

local Module = ns:NewModule("Names")

-- Lua API
local string_gsub = string.gsub
local string_lower = string.lower
local string_upper = string.upper

local replacements = {
	{ "|Hplayer:(.-)-(.-):(.-)|h%[|c(%w%w%w%w%w%w%w%w)(.-)-(.-)|r%]|h", "|Hplayer:%1-%2:%3|h|c%4%5|r|h" },
	{ "|Hplayer:(.-)-(.-):(.-)|h|c(%w%w%w%w%w%w%w%w)(.-)-(.-)|r|h", "|Hplayer:%1-%2:%3|h|c%4%5|r|h" },
	{ "|Hplayer:(.-)|h%[(.-)%]|h", "|Hplayer:%1|h%2|h" },
	{ "|HBNplayer:(.-)|h%[(.-)%]|h", "|HBNplayer:%1|h%2|h" },
}

-- Force the first letter of a name to the configured case. WoW stores
-- character names first-letter-capitalized, so when "Capitalize Player Names"
-- is turned off we actively lowercase the initial -- otherwise the option would
-- have no visible effect (the name always arrives already capitalized).
local nameCase = function(letter)
	if (ns.db == nil) or ns.db.capitalizeNames then
		return string_upper(letter)
	end
	return string_lower(letter)
end

-- Apply the configured case to the first letter of the displayed name,
-- handling both colored (|cAARRGGBBname|r) and plain names.
local applyNameCase = function(open, display, close)
	display = string_gsub(display, "^(|c%x%x%x%x%x%x%x%x)(%a)", function(color, letter)
		return color .. nameCase(letter)
	end)
	display = string_gsub(display, "^(%a)", nameCase)
	return open .. display .. close
end

-- Function replacement that forces the first initial of player names to the
-- configured case: upper when "Capitalize Player Names" is on, lower when off.
local capitalizeNames = function(msg)
	if not msg then
		return
	end
	msg = string_gsub(msg, "(|Hplayer:.-|h)(.-)(|h)", applyNameCase)
	msg = string_gsub(msg, "(|HBNplayer:.-|h)(.-)(|h)", applyNameCase)
	return msg
end

Module.OnEnable = function(self)
	self:RegisterMessageReplacement(replacements, true)
	self:RegisterMessageReplacement(capitalizeNames, true)
end

Module.OnDisable = function(self)
	self:UnregisterMessageReplacement(replacements)
	self:UnregisterMessageReplacement(capitalizeNames)
end
