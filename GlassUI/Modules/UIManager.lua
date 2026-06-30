local Core, Constants, Utils = unpack(select(2, ...))
local ns = select(2, ...) -- Get raw namespace for ns.Timer access
local UIManager = Core:GetModule("UIManager")

local UnlockMover = Constants.ACTIONS.UnlockMover
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

local CreateChatTab = Core.Components.CreateChatTab
local CreateEditBox = Core.Components.CreateEditBox
local CreateMoverDialog = Core.Components.CreateMoverDialog
local CreateWindow = Core.Components.CreateWindow

-- luacheck: push ignore 113
local BNToastFrame = BNToastFrame
local ChatAlertFrame = ChatAlertFrame
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
		temporaryTabs = {},
	}
	-- Registry of all Glass windows. Each window is keyed by its id (e.g. "Main").
	-- Multi-window support: other parts of the addon can iterate self.windows.
	self.windows = {}
end

function UIManager:OnEnable()
	self.tickerFrame = CreateFrame("Frame", "GlassUpdaterFrame", UIParent)

	self:HideCombatLogQuickButtons()

	-- Shared "unlock to move" dialog (one for the whole UI).
	self.moverDialog = CreateMoverDialog("GlassMoverDialog", UIParent)

	-- Main window. CleanerChat renders into this single window today; grouping its
	-- pieces (mover, container, dock, message-frame pool) behind a Window object is
	-- the foundation for supporting multiple separate windows. The main window keeps
	-- the original frame names ("GlassMoverFrame"/"GlassFrame"/"GlassChatDock") so
	-- existing references and saved positions are unchanged.
	self.mainWindow = CreateWindow({
		id = "Main",
		parent = UIParent,
		moverName = "GlassMoverFrame",
		containerName = "GlassFrame",
		dockName = "GlassChatDock",
		primaryChatFrame = _G.ChatFrame1,
	})
	self.windows["Main"] = self.mainWindow

	-- Restore additional windows from saved profile (multi-window persistence)
	-- Clean up orphaned windows first (windows with no chat frames assigned)
	if Core.db.profile.windows then
		local orphanedWindows = {}
		for windowId, windowProfile in pairs(Core.db.profile.windows) do
			if windowId ~= "Main" and type(windowProfile) == "table" then
				-- Check if this window has any chat frames assigned
				local hasFrames = windowProfile.chatFrames and #windowProfile.chatFrames > 0
				if not hasFrames then
					table.insert(orphanedWindows, windowId)
				end
			end
		end
		-- Remove orphaned window profiles
		for _, windowId in ipairs(orphanedWindows) do
			Core.db.profile.windows[windowId] = nil
		end
	end

	-- Now restore valid windows
	if Core.db.profile.windows then
		local nextNum = 2
		for windowId, windowProfile in pairs(Core.db.profile.windows) do
			if windowId ~= "Main" and type(windowProfile) == "table" then
				-- Determine the numeric suffix for frame names
				local num = tonumber(windowId:match("%d+")) or nextNum
				nextNum = math.max(nextNum, num + 1)

				local window = CreateWindow({
					id = windowId,
					parent = UIParent,
					moverName = "GlassMoverFrame" .. num,
					containerName = "GlassFrame" .. num,
					dockName = "GlassChatDock" .. num,
					primaryChatFrame = nil, -- Will be assigned by SetupTabs
				})
				if window then
					self.windows[windowId] = window
					-- Apply saved position
					if windowProfile.positionAnchor then
						window.moverFrame:ClearAllPoints()
						window.moverFrame:SetPoint(
							windowProfile.positionAnchor.point or "BOTTOMLEFT",
							UIParent,
							windowProfile.positionAnchor.point or "BOTTOMLEFT",
							windowProfile.positionAnchor.xOfs or 50,
							windowProfile.positionAnchor.yOfs or 200
						)
					end
				end
			end
		end
	end

	-- Backwards-compatible aliases so the rest of UIManager and the components keep
	-- working unchanged while the per-window migration proceeds.
	self.moverFrame = self.mainWindow.moverFrame
	self.container = self.mainWindow.container
	self.dock = self.mainWindow.dock
	self.slidingMessageFramePool = self.mainWindow.pool

	-- Back the shared render state with the main window's frame/tab tables so the
	-- existing SetupTabs/render loop (which uses self.state.frames) drives it.
	self.state.frames = self.mainWindow.frames
	self.state.tabs = self.mainWindow.tabs

	-- Helper function to check if a chat frame is actually in use
	local function IsChatFrameActive(index)
		local chatFrame = _G["ChatFrame" .. index]
		local chatTab = _G["ChatFrame" .. index .. "Tab"]

		if not chatFrame or not chatTab then
			return false
		end

		-- ChatFrame1 (General) and ChatFrame2 (Combat Log) are always active
		if index <= 2 then
			return true
		end

		-- For frames 3+, check if they're docked
		if chatFrame.isDocked then
			return true
		end

		return false
	end

	-- Create tabs for active chat windows
	-- Use a small delay to ensure Blizzard chat system is fully ready
	local function SetupTabs(reveal)
		-- Hide native Combat Log initially (will be shown when its tab is selected)
		local combatLogFrame = _G.ChatFrame2
		if combatLogFrame then
			combatLogFrame:Hide()
			combatLogFrame:SetAlpha(0)
		end

		-- Active tabs grouped by their owning window, so each window's dock lays out
		-- only the tabs that belong to it.
		local activeTabsByWindow = {}

		for i = 1, NUM_CHAT_WINDOWS do
			local chatFrame = _G["ChatFrame" .. i]
			local chatTab = _G["ChatFrame" .. i .. "Tab"]

			if chatFrame then
				-- Skip Combat Log (ChatFrame2) - let it use native Blizzard rendering
				-- We still create a tab for it, but don't hide the native frame here
				local isCombatLog = (chatFrame == _G.ChatFrame2)

				-- Which window owns this chat frame? (per-window profile.chatFrames,
				-- defaulting to the main window).
				local owner = self:GetOwnerWindowForIndex(i)

				-- Reconcile ownership: if any OTHER window currently holds an SMF for
				-- this index (after a move / spawn / delete), release it so only the
				-- owner renders this chat frame and we never double-render.
				for _, w in pairs(self.windows) do
					if w ~= owner and w.frames[i] then
						local stale = w.frames[i]
						w.frames[i] = nil
						w.tabs[i] = nil
						if w.pool and w.pool.Release then
							w.pool:Release(stale)
						end
					end
				end

				-- Create or get the sliding message frame in the owner window's pool.
				if not owner.frames[i] then
					local smf = owner.pool:Acquire()
					smf.window = owner
					smf:Init(chatFrame)
					owner.frames[i] = smf
				end

				local smf = owner.frames[i]
				smf.window = owner
				smf.profile = owner.profile
				local isActive = IsChatFrameActive(i)

				if isActive then
					local tab = CreateChatTab(smf)
					owner.tabs[i] = tab
					if tab then
						tab.glassDock = owner.dock
						activeTabsByWindow[owner] = activeTabsByWindow[owner] or {}
						table.insert(activeTabsByWindow[owner], tab)
					end

					-- Hide the original Blizzard chat frame visuals so Glass renders
					-- them. Skip Combat Log - it handles its own visibility via SelectChatTab.
					if not isCombatLog then
						chatFrame:SetAlpha(0)
					end
				else
					-- Hide unused chat frame and tab, and drop any stale tab reference so
					-- a closed window's tab is not re-shown later by SelectChatTab.
					if chatTab then
						chatTab:Hide()
					end
					owner.tabs[i] = nil
				end
			end
		end

		-- Position each window's active tabs in that window's own dock.
		local UpdateTabPositions = Core.Components.UpdateTabPositions
		if UpdateTabPositions then
			for _, tabs in pairs(activeTabsByWindow) do
				UpdateTabPositions(tabs)
			end
		end

		-- Only reveal the docks on an explicit initial setup. Re-asserts triggered by
		-- Blizzard's FCF_DockUpdate fire constantly while the combat log streams
		-- during combat; if those forced the dock visible, the idle-faded tabs would
		-- pop back up and then never fade again. On a real reveal we also re-arm the
		-- idle fade-out so the tabs always disappear again when left alone.
		if reveal then
			for _, window in pairs(self.windows) do
				if window.dock then
					window.dock:Show()
					if window.dock.FadeOutTabs then
						window.dock:FadeOutTabs()
					end
				end
			end

			-- Show exactly one tab's messages PER window. Every active chat frame gets
			-- its own SlidingMessageFrame anchored at the same spot, so without an
			-- explicit selection they render together. Each window keeps its own
			-- selected tab.
			local SelectChatTab = Core.Components.SelectChatTab
			if SelectChatTab then
				for _, window in pairs(self.windows) do
					local tabToSelect = window.selectedTab

					-- Validate the remembered selection still exists in this window.
					if tabToSelect then
						local stillThere = false
						for _, t in pairs(window.tabs) do
							if t == tabToSelect then
								stillThere = true
								break
							end
						end
						if not stillThere then
							tabToSelect = nil
						end
					end

					-- Otherwise fall back to the first available tab in this window.
					if not tabToSelect then
						for _, t in pairs(window.tabs) do
							if t then
								tabToSelect = t
								break
							end
						end
					end

					if tabToSelect then
						SelectChatTab(tabToSelect)
					end
				end
			end
		end
	end
	-- Expose so the spawn / delete window helpers can re-run the layout.
	self._setupTabs = SetupTabs

	-- Run setup now, then re-assert it. The Blizzard chat dock
	-- (GeneralDockManager / FCFDock) finishes initializing after login and can
	-- re-dock the tabs, pulling them back into the now-hidden dock manager so
	-- they appear to vanish. Re-running SetupTabs re-parents the tabs into the
	-- Glass dock and shows them; it is idempotent (frames and tabs are reused).
	-- SetupTabs is window-aware (it reads each window's profile.chatFrames), so
	-- restored windows automatically reclaim their saved chat frames.
	SetupTabs(true)

	-- Use internal ns.Timer (or native C_Timer if available)
	if ns.Timer and ns.Timer.After then
		ns.Timer.After(0.5, function()
			SetupTabs(true)
		end)
		ns.Timer.After(2, function()
			SetupTabs(true)
		end)
	elseif C_Timer and C_Timer.After then
		C_Timer.After(0.5, function()
			SetupTabs(true)
		end)
		C_Timer.After(2, function()
			SetupTabs(true)
		end)
	end

	-- Keep the tabs in the Glass dock whenever Blizzard re-lays out its chat dock.
	if not self.dockUpdateHooked then
		self.dockUpdateHooked = true

		-- Defer + debounce. Re-running the tab setup synchronously from inside
		-- Blizzard's dock update can re-enter its dock code and trip an assert in
		-- FrameXML\ChatFrame.lua, so schedule it for the next frame instead. We
		-- only hook the high-level FCF_DockUpdate (which already drives
		-- FCFDock_UpdateTabs) to avoid reacting to every internal call.
		local reassertScheduled = false
		local function ReassertTabs()
			if reassertScheduled then
				return
			end
			reassertScheduled = true
			-- Use internal ns.Timer (or native C_Timer if available)
			if ns.Timer and ns.Timer.After then
				ns.Timer.After(0, function()
					reassertScheduled = false
					SetupTabs(false)
				end)
			elseif C_Timer and C_Timer.After then
				C_Timer.After(0, function()
					reassertScheduled = false
					SetupTabs(false)
				end)
			else
				reassertScheduled = false
				SetupTabs(false)
			end
		end

		if _G.hooksecurefunc and _G.FCF_DockUpdate then
			_G.hooksecurefunc("FCF_DockUpdate", ReassertTabs)
		end
	end

	-- Edit box
	self.editBox = CreateEditBox(self.container, self.mainWindow.profile)
	-- The single edit box follows the active (last-clicked) window. Start on main.
	self.editBox.window = self.mainWindow
	self.activeWindow = self.mainWindow

	-- Fix Battle.net Toast frame position (if it exists)
	if BNToastFrame and ChatAlertFrame then
		BNToastFrame:ClearAllPoints()
		BNToastFrame:SetPoint("BOTTOMLEFT", ChatAlertFrame, "BOTTOMLEFT", 0, 0)

		ChatAlertFrame:ClearAllPoints()
		ChatAlertFrame:SetPoint("BOTTOMLEFT", self.container, "TOPLEFT", 15, 10)
	end

	-- Hide the native chat buttons (channel button and the voice mute/deafen mic buttons).
	-- Blizzard re-shows some of these on chat updates, so pin them hidden with a Show hook.
	-- Note: QuickJoinToastButton doesn't exist in WotLK 3.3.5
	-- ChatFrameMenuButton is handled separately below as a toggleable option.
	if not self.chatButtonsHidden then
		self.chatButtonsHidden = true
		for _, buttonName in ipairs({
			"ChatFrameChannelButton",
			"ChatFrameToggleVoiceDeafenButton",
			"ChatFrameToggleVoiceMuteButton",
		}) do
			local button = _G[buttonName]
			if button then
				button:Hide()
				if _G.hooksecurefunc then
					_G.hooksecurefunc(button, "Show", function(b)
						b:Hide()
					end)
				end
			end
		end
	end

	self:SetupTopBarButtonToggles()

	-- Hide Blizzard chat frame backgrounds and scroll buttons
	for i = 1, NUM_CHAT_WINDOWS do
		local chatFrame = _G["ChatFrame" .. i]
		if chatFrame then
			-- Hide background textures
			local bg = _G["ChatFrame" .. i .. "Background"]
			if bg then
				bg:Hide()
			end

			-- Hide resize button
			local resize = _G["ChatFrame" .. i .. "ResizeButton"]
			if resize then
				resize:Hide()
			end

			-- Hide scroll buttons (bottom/up/down)
			local bottomButton = _G["ChatFrame" .. i .. "BottomButton"]
			if bottomButton then
				bottomButton:Hide()
			end

			local upButton = _G["ChatFrame" .. i .. "UpButton"]
			if upButton then
				upButton:Hide()
			end

			local downButton = _G["ChatFrame" .. i .. "DownButton"]
			if downButton then
				downButton:Hide()
			end
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

	-- Force classic chat style (if CVar exists in WotLK)
	local chatStyleCVar = GetCVar("chatStyle")
	if chatStyleCVar and chatStyleCVar ~= "classic" then
		SetCVar("chatStyle", "classic")
		Utils.notify('Chat Style set to "Classic Style"')

		-- Resets the background that IM style causes
		self.editBox:SetFocus()
		self.editBox:ClearFocus()
	end

	self:InstallChatHooks()

	self:StartRenderLoop()
end

-- Hide Blizzard_CombatLog's quick-button bar, now and whenever that addon loads.
function UIManager:HideCombatLogQuickButtons()
	-- Watch for Blizzard_CombatLog loading to hide its quick-button bar
	local addonWatcher = CreateFrame("Frame")
	addonWatcher:RegisterEvent("ADDON_LOADED")
	addonWatcher:SetScript("OnEvent", function(_, event, addon)
		if addon == "Blizzard_CombatLog" then
			local combatLogButtons = _G["CombatLogQuickButtonFrame"]
			if combatLogButtons then
				combatLogButtons:Hide()
				combatLogButtons:SetAlpha(0)
				-- Replace Show to prevent it from ever appearing
				combatLogButtons.Show = function() end
			end
		end
	end)
	-- Also check if it's already loaded
	if IsAddOnLoaded("Blizzard_CombatLog") then
		local combatLogButtons = _G["CombatLogQuickButtonFrame"]
		if combatLogButtons then
			combatLogButtons:Hide()
			combatLogButtons:SetAlpha(0)
			combatLogButtons.Show = function() end
		end
	end
end

-- Apply and enforce the user's "hide Social / Chat Menu button" settings, and
-- keep them in sync when those settings change.
function UIManager:SetupTopBarButtonToggles()
	-- Handle the Social (friends) button visibility based on settings
	-- FriendsMicroButton is the friends/social button in WotLK 3.3.5
	if not self._socialButtonHooked then
		self._socialButtonHooked = true
		local socialButton = _G["FriendsMicroButton"]
		if socialButton then
			-- Apply initial state
			if Core.db.profile.hideSocialButton then
				socialButton:Hide()
			else
				socialButton:Show()
			end
			-- Hook to enforce setting when Blizzard tries to show it
			if _G.hooksecurefunc then
				_G.hooksecurefunc(socialButton, "Show", function(b)
					if Core.db.profile.hideSocialButton then
						b:Hide()
					end
				end)
			end
		end
		-- Listen for setting changes
		Core:Subscribe(UPDATE_CONFIG, function(payload)
			local key = Core:ResolveConfigKey(payload)
			if key == "hideSocialButton" then
				local btn = _G["FriendsMicroButton"]
				if btn then
					if Core.db.profile.hideSocialButton then
						btn:Hide()
					else
						btn:Show()
					end
				end
			end
		end)
	end

	-- Handle the Chat Menu button (speech bubble with language/emote options)
	if not self._chatMenuButtonHooked then
		self._chatMenuButtonHooked = true
		local chatMenuButton = _G["ChatFrameMenuButton"]
		if chatMenuButton then
			-- Apply initial state
			if Core.db.profile.hideChatMenuButton then
				chatMenuButton:Hide()
			else
				chatMenuButton:Show()
			end
			-- Hook to enforce setting when Blizzard tries to show it
			if _G.hooksecurefunc then
				_G.hooksecurefunc(chatMenuButton, "Show", function(b)
					if Core.db.profile.hideChatMenuButton then
						b:Hide()
					end
				end)
			end
		end
		-- Listen for setting changes
		Core:Subscribe(UPDATE_CONFIG, function(payload)
			local key = Core:ResolveConfigKey(payload)
			if key == "hideChatMenuButton" then
				local btn = _G["ChatFrameMenuButton"]
				if btn then
					if Core.db.profile.hideChatMenuButton then
						btn:Hide()
					else
						btn:Show()
					end
				end
			end
		end)
	end
end

-- Install the defensive Blizzard chat-frame hooks: route temporary (whisper)
-- windows into Glass, and guard the dropdown/channel APIs against the nil chat
-- frame that Glass's tab selection can leave behind.
function UIManager:InstallChatHooks()
	-- Handle temporary chat frames (whisper popout, pet battle)
	self:RawHook("FCF_OpenTemporaryWindow", function(...)
		local chatFrame = self.hooks["FCF_OpenTemporaryWindow"](...)
		local smf = self.slidingMessageFramePool:Acquire()
		smf:Init(chatFrame)

		self.state.temporaryFrames[chatFrame:GetName()] = smf
		self.state.temporaryTabs[chatFrame:GetName()] = CreateChatTab(smf)
		return chatFrame
	end, true)

	-- Hook FCF_GetCurrentChatFrame to return a sensible fallback when it would return nil
	-- This is the root cause of many dropdown callback errors - Glass doesn't keep
	-- UIDROPDOWNMENU_INIT_MENU in sync, so this function returns nil.
	-- Use direct function replacement for guaranteed interception.
	if _G.FCF_GetCurrentChatFrame and not self.fcfGetCurrentHooked then
		self.fcfGetCurrentHooked = true
		local origFCF_GetCurrentChatFrame = _G.FCF_GetCurrentChatFrame
		_G.FCF_GetCurrentChatFrame = function()
			local result = origFCF_GetCurrentChatFrame()
			if not result then
				-- Fallback: use our tracked selection, or SELECTED_CHAT_FRAME, or ChatFrame1
				if Core.Components.selectedTab and Core.Components.selectedTab.chatFrame then
					result = Core.Components.selectedTab.chatFrame
				else
					result = _G.SELECTED_CHAT_FRAME or _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
				end
			end
			return result
		end
	end

	-- Guard FCF_CopyChatSettings against nil copyFrom
	-- When Glass tabs are selected, the Blizzard selection state may not be in sync,
	-- causing "Move to new window" to pass nil as the source frame. Default to
	-- DEFAULT_CHAT_FRAME (ChatFrame1) which always exists.
	if _G.FCF_CopyChatSettings then
		self:RawHook("FCF_CopyChatSettings", function(copyTo, copyFrom)
			if not copyFrom then
				copyFrom = _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
			end
			return self.hooks["FCF_CopyChatSettings"](copyTo, copyFrom)
		end, true)
	end

	-- Guard ChatFrame_RemoveChannel against nil chatFrame
	-- Dropdown callbacks use FCF_GetCurrentChatFrame() which may return nil
	if _G.ChatFrame_RemoveChannel then
		self:RawHook("ChatFrame_RemoveChannel", function(chatFrame, channel)
			if not chatFrame then
				chatFrame = _G.SELECTED_CHAT_FRAME or _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
			end
			return self.hooks["ChatFrame_RemoveChannel"](chatFrame, channel)
		end, true)
	end

	-- Guard ChatFrame_AddChannel against nil chatFrame (same pattern)
	if _G.ChatFrame_AddChannel then
		self:RawHook("ChatFrame_AddChannel", function(chatFrame, channel)
			if not chatFrame then
				chatFrame = _G.SELECTED_CHAT_FRAME or _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
			end
			return self.hooks["ChatFrame_AddChannel"](chatFrame, channel)
		end, true)
	end

	-- Close window
	self:RawHook("FCF_Close", function(chatFrame)
		self.hooks["FCF_Close"](chatFrame)

		local name = chatFrame:GetName()

		-- Temporary (whisper/popout) frame cleanup, only if this was one. The old
		-- code called Release() unconditionally, which passed nil for user-created
		-- windows.
		local tempSMF = self.state.temporaryFrames[name]
		if tempSMF then
			self.slidingMessageFramePool:Release(tempSMF)
			self.state.temporaryFrames[name] = nil
			self.state.temporaryTabs[name] = nil
		end

		-- If the closed window was the selected tab, drop the stale selection so the
		-- re-assert below falls back to the default (General) tab.
		if Core.Components.selectedTab and Core.Components.selectedTab.chatFrame == chatFrame then
			Core.Components.selectedTab = nil
		end

		-- Closing a window re-docks the remaining frames through Blizzard's dock
		-- (FCFDock_UpdateTabs), which re-parents EVERY tab into the hidden native
		-- GeneralDockManager -- and that path does not call FCF_DockUpdate, so our
		-- normal re-assert hook never fires. Without this, all tabs vanish until a
		-- /reload. Re-assert now to pull the remaining tabs back into the Glass dock.
		if self._setupTabs then
			self._setupTabs(true)
		end
	end, true)
end

-- Drive the per-window render loop: tick each window's container (mouse-over
-- tracking) and its sliding message frames, plus any temporary whisper frames.
function UIManager:StartRenderLoop()
	self.timeElapsed = 0
	self.tickerFrame:SetScript("OnUpdate", function(_, elapsed)
		self.timeElapsed = self.timeElapsed + elapsed

		while self.timeElapsed > 0.01 do
			self.timeElapsed = self.timeElapsed - 0.01

			-- Tick every window: its container (mouse-over tracking) and all of its
			-- sliding message frames. The main window is part of self.windows, so this
			-- covers it too.
			for _, window in pairs(self.windows) do
				if window.container and window.container.OnFrame then
					window.container:OnFrame()
				end
				for _, smf in pairs(window.frames) do
					if smf and smf.OnFrame then
						smf:OnFrame()
					end
				end
			end

			-- Temporary frames (whispers, etc.) live on the main window.
			for _, smf in pairs(self.state.temporaryFrames) do
				if smf and smf.OnFrame then
					smf:OnFrame()
				end
			end
		end
	end)
