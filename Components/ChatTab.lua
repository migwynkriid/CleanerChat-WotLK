local Core, Constants = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook

local UnlockMover = Constants.ACTIONS.UnlockMover

local Colors = Constants.COLORS

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- luacheck: push ignore 113
local CHAT_CONFIGURATION = CHAT_CONFIGURATION
local CLOSE_CHAT_WINDOW = CLOSE_CHAT_WINDOW
local ChatConfigFrame = ChatConfigFrame
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local FCF_GetNumActiveChatFrames = FCF_GetNumActiveChatFrames
local FCF_NewChatWindow = FCF_NewChatWindow
local FCF_PopInWindow = FCF_PopInWindow
local FCF_RenameChatWindow_Popup = FCF_RenameChatWindow_Popup
local FCF_StopAlertFlash = FCF_StopAlertFlash
local FILTERS = FILTERS
local IsCombatLog = IsCombatLog
local Mixin = Mixin
local NEW_CHAT_WINDOW = NEW_CHAT_WINDOW
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local RENAME_CHAT_WINDOW = RENAME_CHAT_WINDOW
local ShowUIPanel = ShowUIPanel
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UNLOCK_WINDOW = UNLOCK_WINDOW
-- luacheck: pop

local tabTexs = {
  '',
  'Selected',
  'Highlight'
}

local ChatTabMixin = {}

