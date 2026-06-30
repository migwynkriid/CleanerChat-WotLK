local Core = unpack(select(2, ...))
local TP = Core:GetModule("TextProcessing")

-- luacheck: push ignore 113
local strjoin = strjoin
local strsplit = strsplit
-- luacheck: pop

---
--Takes a texture escape string and adjusts its yOffset
local function adjustTextureYOffset(texture, yOffset)
	-- Texture has 14 parts
	-- path, height, width, offsetX, offsetY,
	-- texWidth, texHeight
	-- leftTex, topTex, rightTex, bottomText,
	-- rColor, gColor, bColor

	-- Strip escape characters
	-- Split into parts
	local parts = { strsplit(":", strsub(texture, 3, -3)) }

	if #parts < 5 then
		-- Pad out ommitted attributes
		for i = 1, 5 do
			if parts[i] == nil then
				if i == 3 then
					-- If width is not specified, the width should equal the height
					parts[i] = parts[2]
				else
					parts[i] = "0"
				end
			end
		end
	end

	-- Adjust yOffset by configured amount
	parts[5] = tostring(tonumber(parts[5]) - yOffset)

	-- Rejoin string and readd escape codes
	return "|T" .. strjoin(":", unpack(parts)) .. "|t"
end

---
-- Gets all inline textures found in the string and adjusts their yOffset
local function textureProcessor(text, profile)
	local cursor = 1
	local origLen = strlen(text)
	local p = profile or Core.db.profile
	local yOffset = p.iconTextureYOffset

	local parts = {}

	while cursor <= origLen do
		local mStart, mEnd = strfind(text, "%|T.-%|t", cursor)

		if mStart then
			table.insert(parts, strsub(text, cursor, mStart - 1))
			table.insert(parts, adjustTextureYOffset(strsub(text, mStart, mEnd), yOffset))
			-- Add a space after icon if next char is alphanumeric (prevents icon overlapping into words)
			local nextChar = strsub(text, mEnd + 1, mEnd + 1)
			if nextChar ~= "" and nextChar ~= " " and nextChar ~= "|" and nextChar ~= "." and nextChar ~= "," then
				table.insert(parts, " ")
			end
			cursor = mEnd + 1
		else
			-- No more matches
			table.insert(parts, strsub(text, cursor, origLen))
			cursor = origLen + 1
		end
	end

	return strjoin("", unpack(parts))
end

---
-- Adds Prat Timestamps if configured
local function pratTimestampProcessor(text)
	-- Prat isn't installed for most users; bail out instead of erroring. This runs
	-- inside a pcall, so the failure was silent -- but it happened on every message.
	if not _G.Prat then
		return text
	end
	return _G.Prat.Addon:GetModule("Timestamps"):InsertTimeStamp(text)
end

---
-- Adds timestamps in [HH:MM] format if enabled in settings.
-- Uses the provided profile's showTimestamps setting.
local function timestampProcessor(text, profile)
	local p = profile or Core.db.profile
	if not p.showTimestamps then
		return text
	end
	local timestamp = date("[%H:%M] ")
	return timestamp .. text
end

---
-- URL detection + linkification.
-- Bare URLs in chat are not clickable, so we wrap each detected URL in a custom
-- "url" hyperlink: |Hurl:<addr>|h<addr>|h. The Glass message overlay then makes
-- it clickable like any other link, and Modules/Hyperlinks.lua opens a small
-- copy dialog when a url link is clicked.
local URL_COLOR = "|cff40a6ff" -- light blue, link-like

-- Top-level domains accepted for *bare* "domain.tld" matches (no scheme/path),
-- to keep false positives (e.g. "etc.", "wait.no") low. URLs with a scheme,
-- "www.", a port or a path are matched regardless of TLD.
local COMMON_TLDS = {
	com = true,
	net = true,
	org = true,
	edu = true,
	gov = true,
	io = true,
	gg = true,
	tv = true,
	co = true,
	me = true,
	info = true,
	biz = true,
	dev = true,
	app = true,
	xyz = true,
	online = true,
	wiki = true,
	gl = true,
}

