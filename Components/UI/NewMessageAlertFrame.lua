local Core, Constants = unpack(select(2, ...))

local Colors = Constants.COLORS

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local Mixin = Mixin
-- luacheck: pop

local NewMessageAlertFrameMixin = {}

function NewMessageAlertFrameMixin:Init()
	self:SetHeight(20)
	self:SetPoint("BOTTOMLEFT")
	self:SetPoint("BOTTOMRIGHT")
	self:SetFadeInDuration(0.15)
	self:SetFadeOutDuration(0.15)

	-- New messages text
	if self.text == nil then
		self.text = self:CreateFontString(nil, "ARTWORK", "GlassMessageFont")
	end
	-- Use customizable color and opacity (defaults to apache gold, fully solid).
	local indicatorColor = self.profile.scrollIndicatorColor or Colors.apache
	local indicatorOpacity = self.profile.scrollIndicatorOpacity or 1
	self.text:SetTextColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, indicatorOpacity)
	self.text:SetPoint("BOTTOMLEFT", 30, 10)
	self.text:SetText("Unread messages")

	-- Alert line
	if self.bottomLine == nil then
		local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin

		self.bottomLine = CreateFrame("Frame", nil, self)
		self.bottomLine = Mixin(self.bottomLine, GradientBackgroundMixin)
		GradientBackgroundMixin.Init(self.bottomLine)
		self.bottomLine:SetHeight(1)
		self.bottomLine:SetPoint("BOTTOMLEFT")
		self.bottomLine:SetPoint("BOTTOMRIGHT")
	end
	-- Use the same color for the line, with 0.65 alpha multiplied by the user opacity
	local lineOpacity = 0.65 * indicatorOpacity
	self.bottomLine:SetGradientBackground(15, 15, indicatorColor, lineOpacity)
end

function NewMessageAlertFrameMixin:UpdateIndicatorStyle()
	local indicatorColor = self.profile.scrollIndicatorColor or Colors.apache
	local indicatorOpacity = self.profile.scrollIndicatorOpacity or 1
	if self.text then
		self.text:SetTextColor(indicatorColor.r, indicatorColor.g, indicatorColor.b, indicatorOpacity)
	end
	if self.bottomLine then
		local lineOpacity = 0.65 * indicatorOpacity
		self.bottomLine:SetGradientBackground(15, 15, indicatorColor, lineOpacity)
	end
end

local function CreateNewMessageAlertFrame(parent, profile)
	local FadingFrameMixin = Core.Components.FadingFrameMixin

	local frame = CreateFrame("Frame", nil, parent)
	local object = Mixin(frame, FadingFrameMixin, NewMessageAlertFrameMixin)

	object.profile = profile or Core.db.profile
	FadingFrameMixin.Init(object)
	NewMessageAlertFrameMixin.Init(object)

	return object
end

Core.Components.CreateNewMessageAlertFrame = CreateNewMessageAlertFrame
