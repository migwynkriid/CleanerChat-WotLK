local Core, Constants = unpack(select(2, ...))

local Colors = Constants.COLORS

local CreateNewMessageAlertFrame = Core.Components.CreateNewMessageAlertFrame

-- Store original Frame methods (WotLK compatibility)
local FramePrototype = getmetatable(CreateFrame("Frame")).__index
local Frame_SetScript = FramePrototype.SetScript

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local Mixin = Mixin
-- luacheck: pop

local ScrollOverlayFrame = {}

-- Update background style based on useOverlayMask setting
function ScrollOverlayFrame:UpdateBackgroundStyle()
	local useOverlayMask = self.profile.useOverlayMask

	if useOverlayMask then
		-- Use the overlay mask texture
		if self.overlayMask then
			self.overlayMask:Show()
		end
		-- Hide the gradient background
		if self.centerBg then
			self.centerBg:Hide()
		end
		if self.leftBg then
			self.leftBg:Hide()
		end
		if self.rightBg then
			self.rightBg:Hide()
		end
	else
		-- Use customizable background color and opacity
		if self.overlayMask then
			self.overlayMask:Hide()
		end
		local bgColor = self.profile.scrollIndicatorBgColor or Colors.codGray
		local bgOpacity = self.profile.scrollIndicatorBgOpacity or 1
		self:SetGradientBackground(15, 15, bgColor, bgOpacity)
	end
end

function ScrollOverlayFrame:Init()
	-- Get the chat frame width for full-width overlay
	local frameWidth = self.profile.frameWidth or 350
	local overlayHeight = 32

	self:SetHeight(overlayHeight)
	self:SetWidth(frameWidth)
	self:ClearAllPoints()

	-- Position indicator at the edit box location (outside the chat frame)
	local mainContainer = self:GetParent():GetParent() -- SlidingMessageFrame's parent is MainContainerFrame
	-- Offset by -1 horizontally to align with the edit box and messages
	-- Offset by +1 vertically to sit just above the edit box
	local yOffset = (self.profile.editBoxAnchor.yOfs or -1) + 1
	if self.profile.editBoxAnchor.position == "ABOVE" then
		-- Edit box is above the chat, so indicator is above the main container
		self:SetPoint("BOTTOMLEFT", mainContainer, "TOPLEFT", -1, yOffset)
		self:SetPoint("BOTTOMRIGHT", mainContainer, "TOPRIGHT", -1, yOffset)
	else
		-- Edit box is below the chat (default), so indicator is below the main container
		self:SetPoint("TOPLEFT", mainContainer, "BOTTOMLEFT", -1, yOffset)
		self:SetPoint("TOPRIGHT", mainContainer, "BOTTOMRIGHT", -1, yOffset)
	end

	self:SetFadeInDuration(0.3)
	self:SetFadeOutDuration(0.15)

	-- Create overlay mask texture (full-width decorative background)
	if self.overlayMask == nil then
		self.overlayMask = self:CreateTexture(nil, "BACKGROUND")
		self.overlayMask:SetTexture("Interface\\AddOns\\CleanerChat\\Assets\\overlayMask")
		self.overlayMask:SetAllPoints()
	end

	-- Apply the background style based on user preference
	self:UpdateBackgroundStyle()

	-- Down arrow icon
	if self.icon == nil then
		self.icon = self:CreateTexture(nil, "ARTWORK")
	end
	self.icon:SetTexture("Interface\\AddOns\\CleanerChat\\Assets\\snapToBottomIcon")
	self.icon:SetWidth(16)
	self.icon:SetHeight(16)
	self.icon:SetPoint("BOTTOMLEFT", 15, 8)

	-- See new messages click area. Keep the original bottom strip layout but
	-- EnableMouse so it actually receives clicks -- a plain CreateFrame("Frame")
	-- gets no mouse events, so without this the OnMouseDown handler (wired in
	-- SlidingMessageFrame via "OnClickSnapFrame") never fired and clicking the
	-- indicator did nothing. The strip spans the full width over the icon/label.
	if self.snapToBottomFrame == nil then
		self.snapToBottomFrame = CreateFrame("Frame", nil, self)
	end
	self.snapToBottomFrame:ClearAllPoints()
	self.snapToBottomFrame:SetHeight(20)
	self.snapToBottomFrame:SetPoint("BOTTOMLEFT")
	self.snapToBottomFrame:SetPoint("BOTTOMRIGHT")
	self.snapToBottomFrame:EnableMouse(true)

	if self.newMessageAlertFrame == nil then
		self.newMessageAlertFrame = CreateNewMessageAlertFrame(self, self.profile)
	end

	self.newMessageAlertFrame:QuickHide()

	-- Default label shown next to the icon when scrolled up with NO unread
	-- messages -- a passive hint that clicking jumps back to the latest chat.
	-- ShowNewMessageAlert swaps it for the "Unread messages" alert (same slot).
	-- Created last so the proven icon/alert frames are built first.
	if self.snapToPresentText == nil then
		self.snapToPresentText = self:CreateFontString(nil, "ARTWORK", "GlassMessageFont")
	end
	self.snapToPresentText:ClearAllPoints()
	-- Use customizable color and opacity (defaults to apache gold, fully solid).
	local indicatorColor = self.profile.scrollIndicatorColor or Colors.apache
	local indicatorOpacity = self.profile.scrollIndicatorOpacity or 1
	self.snapToPresentText:SetTextColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, indicatorOpacity)
	self.snapToPresentText:SetPoint("BOTTOMLEFT", 30, 10)
	self.snapToPresentText:SetText("Bring me to the present")
	self.snapToPresentText:Show()