end

-- Make `window` the active window: the single edit box follows it, so pressing
-- ENTER opens the edit box under that window and focus reveals only its
-- messages. Called when the user clicks a window's tab.
function UIManager:SetActiveWindow(window)
	if not window then
		return
	end
	self.activeWindow = window
	if self.editBox and self.editBox.AttachToWindow then
		self.editBox:AttachToWindow(window.container, window.profile, window)
	end
	-- Update Blizzard's selection state so chat APIs work correctly.
	-- Use the window's primary chat frame, or fall back to ChatFrame1.
	local chatFrame = window.primaryChatFrame or _G.ChatFrame1
	if chatFrame then
		_G.SELECTED_CHAT_FRAME = chatFrame
		_G.SELECTED_DOCK_FRAME = chatFrame
	end
end

-- Returns the window that owns a given chat-frame index, based on each
-- secondary window's saved profile.chatFrames list. Defaults to the main window.
function UIManager:GetOwnerWindowForIndex(chatFrameIndex)
	if self.windows then
		for windowId, window in pairs(self.windows) do
			if windowId ~= "Main" and window.profile and window.profile.chatFrames then
				for _, idx in ipairs(window.profile.chatFrames) do
					if idx == chatFrameIndex then
						return window
					end
				end
			end
		end
	end
	return self.mainWindow
