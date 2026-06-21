local Core, Constants = unpack(select(2, ...))
local TP = Core:GetModule("TextProcessing")

local AceHook = Core.Libs.AceHook

-- CleanerChat integration: resolve its addon object lazily so incoming chat
-- text can be run through the same string filters CleanerChat applies to the
-- default chat frame. Returns nil until CleanerChat is available.
local AceAddon = _G.LibStub("AceAddon-3.0")
local cleanerChat
local function GetCleanerChat()
  if (not cleanerChat) then
    cleanerChat = AceAddon:GetAddon("CleanerChat", true)
  end
  return cleanerChat
end

local LibEasing = Core.Libs.LibEasing
local lodash = Core.Libs.lodash
local drop, reduce, take = lodash.drop, lodash.reduce, lodash.take

local CreateMessageLinePool = Core.Components.CreateMessageLinePool
local CreateScrollOverlayFrame = Core.Components.CreateScrollOverlayFrame

local EDIT_FOCUS_GAINED = Constants.EVENTS.EDIT_FOCUS_GAINED
local EDIT_FOCUS_LOST = Constants.EVENTS.EDIT_FOCUS_LOST
local MOUSE_ENTER = Constants.EVENTS.MOUSE_ENTER
local MOUSE_LEAVE = Constants.EVENTS.MOUSE_LEAVE
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local CreateObjectPool = CreateObjectPool
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local Mixin = Mixin
-- luacheck: pop

----
-- SlidingMessageFrameMixin
--
-- Custom frame for displaying pretty sliding messages
local SlidingMessageFrameMixin = {}

