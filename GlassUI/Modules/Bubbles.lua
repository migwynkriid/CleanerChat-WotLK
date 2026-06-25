local Core, Constants = unpack(select(2, ...))
local Bubbles = Core:GetModule("Bubbles")

local LSM = Core.Libs.LSM

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local WorldFrame = WorldFrame
-- luacheck: pop

-- How often (in seconds) to rescan the WorldFrame for new chat bubbles while the
-- feature is enabled. Bubbles linger for a few seconds, so a light throttle is
-- more than enough to catch them as they appear.
local SCAN_THROTTLE = 0.1

-- Default size to fall back to if the original bubble FontString has no size.
local FALLBACK_FONT_SIZE = 13

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

-- Strips the Blizzard bubble background/border and restyles the message text with
-- the Glass font and an outline, so only the text floats above the speaker's head.
local function SkinBubble(frame)
  for i = 1, frame:GetNumRegions() do
    local region = select(i, frame:GetRegions())
    if region then
      local objectType = region:GetObjectType()
      if objectType == "Texture" then
        region:SetTexture(nil)
      elseif objectType == "FontString" then
        frame.glassText = region
        local _, size = region:GetFont()
        region:SetFont(
          LSM:Fetch(LSM.MediaType.FONT, Core.db.profile.font),
          size or FALLBACK_FONT_SIZE,
          "OUTLINE"
        )
        region:SetShadowColor(0, 0, 0, 1)
        region:SetShadowOffset(1, -1)
      end
    end
  end

  if frame.SetBackdrop then
    frame:SetBackdrop(nil)
  end

  frame.glassBubble = true
end

-- The WorldFrame's child count only changes when frames (bubbles, nameplates,
-- etc.) are added or removed, so we skip the work entirely while it is stable.
local lastChildCount = 0
local function ScanBubbles()
  local count = WorldFrame:GetNumChildren()
  if count == lastChildCount then return end
  lastChildCount = count

  for i = 1, count do
    local frame = select(i, WorldFrame:GetChildren())
    if frame and not frame.glassBubble and IsChatBubble(frame) then
      SkinBubble(frame)
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

-- Turns the WorldFrame scanner on or off to match the saved setting. While the
-- scanner is hidden its OnUpdate never fires, so a disabled feature costs nothing.
function Bubbles:Update()
  if Core.db.profile.chatBubbles then
    lastChildCount = 0 -- force a fresh scan on the next tick
    self.scanner:Show()
  else
    self.scanner:Hide()
  end
end