end

-- Spawn a brand-new CleanerChat window hosting a freshly created chat frame.
-- Settings are copied from the source window (the tab that was right-clicked).
-- Returns the new window object, or nil if creation failed.
function UIManager:SpawnNewWindow(sourceWindowId)
	sourceWindowId = sourceWindowId or "Main"

	-- Find the first free (inactive) chat frame to spawn. General (1) and Combat
	-- Log (2) are always in use, so candidates start at 3.
	local newIndex
	for i = 3, NUM_CHAT_WINDOWS do
		local cf = _G["ChatFrame" .. i]
		if cf and not cf:IsShown() and not cf.isDocked then
			newIndex = i
			break
		end
	end
	if not newIndex then
		Utils.notify("No free chat windows available")
		return nil
	end

	-- Generate a unique window id + numeric suffix for frame names.
	local nextNum = 2
	while self.windows["Window" .. nextNum] do
		nextNum = nextNum + 1
	end
	local windowId = "Window" .. nextNum

	-- Copy settings from the source window onto the new one.
	local profile = Core:CreateWindowProfile(windowId, sourceWindowId)
	if not profile then
		return nil
	end
	profile.chatFrames = { newIndex }

	-- Center the new window on screen so it's immediately visible.
	profile.positionAnchor = {
		point = "CENTER",
		xOfs = 0,
		yOfs = 0,
	}

	-- Create the Glass window (mover, container, dock, pool).
	local newWindow = CreateWindow({
		id = windowId,
		parent = UIParent,
		moverName = "GlassMoverFrame" .. nextNum,
		containerName = "GlassFrame" .. nextNum,
		dockName = "GlassChatDock" .. nextNum,
		primaryChatFrame = _G["ChatFrame" .. newIndex],
	})
	if not newWindow then
		Core:DeleteWindowProfile(windowId)
		return nil
	end
	self.windows[windowId] = newWindow

	-- Position the new window's mover.
	newWindow.moverFrame:ClearAllPoints()
	newWindow.moverFrame:SetPoint(
		profile.positionAnchor.point,
		UIParent,
		profile.positionAnchor.point,
		profile.positionAnchor.xOfs,
		profile.positionAnchor.yOfs
	)

	-- Actually spawn the Blizzard chat frame (opens ChatFrame<newIndex>).
	if _G.FCF_OpenNewWindow then
		_G.FCF_OpenNewWindow()
	end

	-- Route the new chat frame into this window and lay everything out. SetupTabs
	-- reads profile.chatFrames, so the freshly opened frame renders in the new
	-- window's dock rather than the main one.
	if self._setupTabs then
		self._setupTabs(true)
	end

	newWindow.moverFrame:Show()
	newWindow.container:Show()
	newWindow.dock:Show()

	-- Automatically unlock frames so the user can see the new window and
	-- reposition/resize it immediately. This dispatches UNLOCK_MOVER which
	-- enables mouse on all mover frames (including the new one) and shows the
	-- lock/unlock dialog.
	Core:Dispatch(UnlockMover())

	return newWindow
