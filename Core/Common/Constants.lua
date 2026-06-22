local Addon, ns = ...

-- GLOBALS: GetBuildInfo

-- Addon version
------------------------------------------------------
-- Keyword substitution requires the packager,
-- and does not affect direct GitHub repo pulls.
local version = "2.0.59-Release"
if (version:find("project%-version")) then
	version = "Development"
end
ns.Private.Version = version

-- WoW client interface version
------------------------------------------------------
local _, _, _, version = GetBuildInfo()

-- 3.3.5 specific detection (private server)
-- Interface 30300 is 3.3.5a, Classic Wrath uses 30400+
ns.Private.Is335 = (version >= 30300) and (version < 30400)
