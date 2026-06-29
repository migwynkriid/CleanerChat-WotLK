local Core, Constants = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook
local LSM = Core.Libs.LSM

-- Dedicated AceHook host. We must NOT embed AceHook onto the native Blizzard
-- chat tab frames (ChatFrameNTab): Embed() overwrites the frame's native
-- :HookScript with AceHook's incompatible version, which breaks other addons
-- that call tab:HookScript(...). Hooking through a separate plain-table host
-- keeps the tab's native methods intact. Hooks are keyed by the hooked object,
-- so a single shared host works for every tab.
local Hooker = {}
AceHook:Embed(Hooker)

local UnlockMover = Constants.ACTIONS.UnlockMover

local Colors = Constants.COLORS

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

local L = LibStub("AceLocale-3.0"):GetLocale("CleanerChat")

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
  
  -- Apply per-window font settings
  self:UpdateFontFromProfile()
  
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

  if not Hooker:IsHooked(self, "SetAlpha") then
    Hooker:RawHook(self, "SetAlpha", function (alpha)
      Hooker.hooks[self].SetAlpha(self, 1)
    end, true)
  end

  -- Set width dynamically based on text width
  if not Hooker:IsHooked(self, "SetWidth") then
    Hooker:RawHook(self, "SetWidth", function (_, width)
      local textWidth = 0
      if self.Text then
        textWidth = self.Text:GetStringWidth() or 0
      end
      local newWidth = textWidth + Constants.TEXT_XPADDING * 2
      if newWidth < 40 then
        newWidth = 60  -- Minimum width
      end
      Hooker.hooks[self].SetWidth(self, newWidth)
    end, true)
  end

  if tabText and not Hooker:IsHooked(tabText, "SetTextColor") then
    Hooker:RawHook(tabText, "SetTextColor", function (...)
      -- Temporary chat frames retain their color
      if self.chatFrame.isTemporary then
        Hooker.hooks[tabText].SetTextColor(...)
      else
        Hooker.hooks[tabText].SetTextColor(tabText, Colors.apache.r, Colors.apache.g, Colors.apache.b)
      end
    end, true)
  end

  -- Hook SetText to recalculate tab width when renamed
  if tabText and not Hooker:IsHooked(tabText, "SetText") then
    Hooker:RawHook(tabText, "SetText", function (fontString, text)
      -- Call original SetText first
      Hooker.hooks[tabText].SetText(fontString, text)
      -- Defer width recalculation to next frame so text layout is updated
      if not self._widthUpdateFrame then
        self._widthUpdateFrame = CreateFrame("Frame")
      end
      self._widthUpdateFrame:SetScript("OnUpdate", function(frame)
        frame:SetScript("OnUpdate", nil)
        self:SetWidth()
      end)
    end, true)
  end

  -- Don't highlight when frame is already visible
  -- Note: self.glow may not exist in WotLK 3.3.5
  if self.glow and not Hooker:IsHooked(self.glow, "Show") then
    Hooker:RawHook(self.glow, "Show", function ()
      if not slidingMessageFrame:IsVisible() then
        Hooker.hooks[self.glow].Show(self.glow)
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
    
    -- Switch to this SlidingMessageFrame (our custom handler). The `true` flag
    -- marks this as a real user click so it also makes this window active.
    Core.Components.SelectChatTab(self, true)
    
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
    
    -- Get the UIManager module for window operations (used for multi-window features)
    local UIManager = Core:GetModule("UIManager", true)
    local chatFrameIndex = self.chatFrame:GetID()
    local currentWindowId = nil
    if UIManager then
      local _
      _, currentWindowId = UIManager:GetWindowForChatFrame(chatFrameIndex)
    end

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

    -- Close chat window (for non-default, non-combat-log frames in Main window only)
    -- For detached CleanerChat windows, "Delete window" handles closing
    if self.chatFrame ~= DEFAULT_CHAT_FRAME and not IsCombatLog(self.chatFrame) and (not currentWindowId or currentWindowId == "Main") then
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
    info.text = L["CleanerChat settings"]
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

    -- "New window" — spawn a brand-new CleanerChat window (a new chat frame
    -- rendered as its own Glass window, copying the current window's settings).
    -- Available on ANY chat tab that is not the Combat Log.
    if UIManager and not IsCombatLog(self.chatFrame) then
      info = UIDropDownMenu_CreateInfo()
      info.text = L["New detached window"]
      info.notCheckable = 1
      info.func = function()
        UIManager:SpawnNewWindow(currentWindowId)
      end
      UIDropDownMenu_AddButton(info)

      -- "Delete window" — only on non-default (added) windows.
      if currentWindowId ~= "Main" then
        info = UIDropDownMenu_CreateInfo()
        info.text = L["Delete window"]
        info.notCheckable = 1
        info.func = function()
          UIManager:DeleteWindow(currentWindowId)
        end
        UIDropDownMenu_AddButton(info)
      end
    end
  end, "MENU")

  -- Listeners
  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(UPDATE_CONFIG, function (payload)
        local key = Core:ResolveConfigKey(payload, (self.slidingMessageFrame and self.slidingMessageFrame.window and self.slidingMessageFrame.window.id) or "Main")
        
        if key == nil then return end
        
        if key == "frameWidth" or key == "frameHeight" or key == "dockFont" or key == "messageFontSize" then
          self:SetWidth()
        end
        
        -- Update font when dock font settings change for this window
        if key == "dockFont" or key == "dockFontSize" or key == "dockFontFlags" then
          self:UpdateFontFromProfile()
        end
        
        -- Update skin when tab style settings change for this window
        if key == "tabStyle" or key == "tabCornerStyle" or key == "tabActiveColor" 
           or key == "tabInactiveColor" or key == "tabBackgroundOpacity" or key == "tabBorderThickness" then
          self:ApplySkin()
          self:UpdateSkinColors()
        end
        
        -- Update tab positions when spacing settings change
        if key == "tabSpacing" or key == "tabPadding" then
          local UIManager = Core:GetModule("UIManager")
          if UIManager and UIManager.windows then
            for _, window in pairs(UIManager.windows) do
              if window.tabs then
                Core.Components.UpdateTabPositions(window.tabs)
              end
            end
          end
        end
      end)
    }
  end
  
  -- Apply initial skin
  self:ApplySkin()
