local Addon, ns = ...

local Module = ns:NewModule("UrlCopy", "AceHook-3.0", "AceEvent-3.0")
local _G = _G
local string_gsub = string.gsub
local string_match = string.match
local CreateFrame = CreateFrame
local ChatFrame_OnHyperlinkShow = ChatFrame_OnHyperlinkShow

local copyDialog

local function CreateGlassURLCopyDialog()
	if copyDialog then return copyDialog end

	local frame = CreateFrame("Frame", "CleanerChat_UrlCopyFrame", UIParent)
	frame:SetSize(420, 100)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	-- Glass UI Backdrop
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false, tileSize = 0, edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	})
	frame:SetBackdropColor(0.05, 0.07, 0.10, 0.90)
	frame:SetBackdropBorderColor(0.2, 0.4, 0.6, 0.8)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
	title:SetText("Copy URL (Ctrl+C):")
	title:SetTextColor(0.4, 0.8, 1.0)

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

	local editBox = CreateFrame("EditBox", nil, frame)
	editBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -36)
	editBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
	editBox:SetFontObject("GameFontHighlight")
	editBox:SetAutoFocus(true)
	editBox:SetScript("OnEscapePressed", function(self) frame:Hide() end)
	editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

	frame.editBox = editBox
	copyDialog = frame
	return copyDialog
end

local function ShowURLCopyDialog(url)
	local dialog = CreateGlassURLCopyDialog()
	dialog.editBox:SetText(url)
	dialog:Show()
	dialog.editBox:SetFocus()
	dialog.editBox:HighlightText()
end

local urlPatterns = {
	{ "(https?://%S+)", "|cff3399ff|Hurl:%1|h[%1]|h|r" },
	{ "(www%.%S+)", "|cff3399ff|Hurl:http://%1|h[%1]|h|r" },
}

local function FormatURLs(msg)
	if not msg or string_match(msg, "|Hurl:") then return msg end
	for _, pattern in ipairs(urlPatterns) do
		msg = string_gsub(msg, pattern[1], pattern[2])
	end
	return msg
end

function Module:OnEnable()
	self:RegisterMessageReplacement(FormatURLs, true)
	self:RawHook("ChatFrame_OnHyperlinkShow", function(frame, link, text, button, ...)
		if link and string_match(link, "^url:") then
			local url = string_match(link, "^url:(.+)")
			ShowURLCopyDialog(url)
			return
		end
		return self.hooks.ChatFrame_OnHyperlinkShow(frame, link, text, button, ...)
	end, true)
end

function Module:OnDisable()
	self:UnregisterMessageReplacement(FormatURLs)
	self:UnhookAll()
end