function SlidingMessageFrameMixin:Init(chatFrame)
  self.config = {
    height = Core.db.profile.frameHeight - Constants.DOCK_HEIGHT - 5,
    width = Core.db.profile.frameWidth,
    overflowHeight = 60,
  }
  self.state = {
    mouseOver = false,
    showingTooltip = false,
    prevEasingHandle = nil,
    incomingMessages = {},
    messages = {},
    head = nil,
    tail = nil,
    isCombatLog = (chatFrame == _G.ChatFrame2),
    scrollAtBottom = true,
    unreadMessages = false,
  }
  self.chatFrame = chatFrame

  -- Combat Log (ChatFrame2) in WotLK uses a completely different rendering system
  -- that doesn't go through AddMessage(). Rather than trying to hook it, we let
  -- Blizzard's native Combat Log render and just toggle its visibility when the
  -- Glass Combat Log tab is selected. UIManager handles showing/hiding ChatFrame2.
  if self.state.isCombatLog then
    -- Hide the button frame only
    local buttonFrame = _G[chatFrame:GetName().."ButtonFrame"]
    if buttonFrame then
      buttonFrame:Hide()
    end
    
    -- Set up minimal scroll frame (not used for combat log display)
    self:SetHeight(self.config.height + self.config.overflowHeight)
    self:SetWidth(self.config.width)
    self:SetPoint("TOPLEFT", 0, (Constants.DOCK_HEIGHT + 5) * -1)
    self:SetVerticalScroll(self.config.overflowHeight)
    self:Hide()  -- Hide Glass overlay for combat log - native frame renders instead
    
    -- Skip the rest of Init for combat log
    return
  end

  -- Hide Blizzard UI elements (but don't modify chatFrame parent/position).
  local buttonFrame = _G[chatFrame:GetName().."ButtonFrame"]
  if buttonFrame then
    buttonFrame:Hide()
  end

  -- Make the original chat frame invisible but don't change its parent
  -- This preserves Blizzard's internal state
  chatFrame:SetAlpha(0)

  -- Keep it invisible. Blizzard fades a docked frame back in when its tab is
  -- selected (e.g. clicking the Combat Log tab), which resets the alpha and
  -- makes the native frame reappear on top of the Glass display. Force the
  -- alpha to stay at 0 so only the Glass rendering is ever visible.
  if not self:IsHooked(chatFrame, "SetAlpha") then
    self:RawHook(chatFrame, "SetAlpha", function ()
      self.hooks[chatFrame].SetAlpha(chatFrame, 0)
    end, true)
  end

  -- The native chat frame is invisible but still has mouse + mouse-wheel input
  -- enabled, so it captures the scroll wheel over its area (blocking camera
  -- zoom) and swallows clicks. Disable its mouse input entirely -- the Glass
  -- frame does its own scrolling, so nothing is lost.
  chatFrame:EnableMouse(false)
  chatFrame:EnableMouseWheel(false)

  -- Setting alpha 0 hides the native frame's text but NOT its embedded message
  -- icons (|T|t) on this client, so they leak on top of the world. Actually
  -- hide the frame so it renders nothing, and re-hide it whenever Blizzard
  -- re-shows the selected dock frame. Glass's AddMessage hook still fires on
  -- hidden frames, so its own display is unaffected.
  if not self:IsHooked(chatFrame, "Show") then
    self:SecureHook(chatFrame, "Show", function ()
      chatFrame:Hide()
    end)
  end
  chatFrame:Hide()

  -- Chat scroll frame for our custom messages
  self:SetHeight(self.config.height + self.config.overflowHeight)
  self:SetWidth(self.config.width)
  self:SetPoint("TOPLEFT", 0, (Constants.DOCK_HEIGHT + 5) * -1)

  -- Set initial scroll position
  self:SetVerticalScroll(self.config.overflowHeight)

  -- Overlay
  if self.overlay == nil then
    self.overlay = CreateScrollOverlayFrame(self)
    self.overlay:QuickHide()

    -- Snap to bottom on click
    self.overlay:SetScript("OnClickSnapFrame", function ()
      self.state.scrollAtBottom = true
      self.state.unreadMessages = false
      self.overlay:Hide()
      self.overlay:HideNewMessageAlert()

      local startOffset = math.max(
        self:GetVerticalScrollRange() - self.config.height * 2,
        self:GetVerticalScroll()
      )
      local endOffset = self:GetVerticalScrollRange()

      LibEasing:Ease(
        function (offset) self:SetVerticalScroll(offset) end,
        startOffset,
        endOffset,
        0.3,
        LibEasing.OutCubic,
        function ()
          self:SetHeight(self.config.height + self.config.overflowHeight)
        end
      )
    end)
  end

  -- Scrolling
  self:SetScript("OnMouseWheel", function (frame, delta)
    local maxScroll = (
      self.state.scrollAtBottom and
      self:GetVerticalScrollRange() + self.config.overflowHeight
      or self:GetVerticalScrollRange()
    )
    local minScroll = self.config.height + self.config.overflowHeight
    local scrollValue

    if delta < 0 then
      -- Scroll down
      scrollValue = math.min(self:GetVerticalScroll() + 20, maxScroll)
    else
      -- Scroll up
      scrollValue = math.max(self:GetVerticalScroll() - 20, math.min(minScroll, maxScroll))
    end

    self:UpdateScrollChildRect()
    self:SetVerticalScroll(scrollValue)

    self.state.scrollAtBottom = scrollValue == maxScroll

    -- Adjust height of scroll frame when scrolling
    if self.state.scrollAtBottom then
      -- If scrolled to the bottom, the height of the scroll frame should
      -- include overflow to account for slide up animations
      self:SetHeight(self.config.height + self.config.overflowHeight)
      self.overlay:Hide()
      self.overlay:HideNewMessageAlert()
      self.state.unreadMessages = false
    else
      -- If not, the height should fit the frame exactly so messages don't spill
      -- under the edit box area
      self:SetHeight(self.config.height)
      self.overlay:Show()
    end

    -- Show hidden messages
    for _, message in ipairs(self.state.messages) do
      message:Show()
    end
  end)

  -- Mouse clickthrough but allow scrolling
  self:EnableMouse(false)
  self:EnableMouseWheel(true)  -- Enable mouse wheel separately for scrolling

  -- ScrollChild
  if self.slider == nil then
    self.slider = CreateFrame("Frame", nil, self)
  end
  self.slider:SetHeight(self.config.height + self.config.overflowHeight)
  self.slider:SetWidth(self.config.width)
  self:SetScrollChild(self.slider)

  if self.slider.bg == nil then
    self.slider.bg = self.slider:CreateTexture(nil, "BACKGROUND")
  end
  self.slider.bg:SetAllPoints()
  self.slider.bg:SetColorTexture(0, 0, 1, 0)

  -- Pool for the message frames
  if self.messageFramePool == nil then
    self.messageFramePool = CreateMessageLinePool(self.slider)
  end

  -- Hook AddMessage to capture messages for our display
  -- Note: Combat Log returns early in Init, so this only runs for regular chat frames
  self:Hook(chatFrame, "AddMessage", function (frame, text, ...)
    -- Run incoming text through CleanerChat's filters so the Glass display
    -- matches CleanerChat's formatting and drops blacklisted messages.
    local CleanerChat = GetCleanerChat()
    if (CleanerChat and text ~= nil) then
      local filtered = CleanerChat:FilterMessage(frame, text, ...)
      if (filtered == nil) then return end
      text = filtered
    end
    self:AddMessage(frame, text, ...)
  end, true)

  -- Note: historyBuffer doesn't exist in WotLK 3.3.5
  -- Message history restoration is not available

  -- Show our custom frame
  self:Show()

  -- Note: GetNumMessages/GetMessageInfo may not exist in WotLK 3.3.5
  -- Skip loading existing messages from chat frame

  -- Listeners
  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(MOUSE_ENTER, function ()
        -- Don't hide chats when mouse is over
        self.state.mouseOver = true

        if not self.state.scrollAtBottom then
          self.overlay:Show()
        end

        -- Cancel all hide timers when mouse enters
        for _, message in ipairs(self.state.messages) do
          if message.hideTimer then
            message.hideTimer:Cancel()
            message.hideTimer = nil
          end
        end

        -- If messagesOnHover is enabled, fade in all messages
        if Core.db.profile.messagesOnHover then
          local fadeDuration = Core.db.profile.chatFadeInDuration or 0.3
          for _, message in ipairs(self.state.messages) do
            message:FadeIn(fadeDuration)
          end
        end
      end),
      Core:Subscribe(MOUSE_LEAVE, function ()
        -- Hide chats when mouse leaves
        self.state.mouseOver = false

        self.overlay:HideDelay(Core.db.profile.chatHoldTime)

        -- Always fade out messages when mouse leaves
        for _, message in ipairs(self.state.messages) do
          message:HideDelay(Core.db.profile.chatHoldTime)
        end
      end),
      -- Edit focus shows ALL messages regardless of messagesOnHover setting
      Core:Subscribe(EDIT_FOCUS_GAINED, function ()
        self.state.mouseOver = true
        
        -- Cancel all hide timers
        for _, message in ipairs(self.state.messages) do
          if message.hideTimer then
            message.hideTimer:Cancel()
            message.hideTimer = nil
          end
        end
        
        -- Always show ALL messages with animation when edit box is focused
        local fadeDuration = Core.db.profile.chatFadeInDuration or 0.3
        for _, message in ipairs(self.state.messages) do
          message:FadeIn(fadeDuration)
        end
      end),
      Core:Subscribe(EDIT_FOCUS_LOST, function ()
        self.state.mouseOver = false
        
        self.overlay:HideDelay(Core.db.profile.chatHoldTime)
        
        -- Start fade out timers for all messages
        for _, message in ipairs(self.state.messages) do
          message:HideDelay(Core.db.profile.chatHoldTime)
        end
      end),
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if self.state.isCombatLog == false then
          if (
            key == "font" or
            key == "messageFontSize" or
            key == "frameWidth" or
            key == "frameHeight" or
            key == "messageLeading" or
            key == "messageLinePadding" or
            key == "indentWordWrap"
          ) then
            -- Adjust frame dimensions first
            self.config.height = Core.db.profile.frameHeight - Constants.DOCK_HEIGHT - 5
            self.config.width = Core.db.profile.frameWidth

            self:SetHeight(self.config.height + self.config.overflowHeight)
            self:SetWidth(self.config.width)

            -- Then adjust message line dimensions
            for _, message in ipairs(self.state.messages) do
                message:UpdateFrame()
            end

            -- Then update scroll values
            local contentHeight = reduce(self.state.messages, function (acc, message)
              return acc + message:GetHeight()
            end, 0)
            self.slider:SetHeight(self.config.height + self.config.overflowHeight + contentHeight)
            self.slider:SetWidth(self.config.width)

            self.state.scrollAtBottom = true
            self.state.unreadMessages = false
            self:UpdateScrollChildRect()
            self:SetVerticalScroll(self:GetVerticalScrollRange() + self.config.overflowHeight)
            self.overlay:Hide()
            self.overlay:HideNewMessageAlert()
          end

          if key == "chatBackgroundOpacity" then
            for _, message in ipairs(self.state.messages) do
              message:UpdateTextures()
            end
          end

          if key == "messagesOnHover" then
            -- When toggled, just show current messages if mouse is over and option is now enabled
            if Core.db.profile.messagesOnHover and self.state.mouseOver then
              for _, message in ipairs(self.state.messages) do
                message:Show()
              end
            end
          end
        end
      end)
    }
  end
