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
    local overlayOpacity = 0.65
    local topOffset = Core.db.profile.frameHeight - (Constants.DOCK_HEIGHT + 5 + 62)

    self:SetHeight(64)
    self:SetPoint("TOPLEFT", 0, -topOffset)
    self:SetPoint("TOPRIGHT", 0, -topOffset)
    self:SetFadeInDuration(0.3)
    self:SetFadeOutDuration(0.15)

    -- Note: Mask textures are not available in WotLK 3.3.5
    -- We skip the mask functionality for this version

    self:SetGradientBackground(15, 15, Colors.codGray, overlayOpacity)

    -- Note: AddMaskTexture not available in WotLK 3.3.5

    -- Down arrow icon
    if self.icon == nil then
      self.icon = self:CreateTexture(nil, "ARTWORK")
    end
    self.icon:SetTexture("Interface\\AddOns\\CleanerChat\\GlassUI\\Assets\\snapToBottomIcon")
    self.icon:SetWidth(16)
    self.icon:SetHeight(16)
    self.icon:SetPoint("BOTTOMLEFT", 15, 5)

    -- See new messages click area
    if self.snapToBottomFrame == nil then
      self.snapToBottomFrame = CreateFrame("Frame", nil, self)
    end
    self.snapToBottomFrame:SetHeight(20)
    self.snapToBottomFrame:SetPoint("BOTTOMLEFT")
    self.snapToBottomFrame:SetPoint("BOTTOMRIGHT")

    if self.newMessageAlertFrame == nil then
      self.newMessageAlertFrame = CreateNewMessageAlertFrame(self)
    end

    self.newMessageAlertFrame:QuickHide()
end

function ScrollOverlayFrame:SetScript(name, callback)
  if name == "OnClickSnapFrame" then
    self.snapToBottomFrame:SetScript("OnMouseDown", callback)
    return
  end

  Frame_SetScript(self, name, callback)
end

function ScrollOverlayFrame:ShowNewMessageAlert()
  self.newMessageAlertFrame:Show()
end

function ScrollOverlayFrame:HideNewMessageAlert()
  self.newMessageAlertFrame:Hide()
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
