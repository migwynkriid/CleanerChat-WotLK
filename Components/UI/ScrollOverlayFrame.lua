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

function ScrollOverlayFrame:Init()
	-- Keep the overlay just tall enough for the snap-to-bottom arrow and the
	-- "Unread messages" line.
	local overlayHeight = 28

	self:SetHeight(overlayHeight)
	self:ClearAllPoints()

	-- Position indicator at the edit box location (outside the chat frame)
	local mainContainer = self:GetParent():GetParent() -- SlidingMessageFrame's parent is MainContainerFrame
	if self.profile.editBoxAnchor.position == "ABOVE" then
		-- Edit box is above the chat, so indicator is above the main container
		self:SetPoint("BOTTOMLEFT", mainContainer, "TOPLEFT", 0, self.profile.editBoxAnchor.yOfs or 5)
		self:SetPoint("BOTTOMRIGHT", mainContainer, "TOPRIGHT", 0, self.profile.editBoxAnchor.yOfs or 5)
	else
		-- Edit box is below the chat (default), so indicator is below the main container
		self:SetPoint("TOPLEFT", mainContainer, "BOTTOMLEFT", 0, self.profile.editBoxAnchor.yOfs or -5)
		self:SetPoint("TOPRIGHT", mainContainer, "BOTTOMRIGHT", 0, self.profile.editBoxAnchor.yOfs or -5)
	end

	self:SetFadeInDuration(0.3)
	self:SetFadeOutDuration(0.15)

	-- Note: Mask textures are not available in WotLK 3.3.5
	-- We skip the mask functionality for this version

	-- Use customizable background color and opacity (defaults to codGray, fully solid)
	local bgColor = self.profile.scrollIndicatorBgColor or Colors.codGray
	local bgOpacity = self.profile.scrollIndicatorBgOpacity or 1
	self:SetGradientBackground(15, 15, bgColor, bgOpacity)

	-- Note: AddMaskTexture not available in WotLK 3.3.5

	-- Down arrow icon
	if self.icon == nil then
		self.icon = self:CreateTexture(nil, "ARTWORK")
	end
	self.icon:SetTexture("Interface\\AddOns\\CleanerChat\\Assets\\snapToBottomIcon")
	self.icon:SetWidth(16)
	self.icon:SetHeight(16)
	self.icon:SetPoint("BOTTOMLEFT", 15, 5)

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
	if self.profile.editBoxAnchor.position == "ABOVE" then
		-- Edit box is above the chat, so indicator is above the main container
		self:SetPoint("BOTTOMLEFT", mainContainer, "TOPLEFT", 0, self.profile.editBoxAnchor.yOfs or 5)
		self:SetPoint("BOTTOMRIGHT", mainContainer, "TOPRIGHT", 0, self.profile.editBoxAnchor.yOfs or 5)
	else
		-- Edit box is below the chat (default), so indicator is below the main container
		self:SetPoint("TOPLEFT", mainContainer, "BOTTOMLEFT", 0, self.profile.editBoxAnchor.yOfs or -5)
		self:SetPoint("TOPRIGHT", mainContainer, "BOTTOMRIGHT", 0, self.profile.editBoxAnchor.yOfs or -5)
	end
end

function ScrollOverlayFrame:UpdateIndicatorStyle()
	local indicatorColor = self.profile.scrollIndicatorColor or Colors.apache
	local indicatorOpacity = self.profile.scrollIndicatorOpacity or 1
	if self.snapToPresentText then
		self.snapToPresentText:SetTextColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, indicatorOpacity)
	end
	-- Update background
	local bgColor = self.profile.scrollIndicatorBgColor or Colors.codGray
	local bgOpacity = self.profile.scrollIndicatorBgOpacity or 1
	self:SetGradientBackground(15, 15, bgColor, bgOpacity)
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
	-- Unread messages: swap the passive "Bring me to the present" hint for the
	-- "Unread messages" alert (they share the same slot).
	if self.snapToPresentText then
		self.snapToPresentText:Hide()
	end
	self.newMessageAlertFrame:Show()
end

function ScrollOverlayFrame:HideNewMessageAlert()
	self.newMessageAlertFrame:Hide()
	-- Back to the default hint whenever the overlay is shown without unread.
	if self.snapToPresentText then
		self.snapToPresentText:Show()
	end
end

-- Override Show to respect hideScrollIndicator setting
function ScrollOverlayFrame:Show()
	if self.profile.hideScrollIndicator then
		return -- Don't show if indicator is disabled
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
