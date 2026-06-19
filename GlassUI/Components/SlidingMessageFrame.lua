local Core, Constants = unpack(select(2, ...))
local TP = Core:GetModule("TextProcessing")

local AceHook = Core.Libs.AceHook

local LibEasing = Core.Libs.LibEasing
local lodash = Core.Libs.lodash
local drop, reduce, take = lodash.drop, lodash.reduce, lodash.take

local CreateMessageLinePool = Core.Components.CreateMessageLinePool
local CreateScrollOverlayFrame = Core.Components.CreateScrollOverlayFrame

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
    incomingScrollbackMessages = {},
    incomingMessages = {},
    messages = {},
    head = nil,
    tail = nil,
    isCombatLog = false,
    scrollAtBottom = true,
    unreadMessages = false,
  }
  self.chatFrame = chatFrame

  -- Skip combat log FIRST - don't modify it at all to avoid breaking Blizzard_CombatLog
  -- The combat log needs its positioning intact for FCF_DockUpdate to work
  if chatFrame == _G.ChatFrame2 then
    self.state.isCombatLog = true
    -- Still hide the button frame for combat log
    local buttonFrame = _G[chatFrame:GetName().."ButtonFrame"]
    if buttonFrame then
      buttonFrame:Hide()
    end
    -- Don't modify anything else - let Blizzard handle it completely
    return
  end

  -- Hide Blizzard UI elements (but don't modify chatFrame parent/position)
  local buttonFrame = _G[chatFrame:GetName().."ButtonFrame"]
  if buttonFrame then
    buttonFrame:Hide()
  end

  -- Make the original chat frame invisible but don't change its parent
  -- This preserves Blizzard's internal state
  chatFrame:SetAlpha(0)

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

  self:Hook(chatFrame, "AddMessage", function (...)
    self:AddMessage(...)
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
      end),
      Core:Subscribe(MOUSE_LEAVE, function ()
        -- Hide chats when mouse leaves
        self.state.mouseOver = false

        self.overlay:HideDelay(Core.db.profile.chatHoldTime)

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
  message.text:SetText(TP:ProcessText(text))

  -- Adjust height to contain text
  message:UpdateFrame()

  return message
end

function SlidingMessageFrameMixin:AddMessage(...)
  -- Enqueue messages to be displayed
  local args = {...}
  table.insert(self.state.incomingMessages, args)
end

function SlidingMessageFrameMixin:BackFillMessage(...)
  local args = {...}
  table.insert(self.state.incomingScrollbackMessages, args)
end

function SlidingMessageFrameMixin:OnFrame()
  if #self.state.incomingMessages > 0 then
    local incoming = {}
    for _, message in ipairs(self.state.incomingMessages) do
      table.insert(incoming, message)
    end
    self.state.incomingMessages = {}
    self:Update(incoming, false)
  end

  if #self.state.incomingScrollbackMessages > 0 then
    local incoming = {}
    for _, message in ipairs(self.state.incomingScrollbackMessages) do
      table.insert(incoming, message)
    end
    self.state.incomingScrollbackMessages = {}
    self:Update(incoming, true)
  end
end

function SlidingMessageFrameMixin:Update(incoming, reverse)
  -- Create new message frame for each message
  local newMessages = {}

  for _, message in ipairs(incoming) do
    local messageFrame = self:CreateMessageFrame(unpack(message))
    messageFrame:SetPoint("BOTTOMLEFT")

    -- Attach previous messageFrame to this one
    if reverse then
      if self.state.tail then
        messageFrame:ClearAllPoints()
        messageFrame:SetPoint("BOTTOMLEFT", self.state.tail, "TOPLEFT")
      end
    else
      if self.state.head then
        self.state.head:ClearAllPoints()
        self.state.head:SetPoint("BOTTOMLEFT", messageFrame, "TOPLEFT")
      end
    end

    if self.state.tail == nil then
      self.state.tail = messageFrame
    end

    if self.state.head == nil then
      self.state.head = messageFrame
    end

    if reverse then
      self.state.tail = messageFrame
    else
      self.state.head = messageFrame
    end

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
    if not self.state.mouseOver then
      message:HideDelay(Core.db.profile.chatHoldTime)
    end
    if reverse then
      table.insert(self.state.messages, 1, message)
    else
      table.insert(self.state.messages, message)
    end
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
        -- Only unhook if we actually hooked (combat log returns early, no hooks)
        if smf:IsHooked(smf.chatFrame, "AddMessage") then
          smf:Unhook(smf.chatFrame, "AddMessage")
        end
        -- Note: We no longer hook Show/Hide/SetPoint
        -- Note: historyBuffer doesn't exist in WotLK 3.3.5
      end

      if smf.state ~= nil then
        smf.state.head = nil
        smf.state.tail = nil
        smf.state.messages = {}
        smf.state.incomingMessages = {}
        smf.state.incomingScrollbackMessages = {}
      end

      if smf.messageFramePool ~= nil then
        smf.messageFramePool:ReleaseAll()
      end
    end
  )
end

Core.Components.CreateSlidingMessageFrame = CreateSlidingMessageFrame
Core.Components.CreateSlidingMessageFramePool = CreateSlidingMessageFramePool