-- Decide whether a cleaned token is something we want to linkify.
local function isUrlCandidate(s)
	if string.match(s, "^%a[%w%+%.%-]*://.") then
		return true
	end -- scheme://...
	if string.match(s, "^[Ww][Ww][Ww]%.[%w%.%-]+%.%a%a") then
		return true
	end -- www.x.tld
	if string.match(s, "^mailto:.") then
		return true
	end
	if string.match(s, "^[%w%.%-_%+]+@[%w%.%-]+%.%a%a+$") then
		return true
	end -- email
	if string.match(s, "^%d+%.%d+%.%d+%.%d+") then
		return true
	end -- IPv4 (+port/path)
	if string.match(s, "^[%w%.%-]+%.[%w%-]+[:/]") then
		return true
	end -- domain.tld:port or /path
	local tld = string.match(s, "^[%w%-]+%.([%a][%a]+)$") or string.match(s, "%.([%a][%a]+)$")
	return tld ~= nil and COMMON_TLDS[string.lower(tld)] == true -- bare domain.tld
end

-- Wrap a single whitespace token if it is a URL, preserving leading brackets/
-- quotes and trailing sentence punctuation around it.
local function processWord(word)
	local lead, core, trail = string.match(word, "^([%(%[<\"']*)(.-)([%)%]>\"'%.,;:!%?]*)$")
	if core and core ~= "" and isUrlCandidate(core) then
		return lead .. URL_COLOR .. "|Hurl:" .. core .. "|h" .. core .. "|h|r" .. trail
	end
	return word
end

local function wrapUrlsInPlainText(chunk)
	local result = string.gsub(chunk, "%S+", processWord)
	return result
end

-- Walk the text, copying existing escape sequences (|H links, |T textures, |c/|r
-- colours) through untouched and only linkifying URLs in the plain-text runs
-- between them -- so we never linkify inside another link or a texture.
local function urlProcessor(text)
	if not text or text == "" then
		return text
	end
	if not string.find(text, "%.") and not string.find(text, "@", 1, true) then
		return text
	end

	local out = {}
	local i, n = 1, #text
	while i <= n do
		if string.sub(text, i, i) == "|" then
			local nxt = string.sub(text, i + 1, i + 1)
			if nxt == "H" then
				local s, e = string.find(text, "^|H.-|h.-|h", i)
				if s then
					table.insert(out, string.sub(text, s, e))
					i = e + 1
				else
					table.insert(out, "|")
					i = i + 1
				end
			elseif nxt == "T" then
				local s, e = string.find(text, "^|T.-|t", i)
				if s then
					table.insert(out, string.sub(text, s, e))
					i = e + 1
				else
					table.insert(out, "|")
					i = i + 1
				end
			elseif nxt == "c" then
				local s, e = string.find(text, "^|c%x%x%x%x%x%x%x%x", i)
				if s then
					table.insert(out, string.sub(text, s, e))
					i = e + 1
				else
					table.insert(out, "|")
					i = i + 1
				end
			else
				-- |r or a stray escape: copy two characters
				table.insert(out, string.sub(text, i, i + 1))
				i = i + 2
			end
		else
			local barPos = string.find(text, "|", i, true)
			local stop = (barPos and barPos - 1) or n
			table.insert(out, wrapUrlsInPlainText(string.sub(text, i, stop)))
			i = stop + 1
		end
	end
	return table.concat(out)
end

---
-- Text processing pipeline
-- Processors that don't need profile context
local SIMPLE_PROCESSORS = {
	urlProcessor,
	pratTimestampProcessor,
}

-- Processors that need profile context for per-window settings
local PROFILE_PROCESSORS = {
	timestampProcessor,
	textureProcessor,
}

function TP:ProcessText(text, profile)
	local result = text

	-- First apply profile-aware processors (timestamps, textures)
	for _, processor in ipairs(PROFILE_PROCESSORS) do
		local retOk, retVal = pcall(processor, result, profile)
		if retOk then
			result = retVal
		end
	end

	-- Then apply simple processors that don't need profile
	for _, processor in ipairs(SIMPLE_PROCESSORS) do
		-- Prevent failing processors from bringing down the whole pipeline
		local retOk, retVal = pcall(processor, result)

		if retOk then
			result = retVal
		end
	end

	return result
end
