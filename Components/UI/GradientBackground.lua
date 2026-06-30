local Core = unpack(select(2, ...))

local GradientBackgroundMixin = {}

function GradientBackgroundMixin:Init() end

function GradientBackgroundMixin:SetGradientBackground(leftWidth, rightWidth, color, opacity)
	-- WotLK 3.3.5: Simplified background without gradient edges
	-- The gradient effect doesn't work reliably in WotLK, so we use a simple solid background

	-- Hide left gradient (not reliable in WotLK)
	if self.leftBg == nil then
		self.leftBg = self:CreateTexture(nil, "BACKGROUND")
		self.leftBg:SetPoint("TOPLEFT")
		self.leftBg:SetPoint("BOTTOMLEFT")
	end
	self.leftBg:SetWidth(0) -- Hide by setting width to 0
	self.leftBg:Hide()

	-- Hide right gradient (not reliable in WotLK)
	if self.rightBg == nil then
		self.rightBg = self:CreateTexture(nil, "BACKGROUND")
		self.rightBg:SetPoint("TOPRIGHT")
		self.rightBg:SetPoint("BOTTOMRIGHT")
	end
	self.rightBg:SetWidth(0) -- Hide by setting width to 0
	self.rightBg:Hide()

	-- Full-width solid background
	if self.centerBg == nil then
		self.centerBg = self:CreateTexture(nil, "BACKGROUND")
		self.centerBg:SetAllPoints() -- Cover the entire frame
		self.centerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
	end
	-- Solid color background
	self.centerBg:SetVertexColor(color.r, color.g, color.b, opacity)
	self.centerBg:Show()
end

Core.Components.GradientBackgroundMixin = GradientBackgroundMixin