end

function SlidingMessageFrameMixin:CreateMessageFrame(frame, text, red, green, blue, messageId, holdTime)
  red = red or 1
  green = green or 1
  blue = blue or 1

  local message = self.messageFramePool:Acquire()

  message.text:SetTextColor(red, green, blue, 1)
  local processed = TP:ProcessText(text)
  message:SetMessageText(processed)

  -- Adjust height to contain text
  message:UpdateFrame()

  return message
end

function SlidingMessageFrameMixin:AddMessage(...)
  -- Enqueue messages to be displayed
  local args = {...}
  table.insert(self.state.incomingMessages, args)
end

-- Recompute the scroll-child height from the current message heights, keeping
-- the view pinned to the bottom when appropriate.
function SlidingMessageFrameMixin:RecomputeContentHeight()
  local contentHeight = reduce(self.state.messages, function (acc, message)
    return acc + (message:GetHeight() or 0)
  end, 0)
  self.slider:SetHeight(self.config.height + self.config.overflowHeight + contentHeight)
  self:UpdateScrollChildRect()
  if self.state.scrollAtBottom then
    self:SetVerticalScroll(self:GetVerticalScrollRange() + self.config.overflowHeight)
  end
end

function SlidingMessageFrameMixin:OnFrame()
  -- Messages created on the previous frame have now been laid out by the engine,
  -- so their text height is finally reliable. GetStringHeight() can be stale on
  -- the same frame SetText() runs (especially for wrapped quest/loot rewards),
  -- which makes message frames too short and overlap. Re-measure them now and
  -- fix the layout if any height changed.
  if self.state.pendingMeasure and #self.state.pendingMeasure > 0 then
    local changed = false
    for _, message in ipairs(self.state.pendingMeasure) do
      local before = message:GetHeight() or 0
      message:UpdateFrame()
      if math.abs((message:GetHeight() or 0) - before) > 0.5 then
        changed = true
      end
    end
    self.state.pendingMeasure = {}
    if changed then
      self:RecomputeContentHeight()
    end
  end

  if #self.state.incomingMessages > 0 then
    local incoming = {}
    for _, message in ipairs(self.state.incomingMessages) do
      table.insert(incoming, message)
    end
    self.state.incomingMessages = {}
    self:Update(incoming)
  end
