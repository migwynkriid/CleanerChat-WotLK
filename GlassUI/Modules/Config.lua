local Core, Constants = unpack(select(2, ...))
local C = Core:GetModule("Config")

local AceDBOptions = Core.Libs.AceDBOptions
local LSM = Core.Libs.LSM

-- Localization
local L = LibStub("AceLocale-3.0"):GetLocale("CleanerChat")

local UnlockMover = Constants.ACTIONS.UnlockMover
local LockMover = Constants.ACTIONS.LockMover
local UpdateConfig = Constants.ACTIONS.UpdateConfig

-- Multi-window: each category in /cc shows window tabs (Main, Window 2, ...).
-- ProfileFor() resolves which window's settings a control edits from the
-- AceConfig info path (the window-tab key is one of the path segments).
C.selectedWindowId = "Main"

-- True if a window with this id currently exists (Main always does).
local function WindowExists(windowId)
  if windowId == "Main" then return true end
  local UIManager = Core:GetModule("UIManager", true)
  return (UIManager and UIManager.windows and UIManager.windows[windowId]) ~= nil
end

-- Resolve the profile a control should read/write from the AceConfig info path.
-- The window-tab group key ("Main" / "Window2" / ...) appears in the path, so we
-- scan for it. Falls back to the selected/Main profile (e.g. for build-time
-- desc strings where no info is available).
local function ProfileFor(info)
  if info then
    for i = 1, #info do
      local key = info[i]
      if key == "Main" then
        return Core.db.profile
      elseif type(key) == "string" and key:match("^Window%d+$") then
        local w = Core.db.profile.windows and Core.db.profile.windows[key]
        if w then return w end
      end
    end
  end
  return Core:GetWindowProfile(C.selectedWindowId or "Main")
end

-- Build one child "tab" group per window for a category. `builder` returns a
-- fresh copy of the category's controls (their get/set resolve the window from
-- the info path via ProfileFor, so the same builder works for every window).
-- Tabs for windows that don't exist yet are hidden until they're created.
local function buildWindowTabs(builder)
  local tabs = {
    Main = { name = "Main", type = "group", order = 1, args = builder() },
  }
  local maxWindows = _G.NUM_CHAT_WINDOWS or 10
  for n = 2, maxWindows do
    local wid = "Window" .. n
    tabs[wid] = {
      name = "Window " .. n,
      type = "group",
      order = n,
      hidden = function() return not WindowExists(wid) end,
      args = builder(),
    }
  end
  return tabs
end

local ANCHORS = {
  ["TOPLEFT"] = L["Top left"],
  ["TOPRIGHT"] = L["Top right"],
  ["BOTTOMLEFT"] = L["Bottom left"],
  ["BOTTOMRIGHT"] = L["Bottom right"]
}
local FLAGS = {
  [""] = L["None"],
  ["OUTLINE"] = L["Outline"],
  ["THICKOUTLINE"] = L["Thick Outline"],
  ["MONOCHROME"] = L["Monochrome"],
  ["MONOCHROME, OUTLINE"] = L["Monochrome Outline"],
  ["MONOCHROME, THICKOUTLINE"] = L["Monochrome Thick Outline"],
  ["OUTLINE, MONOCHROME"] = L["Outline Monochrome"],
}

