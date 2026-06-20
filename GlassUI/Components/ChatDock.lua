local Core, Constants = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook
local LibEasing = Core.Libs.LibEasing

local Colors = Constants.COLORS

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

  -- Gradient background
  local opacity = 0.4
  self:SetGradientBackground(50, 250, Colors.black, opacity)

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

  -- Show the dock initially, then fade the tabs out after the hold time.
  -- (Glass behaviour: tabs are revealed on hover and fade out when idle.)
  self:Show()
  self:FadeOutTabs()

  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(MOUSE_ENTER, function ()
        -- Reveal the tabs while the mouse is over the chat
        self.state.mouseOver = true
        self:ShowTabs()
      end),
      Core:Subscribe(MOUSE_LEAVE, function ()
        -- Fade the tabs out after the configured delay
        self.state.mouseOver = false
        self:FadeOutTabs()
      end),
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if key == "frameWidth" then
          self:SetWidth(Core.db.profile.frameWidth)

          self:SetGradientBackground(50, 250, Colors.black, opacity)
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
  self:SetAlpha(1)
end

-- Fade the tab dock out after the configured hold time.
function ChatDockMixin:FadeOutTabs()
  if self.fadeOutTimer then
    self.fadeOutTimer:Cancel()
  end

  self.fadeOutTimer = C_Timer.NewTimer(Core.db.profile.chatHoldTime or 10, function ()
    self.fadeOutTimer = nil
    if self.state.mouseOver then return end

    local duration = Core.db.profile.chatFadeOutDuration or 0.6
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
          self:Hide()
          self:SetAlpha(1)
        end
      )
    else
      self:Hide()
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