end

function SlidingMessageFrameMixin:Update(incoming)
  -- Create new message frame for each message
  local newMessages = {}

  for _, message in ipairs(incoming) do
    local messageFrame = self:CreateMessageFrame(unpack(message))
    messageFrame:SetPoint("BOTTOMLEFT")

    -- Attach previous messageFrame to this one
    if self.state.head then
      self.state.head:ClearAllPoints()
      self.state.head:SetPoint("BOTTOMLEFT", messageFrame, "TOPLEFT")
    end

    if self.state.tail == nil then
      self.state.tail = messageFrame
    end

    if self.state.head == nil then
      self.state.head = messageFrame
    end

    self.state.head = messageFrame

    table.insert(newMessages, messageFrame)
  end

  -- Update slider offsets animation
  local offset = reduce(newMessages, function (acc, message)
    return acc + message:GetHeight()
  end, 0)

  local newHeight = self.slider:GetHeight() + offset
  self.slider:SetHeight(newHeight)

  -- Display and run everything
  if self.state.scrollAtBottom then
    -- Only play slide up if not scrolling
    if self.state.prevEasingHandle ~= nil then
      LibEasing:StopEasing(self.state.prevEasingHandle)
    end

    local startOffset = self:GetVerticalScroll()
    local endOffset = newHeight - self:GetHeight() + self.config.overflowHeight

    if Core.db.profile.chatSlideInDuration > 0 then
      self.state.prevEasingHandle = LibEasing:Ease(
        function (n) self:SetVerticalScroll(n) end,
        startOffset,
        endOffset,
        Core.db.profile.chatSlideInDuration,
        LibEasing.OutCubic
      )
    else
      self:SetVerticalScroll(endOffset)
    end
  else
    -- Otherwise show "Unread messages" notification
    self.state.unreadMessages = true
    self.overlay:Show()
    self.overlay:ShowNewMessageAlert()
    if not self.state.mouseOver then
      self.overlay:HideDelay(Core.db.profile.chatHoldTime)
    end
  end

  for _, message in ipairs(newMessages) do
    message:Show()
    -- Always fade out new messages when mouse is not over
    if not self.state.mouseOver then
      message:HideDelay(Core.db.profile.chatHoldTime)
    end
    table.insert(self.state.messages, message)

    -- Queue for a next-frame re-measure so the layout is corrected once the
    -- engine has laid the text out (fixes overlapping messages).
    self.state.pendingMeasure = self.state.pendingMeasure or {}
    table.insert(self.state.pendingMeasure, message)
  end

  -- Release old messages
  local historyLimit = 128
  if #self.state.messages > historyLimit then
    local overflow = #self.state.messages - historyLimit
    local oldMessages = take(self.state.messages, overflow)
    self.state.messages = drop(self.state.messages, overflow)

    for _, message in ipairs(oldMessages) do
      self.messageFramePool:Release(message)
    end
  end
