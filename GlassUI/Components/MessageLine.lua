local Core, Constants = unpack(select(2, ...))

local Colors = Constants.COLORS

local HyperlinkClick = Constants.ACTIONS.HyperlinkClick
local HyperlinkEnter = Constants.ACTIONS.HyperlinkEnter
local HyperlinkLeave = Constants.ACTIONS.HyperlinkLeave

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local CreateObjectPool = CreateObjectPool
local Mixin = Mixin
-- luacheck: pop

-- WotLK compatibility: GetLineHeight may not exist on FontStrings
local function GetFontHeight(fontString)
  if fontString.GetLineHeight then
    local height = fontString:GetLineHeight()
    if height and height > 0 then
      return height
    end
  end
  -- Try GetFont to get the font size
  if fontString.GetFont then
    local _, fontHeight = fontString:GetFont()
    if fontHeight and fontHeight > 0 then
      return fontHeight
    end
  end
  -- Fallback to GetStringHeight
  if fontString.GetStringHeight then
    local height = fontString:GetStringHeight()
    if height and height > 0 then
      return height
    end
  end
  return 14  -- reasonable default
end

local MessageLineMixin = {}

function MessageLineMixin:Init()
  self:SetWidth(Core.db.profile.frameWidth)
  self:SetFadeInDuration(Core.db.profile.chatFadeInDuration)
  self:SetFadeOutDuration(Core.db.profile.chatFadeOutDuration)

  local rightBgWidth = math.min(250, Core.db.profile.frameWidth - 50)
  self:SetGradientBackground(50, rightBgWidth, Colors.codGray, Core.db.profile.chatBackgroundOpacity)

  if self.text == nil then
    self.text = self:CreateFontString(nil, "ARTWORK", "GlassMessageFont")
  end
  self.text:SetPoint("LEFT", Constants.TEXT_XPADDING, 0)
  self.text:SetWidth(Core.db.profile.frameWidth - Constants.TEXT_XPADDING * 2)
  self.text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)

  -- Hyperlink handling
  -- Note: In WotLK 3.3.5, plain Frame objects don't support hyperlink scripts
  -- Only SimpleHTML and MessageFrame types support OnHyperlinkClick/Enter/Leave
  -- We use pcall to safely attempt setting these scripts
  if self.SetHyperlinksEnabled then
    pcall(function() self:SetHyperlinksEnabled(true) end)
  end

  -- Try to set hyperlink scripts (will fail silently on WotLK for plain Frames)
  if self:HasScript("OnHyperlinkClick") then
    self:SetScript("OnHyperlinkClick", function (_, link, text, button)
      Core:Dispatch(HyperlinkClick({link, text, button}))
    end)
  end

  if self:HasScript("OnHyperlinkEnter") then
    self:SetScript("OnHyperlinkEnter", function (_, link, text)
      if Core.db.profile.mouseOverTooltips then
        Core:Dispatch(HyperlinkEnter({link, text}))
      end
    end)
  end

  if self:HasScript("OnHyperlinkLeave") then
    self:SetScript("OnHyperlinkLeave", function (_, link)
      Core:Dispatch(HyperlinkLeave(link))
    end)
  end

  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if key == "chatFadeInDuration" then
          self:SetFadeInDuration(Core.db.profile.chatFadeInDuration)
        end

        if key == "chatFadeOutDuration" then
          self:SetFadeOutDuration(Core.db.profile.chatFadeOutDuration)
        end
      end)
    }
  end
end

---
-- Update height based on text height
function MessageLineMixin:UpdateFrame()
  local Ypadding = GetFontHeight(self.text) * Core.db.profile.messageLinePadding
  local messageLineHeight = (self.text:GetStringHeight() + Ypadding * 2)
  self:SetHeight(messageLineHeight)

  self:SetWidth(Core.db.profile.frameWidth)
  self.text:SetWidth(Core.db.profile.frameWidth - Constants.TEXT_XPADDING * 2)
  self.text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)

  local rightBgWidth = math.min(250, Core.db.profile.frameWidth - 50)
  self:SetGradientBackground(50, rightBgWidth, Colors.codGray, Core.db.profile.chatBackgroundOpacity)
end

---
-- Update texture color based on setting
function MessageLineMixin:UpdateTextures()
  local rightBgWidth = math.min(250, Core.db.profile.frameWidth - 50)
  self:SetGradientBackground(50, rightBgWidth, Colors.codGray, Core.db.profile.chatBackgroundOpacity)
end

local function CreateMessageLine(parent)
  local FadingFrameMixin = Core.Components.FadingFrameMixin
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin

  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, MessageLineMixin)

  FadingFrameMixin.Init(object)
  GradientBackgroundMixin.Init(object)
  MessageLineMixin.Init(object)

  return object
end

local function CreateMessageLinePool(parent)
  return CreateObjectPool(
    function () return CreateMessageLine(parent) end,
    function (_, message)
      -- Reset all animations and timers
      message:QuickHide()
    end
  )
end

Core.Components.CreateMessageLine = CreateMessageLine
Core.Components.CreateMessageLinePool = CreateMessageLinePool
