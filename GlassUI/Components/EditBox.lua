local Core, Constants = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook

local Colors = Constants.COLORS

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local Mixin = Mixin
-- luacheck: pop

local EditBoxMixin = {}

function EditBoxMixin:Init(parent)
  -- Hide default styling
  _G[self:GetName().."Left"]:Hide()
  _G[self:GetName().."Mid"]:Hide()
  _G[self:GetName().."Right"]:Hide()

  self:RawHook(_G[self:GetName().."Left"], "Show", function () end, true)
  self:RawHook(_G[self:GetName().."Mid"], "Show", function () end, true)
  self:RawHook(_G[self:GetName().."Right"], "Show", function () end, true)

  -- Note: Focus textures don't exist in WotLK 3.3.5, so we skip them

  -- New styling
  self:ClearAllPoints()

  self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 8, Core.db.profile.editBoxAnchor.yOfs)

  if Core.db.profile.editBoxAnchor.position == "ABOVE" then
    self:ClearAllPoints()
    self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 8, Core.db.profile.editBoxAnchor.yOfs)
  end

  self:SetFontObject("GlassEditBoxFont")
  self:SetWidth(Core.db.profile.frameWidth - 8 * 2)
  self.header:SetFontObject("GlassEditBoxFont")
  self.header:SetPoint("LEFT", 8, 0)

  local bg = self:CreateTexture(nil, "BACKGROUND")
  bg:SetColorTexture(
    Colors.codGray.r, Colors.codGray.g, Colors.codGray.b, Core.db.profile.editBoxBackgroundOpacity
  )
  bg:SetAllPoints()

  -- WotLK compatibility: GetLineHeight may not exist, use GetStringHeight or fallback
  local function GetFontHeight(fontString)
    if fontString.GetLineHeight then
      return fontString:GetLineHeight()
    elseif fontString.GetStringHeight then
      local height = fontString:GetStringHeight()
      return height > 0 and height or 14
    else
      return 14 -- fallback
    end
  end

  local Ypadding = GetFontHeight(self.header) * 0.66
  self:SetHeight(GetFontHeight(self.header) + Ypadding * 2)

  self:RawHook(self, "SetTextInsets", function ()
    Ypadding = GetFontHeight(self.header) * 0.66
    self.hooks[self].SetTextInsets(
      self,
      self.header:GetStringWidth() + 8,
      8, Ypadding, Ypadding
    )
  end, true)

  self:SetTextInsets()

  -- Helper function to safely set animation alpha
  local function SafeSetAlphaAnimation(anim, fromAlpha, toAlpha)
    if anim.SetFromAlpha and anim.SetToAlpha then
      anim:SetFromAlpha(fromAlpha)
      anim:SetToAlpha(toAlpha)
    elseif anim.SetChange then
      anim:SetChange(toAlpha - fromAlpha)
    end
    if anim.SetSmoothing then
      anim:SetSmoothing("OUT")
    end
  end

  -- Animations
  -- Intro animations
  local introAg = self:CreateAnimationGroup()
  local fadeIn = introAg:CreateAnimation("Alpha")
  SafeSetAlphaAnimation(fadeIn, 0, 1)
  fadeIn:SetDuration(0.2)
  
  -- Ensure alpha is 1 after fade-in completes
  introAg:SetScript("OnFinished", function()
    self:SetAlpha(1)
  end)

  -- Outro animations
  local outroAg = self:CreateAnimationGroup()
  local fadeOut = outroAg:CreateAnimation("Alpha")
  SafeSetAlphaAnimation(fadeOut, 1, 0)
  fadeOut:SetDuration(0.05)

  -- Workaround for editbox being open on login
  self.glassInitialized = false

  self:SetScript("OnShow", function ()
    if self.glassInitialized then
      -- Set alpha to 0 before fade-in so SetChange(1) works in WotLK
      self:SetAlpha(0)
      introAg:Play()
    else
      self.glassInitialized = true
      self:SetAlpha(1)
    end
  end)

  outroAg:SetScript("OnFinished", function ()
    if not introAg:IsPlaying() then
      self:SetAlpha(1)  -- Reset alpha before hiding
      self.hooks[self].Hide(self)
    end
  end)

  self:RawHook(self, "Hide", function ()
    -- Set alpha to 1 before fade-out so SetChange(-1) works in WotLK
    self:SetAlpha(1)
    outroAg:Play()
  end, true)

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "font" or key == "editBoxFontSize" then
      Ypadding = GetFontHeight(self.header) * 0.66
      self:SetHeight(GetFontHeight(self.header) + Ypadding * 2)
      self:SetTextInsets()
    end

    if key == "frameWidth" then
      self:SetWidth(Core.db.profile.frameWidth - 8 * 2)
    end

    if key == "editBoxBackgroundOpacity" then
      bg:SetColorTexture(
        Colors.codGray.r, Colors.codGray.g, Colors.codGray.b, Core.db.profile.editBoxBackgroundOpacity
      )
    end

    if key == "editBoxAnchor" then
      if Core.db.profile.editBoxAnchor.position == "ABOVE" then
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 8, Core.db.profile.editBoxAnchor.yOfs)
      else
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 8, Core.db.profile.editBoxAnchor.yOfs)
      end
    end
  end)
end

Core.Components.CreateEditBox = function (parent)
  local object = Mixin(_G.ChatFrame1EditBox, EditBoxMixin)
  AceHook:Embed(object)
  object:Init(parent)
  return object
end
