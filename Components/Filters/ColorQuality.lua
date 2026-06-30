local _, ns = ...

local Module = ns:NewModule("QualityColors")

-- Lua API
local pairs = pairs
local table_insert = table.insert

Module.OnInitialize = function(self)
	self.replacements = {}

	local Colors = ns.Colors
	for i, color in pairs(Colors.blizzquality) do
		if color and color.colorCode and Colors.quality[i] and Colors.quality[i].colorCode then
			table_insert(self.replacements, { color.colorCode, Colors.quality[i].colorCode })
		end
	end
end

Module.OnEnable = function(self)
	self:RegisterMessageReplacement(self.replacements, true)
end

Module.OnDisable = function(self)
	self:UnregisterMessageReplacement(self.replacements)
end
