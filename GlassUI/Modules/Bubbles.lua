local Core, Constants = unpack(select(2, ...))
local Bubbles = Core:GetModule("Bubbles")

local LSM = Core.Libs.LSM

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local WorldFrame = WorldFrame
local GetTime = GetTime
-- luacheck: pop

-- How often (in seconds) we scan the WorldFrame and advance the bubble stacks. A
-- small value keeps the fade animations smooth.
local SCAN_THROTTLE = 0.03

-- Vertical gap (in pixels) between stacked messages above a speaker's head.
local LINE_SPACING = 2

-- Identifies the default 3.3.5 chat bubble: an anonymous child of the WorldFrame
-- whose backdrop uses Blizzard's ChatBubble background texture.
local function IsChatBubble(frame)
  if frame:GetName() then return false end
  if not frame.GetBackdrop then return false end

  local backdrop = frame:GetBackdrop()
  if backdrop and backdrop.bgFile then
    return backdrop.bgFile:lower():find("chatbubble", 1, true) ~= nil
  end

  return false
end

-- Frames we have touched, tracked so the feature can restore them all when it is
-- switched off (the game pools bubble frames, so an altered frame is reused).
local trackedBubbles = {}

-- Applies the configured Glass font, size and outline to one of our stacked lines.
local function ApplyLineFont(fontString)
  local font = LSM:Fetch(LSM.MediaType.FONT, Core.db.profile.bubbleFont) or "Fonts\\FRIZQT__.TTF"
  fontString:SetFont(font, Core.db.profile.bubbleFontSize or 13, Core.db.profile.bubbleFontFlags)
  fontString:SetShadowColor(0, 0, 0, 1)
  fontString:SetShadowOffset(1, -1)
end

-- Per-frame pool of reusable FontString "lines" so we don't churn FontStrings as
-- messages come and go.
local function AcquireLine(frame)
  local pool = frame.glassPool
  if pool and #pool > 0 then
    return table.remove(pool)
  end
  local line = { fs = frame:CreateFontString(nil, "OVERLAY") }
  line.fs:SetJustifyH("CENTER")
  ApplyLineFont(line.fs)
  return line
end

