local Core, Constants, Utils = unpack(select(2, ...))

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
    -- Fully solid background so the chat behind doesn't bleed through and the
    -- gold label reads as solid (was 0.65, which looked transparent).
    local overlayOpacity = 1
    -- Keep the overlay just tall enough for the snap-to-bottom arrow and the
    -- "Unread messages" line. The "-2" keeps its bottom edge anchored in the
    -- same place as the frame height changes (height - 2).
    local overlayHeight = 28
    local topOffset = Core.db.profile.frameHeight - (Constants.DOCK_HEIGHT + 5 + (overlayHeight - 2))

    self:SetHeight(overlayHeight)
    self:SetPoint("TOPLEFT", 0, -topOffset)
    self:SetPoint("TOPRIGHT", 0, -topOffset)
    self:SetFadeInDuration(0.3)
    self:SetFadeOutDuration(0.15)

    -- Note: Mask textures are not available in WotLK 3.3.5
    -- We skip the mask functionality for this version

    self:SetGradientBackground(15, 15, Core.db.profile.chatBackgroundColor or Colors.codGray, overlayOpacity)

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
      self.newMessageAlertFrame = CreateNewMessageAlertFrame(self)
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
    -- Same apache colour as the "Unread messages" text, fully solid.
    self.snapToPresentText:SetTextColor(Colors.apache.r, Colors.apache.g, Colors.apache.b)
    self.snapToPresentText:SetPoint("BOTTOMLEFT", 30, 10)
    self.snapToPresentText:SetText("Bring me to the present")
    self.snapToPresentText:Show()
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

local function CreateScrollOverlayFrame(parent)
  local FadingFrameMixin = Core.Components.FadingFrameMixin
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin

  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, ScrollOverlayFrame)

  FadingFrameMixin.Init(object)
  GradientBackgroundMixin.Init(object)
  ScrollOverlayFrame.Init(object)

  return object
end

Core.Components.CreateScrollOverlayFrame = CreateScrollOverlayFrame
