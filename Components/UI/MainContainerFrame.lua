local Core, Constants = unpack(select(2, ...))

local MOUSE_ENTER = Constants.EVENTS.MOUSE_ENTER
local MOUSE_LEAVE = Constants.EVENTS.MOUSE_LEAVE

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
		lastMouseCheck = 0, -- Debounce timer
	}

	self:SetWidth(self.profile.frameWidth)
	self:SetHeight(self.profile.frameHeight)

	-- Enable mouse so clicking on the chat area sets focus to this window.
	self:EnableMouse(true)
	self:SetScript("OnMouseDown", function(frame, button)
		if button == "LeftButton" then
			local UIManager = Core:GetModule("UIManager", true)
			if UIManager and UIManager.SetActiveWindow and frame.window then
				UIManager:SetActiveWindow(frame.window)
			end
		end
	end)

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

	self.subscriptions = {
		Core:Subscribe(UPDATE_CONFIG, function(payload)
			local key = Core:ResolveConfigKey(payload, self.window and self.window.id or "Main")

			if key == nil then
				return
			end

			if key == "frameWidth" then
				self:SetWidth(self.profile.frameWidth)
			end

			if key == "frameHeight" then
				self:SetHeight(self.profile.frameHeight)
			end
		end),
	}
end

-- Unsubscribe the container's event-bus listeners when its window is deleted.
function MainContainerFrameMixin:Destroy()
	if self.subscriptions then
		for _, unsubscribe in ipairs(self.subscriptions) do
			if type(unsubscribe) == "function" then
				unsubscribe()
			end
		end
		self.subscriptions = nil
	end
end

function MainContainerFrameMixin:OnFrame()
	-- Mouse over tracking
	local isOver = MouseIsOver(self)
	if self.state.mouseOver ~= isOver then
		if not self.state.mouseOver then
			-- Scope the hover event to this window so only its messages/tabs react.
			Core:Dispatch(MOUSE_ENTER, self.window)
		else
			Core:Dispatch(MOUSE_LEAVE, self.window)
		end

		self.state.mouseOver = not self.state.mouseOver
	end
end

Core.Components.CreateMainContainerFrame = function(name, parent, profile)
	local frame = CreateFrame("Frame", name, parent)
	local object = Mixin(frame, MainContainerFrameMixin)
	object.profile = profile or Core.db.profile
	object:Init()
	return object
end