end

-- Delete a (non-default) CleanerChat window. Its chat frames revert to the main
-- window so nothing is lost.
function UIManager:DeleteWindow(windowId)
	if not windowId or windowId == "Main" then
		return
	end

	local window = self.windows[windowId]
	if not window then
		return
	end

	-- Release this window's SMFs so SetupTabs can re-home its chat frames into the
	-- main window's pool/dock.
	for idx, smf in pairs(window.frames) do
		window.frames[idx] = nil
		window.tabs[idx] = nil
		if window.pool and window.pool.Release then
			window.pool:Release(smf)
		end
	end

	-- Hide the window's Glass frames and clean up subscriptions. The SMFs were
	-- unsubscribed by the pool resetter (Release -> smf:Destroy()) above; the dock
	-- and container are one-per-window, so destroy them directly.
	if window.dock then
		if window.dock.Destroy then
			window.dock:Destroy()
		end
		window.dock:Hide()
	end
	if window.container then
		if window.container.Destroy then
			window.container:Destroy()
		end
		window.container:Hide()
	end
	if window.moverFrame then
		-- Destroy unsubscribes from LOCK_MOVER/UNLOCK_MOVER so the mover won't
		-- reappear when the user does /cc lock after deleting this window.
		if window.moverFrame.Destroy then
			window.moverFrame:Destroy()
		else
			window.moverFrame:Hide()
		end
	end

	-- If this was the active (edit-focus) window, hand focus back to main.
	if self.activeWindow == window then
		self:SetActiveWindow(self.mainWindow)
	end

	-- Drop the window from the registry and remove its saved settings. Clearing
	-- its profile (and thus its chatFrames ownership) means the freed chat frames
	-- have no owner, so the main window reclaims them on the next layout.
	self.windows[windowId] = nil
	Core:DeleteWindowProfile(windowId)

	-- If the options panel was editing this window, fall back to Main.
	local Config = Core:GetModule("Config", true)
	if Config and Config.selectedWindowId == windowId then
		Config.selectedWindowId = "Main"
	end

	-- Re-lay out: the freed chat frames now have no owner → main reclaims them.
	if self._setupTabs then
		self._setupTabs(true)
	end
end

-- Get the window that owns a specific chat frame index (and its id).
function UIManager:GetWindowForChatFrame(chatFrameIndex)
	local owner = self:GetOwnerWindowForIndex(chatFrameIndex)
	for windowId, window in pairs(self.windows) do
		if window == owner then
			return window, windowId
		end
	end
	-- Default: main window owns it
	return self.mainWindow, "Main"
end
