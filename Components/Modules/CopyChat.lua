local _, ns = ...

-- Copy Chat History
-- Adds /copychat (and /cccopy), which opens a window with the current chat
-- window's recent lines as selectable text so they can be copied out with
-- Ctrl+C. Reads from Glass's own stored history first (the native
-- ScrollingMessageFrame has no public "read every message" API on 3.3.5) and
-- falls back to the native frame on clients that do expose GetMessageInfo.

local Module = ns:NewModule("CopyChat", "AceConsole-3.0")

-- Lua API
local ipairs = ipairs
local pairs = pairs
local table_concat = table.concat

-- WoW API
local _G = _G
local CreateFrame = CreateFrame
-- GLOBALS: CreateFrame, UIParent, FCF_GetCurrentChatFrame

local copyFrame

local function createCopyFrame()
	if copyFrame then
		return copyFrame
	end

	local frame = CreateFrame("Frame", "CleanerChatCopyChatDialog", _G.UIParent)
	frame:SetSize(600, 400)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	frame:SetBackdropColor(0.05, 0.07, 0.1, 0.94)
	frame:SetBackdropBorderColor(0.2, 0.4, 0.6, 0.8)
	frame:Hide()

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText("CleanerChat - Copy Chat History")
	title:SetTextColor(0.4, 0.8, 1.0)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local scroll = CreateFrame("ScrollFrame", "CleanerChatCopyChatScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -34)
	scroll:SetPoint("BOTTOMRIGHT", -32, 12)

	local editBox = CreateFrame("EditBox", nil, scroll)
	editBox:SetMultiLine(true)
	editBox:SetMaxLetters(0)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject("GameFontHighlightSmall")
	editBox:SetWidth(540)
	editBox:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	scroll:SetScrollChild(editBox)

	frame.editBox = editBox
	copyFrame = frame
	return copyFrame
end

-- Prefer Glass's own history (what is actually shown by this addon).
local function collectFromGlass()
	local Glass = _G.Glass
	if not Glass or not Glass.GetModule then
		return nil
	end
	local UIManager = Glass:GetModule("UIManager", true)
	local window = UIManager and (UIManager.activeWindow or UIManager.mainWindow)
	if not window or not window.frames then
		return nil
	end
	for _, smf in pairs(window.frames) do
		local raw = smf and smf.state and smf.state.rawMessages
		if raw and #raw > 0 then
			local lines = {}
			for _, entry in ipairs(raw) do
				lines[#lines + 1] = entry.text or ""
			end
			return lines
		end
	end
	return nil
end

-- Fallback: the native frame, on clients that expose GetMessageInfo.
local function collectFromNative()
	local getCurrent = _G.FCF_GetCurrentChatFrame
	local cf = (getCurrent and getCurrent()) or _G.ChatFrame1
	if not cf or not cf.GetNumMessages or not cf.GetMessageInfo then
		return nil
	end
	local lines = {}
	for i = 1, cf:GetNumMessages() do
		local text = cf:GetMessageInfo(i)
		if text then
			lines[#lines + 1] = text
		end
	end
	return lines
end

function Module:OpenCopyWindow()
	local lines = collectFromGlass() or collectFromNative()
	if not lines or #lines == 0 then
		self:Print("No chat history is available to copy yet.")
		return
	end
	local dialog = createCopyFrame()
	dialog.editBox:SetText(table_concat(lines, "\n"))
	dialog:Show()
	dialog.editBox:SetFocus()
	dialog.editBox:HighlightText()
end

function Module:OnEnable()
	self:RegisterChatCommand("copychat", "OpenCopyWindow")
	self:RegisterChatCommand("cccopy", "OpenCopyWindow")
end

function Module:OnDisable()
	self:UnregisterChatCommand("copychat")
	self:UnregisterChatCommand("cccopy")
end