function C:OnEnable()
  local options = {
      name = L["Glass"],
      handler = C,
      type = "group",
      args = {
        general = {
          name = L["General"],
          type = "group",
          childGroups = "tab",
          order = 1,
          args = buildWindowTabs(function() return {
            section1 = {
              name = L["Frame Position"],
              type = "group",
              inline = true,
              order = 2,
              args = {
                unlockFrame = {
                  name = function()
                    local UIManager = Core:GetModule("UIManager", true)
                    if UIManager and UIManager.moverDialog and UIManager.moverDialog:IsShown() then
                      return L["Lock frame"]
                    end
                    return L["Unlock frame"]
                  end,
                  type = "execute",
                  func = function()
                    local UIManager = Core:GetModule("UIManager", true)
                    if UIManager and UIManager.moverDialog and UIManager.moverDialog:IsShown() then
                      Core:Dispatch(LockMover())
                    else
                      Core:Dispatch(UnlockMover())
                    end
                  end,
                  order = 2.1,
                },
              }
            },
            section3 = {
              name = L["Frame"],
              type = "group",
              inline = true,
              order = 4,
              args = {
                frameXOfs = {
                  name = L["X offset"],
                  desc = "Default: "..Core.defaults.profile.positionAnchor.xOfs,
                  type = "range",
                  order = 4.1,
                  min = -9999,
                  max = 9999,
                  softMin = -2000,
                  softMax = 2000,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).positionAnchor.xOfs
                  end,
                  set = function (info, input)
                    ProfileFor(info).positionAnchor.xOfs = input
                    Core:Dispatch(UpdateConfig("framePosition"))
                  end
                },
                frameWidth = {
                  name = L["Width"],
                  desc = "Default: "..Core.defaults.profile.frameWidth..
                    "\nMin: 100",
                  type = "range",
                  order = 4.2,
                  min = 100,
                  max = 9999,
                  softMin = 300,
                  softMax = 800,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).frameWidth
                  end,
                  set = function (info, input)
                    ProfileFor(info).frameWidth = input
                    Core:Dispatch(UpdateConfig("frameWidth"))
                  end
                },
                frameYOfs = {
                  name = L["Y offset"],
                  desc = "Default: "..Core.defaults.profile.positionAnchor.yOfs,
                  type = "range",
                  order = 4.4,
                  min = -9999,
                  max = 9999,
                  softMin = -2000,
                  softMax = 2000,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).positionAnchor.yOfs
                  end,
                  set = function (info, input)
                    ProfileFor(info).positionAnchor.yOfs = input
                    Core:Dispatch(UpdateConfig("framePosition"))
                  end
                },
                frameHeight = {
                  name = L["Height"],
                  desc = "Default: "..Core.defaults.profile.frameHeight,
                  type = "range",
                  order = 4.5,
                  min = 1,
                  max = 9999,
                  softMin = 200,
                  softMax = 800,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).frameHeight
                  end,
                  set = function (info, input)
                    ProfileFor(info).frameHeight = input
                    Core:Dispatch(UpdateConfig("frameHeight"))
                  end
                },
                frameAnchor = {
                  name = L["Anchor"],
                  desc = function (info) return "Default: "..ProfileFor(info).positionAnchor.point end,
                  type = "select",
                  order = 4.3,
                  values = ANCHORS,
                  get = function (info)
                    return ProfileFor(info).positionAnchor.point
                  end,
                  set = function (info, input)
                    ProfileFor(info).positionAnchor.point = input
                    Core:Dispatch(UpdateConfig("framePosition"))
                  end
                },
              }
            }
          } end)
        },
        editBox = {
          name = L["Edit box"],
          type = "group",
          childGroups = "tab",
          order = 2,
          args = buildWindowTabs(function() return {
            section1 = {
              name = L["Appearance"],
              type = "group",
              inline = true,
              order = 1,
              args = {
                editBoxFont = {
                  name = L["Font"],
                  desc = L["Font to use for the edit box text."],
                  type = "select",
                  order = 1.0,
                  dialogControl = "LSM30_Font",
                  values = LSM:HashTable("font"),
                  get = function (info)
                    return ProfileFor(info).editBoxFont
                  end,
                  set = function (info, input)
                    ProfileFor(info).editBoxFont = input
                    Core:Dispatch(UpdateConfig("editBoxFont"))
                  end,
                },
                editBoxFontSize = {
                  name = L["Font size"],
                  desc = "Default: "..Core.defaults.profile.editBoxFontSize.."\nMin: 1\nMax: 100",
                  type = "range",
                  min = 1,
                  max = 100,
                  softMin = 6,
                  softMax = 24,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).editBoxFontSize
                  end,
                  set = function (info, input)
                    ProfileFor(info).editBoxFontSize = input
                    Core:Dispatch(UpdateConfig("editBoxFontSize"))
                  end,
                  order = 1.1,
                },
                editBoxFontFlags = {
                  name = L["Font style"],
                  desc = L["Add an outline to the edit box text so it stands out instead of looking flat."],
                  type = "select",
                  order = 1.3,
                  values = FLAGS,
                  get = function (info)
                    return ProfileFor(info).editBoxFontFlags
                  end,
                  set = function (info, input)
                    ProfileFor(info).editBoxFontFlags = input
                    Core:Dispatch(UpdateConfig("editBoxFontFlags"))
                  end,
                },
                editBoxBackgroundOpacity = {
                  name = L["Background opacity"],
                  desc = "Default: "..Core.defaults.profile.editBoxBackgroundOpacity,
                  type = "range",
                  order = 1.2,
                  min = 0,
                  max = 1,
                  softMin = 0,
                  softMax = 1,
                  step = 0.01,
                  get = function (info)
                    return ProfileFor(info).editBoxBackgroundOpacity
                  end,
                  set = function (info, input)
                    ProfileFor(info).editBoxBackgroundOpacity = input
                    Core:Dispatch(UpdateConfig("editBoxBackgroundOpacity"))
                  end,
                },
                editBoxBackgroundColor = {
                  name = L["Background color"],
                  desc = L["The colour of the edit box background."],
                  type = "color",
                  hasAlpha = false,
                  order = 1.4,
                  get = function (info)
                    local c = ProfileFor(info).editBoxBackgroundColor
                    return c.r, c.g, c.b
                  end,
                  set = function (info, r, g, b)
                    local c = ProfileFor(info).editBoxBackgroundColor
                    c.r, c.g, c.b = r, g, b
                    Core:Dispatch(UpdateConfig("editBoxBackgroundColor"))
                  end,
                },
              }
            },
            section2 = {
              name = L["Position"],
              type = "group",
              inline = true,
              order = 2,
              args = {
                editBoxAnchorPosition = {
                  name = L["Position"],
                  desc = "Default: "..Core.defaults.profile.editBoxAnchor.position,
                  type = "select",
                  order = 2.2,
                  values = {
                    ABOVE = L["Above"],
                    BELOW = L["Below"],
                  },
                  get = function (info)
                    return ProfileFor(info).editBoxAnchor.position
                  end,
                  set = function (info, input)
                    ProfileFor(info).editBoxAnchor.position = input
                    if input == "ABOVE" then
                      ProfileFor(info).editBoxAnchor.yOfs = 5
                    else
                      ProfileFor(info).editBoxAnchor.yOfs = -5
                    end
                    Core:Dispatch(UpdateConfig("editBoxAnchor"))
                  end
                },
                editBoxAnchorYOfs = {
                  name = L["Vertical offset"],
                  desc = "Default: 5 or -5",
                  type = "range",
                  order = 2.1,
                  min = -9999,
                  max = 9999,
                  softMin = -10,
                  softMax = 10,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).editBoxAnchor.yOfs
                  end,
                  set = function (info, input)
                    ProfileFor(info).editBoxAnchor.yOfs = input
                    Core:Dispatch(UpdateConfig("editBoxAnchor"))
                  end
                }
              },
            },
            section3 = {
              name = L["Behavior"],
              type = "group",
              inline = true,
              order = 3,
              args = {
                showOnEditFocus = {
                  name = L["Show chat on focus"],
                  desc = L["When enabled, opening the edit box (pressing Enter or clicking) reveals the chat messages."],
                  type = "toggle",
                  order = 3.1,
                  get = function (info)
                    return ProfileFor(info).showOnEditFocus
                  end,
                  set = function (info, input)
                    ProfileFor(info).showOnEditFocus = input
                  end,
                },
              },
            }
          } end),
        },
        messages = {
          name = L["Messages"],
          type = "group",
          childGroups = "tab",
          order = 3,
          args = buildWindowTabs(function() return {
            section1 = {
              name = L["Appearance"],
              type = "group",
              inline = true,
              order = 1,
              args = {
                messageFont = {
                  name = L["Font"],
                  desc = L["Font to use for chat messages."],
                  type = "select",
                  order = 1.0,
                  dialogControl = "LSM30_Font",
                  values = LSM:HashTable("font"),
                  get = function (info)
                    return ProfileFor(info).messageFont
                  end,
                  set = function (info, input)
                    ProfileFor(info).messageFont = input
                    Core:Dispatch(UpdateConfig("messageFont"))
                  end,
                },
                messageFontSize = {
                  name = L["Font size"],
                  desc = "Default: "..Core.defaults.profile.messageFontSize.."\nMin: 1\nMax: 100",
                  type = "range",
                  min = 1,
                  max = 100,
                  softMin = 6,
                  softMax = 24,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).messageFontSize
                  end,
                  set = function (info, input)
                    ProfileFor(info).messageFontSize = input
                    Core:Dispatch(UpdateConfig("messageFontSize"))
                  end,
                  order = 1.2,
                },
                messageFontFlags = {
                  name = L["Font style"],
                  desc = L["Add an outline to chat message text so it stands out instead of looking flat."],
                  type = "select",
                  order = 1.6,
                  values = FLAGS,
                  get = function (info)
                    return ProfileFor(info).messageFontFlags
                  end,
                  set = function (info, input)
                    ProfileFor(info).messageFontFlags = input
                    Core:Dispatch(UpdateConfig("messageFontFlags"))
                  end,
                },
                chatBackgroundOpacity = {
                  name = L["Background opacity"],
                  desc = "Default: "..Core.defaults.profile.chatBackgroundOpacity,
                  type = "range",
                  order = 1.2,
                  min = 0,
                  max = 1,
                  softMin = 0,
                  softMax = 1,
                  step = 0.01,
                  get = function (info)
                    return ProfileFor(info).chatBackgroundOpacity
                  end,
                  set = function (info, input)
                    ProfileFor(info).chatBackgroundOpacity = input
                    Core:Dispatch(UpdateConfig("chatBackgroundOpacity"))
                  end,
                },
                chatBackgroundColor = {
                  name = L["Background color"],
                  desc = L["The colour of the chat message background."],
                  type = "color",
                  hasAlpha = false,
                  order = 1.7,
                  get = function (info)
                    local c = ProfileFor(info).chatBackgroundColor
                    return c.r, c.g, c.b
                  end,
                  set = function (info, r, g, b)
                    local c = ProfileFor(info).chatBackgroundColor
                    c.r, c.g, c.b = r, g, b
                    Core:Dispatch(UpdateConfig("chatBackgroundColor"))
                  end,
                },
                messageLeading = {
                  name = L["Leading"],
                  desc = "Default: "..Core.defaults.profile.messageLeading.."\nMin: 0\nMax: 10",
                  type = "range",
                  min = 0,
                  max = 10,
                  softMin = 0,
                  softMax = 5,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).messageLeading
                  end,
                  set = function (info, input)
                    ProfileFor(info).messageLeading = input
                    Core:Dispatch(UpdateConfig("messageLeading"))
                  end,
                  order = 1.3,
                },
                messageLinePadding = {
                  name = L["Line padding"],
                  desc = "Default: "..Core.defaults.profile.messageLinePadding.."\nMin: 0\nMax: 5",
                  type = "range",
                  min = 0,
                  max = 5,
                  softMin = 0,
                  softMax = 1,
                  step = 0.05,
                  get = function (info)
                    return ProfileFor(info).messageLinePadding
                  end,
                  set = function (info, input)
                    ProfileFor(info).messageLinePadding = input
                    Core:Dispatch(UpdateConfig("messageLinePadding"))
                  end,
                  order = 1.4,
                },
                messageLeftPadding = {
                  name = L["Left padding"],
                  desc = "Default: "..Core.defaults.profile.messageLeftPadding.."\nMin: 0\nMax: 50\n\n"..L["Controls the blank space on the left side of messages."],
                  type = "range",
                  min = 0,
                  max = 50,
                  softMin = 0,
                  softMax = 30,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).messageLeftPadding
                  end,
                  set = function (info, input)
                    ProfileFor(info).messageLeftPadding = input
                    Core:Dispatch(UpdateConfig("messageLeftPadding"))
                  end,
                  order = 1.5,
                },
                messageHistoryLimit = {
                  name = L["Message history"],
                  desc = "Default: "..Core.defaults.profile.messageHistoryLimit.."\nMin: 128\nMax: 2048\n\n"..L["Maximum number of messages to keep in memory per chat window. Higher values use more memory."],
                  type = "range",
                  min = 128,
                  max = 2048,
                  softMin = 128,
                  softMax = 1024,
                  step = 64,
                  get = function (info)
                    return ProfileFor(info).messageHistoryLimit
                  end,
                  set = function (info, input)
                    ProfileFor(info).messageHistoryLimit = input
                  end,
                  order = 1.6,
                },
              },
            },
            section2 = {
              name = L["Animations"],
              type = "group",
              inline = true,
              order = 2,
              args = {
                disableAnimations = {
                  name = L["Disable animations"],
                  desc = L["Show messages instantly with no slide or fade -- the chat becomes static. The timing sliders below have no effect while this is on."],
                  type = "toggle",
                  order = 2.0,
                  get = function (info)
                    return ProfileFor(info).messageAnimations == false
                  end,
                  set = function (info, input)
                    ProfileFor(info).messageAnimations = not input
                    Core:Dispatch(UpdateConfig("messageAnimations"))
                  end,
                },
                messagesAlwaysVisible = {
                  name = L["Keep messages visible"],
                  desc = L["Messages never fade out -- they stay on screen permanently. Overrides the fade out delay and duration below."],
                  type = "toggle",
                  order = 2.01,
                  get = function (info)
                    return ProfileFor(info).messagesAlwaysVisible
                  end,
                  set = function (info, input)
                    ProfileFor(info).messagesAlwaysVisible = input
                    Core:Dispatch(UpdateConfig("messagesAlwaysVisible"))
                  end,
                },
                animationsSpacer = {
                  name = "",
                  type = "description",
                  order = 2.05,
                  width = "full",
                },
                chatHoldTime = {
                  name = L["Fade out delay"],
                  desc = "Default: "..Core.defaults.profile.chatHoldTime..
                    "\nMin: 1\nMax: 180",
                  type = "range",
                  order = 2.1,
                  min = 1,
                  max = 180,
                  softMin = 1,
                  softMax = 20,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).chatHoldTime
                  end,
                  set = function (info, input)
                    ProfileFor(info).chatHoldTime = input
                  end,
                },
                fadeInDuration = {
                  name = L["Fade in duration"],
                  desc = "Default: "..Core.defaults.profile.chatFadeInDuration..
                    "\nMin: 0\nMax:30",
                  type = "range",
                  order = 2.3,
                  min = 0,
                  max = 30,
                  softMin = 0,
                  softMax = 10,
                  step = 0.05,
                  get = function (info)
                    return ProfileFor(info).chatFadeInDuration
                  end,
                  set = function (info, input)
                    ProfileFor(info).chatFadeInDuration = input
                    Core:Dispatch(UpdateConfig("chatFadeInDuration"))
                  end
                },
                fadeOutDuration = {
                  name = L["Fade out duration"],
                  desc = "Default: "..Core.defaults.profile.chatFadeOutDuration..
                    "\nMin: 0\nMax:30",
                  type = "range",
                  order = 2.4,
                  min = 0,
                  max = 30,
                  softMin = 0,
                  softMax = 10,
                  step = 0.05,
                  get = function (info)
                    return ProfileFor(info).chatFadeOutDuration
                  end,
                  set = function (info, input)
                    ProfileFor(info).chatFadeOutDuration = input
                    Core:Dispatch(UpdateConfig("chatFadeOutDuration"))
                  end
                },
                slideInDuration = {
                  name = L["Slide in duration"],
                  desc = "Default: "..Core.defaults.profile.chatSlideInDuration,
                  type = "range",
                  order = 2.3,
                  min = 0,
                  max = 30,
                  softMin = 0,
                  softMax = 5,
                  step = 0.05,
                  get = function (info)
                    return ProfileFor(info).chatSlideInDuration
                  end,
                  set = function (info, input)
                    ProfileFor(info).chatSlideInDuration = input
                  end
                }
              }
            },
            section3 = {
              name = L["Misc"],
              type = "group",
              inline = true,
              order = 3,
              args = {
                indentWordWrap = {
                  name = L["Indent on line wrap"],
                  desc = L["Adds an indent when a message wraps beyond a single line."],
                  type = "toggle",
                  order = 3.1,
                  get = function (info)
                    return ProfileFor(info).indentWordWrap
                  end,
                  set = function (info, input)
                    ProfileFor(info).indentWordWrap = input
                    Core:Dispatch(UpdateConfig("indentWordWrap"))
                  end,
                },
                mouseOverTooltips = {
                  name = L["Mouse over tooltips"],
                  desc = L["Should tooltips appear when hovering over chat links."],
                  type = "toggle",
                  order = 3.2,
                  get = function (info)
                    return ProfileFor(info).mouseOverTooltips
                  end,
                  set = function (info, input)
                    ProfileFor(info).mouseOverTooltips = input
                  end,
                },
                iconTextureYOffset = {
                  type = "range",
                  name = L["Text icons Y offset"],
                  desc = "Default: "..Core.defaults.profile.iconTextureYOffset..
                    "\n"..L["Adjust this if text icons aren't centered."],
                  order = 3.4,
                  min = 0,
                  max = 12,
                  softMin = 0,
                  softMax = 12,
                  step = 3.1,
                  get = function (info)
                    return ProfileFor(info).iconTextureYOffset
                  end,
                  set = function (info, input)
                    -- TODO: Update messages dynamically
                    ProfileFor(info).iconTextureYOffset = input
                  end,
                },
                messagesOnHover = {
                  name = L["Show messages on hover"],
                  desc = L["When enabled, hovering over the chat reveals faded messages. When disabled, only scrolling reveals them."],
                  type = "toggle",
                  order = 3.3,
                  get = function (info)
                    return ProfileFor(info).messagesOnHover
                  end,
                  set = function (info, input)
                    ProfileFor(info).messagesOnHover = input
                    Core:Dispatch(UpdateConfig("messagesOnHover"))
                  end,
                },
                showTimestamps = {
                  name = L["Show timestamps"],
                  desc = L["Prepend each message with a timestamp in [HH:MM] format."],
                  type = "toggle",
                  order = 3.35,
                  get = function (info)
                    return ProfileFor(info).showTimestamps
                  end,
                  set = function (info, input)
                    ProfileFor(info).showTimestamps = input
                  end,
                },
                scrollIndicatorHeader = {
                  name = L["Scroll Indicator"],
                  type = "header",
                  order = 3.5,
                },
                hideScrollIndicator = {
                  name = L["Hide scroll indicator"],
                  desc = L["Hide the \"Unread messages\" and \"Bring me to the present\" indicator completely."],
                  type = "toggle",
                  width = "full",
                  order = 3.55,
                  get = function (info)
                    return ProfileFor(info).hideScrollIndicator
                  end,
                  set = function (info, input)
                    ProfileFor(info).hideScrollIndicator = input
                    Core:Dispatch(UpdateConfig("hideScrollIndicator"))
                  end,
                },
                scrollIndicatorColor = {
                  name = L["Indicator text color"],
                  desc = L["Color of the \"Unread messages\" and \"Bring me to the present\" text."],
                  type = "color",
                  hasAlpha = false,
                  width = 1,
                  order = 3.6,
                  disabled = function (info) return ProfileFor(info).hideScrollIndicator end,
                  get = function (info)
                    local c = ProfileFor(info).scrollIndicatorColor
                    return c.r, c.g, c.b
                  end,
                  set = function (info, r, g, b)
                    local c = ProfileFor(info).scrollIndicatorColor
                    c.r, c.g, c.b = r, g, b
                    Core:Dispatch(UpdateConfig("scrollIndicatorColor"))
                  end,
                },
                scrollIndicatorOpacity = {
                  name = L["Indicator text opacity"],
                  desc = "Default: "..Core.defaults.profile.scrollIndicatorOpacity.."\n"..L["Opacity of the scroll indicator text."],
                  type = "range",
                  width = 1.5,
                  order = 3.65,
                  disabled = function (info) return ProfileFor(info).hideScrollIndicator end,
                  min = 0,
                  max = 1,
                  step = 0.05,
                  get = function (info)
                    return ProfileFor(info).scrollIndicatorOpacity
                  end,
                  set = function (info, input)
                    ProfileFor(info).scrollIndicatorOpacity = input
                    Core:Dispatch(UpdateConfig("scrollIndicatorOpacity"))
                  end,
                },
                scrollIndicatorBgColor = {
                  name = L["Indicator background color"],
                  desc = L["Background color behind the scroll indicator text."],
                  type = "color",
                  hasAlpha = false,
                  width = 1,
                  order = 3.7,
                  disabled = function (info) return ProfileFor(info).hideScrollIndicator end,
                  get = function (info)
                    local c = ProfileFor(info).scrollIndicatorBgColor
                    return c.r, c.g, c.b
                  end,
                  set = function (info, r, g, b)
                    local c = ProfileFor(info).scrollIndicatorBgColor
                    c.r, c.g, c.b = r, g, b
                    Core:Dispatch(UpdateConfig("scrollIndicatorBgColor"))
                  end,
                },
                scrollIndicatorBgOpacity = {
                  name = L["Indicator background opacity"],
                  desc = "Default: "..Core.defaults.profile.scrollIndicatorBgOpacity.."\n"..L["Opacity of the scroll indicator background."],
                  type = "range",
                  width = 1.5,
                  order = 3.75,
                  disabled = function (info) return ProfileFor(info).hideScrollIndicator end,
                  min = 0,
                  max = 1,
                  step = 0.05,
                  get = function (info)
                    return ProfileFor(info).scrollIndicatorBgOpacity
                  end,
                  set = function (info, input)
                    ProfileFor(info).scrollIndicatorBgOpacity = input
                    Core:Dispatch(UpdateConfig("scrollIndicatorBgOpacity"))
                  end,
                },
              }
            },
          } end),
        },
        topBar = {
          name = L["Top bar"],
          type = "group",
          childGroups = "tab",
          order = 4,
          args = buildWindowTabs(function() return {
            section1 = {
              name = L["Appearance"],
              type = "group",
              inline = true,
              order = 1,
              args = {
                dockFont = {
                  name = L["Font"],
                  desc = L["Font to use for the chat tab text."],
                  type = "select",
                  order = 1.0,
                  dialogControl = "LSM30_Font",
                  values = LSM:HashTable("font"),
                  get = function (info)
                    return ProfileFor(info).dockFont
                  end,
                  set = function (info, input)
                    ProfileFor(info).dockFont = input
                    Core:Dispatch(UpdateConfig("dockFont"))
                  end,
                },
                dockFontSize = {
                  name = L["Font size"],
                  desc = "Default: "..Core.defaults.profile.dockFontSize.."\nMin: 1\nMax: 100"..
                    "\n"..L["Tab widths refit on /reload."],
                  type = "range",
                  order = 1.1,
                  min = 1,
                  max = 100,
                  softMin = 6,
                  softMax = 24,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).dockFontSize
                  end,
                  set = function (info, input)
                    ProfileFor(info).dockFontSize = input
                    Core:Dispatch(UpdateConfig("dockFontSize"))
                  end,
                },
                dockFontFlags = {
                  name = L["Font style"],
                  desc = L["Add an outline to the chat tab text so it stands out instead of looking flat."],
                  type = "select",
                  order = 1.15,
                  values = FLAGS,
                  get = function (info)
                    return ProfileFor(info).dockFontFlags
                  end,
                  set = function (info, input)
                    ProfileFor(info).dockFontFlags = input
                    Core:Dispatch(UpdateConfig("dockFontFlags"))
                  end,
                },
                dockBackgroundOpacity = {
                  name = L["Background opacity"],
                  desc = "Default: "..Core.defaults.profile.dockBackgroundOpacity,
                  type = "range",
                  order = 1.2,
                  min = 0,
                  max = 1,
                  softMin = 0,
                  softMax = 1,
                  step = 0.01,
                  get = function (info)
                    return ProfileFor(info).dockBackgroundOpacity
                  end,
                  set = function (info, input)
                    ProfileFor(info).dockBackgroundOpacity = input
                    Core:Dispatch(UpdateConfig("dockBackgroundOpacity"))
                  end,
                },
                dockBackgroundColor = {
                  name = L["Background color"],
                  desc = L["The colour of the top bar background."],
                  type = "color",
                  hasAlpha = false,
                  order = 1.3,
                  get = function (info)
                    local c = ProfileFor(info).dockBackgroundColor
                    return c.r, c.g, c.b
                  end,
                  set = function (info, r, g, b)
                    local c = ProfileFor(info).dockBackgroundColor
                    c.r, c.g, c.b = r, g, b
                    Core:Dispatch(UpdateConfig("dockBackgroundColor"))
                  end,
                },
              },
            },
            section2 = {
              name = L["Animations"],
              type = "group",
              inline = true,
              order = 2,
              args = {
                disableAnimations = {
                  name = L["Disable animations"],
                  desc = L["Show and hide the top bar instantly with no fade -- the tabs become static. The timing sliders below have no effect while this is on."],
                  type = "toggle",
                  order = 2.0,
                  get = function (info)
                    return ProfileFor(info).dockAnimations == false
                  end,
                  set = function (info, input)
                    ProfileFor(info).dockAnimations = not input
                    Core:Dispatch(UpdateConfig("dockAnimations"))
                  end,
                },
                tabsAlwaysVisible = {
                  name = L["Keep tabs visible"],
                  desc = L["Chat tabs never fade out -- they stay on screen permanently. Overrides the fade out delay and duration below."],
                  type = "toggle",
                  order = 2.01,
                  get = function (info)
                    return ProfileFor(info).tabsAlwaysVisible
                  end,
                  set = function (info, input)
                    ProfileFor(info).tabsAlwaysVisible = input
                    Core:Dispatch(UpdateConfig("tabsAlwaysVisible"))
                  end,
                },
                topBarAnimationsSpacer = {
                  name = "",
                  type = "description",
                  order = 2.05,
                  width = "full",
                },
                dockHoldTime = {
                  name = L["Fade out delay"],
                  desc = "Default: "..Core.defaults.profile.dockHoldTime.."\nMin: 1\nMax: 180",
                  type = "range",
                  order = 2.1,
                  min = 1,
                  max = 180,
                  softMin = 1,
                  softMax = 20,
                  step = 1,
                  get = function (info)
                    return ProfileFor(info).dockHoldTime
                  end,
                  set = function (info, input)
                    ProfileFor(info).dockHoldTime = input
                  end,
                },
                dockFadeOutDuration = {
                  name = L["Fade out duration"],
                  desc = "Default: "..Core.defaults.profile.dockFadeOutDuration.."\nMin: 0\nMax: 30",
                  type = "range",
                  order = 2.2,
                  min = 0,
                  max = 30,
                  softMin = 0,
                  softMax = 10,
                  step = 0.05,
                  get = function (info)
                    return ProfileFor(info).dockFadeOutDuration
                  end,
                  set = function (info, input)
                    ProfileFor(info).dockFadeOutDuration = input
                  end,
                },
                dockFadeInDuration = {
                  name = L["Slide in duration"],
                  desc = "Default: "..Core.defaults.profile.dockFadeInDuration.."\nMin: 0\nMax: 30",
                  type = "range",
                  order = 2.3,
                  min = 0,
                  max = 30,
                  softMin = 0,
                  softMax = 5,
                  step = 0.05,
                  get = function (info)
                    return ProfileFor(info).dockFadeInDuration
                  end,
                  set = function (info, input)
                    ProfileFor(info).dockFadeInDuration = input
                  end,
                },
                tabsOnHover = {
                  name = L["Show tabs on hover"],
                  desc = L["When enabled, chat tabs fade out when idle and reappear on mouse hover. When disabled, tabs are always visible."],
                  type = "toggle",
                  order = 2.02,
                  get = function (info)
                    return ProfileFor(info).tabsOnHover
                  end,
                  set = function (info, input)
                    ProfileFor(info).tabsOnHover = input
                    Core:Dispatch(UpdateConfig("tabsOnHover"))
                  end,
                },
              },
            },
          } end),
        },
        profile = AceDBOptions:GetOptionsTable(Core.db)
      }
  }

  -- Glass no longer owns its own options window or slash command -- its
  -- settings are embedded as categories in CleanerChat's /cc window. Expose the
  -- config groups for that, plus a helper so "/cc lock" can unlock the frame.
  Core.configGroups = options.args
  function Core.UnlockFrame()
    Core:Dispatch(UnlockMover())
  end

  Core.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
  Core.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
  Core.db.RegisterCallback(self, "OnProfileReset", "OnProfileReset")