function ChatTabMixin:Init(slidingMessageFrame)
  self.slidingMessageFrame = slidingMessageFrame
  self.chatFrame = slidingMessageFrame.chatFrame
  local dropDown = _G[self.chatFrame:GetName().."TabDropDown"]

  for _, texName in ipairs(tabTexs) do
    local leftTex = _G[self:GetName()..texName..'Left']
    local middleTex = _G[self:GetName()..texName..'Middle']
    local rightTex = _G[self:GetName()..texName..'Right']
    if leftTex then leftTex:SetTexture() end
    if middleTex then middleTex:SetTexture() end
    if rightTex then rightTex:SetTexture() end
  end

  self:SetHeight(Constants.DOCK_HEIGHT)
  
  -- Try to set custom font, but don't fail if it doesn't exist yet
  local glassFont = _G["GlassChatDockFont"]
  if glassFont then
    self:SetNormalFontObject(glassFont)
  end
  
  -- In WotLK 3.3.5, the text element may be accessed differently
  local tabText = self.Text or _G[self:GetName().."Text"] or self:GetFontString()
  self.Text = tabText  -- Store reference for later use
  
  if tabText then
    tabText:ClearAllPoints()
    tabText:SetPoint("LEFT", Constants.TEXT_XPADDING, 0)
    local textWidth = tabText:GetStringWidth()
    if textWidth and textWidth > 10 then
      self:SetWidth(textWidth + Constants.TEXT_XPADDING * 2)
    else
      self:SetWidth(60)  -- Default width if text not available
    end
  else
    self:SetWidth(60)  -- Default width
  end

  if not self:IsHooked(self, "SetAlpha") then
    self:RawHook(self, "SetAlpha", function (alpha)
      self.hooks[self].SetAlpha(self, 1)
    end, true)
  end

  -- Set width dynamically based on text width
  if not self:IsHooked(self, "SetWidth") then
    self:RawHook(self, "SetWidth", function (_, width)
      local textWidth = self:GetTextWidth() or 0
      local newWidth = textWidth + Constants.TEXT_XPADDING * 2
      if newWidth < 40 then
        newWidth = 60  -- Minimum width
      end
      self.hooks[self].SetWidth(self, newWidth)
    end, true)
  end

  if tabText and not self:IsHooked(tabText, "SetTextColor") then
    self:RawHook(tabText, "SetTextColor", function (...)
      -- Temporary chat frames retain their color
      if self.chatFrame.isTemporary then
        self.hooks[tabText].SetTextColor(...)
      else
        self.hooks[tabText].SetTextColor(tabText, Colors.apache.r, Colors.apache.g, Colors.apache.b)
      end
    end, true)
  end

  -- Don't highlight when frame is already visible
  -- Note: self.glow may not exist in WotLK 3.3.5
  if self.glow and not self:IsHooked(self.glow, "Show") then
    self:RawHook(self.glow, "Show", function ()
      if not slidingMessageFrame:IsVisible() then
        self.hooks[self.glow].Show(self.glow)
      end
    end, true)
  end

  -- Override OnClick to handle our tab selection
  -- Store original script before overriding
  local originalOnClick = self:GetScript("OnClick")
  self:SetScript("OnClick", function(frame, button)
    if FCF_StopAlertFlash then
      FCF_StopAlertFlash(self.chatFrame)
    end
    
    -- Switch to this SlidingMessageFrame (our custom handler)
    Core.Components.SelectChatTab(self)
    
    -- For Combat Log, skip the original Blizzard handler since we manage it ourselves
    -- Otherwise Blizzard's handler interferes with our show/hide logic
    if IsCombatLog(self.chatFrame) then
      return
    end
    
    -- Also call original handler to let Blizzard know which chat is selected
    -- This keeps SELECTED_CHAT_FRAME in sync
    if originalOnClick then
      originalOnClick(frame, button)
    end
  end)

  -- Disable dragging for General and CombatLog
  if self.chatFrame == DEFAULT_CHAT_FRAME or IsCombatLog(self.chatFrame) then
    self:RegisterForDrag()
  end

  -- Override context menu
  UIDropDownMenu_Initialize(dropDown, function ()
    local info = UIDropDownMenu_CreateInfo()

    if self.chatFrame == DEFAULT_CHAT_FRAME then
      -- Unlock chat window
      info = UIDropDownMenu_CreateInfo()
      info.text = UNLOCK_WINDOW
      info.notCheckable = 1
      info.func = function()
        Core:Dispatch(UnlockMover())
      end
      UIDropDownMenu_AddButton(info)

      -- Create new chat window
      info = UIDropDownMenu_CreateInfo()
      info.text = NEW_CHAT_WINDOW
      info.func = FCF_NewChatWindow
      info.notCheckable = 1
      if FCF_GetNumActiveChatFrames() == NUM_CHAT_WINDOWS then
        info.disabled = 1
      end
      UIDropDownMenu_AddButton(info)
    end

    -- Rename window
    info.text = RENAME_CHAT_WINDOW
    info.func = FCF_RenameChatWindow_Popup
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info)

    -- Close chat window
    if self.chatFrame ~= DEFAULT_CHAT_FRAME and not IsCombatLog(self.chatFrame) then
      info = UIDropDownMenu_CreateInfo()
      info.text = CLOSE_CHAT_WINDOW
      info.func = FCF_PopInWindow
      info.arg1 = self.chatFrame
      info.notCheckable = 1
      UIDropDownMenu_AddButton(info)
    end

    -- Filter header
    info = UIDropDownMenu_CreateInfo()
    info.text = FILTERS
    info.isTitle = 1
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info)

    -- Configure settings
    info = UIDropDownMenu_CreateInfo()
    info.text = CHAT_CONFIGURATION
    info.func = function() ShowUIPanel(ChatConfigFrame) end
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info)

    -- CleanerChat settings (opens the /cc options panel)
    info = UIDropDownMenu_CreateInfo()
    info.text = "CleanerChat settings"
    info.notCheckable = 1
    info.func = function()
      local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
      local cc = AceAddon and AceAddon:GetAddon("CleanerChat", true)
      local options = cc and cc:GetModule("Options", true)
      if options then
        options:OpenOptionsMenu("")
      end
    end
    UIDropDownMenu_AddButton(info)
  end, "MENU")

  -- Listeners
  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if key == "frameWidth" or key == "frameHeight" or key == "dockFont" or key == "messageFontSize" then
          self:SetWidth()
        end
      end)
    }
  end
end

Core.Components.CreateChatTab = function (slidingMessageFrame)
  local frameName = slidingMessageFrame.chatFrame:GetName()
  local tabName = frameName.."Tab"
  local frame = _G[tabName]
  
  if not frame then
    return nil  -- Tab doesn't exist
  end
  
  -- If already initialized, just return it
  if frame._glassInitialized then
    return frame
  end
  
  local object = Mixin(frame, ChatTabMixin)
  AceHook:Embed(object)
  
  local success = pcall(function()
    object:Init(slidingMessageFrame)
  end)
  
  if not success then
    return nil
  end
  
  -- Mark as initialized
  frame._glassInitialized = true
  
  -- Store reference to dock for later positioning
  object.glassDock = _G["GlassChatDock"]
  
  return object
end

