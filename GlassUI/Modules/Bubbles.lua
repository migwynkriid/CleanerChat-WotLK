local Core, Constants = unpack(select(2, ...))
local Bubbles = Core:GetModule("Bubbles")

local LSM = Core.Libs.LSM

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local WorldFrame = WorldFrame
local GetTime = GetTime
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitName = UnitName
local UnitClass = UnitClass
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local wipe = wipe
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

-- The default 3.3.5 chat bubble only carries the spoken text -- never the
-- speaker's name. To label a bubble we listen to the chat events that produce
-- bubbles (say/yell and their monster equivalents), remember each message's
-- text and author for a short window, then match a freshly shown bubble back to
-- the author by its text. Entries are consumed on match and expire quickly so a
-- bubble is never tagged with a stale name.
local NAME_EVENTS = {
  "CHAT_MSG_SAY",
  "CHAT_MSG_YELL",
  "CHAT_MSG_MONSTER_SAY",
  "CHAT_MSG_MONSTER_YELL",
  "CHAT_MSG_MONSTER_PARTY",
  "CHAT_MSG_MONSTER_WHISPER",
}

-- How long (seconds) a captured message stays eligible to label a bubble. Bubbles
-- appear within a frame or two of the chat event, so this only needs to be large
-- enough to bridge that gap and is kept short to avoid mislabelling.
local NAME_EXPIRY = 5

-- Neutral colour used for names we cannot resolve to a class (NPCs, or players
-- not currently on a readable unit). Light blue-grey so the name still stands
-- out from the white message body.
local DEFAULT_NAME_COLOR = "|cffc3cad9"

-- Recently captured { text, name, time } messages, newest last.
local recentMessages = {}

-- Units we can read a class from without targeting anyone. There is no API in
-- 3.3.5 to look up an arbitrary player's class, but a speaker in say/yell range
-- is very often one of these. Built once since the list never changes.
local SCAN_UNITS = { "player", "target", "targettarget", "focus", "focustarget", "mouseover", "pet" }
for i = 1, 4 do SCAN_UNITS[#SCAN_UNITS + 1] = "party"..i end
for i = 1, 40 do SCAN_UNITS[#SCAN_UNITS + 1] = "raid"..i end

-- Best-effort class colour escape (e.g. "|cff69ccf0") for a player name, read
-- from any currently readable unit that matches. Returns nil when the name can't
-- be matched to a player (notably NPCs, which have no class).
local function GetClassColorCode(name)
  if (not name) or (name == "") or (not RAID_CLASS_COLORS) then return nil end

  for _, unit in ipairs(SCAN_UNITS) do
    if UnitExists(unit) and UnitIsPlayer(unit) and UnitName(unit) == name then
      local _, class = UnitClass(unit)
      local color = class and RAID_CLASS_COLORS[class]
      if color then
        return string.format("|cff%02x%02x%02x",
          math.floor(color.r * 255 + 0.5),
          math.floor(color.g * 255 + 0.5),
          math.floor(color.b * 255 + 0.5))
      end
    end
  end

  return nil
end

-- Wraps a speaker's name in its class colour (or the neutral default for NPCs and
-- unresolved players). Returns nil when there is no name to show.
local function BuildSpeakerPrefix(name)
  if (not name) or (name == "") then return nil end
  local code = GetClassColorCode(name) or DEFAULT_NAME_COLOR
  return code .. name .. "|r"
end

-- Records a chat message so a soon-to-appear bubble can be matched to its author.
local function RememberMessage(message, sender)
  if (not message) or (message == "") then return end
  if (not sender) or (sender == "") then return end

  local now = GetTime()
  -- Drop expired entries from the front (the list is in chronological order).
  while recentMessages[1] and (now - recentMessages[1].time) > NAME_EXPIRY do
    table.remove(recentMessages, 1)
  end

  recentMessages[#recentMessages + 1] = { text = message, name = sender, time = now }
end

-- Finds and consumes the author of a bubble by its exact text, preferring the
-- most recent match. Returns nil when no live capture matches.
local function ConsumeAuthor(text)
  if not text then return nil end
  local now = GetTime()

  for i = #recentMessages, 1, -1 do
    local entry = recentMessages[i]
    if (now - entry.time) > NAME_EXPIRY then
      table.remove(recentMessages, i)
    elseif entry.text == text then
      local name = entry.name
      table.remove(recentMessages, i)
      return name
    end
  end

  return nil
end

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
      local displayText = text
      if Core.db.profile.bubbleShowName then
        local prefix = BuildSpeakerPrefix(ConsumeAuthor(text))
        if prefix then
          displayText = prefix .. ": " .. text
        end
      end
      AddMessage(frame, displayText)
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

  -- Listens for the chat events that spawn bubbles and remembers each message so
  -- ScanBubbles can label the matching bubble with its speaker. Events are only
  -- registered while the labelling feature is active (see UpdateNameCapture).
  self.nameCapture = CreateFrame("Frame")
  self.nameCapture:SetScript("OnEvent", function (_, _, message, sender)
    RememberMessage(message, sender)
  end)
end

function Bubbles:OnEnable()
  self:Update()

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "chatBubbles" or key == "bubbleShowName" then
      self:Update()
    end
  end)
end

-- Registers or clears the chat-event listeners used to label bubbles with the
-- speaker's name, matching the current settings. Only active when both bubble
-- replacement and the name option are on, so we do no work otherwise.
function Bubbles:UpdateNameCapture()
  if Core.db.profile.chatBubbles and Core.db.profile.bubbleShowName then
    for _, event in ipairs(NAME_EVENTS) do
      self.nameCapture:RegisterEvent(event)
    end
  else
    self.nameCapture:UnregisterAllEvents()
    wipe(recentMessages)
  end
end

-- Turns the WorldFrame scanner on or off to match the saved setting. When turned
-- off, every bubble we touched is restored to Blizzard's default appearance.
function Bubbles:Update()
  self:UpdateNameCapture()
  if Core.db.profile.chatBubbles then
    self.scanner:Show()
  else
    self.scanner:Hide()
    RestoreBubbles()
  end
end
