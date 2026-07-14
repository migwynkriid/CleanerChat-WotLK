local Core, Constants, Utils = unpack(select(2, ...))
local TP = Core:GetModule("TextProcessing")

local AceHook = Core.Libs.AceHook

-- CleanerChat integration: resolve its addon object lazily so incoming chat
-- text can be run through the same string filters CleanerChat applies to the
-- default chat frame. Returns nil until CleanerChat is available.
local AceAddon = _G.LibStub("AceAddon-3.0")
local cleanerChat
local function GetCleanerChat()
	if not cleanerChat then
		cleanerChat = AceAddon:GetAddon("CleanerChat", true)
	end
	return cleanerChat
end

local LibEasing = Core.Libs.LibEasing

-- Functional helpers (replaces lodash.wow)
local drop, reduce, take = Utils.drop, Utils.reduce, Utils.take

-- Solid colour texture helper (shared; SetColorTexture polyfilled in compat).
local SetSolidColor = Utils.SetSolidColor

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
local Mixin = Mixin
-- luacheck: pop

----
-- SlidingMessageFrameMixin
--
-- Custom frame for displaying pretty sliding messages
local SlidingMessageFrameMixin = {}

function SlidingMessageFrameMixin:Init(chatFrame)
	-- Per-window profile: use the window's profile if attached, else global.
	self.profile = self.window and self.window.profile or Core.db.profile

	self.config = {
		height = self.profile.frameHeight - Constants.DOCK_HEIGHT - Constants.MESSAGE_DOCK_GAP,
		width = self.profile.frameWidth,
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
		local buttonFrame = _G[chatFrame:GetName() .. "ButtonFrame"]
		if buttonFrame then
			buttonFrame:Hide()
		end

		-- Set up minimal scroll frame (not used for combat log display)
		self:SetHeight(self.config.height + self.config.overflowHeight)
		self:SetWidth(self.config.width)
		self:SetPoint("TOPLEFT", 0, (Constants.DOCK_HEIGHT + Constants.MESSAGE_DOCK_GAP) * -1)
		self:SetVerticalScroll(self.config.overflowHeight)
		self:Hide() -- Hide Glass overlay for combat log - native frame renders instead

		-- Skip the rest of Init for combat log
		return
	end

	-- Hide Blizzard UI elements (but don't modify chatFrame parent/position).
	local buttonFrame = _G[chatFrame:GetName() .. "ButtonFrame"]
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
		self:RawHook(chatFrame, "SetAlpha", function()
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
		self:SecureHook(chatFrame, "Show", function()
			chatFrame:Hide()
		end)
	end
	chatFrame:Hide()

	-- Chat scroll frame for our custom messages
	self:SetHeight(self.config.height + self.config.overflowHeight)
	self:SetWidth(self.config.width)
	self:SetPoint("TOPLEFT", 0, (Constants.DOCK_HEIGHT + Constants.MESSAGE_DOCK_GAP) * -1)

	-- Set initial scroll position
	self:SetVerticalScroll(self.config.overflowHeight)

	-- Overlay
	if self.overlay == nil then
		self.overlay = CreateScrollOverlayFrame(self, self.profile)
		self.overlay:QuickHide()

		-- Snap to bottom on click
		self.overlay:SetScript("OnClickSnapFrame", function()
			self:SnapToBottom()
		end)
	end

	-- Scrolling
	self:SetScript("OnMouseWheel", function(frame, delta)
		local maxScroll = (
			self.state.scrollAtBottom and self:GetVerticalScrollRange() + self.config.overflowHeight
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
			-- Fade the overlay out with whatever label it's currently showing (e.g.
			-- the unread alert). Don't swap in the "Bring me to the present" hint
			-- here, or it briefly flashes over the fading alert. The label is chosen
			-- fresh the next time the overlay is shown (ShowScrollOverlay).
			self.overlay:Hide()
			self.state.unreadMessages = false
		else
			-- If not, the height should fit the frame exactly so messages don't spill
			-- under the edit box area
			self:SetHeight(self.config.height)
			self:ShowScrollOverlay()
		end

		-- Show hidden messages
		for _, message in ipairs(self.state.messages) do
			message:Show()
		end
	end)

	-- Mouse clickthrough but allow scrolling. We enable mouse so we can capture
	-- clicks for window focus, but hyperlinks handle their own clicks via the
	-- message lines' own scripts.
	self:EnableMouse(true)
	self:EnableMouseWheel(true)
	self:SetScript("OnMouseDown", function(frame, button)
		if button == "LeftButton" then
			local UIManager = Core:GetModule("UIManager", true)
			if UIManager and UIManager.SetActiveWindow and frame.window then
				UIManager:SetActiveWindow(frame.window)
			end
		end
	end)

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
	SetSolidColor(self.slider.bg, 0, 0, 1, 0)

	-- Pool for the message frames
	if self.messageFramePool == nil then
		self.messageFramePool = CreateMessageLinePool(self.slider, self.profile)
	end

	-- Hook AddMessage to capture messages for our display
	-- Note: Combat Log returns early in Init, so this only runs for regular chat frames
	self:Hook(chatFrame, "AddMessage", function(frame, text, ...)
		-- Skip filtering for restored messages (they were already filtered when originally received)
		local UIManager = Core:GetModule("UIManager", true)
		local isRestoring = UIManager and UIManager._restoringMessages

		-- Run incoming text through CleanerChat's filters so the Glass display
		-- matches CleanerChat's formatting and drops blacklisted messages.
		if not isRestoring then
			local CleanerChat = GetCleanerChat()
			if CleanerChat and text ~= nil then
				local filtered = CleanerChat:FilterMessage(frame, text, ...)
				if filtered == nil then
					return
				end
				text = filtered
			end
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
			Core:Subscribe(MOUSE_ENTER, function(window)
				-- Only react to our own window's hover (nil = legacy global).
				if window and window ~= self.window then
					return
				end
				-- Don't hide chats when mouse is over
				self.state.mouseOver = true

				if not self.state.scrollAtBottom then
					self:ShowScrollOverlay()
				end

				-- Cancel all hide timers when mouse enters
				for _, message in ipairs(self.state.messages) do
					if message.hideTimer then
						message.hideTimer:Cancel()
						message.hideTimer = nil
					end
				end

				-- If messagesOnHover is enabled, fade in all messages
				if self.profile.messagesOnHover then
					local fadeDuration = (self.profile.messageAnimations ~= false)
							and (self.profile.chatFadeInDuration or 0.3)
						or 0
					for _, message in ipairs(self.state.messages) do
						message:FadeIn(fadeDuration)
					end
				end
			end),
			Core:Subscribe(MOUSE_LEAVE, function(window)
				if window and window ~= self.window then
					return
				end
				-- Hide chats when mouse leaves
				self.state.mouseOver = false

				self.overlay:HideDelay(self.profile.chatHoldTime)

				-- Fade out messages when mouse leaves, unless messages are pinned.
				if not self.profile.messagesAlwaysVisible then
					for _, message in ipairs(self.state.messages) do
						message:HideDelay(self.profile.chatHoldTime)
					end
				end
			end),
			-- Edit focus shows ALL messages regardless of messagesOnHover setting
			Core:Subscribe(EDIT_FOCUS_GAINED, function(window)
				-- Only react when our own window's edit box is focused (nil = global).
				if window and window ~= self.window then
					return
				end

				-- Always hide the scroll overlay (unread / "Bring me to the present"
				-- indicator) while the edit box is focused so it doesn't overlap the
				-- input box. This is independent of showOnEditFocus. Hiding the
				-- overlay frame itself makes its labels invisible while preserving
				-- their shown-state, so the correct label reappears when it's shown
				-- again (don't Hide the child labels here, or they stay hidden).
				if self.overlay then
					self.overlay.editBoxFocused = true
					self.overlay:QuickHide()
				end

				-- Revealing all messages on focus is opt-in via showOnEditFocus.
				if not self.profile.showOnEditFocus then
					return
				end

				self.state.mouseOver = true

				-- Cancel all hide timers
				for _, message in ipairs(self.state.messages) do
					if message.hideTimer then
						message.hideTimer:Cancel()
						message.hideTimer = nil
					end
				end

				-- Always show ALL messages with animation when edit box is focused
				local fadeDuration = (self.profile.messageAnimations ~= false)
						and (self.profile.chatFadeInDuration or 0.3)
					or 0
				for _, message in ipairs(self.state.messages) do
					message:FadeIn(fadeDuration)
				end

				-- If there are unread messages or scrolled up, snap to the bottom
				if self.state.unreadMessages or not self.state.scrollAtBottom then
					self:SnapToBottom()
				end
			end),
			Core:Subscribe(EDIT_FOCUS_LOST, function(window)
				if window and window ~= self.window then
					return
				end

				-- Clear the edit box focus flag so the overlay can show again.
				if self.overlay then
					self.overlay.editBoxFocused = false
				end

				if self.profile.showOnEditFocus then
					self.state.mouseOver = false

					self.overlay:HideDelay(self.profile.chatHoldTime)

					-- Start fade out timers for all messages, unless messages are pinned.
					if not self.profile.messagesAlwaysVisible then
						for _, message in ipairs(self.state.messages) do
							message:HideDelay(self.profile.chatHoldTime)
						end
					end
				elseif self.state.unreadMessages or not self.state.scrollAtBottom then
					-- The overlay was only hidden to avoid overlapping the edit box;
					-- restore the correct indicator now that typing is done and the user
					-- is still scrolled up / has unread messages.
					self:ShowScrollOverlay()
				end
			end),
			Core:Subscribe(UPDATE_CONFIG, function(payload)
				local key = Core:ResolveConfigKey(payload, self.window and self.window.id or "Main")
				if key ~= nil then
					self:OnConfigChanged(key)
				end
			end),
		}
	end
end
-- Show the scroll overlay with the label that matches the current state: the
-- "Unread messages" alert if there are unread messages, otherwise the passive
-- "Bring me to the present" hint. Centralizing this keeps the label in sync
-- whenever the overlay is shown, so hiding it (e.g. on scroll-to-bottom) never
-- has to pre-swap the label and flash the wrong one during the fade-out.
function SlidingMessageFrameMixin:ShowScrollOverlay()
	if not self.overlay then
		return
	end
	self.overlay:Show()
	if self.state.unreadMessages then
		self.overlay:ShowNewMessageAlert()
	else
		self.overlay:HideNewMessageAlert()
	end
end
-- Smoothly scroll to the newest message, clearing the unread state and overlay.
-- Shared by the scroll-overlay click and the edit-focus reveal.
function SlidingMessageFrameMixin:SnapToBottom()
	self.state.scrollAtBottom = true
	self.state.unreadMessages = false
	self.overlay:Hide()
	self.overlay:HideNewMessageAlert()

	local startOffset = math.max(self:GetVerticalScrollRange() - self.config.height * 2, self:GetVerticalScroll())
	local endOffset = self:GetVerticalScrollRange()

	LibEasing:Ease(
		function(offset)
			self:SetVerticalScroll(offset)
		end,
		startOffset,
		endOffset,
		0.3,
		LibEasing.OutCubic,
		function()
			self:SetHeight(self.config.height + self.config.overflowHeight)
		end
	)
end

-- React to a Glass config change for this window's message display. The Combat
-- Log renders natively, so nothing here applies to it.
function SlidingMessageFrameMixin:OnConfigChanged(key)
	if self.state.isCombatLog ~= false then
		return
	end

	if
		key == "messageFont"
		or key == "messageFontSize"
		or key == "frameWidth"
		or key == "frameHeight"
		or key == "messageLeading"
		or key == "messageLinePadding"
		or key == "indentWordWrap"
	then
		-- Adjust frame dimensions first
		self.config.height = self.profile.frameHeight - Constants.DOCK_HEIGHT - Constants.MESSAGE_DOCK_GAP
		self.config.width = self.profile.frameWidth

		self:SetHeight(self.config.height + self.config.overflowHeight)
		self:SetWidth(self.config.width)

		-- Then adjust message line dimensions
		for _, message in ipairs(self.state.messages) do
			message:UpdateFrame()
		end

		-- Then update scroll values
		local contentHeight = reduce(self.state.messages, function(acc, message)
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

		-- Update overlay position when frame height changes
		if self.overlay and self.overlay.UpdatePosition then
			self.overlay:UpdatePosition()
		end
	end

	if key == "chatBackgroundOpacity" or key == "chatBackgroundColor" then
		for _, message in ipairs(self.state.messages) do
			message:UpdateTextures()
		end
	end

	if key == "messagesOnHover" then
		-- When toggled, show current messages if the mouse is over and it's now enabled.
		if self.profile.messagesOnHover and self.state.mouseOver then
			for _, message in ipairs(self.state.messages) do
				message:Show()
			end
		end
	end

	if key == "messagesAlwaysVisible" then
		if self.profile.messagesAlwaysVisible then
			-- Pin every message on screen and cancel any pending fade-out.
			for _, message in ipairs(self.state.messages) do
				if message.hideTimer then
					message.hideTimer:Cancel()
					message.hideTimer = nil
				end
				message:Show()
			end
		elseif not self.state.mouseOver then
			-- Resume the normal fade-out behaviour.
			for _, message in ipairs(self.state.messages) do
				message:HideDelay(self.profile.chatHoldTime)
			end
		end
	end

	if
		key == "scrollIndicatorColor"
		or key == "scrollIndicatorOpacity"
		or key == "scrollIndicatorBgColor"
		or key == "scrollIndicatorBgOpacity"
		or key == "useOverlayMask"
	then
		if self.overlay and self.overlay.UpdateIndicatorStyle then
			self.overlay:UpdateIndicatorStyle()
		end
	end

	if key == "editBoxAnchor" then
		if self.overlay and self.overlay.UpdatePosition then
			self.overlay:UpdatePosition()
		end
	end

	if key == "hideScrollIndicator" then
		if self.overlay then
			if self.profile.hideScrollIndicator then
				self.overlay:QuickHide()
			end
			-- If turned back on, it will show naturally when scrolling up.
		end
	end
end

-- Unsubscribe this frame's event-bus listeners. Called when the frame is
-- released back to the pool (and re-subscribed on the next Init), so a deleted
-- window's frames stop reacting to events.
function SlidingMessageFrameMixin:Destroy()
	if self.subscriptions then
		for _, unsubscribe in ipairs(self.subscriptions) do
			if type(unsubscribe) == "function" then
				unsubscribe()
			end
		end
		self.subscriptions = nil
	end
end

function SlidingMessageFrameMixin:CreateMessageFrame(frame, text, red, green, blue, messageId, holdTime)
	red = red or 1
	green = green or 1
	blue = blue or 1

	local message = self.messageFramePool:Acquire()

	-- Set back-reference to this SMF so the message can find its window
	message.smf = self

	message.text:SetTextColor(red, green, blue, 1)
	local processed = TP:ProcessText(text, self.profile)
	message:SetMessageText(processed)

	-- Adjust height to contain text
	message:UpdateFrame()

	return message
end

function SlidingMessageFrameMixin:AddMessage(...)
	-- Enqueue messages to be displayed
	local args = { ... }
	table.insert(self.state.incomingMessages, args)

	-- Store raw message data for restore-on-reload feature
	-- Skip storing if we're currently restoring messages (to avoid duplicates)
	local UIManager = Core:GetModule("UIManager", true)
	if UIManager and UIManager._restoringMessages then
		return
	end

	-- Format: { text, r, g, b } (skip frame reference as it can't be serialized)
	if not self.state.rawMessages then
		self.state.rawMessages = {}
	end
	local _, text, r, g, b = ...
	if text then
		table.insert(self.state.rawMessages, { text = text, r = r or 1, g = g or 1, b = b or 1 })
		-- Trim to history limit
		local historyLimit = self.profile.messageHistoryLimit or 128
		while #self.state.rawMessages > historyLimit do
			table.remove(self.state.rawMessages, 1)
		end
	end
end

-- Recompute the scroll-child height from the current message heights, keeping
-- the view pinned to the bottom when appropriate.
function SlidingMessageFrameMixin:RecomputeContentHeight()
	local contentHeight = reduce(self.state.messages, function(acc, message)
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

	-- Track the highest frame level to ensure newer messages render on top.
	-- This fixes z-order issues when pooled frames are reused (their creation
	-- order may not match visual order, causing icons to bleed through).
	local baseLevel = (self.slider:GetFrameLevel() or 1) + 1
	if not self.state.nextFrameLevel then
		self.state.nextFrameLevel = baseLevel
	end

	-- Reset frame levels if they get too high to avoid potential issues.
	-- Re-normalize all existing messages from the base level.
	if self.state.nextFrameLevel > 500 then
		local level = baseLevel
		for _, msg in ipairs(self.state.messages) do
			msg:SetFrameLevel(level)
			level = level + 1
		end
		self.state.nextFrameLevel = level
	end

	for _, message in ipairs(incoming) do
		local messageFrame = self:CreateMessageFrame(unpack(message))
		messageFrame:SetPoint("BOTTOMLEFT")

		-- Newer messages (at the bottom) get higher frame levels so their
		-- backgrounds properly cover icons from older messages above.
		messageFrame:SetFrameLevel(self.state.nextFrameLevel)
		self.state.nextFrameLevel = self.state.nextFrameLevel + 1

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
	local offset = reduce(newMessages, function(acc, message)
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

		if (self.profile.messageAnimations ~= false) and self.profile.chatSlideInDuration > 0 then
			self.state.prevEasingHandle = LibEasing:Ease(function(n)
				self:SetVerticalScroll(n)
			end, startOffset, endOffset, self.profile.chatSlideInDuration, LibEasing.OutCubic)
		else
			self:SetVerticalScroll(endOffset)
		end
	else
		-- Otherwise show "Unread messages" notification
		self.state.unreadMessages = true
		self.overlay:Show()
		self.overlay:ShowNewMessageAlert()
		if not self.state.mouseOver then
			self.overlay:HideDelay(self.profile.chatHoldTime)
		end
	end

	for _, message in ipairs(newMessages) do
		message:Show()
		-- Fade out new messages when mouse is not over, unless messages are pinned.
		-- Each message fades chatHoldTime after its OWN arrival (per-message), so a
		-- newer message does not reset older messages' timers.
		if not self.state.mouseOver and not self.profile.messagesAlwaysVisible then
			message:HideDelay(self.profile.chatHoldTime)
		end
		table.insert(self.state.messages, message)

		-- Queue for a next-frame re-measure so the layout is corrected once the
		-- engine has laid the text out (fixes overlapping messages).
		self.state.pendingMeasure = self.state.pendingMeasure or {}
		table.insert(self.state.pendingMeasure, message)
	end

	-- Release old messages
	local historyLimit = self.profile.messageHistoryLimit or 128
	if #self.state.messages > historyLimit then
		local overflow = #self.state.messages - historyLimit
		local oldMessages = take(self.state.messages, overflow)
		self.state.messages = drop(self.state.messages, overflow)

		for _, message in ipairs(oldMessages) do
			self.messageFramePool:Release(message)
		end
	end

	-- Flash this tab if it received new messages and is NOT currently selected.
	-- Each tab that receives messages will flash independently (like Prat/default Blizz).
	-- This works regardless of whether tabs are faded out.
	if #newMessages > 0 then
		-- Find the tab for this chatFrame directly using the tab name pattern
		local chatFrameName = self.chatFrame:GetName()
		local tabName = chatFrameName .. "Tab"
		local myTab = _G[tabName]

		-- Check if flashing is enabled in profile (default true)
		local flashEnabled = true
		if self.profile and self.profile.flashTabOnMessage == false then
			flashEnabled = false
		end

		-- Flash if enabled, tab exists, and is not the selected one
		if flashEnabled and myTab and Core.Components.selectedTab ~= myTab then
			if myTab.FlashTab and myTab._glassInitialized then
				-- Use our custom flash (shows the tab even when faded)
				myTab:FlashTab()
			elseif _G.FCF_StartAlertFlash then
				-- Fallback to Blizzard's built-in alert flash
				_G.FCF_StartAlertFlash(self.chatFrame)
			end
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

local function CreateSlidingMessageFramePool(parent, window)
	return CreateObjectPool(function()
		local smf = CreateSlidingMessageFrame(nil, parent)
		smf.window = window
		return smf
	end, function(_, smf)
		smf:Hide()
		smf:Destroy() -- unsubscribe event-bus listeners (re-subscribed on next Init)

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
			smf.state.nextFrameLevel = nil -- Reset frame level counter
		end

		if smf.messageFramePool ~= nil then
			smf.messageFramePool:ReleaseAll()
		end
	end)
end

Core.Components.CreateSlidingMessageFrame = CreateSlidingMessageFrame
Core.Components.CreateSlidingMessageFramePool = CreateSlidingMessageFramePool
