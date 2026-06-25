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

-- Frames we have touched, tracked so the feature can restore them all when it is
-- switched off (Blizzard pools bubble frames, so an altered frame is reused).
local trackedBubbles = {}

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

-- Remembers a bubble's original backdrop, colours and font the first time we see
-- it, so disabling the feature can restore Blizzard's default look exactly.
local function RememberBubble(frame)
  frame.glassBackdrop = frame:GetBackdrop()
  frame.glassBackdropColor = { frame:GetBackdropColor() }
  frame.glassBackdropBorderColor = { frame:GetBackdropBorderColor() }

  for i = 1, frame:GetNumRegions() do
    local region = select(i, frame:GetRegions())
    if region and region:GetObjectType() == "FontString" then
      frame.glassText = region
      frame.glassFont = { region:GetFont() }
      break
    end
  end

  frame.glassRemembered = true
  trackedBubbles[#trackedBubbles + 1] = frame
end

-- Hides the Blizzard bubble graphic (its backdrop and any textures) and applies
-- the Glass font. Re-run each pass because a reused frame is reset to defaults.
local function StyleBubble(frame)
  if frame.SetBackdrop then
    frame:SetBackdrop(nil)
  end
  for i = 1, frame:GetNumRegions() do
    local region = select(i, frame:GetRegions())
    if region and region:GetObjectType() == "Texture" then
      region:Hide()
    end
  end
  if frame.glassText then
    ApplyBubbleFont(frame.glassText)
  end
end

-- Restores every bubble we have touched back to Blizzard's default appearance.
local function RestoreBubbles()
  for _, frame in ipairs(trackedBubbles) do
    if frame.glassRemembered and frame.SetBackdrop then
      frame:SetBackdrop(frame.glassBackdrop)
      if frame.glassBackdrop then
        local c = frame.glassBackdropColor
        if c[1] then frame:SetBackdropColor(c[1], c[2], c[3], c[4]) end
        local b = frame.glassBackdropBorderColor
        if b[1] then frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4]) end
      end
      for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region:GetObjectType() == "Texture" then
          region:Show()
        end
      end
      if frame.glassText and frame.glassFont and frame.glassFont[1] then
        frame.glassText:SetFont(frame.glassFont[1], frame.glassFont[2], frame.glassFont[3])
      end
    end
  end
end

-- Scans the WorldFrame's children for chat bubbles. Each one is remembered once,
-- then re-styled on every visible pass so reused frames (which Blizzard resets to
-- the default look) keep the Glass styling.
local function ScanBubbles()
  local count = WorldFrame:GetNumChildren()
  for i = 1, count do
    local frame = select(i, WorldFrame:GetChildren())
    if frame then
      if not frame.glassRemembered and IsChatBubble(frame) then
        RememberBubble(frame)
      end

      if frame.glassRemembered and frame:IsShown() then
        StyleBubble(frame)
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
