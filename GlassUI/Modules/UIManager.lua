local Core, Constants, Utils = unpack(select(2, ...))
local UIManager = Core:GetModule("UIManager")

local CreateChatDock = Core.Components.CreateChatDock
local CreateChatTab = Core.Components.CreateChatTab
local CreateEditBox = Core.Components.CreateEditBox
local CreateMainContainerFrame = Core.Components.CreateMainContainerFrame
local CreateMoverDialog = Core.Components.CreateMoverDialog
local CreateMoverFrame = Core.Components.CreateMoverFrame
local CreateSlidingMessageFramePool = Core.Components.CreateSlidingMessageFramePool

-- luacheck: push ignore 113
local BNToastFrame = BNToastFrame
local ChatAlertFrame = ChatAlertFrame
local ChatFrameChannelButton = ChatFrameChannelButton
local ChatFrameMenuButton = ChatFrameMenuButton
local CreateFrame = CreateFrame
local GetCVar = GetCVar
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local SetCVar = SetCVar
local UIParent = UIParent
-- luacheck: pop

----
-- UIManager Module
function UIManager:OnInitialize()
  self.state = {
    frames = {},
    tabs = {},
    temporaryFrames = {},
    temporaryTabs = {}
  }
end

function UIManager:OnEnable()
  self.tickerFrame = CreateFrame("Frame", "GlassUpdaterFrame", UIParent)

  -- Mover
  self.moverFrame = CreateMoverFrame("GlassMoverFrame", UIParent)
  self.moverDialog = CreateMoverDialog("GlassMoverDialog", UIParent)

  -- Mover
  self.moverFrame = CreateMoverFrame("GlassMoverFrame", UIParent)
  self.moverDialog = CreateMoverDialog("GlassMoverDialog", UIParent)

  -- Main Container
  self.container = CreateMainContainerFrame("GlassFrame", UIParent)
  self.container:SetPoint("TOPLEFT", self.moverFrame)

  -- Chat dock
  self.dock = CreateChatDock(self.container)

  -- SlidingMessageFrames
  self.slidingMessageFramePool = CreateSlidingMessageFramePool(self.container)

  -- Helper function to check if a chat frame is actually in use
  local function IsChatFrameActive(index)
    local chatFrame = _G["ChatFrame"..index]
    local chatTab = _G["ChatFrame"..index.."Tab"]
    
    if not chatFrame or not chatTab then 
      print("|cFFFF0000Glass: ChatFrame" .. index .. " or tab not found|r")
      return false 
    end
    
    -- ChatFrame1 (General) and ChatFrame2 (Combat Log) are always active
    if index <= 2 then 
      print("|cFF00FF00Glass: ChatFrame" .. index .. " is active (default)|r")
      return true 
    end
    
    -- For frames 3+, check if they're docked
    if chatFrame.isDocked then
      print("|cFF00FF00Glass: ChatFrame" .. index .. " is active (docked)|r")
      return true
    end
    
    print("|cFFFFFF00Glass: ChatFrame" .. index .. " is NOT active|r")
    return false
  end

  -- Create tabs for active chat windows
  -- Use a small delay to ensure Blizzard chat system is fully ready
  local function SetupTabs()
    local activeTabs = {}
    for i=1, NUM_CHAT_WINDOWS do
      local chatFrame = _G["ChatFrame"..i]
      local chatTab = _G["ChatFrame"..i.."Tab"]
      
      if chatFrame then
        -- Create or get the sliding message frame
        if not self.state.frames[i] then
          local smf = self.slidingMessageFramePool:Acquire()
          smf:Init(chatFrame)
          self.state.frames[i] = smf
        end
        
        local smf = self.state.frames[i]
        local isActive = IsChatFrameActive(i)
        
        if isActive then
          local tab = CreateChatTab(smf)
          self.state.tabs[i] = tab
          if tab then
            table.insert(activeTabs, tab)
          end
          
          -- Hide the original Blizzard chat frame visuals
          chatFrame:SetAlpha(0)
        else
          -- Hide unused chat frame and tab
          if chatTab then
            chatTab:Hide()
          end
        end
      end
    end

    -- Position all active tabs in the dock
    local UpdateTabPositions = Core.Components.UpdateTabPositions
    if UpdateTabPositions then
      UpdateTabPositions(activeTabs)
    end
    
    -- Don't auto-select - just show all frames for now
    -- Tab switching will be handled by click
    
    -- Ensure dock is shown
    if self.dock then
      self.dock:Show()
    end
  end
  
  -- Run setup once
  SetupTabs()

  -- Edit box
  self.editBox = CreateEditBox(self.container)

  -- Fix Battle.net Toast frame position (if it exists)
  if BNToastFrame and ChatAlertFrame then
    BNToastFrame:ClearAllPoints()
    BNToastFrame:SetPoint("BOTTOMLEFT", ChatAlertFrame, "BOTTOMLEFT", 0, 0)

    ChatAlertFrame:ClearAllPoints()
    ChatAlertFrame:SetPoint("BOTTOMLEFT", self.container, "TOPLEFT", 15, 10)
  end

  -- Hide other chat elements
  -- Note: QuickJoinToastButton doesn't exist in WotLK 3.3.5
  if ChatFrameChannelButton then
    ChatFrameChannelButton:Hide()
  end
  if ChatFrameMenuButton then
    ChatFrameMenuButton:Hide()
  end
  
  -- Hide Blizzard chat frame backgrounds and scroll buttons
  for i = 1, NUM_CHAT_WINDOWS do
    local chatFrame = _G["ChatFrame"..i]
    if chatFrame then
      -- Hide background textures
      local bg = _G["ChatFrame"..i.."Background"]
      if bg then bg:Hide() end
      
      -- Hide resize button
      local resize = _G["ChatFrame"..i.."ResizeButton"]
      if resize then resize:Hide() end
      
      -- Hide scroll buttons (bottom/up/down)
      local bottomButton = _G["ChatFrame"..i.."BottomButton"]
      if bottomButton then bottomButton:Hide() end
      
      local upButton = _G["ChatFrame"..i.."UpButton"] 
      if upButton then upButton:Hide() end
      
      local downButton = _G["ChatFrame"..i.."DownButton"]
      if downButton then downButton:Hide() end
    end
  end
  
  -- Hide the GeneralDockManager if it exists (retail feature, may not exist in WotLK)
  if GeneralDockManager then
    GeneralDockManager:Hide()
  end
  
  -- Hide ChatFrame tab holder/container if it exists
  if ChatFrame1TabHolder then
    ChatFrame1TabHolder:Hide()
  end
  
  -- Hide any dock backgrounds
  if ChatFrame1Background then
    ChatFrame1Background:Hide()
  end

  -- New version alert
  --@non-debug@
  if Core.db.global.version == nil or Utils.versionGreaterThan(Core.Version, Core.db.global.version) then
    Utils.notify('Glass has just been updated. |cFFFFFF00|Hgarrmission:Glass:opennews|h[See what’s new]|h|r')
    Core.db.global.version = Core.Version
  end
  --@end-non-debug@--

  -- Force classic chat style (if CVar exists in WotLK)
  local chatStyleCVar = GetCVar("chatStyle")
  if chatStyleCVar and chatStyleCVar ~= "classic" then
    SetCVar("chatStyle", "classic")
    Utils.notify('Chat Style set to "Classic Style"')

    -- Resets the background that IM style causes
    self.editBox:SetFocus()
    self.editBox:ClearFocus()
  end

  -- Handle temporary chat frames (whisper popout, pet battle)
  self:RawHook("FCF_OpenTemporaryWindow", function (...)
    local chatFrame = self.hooks["FCF_OpenTemporaryWindow"](...)
    local smf = self.slidingMessageFramePool:Acquire()
    smf:Init(chatFrame)

    self.state.temporaryFrames[chatFrame:GetName()] = smf
    self.state.temporaryTabs[chatFrame:GetName()] = CreateChatTab(smf)
    return chatFrame
  end, true)

  -- Close window
  self:RawHook("FCF_Close", function (chatFrame)
    self.hooks["FCF_Close"](chatFrame)

    self.slidingMessageFramePool:Release(self.state.temporaryFrames[chatFrame:GetName()])
    self.state.temporaryFrames[chatFrame:GetName()] = nil
    self.state.temporaryTabs[chatFrame:GetName()] = nil
  end, true)

  -- Start rendering
  self.timeElapsed = 0
  self.tickerFrame:SetScript("OnUpdate", function (_, elapsed)
    self.timeElapsed = self.timeElapsed + elapsed

    while (self.timeElapsed > 0.01) do
      self.timeElapsed = self.timeElapsed - 0.01

      self.container:OnFrame()

      -- Use pairs instead of ipairs to handle sparse arrays
      for _, smf in pairs(self.state.frames) do
        if smf and smf.OnFrame then
          smf:OnFrame()
        end
      end

      for _, smf in pairs(self.state.temporaryFrames) do
        if smf and smf.OnFrame then
          smf:OnFrame()
        end
      end
    end
  end)
end
