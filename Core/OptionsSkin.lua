--[[

	OptionsSkin.lua

	Re-skins the /cc options window with CleanerChat's gold/dark Glass theme.

	CRITICAL: We must restore ALL modifications when the window closes, because
	AceGUI pools and reuses widgets. Any leftover styling bleeds into other addons.

	Strategy:
	1. Store references to ALL elements we modify BEFORE modifying them
	2. Store their original states (visibility, colors, backdrops, etc.)
	3. On window close, restore everything from stored references
	4. Use our own overlay frame for the visual theme (CleanerChat-owned, not pooled)

--]]
local _, ns = ...

-- Palette
local GOLD = { r = 223 / 255, g = 186 / 255, b = 105 / 255 }
local PANEL = { r = 0.035, g = 0.035, b = 0.045, a = 0.95 }
local INNER = { r = 0.065, g = 0.065, b = 0.080, a = 0.88 }
local BTN_BG = { r = 0.12, g = 0.12, b = 0.14, a = 0.90 }
local SOLID = "Interface\\Buttons\\WHITE8x8"

local EDGE_INSET = 8
local TITLE_HEIGHT = 32
local STATUS_HEIGHT = 24

local GlassBackdrop = {
	bgFile = SOLID,
	edgeFile = SOLID,
	tile = false,
	edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local ipairs, type = ipairs, type
local CLOSE = CLOSE or "Close"

-- Our overlay frame (owned by CleanerChat, never pooled)
local overlayFrame = nil

-- Store element references and their original states
-- Key = element reference, Value = table of {property = originalValue}
local elementStates = {}

local function applyGlass(frame, bg, borderAlpha)
	if (not frame) or not frame.SetBackdrop then
		return
	end
	frame:SetBackdrop(GlassBackdrop)
	frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
	frame:SetBackdropBorderColor(GOLD.r, GOLD.g, GOLD.b, borderAlpha or 0.35)
end

-- Store original state and hide an element
local function hideAndStore(element)
	if not element then
		return
	end
	if not elementStates[element] then
		elementStates[element] = { wasShown = element:IsShown() }
	end
	element:Hide()
end

-- Store original frame level
local function storeFrameLevel(frame)
	if not frame or not frame.GetFrameLevel then
		return
	end
	if not elementStates[frame] then
		elementStates[frame] = {}
	end
	if not elementStates[frame].frameLevel then
		elementStates[frame].frameLevel = frame:GetFrameLevel()
	end
end

-- Restore all stored elements to original states
local function restoreAllStates()
	for element, states in pairs(elementStates) do
		if element and type(element) == "table" then
			-- Restore visibility
			if states.wasShown ~= nil then
				if states.wasShown then
					if element.Show then
						element:Show()
					end
				end
			end
			-- Restore text color
			if states.textColor and element.SetTextColor then
				element:SetTextColor(unpack(states.textColor))
			end
			-- Restore font
			if states.font and element.SetFont then
				element:SetFont(unpack(states.font))
			end
			-- Restore frame level
			if states.frameLevel and element.SetFrameLevel then
				element:SetFrameLevel(states.frameLevel)
			end
		end
	end
	-- Clear for next use
	elementStates = {}
end

-- Create overlay frame (once, reused)
local function createOverlayFrame()
	if overlayFrame then
		return overlayFrame
	end

	overlayFrame = CreateFrame("Frame", "CleanerChatOptionsOverlay", UIParent)
	overlayFrame:Hide()
	applyGlass(overlayFrame, PANEL, 0.85)

	-- Title bar
	local titleBar = overlayFrame:CreateTexture(nil, "ARTWORK")
	titleBar:SetTexture(SOLID)
	titleBar:SetPoint("TOPLEFT", 1, -1)
	titleBar:SetPoint("TOPRIGHT", -1, -1)
	titleBar:SetHeight(TITLE_HEIGHT)
	titleBar:SetVertexColor(GOLD.r * 0.16, GOLD.g * 0.14, GOLD.b * 0.09, 0.95)
	overlayFrame.titleBar = titleBar

	local titleLine = overlayFrame:CreateTexture(nil, "OVERLAY")
	titleLine:SetTexture(SOLID)
	titleLine:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT")
	titleLine:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT")
	titleLine:SetHeight(1)
	titleLine:SetVertexColor(GOLD.r, GOLD.g, GOLD.b, 0.90)

	-- Status bar
	local statusBar = CreateFrame("Frame", nil, overlayFrame)
	statusBar:SetPoint("BOTTOMLEFT", 1, 1)
	statusBar:SetPoint("BOTTOMRIGHT", -1, 1)
	statusBar:SetHeight(STATUS_HEIGHT)
	applyGlass(statusBar, INNER, 0.50)
	overlayFrame.statusBar = statusBar

	local statusLine = overlayFrame:CreateTexture(nil, "OVERLAY")
	statusLine:SetTexture(SOLID)
	statusLine:SetPoint("BOTTOMLEFT", statusBar, "TOPLEFT")
	statusLine:SetPoint("BOTTOMRIGHT", statusBar, "TOPRIGHT")
	statusLine:SetHeight(1)
	statusLine:SetVertexColor(GOLD.r, GOLD.g, GOLD.b, 0.50)

	-- Left panel
	local leftPanel = CreateFrame("Frame", nil, overlayFrame)
	leftPanel:SetPoint("TOPLEFT", EDGE_INSET, -(TITLE_HEIGHT + EDGE_INSET))
	leftPanel:SetPoint("BOTTOMLEFT", EDGE_INSET, STATUS_HEIGHT + EDGE_INSET)
	leftPanel:SetWidth(175)
	applyGlass(leftPanel, INNER, 0.50)
	overlayFrame.leftPanel = leftPanel

	-- Right panel
	local rightPanel = CreateFrame("Frame", nil, overlayFrame)
	rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 4, 0)
	rightPanel:SetPoint("BOTTOMRIGHT", -EDGE_INSET, STATUS_HEIGHT + EDGE_INSET)
	applyGlass(rightPanel, INNER, 0.50)
	overlayFrame.rightPanel = rightPanel

	-- Title text
	local titleText = overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	titleText:SetPoint("CENTER", titleBar, "CENTER")
	titleText:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
	overlayFrame.titleText = titleText

	-- Close button
	local closeBtn = CreateFrame("Button", nil, statusBar)
	closeBtn:SetSize(60, STATUS_HEIGHT - 6)
	closeBtn:SetPoint("RIGHT", -6, 0)

	local btnBorder = closeBtn:CreateTexture(nil, "BACKGROUND")
	btnBorder:SetTexture(SOLID)
	btnBorder:SetAllPoints()
	btnBorder:SetVertexColor(GOLD.r, GOLD.g, GOLD.b, 0.40)

	local btnBg = closeBtn:CreateTexture(nil, "BORDER")
	btnBg:SetTexture(SOLID)
	btnBg:SetPoint("TOPLEFT", 1, -1)
	btnBg:SetPoint("BOTTOMRIGHT", -1, 1)
	btnBg:SetVertexColor(BTN_BG.r, BTN_BG.g, BTN_BG.b, BTN_BG.a)

	local btnText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	btnText:SetPoint("CENTER")
	btnText:SetText(CLOSE)
	btnText:SetTextColor(GOLD.r, GOLD.g, GOLD.b)

	closeBtn:SetScript("OnEnter", function()
		btnBg:SetVertexColor(GOLD.r * 0.30, GOLD.g * 0.28, GOLD.b * 0.20, 0.95)
		btnBorder:SetVertexColor(GOLD.r, GOLD.g, GOLD.b, 0.85)
	end)
	closeBtn:SetScript("OnLeave", function()
		btnBg:SetVertexColor(BTN_BG.r, BTN_BG.g, BTN_BG.b, BTN_BG.a)
		btnBorder:SetVertexColor(GOLD.r, GOLD.g, GOLD.b, 0.40)
	end)

	overlayFrame.closeBtn = closeBtn

	-- Status text
	local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	statusText:SetPoint("LEFT", 10, 0)
	statusText:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
	statusText:SetJustifyH("LEFT")
	statusText:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
	overlayFrame.statusText = statusText

	return overlayFrame
