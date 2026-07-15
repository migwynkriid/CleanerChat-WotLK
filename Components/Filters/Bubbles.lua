--[[

	CHAT BUBBLE MODULE - toggled with the "Activate bubbles" option in /cc

	Strips the default black background and border from the speech bubbles that
	appear over a player's or NPC's head on SAY / YELL, leaving only the message
	text floating in the world. The original textures are remembered so the
	default look is fully restored when the feature is turned off.

	On the 3.3.5 client chat bubbles are anonymous frames parented to WorldFrame.
	New bubbles only appear as new WorldFrame children, so we watch the child
	count and only rescan when it changes, keeping the OnUpdate cheap.

--]]
local _, ns = ...

local Module = ns:NewModule("Bubbles")

-- Lua API
local pairs = pairs
local select = select

-- WoW globals
-- GLOBALS: WorldFrame, CreateFrame
local WorldFrame = WorldFrame
local CreateFrame = CreateFrame

-- The default chat-bubble background texture used by the 3.3.5 client. A frame
-- is treated as a chat bubble when one of its texture regions uses this file.
local BUBBLE_BACKGROUND = "Interface\\Tooltips\\ChatBubble-Background"

-- How often (seconds) we look for new bubbles. Because we only rescan when the
-- WorldFrame child count changes, this throttle just caps how often we check
-- that count.
local SCAN_THROTTLE = 0.1

-- Per-bubble record of the texture regions we stripped and their original
-- textures, so the backgrounds can be restored when the feature is turned off.
local stripped = {}

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

-- Remove the background/border textures from a bubble, leaving only the message
-- text (a FontString, which is not a Texture region and is left untouched).
-- Original textures are saved so they can be restored later.
local function StripBubble(frame)
	local saved = stripped[frame]
	if not saved then
		saved = {}
		stripped[frame] = saved
	end
	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			if saved[region] == nil then
				saved[region] = region:GetTexture() or false
			end
			region:SetTexture(nil)
		end
	end
end

-- Restore every bubble we previously stripped back to its default look.
local function RestoreAll()
	for frame, saved in pairs(stripped) do
		for region, texture in pairs(saved) do
			if texture then
				region:SetTexture(texture)
			end
		end
		stripped[frame] = nil
	end
end

Module.OnEnable = function(self)
	if not self.scanner then
		local scanner = CreateFrame("Frame")
		scanner.elapsed = 0
		scanner.lastChildCount = 0
		scanner:SetScript("OnUpdate", function(frame, elapsed)
			frame.elapsed = frame.elapsed + elapsed
			if frame.elapsed < SCAN_THROTTLE then
				return
			end
			frame.elapsed = 0

			local count = WorldFrame:GetNumChildren()
			if count == frame.lastChildCount then
				return
			end
			frame.lastChildCount = count

			for i = 1, count do
				local child = select(i, WorldFrame:GetChildren())
				if IsChatBubble(child) then
					StripBubble(child)
				end
			end
		end)
		self.scanner = scanner
	end

	self.scanner.elapsed = 0
	self.scanner.lastChildCount = 0
	self.scanner:Show()
end

Module.OnDisable = function(self)
	if self.scanner then
		self.scanner:Hide()
	end
	RestoreAll()
end
