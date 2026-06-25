local Core, Constants = unpack(select(2, ...))
local Bubbles = Core:GetModule("Bubbles")

local LSM = Core.Libs.LSM

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local WorldFrame = WorldFrame
-- luacheck: pop

-- How often (in seconds) to scan the WorldFrame for chat bubbles while the feature
-- is enabled. We re-assert the font on each pass, so a snappy throttle keeps the
-- styling from briefly flashing the default font when a bubble first appears.
local SCAN_THROTTLE = 0.05

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

-- Applies the configured Glass font, size and outline to a bubble's text. This is
-- re-run on every pass because WoW 3.3.5 pools chat-bubble frames and resets the
-- text back to the default font whenever a frame is reused for a new message.
local function ApplyBubbleFont(fontString)
  fontString:SetFont(
    LSM:Fetch(LSM.MediaType.FONT, Core.db.profile.bubbleFont),
    Core.db.profile.bubbleFontSize,
    Core.db.profile.bubbleFontFlags
  )
  fontString:SetShadowColor(0, 0, 0, 1)
  fontString:SetShadowOffset(1, -1)
end

-- One-time cleanup for a freshly detected bubble: strip Blizzard's background and
-- border (this persists across reuse) and remember the text region for restyling.
local function StripBubble(frame)
  for i = 1, frame:GetNumRegions() do
    local region = select(i, frame:GetRegions())
    if region then
      local objectType = region:GetObjectType()
      if objectType == "Texture" then
        region:SetTexture(nil)
      elseif objectType == "FontString" then
        frame.glassText = region
      end
    end
  end

  if frame.SetBackdrop then
    frame:SetBackdrop(nil)
  end

  frame.glassStripped = true
end

-- Scans the WorldFrame's children for chat bubbles. New bubbles are stripped once;
-- the font is then re-asserted on every visible bubble each pass so reused frames
-- (which Blizzard resets back to the default font) keep the Glass styling.
local function ScanBubbles()
  local count = WorldFrame:GetNumChildren()
  for i = 1, count do
    local frame = select(i, WorldFrame:GetChildren())
    if frame then
      if not frame.glassStripped and IsChatBubble(frame) then
        StripBubble(frame)
      end

      if frame.glassStripped and frame.glassText and frame:IsShown() then
        ApplyBubbleFont(frame.glassText)
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

-- Turns the WorldFrame scanner on or off to match the saved setting. While the
-- scanner is hidden its OnUpdate never fires, so a disabled feature costs nothing.
function Bubbles:Update()
  if Core.db.profile.chatBubbles then
    self.scanner:Show()
  else
    self.scanner:Hide()
  end
end