-- Helper function to update tab positions (called after all tabs are created)
Core.Components.UpdateTabPositions = function(tabs)
  local glassDock = _G["GlassChatDock"]
  if not glassDock then 
    return 
  end
  
  local xOffset = 5  -- Small padding from left edge
  for i, tab in ipairs(tabs) do
    if tab then
      -- Reparent to our dock
      tab:SetParent(glassDock)
      tab:SetFrameStrata("MEDIUM")
      tab:SetFrameLevel(11)  -- Above the dock background
      tab:ClearAllPoints()
      tab:SetPoint("BOTTOMLEFT", glassDock, "BOTTOMLEFT", xOffset, 0)
      
      -- Force alpha and visibility
      if tab.hooks and tab.hooks[tab] and tab.hooks[tab].SetAlpha then
        tab.hooks[tab].SetAlpha(tab, 1)
      else
        tab:SetAlpha(1)
      end
      tab:Show()  -- Ensure tab is visible
      
      -- Use GetWidth but ensure minimum width
      local tabWidth = tab:GetWidth()
      if tabWidth < 30 then
        tabWidth = 60  -- Default minimum width
      end
      xOffset = xOffset + tabWidth + 5  -- Add spacing between tabs
    end
  end
end

-- Track currently selected tab
Core.Components.selectedTab = nil

-- Select a chat tab and show its SlidingMessageFrame
Core.Components.SelectChatTab = function(selectedTab)
  local UIManager = Core:GetModule("UIManager")
  if not UIManager or not UIManager.state then 
    return 
  end
  
  local frames = UIManager.state.frames
  local tabs = UIManager.state.tabs
  
  -- Store selected tab
  Core.Components.selectedTab = selectedTab
  
  -- Get the chatFrame for the selected tab
  local selectedChatFrame = selectedTab.chatFrame
  
  -- Sync to Blizzard's selection state so dropdown menu callbacks work correctly
  -- Without this, "Move to new window" and similar actions fail because
  -- FCF_GetCurrentChatFrame() returns nil or the wrong frame
  if selectedChatFrame then
    SELECTED_CHAT_FRAME = selectedChatFrame
    SELECTED_DOCK_FRAME = selectedChatFrame
  end
  
  -- Check if Combat Log tab is being selected
  local combatLogFrame = _G.ChatFrame2
  local selectingCombatLog = (selectedChatFrame == combatLogFrame)
  
  -- Always hide the Combat Log quick-button bar ("Self / Everything / What happened to me?")
  -- It can appear at various times so we hide it on every tab switch
  local combatLogButtons = _G["CombatLogQuickButtonFrame"]
  if combatLogButtons then
    combatLogButtons:Hide()
    combatLogButtons:SetAlpha(0)
  end
  
  -- Show/hide native Combat Log based on selection
  -- WotLK Combat Log doesn't use AddMessage, so we show the native frame
  if combatLogFrame then
    if selectingCombatLog then
      -- Show native Combat Log and restore all its properties
      combatLogFrame:Show()
      combatLogFrame:SetAlpha(1)
      combatLogFrame:EnableMouse(true)
      combatLogFrame:EnableMouseWheel(true)
      -- Position it below the Glass dock area (extra offset to avoid overlap)
      combatLogFrame:ClearAllPoints()
      combatLogFrame:SetPoint("TOPLEFT", UIManager.container, "TOPLEFT", 0, -Constants.DOCK_HEIGHT - 30)
      combatLogFrame:SetPoint("BOTTOMRIGHT", UIManager.container, "BOTTOMRIGHT", 0, 0)
    else
      -- Hide native Combat Log when other tabs selected
      combatLogFrame:Hide()
      combatLogFrame:SetAlpha(0)
    end
  end
  
  -- Show/hide SlidingMessageFrames based on selection
  for i, smf in pairs(frames) do
    if smf and smf.chatFrame and smf.Show and smf.Hide then
      -- Skip showing Glass overlay for Combat Log (it uses native rendering)
      if smf.state and smf.state.isCombatLog then
        smf:Hide()
      elseif smf.chatFrame == selectedChatFrame then
        smf:Show()
      else
        -- Hide every other frame's messages so only the selected tab is visible
        smf:Hide()
      end
    end
  end
  
  -- Update tab visual states and ensure all tabs stay visible
  for i, tab in pairs(tabs) do
    if tab then
      -- Keep all tabs visible
      tab:Show()
      
      local tabText = tab.Text or _G[tab:GetName().."Text"]
      if tabText then
        if tab == selectedTab then
          -- Selected tab - brighter color
          tabText:SetTextColor(1, 1, 1)  -- White for selected
        else
          -- Unselected tab - use Glass color
          tabText:SetTextColor(Colors.apache.r, Colors.apache.g, Colors.apache.b)
        end
      end
    end
  end
  
  -- Ensure dock stays visible
  local glassDock = _G["GlassChatDock"]
  if glassDock then
    glassDock:Show()
  end
end
