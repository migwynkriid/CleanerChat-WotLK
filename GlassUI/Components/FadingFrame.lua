local Core, _, Utils = unpack(select(2, ...))

-- luacheck: push ignore 113
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local Mixin = Mixin
-- luacheck: pop

local FadingFrameMixin = {}

-- Helper function to safely set animation alpha
local function SafeSetAlphaAnimation(anim, fromAlpha, toAlpha)
  -- Store the target values for reference
  anim._fromAlpha = fromAlpha
  anim._toAlpha = toAlpha
  
  -- Try modern API first (SetFromAlpha/SetToAlpha)
  if anim.SetFromAlpha and anim.SetToAlpha then
    anim:SetFromAlpha(fromAlpha)
    anim:SetToAlpha(toAlpha)
  -- Fall back to WotLK API (SetChange)
  elseif anim.SetChange then
    anim:SetChange(toAlpha - fromAlpha)
  end
  
  -- Try to set smoothing if available
  if anim.SetSmoothing then
    anim:SetSmoothing("OUT")
  end
end

-- Store original Frame methods (WotLK compatibility)
local FramePrototype = getmetatable(CreateFrame("Frame")).__index
local Frame_Show = FramePrototype.Show
local Frame_Hide = FramePrototype.Hide

function FadingFrameMixin:Init()
  if self.showAg == nil then
    self.showAg = self:CreateAnimationGroup()
    self.fadeIn = self.showAg:CreateAnimation("Alpha")
    SafeSetAlphaAnimation(self.fadeIn, 0, 1)
    self.fadeIn:SetDuration(0)
    
    -- In WotLK, we need to set alpha to 1 after fade-in completes
    self.showAg:SetScript("OnFinished", function()
      self:SetAlpha(1)
    end)
  end

  if self.hideAg == nil then
    self.hideAg = self:CreateAnimationGroup()
    self.fadeOut = self.hideAg:CreateAnimation("Alpha")
    SafeSetAlphaAnimation(self.fadeOut, 1, 0)
    self.fadeOut:SetDuration(0)

    self.hideAg:SetScript("OnFinished", function ()
      self:SetAlpha(1)  -- Reset alpha before hiding
      self:QuickHide()
    end)
  end
end

function FadingFrameMixin:QuickShow()
  self:StopAnimating()

  if self.hideTimer ~= nil then
    self.hideTimer:Cancel()
  end

  self:SetAlpha(1)
  Frame_Show(self)
end

function FadingFrameMixin:QuickHide()
  if self.hideTimer ~= nil then
    self.hideTimer:Cancel()
  end

  self:SetAlpha(1)
  Frame_Hide(self)
end

function FadingFrameMixin:Show()
  -- Cancel any pending hide operations
  if self.hideTimer ~= nil then
    self.hideTimer:Cancel()
    self.hideTimer = nil
  end

  if not self:IsVisible() then
    self:StopAnimating()
    self:SetAlpha(1)  -- Ensure visible
    Frame_Show(self)
    -- Skip fade-in animation - just show immediately for stability in WotLK
  end
end

function FadingFrameMixin:Hide()
  if self.hideTimer ~= nil then
    self.hideTimer:Cancel()
    self.hideTimer = nil
  end

  if self:IsVisible() then
    -- Just hide immediately - skip fade animation for WotLK stability
    self:SetAlpha(1)
    Frame_Hide(self)
  end
end

function FadingFrameMixin:HideDelay(delay)
  -- Ensure valid delay
  delay = delay or 10
  if delay < 1 then
    delay = 10  -- Default to 10 seconds
  end

  if self:IsVisible() then
    if self.hideTimer ~= nil then
      self.hideTimer:Cancel()
    end

    self.hideTimer = C_Timer.NewTimer(delay, function ()
      self:Hide()
    end)
  end
end

function FadingFrameMixin:SetFadeInDuration(duration)
  self.fadeIn:SetDuration(duration)
end

function FadingFrameMixin:SetFadeOutDuration(duration)
  self.fadeOut:SetDuration(duration)
end

local function CreateFadingFrame(frameType, name, parent)
  local frame = CreateFrame(frameType, name, parent)
  local object = Mixin(frame, FadingFrameMixin)
  object:Init()
  return object
end

Core.Components.CreateFadingFrame = CreateFadingFrame
Core.Components.FadingFrameMixin = FadingFrameMixin
