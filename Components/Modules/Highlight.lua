local _, ns = ...

-- Keyword Highlighting
-- Colours the player's own name where it appears in the readable text of an
-- incoming chat line. Escape sequences (the sender's |Hplayer:...|h link,
-- textures, colour codes) are copied through untouched, so hyperlinks are never
-- corrupted -- a naive search would match the name inside the sender's link data
-- and mangle the whole message. Optionally plays a short alert sound (controlled
-- by the separate "highlightSound" setting). Runs as a message replacement, so
-- it applies to whatever chat display is active.

local Module = ns:NewModule("Highlight", "AceEvent-3.0")

-- Lua API
local string_find = string.find
local string_lower = string.lower
local string_sub = string.sub
local table_concat = table.concat

-- WoW API
local PlaySound = PlaySound
local UnitName = UnitName
-- GLOBALS: PlaySound, UnitName

local HIGHLIGHT_COLOR = "|cffffcc00"

-- Lower-cased player name, refreshed on login (nil until we know it).
local playerName

local function refreshPlayerName()
	local name = UnitName("player")
	playerName = (name and name ~= "") and string_lower(name) or nil
end

-- Whole-word test: a letter on either side means the name is embedded in a
-- larger word (e.g. "Kriidsson"), which we leave alone.
local function isLetter(char)
	return char ~= "" and string_find(char, "%a") ~= nil
end

-- Highlight every whole-word occurrence of the name inside a plain-text run,
-- preserving the original casing. Returns the processed text and a match count.
local function highlightPlainText(chunk)
	local lowerChunk = string_lower(chunk)
	local pieces = {}
	local from = 1
	local matches = 0
	while true do
		local s, e = string_find(lowerChunk, playerName, from, true)
		if not s then
			pieces[#pieces + 1] = string_sub(chunk, from)
			break
		end
		local before = (s > 1) and string_sub(lowerChunk, s - 1, s - 1) or ""
		local after = (e < #lowerChunk) and string_sub(lowerChunk, e + 1, e + 1) or ""
		if isLetter(before) or isLetter(after) then
			pieces[#pieces + 1] = string_sub(chunk, from, e)
		else
			pieces[#pieces + 1] = string_sub(chunk, from, s - 1)
			pieces[#pieces + 1] = HIGHLIGHT_COLOR .. string_sub(chunk, s, e) .. "|r"
			matches = matches + 1
		end
		from = e + 1
	end
	return table_concat(pieces), matches
end

local function highlightName(msg)
	if not msg or not playerName then
		return msg
	end
	-- Cheap early-out: nothing to do if the name is nowhere in the line.
	if not string_find(string_lower(msg), playerName, 1, true) then
		return msg
	end

	-- Walk the line, passing escape sequences through untouched and only
	-- highlighting the name in the plain-text runs (the message body) between
	-- them. This keeps the sender's |Hplayer:Name:...|h[Name]|h link intact.
	local pieces = {}
	local matches = 0
	local i, n = 1, #msg
	while i <= n do
		if string_sub(msg, i, i) == "|" then
			local nxt = string_sub(msg, i + 1, i + 1)
			if nxt == "H" then
				local s, e = string_find(msg, "^|H.-|h.-|h", i)
				if s then
					pieces[#pieces + 1] = string_sub(msg, s, e)
					i = e + 1
				else
					pieces[#pieces + 1] = "|"
					i = i + 1
				end
			elseif nxt == "T" then
				local s, e = string_find(msg, "^|T.-|t", i)
				if s then
					pieces[#pieces + 1] = string_sub(msg, s, e)
					i = e + 1
				else
					pieces[#pieces + 1] = "|"
					i = i + 1
				end
			elseif nxt == "c" then
				local s, e = string_find(msg, "^|c%x%x%x%x%x%x%x%x", i)
				if s then
					pieces[#pieces + 1] = string_sub(msg, s, e)
					i = e + 1
				else
					pieces[#pieces + 1] = "|"
					i = i + 1
				end
			else
				-- |r or a stray escape: copy the two-character sequence.
				pieces[#pieces + 1] = string_sub(msg, i, i + 1)
				i = i + 2
			end
		else
			local barPos = string_find(msg, "|", i, true)
			local stop = (barPos and barPos - 1) or n
			local processed, count = highlightPlainText(string_sub(msg, i, stop))
			pieces[#pieces + 1] = processed
			matches = matches + count
			i = stop + 1
		end
	end

	if matches > 0 and ns.db and ns.db.highlightSound then
		PlaySound("RaidWarning")
	end
	return table_concat(pieces)
end

function Module:OnEnable()
	refreshPlayerName()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", refreshPlayerName)
	self:RegisterMessageReplacement(highlightName, true)
end

function Module:OnDisable()
	self:UnregisterAllEvents()
	self:UnregisterMessageReplacement(highlightName)
end
