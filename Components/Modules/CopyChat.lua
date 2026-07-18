local Addon, ns = ...

local Module = ns:NewModule("CopyChat", "AceConsole-3.0")
local _G = _G
local table_concat = table.concat
local table_insert = table.insert
local CreateFrame = CreateFrame
local FCF_GetCurrentChatFrame = FCF_GetCurrentChatFrame or function() return _G.ChatFrame1 end

local copyFrame

local function CreateGlassCopyFrame()
	if copyFrame then return copyFrame end

	local frame = CreateFrame("Frame", "CleanerChat_CopyChatFrame", UIParent)
	frame:SetSize(600, 400)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
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
	frame:SetBackdropColor(0.05, 0.07, 0.10, 0.92)
	frame:SetBackdropBorderColor(0.2, 0.4, 0.6, 0.8)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
	title:SetText("CleanerChat — Copy Chat History")
	title:SetTextColor(0.4, 0.8, 1.0)

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

	local scrollArea = CreateFrame("ScrollFrame", "CleanerChat_CopyScrollFrame", frame, "UIPanelScrollFrameTemplate")
	scrollArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -34)
	scrollArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 12)

	local editBox = CreateFrame("EditBox", nil, scrollArea)
	editBox:SetMultiLine(true)
	editBox:SetMaxLetters(0)
	editBox:SetEnableMouse(true)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject("GameFontHighlightSmall")
	editBox:SetWidth(540)
	editBox:SetScript("OnEscapePressed", function() frame:Hide() end)

	scrollArea:SetScrollChild(editBox)

	frame.editBox = editBox
	copyFrame = frame
	return copyFrame
end

function Module:CopyCurrentChatFrame()
	local cf = FCF_GetCurrentChatFrame()
	if not cf then return end

	local lines = {}
	local numMessages = cf:GetNumMessages()
	for i = 1, numMessages do
		local text = cf:GetMessageInfo(i)
		if text then
			table_insert(lines, text)
		end
	end

	local fullText = table_concat(lines, "\n")
	local dialog = CreateGlassCopyFrame()
	dialog.editBox:SetText(fullText)
	dialog:Show()
	dialog.editBox:SetFocus()
	dialog.editBox:HighlightText()
end

function Module:OnEnable()
	self:RegisterChatCommand("copychat", "CopyCurrentChatFrame")
	self:RegisterChatCommand("cccopy", "CopyCurrentChatFrame")
end