end

---
-- Apply the visual skin style to the tab button.
-- Supports: minimal (text only), outline (border only)
-- With corner styles: square or rounded
function ChatTabMixin:ApplySkin()
  local profile = self.slidingMessageFrame and self.slidingMessageFrame.window and self.slidingMessageFrame.window.profile
  profile = profile or Core.db.profile
  
  local style = profile.tabStyle or "minimal"
  -- Backward compatibility: old styles map to outline
  if style == "modern" or style == "filled" then style = "outline" end
  
  local cornerStyle = profile.tabCornerStyle or "square"
  local isRounded = cornerStyle == "rounded"
  local isOutline = style == "outline"
  
  if isOutline then
    if isRounded then
      -- ROUNDED CORNERS: Use backdrop-based rendering
      -- Hide texture-based elements
      if self.skinBorderTop then self.skinBorderTop:Hide() end
      if self.skinBorderBottom then self.skinBorderBottom:Hide() end
      if self.skinBorderLeft then self.skinBorderLeft:Hide() end
      if self.skinBorderRight then self.skinBorderRight:Hide() end
      
      -- Create backdrop frame if needed
      if not self.skinBackdrop then
        self.skinBackdrop = CreateFrame("Frame", nil, self)
        self.skinBackdrop:SetFrameLevel(math.max(1, self:GetFrameLevel() - 1))
        self.skinBackdrop:SetAllPoints()
      end
      
      -- Set rounded backdrop (tooltip border has natural rounded corners)
      self.skinBackdrop:SetBackdrop({
        bgFile = nil, -- No fill, outline only
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 0,
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
      })
      self.skinBackdrop:Show()
      
    else
      -- SQUARE CORNERS: Use 4 edge textures for true outline
      -- Hide backdrop if exists
      if self.skinBackdrop then self.skinBackdrop:Hide() end
      
      local borderThickness = profile.tabBorderThickness or 1
      
      -- Create top edge
      if not self.skinBorderTop then
        self.skinBorderTop = self:CreateTexture(nil, "BACKGROUND", nil, -8)
        self.skinBorderTop:SetTexture("Interface\\Buttons\\WHITE8x8")
        self.skinBorderTop:SetPoint("TOPLEFT", 0, 0)
        self.skinBorderTop:SetPoint("TOPRIGHT", 0, 0)
      end
      self.skinBorderTop:SetHeight(borderThickness)
      
      -- Create bottom edge
      if not self.skinBorderBottom then
        self.skinBorderBottom = self:CreateTexture(nil, "BACKGROUND", nil, -8)
        self.skinBorderBottom:SetTexture("Interface\\Buttons\\WHITE8x8")
        self.skinBorderBottom:SetPoint("BOTTOMLEFT", 0, 0)
        self.skinBorderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
      end
      self.skinBorderBottom:SetHeight(borderThickness)
      
      -- Create left edge
      if not self.skinBorderLeft then
        self.skinBorderLeft = self:CreateTexture(nil, "BACKGROUND", nil, -8)
        self.skinBorderLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
        self.skinBorderLeft:SetPoint("TOPLEFT", 0, 0)
        self.skinBorderLeft:SetPoint("BOTTOMLEFT", 0, 0)
      end
      self.skinBorderLeft:SetWidth(borderThickness)
      
      -- Create right edge
      if not self.skinBorderRight then
        self.skinBorderRight = self:CreateTexture(nil, "BACKGROUND", nil, -8)
        self.skinBorderRight:SetTexture("Interface\\Buttons\\WHITE8x8")
        self.skinBorderRight:SetPoint("TOPRIGHT", 0, 0)
        self.skinBorderRight:SetPoint("BOTTOMRIGHT", 0, 0)
      end
      self.skinBorderRight:SetWidth(borderThickness)
      
      self.skinBorderTop:Show()
      self.skinBorderBottom:Show()
      self.skinBorderLeft:Show()
      self.skinBorderRight:Show()
    end
    
    -- Hook hover events for visual feedback (only once)
    if not self._skinHoverHooked then
      self._skinHoverHooked = true
      self:HookScript("OnEnter", function()
        self:UpdateSkinColors(true)
      end)
      self:HookScript("OnLeave", function()
        self:UpdateSkinColors(false)
      end)
    end
    
  else
    -- Minimal style - hide all decoration elements
    if self.skinBorderTop then self.skinBorderTop:Hide() end
    if self.skinBorderBottom then self.skinBorderBottom:Hide() end
    if self.skinBorderLeft then self.skinBorderLeft:Hide() end
    if self.skinBorderRight then self.skinBorderRight:Hide() end
    if self.skinBackdrop then self.skinBackdrop:Hide() end
  end
  
  self:UpdateSkinColors()
