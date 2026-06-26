local Core, Constants = unpack(select(2, ...))
local _, ns = ...
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

-- DEBUG: Controlled by /ccdebugb or the config toggle
local function IsBubbleDebugActive()
  return ns.db and ns.db.bubbleDebug
end

local function DebugPrint(...)
  if IsBubbleDebugActive() and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[BubbleDebug]|r " .. string.format(...))
  end
end

-- Expose bubble debug functions on the namespace for the config UI and slash command
ns.SetBubbleDebug = function(value)
  value = value and true or false
  if ns.db then ns.db.bubbleDebug = value end
  if value then
    print("|cffff7d0aCleanerChat|r bubble debug: |cff00ff00ON|r")
  else
    print("|cffff7d0aCleanerChat|r bubble debug: |cffff0000OFF|r")
  end
end

ns.GetBubbleDebug = function()
  if ns.db then return ns.db.bubbleDebug and true or false end
  return false
end

ns.ToggleBubbleDebug = function()
  ns.SetBubbleDebug(not ns.GetBubbleDebug())
end

-- Assign unique IDs to frames and lines for debugging
local nextFrameId = 1
local nextLineId = 1
local frameIds = setmetatable({}, { __mode = "k" })
local function GetFrameId(frame)
  if not frameIds[frame] then
    frameIds[frame] = nextFrameId
    nextFrameId = nextFrameId + 1
  end
  return frameIds[frame]
end

-- How often (in seconds) we scan the WorldFrame and advance the bubble fades. A
-- small value keeps the fade animations smooth.
local SCAN_THROTTLE = 0.03

-- Vertical gap (in pixels) between stacked messages above a speaker's head.
local LINE_SPACING = 2

