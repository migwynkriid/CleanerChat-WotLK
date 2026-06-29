--[[

	CHAT DIAGNOSTIC MODULE - toggled on demand with /ccdebug

	Captures, for every chat line:
	  [RAW] = the exact text the chat frame receives BEFORE CleanerChat
	          modifies it (escaped so color codes / hyperlinks are visible).
	  [EVT] = the underlying CHAT_MSG_* event, including the `author` field,
	          IF the line actually arrives as a normal chat event.

	Use this to find where a player name goes missing:
	  * If [EVT] shows a populated author but the displayed line has no name,
	    CleanerChat is stripping it.
	  * If [EVT] never appears for the line (only [RAW]), the line is being
	    printed straight to the chat frame (e.g. a server relay) and never
	    came through a real event.
	  * If [RAW] already lacks the name, the server/relay never sent one.

	Toggle with:  /ccdebug

--]]
local _, ns = ...

local ipairs = ipairs
local tostring = tostring

local active = false
local printing = false
local hookedFrames = {}

local esc = function(s)
	if (s == nil) then return "<nil>" end
	if (s == "") then return "<empty>" end
	return (tostring(s):gsub("|", "||"))
end

local out = function(text)
	printing = true
	DEFAULT_CHAT_FRAME:AddMessage(text)
	printing = false
end

-- Collapse the per-chat-frame duplication: the same line is delivered to
-- every tab subscribed to a channel, so without this each message would log
-- many times. Identical signatures seen within half a second are skipped.
local recent = {}
local isDuplicate = function(sig)
	local now = GetTime()
	for k,t in pairs(recent) do
		if (now - t > 1) then recent[k] = nil end
	end
	if (recent[sig] and (now - recent[sig]) < 0.5) then
		return true
	end
	recent[sig] = now
	return false
end

-- Wrap each chat frame's AddMessage ON TOP of CleanerChat's hook so we see
-- the unmodified text. Done lazily on first enable, after CleanerChat has
-- already installed its own hook.
local ensureHooks = function()
	for _,name in ipairs(CHAT_FRAMES) do
		local frame = _G[name]
		if (frame and not hookedFrames[frame]) then
			local inner = frame.AddMessage
			hookedFrames[frame] = inner
			frame.AddMessage = function(self, msg, ...)
				if (active and not printing and msg and msg ~= "" and not isDuplicate("RAW"..msg)) then
					out("|cff00ff00[RAW]|r \""..esc(msg).."\"")
				end
				return inner(self, msg, ...)
			end
		end
	end
end

local eventFilter = function(self, event, message, author, ...)
	if (active and not printing and not isDuplicate("EVT"..tostring(event)..tostring(author)..tostring(message))) then
		out("|cff33ccff[EVT]|r "..event.." author=\""..esc(author).."\" msg=\""..esc(message).."\"")
	end
	return false
end

local watchedEvents = {
	"CHAT_MSG_CHANNEL",
	"CHAT_MSG_SAY",
	"CHAT_MSG_YELL",
	"CHAT_MSG_GUILD",
	"CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER",
	-- Reward / system events (to trace duplicated quest rewards)
	"CHAT_MSG_LOOT",
	"CHAT_MSG_CURRENCY",
	"CHAT_MSG_MONEY",
	"CHAT_MSG_SYSTEM",
	"CHAT_MSG_COMBAT_MISC_INFO",
	"CHAT_MSG_COMBAT_XP_GAIN",
	"CHAT_MSG_COMBAT_FACTION_CHANGE",
}

SLASH_CCDEBUG1 = "/ccdebug"

-- Turn capture on/off. `silent` skips the chat confirmation (used when
-- re-applying the saved state on login).
local setActive = function(value, silent)
	value = value and true or false
	if (value == active) then return end
	active = value
	if (active) then
		ensureHooks()
		for _,event in ipairs(watchedEvents) do
			ChatFrame_AddMessageEventFilter(event, eventFilter)
		end
		if (not silent) then
			print("|cffff7d0aCleanerChat|r raw debug: |cff00ff00ON|r - say something in the affected channel.")
		end
	else
		for _,event in ipairs(watchedEvents) do
			ChatFrame_RemoveMessageEventFilter(event, eventFilter)
		end
		if (not silent) then
			print("|cffff7d0aCleanerChat|r raw debug: |cffff0000OFF|r")
		end
	end
end

-- Public setter that also PERSISTS the choice to the saved variables so it
-- survives a /reload or relog.
ns.SetRawDebug = function(value)
	value = value and true or false
	if (ns.db) then ns.db.rawDebug = value end
	setActive(value)
end

ns.GetRawDebug = function()
	if (ns.db) then return ns.db.rawDebug and true or false end
	return active
end

-- Expose the toggle on the addon namespace so it can also be reached through
-- the addon's normal AceConsole command registration (in Options.lua), which
-- is known to work on this client even when a bare SlashCmdList entry doesn't.
ns.ToggleRawDebug = function()
	ns.SetRawDebug(not active)
end

SlashCmdList["CCDEBUG"] = function()
	ns.ToggleRawDebug()
end

-- Re-apply the saved state on login (ns.db is ready by PLAYER_LOGIN, which
-- fires after AceAddon OnInitialize sets up the database).
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	if (ns.db and ns.db.rawDebug) then
		setActive(true, true)
	end
end)
