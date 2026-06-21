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
      -- Ascension uses "|:" as a separator in some icon strings (e.g. :16|:16|:0:-4).
      -- Normalize by replacing "|:" with ":" before tokenizing.
      local normalized = string.gsub(params, "|:", ":")
      for token in string.gmatch(normalized, "[^:]+") do
        nums[#nums + 1] = tonumber(token)
      end
    end

    local h, w = nums[1], nums[2]
    local offsetX, offsetY = nums[3] or 0, nums[4] or 0
    -- Simple icon = path + up to height:width:offsetX:offsetY (no texcoords).
    -- h=0 or h=nil means "auto-size to font height" in WoW - treat as valid simple icon.
    -- Icons with more than 4 numeric params have texcoords and need special handling.
    if path ~= "" and #nums <= 4 then
      -- If h is 0, nil, or not set, use font-based default (roughly 16 for chat).
      local defaultSize = 16
      local actualH = (h and h > 0) and h or defaultSize
      local actualW = (w and w > 0) and w or actualH
      local n = math.max(1, math.floor(actualW / spaceW + 0.5))
      icons[#icons + 1] = { path = path, w = actualW, h = actualH, offsetX = offsetX, offsetY = offsetY, before = table.concat(out) }
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
  self:SetGradientBackground(50, rightBgWidth, Core.db.profile.chatBackgroundColor or Colors.codGray, Core.db.profile.chatBackgroundOpacity)

  if self.text == nil then
    self.text = self:CreateFontString(nil, "ARTWORK", "GlassMessageFont")
  end
  local leftPadding = Core.db.profile.messageLeftPadding or Constants.TEXT_XPADDING
  self.text:SetPoint("LEFT", leftPadding, 0)
  self.text:SetWidth(Core.db.profile.frameWidth - leftPadding - Constants.TEXT_XPADDING)
  self.text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)
  -- Allow a single very long run of non-space characters (e.g. spammed
  -- "AAAA...") to break across lines at the frame width. Without this WoW
  -- leaves the whole "word" on one overflowing line and reserves empty space.
  if self.text.SetNonSpaceWrap then
    self.text:SetNonSpaceWrap(true)
  end

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

        if key == "messageLeftPadding" then
          self:UpdateFrame()
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

  -- Always split icons so they fade properly. For multi-line messages,
  -- we'll calculate line positions in UpdateIcons.
  local displayText, icons = buildDisplayText(processed, fs)
  self.displayText = displayText
  self.iconList = (icons and #icons > 0) and icons or nil
  self.text:SetText(displayText)
end

---
-- Update height based on text height
function MessageLineMixin:UpdateFrame()
  -- Set the widths first so wrapped text reports its real (multi-line) height.
  local leftPadding = Core.db.profile.messageLeftPadding or Constants.TEXT_XPADDING
  self:SetWidth(Core.db.profile.frameWidth)
  self.text:ClearAllPoints()
  self.text:SetPoint("LEFT", leftPadding, 0)
  self.text:SetWidth(Core.db.profile.frameWidth - leftPadding - Constants.TEXT_XPADDING)
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
  self:SetGradientBackground(50, rightBgWidth, Core.db.profile.chatBackgroundColor or Colors.codGray, Core.db.profile.chatBackgroundOpacity)

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

  -- Get the wrap width and line height for multi-line positioning.
  local leftPadding = Core.db.profile.messageLeftPadding or Constants.TEXT_XPADDING
  local wrapWidth = Core.db.profile.frameWidth - leftPadding - Constants.TEXT_XPADDING
  fs:SetWidth(0)
  fs:SetText("Ay")
  local lineHeight = fs:GetStringHeight() or 12

  for i = 1, #icons do
    local icon = icons[i]
    local t = pool[i]
    if not t then
      -- Use ARTWORK layer (same as text) so icons are clipped with the line
      -- and don't bleed over messages below.
      t = self:CreateTexture(nil, "ARTWORK")
      pool[i] = t
    end

    local before = icon.before or ""

    -- Measure unwrapped width for x position calculation.
    fs:SetWidth(0)
    fs:SetText(before)
    local unwrappedWidth = fs:GetStringWidth() or 0

    -- Measure wrapped height to determine which visual line the icon is on.
    fs:SetWidth(wrapWidth)
    fs:SetText(before)
    local wrappedHeight = fs:GetStringHeight() or lineHeight
    local lineCount = math.max(1, math.floor(wrappedHeight / lineHeight + 0.5))

    -- X offset: approximate position on the last line.
    -- For single-line, this is just the unwrapped width.
    -- For multi-line, use modulo to estimate position on the last line.
    local x
    if lineCount == 1 then
      x = unwrappedWidth
    else
      x = unwrappedWidth % wrapWidth
      -- If the last line is nearly full, the icon might be at the start of next line.
      -- Add a small buffer for word-wrap variance.
      if x < 5 then x = 0 end
    end

    -- Y offset: position icon center at center of the correct line.
    -- From TOPLEFT, line N's center is at y = -lineHeight * (N - 0.5).
    local y = -lineHeight * (lineCount - 0.5)

    -- Scale the icon to fit within the line height if it's too large.
    -- This prevents icons from bleeding into adjacent messages.
    local iconW, iconH = icon.w, icon.h
    local wasScaled = false
    if iconH > lineHeight then
      local scale = lineHeight / iconH
      iconW = iconW * scale
      iconH = lineHeight
      wasScaled = true
    end

    -- Apply the icon's own offsets only if not scaled.
    -- When scaled, the icon is already centered properly within the line,
    -- and the original offsets (meant for full-size icons) would throw it off.
    local iconOffsetX = wasScaled and 0 or (icon.offsetX or 0)
    local iconOffsetY = wasScaled and 0 or (icon.offsetY or 0)

    t:SetTexture(icon.path)
    t:SetSize(iconW, iconH)
    t:ClearAllPoints()
    t:SetPoint("LEFT", self.text, "TOPLEFT", x + iconOffsetX, y + iconOffsetY)
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

  local textXPad = Core.db.profile.messageLeftPadding or Constants.TEXT_XPADDING
  local textWidth = Core.db.profile.frameWidth - textXPad - Constants.TEXT_XPADDING

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
  self:SetGradientBackground(50, rightBgWidth, Core.db.profile.chatBackgroundColor or Colors.codGray, Core.db.profile.chatBackgroundOpacity)
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
