local Core, Constants, Utils = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook
local LSM = Core.Libs.LSM

-- Dedicated AceHook host.
--
-- We must NOT embed AceHook directly onto the live Blizzard ChatFrame1EditBox.
-- AceHook:Embed() copies its mixin methods onto the target, and one of them --
-- HookScript -- overwrites the frame's native :HookScript with AceHook's
-- different signature (object, script, handler). Other addons (e.g. Ludwig)
-- still call the native editBox:HookScript("OnChar", handler), which then hits
-- AceHook's version and errors with "'object' - nil or table expected got
-- string". Hooking through this separate plain-table host lets us keep using
-- AceHook's RawHook while leaving the editbox's native methods untouched.
local Hooker = {}
AceHook:Embed(Hooker)

local Colors = Constants.COLORS

local EDIT_FOCUS_GAINED = Constants.EVENTS.EDIT_FOCUS_GAINED
local EDIT_FOCUS_LOST = Constants.EVENTS.EDIT_FOCUS_LOST
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local Mixin = Mixin
-- luacheck: pop

local EditBoxMixin = {}

function EditBoxMixin:Init(parent)
	-- Reparent the edit box out of the native chat frame.
	-- In FrameXML, ChatFrame1EditBox is defined as a child of ChatFrame1 (it is
	-- the template's "$parentEditBox"). The SlidingMessageFrame hides ChatFrame1
	-- to suppress the native message display (and its leaking embedded icons),
	-- but a child of a hidden frame cannot render -- so the edit box ended up
	-- focused and functional (chat still sent) yet invisible, flickering as
	-- Blizzard toggled the parent's visibility. Anchoring already targets the
	-- Glass container, so reparent to it as well to fully decouple from
	-- ChatFrame1's forced-hidden state. The fields chat code relies on
	-- (editBox.chatFrame, ChatFrame1.editBox) are set once at load and are not
	-- affected by SetParent, and ChatEdit_ChooseBoxForSend (classic style)
	-- returns DEFAULT_CHAT_FRAME.editBox, so sending is unaffected.
	self:SetParent(parent)

	-- New styling
	self:ClearAllPoints()
	-- WoW 3.3.5: explicitly set width to match the container (dual anchors may not work reliably on native edit boxes)
	self:SetWidth(self.profile.frameWidth)

	-- Offset by -1 to compensate for native ChatFrame1EditBox's inherent left offset
	self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", -1, self.profile.editBoxAnchor.yOfs)

	if self.profile.editBoxAnchor.position == "ABOVE" then
		self:ClearAllPoints()
		self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", -1, self.profile.editBoxAnchor.yOfs)
	end

	self:SetFontObject("GlassEditBoxFont")
	self.header:SetFontObject("GlassEditBoxFont")
	self.header:SetPoint("LEFT", 8, 0)

	-- Apply per-window font settings directly
	self:UpdateFontFromProfile()

	-- Solid colour texture helper (shared; SetColorTexture polyfilled in compat).
	local SetSolidColor = Utils.SetSolidColor

	self.bg = self:CreateTexture(nil, "BACKGROUND")
	local editBoxColor = self.profile.editBoxBackgroundColor or Colors.codGray
	SetSolidColor(self.bg, editBoxColor.r, editBoxColor.g, editBoxColor.b, self.profile.editBoxBackgroundOpacity)
	self.bg:SetAllPoints()

	-- Strip the native edit box skin. The original backport only hid the
	-- Left/Mid/Right background slices and assumed focus textures don't exist on
	-- 3.3.5 -- but this client draws extra textures (notably a gold focus
	-- outline, which Blizzard re-Shows every time the box gains focus) that sat
	-- on top of our background, so the gold border lingered and the
	-- editBoxBackgroundOpacity setting looked like it did nothing. Hide *every*
	-- texture region except our own bg and pin them hidden, so our bg is the
	-- only skin and its opacity is actually visible.
	for _, region in ipairs({ self:GetRegions() }) do
		if region ~= self.bg and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:Hide()
			Hooker:RawHook(region, "Show", function() end, true)
		end
	end

	-- Defensive: clear a bordered backdrop if this client skinned the edit box
	-- frame with one instead of (or in addition to) slice textures.
	if self.GetBackdrop and self:GetBackdrop() then
		self:SetBackdrop(nil)
	end

	-- WotLK compatibility: GetLineHeight may not exist, use GetStringHeight or fallback
	local function GetFontHeight(fontString)
		if fontString.GetLineHeight then
			return fontString:GetLineHeight()
		elseif fontString.GetStringHeight then
			local height = fontString:GetStringHeight()
			return height > 0 and height or 14
		else
			return 14 -- fallback
		end
	end

	local Ypadding = GetFontHeight(self.header) * Constants.EDITBOX_PADDING_RATIO
	self:SetHeight(GetFontHeight(self.header) + Ypadding * 2)

	Hooker:RawHook(self, "SetTextInsets", function()
		Ypadding = GetFontHeight(self.header) * Constants.EDITBOX_PADDING_RATIO
		Hooker.hooks[self].SetTextInsets(self, self.header:GetStringWidth() + 8, 8, Ypadding, Ypadding)
	end, true)

	self:SetTextInsets()

	-- Show/hide the edit box instantly.
	--
	-- This previously used intro/outro Alpha animations, but they caused a string
	-- of bugs on 3.3.5:
	--   1. The intro fade left the box invisible on the first open after a
	--      /reload. A 3.3.5 Alpha animation is a transient offset that reverts to
	--      the frame's base alpha when it finishes, and the first Play() could
	--      silently no-op -- so the box stayed shown but stuck at alpha 0.
	--   2. The outro fade deferred the real Hide() to the animation's OnFinished.
	--      Reopening right after sending a message let that still-pending hide
	--      tear the freshly reopened box back down ("pops up and closes", and the
	--      box deactivates so you cannot type/send).
	-- A chat input should appear and disappear instantly anyway, so we just drive
	-- alpha directly on show and let Hide() run natively (immediate). No
	-- animations means no deferred hide and no show/hide race.
	self:SetScript("OnShow", function()
		self:SetAlpha(1)
	end)

	-- When the edit box gains focus (user presses Enter or clicks), reveal the
	-- chat messages if the option is enabled. Scope the reveal to the window the
	-- edit box is currently attached to (set via AttachToWindow).
	local oldOnEditFocusGained = self:GetScript("OnEditFocusGained")
	self:SetScript("OnEditFocusGained", function(frame, ...)
		if self.profile.showOnEditFocus then
			Core:Dispatch(EDIT_FOCUS_GAINED, self.window)
		end
		if oldOnEditFocusGained then
			oldOnEditFocusGained(frame, ...)
		end
	end)

	-- When the edit box loses focus, start the fade out if showOnEditFocus is enabled.
	-- This ensures the mouseOver state is properly reset when typing is done.
	local oldOnEditFocusLost = self:GetScript("OnEditFocusLost")
	self:SetScript("OnEditFocusLost", function(frame, ...)
		if self.profile.showOnEditFocus then
			Core:Dispatch(EDIT_FOCUS_LOST, self.window)
		end
		if oldOnEditFocusLost then
			oldOnEditFocusLost(frame, ...)
		end
	end)

	Core:Subscribe(UPDATE_CONFIG, function(payload)
		local key = Core:ResolveConfigKey(payload, self.window and self.window.id or "Main")

		if key == nil then
			return
		end

		if key == "editBoxFont" or key == "editBoxFontSize" or key == "editBoxFontFlags" then
			self:UpdateFontFromProfile()
			Ypadding = GetFontHeight(self.header) * 0.66
			self:SetHeight(GetFontHeight(self.header) + Ypadding * 2)
			self:SetTextInsets()
		end

		if key == "frameWidth" then
			self:SetWidth(self.profile.frameWidth)
		end

		if key == "editBoxBackgroundOpacity" or key == "editBoxBackgroundColor" then
			self:UpdateBackgroundFromProfile()
		end

		if key == "editBoxAnchor" then
			-- Anchor relative to whichever window container the box is currently
			-- attached to (it follows the active window), not the original parent.
			local anchorParent = self:GetParent() or parent
			self:ClearAllPoints()
			self:SetWidth(self.profile.frameWidth)
			-- Offset by -1 to compensate for native ChatFrame1EditBox's inherent left offset
			if self.profile.editBoxAnchor.position == "ABOVE" then
				self:SetPoint("BOTTOMLEFT", anchorParent, "TOPLEFT", -1, self.profile.editBoxAnchor.yOfs)
			else
				self:SetPoint("TOPLEFT", anchorParent, "BOTTOMLEFT", -1, self.profile.editBoxAnchor.yOfs)
			end
		end
	end)
end

-- Re-attach the edit box to a different window's container (multi-window). The
-- single edit box "follows" the active window: clicking a window makes ENTER
-- open the box under that window and target that window for focus reveals.
function EditBoxMixin:AttachToWindow(parent, profile, window)
	self.profile = profile or self.profile
	self.window = window

	self:SetParent(parent)
	self:ClearAllPoints()
	self:SetWidth(self.profile.frameWidth)
	-- Offset by -1 to compensate for native ChatFrame1EditBox's inherent left offset
	if self.profile.editBoxAnchor.position == "ABOVE" then
		self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", -1, self.profile.editBoxAnchor.yOfs)
	else
		self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", -1, self.profile.editBoxAnchor.yOfs)
	end
	self.header:SetPoint("LEFT", 8, 0)
	self:SetTextInsets()

	-- Apply the new window's visual settings
	self:UpdateFontFromProfile()
	self:UpdateBackgroundFromProfile()
end

---
-- Apply font settings from the current window's profile directly.
-- This allows the edit box to use the active window's font settings.
function EditBoxMixin:UpdateFontFromProfile()
	local fontPath = LSM:Fetch(LSM.MediaType.FONT, self.profile.editBoxFont)
	local fontSize = self.profile.editBoxFontSize
	local fontFlags = self.profile.editBoxFontFlags

	if fontPath and fontSize then
		self:SetFont(fontPath, fontSize, fontFlags or "")
		if self.header then
			self.header:SetFont(fontPath, fontSize, fontFlags or "")
		end
	end
end

---
-- Apply background settings from the current window's profile.
-- This allows the edit box background to change when switching windows.
function EditBoxMixin:UpdateBackgroundFromProfile()
	if not self.bg then
		return
	end
	local color = self.profile.editBoxBackgroundColor or Colors.codGray
	local opacity = self.profile.editBoxBackgroundOpacity or 0.6
	if self.bg.SetColorTexture then
		self.bg:SetColorTexture(color.r, color.g, color.b, opacity)
	else
		self.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
		self.bg:SetVertexColor(color.r, color.g, color.b, opacity)
	end
end

Core.Components.CreateEditBox = function(parent, profile)
	local object = Mixin(_G.ChatFrame1EditBox, EditBoxMixin)
	-- Do NOT embed AceHook here -- use the module-level Hooker table instead.
	-- See comment at top of file for rationale.
	object.profile = profile or Core.db.profile
	object:Init(parent)
	return object
end
