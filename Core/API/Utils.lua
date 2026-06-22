local _, ns = ...

-- Lua API
local string_gsub = string.gsub

-- Converts a WoW global string (containing %d / %s tokens) into a Lua
-- search pattern with capture groups. Previously duplicated verbatim in
-- every Components module; centralized here as ns.MakePattern.
ns.MakePattern = function(msg)
	if (not msg) or (msg == "") then return nil end
	msg = string_gsub(msg, "%%([%d%$]-)d", "(%%d+)")
	msg = string_gsub(msg, "%%([%d%$]-)s", "(.+)")
	return msg
end