end

---
-- Update skin colors based on selection state and hover.
-- @param isHovered boolean (optional) Whether the tab is being hovered
function ChatTabMixin:UpdateSkinColors(isHovered)
  local profile = self.slidingMessageFrame and self.slidingMessageFrame.window and self.slidingMessageFrame.window.profile
  profile = profile or Core.db.profile
  
  local style = profile.tabStyle or "minimal"
  -- Backward compatibility
  if style == "modern" or style == "filled" then style = "outline" end
  
  local cornerStyle = profile.tabCornerStyle or "square"
  local isRounded = cornerStyle == "rounded"
  local isOutline = style == "outline"
  
  if not isOutline then return end
  
  local isSelected = (Core.Components.selectedTab == self)
  
  -- Get colors from profile
  local activeColor = profile.tabActiveColor or { r = 223/255, g = 186/255, b = 105/255 }
  local inactiveColor = profile.tabInactiveColor or { r = 0.4, g = 0.4, b = 0.4 }
  local bgOpacity = profile.tabBackgroundOpacity or 0.7
  
  -- Determine the base color
  local baseColor = isSelected and activeColor or inactiveColor
  
  -- Apply hover brightening effect
  local hoverMult = isHovered and 1.3 or 1.0
  local r = math.min(1, baseColor.r * hoverMult)
  local g = math.min(1, baseColor.g * hoverMult)
  local b = math.min(1, baseColor.b * hoverMult)
  
  -- Opacity multiplier based on state
  local opacityMult = isSelected and 1.0 or (isHovered and 0.5 or 0.3)
  local finalOpacity = bgOpacity * opacityMult
  
  if isRounded then
    -- ROUNDED: Update backdrop colors
    if self.skinBackdrop then
      self.skinBackdrop:SetBackdropColor(0, 0, 0, 0) -- Transparent fill
      self.skinBackdrop:SetBackdropBorderColor(r, g, b, finalOpacity)
    end
  else
    -- SQUARE: Update 4 edge texture colors
    if self.skinBorderTop then
      self.skinBorderTop:SetVertexColor(r, g, b, finalOpacity)
    end
    if self.skinBorderBottom then
      self.skinBorderBottom:SetVertexColor(r, g, b, finalOpacity)
    end
    if self.skinBorderLeft then
      self.skinBorderLeft:SetVertexColor(r, g, b, finalOpacity)
    end
    if self.skinBorderRight then
      self.skinBorderRight:SetVertexColor(r, g, b, finalOpacity)
    end
  end
  
  -- Update text color based on style
  local tabText = self.Text or _G[self:GetName().."Text"]
  if tabText then
    if isSelected then
      tabText:SetTextColor(1, 1, 1) -- White for selected
    else
      tabText:SetTextColor(activeColor.r, activeColor.g, activeColor.b) -- Gold for unselected
    end
  end
