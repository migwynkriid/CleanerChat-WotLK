local Core = unpack(select(2, ...))
local ns = select(2, ...) -- Get raw namespace for ns.Timer access

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local Mixin = Mixin
-- luacheck: pop

-- Timer helper: use internal ns.Timer or native C_Timer
local function GetTimer()
	return ns.Timer or _G.C_Timer
end

local LibEasing = Core.Libs.LibEasing

local FadingFrameMixin = {}

-- Helper function to safely set animation alpha
local function SafeSetAlphaAnimation(anim, fromAlpha, toAlpha)
	-- Store the target values for reference
	anim._fromAlpha = fromAlpha
	anim._toAlpha = toAlpha

	-- Try modern API first (SetFromAlpha/SetToAlpha)
	if anim.SetFromAlpha and anim.SetToAlpha then
		anim:SetFromAlpha(fromAlpha)
		anim:SetToAlpha(toAlpha)
	-- Fall back to WotLK API (SetChange)
	elseif anim.SetChange then
		anim:SetChange(toAlpha - fromAlpha)
	end

	-- Try to set smoothing if available
	if anim.SetSmoothing then
		anim:SetSmoothing("OUT")
	end
end

-- Store original Frame methods (WotLK compatibility)
local FramePrototype = getmetatable(CreateFrame("Frame")).__index
local Frame_Show = FramePrototype.Show
local Frame_Hide = FramePrototype.Hide

function FadingFrameMixin:Init()
	if self.showAg == nil then
		self.showAg = self:CreateAnimationGroup()
		self.fadeIn = self.showAg:CreateAnimation("Alpha")
		SafeSetAlphaAnimation(self.fadeIn, 0, 1)
		self.fadeIn:SetDuration(0)

		-- In WotLK, we need to set alpha to 1 after fade-in completes
		self.showAg:SetScript("OnFinished", function()
			self:SetAlpha(1)
		end)
	end

	if self.hideAg == nil then
		self.hideAg = self:CreateAnimationGroup()
		self.fadeOut = self.hideAg:CreateAnimation("Alpha")
		SafeSetAlphaAnimation(self.fadeOut, 1, 0)
		self.fadeOut:SetDuration(0)

		self.hideAg:SetScript("OnFinished", function()
			self:SetAlpha(1) -- Reset alpha before hiding
			self:QuickHide()
		end)
	end
end

function FadingFrameMixin:QuickShow()
	self:StopAnimating()

	if self.fadeHandle and LibEasing then
		LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end

	if self.hideTimer ~= nil then
		self.hideTimer:Cancel()
		self.hideTimer = nil
	end

	self:SetAlpha(1)
	Frame_Show(self)
end

function FadingFrameMixin:QuickHide()
	if self.fadeHandle and LibEasing then
		LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end

	if self.hideTimer ~= nil then
		self.hideTimer:Cancel()
		self.hideTimer = nil
	end

	self:SetAlpha(1)
	Frame_Hide(self)
end

function FadingFrameMixin:Show()
	-- Cancel any pending hide / in-flight fade-out so a re-shown (e.g.
	-- moused-over) line snaps back to full opacity instead of continuing to fade.
	if self.hideTimer ~= nil then
		self.hideTimer:Cancel()
		self.hideTimer = nil
	end

	if self.fadeHandle and LibEasing then
		LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end

	self:StopAnimating()
	self:SetAlpha(1) -- Ensure fully visible
	if not self:IsVisible() then
		Frame_Show(self)
	end
	-- Fade-in itself is driven by the SlidingMessageFrame slide animation.
end

-- Fade in with animation (for hover/focus reveal)
function FadingFrameMixin:FadeIn(duration)
	-- Cancel any pending hide / in-flight fade
	if self.hideTimer ~= nil then
		self.hideTimer:Cancel()
		self.hideTimer = nil
	end

	if self.fadeHandle and LibEasing then
		LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end

	self:StopAnimating()

	duration = duration or (self.fadeInDuration or 0.3)
	local startAlpha = self:GetAlpha()

	if not self:IsVisible() then
		self:SetAlpha(0)
		startAlpha = 0
		Frame_Show(self)
	end

	if duration > 0 and startAlpha < 1 and LibEasing then
		self.fadeHandle = LibEasing:Ease(
			function(alpha)
				self:SetAlpha(alpha)
			end,
			startAlpha,
			1,
			duration,
			LibEasing.OutCubic,
			function()
				self.fadeHandle = nil
				self:SetAlpha(1)
			end
		)
	else
		self:SetAlpha(1)
	end
end

function FadingFrameMixin:Hide()
	if self.hideTimer ~= nil then
		self.hideTimer:Cancel()
		self.hideTimer = nil
	end

	if not self:IsVisible() then
		return
	end

	if self.fadeHandle and LibEasing then
		LibEasing:StopEasing(self.fadeHandle)
		self.fadeHandle = nil
	end

	-- Fade the alpha out over the configured duration, then hide for real. The
	-- AnimationGroup approach is unreliable on 3.3.5 (OnFinished can fail to
	-- fire, leaving frames stuck), so drive the fade with LibEasing -- the same
	-- approach the chat dock uses.
	local duration = self.fadeOutDuration or 0
	if duration > 0 and LibEasing then
		self.fadeHandle = LibEasing:Ease(
			function(alpha)
				self:SetAlpha(alpha)
			end,
			self:GetAlpha(),
			0,
			duration,
			LibEasing.OutCubic,
			function()
				self.fadeHandle = nil
				Frame_Hide(self)
				self:SetAlpha(1)
			end
		)
	else
		self:SetAlpha(1)
		Frame_Hide(self)
	end
end

function FadingFrameMixin:HideDelay(delay)
	-- Ensure valid delay
	delay = delay or 10
	if delay < 1 then
		delay = 10 -- Default to 10 seconds
	end

	if self:IsVisible() then
		if self.hideTimer ~= nil then
			self.hideTimer:Cancel()
		end

		local Timer = GetTimer()
		if Timer and Timer.NewTimer then
			self.hideTimer = Timer.NewTimer(delay, function()
				self:Hide()
			end)
		else
			-- Fallback: hide immediately if no timer available
			self:Hide()
		end
	end
end

function FadingFrameMixin:SetFadeInDuration(duration)
	self.fadeInDuration = duration
	self.fadeIn:SetDuration(duration)
end

function FadingFrameMixin:SetFadeOutDuration(duration)
	self.fadeOutDuration = duration
	self.fadeOut:SetDuration(duration)
end

local function CreateFadingFrame(frameType, name, parent)
	local frame = CreateFrame(frameType, name, parent)
	local object = Mixin(frame, FadingFrameMixin)
	object:Init()
	return object
end

Core.Components.CreateFadingFrame = CreateFadingFrame
Core.Components.FadingFrameMixin = FadingFrameMixin