end

function ScrollOverlayFrame:UpdatePosition()
	self:ClearAllPoints()

	local mainContainer = self:GetParent():GetParent()
	-- Offset by -1 horizontally to align with the edit box and messages
	-- Offset by +1 vertically to sit just above the edit box
	local yOffset = (self.profile.editBoxAnchor.yOfs or -1) + 1
	if self.profile.editBoxAnchor.position == "ABOVE" then
		-- Edit box is above the chat, so indicator is above the main container
		self:SetPoint("BOTTOMLEFT", mainContainer, "TOPLEFT", -1, yOffset)
		self:SetPoint("BOTTOMRIGHT", mainContainer, "TOPRIGHT", -1, yOffset)
	else
		-- Edit box is below the chat (default), so indicator is below the main container
		self:SetPoint("TOPLEFT", mainContainer, "BOTTOMLEFT", -1, yOffset)
		self:SetPoint("TOPRIGHT", mainContainer, "BOTTOMRIGHT", -1, yOffset)
	end
end

function ScrollOverlayFrame:UpdateIndicatorStyle()
	local indicatorColor = self.profile.scrollIndicatorColor or Colors.apache
	local indicatorOpacity = self.profile.scrollIndicatorOpacity or 1
	if self.snapToPresentText then
		self.snapToPresentText:SetTextColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, indicatorOpacity)
	end
	-- Update background style (overlay mask or gradient)
	self:UpdateBackgroundStyle()
	-- Update child alert frame
	if self.newMessageAlertFrame and self.newMessageAlertFrame.UpdateIndicatorStyle then
		self.newMessageAlertFrame:UpdateIndicatorStyle()
	end
end

function ScrollOverlayFrame:SetScript(name, callback)
	if name == "OnClickSnapFrame" then
		self.snapToBottomFrame:SetScript("OnMouseDown", callback)
		return
	end

	Frame_SetScript(self, name, callback)
end

function ScrollOverlayFrame:ShowNewMessageAlert()
	-- Don't show if edit box is focused
	if self.editBoxFocused then
		return
	end
	-- Unread messages: swap the passive "Bring me to the present" hint for the
	-- "Unread messages" alert (they share the same slot).
	if self.snapToPresentText then
		self.snapToPresentText:Hide()
	end
	self.newMessageAlertFrame:Show()
end

function ScrollOverlayFrame:HideNewMessageAlert()
	-- Hide the alert INSTANTLY (not its fade-out) so it can't remain visible on
	-- top of the "Bring me to the present" hint we show below -- otherwise both
	-- labels overlap while the alert fades, especially when scrolling up/down
	-- quickly.
	self.newMessageAlertFrame:QuickHide()
	-- Don't show the default hint if edit box is focused
	if self.editBoxFocused then
		return
	end
	-- Back to the default hint whenever the overlay is shown without unread.
	if self.snapToPresentText then
		self.snapToPresentText:Show()
	end
end

-- Override Show to respect hideScrollIndicator setting and edit box focus
function ScrollOverlayFrame:Show()
	if self.profile.hideScrollIndicator then
		return -- Don't show if indicator is disabled
	end
	if self.editBoxFocused then
		return -- Don't show if edit box is focused (it would overlap)
	end
	-- Call the FadingFrameMixin's Show implementation directly
	local FadingFrameMixin = Core.Components.FadingFrameMixin
	FadingFrameMixin.Show(self)
end

local function CreateScrollOverlayFrame(parent, profile)
	local FadingFrameMixin = Core.Components.FadingFrameMixin
	local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin

	local frame = CreateFrame("Frame", nil, parent)
	local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, ScrollOverlayFrame)

	object.profile = profile or Core.db.profile
	FadingFrameMixin.Init(object)
	GradientBackgroundMixin.Init(object)
	ScrollOverlayFrame.Init(object)

	return object
end

Core.Components.CreateScrollOverlayFrame = CreateScrollOverlayFrame
