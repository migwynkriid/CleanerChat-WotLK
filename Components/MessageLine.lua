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
    -- Parse texcoords if present: texWidth, texHeight, left, right, top, bottom
    local texWidth, texHeight = nums[5], nums[6]
    local texLeft, texRight, texTop, texBottom = nums[7], nums[8], nums[9], nums[10]
    -- Simple icon = path + up to height:width:offsetX:offsetY (no texcoords).
    -- h=0 or h=nil means "auto-size to font height" in WoW - treat as valid simple icon.
    -- Icons with more than 4 numeric params have texcoords - we now support those too.
    if path ~= "" then
      -- If h is 0, nil, or not set, use font-based default (roughly 16 for chat).
      local defaultSize = 16
      local actualH = (h and h > 0) and h or defaultSize
      local actualW = (w and w > 0) and w or actualH
      local n = math.max(1, math.floor(actualW / spaceW + 0.5))
      -- Store texcoords if present (convert from pixels to normalized 0-1)
      local texCoords = nil
      if texWidth and texHeight and texLeft and texRight and texTop and texBottom then
        texCoords = {
          left = texLeft / texWidth,
          right = texRight / texWidth,
          top = texTop / texHeight,
          bottom = texBottom / texHeight
        }
      end
      icons[#icons + 1] = { path = path, w = actualW, h = actualH, offsetX = offsetX, offsetY = offsetY, texCoords = texCoords, before = table.concat(out) }
      out[#out + 1] = string.rep(" ", n)
    else
      -- Keep the original icon embedded (empty path).
      out[#out + 1] = string.sub(text, s, e)
    end
    pos = e + 1
  end

  return table.concat(out), icons
end

local MessageLineMixin = {}

local LSM = Core.Libs.LSM

function MessageLineMixin:Init()
  self:SetWidth(self.profile.frameWidth)
  local animate = self.profile.messageAnimations ~= false
  self:SetFadeInDuration(animate and self.profile.chatFadeInDuration or 0)
  self:SetFadeOutDuration(animate and self.profile.chatFadeOutDuration or 0)

  local rightBgWidth = math.min(250, self.profile.frameWidth - 50)
  self:SetGradientBackground(50, rightBgWidth, self.profile.chatBackgroundColor or Colors.codGray, self.profile.chatBackgroundOpacity)

  if self.text == nil then
    self.text = self:CreateFontString(nil, "ARTWORK", "GlassMessageFont")
  end
  -- Apply font settings from window's profile directly (not global FontObject)
  self:UpdateFontFromProfile()
  local leftPadding = self.profile.messageLeftPadding or Constants.TEXT_XPADDING
  self.text:SetPoint("LEFT", leftPadding, 0)
  self.text:SetWidth(self.profile.frameWidth - leftPadding - Constants.TEXT_XPADDING)
  self.text:SetIndentedWordWrap(self.profile.indentWordWrap)
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
      Core:Subscribe(UPDATE_CONFIG, function (payload)
        local key = Core:ResolveConfigKey(payload, (self.smf and self.smf.window and self.smf.window.id) or "Main")
        
        if key == nil then return end
        
        if key == "chatFadeInDuration" or key == "messageAnimations" then
          local shouldAnimate = self.profile.messageAnimations ~= false
          self:SetFadeInDuration(shouldAnimate and self.profile.chatFadeInDuration or 0)
        end

        if key == "chatFadeOutDuration" or key == "messageAnimations" then
          local shouldAnimate = self.profile.messageAnimations ~= false
          self:SetFadeOutDuration(shouldAnimate and self.profile.chatFadeOutDuration or 0)
        end

        if key == "messageLeftPadding" then
          self:UpdateFrame()
        end
        
        -- Update font when font settings change for this window
        if key == "messageFont" or key == "messageFontSize" or key == "messageFontFlags" or key == "messageLeading" then
          self:UpdateFontFromProfile()
        end
      end)
    }
  end
end

---
-- Apply font settings from the window's profile directly to the FontString.
-- This allows each window to have independent font settings.
function MessageLineMixin:UpdateFontFromProfile()
  local fontPath = LSM:Fetch(LSM.MediaType.FONT, self.profile.messageFont)
  local fontSize = self.profile.messageFontSize
  local fontFlags = self.profile.messageFontFlags
  local leading = self.profile.messageLeading
  
  if fontPath and fontSize then
    self.text:SetFont(fontPath, fontSize, fontFlags or "")
    self.text:SetSpacing(leading or 0)
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
  local leftPadding = self.profile.messageLeftPadding or Constants.TEXT_XPADDING
  self:SetWidth(self.profile.frameWidth)
  self.text:ClearAllPoints()
  self.text:SetPoint("LEFT", leftPadding, 0)
  self.text:SetWidth(self.profile.frameWidth - leftPadding - Constants.TEXT_XPADDING)
  self.text:SetIndentedWordWrap(self.profile.indentWordWrap)

  -- WotLK quirk: GetStringHeight() can return 0 / a too-small value (especially
  -- right after SetText), which collapses the frame and makes messages overlap.
  -- Never let a line be shorter than a single text line.
  local lineHeight = GetFontHeight(self.text)
  local stringHeight = self.text:GetStringHeight() or 0
  if stringHeight < lineHeight then
    stringHeight = lineHeight
  end

  local Ypadding = lineHeight * self.profile.messageLinePadding
  self:SetHeight(stringHeight + Ypadding * 2)

  local rightBgWidth = math.min(250, self.profile.frameWidth - 50)
  self:SetGradientBackground(50, rightBgWidth, self.profile.chatBackgroundColor or Colors.codGray, self.profile.chatBackgroundOpacity)

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
  local leftPadding = self.profile.messageLeftPadding or Constants.TEXT_XPADDING
  local wrapWidth = self.profile.frameWidth - leftPadding - Constants.TEXT_XPADDING
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
    -- Apply texcoords if present (for atlas textures like coins.tga)
    if icon.texCoords then
      t:SetTexCoord(icon.texCoords.left, icon.texCoords.right, icon.texCoords.top, icon.texCoords.bottom)
    else
      t:SetTexCoord(0, 1, 0, 1) -- Reset to full texture
    end
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
-- FontString to place each overlay.

-- Strip hyperlink markup for width measurement. The |H...|h markers are not
-- displayed, so we need to remove them to get accurate text widths.
local function stripHyperlinks(str)
  -- Replace |H...|h(visible)|h with just the visible text
  return (string.gsub(str, "|H.-|h(.-)|h", "%1"))
end

-- Strip color codes for width measurement
local function stripColors(str)
  local s = string.gsub(str, "|c%x%x%x%x%x%x%x%x", "")
  return (string.gsub(s, "|r", ""))
end

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

  local textXPad = self.profile.messageLeftPadding or Constants.TEXT_XPADDING
  local textWidth = self.profile.frameWidth - textXPad - Constants.TEXT_XPADDING

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
        if b._link and self.profile.mouseOverTooltips then
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

    -- Get prefix and link text, stripped of markup for measurement
    local prefix = string.sub(text, 1, s - 1)
    local strippedPrefix = stripHyperlinks(prefix)
    local cleanLinkText = stripColors(linkText)

    -- Measure prefix width (unwrapped) to find X position on its final line
    fs:SetWidth(0)
    fs:SetText(strippedPrefix)
    local prefixUnwrappedWidth = fs:GetStringWidth() or 0

    -- Measure link width
    fs:SetText(cleanLinkText)
    local linkWidth = fs:GetStringWidth() or 0

    -- Measure prefix height (wrapped) to find which line the link starts on
    fs:SetWidth(textWidth)
    if strippedPrefix ~= "" then
      fs:SetText(strippedPrefix)
    else
      fs:SetText("")
    end
    local prefixWrappedHeight = strippedPrefix ~= "" and (fs:GetStringHeight() or oneLineH) or 0
    local startLine = math.max(0, math.floor(prefixWrappedHeight / oneLineH + 0.5))
    if strippedPrefix ~= "" and prefixWrappedHeight > 0 then
      startLine = startLine - 1
    end

    -- Calculate X position on the line where the link starts
    -- This is the remainder after wrapping
    local xPos = 0
    if strippedPrefix ~= "" then
      xPos = prefixUnwrappedWidth % textWidth
      -- If prefix ends exactly at line boundary, link starts at x=0 on next line
      if prefixUnwrappedWidth > 0 and xPos < 1 then
        xPos = 0
        startLine = startLine + 1
      end
    end

    -- Check if the link itself fits on the remainder of the current line
    local spaceOnLine = textWidth - xPos
    local linkFitsOnLine = linkWidth <= spaceOnLine

    if linkFitsOnLine then
      -- Link fits on one line - use precise positioning
      btn:SetPoint("TOPLEFT", self.text, "TOPLEFT", xPos, -startLine * oneLineH)
      btn:SetSize(math.max(4, linkWidth), oneLineH)
    else
      -- Link wraps to multiple lines - calculate how many lines it spans
      local strippedUpToEnd = stripHyperlinks(string.sub(text, 1, e))
      fs:SetWidth(textWidth)
      fs:SetText(strippedUpToEnd)
      local totalHeight = fs:GetStringHeight() or oneLineH
      local endLine = math.max(startLine, math.floor(totalHeight / oneLineH + 0.5) - 1)
      
      -- Use full-width band for wrapped links
      btn:SetPoint("TOPLEFT", self.text, "TOPLEFT", 0, -startLine * oneLineH)
      btn:SetSize(textWidth, oneLineH * (endLine - startLine + 1))
    end

    btn:Show()
  end
end

---
-- Update texture color based on setting
function MessageLineMixin:UpdateTextures()
  local rightBgWidth = math.min(250, self.profile.frameWidth - 50)
  self:SetGradientBackground(50, rightBgWidth, self.profile.chatBackgroundColor or Colors.codGray, self.profile.chatBackgroundOpacity)
end

local function CreateMessageLine(parent, profile)
  local FadingFrameMixin = Core.Components.FadingFrameMixin
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin

  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, MessageLineMixin)

  object.profile = profile or Core.db.profile
  FadingFrameMixin.Init(object)
  GradientBackgroundMixin.Init(object)
  MessageLineMixin.Init(object)

  return object
end

local function CreateMessageLinePool(parent, profile)
  return CreateObjectPool(
    function () return CreateMessageLine(parent, profile) end,
    function (_, message)
      -- Reset all animations and timers
      message:QuickHide()
    end
  )
end

Core.Components.CreateMessageLine = CreateMessageLine
Core.Components.CreateMessageLinePool = CreateMessageLinePool
