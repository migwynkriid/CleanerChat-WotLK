local _, ns = ...

-- Lua API
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local string_gsub = string.gsub
local string_match = string.match

-- Converts a WoW global string (containing %d / %s tokens) into a Lua
-- search pattern with capture groups. Previously duplicated verbatim in
-- every Components module; centralized here as ns.MakePattern.
ns.MakePattern = function(msg)
	if (not msg) or (msg == "") then
		return nil
	end
	msg = string_gsub(msg, "%%([%d%$]-)d", "(%%d+)")
	msg = string_gsub(msg, "%%([%d%$]-)s", "(.+)")
	return msg
end

-- Returns a self-populating pattern cache. Indexing it with a WoW global string
-- lazily compiles (via ns.MakePattern) and memoizes the resulting search
-- pattern. Replaces the identical setmetatable boilerplate that was duplicated
-- in every filter module.
ns.MakePatternCache = function()
	return setmetatable({}, {
		__index = function(t, k)
			if (k == nil) or (k == "") then
				return nil
			end
			rawset(t, k, ns.MakePattern(k))
			return rawget(t, k)
		end,
	})
end

-- Pattern match that tolerates a nil pattern (returns nil instead of erroring),
-- e.g. when a WoW global string doesn't exist on this client.
ns.SafeMatch = function(msg, pattern)
	if not pattern then
		return nil
	end
	return string_match(msg, pattern)
end

-- Strip the surrounding [ and ] from an item/spell link's display name while
-- keeping the |H...|h hyperlink and its colour intact. (Also strips stray "/"
-- for parity with the original inline gsub used across the filters.)
ns.StripBrackets = function(s)
	if not s then
		return s
	end
	return (string_gsub(s, "[%[/%]]", ""))
end

-- Emit a message to a chat frame using the colour WoW normally uses for the
-- given chat type (e.g. "LOOT", "MONEY"), falling back to the frame default.
-- Centralizes the ChatTypeInfo lookup + AddMessage pattern that was duplicated
-- across the loot, money and reputation modules.
ns.PrintToFrame = function(chatFrame, msg, chatType)
	if (not chatFrame) or not chatFrame.AddMessage or not msg then
		return
	end
	local info = chatType and ChatTypeInfo and ChatTypeInfo[chatType]
	if info then
		chatFrame:AddMessage(msg, info.r, info.g, info.b)
	else
		chatFrame:AddMessage(msg)
	end
end

-- Creates a per-chat-frame batching buffer. Bursts of events that fire within
-- the same frame (e.g. a quest turn-in) are collected per chat frame and
-- flushed once on the next frame. `newState()` returns a fresh accumulator;
-- `flush(chatFrame, state)` consumes it. Returns a table with:
--   .Get(chatFrame)      -> the current accumulator (created on demand)
--   .Schedule(chatFrame) -> arrange a next-frame flush (idempotent per frame)
-- The accumulator is cleared *before* flush runs, so output produced during the
-- flush safely starts a new batch.
ns.CreateFrameBuffer = function(newState, flush)
	local buffers = {}

	local function get(chatFrame)
		local buf = buffers[chatFrame]
		if not buf then
			buf = newState()
			buf.scheduled = false
			buffers[chatFrame] = buf
		end
		return buf
	end

	local function schedule(chatFrame)
		local buf = get(chatFrame)
		if buf.scheduled then
			return
		end
		buf.scheduled = true

		local function run()
			local b = buffers[chatFrame]
			if not b then
				return
			end
			-- Reset before flushing so anything printed during the flush starts a
			-- fresh batch instead of mutating the one being drained.
			buffers[chatFrame] = nil
			flush(chatFrame, b)
		end

		if ns.Timer and ns.Timer.After then
			ns.Timer.After(0, run)
		elseif C_Timer and C_Timer.After then
			C_Timer.After(0, run)
		else
			run()
		end
	end

	return { Get = get, Schedule = schedule }
end
