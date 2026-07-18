local Core, Constants = unpack(select(2, ...))
local Fonts = Core:GetModule("Fonts")

local LSM = Core.Libs.LSM

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local CreateFont = CreateFont
-- luacheck: pop

function Fonts:OnInitialize()
	-- Only create the table if it doesn't already exist, so a defensive early
	-- SetupFonts() call (e.g. from UIManager) can't have its font objects wiped.
	self.fonts = self.fonts or {}
	-- Create the shared font objects during initialization so they exist before
	-- ANY module's OnEnable builds frames that inherit them. Module enable order is
	-- not guaranteed: when a higher-versioned AceAddon from another addon (e.g. DBM)
	-- wins the LibStub race, it can enable UIManager before Fonts, which previously
	-- crashed with "Couldn't find inherited node GlassMessageFont".
	self:SetupFonts()
end

-- Create the shared FontObjects the chat frames inherit from. Idempotent: once
-- the objects exist the call is a no-op, so OnInitialize and OnEnable can both
-- call it safely regardless of which runs first.
function Fonts:SetupFonts()
	self.fonts = self.fonts or {}
	-- Skip only after a PREVIOUS call fully finished (flag set at the very end).
	-- Gating on the font objects merely existing isn't enough: each object is
	-- assigned before its SetFont args (Core.db.profile.*) are evaluated, so an
	-- error partway could leave the objects created but NOT configured with the
	-- real font -- and we'd then never re-apply it.
	if self.fontsConfigured then
		return
	end

	-- GlassMessageFont
	self.fonts.GlassMessageFont = _G.GlassMessageFont or CreateFont("GlassMessageFont")
	self.fonts.GlassMessageFont:SetFont(
		LSM:Fetch(LSM.MediaType.FONT, Core.db.profile.messageFont),
		Core.db.profile.messageFontSize,
		Core.db.profile.messageFontFlags
	)
	self.fonts.GlassMessageFont:SetShadowColor(0, 0, 0, 1)
	self.fonts.GlassMessageFont:SetShadowOffset(1, -1)
	self.fonts.GlassMessageFont:SetJustifyH("LEFT")
	self.fonts.GlassMessageFont:SetJustifyV("MIDDLE")
	self.fonts.GlassMessageFont:SetSpacing(Core.db.profile.messageLeading)

	-- GlassChatDockFont
	self.fonts.GlassChatDockFont = _G.GlassChatDockFont or CreateFont("GlassChatDockFont")
	self.fonts.GlassChatDockFont:SetFont(
		LSM:Fetch(LSM.MediaType.FONT, Core.db.profile.dockFont),
		Core.db.profile.dockFontSize,
		Core.db.profile.dockFontFlags
	)
	self.fonts.GlassChatDockFont:SetShadowColor(0, 0, 0, 0)
	self.fonts.GlassChatDockFont:SetShadowOffset(1, -1)
	self.fonts.GlassChatDockFont:SetJustifyH("LEFT")
	self.fonts.GlassChatDockFont:SetJustifyV("MIDDLE")
	self.fonts.GlassChatDockFont:SetSpacing(3)

	-- GlassEditBoxFont
	self.fonts.GlassEditBoxFont = _G.GlassEditBoxFont or CreateFont("GlassEditBoxFont")
	self.fonts.GlassEditBoxFont:SetFont(
		LSM:Fetch(LSM.MediaType.FONT, Core.db.profile.editBoxFont),
		Core.db.profile.editBoxFontSize,
		Core.db.profile.editBoxFontFlags
	)
	self.fonts.GlassEditBoxFont:SetShadowColor(0, 0, 0, 0)
	self.fonts.GlassEditBoxFont:SetShadowOffset(1, -1)
	self.fonts.GlassEditBoxFont:SetJustifyH("LEFT")
	self.fonts.GlassEditBoxFont:SetJustifyV("MIDDLE")
	self.fonts.GlassEditBoxFont:SetSpacing(3)

	-- Every font is now created AND fully configured -- only now is it safe for
	-- future calls to skip the work above.
	self.fontsConfigured = true
end

function Fonts:OnEnable()
	-- Fonts are created in OnInitialize; ensure they exist in case OnEnable runs
	-- first under an unexpected module lifecycle.
	self:SetupFonts()

	Core:Subscribe(UPDATE_CONFIG, function(_)
		-- Note: All fonts (Message, EditBox, Dock) are now set directly per-window
		-- by their respective components (MessageLine, EditBox, ChatTab).
		-- The global FontObjects are still used as templates for initial creation,
		-- but we don't update them here to avoid affecting all windows at once.
	end)
end

-- Register the shared FontObjects the instant this file loads -- before ANY Ace
-- lifecycle (OnInitialize/OnEnable) runs -- so their NAMES always exist and a
-- frame that inherits them can never fail with "Couldn't find inherited node
-- GlassMessageFont". This is the last line of defence for the module-enable-order
-- race: another addon's higher-versioned AceAddon (DBM, CooldownCount,
-- ThreatPlates, ...) can win the shared LibStub and enable our UIManager module
-- before Fonts. The real font face/size/spacing are applied later in SetupFonts()
-- once the saved settings exist; here we only guarantee the objects exist with a
-- safe placeholder so frame creation can never crash.
do
	local placeholder = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	for _, fontName in ipairs({ "GlassMessageFont", "GlassChatDockFont", "GlassEditBoxFont" }) do
		if not _G[fontName] then
			local fontObject = CreateFont(fontName)
			if fontObject then
				fontObject:SetFont(placeholder, 14)
			end
		end
	end
end
