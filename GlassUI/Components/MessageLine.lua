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

-- A single shared, hidden FontString used to measure rendered text widths and
-- heights, so we can position the clickable hyperlink overlays. Created lazily.
local measureFontString
local function getMeasureFontString()
  if not measureFontString then
    measureFontString = UIParent:CreateFontString(nil, "ARTWORK")
    measureFontString:Hide()
  end
  return measureFontString
end

-- Split simple embedded |T...|t icons (coins, currency, etc.) out of a single
-- line of text so they can be FADED. Embedded FontString textures ignore alpha
-- on 3.3.5 -- only the text fades, the icon stays fully opaque and then pops
-- out when the line is finally hidden. We replace each simple icon with a run
-- of spaces of roughly the same width (so the surrounding text keeps its
-- layout) and return a list of the icons + the text that precedes each, so
-- UpdateIcons can draw the real icon as a separate Texture overlay that DOES
-- fade with the line. Icons that carry texture coordinates (class icons,
-- sprite-sheet icons) are left embedded untouched -- redrawing them without
-- their texcoords would show the wrong art, and they're rarely what fades.
-- `fs` must already have the line's font set.
local function buildDisplayText(text, fs)
  fs:SetWidth(0)
  fs:SetText(" ")
  local spaceW = fs:GetStringWidth() or 0
  if spaceW <= 0 then spaceW = 3 end

  local out, icons = {}, {}
  local pos = 1
  while true do
    local s, e, inner = string.find(text, "|T(.-)|t", pos)
    if not s then
      out[#out + 1] = string.sub(text, pos)
      break
    end
    out[#out + 1] = string.sub(text, pos, s - 1)

    local path = inner
    local params = nil
    local colon = string.find(inner, ":", 1, true)
    if colon then
      path = string.sub(inner, 1, colon - 1)
      params = string.sub(inner, colon + 1)
    end

    local nums = {}
    if params then
      for token in string.gmatch(params, "[^:]+") do
        nums[#nums + 1] = tonumber(token)
      end
    end

    local h, w = nums[1], nums[2]
    -- Simple icon = path + up to height:width:offsetX:offsetY (no texcoords).
    if path ~= "" and h and h > 0 and #nums <= 4 then
      w = (w and w > 0) and w or h
      local n = math.max(1, math.floor(w / spaceW + 0.5))
      icons[#icons + 1] = { path = path, w = w, h = h, before = table.concat(out) }
      out[#out + 1] = string.rep(" ", n)
    else
      -- Keep the original icon embedded (correct art, just won't fade).
      out[#out + 1] = string.sub(text, s, e)
    end
    pos = e + 1
  end

  return table.concat(out), icons
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

  -- Hyperlink handling.
  -- WotLK 3.3.5 only fires OnHyperlinkClick/Enter/Leave on ScrollingMessageFrame
  -- and SimpleHTML -- NOT on the plain Frame we render each message into, so
  -- those scripts never trigger here (verified: links stay dead even with the
  -- frame mouse-enabled). Instead we overlay a small transparent Button on top
  -- of each |H...|h link in UpdateHyperlinks(), which works on any client. The
  -- line itself stays mouse-transparent so non-link chat still clicks through.
  self.linkButtons = self.linkButtons or {}
  self.iconTextures = self.iconTextures or {}

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
-- Set the message text, splitting fadeable icons out for single-line messages.
function MessageLineMixin:SetMessageText(processed)
  self.processedText = processed

  if not processed or not string.find(processed, "|T", 1, true) then
    -- No icons: nothing to split.
    self.displayText = processed
    self.iconList = nil
    self.text:SetText(processed or "")
    return
  end

  local fs = getMeasureFontString()
  local fontPath, fontSize, fontFlags = self.text:GetFont()
  if fontPath then
    fs:SetFont(fontPath, fontSize, fontFlags)
  end

  -- Only split icons for single-line messages -- positioning overlays across
  -- wrapped lines isn't reliable, so wrapped messages keep their embedded icons
  -- (unchanged behaviour).
  local textWidth = Core.db.profile.frameWidth - Constants.TEXT_XPADDING * 2
  fs:SetWidth(0)
  fs:SetText(processed)
  if (fs:GetStringWidth() or 0) > textWidth then
    self.displayText = processed
    self.iconList = nil
    self.text:SetText(processed)
    return
  end

  local displayText, icons = buildDisplayText(processed, fs)
  self.displayText = displayText
  self.iconList = (icons and #icons > 0) and icons or nil
  self.text:SetText(displayText)
end

---
-- Update height based on text height
function MessageLineMixin:UpdateFrame()
  -- Set the widths first so wrapped text reports its real (multi-line) height.
  self:SetWidth(Core.db.profile.frameWidth)
  self.text:SetWidth(Core.db.profile.frameWidth - Constants.TEXT_XPADDING * 2)
  self.text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)

  -- WotLK quirk: GetStringHeight() can return 0 / a too-small value (especially
  -- right after SetText), which collapses the frame and makes messages overlap.
  -- Never let a line be shorter than a single text line.
  local lineHeight = GetFontHeight(self.text)
  local stringHeight = self.text:GetStringHeight() or 0
  if stringHeight < lineHeight then
    stringHeight = lineHeight
  end

  local Ypadding = lineHeight * Core.db.profile.messageLinePadding
  self:SetHeight(stringHeight + Ypadding * 2)

  local rightBgWidth = math.min(250, Core.db.profile.frameWidth - 50)
  self:SetGradientBackground(50, rightBgWidth, Colors.codGray, Core.db.profile.chatBackgroundOpacity)

  -- Reposition the faded icon overlays, then the clickable hyperlink overlays.
  self:UpdateIcons()
  self:UpdateHyperlinks()
end

---
-- Draw each split-out simple icon (see buildDisplayText) as a real Texture
-- parented to the line, positioned over the spaces that reserve its slot.
-- Unlike an embedded FontString icon, a Texture fades with the line's alpha,
-- so the icon now fades out with the text instead of popping.
function MessageLineMixin:UpdateIcons()
  local pool = self.iconTextures
  if not pool then
    pool = {}
    self.iconTextures = pool
  end

  for i = 1, #pool do
    pool[i]:Hide()
  end

  local icons = self.iconList
  if not icons or #icons == 0 then
    return
  end

  local fs = getMeasureFontString()
  local fontPath, fontSize, fontFlags = self.text:GetFont()
  if fontPath then
    fs:SetFont(fontPath, fontSize, fontFlags)
  end
  fs:SetWidth(0)

  for i = 1, #icons do
    local icon = icons[i]
    local t = pool[i]
    if not t then
      t = self:CreateTexture(nil, "OVERLAY")
      pool[i] = t
    end

    fs:SetText(icon.before or "")
    local x = fs:GetStringWidth() or 0

    t:SetTexture(icon.path)
    t:SetSize(icon.w, icon.h)
    t:ClearAllPoints()
    t:SetPoint("LEFT", self.text, "LEFT", x, 0)
    t:Show()
  end
end

---
-- Overlay a small, transparent, clickable Button on top of each |H...|h
-- hyperlink in the line. Plain Frames don't fire OnHyperlink* scripts on 3.3.5,
-- so this is how links become clickable. We measure text widths with a shared
-- FontString to place each overlay. Single-line messages (the common case for
-- item links) get pixel-accurate overlays; wrapped messages fall back to a
-- full-width band over the line(s) the link spans.
function MessageLineMixin:UpdateHyperlinks()
  local buttons = self.linkButtons
  if not buttons then
    buttons = {}
    self.linkButtons = buttons
  end

  -- Hide overlays from the previous layout; we re-show the ones still needed.
  for i = 1, #buttons do
    buttons[i]:Hide()
  end

  local text = self.displayText or self.processedText
  if not text or not string.find(text, "|H", 1, true) then
    return
  end

  local textXPad = Constants.TEXT_XPADDING
  local textWidth = Core.db.profile.frameWidth - textXPad * 2

  local fs = getMeasureFontString()
  local fontPath, fontSize, fontFlags = self.text:GetFont()
  if fontPath then
    fs:SetFont(fontPath, fontSize, fontFlags)
  end

  -- Height of a single line (includes the font's internal leading).
  fs:SetWidth(0)
  fs:SetText("Ay")
  local oneLineH = fs:GetStringHeight()
  if not oneLineH or oneLineH <= 0 then
    oneLineH = GetFontHeight(self.text)
  end

  -- Does the whole message fit on one line?
  fs:SetWidth(0)
  fs:SetText(text)
  local singleLine = (fs:GetStringWidth() or 0) <= textWidth

  local count = 0
  local pos = 1
  while true do
    local s, e, link, linkText = string.find(text, "|H(.-)|h(.-)|h", pos)
    if not s then break end
    pos = e + 1
    count = count + 1

    local btn = buttons[count]
    if not btn then
      btn = CreateFrame("Button", nil, self)
      btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      btn:SetScript("OnClick", function (b, mouseButton)
        if b._link then Core:Dispatch(HyperlinkClick({b._link, b._text, mouseButton})) end
      end)
      btn:SetScript("OnEnter", function (b)
        if b._link and Core.db.profile.mouseOverTooltips then
          Core:Dispatch(HyperlinkEnter({b._link, b._text}))
        end
      end)
      btn:SetScript("OnLeave", function (b)
        if b._link then Core:Dispatch(HyperlinkLeave(b._link)) end
      end)
      buttons[count] = btn
    end

    btn._link = link
    btn._text = linkText
    btn:ClearAllPoints()

    local prefix = string.sub(text, 1, s - 1)

    if singleLine then
      fs:SetWidth(0)
      fs:SetText(prefix)
      local px = fs:GetStringWidth() or 0
      fs:SetText(linkText)
      local lw = fs:GetStringWidth() or 0
      btn:SetPoint("TOPLEFT", self.text, "TOPLEFT", px, 0)
      btn:SetSize(math.max(4, lw), oneLineH)
    else
      fs:SetWidth(textWidth)
      fs:SetText(prefix == "" and "" or prefix)
      local startLine = 0
      if prefix ~= "" then
        startLine = math.max(0, math.floor((fs:GetStringHeight() or 0) / oneLineH + 0.5) - 1)
      end
      fs:SetText(string.sub(text, 1, e))
      local endLine = math.max(startLine, math.floor((fs:GetStringHeight() or 0) / oneLineH + 0.5) - 1)
      btn:SetPoint("TOPLEFT", self.text, "TOPLEFT", 0, -startLine * oneLineH)
      btn:SetSize(textWidth, oneLineH * (endLine - startLine + 1))
    end

    btn:Show()
  end
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