end

-- Find tree widget
local function findTree(widget)
	if not widget or not widget.children then
		return nil
	end
	for _, child in ipairs(widget.children) do
		if type(child) == "table" and child.treeframe then
			return child
		end
	end
	return nil
end

-- Find close button
local function findCloseButton(frame)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child.GetObjectType and child:GetObjectType() == "Button" then
			if child.GetText and child:GetText() == CLOSE then
				return child
			end
		end
	end
	return nil
end

-- Main skinning function
function ns.SkinOptionsWindow(widget)
	if not widget or not widget.frame then
		return
	end

	local f = widget.frame
	local overlay = createOverlayFrame()

	-- Position overlay over AceGUI window
	overlay:SetParent(f)
	overlay:ClearAllPoints()
	overlay:SetAllPoints(f)
	overlay:SetFrameLevel(f:GetFrameLevel() + 1)
	overlay:Show()

	-- Copy title to our overlay
	if widget.titletext then
		overlay.titleText:SetText(widget.titletext:GetText() or "CleanerChat")
	end

	-- Hide AceGUI's header elements (store first, then hide)
	if widget.titlebg then
		hideAndStore(widget.titlebg)
	end

	-- Hide header textures
	for _, region in ipairs({ f:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "Texture" then
			local tex = region.GetTexture and region:GetTexture()
			if type(tex) == "string" and tex:find("UI%-DialogBox%-Header") then
				hideAndStore(region)
			end
		end
	end

	-- Hide original title text (we show our own)
	if widget.titletext then
		hideAndStore(widget.titletext)
	end

	-- Hide original close button
	local origClose = findCloseButton(f)
	if origClose then
		hideAndStore(origClose)
		overlay.closeBtn:SetScript("OnClick", function()
			origClose:Click()
		end)
	end

	-- Hide original status text and copy to our overlay
	if widget.statustext then
		overlay.statusText:SetText(widget.statustext:GetText() or "")
		hideAndStore(widget.statustext)
	end

	-- Raise tree content above our overlay panels (store original levels first)
	local tree = findTree(widget)
	if tree then
		if tree.treeframe then
			storeFrameLevel(tree.treeframe)
			tree.treeframe:SetFrameLevel(overlay.leftPanel:GetFrameLevel() + 2)
		end
		if tree.border then
			storeFrameLevel(tree.border)
			tree.border:SetFrameLevel(overlay.rightPanel:GetFrameLevel() + 2)
		end
	end

	-- Hook OnHide to restore everything
	if not f.ccRestoreHooked then
		f.ccRestoreHooked = true
		f:HookScript("OnHide", function()
			-- Restore all modified elements
			restoreAllStates()
			-- Hide and detach overlay
			if overlayFrame then
				overlayFrame:Hide()
				overlayFrame:SetParent(UIParent)
			end
		end)
	end
end

-- Manual cleanup (also called on hide)
function ns.CleanupOptionsWindow(widget)
	restoreAllStates()
	if overlayFrame then
		overlayFrame:Hide()
	end
end
