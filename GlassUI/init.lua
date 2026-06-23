local _G = _G

local AceAddon = _G.LibStub("AceAddon-3.0")

-- Integrated into CleanerChat: this file is loaded by the CleanerChat .toc, so the
-- "..." vararg carries CleanerChat's name/namespace. Use a fixed identity for the
-- Glass UI so it registers its own AceAddon object and "Glass" global, while still
-- sharing Core/Constants/Utils with the other Glass files via the vararg table.
local _, AddonVars = ...
local AddonName = "Glass"
local Core = AceAddon:NewAddon(AddonName)
local Constants = {}
local Utils = {}
AddonVars[1] = Core
AddonVars[2] = Constants
AddonVars[3] = Utils
_G[AddonName] = Core

-- Core
Core.Libs = {
  AceDB = _G.LibStub("AceDB-3.0"),
  AceDBOptions = _G.LibStub("AceDBOptions-3.0"),
  AceHook = _G.LibStub("AceHook-3.0"),
  LSM = _G.LibStub("LibSharedMedia-3.0"),
  LibEasing = _G.LibStub("LibEasing-1.0"),
  lodash = _G.LibStub("lodash.wow")
}
Core.Components = {}
Core.Version = "1.7.0-wotlk"
--[===[@debug@--
Core.Version = "DEBUG"
--@end-debug@]===]--

-- Modules
Core:NewModule("Config", "AceConsole-3.0")
Core:NewModule("Fonts")
Core:NewModule("Hyperlinks")
Core:NewModule("TextProcessing")
Core:NewModule("UIManager", "AceHook-3.0")

-- Default settings
Core.defaults = {
  profile = {
    -- General
    font = "Friz Quadrata TT",
    frameWidth = 520,
    frameHeight = 340,
    positionAnchor = {
      point = "BOTTOMLEFT",
      xOfs = 20,
      yOfs = 230
    },

    -- Edit box
    editBoxFontSize = 12,
    editBoxFontFlags = "OUTLINE",
    editBoxBackgroundOpacity = 0.6,
    editBoxBackgroundColor = { r = 17 / 255, g = 17 / 255, b = 17 / 255 }, -- codGray
    editBoxAnchor = {
      position = "BELOW",
      yOfs = -5
    },
    showOnEditFocus = true, -- When ON (default), opening the edit box reveals the chat messages.

    -- Messages
    messageFontSize = 12,
    messageFontFlags = "OUTLINE",
    messageAnimations = true,
    messagesAlwaysVisible = false,
    chatBackgroundOpacity = 0.15,
    chatBackgroundColor = { r = 17 / 255, g = 17 / 255, b = 17 / 255 }, -- codGray
    messageLeading = 3,
    messageLinePadding = 0.25,
    messageLeftPadding = 15,
    messageHistoryLimit = 128,

    chatHoldTime = 14,
    chatFadeInDuration = 0.6,
    chatFadeOutDuration = 0.6,
    chatSlideInDuration = 0.35,

    -- Top bar (chat tabs dock)
    dockFontSize = 12,
    dockFontFlags = "OUTLINE",
    dockAnimations = true,
    tabsAlwaysVisible = false,
    dockBackgroundOpacity = 0,
    dockBackgroundColor = { r = 0, g = 0, b = 0 }, -- black
    dockHoldTime = 10,
    dockFadeOutDuration = 0.6,
    dockFadeInDuration = 0.3,
    tabsOnHover = true, -- When ON (default), tabs fade out and appear on hover. When OFF, tabs are always visible.

    indentWordWrap = true,
    mouseOverTooltips = true,
    iconTextureYOffset = 4,
    messagesOnHover = true, -- When ON (default), hovering reveals faded messages. When OFF, only scrolling reveals them.
    showTimestamps = false, -- When ON, prepend timestamps to messages in [HH:MM] format.

    -- Scroll indicator ("Unread messages" / "Bring me to the present")
    scrollIndicatorColor = { r = 223 / 255, g = 186 / 255, b = 105 / 255 }, -- apache (gold)
    scrollIndicatorOpacity = 1, -- fully solid
    scrollIndicatorBgColor = { r = 17 / 255, g = 17 / 255, b = 17 / 255 }, -- codGray (same as chat bg)
    scrollIndicatorBgOpacity = 0.65, -- slightly transparent
    hideScrollIndicator = false, -- when true, hides the "Unread messages" / "Bring me to the present" indicator
  }
}

function Core:OnInitialize()
  self.listeners = {}

  self.db = self.Libs.AceDB:New("GlassDB", self.defaults, true)
  self.printBuffer = {}
end

function Core:OnEnable()
  -- Buffer print messages until ViragDevTool loads
  for _, item in ipairs(self.printBuffer) do
    Utils.print(unpack(item))
  end
  self.printBuffer = {}
end

function Core:Subscribe(messageType, listener)
  if self.listeners[messageType] == nil then
    self.listeners[messageType] = {}
  end

  local listeners = self.listeners[messageType]
  local index = #listeners + 1
  listeners[index] = listener

  return function ()
    self.Libs.lodash.remove(listeners, function (val) return val == listener end)
  end
end

function Core:Dispatch(messageType, payload)
  --[===[@debug@--
  Utils.print('E: '..messageType, payload)
  --@end-debug@]===]--

  local listeners = self.listeners[messageType] or {}
  for _, listener in ipairs(listeners) do
    listener(payload)
  end
end
