local _, ns = ...

local Module = ns:NewModule("ClassColors")

-- Lua API
local pairs = pairs
local table_insert = table.insert

Module.OnInitialize = function(self)
	self.replacements = {}

	local Colors = ns.Colors
	for class, color in pairs(Colors.blizzclass) do
		if color and color.colorCode and Colors.class[class] and Colors.class[class].colorCode then
			table_insert(self.replacements, { color.colorCode, Colors.class[class].colorCode })
		end
	end
end

Module.OnEnable = function(self)
	self:RegisterMessageReplacement(self.replacements, true)
end

Module.OnDisable = function(self)
	self:UnregisterMessageReplacement(self.replacements)
end