end

---
-- Apply font settings from the window's profile directly to the tab's FontString.
-- This allows each window to have independent tab font settings.
function ChatTabMixin:UpdateFontFromProfile()
  local profile = self.slidingMessageFrame and self.slidingMessageFrame.window and self.slidingMessageFrame.window.profile
  profile = profile or Core.db.profile
  
  local fontPath = LSM:Fetch(LSM.MediaType.FONT, profile.dockFont)
  local fontSize = profile.dockFontSize
  local fontFlags = profile.dockFontFlags
  
  if fontPath and fontSize and self.Text then
    self.Text:SetFont(fontPath, fontSize, fontFlags or "")
  end
end

Core.Components.CreateChatTab = function (slidingMessageFrame)
  local frameName = slidingMessageFrame.chatFrame:GetName()
  local tabName = frameName.."Tab"
  local frame = _G[tabName]
  
  if not frame then
    return nil  -- Tab doesn't exist
  end
  
  -- If already initialized, update its SMF reference (in case the tab was
  -- re-homed to a different window after deletion) and return it.
  if frame._glassInitialized then
    frame.slidingMessageFrame = slidingMessageFrame
    frame.chatFrame = slidingMessageFrame.chatFrame
    -- Update the dock reference too
    frame.glassDock = (slidingMessageFrame.window and slidingMessageFrame.window.dock) or _G["GlassChatDock"]
    return frame
  end
  
  local object = Mixin(frame, ChatTabMixin)

  local success = pcall(function()
    object:Init(slidingMessageFrame)
  end)
  
  if not success then
    return nil
  end
  
  -- Mark as initialized
  frame._glassInitialized = true
  
  -- Store reference to the owning window's dock for later positioning. Falls
  -- back to the global main dock for safety.
  object.glassDock = (slidingMessageFrame.window and slidingMessageFrame.window.dock) or _G["GlassChatDock"]
  
  return object
