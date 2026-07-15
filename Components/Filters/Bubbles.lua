--[[

	CHAT BUBBLE MODULE - toggled with the "Activate bubbles" option in /cc

	Strips the default black background and border from the speech bubbles that
	appear over a player's or NPC's head on SAY / YELL, leaving only the message
	text floating in the world. The bubble text is restyled to the chat message
	font/outline and prefixed with the speaker's name (class-coloured for
	players), e.g. "Playername: HELLO". The originals are remembered so the
	default look is fully restored when the feature is turned off.

	On the 3.3.5 client chat bubbles are anonymous frames parented to WorldFrame.
	New bubbles appear as new WorldFrame children (discovered when the child count
	changes), but the client REUSES a hidden bubble frame for later messages
	without changing the count -- so once discovered, each bubble is reconciled
	every tick to catch new messages (e.g. to re-apply the speaker's name).

--]]
local _, ns = ...

local Module = ns:NewModule("Bubbles")

-- Lua API
local pairs = pairs
local select = select
local table_remove = table.remove
local type = type

-- WoW globals
-- GLOBALS: WorldFrame, CreateFrame, LibStub, Glass, GetTime, GetPlayerInfoByGUID, UnitClass, UnitExists, UnitIsPlayer, UnitName
local _G = _G
local WorldFrame = WorldFrame
local CreateFrame = CreateFrame
local LibStub = _G.LibStub
local GetTime = GetTime
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitName = UnitName

-- The default chat-bubble background texture used by the 3.3.5 client. A frame
-- is treated as a chat bubble when one of its texture regions uses this file.
local BUBBLE_BACKGROUND = "Interface\\Tooltips\\ChatBubble-Background"

-- How often (seconds) we look for new bubbles. Because we only rescan when the
-- WorldFrame child count changes, this throttle just caps how often we check
-- that count.
local SCAN_THROTTLE = 0.1

-- Seconds spent fading a bubble out at the end of its custom hold time.
local BUBBLE_FADE = 0.5

-- Per-bubble record of what we changed (stripped texture regions + original
-- textures, and the message FontString + its original font), so everything can
-- be restored to the default look when the feature is turned off.
local stripped = {}

-- Set of frames identified as chat bubbles. Kept even after a bubble's background
-- is stripped (which makes it undetectable by texture again) so that reused
-- bubbles showing a new message can still be reconciled.
local known = {}

-- Resolve the bubble text font (path, flags). Uses the Bubbles font/outline
-- overrides from the profile when set, otherwise inherits the chat message
-- font/outline from the Glass profile. Read at call time because the Glass addon
-- and the saved settings are only available after login.
local function GetBubbleFontConfig()
	local glass = _G.Glass
	local p = glass and glass.db and glass.db.profile
	local db = ns.db

	-- `false` (the default) means "inherit the chat message setting".
	local fontName = (db and db.bubbleFont) or (p and p.messageFont)
	local flags = (db and db.bubbleFontFlags) or (p and p.messageFontFlags)

	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	local path = LSM and fontName and LSM:Fetch(LSM.MediaType.FONT, fontName)
	return path, flags
end

-- Locate the bubble's message text. On the 3.3.5 client this is usually a direct
-- FontString region of the bubble frame; fall back to scanning child frames.
local function GetBubbleFontString(frame)
	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "FontString" then
			return region
		end
	end
	if frame.GetNumChildren then
		for i = 1, frame:GetNumChildren() do
			local child = select(i, frame:GetChildren())
			if child and child.GetNumRegions then
				for j = 1, child:GetNumRegions() do
					local region = select(j, child:GetRegions())
					if region and region.GetObjectType and region:GetObjectType() == "FontString" then
						return region
					end
				end
			end
		end
	end
end

-- Speaker-name tracking -------------------------------------------------------
--
-- Chat bubbles carry no speaker information, so we listen to the SAY / YELL (and
-- their MONSTER_ variants) chat events and queue each message together with the
-- name to show. When a bubble is skinned we match its text against the queue and
-- prefix the name. Players are class-coloured; NPCs are shown plain.

-- Recent messages awaiting a matching bubble: { msg, name, time }.
local pending = {}
local PENDING_TTL = 15 -- seconds before an unmatched message is discarded
local PENDING_MAX = 50 -- hard cap on queued messages

local function PrunePending()
	local now = GetTime()
	for i = #pending, 1, -1 do
		if now - pending[i].time > PENDING_TTL then
			table_remove(pending, i)
		end
	end
	while #pending > PENDING_MAX do
		table_remove(pending, 1)
	end
end

-- Find and remove the oldest queued message whose text matches `text`,
-- returning the display name to prefix (or nil if none is queued).
local function ConsumeName(text)
	for i = 1, #pending do
		if pending[i].msg == text then
			local name = pending[i].name
			table_remove(pending, i)
			return name
		end
	end
