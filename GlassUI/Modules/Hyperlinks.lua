local Core, Constants = unpack(select(2, ...))
local Hyperlinks = Core:GetModule("Hyperlinks")

local HYPERLINK_CLICK = Constants.EVENTS.HYPERLINK_CLICK
local HYPERLINK_ENTER = Constants.EVENTS.HYPERLINK_ENTER
local HYPERLINK_LEAVE = Constants.EVENTS.HYPERLINK_LEAVE

-- luacheck: push ignore 113
local GameTooltip = GameTooltip
local ShowUIPanel = ShowUIPanel
local UIParent = UIParent
local CreateFrame = CreateFrame
-- luacheck: pop

-- WotLK 3.3.5 supported link types
local linkTypes = {
	item = true,
	enchant = true,
	spell = true,
	quest = true,
	achievement = true,
	talent = true,
	glyph = true,
	unit = true,
	trade = true,
}

-- Copy dialog shown when a detected URL link is clicked. WotLK has no
-- programmatic clipboard, so we present the URL in a focused, pre-selected edit
-- box for the user to Ctrl+C. We build a small custom frame instead of a
-- StaticPopup, whose editbox/extra sub-frames render unpredictably (a stray
-- black square) on this client.
local copyDialog

local function ensureCopyDialog()
	if copyDialog then
		return copyDialog
	end

	local f = CreateFrame("Frame", "CleanerChatCopyURLDialog", UIParent)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetSize(400, 112)
	f:SetPoint("CENTER")
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)

	local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	title:SetPoint("TOP", 0, -18)
	title:SetText("Link (press Ctrl+C to copy):")

	local editBox = CreateFrame("EditBox", "CleanerChatCopyURLDialogEditBox", f, "InputBoxTemplate")
	editBox:SetSize(340, 20)
	editBox:SetPoint("TOP", title, "BOTTOM", 0, -14)
	editBox:SetAutoFocus(false)
	editBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		f:Hide()
	end)
	editBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		f:Hide()
	end)
	editBox:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	f.editBox = editBox

	local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	close:SetSize(100, 24)
	close:SetPoint("BOTTOM", 0, 16)
	close:SetText(_G.CLOSE or "Close")
	close:SetScript("OnClick", function()
		f:Hide()
	end)

	-- Let Escape close it via the standard mechanism.
	if _G.UISpecialFrames then
		table.insert(_G.UISpecialFrames, "CleanerChatCopyURLDialog")
	end

	f:Hide()
	copyDialog = f
	return f
end

local function showCopyDialog(url)
	local f = ensureCopyDialog()
	f.editBox:SetText(url or "")
	f.editBox:SetCursorPosition(0)
	f:Show()
	f:Raise()
	f.editBox:SetFocus()
	f.editBox:HighlightText()
end

function Hyperlinks:OnInitialize()
	self.state = {
		showingTooltip = nil,
	}
end

function Hyperlinks:OnEnable()
	Core:Subscribe(HYPERLINK_CLICK, function(payload)
		local link, text, button = unpack(payload)

		-- Detected URL links open a small copy dialog instead of SetItemRef.
		local linkType = link and string.match(link, "^(%a+):")
		if linkType == "url" then
			local url = string.match(link, "^url:(.+)$") or text
			if url and url ~= "" then
				showCopyDialog(url)
			end
			return
		end

		-- Use global reference in case some addon has hooked into it for custom
		-- hyperlinks (e.g. Mythic Dungeon Tools, Prat).
		--
		-- pcall it: our clickable overlays make EVERY |H...|h link clickable, and
		-- some chat link types ("trial:", "uierror:", custom server links) aren't
		-- understood by SetItemRef -> ItemRefTooltip:SetHyperlink and throw
		-- "Unknown link type". There's nothing useful to show for those, so a
		-- failed click is silently ignored instead of erroring (mass-clicking
		-- otherwise spammed the error frame). Valid/addon-handled links still work.
		--
		-- IMPORTANT: Pass the chatFrame as 4th arg so channel dropdown callbacks
		-- know which frame to operate on (fixes "Move to New Window" etc.)
		local chatFrame
		if Core.Components.selectedTab and Core.Components.selectedTab.chatFrame then
			chatFrame = Core.Components.selectedTab.chatFrame
		else
			chatFrame = _G.SELECTED_CHAT_FRAME or _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
		end
		pcall(_G.SetItemRef, link, text, button, chatFrame)
	end)

	Core:Subscribe(HYPERLINK_ENTER, function(payload)
		local link = unpack(payload)
		local t = string.match(link, "^(.-):")

		if t == "url" then
			self.state.showingTooltip = GameTooltip
			GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
			GameTooltip:SetText("Click to copy link")
			GameTooltip:Show()
		elseif linkTypes[t] then
			self.state.showingTooltip = GameTooltip
			ShowUIPanel(GameTooltip)
			GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
			GameTooltip:SetHyperlink(link)
			GameTooltip:Show()
		end
	end)

	Core:Subscribe(HYPERLINK_LEAVE, function(link)
		if self.state.showingTooltip then
			self.state.showingTooltip:Hide()
			self.state.showingTooltip = false
		end
	end)
end