end

local function CreateSlidingMessageFrame(name, parent, chatFrame)
  local frame = CreateFrame("ScrollFrame", name, parent)
  local object = Mixin(frame, SlidingMessageFrameMixin)
  AceHook:Embed(object)

  if chatFrame then
    object:Init(chatFrame)
  end
  object:Hide()
  return object
end

local function CreateSlidingMessageFramePool(parent)
  return CreateObjectPool(
    function () return CreateSlidingMessageFrame(nil, parent) end,
    function (_, smf)
      smf:Hide()

      if smf.chatFrame and not smf.state.isCombatLog then
        -- Only unhook if we actually hooked
        if smf:IsHooked(smf.chatFrame, "AddMessage") then
          smf:Unhook(smf.chatFrame, "AddMessage")
        end
        if smf:IsHooked(smf.chatFrame, "SetAlpha") then
          smf:Unhook(smf.chatFrame, "SetAlpha")
        end
        if smf:IsHooked(smf.chatFrame, "Show") then
          smf:Unhook(smf.chatFrame, "Show")
        end
        -- Note: historyBuffer doesn't exist in WotLK 3.3.5
      end

      if smf.state ~= nil then
        smf.state.head = nil
        smf.state.tail = nil
        smf.state.messages = {}
        smf.state.incomingMessages = {}
      end

      if smf.messageFramePool ~= nil then
        smf.messageFramePool:ReleaseAll()
      end
    end
  )
end

Core.Components.CreateSlidingMessageFrame = CreateSlidingMessageFrame
Core.Components.CreateSlidingMessageFramePool = CreateSlidingMessageFramePool
