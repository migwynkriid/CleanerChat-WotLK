local Core, Constants = unpack(select(2, ...))

local MouseEnter = Constants.ACTIONS.MouseEnter
local MouseLeave = Constants.ACTIONS.MouseLeave

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local Mixin = Mixin
local MouseIsOver = MouseIsOver
-- luacheck: pop

local MainContainerFrameMixin = {}

function MainContainerFrameMixin:Init()
  self.state = {
    mouseOver = false,
    lastMouseCheck = 0,  -- Debounce timer
  }

  self:SetWidth(Core.db.profile.frameWidth)
  self:SetHeight(Core.db.profile.frameHeight)

  --[===[@debug@
  -- Helper to set solid color texture (3.3.5 compatibility)
  local function SetSolidColor(texture, r, g, b, a)
    if texture.SetColorTexture then
      texture:SetColorTexture(r, g, b, a)
    else
      texture:SetTexture("Interface\\Buttons\\WHITE8x8")
      texture:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    end
  end
  self.bg = self:CreateTexture(nil, "BACKGROUND")
  SetSolidColor(self.bg, 1, 0, 0, 0)
  self.bg:SetAllPoints()
  --@end-debug@]===]

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "frameWidth" then
      self:SetWidth(Core.db.profile.frameWidth)
    end

    if key == "frameHeight" then
      self:SetHeight(Core.db.profile.frameHeight)
    end
  end)
end

function MainContainerFrameMixin:OnFrame()
  -- Mouse over tracking
  local isOver = MouseIsOver(self)
  if self.state.mouseOver ~= isOver then
    if not self.state.mouseOver then
      Core:Dispatch(MouseEnter())
    else
      Core:Dispatch(MouseLeave())
    end

    self.state.mouseOver = not self.state.mouseOver
  end
end

Core.Components.CreateMainContainerFrame = function (name, parent)
  local frame = CreateFrame("Frame", name, parent)
  local object = Mixin(frame, MainContainerFrameMixin)
  object:Init()
  return object
end
