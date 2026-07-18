local Addon, ns = ...

local Module = ns:NewModule("ClickInvite", "AceHook-3.0")
local _G = _G
local string_match = string.match
local IsShiftKeyDown = IsShiftKeyDown
local InviteUnit = InviteUnit

function Module:OnEnable()
	self:RawHook("ChatFrame_OnHyperlinkShow", function(frame, link, text, button, ...)
		if link and string_match(link, "^player:") and IsShiftKeyDown() then
			local name = string_match(link, "^player:([^:]+)")
			if name then
				InviteUnit(name)
				return
			end
		end
		return self.hooks.ChatFrame_OnHyperlinkShow(frame, link, text, button, ...)
	end, true)
end

function Module:OnDisable()
	self:UnhookAll()
end