end

function C:RefreshConfig()
  -- General
  Core:Dispatch(UpdateConfig("frameHeight"))
  Core:Dispatch(UpdateConfig("frameWidth"))
  Core:Dispatch(UpdateConfig("framePosition"))

  -- Edit box
  Core:Dispatch(UpdateConfig("editBoxFont"))
  Core:Dispatch(UpdateConfig("editBoxFontSize"))
  Core:Dispatch(UpdateConfig("editBoxFontFlags"))
  Core:Dispatch(UpdateConfig("editBoxBackgroundOpacity"))
  Core:Dispatch(UpdateConfig("editBoxBackgroundColor"))
  Core:Dispatch(UpdateConfig("editBoxAnchor"))

  -- Messages
  Core:Dispatch(UpdateConfig("messageFont"))
  Core:Dispatch(UpdateConfig("messageFontSize"))
  Core:Dispatch(UpdateConfig("messageFontFlags"))
  Core:Dispatch(UpdateConfig("messageAnimations"))
  Core:Dispatch(UpdateConfig("messagesAlwaysVisible"))
  Core:Dispatch(UpdateConfig("chatBackgroundOpacity"))
  Core:Dispatch(UpdateConfig("chatBackgroundColor"))
  Core:Dispatch(UpdateConfig("chatFadeInDuration"))
  Core:Dispatch(UpdateConfig("chatFadeOutDuration"))
  Core:Dispatch(UpdateConfig("scrollIndicatorColor"))
  Core:Dispatch(UpdateConfig("scrollIndicatorOpacity"))
  Core:Dispatch(UpdateConfig("scrollIndicatorBgColor"))
  Core:Dispatch(UpdateConfig("scrollIndicatorBgOpacity"))
  Core:Dispatch(UpdateConfig("hideScrollIndicator"))

  -- Top bar (dock)
  Core:Dispatch(UpdateConfig("dockFont"))
  Core:Dispatch(UpdateConfig("dockFontSize"))
  Core:Dispatch(UpdateConfig("dockFontFlags"))
  Core:Dispatch(UpdateConfig("dockAnimations"))
  Core:Dispatch(UpdateConfig("tabsAlwaysVisible"))
  Core:Dispatch(UpdateConfig("dockBackgroundOpacity"))
  Core:Dispatch(UpdateConfig("dockBackgroundColor"))
  Core:Dispatch(UpdateConfig("tabsOnHover"))
end

function C:OnProfileReset()
  -- Also reset CleanerChat filter settings
  local CleanerChat = LibStub("AceAddon-3.0"):GetAddon("CleanerChat", true)
  if CleanerChat and CleanerChat.ResetCleanerChatSettings then
    CleanerChat:ResetCleanerChatSettings()
  end
  -- Refresh Glass UI config
  self:RefreshConfig()
end
