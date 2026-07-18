local Addon, ns = ...

local Module = ns:NewModule("LinkHover", "AceHook-3.0")
local _G = _G
local string_match = string.match
local ShowUIPanel = ShowUIPanel
local HideUIPanel = HideUIPanel
local GameTooltip = GameTooltip
local UIParent = UIParent
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10

local linkTypes = {
	item = true,
	enchant = true,
	spell = true,
	quest = true,
	achievement = true,
}

local function OnHyperlinkEnter(frame, link, ...)
	if not link then return end
	local linkType = string_match(link, "^(.-):")
	if linkTypes[linkType] then
		ShowUIPanel(GameTooltip)
		GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
	end
end

local function OnHyperlinkLeave(frame, link, ...)
	if not link then return end
	local linkType = string_match(link, "^(.-):")
	if linkTypes[linkType] then
		HideUIPanel(GameTooltip)
	end
end

function Module:OnEnable()
	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame"..i]
		if frame then
			self:HookScript(frame, "OnHyperlinkEnter", OnHyperlinkEnter)
			self:HookScript(frame, "OnHyperlinkLeave", OnHyperlinkLeave)
		end
	end
end

function Module:OnDisable()
	self:UnhookAll()
end
