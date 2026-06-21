local Core, Constants = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook
local LibEasing = Core.Libs.LibEasing

local Colors = Constants.COLORS

local EDIT_FOCUS_GAINED = Constants.EVENTS.EDIT_FOCUS_GAINED
local EDIT_FOCUS_LOST = Constants.EVENTS.EDIT_FOCUS_LOST
local MOUSE_ENTER = Constants.EVENTS.MOUSE_ENTER
local MOUSE_LEAVE = Constants.EVENTS.MOUSE_LEAVE
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local Mixin = Mixin
local CreateFrame = CreateFrame
local FCFDock_GetInsertIndex = FCFDock_GetInsertIndex
local FCFDock_HideInsertHighlight = FCFDock_HideInsertHighlight
local FCF_DockFrame = FCF_DockFrame
local GENERAL_CHAT_DOCK = GENERAL_CHAT_DOCK
local GetCursorPosition = GetCursorPosition
local UIParent = UIParent
-- luacheck: pop

-- Raw native Hide, bypassing the animated FadingFrameMixin:Hide() that this
-- frame mixes in. The tab dock runs its OWN LibEasing fade-out; when that fade
-- finishes it must hide the frame for real. Calling self:Hide() there invoked
-- FadingFrameMixin:Hide(), which started a SECOND alpha fade, and the following
-- SetAlpha(1) then flashed the fully-opaque tabs back for a frame before they
-- disappeared again. Use the raw Hide so the dock just hides, no re-fade.
local Frame_Hide = getmetatable(CreateFrame("Frame")).__index.Hide

local ChatDockMixin = {}

function ChatDockMixin:Init(parent)
  self.state = {
    mouseOver = false
  }

  self:SetWidth(Core.db.profile.frameWidth)
  self:SetHeight(Constants.DOCK_HEIGHT)
  self:ClearAllPoints()
  self:SetPoint("TOPLEFT", parent, "TOPLEFT")
  self:SetFrameStrata("MEDIUM")  -- Ensure dock is visible above chat frames
  self:SetFrameLevel(10)
  self:SetFadeInDuration(0.6)
  self:SetFadeOutDuration(0.6)

  -- Note: In WotLK 3.3.5, GeneralDockManager doesn't exist
  -- We create our own dock frame instead

  -- Gradient background. Opacity is user-configurable via the Top Bar settings.
  self:SetGradientBackground(50, 250, Colors.black, Core.db.profile.dockBackgroundOpacity or 0.4)

  -- Override drag behaviour
  -- Disable undocking frames (if GENERAL_CHAT_DOCK exists)
  if GENERAL_CHAT_DOCK and FCFDock_HideInsertHighlight and FCFDock_GetInsertIndex and FCF_DockFrame then
    self:RawHook("FCF_StopDragging", function (chatFrame)
      chatFrame:StopMovingOrSizing();
      _G[chatFrame:GetName().."Tab"]:UnlockHighlight();

      FCFDock_HideInsertHighlight(GENERAL_CHAT_DOCK);

      local mouseX, mouseY = GetCursorPosition();
      mouseX, mouseY = mouseX / UIParent:GetScale(), mouseY / UIParent:GetScale();
      FCF_DockFrame(chatFrame, FCFDock_GetInsertIndex(GENERAL_CHAT_DOCK, chatFrame, mouseX, mouseY), true);
    end, true)
  end

  -- Show the dock initially, then fade the tabs out after the hold time
  -- (only if tabsOnHover is enabled).
  self:Show()
  self:SetAlpha(1)
  if Core.db.profile.tabsOnHover then
    self:FadeOutTabs()
  end

  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(MOUSE_ENTER, function ()
        -- Reveal the tabs while the mouse is over the chat
        self.state.mouseOver = true
        if Core.db.profile.tabsOnHover then
          self:ShowTabs()
        end
      end),
      Core:Subscribe(MOUSE_LEAVE, function ()
        -- Fade the tabs out after the configured delay
        self.state.mouseOver = false
        if Core.db.profile.tabsOnHover then
          self:FadeOutTabs()
        end
      end),
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if key == "frameWidth" then
          self:SetWidth(Core.db.profile.frameWidth)
        end

        if key == "frameWidth" or key == "dockBackgroundOpacity" then
          self:SetGradientBackground(50, 250, Colors.black, Core.db.profile.dockBackgroundOpacity or 0.4)
        end

        if key == "tabsOnHover" then
          if Core.db.profile.tabsOnHover then
            -- Tabs on hover enabled - start fade out timer
            self:FadeOutTabs()
          else
            -- Tabs always visible - cancel any fade and show
            self:ShowTabs()
          end
        end
      end)
    }
  end
end

-- Reveal the tab dock immediately and cancel any pending fade-out.
function ChatDockMixin:ShowTabs()
  if self.fadeOutTimer then
    self.fadeOutTimer:Cancel()
    self.fadeOutTimer = nil
  end
  if self.fadeHandle then
    LibEasing:StopEasing(self.fadeHandle)
    self.fadeHandle = nil
  end
  self:Show()

  -- Slide/fade the tabs in over the configured duration (0 = instant).
  local duration = Core.db.profile.dockFadeInDuration or 0
  if duration > 0 then
    self.fadeHandle = LibEasing:Ease(
      function (a) self:SetAlpha(a) end,
      self:GetAlpha(),
      1,
      duration,
      LibEasing.OutCubic,
      function ()
        self.fadeHandle = nil
        self:SetAlpha(1)
      end
    )
  else
    self:SetAlpha(1)
  end
end

-- Fade the tab dock out after the configured hold time.
function ChatDockMixin:FadeOutTabs()
  if self.fadeOutTimer then
    self.fadeOutTimer:Cancel()
  end

  self.fadeOutTimer = C_Timer.NewTimer(Core.db.profile.dockHoldTime or 10, function ()
    self.fadeOutTimer = nil
    if self.state.mouseOver then return end

    local duration = Core.db.profile.dockFadeOutDuration or 0.6
    if self.fadeHandle then
      LibEasing:StopEasing(self.fadeHandle)
      self.fadeHandle = nil
    end

    if duration > 0 and self:IsVisible() then
      self.fadeHandle = LibEasing:Ease(
        function (a) self:SetAlpha(a) end,
        self:GetAlpha(),
        0,
        duration,
        LibEasing.OutCubic,
        function ()
          self.fadeHandle = nil
          Frame_Hide(self)
          self:SetAlpha(1)
        end
      )
    else
      Frame_Hide(self)
      self:SetAlpha(1)
    end
  end)
end

local isCreated = false

Core.Components.CreateChatDock = function (parent)
  if isCreated then
    error("ChatDock already exists. Only one ChatDock can exist at a time.")
  end

  local FadingFrameMixin = Core.Components.FadingFrameMixin
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin

  isCreated = true
  
  -- In WotLK 3.3.5, GeneralDockManager doesn't exist
  -- We create our own frame instead
  local frame = CreateFrame("Frame", "GlassChatDock", parent)
  
  local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, ChatDockMixin)
  AceHook:Embed(object)
  FadingFrameMixin.Init(object)
  GradientBackgroundMixin.Init(object)
  ChatDockMixin.Init(object, parent)
  
  return object
end
