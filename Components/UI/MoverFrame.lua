local Core, Constants, Utils = unpack(select(2, ...))

local UpdateConfig = Constants.ACTIONS.UpdateConfig

local LOCK_MOVER = Constants.EVENTS.LOCK_MOVER
local UNLOCK_MOVER = Constants.EVENTS.UNLOCK_MOVER
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

local MoverFrameMixin = {}

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local Mixin = Mixin
-- luacheck: pop
local math_floor = math.floor

function MoverFrameMixin:Init()
	-- Reset destroyed flag in case this frame is being reused
	self._destroyed = nil

	local editBoxMargin = 35
	self:ClearAllPoints()
	self:SetPoint(self.profile.positionAnchor.point, self.profile.positionAnchor.xOfs, self.profile.positionAnchor.yOfs)
	self:SetWidth(self.profile.frameWidth)
	self:SetHeight(self.profile.frameHeight + editBoxMargin)

	-- Draw the mover above the chat (which sits at MEDIUM) so its move/resize
	-- card and corner grips stay visible even over a full chat window.
	self:SetFrameStrata("DIALOG")
	self:SetToplevel(true)

	-- Gold accent used by the rest of the /cc theme (#DFBA69).
	local GOLD = { 223 / 255, 186 / 255, 105 / 255 }

	-- Solid colour texture helper (shared; SetColorTexture polyfilled in compat).
	local SetSolidColor = Utils.SetSolidColor

	-- Subtle dark translucent fill so the drag region is clearly visible without
	-- the garish solid-green look. Tinted very slightly gold to match the theme.
	self.bg = self:CreateTexture(nil, "BACKGROUND")
	SetSolidColor(self.bg, GOLD[1], GOLD[2], GOLD[3], 0.10)
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

	-- Centered move affordance: a small dark "card" with a clear title + hint,
	-- so it stays readable over any chat background.
	self.plate = self:CreateTexture(nil, "ARTWORK")
	self.plate:SetTexture("Interface\\Buttons\\WHITE8X8")
	self.plate:SetVertexColor(0, 0, 0, 0.6)
	self.plate:SetPoint("CENTER")
	self.plate:SetSize(258, 50)

	self.title = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.title:SetPoint("TOPLEFT", self.plate, "TOPLEFT", 16, -10)
	self.title:SetText("Move chat frame")
	self.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)

	self.hint = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.hint:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
	self.hint:SetText("Drag to move · Corners to resize · Lock to save")
	self.hint:SetTextColor(0.8, 0.8, 0.8, 1)

	self:Hide()

	self:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", self.StartMoving)
	self:SetScript("OnDragStop", self.StopMovingOrSizing)

	-- Corner resize handles: drag any corner to adjust the chat frame's width and
	-- height. The mover frame itself is the resize target; on release we read its
	-- new size back into frameWidth/frameHeight and dispatch UPDATE_CONFIG so the
	-- chat frame and all its parts resize to match. Position is saved on Lock.
	self:SetResizable(true)
	if self.SetMinResize then
		self:SetMinResize(100, 80)
	end
	if self.SetMaxResize then
		self:SetMaxResize(4000, 3000)
	end

	if self.resizeHandles == nil then
		-- Push the mover's current size into the config and resize the chat frame
		-- (and all its parts) to match. Called LIVE during a corner drag (via
		-- OnSizeChanged) so the chat resizes continuously, not just on release.
		-- The integer-change guards avoid redundant dispatches.
		-- Throttled to reduce lag during resize (dispatch at most every 0.1s).
		local lastDispatchTime = 0
		local THROTTLE_INTERVAL = 0.1

		local function syncMoverSize(force)
			local now = GetTime()
			if (not force) and (now - lastDispatchTime < THROTTLE_INTERVAL) then
				return -- throttled
			end

			local newWidth = math_floor(self:GetWidth() + 0.5)
			local newHeight = math_floor(self:GetHeight() - editBoxMargin + 0.5)
			if newWidth < 100 then
				newWidth = 100
			end
			if newHeight < 1 then
				newHeight = 1
			end

			local changed = false
			if self.profile.frameWidth ~= newWidth then
				self.profile.frameWidth = newWidth
				changed = true
			end
			if self.profile.frameHeight ~= newHeight then
				self.profile.frameHeight = newHeight
				changed = true
			end

			if changed then
				lastDispatchTime = now
				Core:Dispatch(UpdateConfig("frameWidth"))
				Core:Dispatch(UpdateConfig("frameHeight"))
			end
		end

		-- Resize live while a corner is dragged. self.isSizing gates this so the
		-- config-driven SetWidth/SetHeight (slider, Init) don't re-trigger it.
		self:SetScript("OnSizeChanged", function()
			if self.isSizing then
				syncMoverSize(false)
			end
		end)

		-- Diagonal resize-grip art (the chat window's size grabber), flipped per
		-- corner so each points outward toward its corner -- reads as a resize
		-- arrow instead of a plain square.
		local gripTexCoords = {
			TOPLEFT = { 1, 0, 1, 0 },
			TOPRIGHT = { 0, 1, 1, 0 },
			BOTTOMLEFT = { 1, 0, 0, 1 },
			BOTTOMRIGHT = { 0, 1, 0, 1 },
		}

		local function makeResizeHandle(point)
			local handle = CreateFrame("Frame", nil, self)
			handle:SetSize(24, 24)
			handle:SetPoint(point, self, point, 0, 0)
			handle:SetFrameLevel(self:GetFrameLevel() + 5)
			handle:EnableMouse(true)

			local tex = handle:CreateTexture(nil, "OVERLAY")
			tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
			local tc = gripTexCoords[point]
			tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
			-- Bright warm-white at full opacity so the grips read clearly against the
			-- dark chat background and the gold border (gold-on-gold was too faint).
			tex:SetVertexColor(1, 0.92, 0.72, 1)
			tex:SetAllPoints()

			handle:SetScript("OnMouseDown", function()
				self.isSizing = true
				self:StartSizing(point)
			end)
			handle:SetScript("OnMouseUp", function()
				self:StopMovingOrSizing()
				self.isSizing = false
				syncMoverSize(true) -- force final sync on release
			end)
			handle:SetScript("OnEnter", function()
				tex:SetVertexColor(1, 1, 1, 1)
			end)
			handle:SetScript("OnLeave", function()
				tex:SetVertexColor(1, 0.92, 0.72, 1)
			end)
			return handle
		end

		self.resizeHandles = {
			makeResizeHandle("TOPLEFT"),
			makeResizeHandle("TOPRIGHT"),
			makeResizeHandle("BOTTOMLEFT"),
			makeResizeHandle("BOTTOMRIGHT"),
		}
	end

	if self.subscriptions == nil then
		self.subscriptions = {
			Core:Subscribe(LOCK_MOVER, function()
				-- Skip if this frame has been destroyed
				if self._destroyed then
					return
				end

				self:Hide()
				self:EnableMouse(false)
				self:SetMovable(false)

				local point, _, _, xOfs, yOfs = self:GetPoint(1)
				-- Save position to this window's profile (multi-window aware)
				self.profile.positionAnchor = {
					point = point,
					xOfs = xOfs,
					yOfs = yOfs,
				}
			end),
			Core:Subscribe(UNLOCK_MOVER, function()
				-- Skip if this frame has been destroyed
				if self._destroyed then
					return
				end

				self:Show()
				self:EnableMouse(true)
				self:SetMovable(true)
			end),
			Core:Subscribe(UPDATE_CONFIG, function(payload)
				-- Skip if this frame has been destroyed
				if self._destroyed then
					return
				end

				local key = Core:ResolveConfigKey(payload, self.window and self.window.id or "Main")

				if key == nil then
					return
				end

				if key == "frameWidth" then
					if not self.isSizing then
						self:SetWidth(self.profile.frameWidth)
					end
				end

				if key == "frameHeight" then
					if not self.isSizing then
						self:SetHeight(self.profile.frameHeight + editBoxMargin)
					end
				end

				if key == "framePosition" then
					self:ClearAllPoints()
					self:SetPoint(
						self.profile.positionAnchor.point,
						self.profile.positionAnchor.xOfs,
						self.profile.positionAnchor.yOfs
					)
				end
			end),
		}
	end
end

-- Update the mover's title to show which window it belongs to.
-- Called after the window reference is set on the moverFrame.
function MoverFrameMixin:SetWindowLabel(windowId)
	local label
	if windowId and windowId ~= "Main" then
		-- Convert "Window2" to "Window 2"
		local num = windowId:match("Window(%d+)")
		if num then
			label = "Move chat frame - Window " .. num
		else
			label = "Move chat frame - " .. windowId
		end
	else
		label = "Move chat frame - Main"
	end
	self.title:SetText(label)

	-- Resize the plate to fit the new title
	local plateText = math.max(self.title:GetStringWidth(), self.hint:GetStringWidth())
	self.plate:SetWidth(math.max(32 + plateText, 180))
end

-- Clean up subscriptions and hide the frame. Called when the owning window is deleted.
function MoverFrameMixin:Destroy()
	-- Mark as destroyed so any lingering event handlers can skip this frame
	self._destroyed = true

	-- Unsubscribe from all events
	if self.subscriptions then
		for _, unsubscribe in ipairs(self.subscriptions) do
			if type(unsubscribe) == "function" then
				unsubscribe()
			end
		end
		self.subscriptions = nil
	end
	-- Hide and disable
	self:Hide()
	self:EnableMouse(false)
	self:SetMovable(false)
end

Core.Components.CreateMoverFrame = function(name, parent, profile)
	local frame = CreateFrame("Frame", name, parent)
	local object = Mixin(frame, MoverFrameMixin)
	object.profile = profile or Core.db.profile
	object:Init()
	return object
end
