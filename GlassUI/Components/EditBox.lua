local Core, Constants = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook

local Colors = Constants.COLORS

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local Mixin = Mixin
-- luacheck: pop

local EditBoxMixin = {}

function EditBoxMixin:Init(parent)
  -- Hide default styling
  _G[self:GetName().."Left"]:Hide()
  _G[self:GetName().."Mid"]:Hide()
  _G[self:GetName().."Right"]:Hide()

  self:RawHook(_G[self:GetName().."Left"], "Show", function () end, true)
  self:RawHook(_G[self:GetName().."Mid"], "Show", function () end, true)
  self:RawHook(_G[self:GetName().."Right"], "Show", function () end, true)

  -- Note: Focus textures don't exist in WotLK 3.3.5, so we skip them

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

  self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 8, Core.db.profile.editBoxAnchor.yOfs)

  if Core.db.profile.editBoxAnchor.position == "ABOVE" then
    self:ClearAllPoints()
    self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 8, Core.db.profile.editBoxAnchor.yOfs)
  end

  self:SetFontObject("GlassEditBoxFont")
  self:SetWidth(Core.db.profile.frameWidth - 8 * 2)
  self.header:SetFontObject("GlassEditBoxFont")
  self.header:SetPoint("LEFT", 8, 0)

  local bg = self:CreateTexture(nil, "BACKGROUND")
  bg:SetColorTexture(
    Colors.codGray.r, Colors.codGray.g, Colors.codGray.b, Core.db.profile.editBoxBackgroundOpacity
  )
  bg:SetAllPoints()

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

  local Ypadding = GetFontHeight(self.header) * 0.66
  self:SetHeight(GetFontHeight(self.header) + Ypadding * 2)

  self:RawHook(self, "SetTextInsets", function ()
    Ypadding = GetFontHeight(self.header) * 0.66
    self.hooks[self].SetTextInsets(
      self,
      self.header:GetStringWidth() + 8,
      8, Ypadding, Ypadding
    )
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
  self:SetScript("OnShow", function ()
    self:SetAlpha(1)
  end)

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "font" or key == "editBoxFontSize" then
      Ypadding = GetFontHeight(self.header) * 0.66
      self:SetHeight(GetFontHeight(self.header) + Ypadding * 2)
      self:SetTextInsets()
    end

    if key == "frameWidth" then
      self:SetWidth(Core.db.profile.frameWidth - 8 * 2)
    end

    if key == "editBoxBackgroundOpacity" then
      bg:SetColorTexture(
        Colors.codGray.r, Colors.codGray.g, Colors.codGray.b, Core.db.profile.editBoxBackgroundOpacity
      )
    end

    if key == "editBoxAnchor" then
      if Core.db.profile.editBoxAnchor.position == "ABOVE" then
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 8, Core.db.profile.editBoxAnchor.yOfs)
      else
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 8, Core.db.profile.editBoxAnchor.yOfs)
      end
    end
  end)
end

Core.Components.CreateEditBox = function (parent)
  local object = Mixin(_G.ChatFrame1EditBox, EditBoxMixin)
  AceHook:Embed(object)
  object:Init(parent)
  return object
end
