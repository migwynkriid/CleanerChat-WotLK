local Core, Constants = unpack(select(2, ...))

local SaveFramePosition = Constants.ACTIONS.SaveFramePosition

local LOCK_MOVER = Constants.EVENTS.LOCK_MOVER
local UNLOCK_MOVER = Constants.EVENTS.UNLOCK_MOVER
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

local MoverFrameMixin = {}

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local Mixin = Mixin
-- luacheck: pop

function MoverFrameMixin:Init()
  local editBoxMargin = 35
  self:ClearAllPoints()
  self:SetPoint(
    Core.db.profile.positionAnchor.point,
    Core.db.profile.positionAnchor.xOfs,
    Core.db.profile.positionAnchor.yOfs
  )
  self:SetWidth(Core.db.profile.frameWidth)
  self:SetHeight(Core.db.profile.frameHeight + editBoxMargin)

  -- Gold accent used by the rest of the /cc theme (#DFBA69).
  local GOLD = { 223 / 255, 186 / 255, 105 / 255 }

  -- Subtle dark translucent fill so the drag region is clearly visible without
  -- the garish solid-green look. Tinted very slightly gold to match the theme.
  self.bg = self:CreateTexture(nil, "BACKGROUND")
  self.bg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.10)
  self.bg:SetAllPoints()

  -- Thin gold border on all four edges (1px WHITE8x8 tinted gold).
  local function makeEdge()
    local t = self:CreateTexture(nil, "BORDER")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.85)
    return t
  end
  local thickness = 2
  self.edgeTop = makeEdge()
  self.edgeTop:SetPoint("TOPLEFT")
  self.edgeTop:SetPoint("TOPRIGHT")
  self.edgeTop:SetHeight(thickness)

  self.edgeBottom = makeEdge()
  self.edgeBottom:SetPoint("BOTTOMLEFT")
  self.edgeBottom:SetPoint("BOTTOMRIGHT")
  self.edgeBottom:SetHeight(thickness)

  self.edgeLeft = makeEdge()
  self.edgeLeft:SetPoint("TOPLEFT")
  self.edgeLeft:SetPoint("BOTTOMLEFT")
  self.edgeLeft:SetWidth(thickness)

  self.edgeRight = makeEdge()
  self.edgeRight:SetPoint("TOPRIGHT")
  self.edgeRight:SetPoint("BOTTOMRIGHT")
  self.edgeRight:SetWidth(thickness)

  -- Centered move affordance: a small dark "card" with a move icon and a clear
  -- title + hint, so it stays readable over any chat background.
  self.plate = self:CreateTexture(nil, "ARTWORK")
  self.plate:SetTexture("Interface\\Buttons\\WHITE8X8")
  self.plate:SetVertexColor(0, 0, 0, 0.6)
  self.plate:SetPoint("CENTER")
  self.plate:SetSize(258, 50)

  self.moveIcon = self:CreateTexture(nil, "OVERLAY")
  self.moveIcon:SetTexture("Interface\\Minimap\\MiniMap-PositionArrows")
  self.moveIcon:SetSize(26, 26)
  self.moveIcon:SetPoint("LEFT", self.plate, "LEFT", 14, 0)
  self.moveIcon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)

  self.title = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  self.title:SetPoint("TOPLEFT", self.moveIcon, "TOPRIGHT", 12, 1)
  self.title:SetText("Move chat frame")
  self.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)

  self.hint = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.hint:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
  self.hint:SetText("Drag to reposition · Lock to save")
  self.hint:SetTextColor(0.8, 0.8, 0.8, 1)

  self:Hide()

  self:RegisterForDrag("LeftButton")
  self:SetScript("OnDragStart", self.StartMoving)
  self:SetScript("OnDragStop", self.StopMovingOrSizing)

  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(LOCK_MOVER, function ()
        self:Hide()
        self:EnableMouse(false)
        self:SetMovable(false)

        local point, _, _, xOfs, yOfs = self:GetPoint(1)
        local position = {
          point = point,
          xOfs = xOfs,
          yOfs = yOfs
        }

        Core:Dispatch(SaveFramePosition(position))
      end),
      Core:Subscribe(UNLOCK_MOVER, function ()
        self:Show()
        self:EnableMouse(true)
        self:SetMovable(true)
      end),
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if (key == "frameWidth") then
          self:SetWidth(Core.db.profile.frameWidth)
        end

        if (key == "frameHeight") then
          self:SetHeight(Core.db.profile.frameHeight + editBoxMargin)
        end

        if key == "framePosition" then
          self:ClearAllPoints()
          self:SetPoint(
            Core.db.profile.positionAnchor.point,
            Core.db.profile.positionAnchor.xOfs,
            Core.db.profile.positionAnchor.yOfs
          )
        end
      end),
    }
  end
end

Core.Components.CreateMoverFrame = function (name, parent)
  local frame = CreateFrame("Frame", name, parent)
  local object = Mixin(frame, MoverFrameMixin)
  object:Init()
  return object
end