local function ReleaseLine(frame, line)
  line.fs:Hide()
  line.fs:SetText("")
  frame.glassPool = frame.glassPool or {}
  frame.glassPool[#frame.glassPool + 1] = line
end

-- Computes a line's alpha from its age and the configured fade timing. Returns the
-- alpha plus a "dead" flag once the line has fully faded out.
local function LineAlpha(line, now)
  local fadeIn = Core.db.profile.bubbleFadeInDuration or 0
  local fadeOut = Core.db.profile.bubbleFadeOutDuration or 0
  local hold = Core.db.profile.bubbleHoldTime or 0

  -- Forced out: bumped from the stack because the maximum was exceeded.
  if line.forcedOutAt then
    if fadeOut <= 0 then return 0, true end
    local t = now - line.forcedOutAt
    if t >= fadeOut then return 0, true end
    return 1 - t / fadeOut, false
  end

  local age = now - line.born
  if fadeIn > 0 and age < fadeIn then
    return age / fadeIn, false
  end

  local holdEnd = (fadeIn > 0 and fadeIn or 0) + hold
  if age < holdEnd then
    return 1, false
  end

  if fadeOut <= 0 then return 0, true end
  local t = age - holdEnd
  if t >= fadeOut then return 0, true end
  return 1 - t / fadeOut, false
end

-- Adds a new message to a frame's stack (newest last) and, once the stack exceeds
-- the configured maximum, starts fading out the oldest line.
local function AddMessage(frame, text)
  local line = AcquireLine(frame)
  ApplyLineFont(line.fs)
  line.fs:SetText(text)
  line.born = GetTime()
  line.forcedOutAt = nil
  line.fs:SetAlpha(0)
  line.fs:Show()

  local lines = frame.glassLines
  lines[#lines + 1] = line

  local max = Core.db.profile.bubbleMaxLines or 4
  if #lines > max then
    for i = 1, #lines do
      if not lines[i].forcedOutAt then
        lines[i].forcedOutAt = GetTime()
        break
      end
    end
  end
end

-- Re-anchors a frame's lines so the newest sits at the bottom (nearest the head)
-- and older messages stack upward.
local function RepositionLines(frame)
  local lines = frame.glassLines
  local n = #lines
  if n == 0 then return end

  lines[n].fs:ClearAllPoints()
  lines[n].fs:SetPoint("CENTER", frame, "CENTER", 0, 0)
  for i = n - 1, 1, -1 do
    lines[i].fs:ClearAllPoints()
    lines[i].fs:SetPoint("BOTTOM", lines[i + 1].fs, "TOP", 0, LINE_SPACING)
  end
end

-- Hides the game's bubble graphic (backdrop + textures). The game's own text is
-- hidden separately so only our stacked lines are shown.
local function HideBubbleGraphic(frame)
  if frame.SetBackdrop then
    frame:SetBackdrop(nil)
  end
  for i = 1, frame:GetNumRegions() do
    local region = select(i, frame:GetRegions())
    if region and region:GetObjectType() == "Texture" then
      region:Hide()
    end
  end
end

-- Keeps a bubble frame visible while its stack is still fading, instead of letting
-- the game hide it after its own short timeout.
local function HookHide(frame)
  if frame.glassHideHooked then return end
  frame.glassHideHooked = true
  frame.glassRealHide = frame.Hide
  frame.Hide = function (self)
    if self.glassActive then return end
    return self.glassRealHide(self)
  end
end

-- Remembers a bubble's original look the first time we see it (so it can be fully
-- restored), grabs the game's text region, and prepares the per-frame stack.
local function RememberBubble(frame)
  frame.glassBackdrop = frame:GetBackdrop()
  frame.glassBackdropColor = { frame:GetBackdropColor() }
  frame.glassBackdropBorderColor = { frame:GetBackdropBorderColor() }

  for i = 1, frame:GetNumRegions() do
    local region = select(i, frame:GetRegions())
    if region and region:GetObjectType() == "FontString" then
      frame.glassGameText = region
      frame.glassGameFont = { region:GetFont() }
      break
    end
  end

  frame.glassLines = {}
  frame.glassPool = {}
  frame.glassRemembered = true
  HookHide(frame)
  trackedBubbles[#trackedBubbles + 1] = frame
end

-- Drives a single bubble each pass: hides the game's graphic and text, captures
-- any new message into the stack, fades existing lines, and repositions them.
local function UpdateBubble(frame, now)
  HideBubbleGraphic(frame)

  local gameText = frame.glassGameText
  if gameText then
    local text = gameText:GetText()
    gameText:Hide()
    if text and text ~= "" and text ~= frame.glassLastText then
      frame.glassLastText = text
      AddMessage(frame, text)
    end
  end

  local lines = frame.glassLines
  local i = 1
  while i <= #lines do
    local alpha, dead = LineAlpha(lines[i], now)
    if dead then
      ReleaseLine(frame, lines[i])
      table.remove(lines, i)
    else
      lines[i].fs:SetAlpha(alpha)
      i = i + 1
    end
  end

  RepositionLines(frame)

  if #lines > 0 then
    frame.glassActive = true
  else
    -- Stack empty: let the frame hide and reset so it can be reused cleanly.
    frame.glassActive = false
    frame.glassLastText = nil
    if frame.glassRealHide then
      frame.glassRealHide(frame)
    end
  end
end

-- Clears a frame's stack and restores it to the game's default appearance.
local function RestoreBubble(frame)
  if frame.glassLines then
    for _, line in ipairs(frame.glassLines) do
      ReleaseLine(frame, line)
    end
    frame.glassLines = {}
  end
  frame.glassActive = false
  frame.glassLastText = nil

  if frame.SetBackdrop then
    frame:SetBackdrop(frame.glassBackdrop)
    if frame.glassBackdrop then
      local c = frame.glassBackdropColor
      if c[1] then frame:SetBackdropColor(c[1], c[2], c[3], c[4]) end
      local b = frame.glassBackdropBorderColor
      if b[1] then frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4]) end
    end
  end
  for i = 1, frame:GetNumRegions() do
    local region = select(i, frame:GetRegions())
    if region and region:GetObjectType() == "Texture" then
      region:Show()
    end
  end
  if frame.glassGameText then
    frame.glassGameText:Show()
    if frame.glassGameFont and frame.glassGameFont[1] then
      frame.glassGameText:SetFont(frame.glassGameFont[1], frame.glassGameFont[2], frame.glassGameFont[3])
    end
  end
end

-- Restores every bubble we have touched (used when the feature is switched off).
local function RestoreBubbles()
  for _, frame in ipairs(trackedBubbles) do
    if frame.glassRemembered then
      RestoreBubble(frame)
    end
  end
end

-- Scans the WorldFrame's children for chat bubbles, remembering new ones and
-- advancing the stack on every visible bubble each pass.
local function ScanBubbles()
  local now = GetTime()
  local count = WorldFrame:GetNumChildren()
  for i = 1, count do
    local frame = select(i, WorldFrame:GetChildren())
    if frame then
      if not frame.glassRemembered and IsChatBubble(frame) then
        RememberBubble(frame)
      end

      if frame.glassRemembered and frame:IsShown() then
        UpdateBubble(frame, now)
      end
    end
  end
end

function Bubbles:OnInitialize()
  self.scanner = CreateFrame("Frame")
  self.scanner:Hide()
  self.scanner.elapsed = 0
  self.scanner:SetScript("OnUpdate", function (frame, elapsed)
    frame.elapsed = frame.elapsed + elapsed
    if frame.elapsed < SCAN_THROTTLE then return end
    frame.elapsed = 0
    ScanBubbles()
  end)
end

function Bubbles:OnEnable()
  self:Update()

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "chatBubbles" then
      self:Update()
    end
  end)
end

-- Turns the WorldFrame scanner on or off to match the saved setting. When turned
-- off, every bubble we touched is restored to Blizzard's default appearance.
function Bubbles:Update()
  if Core.db.profile.chatBubbles then
    self.scanner:Show()
  else
    self.scanner:Hide()
    RestoreBubbles()
  end
end