end

-- Helper function to update tab positions (called after all tabs are created)
Core.Components.UpdateTabPositions = function(tabs)
  -- Position tabs in their owning window's dock (falls back to the main dock).
  local firstTab = tabs and tabs[1]
  local ownerWindow = firstTab and firstTab.slidingMessageFrame and firstTab.slidingMessageFrame.window
  local glassDock = (ownerWindow and ownerWindow.dock) or _G["GlassChatDock"]
  if not glassDock then 
    return 
  end
  
  -- Get spacing settings from profile
  local profile = (ownerWindow and ownerWindow.profile) or Core.db.profile
  local tabPadding = profile.tabPadding or 5
  local tabSpacing = profile.tabSpacing or 5
  
  local xOffset = tabPadding  -- Padding from left edge
  for i, tab in ipairs(tabs) do
    if tab then
      -- Reparent to our dock
      tab:SetParent(glassDock)
      tab:SetFrameStrata("MEDIUM")
      tab:SetFrameLevel(11)  -- Above the dock background
      tab:ClearAllPoints()
      tab:SetPoint("BOTTOMLEFT", glassDock, "BOTTOMLEFT", xOffset, 0)
      
      -- Force alpha and visibility
      if Hooker.hooks[tab] and Hooker.hooks[tab].SetAlpha then
        Hooker.hooks[tab].SetAlpha(tab, 1)
      else
        tab:SetAlpha(1)
      end
      tab:Show()  -- Ensure tab is visible
      
      -- Use GetWidth but ensure minimum width
      local tabWidth = tab:GetWidth()
      if tabWidth < 30 then
        tabWidth = 60  -- Default minimum width
      end
      xOffset = xOffset + tabWidth + tabSpacing  -- Add spacing between tabs
    end
  end
end

-- Track currently selected tab
Core.Components.selectedTab = nil

-- Select a chat tab and show its SlidingMessageFrame. `isUserClick` is true when
-- the user actually clicked the tab (vs. programmatic selection during setup);
-- only real clicks change which window is active for the edit box / ENTER.
Core.Components.SelectChatTab = function(selectedTab, isUserClick)
  local UIManager = Core:GetModule("UIManager")
  if not UIManager or not UIManager.state then 
    return 
  end

  -- Operate on the tab's OWNING window, so selecting a tab only changes that
  -- window's visible chat (multi-window). Falls back to the main render state.
  local window = selectedTab.slidingMessageFrame and selectedTab.slidingMessageFrame.window
  local frames = (window and window.frames) or UIManager.state.frames
  local tabs = (window and window.tabs) or UIManager.state.tabs

  -- Store selected tab (per-window, plus a global "last selected" for sync).
  if window then
    window.selectedTab = selectedTab
    -- A real click makes this window active: the edit box follows it, so ENTER
    -- opens under this window until another window is clicked.
    if isUserClick and UIManager.SetActiveWindow then
      UIManager:SetActiveWindow(window)
    end
  end
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
      
      -- Get the profile for skin style check
      local profile = tab.slidingMessageFrame and tab.slidingMessageFrame.window and tab.slidingMessageFrame.window.profile
      profile = profile or Core.db.profile
      local style = profile.tabStyle or "minimal"
      -- Backward compatibility
      if style == "modern" or style == "filled" then style = "outline" end
      
      -- Update skin colors for outline style tabs
      if style == "outline" and tab.UpdateSkinColors then
        tab:UpdateSkinColors()
      else
        -- Minimal style - just update text color directly
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
  end
  
  -- Ensure the owning window's dock stays visible
  local visTab = tabs and tabs[1]
  local visWindow = visTab and visTab.slidingMessageFrame and visTab.slidingMessageFrame.window
  local visDock = (visWindow and visWindow.dock) or _G["GlassChatDock"]
  if visDock then
    visDock:Show()
  end
end
