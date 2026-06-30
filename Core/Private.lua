local _, ns = ...

-- GLOBALS: getmetatable, setmetatable, rawset, error, tostring, type

local mt = getmetatable(ns) or {}
local private = {}

mt.__newindex = function(t, k, v)
	if private[k] ~= nil then
		error(
			string.format("['%s']: Can't replace the protected %s '%s'.", tostring(ns), type(private[k]), tostring(k)),
			2
		)
	else
		rawset(t, k, v)
	end
end

mt.__index = function(t, k)
	return private[k]
end

setmetatable(ns, mt)

ns.Private = private