-- Approximate height of a bubble line in pixels. Used to stack fading messages.
local LINE_HEIGHT = 14

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
for i = 1, 4 do
  SCAN_UNITS[#SCAN_UNITS + 1] = "party"..i
  SCAN_UNITS[#SCAN_UNITS + 1] = "party"..i.."target"
  SCAN_UNITS[#SCAN_UNITS + 1] = "partypet"..i
end
for i = 1, 40 do
  SCAN_UNITS[#SCAN_UNITS + 1] = "raid"..i
  SCAN_UNITS[#SCAN_UNITS + 1] = "raid"..i.."target"
  SCAN_UNITS[#SCAN_UNITS + 1] = "raidpet"..i
end
-- Nameplates: may not exist in 3.3.5 but some servers support them
for i = 1, 40 do SCAN_UNITS[#SCAN_UNITS + 1] = "nameplate"..i end

-- Cache of discovered class colors: [name] = colorCode. Once we've seen a player's
-- class (from any unit scan), we remember it so future bubbles stay colored even
-- if the player is no longer targetable.
local classColorCache = {}

-- Strips the realm suffix from a name (e.g. "Player-Realm" -> "Player").
local function StripRealm(name)
  if not name then return name end
  return name:match("^([^%-]+)") or name
end

-- Best-effort class colour escape (e.g. "|cff69ccf0") for a player name, read
-- from any currently readable unit that matches. Returns nil when the name can't
-- be matched to a player (notably NPCs, which have no class).
local function GetClassColorCode(name)
  if (not name) or (name == "") or (not RAID_CLASS_COLORS) then return nil end

  local searchName = StripRealm(name)

  -- Check cache first
  if classColorCache[searchName] then
    return classColorCache[searchName]
  end

  for _, unit in ipairs(SCAN_UNITS) do
    if UnitExists(unit) and UnitIsPlayer(unit) then
      local unitName = UnitName(unit)
      if unitName == searchName or unitName == name then
        local _, class = UnitClass(unit)
        local color = class and RAID_CLASS_COLORS[class]
        if color then
          local colorCode = string.format("|cff%02x%02x%02x",
            math.floor(color.r * 255 + 0.5),
            math.floor(color.g * 255 + 0.5),
            math.floor(color.b * 255 + 0.5))
          -- Cache for future lookups
          classColorCache[searchName] = colorCode
          return colorCode
        end
      end
    end
  end

  return nil
end

-- Wraps a speaker's name in its class colour (or the neutral default for NPCs and
-- unresolved players). Returns nil when there is no name to show.
local function BuildSpeakerPrefix(name, colorCode)
  if (not name) or (name == "") then return nil end
  local code = colorCode or GetClassColorCode(name) or DEFAULT_NAME_COLOR
  return code .. name .. "|r"
end

-- Records a chat message so a soon-to-appear bubble can be matched to its author.
-- Captures the class color NOW (at chat event time) when the player is most likely
-- to be queryable as a unit.
local function RememberMessage(message, sender)
  if (not message) or (message == "") then return end
  if (not sender) or (sender == "") then return end

  local now = GetTime()
  -- Drop expired entries from the front (the list is in chronological order).
  while recentMessages[1] and (now - recentMessages[1].time) > NAME_EXPIRY do
    table.remove(recentMessages, 1)
  end

  -- Capture class color NOW while the chat event is fresh - we're more likely to
  -- have the player as target/mouseover/etc at this moment than when the bubble renders.
  local colorCode = GetClassColorCode(sender)

  recentMessages[#recentMessages + 1] = { text = message, name = sender, time = now, colorCode = colorCode }
end

-- Finds and consumes the author of a bubble by its exact text, preferring the
-- most recent match. Returns the name and cached color code, or nil when no live capture matches.
local function ConsumeAuthor(text)
  if not text then return nil, nil end
  local now = GetTime()

  for i = #recentMessages, 1, -1 do
    local entry = recentMessages[i]
    if (now - entry.time) > NAME_EXPIRY then
      table.remove(recentMessages, i)
    elseif entry.text == text then
      local name = entry.name
      local colorCode = entry.colorCode
      table.remove(recentMessages, i)
      return name, colorCode
    end
  end

  return nil, nil
end

-- Applies the configured Glass font, size and outline to one of our stacked lines.
local function ApplyLineFont(fontString)
  local font = LSM:Fetch(LSM.MediaType.FONT, Core.db.profile.bubbleFont) or "Fonts\\FRIZQT__.TTF"
  fontString:SetFont(font, Core.db.profile.bubbleFontSize or 13, Core.db.profile.bubbleFontFlags)
  fontString:SetShadowColor(0, 0, 0, 1)
  fontString:SetShadowOffset(1, -1)
end

-- A private overlay that parents every bubble line. Because the lines live on our
-- own frame -- not the game's pooled bubble frames -- a message can keep fading
-- after the game recycles or hides the bubble it came from, which is what the old
-- per-frame stacking could not do without desyncing.
local overlay

-- Reusable FontStrings shared across all bubbles.
local linePool = {}

-- The single line each tracked game bubble frame is currently showing: [frame] =
-- line. One live line per frame, so messages never pile into a recycled frame.
local liveLines = {}

-- Lines that have detached from their frame (recycled or hidden) and are finishing
-- their fade-out in place.
local fadingLines = {}

-- Tracks which speaker owns which bubble frame: [frame] = { name, colorCode }.
-- The game pools bubble frames by speaker, so once we identify who owns a frame,
-- subsequent messages on that frame come from the same speaker (until recycled).
local frameSpeakers = {}

-- Acquires a styled, ready-to-show line from the shared pool.
local function AcquireLine()
  local line = table.remove(linePool)
  if not line then
    line = { fs = overlay:CreateFontString(nil, "OVERLAY") }
    line.fs:SetJustifyH("CENTER")
  end
  ApplyLineFont(line.fs)
  line.fs:SetAlpha(0)
  line.fs:Show()
  return line
end

-- Returns a line to the pool, fully reset.
local function ReleaseLine(line)
  DebugPrint("RELEASE Line#%s", tostring(line.lineId))
  line.fs:Hide()
  line.fs:SetText("")
  line.fs:ClearAllPoints()
  line.born, line.forcedOutAt, line.text, line.originFrame, line.stackOffset = nil, nil, nil, nil, nil
  line.frozenX, line.frozenY, line.lastX, line.lastY = nil, nil, nil, nil
  line.lineId = nil
  linePool[#linePool + 1] = line
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

-- Builds the text shown for a freshly seen message: the raw bubble text, optionally
-- prefixed with the class-colored speaker name. Consumes one captured author, so it
-- must run exactly once per new message.
-- If text matching fails, falls back to the cached speaker for this frame.
local function Decorate(text, frame)
  if not Core.db.profile.bubbleShowName then
    return text
  end

  -- Try to match this text to a recently captured chat message
  local name, colorCode = ConsumeAuthor(text)

  if name then
    -- Found a match: cache this speaker for the frame
    frameSpeakers[frame] = { name = name, colorCode = colorCode }
    DebugPrint("  SPEAKER MATCH: Frame#%d matched to '%s'", GetFrameId(frame), name)
  else
    -- No match: use cached speaker for this frame (same person speaking again)
    local cached = frameSpeakers[frame]
    if cached then
      name = cached.name
      colorCode = cached.colorCode
      DebugPrint("  SPEAKER CACHED: Frame#%d using cached '%s'", GetFrameId(frame), name)
    else
      DebugPrint("  SPEAKER UNKNOWN: Frame#%d has no match and no cache", GetFrameId(frame))
    end
  end

  local prefix = BuildSpeakerPrefix(name, colorCode)
  if prefix then
    return prefix .. ": " .. text
  end

  return text
end

-- Glues a live line to its game bubble frame so it tracks the speaker on screen.
local function AnchorToFrame(line, frame)
  line.fs:ClearAllPoints()
  line.fs:SetPoint("CENTER", frame, "CENTER", 0, 0)
  line.frozen = false  -- Mark as actively anchored
end

-- Freezes a live line at its last known position (used when frame hides).
-- The line stays in liveLines and continues fading, but no longer follows the frame.
-- Only collides with lines from DIFFERENT speakers to avoid visual overlap.
local FREEZE_COLLISION_X = 100  -- Horizontal range to check for collisions
local FREEZE_COLLISION_Y = 50   -- Vertical range to check for collisions
local function FreezeLine(line)
  if line.frozen then return end  -- Already frozen
  local x, y = line.lastX, line.lastY
  if not x or not y then return end
  
  local mySpeaker = line.speakerName
  
  -- Check for collisions with other frozen live lines from DIFFERENT speakers
  local offset = 0
  for _, otherLine in pairs(liveLines) do
    if otherLine ~= line and otherLine.frozen and otherLine.lastX and otherLine.lastY then
      -- Only collide if speakers are different (or unknown)
      local sameSpeaker = mySpeaker and otherLine.speakerName and (mySpeaker == otherLine.speakerName)
      if not sameSpeaker then
        local otherY = otherLine.lastY + (otherLine.stackOffset or 0)
        local dx = math.abs(x - otherLine.lastX)
        local newY = y + offset
        local dy = math.abs(newY - otherY)
        
        if dx < FREEZE_COLLISION_X and dy < FREEZE_COLLISION_Y then
          -- Push away from the other line (up if we're above, down if below)
          if newY >= otherY then
            -- We're above or at same level: push UP
            offset = offset + (FREEZE_COLLISION_Y - dy) + LINE_SPACING
          else
            -- We're below: push DOWN
            offset = offset - (FREEZE_COLLISION_Y - dy) - LINE_SPACING
          end
          DebugPrint("  -> Freeze collision with Line#%s speaker='%s' (dx=%d dy=%d), offset now %d", 
            tostring(otherLine.lineId), otherLine.speakerName or "?", math.floor(dx), math.floor(dy), offset)
        end
      end
    end
  end
  
  line.stackOffset = offset
  line.fs:ClearAllPoints()
  line.fs:SetPoint("CENTER", overlay, "BOTTOMLEFT", x, y + offset)
  line.frozen = true
  DebugPrint("FREEZE Line#%s speaker='%s' at (%d,%d) with offset %d", tostring(line.lineId), mySpeaker or "?", math.floor(x), math.floor(y), offset)
end

-- Check if a position would collide with any existing frozen line (fading or frozen-live),
-- and return the offset needed to avoid collision. Two lines "collide" if they're within
-- threshold pixels of each other.
local COLLISION_THRESHOLD_X = 100
local COLLISION_THRESHOLD_Y = 50
local function GetCollisionOffset(x, y, excludeLine)
  local offset = 0
  
  -- Check against fading lines
  for _, other in ipairs(fadingLines) do
    if other ~= excludeLine and other.frozenX and other.frozenY then
      local otherY = other.frozenY + (other.stackOffset or 0)
      local dx = math.abs((x or 0) - other.frozenX)
      local dy = math.abs((y + offset) - otherY)
      if dx < COLLISION_THRESHOLD_X and dy < COLLISION_THRESHOLD_Y then
        offset = offset + LINE_HEIGHT + LINE_SPACING
        DebugPrint("  -> Collision with fading Line#%s, offset now %d", tostring(other.lineId), offset)
      end
    end
  end
  
  -- Check against frozen live lines
  for _, other in pairs(liveLines) do
    if other ~= excludeLine and other.frozen and other.lastX and other.lastY then
      local otherY = other.lastY + (other.stackOffset or 0)
      local dx = math.abs((x or 0) - other.lastX)
      local dy = math.abs((y + offset) - otherY)
      if dx < COLLISION_THRESHOLD_X and dy < COLLISION_THRESHOLD_Y then
        offset = offset + LINE_HEIGHT + LINE_SPACING
        DebugPrint("  -> Collision with frozen-live Line#%s, offset now %d", tostring(other.lineId), offset)
      end
    end
  end
  
  return offset
end

-- Detaches the line a frame is carrying so it finishes fading on its own. The
-- line remembers which frame it came from and its current stack offset, so it
-- can be repositioned when new messages push it upward.
-- IMPORTANT: Uses lastX/lastY (captured during previous update) instead of querying
-- the frame now, because by the time we detect text changed, the frame may have
-- already moved to track a new speaker (WoW recycles frames).
local function DetachLine(frame)
  local line = liveLines[frame]
  if not line then return end
  
  local frameId = GetFrameId(frame)
  local lineId = line.lineId or "?"
  local curX, curY = frame:GetCenter()
  DebugPrint("DETACH Line#%s from Frame#%d text='%s' lastPos=(%s,%s) curPos=(%s,%s)",
    tostring(lineId), frameId, 
    string.sub(line.text or "", 1, 20),
    tostring(line.lastX and math.floor(line.lastX)), tostring(line.lastY and math.floor(line.lastY)),
    tostring(curX and math.floor(curX)), tostring(curY and math.floor(curY)))
  
  liveLines[frame] = nil
  line.originFrame = frame
  line.stackOffset = line.stackOffset or 0
  -- Use the position we captured BEFORE the text changed, not the current position
  -- which may have already moved to track a different speaker
  if line.lastX and line.lastY then
    line.frozenX, line.frozenY = line.lastX, line.lastY
    DebugPrint("  -> Using lastX/lastY for frozen pos")
  else
    -- Fallback: try current position (better than nothing)
    local x, y = frame:GetCenter()
    if x and y then
      line.frozenX, line.frozenY = x, y
      DebugPrint("  -> FALLBACK: Using current pos for frozen")
    end
  end
  
  -- Check for collision with existing fading lines and offset if needed
  if line.frozenX and line.frozenY then
    local collisionOffset = GetCollisionOffset(line.frozenX, line.frozenY, line)
    if collisionOffset > 0 then
      line.stackOffset = (line.stackOffset or 0) + collisionOffset
      DebugPrint("  -> Added collision offset: %d, total stackOffset: %d", collisionOffset, line.stackOffset)
    end
  end
  
  DebugPrint("  -> Frozen at (%s,%s) with stackOffset=%d", 
    tostring(line.frozenX and math.floor(line.frozenX)), 
    tostring(line.frozenY and math.floor(line.frozenY)),
    line.stackOffset or 0)
  fadingLines[#fadingLines + 1] = line
end

-- Pushes up all fading lines that came from a given frame by one message height.
-- Called when a new message appears for that speaker.
local function PushUpFadingLines(frame)
  for _, line in ipairs(fadingLines) do
    if line.originFrame == frame then
      line.stackOffset = (line.stackOffset or 0) + LINE_HEIGHT + LINE_SPACING
    end
  end
end

-- Repositions a fading line at its frozen screen position. Once a line is detached,
-- it no longer tracks any frame - it stays exactly where it was when detached.
-- This prevents lines from jumping to wrong positions when frames are recycled or
-- when camera movement causes frame positions to shift.
local function PositionFadingLine(line)
  local offset = line.stackOffset or 0
  line.fs:ClearAllPoints()
  if line.frozenX and line.frozenY then
    line.fs:SetPoint("CENTER", UIParent, "BOTTOMLEFT", line.frozenX, line.frozenY + offset)
  end
end

-- Caps how many bubble lines may be visible at once. When the cap is exceeded the
-- oldest line that isn't already fading out is forced to start fading.
local function EnforceMaxLines()
  local max = Core.db.profile.bubbleMaxLines or 4
  if max < 1 then max = 1 end

  local count, oldest, oldestBorn = 0, nil, nil
  local function consider(line)
    if line.forcedOutAt then return end
    count = count + 1
    if (not oldestBorn) or line.born < oldestBorn then
      oldest, oldestBorn = line, line.born
    end
  end
  for _, line in pairs(liveLines) do consider(line) end
  for _, line in ipairs(fadingLines) do consider(line) end

  if count > max and oldest then
    oldest.forcedOutAt = GetTime()
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

-- Remembers a bubble's original look the first time we see it (so it can be fully
-- restored) and grabs the game's text region. We no longer hook its lifetime or
-- position -- the game keeps owning when each frame shows, hides and is recycled,
-- while our own lines carry the message and fade.
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

  frame.glassRemembered = true
  -- Draw our lines in the same layer the game draws bubbles in, so they stay visible.
  if overlay then
    overlay:SetFrameStrata(frame:GetFrameStrata())
  end
  trackedBubbles[#trackedBubbles + 1] = frame
end

-- Handles one shown bubble frame each pass: hides the game's own graphic and text,
-- then makes sure the frame is showing exactly one of our lines for its current
-- message. A changed text means the game recycled the frame for a new message, so
-- the previous line is dropped (the game has already replaced its bubble) and a
-- fresh line with its own timer takes over.
local function ProcessFrame(frame)
  HideBubbleGraphic(frame)

  local gameText = frame.glassGameText
  if not gameText then return end

  local text = gameText:GetText()
  gameText:Hide()

  local line = liveLines[frame]

  if (not text) or text == "" then
    if line then DetachLine(frame) end
    return
  end

  if (not line) or line.text ~= text then
    if line then
      -- Text changed: the game recycled this frame for a new message. Let the old
      -- line finish fading where it was last seen instead of deleting it.
      DebugPrint("TEXT CHANGED on Frame#%d: old='%s' new='%s'", GetFrameId(frame), string.sub(line.text or "", 1, 20), string.sub(text, 1, 20))
      DetachLine(frame)
      -- CRITICAL: Clear cached speaker when frame is recycled! Otherwise we'd
      -- incorrectly attribute the new message to the old speaker if ConsumeAuthor fails.
      frameSpeakers[frame] = nil
    end
    -- Push all existing fading lines from this frame upward before adding new one
    PushUpFadingLines(frame)
    line = AcquireLine()
    line.lineId = nextLineId
    nextLineId = nextLineId + 1
    line.text = text
    line.born = GetTime()
    line.forcedOutAt = nil
    line.stackOffset = 0
    line.originFrame = frame
    -- Capture initial position immediately
    local x, y = frame:GetCenter()
    if x and y then
      line.lastX, line.lastY = x, y
    end
    line.fs:SetText(Decorate(text, frame))
    -- Store the speaker info on the line so we know who owns it even after detaching
    local speaker = frameSpeakers[frame]
    line.speakerName = speaker and speaker.name or nil
    AnchorToFrame(line, frame)
    liveLines[frame] = line
    DebugPrint("NEW Line#%d on Frame#%d at (%d,%d) speaker='%s' text='%s'", line.lineId, GetFrameId(frame), math.floor(x or 0), math.floor(y or 0), line.speakerName or "?", string.sub(text, 1, 30))
    EnforceMaxLines()
  else
    -- Same message still up on the same frame.
    -- Even if frozen, RE-ANCHOR since the frame is showing again and tracking.
    line.frozen = false
    local x, y = frame:GetCenter()
    if x and y then
      line.lastX, line.lastY = x, y
    end
    AnchorToFrame(line, frame)
  end
end

-- Advances every line's fade one step and reclaims any that have fully faded.
local function UpdateFades(now)
  for frame, line in pairs(liveLines) do
    local alpha, dead = LineAlpha(line, now)
    if dead then
      local state = line.frozen and "frozen" or (frame:IsShown() and "shown" or "hidden")
      DebugPrint("DEAD (live) Line#%s on Frame#%d (%s)", tostring(line.lineId), GetFrameId(frame), state)
      ReleaseLine(line)
      liveLines[frame] = nil
    else
      line.fs:SetAlpha(alpha)
      -- Only track position if line is still actively anchored (not frozen).
      -- Frozen lines stay at their last-shown position.
      if not line.frozen then
        local x, y = frame:GetCenter()
        if x and y then
          line.lastX, line.lastY = x, y
        end
      end
    end
  end

  local i = 1
  while i <= #fadingLines do
    local line = fadingLines[i]
    local alpha, dead = LineAlpha(line, now)
    if dead then
      DebugPrint("DEAD (fading) Line#%s frozen=(%s,%s)", tostring(line.lineId), tostring(line.frozenX and math.floor(line.frozenX)), tostring(line.frozenY and math.floor(line.frozenY)))
      ReleaseLine(line)
      table.remove(fadingLines, i)
    else
      line.fs:SetAlpha(alpha)
      PositionFadingLine(line)
      i = i + 1
    end
  end
end

-- Restores a single bubble frame to the game's default appearance.
local function RestoreBubble(frame)
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

-- Restores every bubble we have touched and reclaims all of our lines (used when
-- the feature is switched off).
local function RestoreBubbles()
  for frame, line in pairs(liveLines) do
    ReleaseLine(line)
    liveLines[frame] = nil
  end
  for i = #fadingLines, 1, -1 do
    ReleaseLine(fadingLines[i])
    fadingLines[i] = nil
  end
  wipe(frameSpeakers)
  for _, frame in ipairs(trackedBubbles) do
    if frame.glassRemembered then
      RestoreBubble(frame)
    end
  end
end

-- Debug: periodic status dump
local lastStatusDump = 0
local function DebugStatus()
  if not DEBUG_BUBBLES then return end
  local now = GetTime()
  if now - lastStatusDump < 2 then return end -- Only dump every 2 seconds
  lastStatusDump = now
  
  local liveCount = 0
  for frame, line in pairs(liveLines) do
    liveCount = liveCount + 1
    local x, y = frame:GetCenter()
    local state = line.frozen and "FROZEN" or (frame:IsShown() and "SHOWN" or "HIDDEN")
    DebugPrint("  LIVE: Line#%s Frame#%d %s pos=(%d,%d) last=(%s,%s)", 
      tostring(line.lineId), GetFrameId(frame), state,
      math.floor(x or 0), math.floor(y or 0),
      tostring(line.lastX and math.floor(line.lastX)), tostring(line.lastY and math.floor(line.lastY)))
  end
  
  for i, line in ipairs(fadingLines) do
    local frameId = line.originFrame and GetFrameId(line.originFrame) or "?"
    DebugPrint("  FADING[%d]: Line#%s from Frame#%s frozen=(%s,%s)", 
      i, tostring(line.lineId), tostring(frameId),
      tostring(line.frozenX and math.floor(line.frozenX)), tostring(line.frozenY and math.floor(line.frozenY)))
  end
  
  if liveCount > 0 or #fadingLines > 0 then
    DebugPrint("STATUS: %d live, %d fading", liveCount, #fadingLines)
  end
end

-- Scans the WorldFrame's children for chat bubbles each pass: remembers new ones,
-- refreshes the line on every shown bubble, and advances every line's fade.
-- When a frame hides, we detach its line using the LAST SHOWN position (lastX/lastY),
-- not the current position which may have drifted to a "parking spot".
local function ScanBubbles()
  local now = GetTime()
  DebugStatus()
  local count = WorldFrame:GetNumChildren()
  for i = 1, count do
    local frame = select(i, WorldFrame:GetChildren())
    if frame then
      if not frame.glassRemembered and IsChatBubble(frame) then
        RememberBubble(frame)
      end

      if frame.glassRemembered then
        if frame:IsShown() then
          ProcessFrame(frame)
        elseif liveLines[frame] then
          -- Frame is hidden but line still exists. The frame continues tracking
          -- the unit position even when hidden. Check if it moved dramatically
          -- (parking spot) vs still tracking normally.
          local line = liveLines[frame]
          local x, y = frame:GetCenter()
          if x and y and line.lastX and line.lastY then
            local dx = math.abs(x - line.lastX)
            local dy = math.abs(y - line.lastY)
            -- If frame jumped more than 200 pixels, it's probably parked - freeze
            if dx > 200 or dy > 200 then
              if not line.frozen then
                DebugPrint("PARKING DETECTED: Frame#%d jumped (%d,%d) - freezing line", GetFrameId(frame), math.floor(dx), math.floor(dy))
                FreezeLine(line)
              end
            else
              -- Small movement: frame is still tracking the unit.
              -- Position our line where the frame is (can't anchor to hidden frame).
              line.lastX, line.lastY = x, y
              line.fs:ClearAllPoints()
              line.fs:SetPoint("CENTER", overlay, "BOTTOMLEFT", x, y)
            end
          elseif x and y then
            -- No previous position, just track
            line.lastX, line.lastY = x, y
            line.fs:ClearAllPoints()
            line.fs:SetPoint("CENTER", overlay, "BOTTOMLEFT", x, y)
          end
        end
      end
    end
  end

  UpdateFades(now)
end

function Bubbles:OnInitialize()
  -- Private parent for every bubble line, so a line can outlive the game bubble
  -- frame it came from and keep fading after the frame is recycled or hidden.
  overlay = CreateFrame("Frame", nil, WorldFrame)
  overlay:SetAllPoints(WorldFrame)

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