end

-- Read a player's English class off any visible unit whose name matches. There
-- is no API to look up an arbitrary player's class on 3.3.5, so we inspect the
-- units that could be the speaker (self, target, focus, mouseover, group).
local function ClassFromUnits(name)
	local fixed = { "player", "target", "targettarget", "focus", "focustarget", "mouseover" }
	for i = 1, #fixed do
		local unit = fixed[i]
		if UnitExists(unit) and UnitIsPlayer(unit) and UnitName(unit) == name then
			local _, class = UnitClass(unit)
			return class
		end
	end
	for i = 1, 4 do
		local unit = "party" .. i
		if UnitExists(unit) and UnitName(unit) == name then
			local _, class = UnitClass(unit)
			return class
		end
	end
	for i = 1, 40 do
		local unit = "raid" .. i
		if UnitExists(unit) and UnitName(unit) == name then
			local _, class = UnitClass(unit)
			return class
		end
	end
end

-- Build the class-coloured display name for a player (falls back to the plain
-- name when the class can't be determined).
local function ClassColorForName(sender, guid)
	if not sender or sender == "" then
		return sender
	end
	local colors = ns.Colors
	if not (colors and colors.class) then
		return sender
	end

	local class
	-- Some 3.3.5 servers include the sender GUID with chat events; use it when
	-- present, otherwise read the class off a matching visible unit.
	if type(guid) == "string" and guid ~= "" and GetPlayerInfoByGUID then
		local _, englishClass = GetPlayerInfoByGUID(guid)
		class = englishClass
	end
	if not class then
		class = ClassFromUnits(sender)
	end

	local color = class and colors.class[class]
	if color and color.colorCode then
		return color.colorCode .. sender .. "|r"
	end
	return sender
end

-- Queue a SAY / YELL message with the name to display on its bubble.
local function OnSpeakEvent(_, event, message, sender, ...)
	if not message or message == "" or not sender or sender == "" then
		return
	end
	local name
	if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" then
		name = ClassColorForName(sender, select(10, ...))
	else
		-- Monster SAY / YELL: NPCs have no class, so show the plain name.
		name = sender
	end
	PrunePending()
	pending[#pending + 1] = { msg = message, name = name, time = GetTime() }
end

-- Returns true if `frame` is a chat bubble that still shows its background.
-- Already-stripped bubbles report false (their background texture is nil), so
-- they are naturally skipped on subsequent scans.
local function IsChatBubble(frame)
	if frame:GetName() then
		return false
	end
	if not frame.GetNumRegions then
		return false
	end
	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if
			region
			and region.GetObjectType
			and region:GetObjectType() == "Texture"
			and region:GetTexture() == BUBBLE_BACKGROUND
		then
			return true
		end
	end
	return false
end

-- Bring a known bubble into the desired state: background/border textures
-- stripped, message text restyled to the chat font/outline and prefixed with the
-- speaker's name. Safe to call every tick -- it early-outs once the bubble
-- already shows our named text, and re-runs when a reused bubble shows a new
-- message. Originals are saved so everything can be restored later.
local function ReconcileBubble(frame)
	if not frame:IsShown() then
		return
	end

	local record = stripped[frame]
	if not record then
		record = { textures = {} }
		stripped[frame] = record
	end

	-- Strip any background/border textures currently set (a FontString is not a
	-- Texture region, so the message text is left in place).
	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			local tex = region:GetTexture()
			if tex then
				if record.textures[region] == nil then
					record.textures[region] = tex or false
				end
				region:SetTexture(nil)
			end
		end
	end

	local fs = GetBubbleFontString(frame)
	if not fs then
		return
	end

	-- Remember the bubble's original font once, so it can be restored later.
	if not record.fs then
		record.fs = fs
		local path, size, flags = fs:GetFont()
		record.font = { path, size, flags }
	end

	local text = fs:GetText()
	if not text or text == "" then
		return
	end
	-- Already showing what we last applied for this message -> nothing to do. A
	-- reused bubble shows a new (plain) message which differs from timedText, so it
	-- gets processed afresh (re-stripped, re-named, timer restarted).
	if text == record.timedText then
		return
	end

	-- Apply the bubble font (family + outline flags). Keep the bubble's native
	-- size so it still scales correctly in the world.
	local fontPath, fontFlags = GetBubbleFontConfig()
	if fontPath then
		local _, size = fs:GetFont()
		fs:SetFont(fontPath, size or (record.font and record.font[2]) or 13, fontFlags or "")
	end

	-- Prefix the speaker's name, e.g. "Playername: HELLO", matched from the queued
	-- SAY / YELL events by message text. Skipped when the name display is off.
	local displayed = text
	if ns.db and ns.db.bubbleShowName ~= false then
		local name = ConsumeName(text)
		if name then
			-- The client sizes the FontString's width to the original (short)
			-- message, which would wrap our longer text one character per line.
			-- Clear the width so it lays out on a single line instead.
			fs:SetWidth(0)
			record.origText = text
			displayed = name .. ": " .. text
			fs:SetText(displayed)
		end
	end

	record.namedText = (displayed ~= text) and displayed or nil
	record.timedText = displayed

	-- Start (or restart) the custom fade timer for this freshly shown message.
	if ns.db and ns.db.bubbleCustomHold then
		record.shownAt = GetTime()
		record.expired = false
	end
end

-- Restore every bubble we previously stripped back to its default look.
local function RestoreAll()
	for frame, record in pairs(stripped) do
		for region, texture in pairs(record.textures) do
			if texture then
				region:SetTexture(texture)
			end
		end
		if record.fs and record.font and record.font[1] then
			record.fs:SetFont(record.font[1], record.font[2], record.font[3])
		end
		if record.fs and record.namedText and record.fs:GetText() == record.namedText then
			record.fs:SetText(record.origText)
		end
		frame:SetAlpha(1)
		stripped[frame] = nil
	end
end

-- Drive the custom fade timing. Runs every frame (not throttled) so the fade is
-- smooth and can override the client's own fade. Holds the bubble at full alpha
-- until its duration, fades it out over BUBBLE_FADE, then hides it. When the
-- custom hold is off, alpha is handed straight back to the client.
local function ManageHold()
	local db = ns.db
	local custom = db and db.activateBubbles and db.bubbleCustomHold
	local holdTime = (db and db.bubbleHoldTime) or 10
	local now = GetTime()

	for frame, record in pairs(stripped) do
		if record.shownAt then
			if not custom then
				frame:SetAlpha(1)
				record.shownAt = nil
				record.expired = nil
			elseif not record.expired then
				local elapsed = now - record.shownAt
				if elapsed >= holdTime then
					frame:SetAlpha(0)
					frame:Hide()
					record.expired = true
				elseif elapsed > holdTime - BUBBLE_FADE then
					frame:SetAlpha((holdTime - elapsed) / BUBBLE_FADE)
					if not frame:IsShown() then
						frame:Show()
					end
				else
					frame:SetAlpha(1)
					if not frame:IsShown() then
						frame:Show()
					end
				end
			end
		end
	end
end

Module.OnEnable = function(self)
	if not self.scanner then
		local scanner = CreateFrame("Frame")
		scanner.elapsed = 0
		scanner.lastChildCount = 0
		scanner:SetScript("OnUpdate", function(frame, elapsed)
			-- Every frame: drive the custom bubble fade/hold timing so it stays
			-- smooth and can override the client's own fade.
			ManageHold()

			frame.elapsed = frame.elapsed + elapsed
			if frame.elapsed < SCAN_THROTTLE then
				return
			end
			frame.elapsed = 0

			-- Discover newly created bubble frames. New bubbles appear as new
			-- WorldFrame children, so we only rescan the child list when its size
			-- changes; discovered frames are remembered in `known`.
			local count = WorldFrame:GetNumChildren()
			if count ~= frame.lastChildCount then
				frame.lastChildCount = count
				for i = 1, count do
					local child = select(i, WorldFrame:GetChildren())
					if not known[child] and IsChatBubble(child) then
						known[child] = true
					end
				end
			end

			-- Reconcile every known bubble each tick. Reused bubbles do not change
			-- the child count, so this is what keeps their message stripped and
			-- re-applies the speaker's name to every message, not just the first.
			for bubble in pairs(known) do
				ReconcileBubble(bubble)
			end
		end)
		self.scanner = scanner
	end

	if not self.listener then
		local listener = CreateFrame("Frame")
		listener:SetScript("OnEvent", OnSpeakEvent)
		self.listener = listener
	end
	self.listener:RegisterEvent("CHAT_MSG_SAY")
	self.listener:RegisterEvent("CHAT_MSG_YELL")
	self.listener:RegisterEvent("CHAT_MSG_MONSTER_SAY")
	self.listener:RegisterEvent("CHAT_MSG_MONSTER_YELL")

	self.scanner.elapsed = 0
	self.scanner.lastChildCount = 0
	self.scanner:Show()
end

Module.OnDisable = function(self)
	if self.scanner then
		self.scanner:Hide()
	end
	if self.listener then
		self.listener:UnregisterAllEvents()
	end
	for i = #pending, 1, -1 do
		pending[i] = nil
	end
	RestoreAll()
	for frame in pairs(known) do
		known[frame] = nil
	end
end
