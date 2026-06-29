local _, ns = ...

local Module = ns:NewModule("Blacklist")

-- Lua API
local string_find = string.find
local string_format = string.format
local string_match = string.match

-- Build blacklist table safely (some globals may be nil in 3.3.5)
local B = {}
if ERR_NOT_IN_INSTANCE_GROUP then B[ERR_NOT_IN_INSTANCE_GROUP] = true end
if ERR_NOT_IN_RAID then B[ERR_NOT_IN_RAID] = true end
if ERR_QUEST_ALREADY_ON then B[ERR_QUEST_ALREADY_ON] = true end

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	-- Death message: |cff71d5ff|Hdeath:...|h[You died.]|h|r
	if (string_find(message, "|Hdeath:")) then
		return false, ns.out.died, author, ...
	end

	-- Durability loss: "Your equipped items suffer a 10% durability loss."
	-- Comes through CHAT_MSG_COMBAT_MISC_INFO
	if (event == "CHAT_MSG_COMBAT_MISC_INFO") then
		local durability = string_match(message, "suffer a (%d+)%% durability loss")
		if (durability) then
			return false, string_format(ns.out.durability_loss, tonumber(durability)), author, ...
		end
	end

	if (B[message]) then
		-- These problems mostly occur in battlegrounds and other PvP.
		return IsInInstance()
	end
end

-- Suppress ONLY the benign, repeated "Interface\FrameXML\ChatFrame.lua:3481:
-- assertion failed!" (from Glass's chat-dock interference) -- so REAL errors are
-- never hidden and nothing is missed.
--
-- The server's "UI Error: an interface error occured." chat line is GENERIC --
-- identical for every error -- so we can't tell from the line alone which error
-- it belongs to. An error watcher chains the Lua error handler: for the 3481
-- assert it records a flag and swallows it (so it isn't reported by BugGrabber /
-- the error frame); EVERY other error is passed straight through untouched.
-- Re-installed on login so it stays on top of BugGrabber. OnAddMessage then
-- drops the generic "UI Error" line ONLY when the matching error was the 3481
-- assert, so a real bug still shows its notification.
local lastErrorWas3481 = false
local prevErrorHandler

local function ccErrorHandler(err, ...)
	local is3481 = (type(err) == "string") and string_find(err, "ChatFrame.lua:3481", 1, true) and true or false
	lastErrorWas3481 = is3481
	if (is3481 and ns.db and ns.db.hideUIErrors) then
		return -- swallow ONLY the benign 3481 assert; do not report it
	end
	if (prevErrorHandler) then return prevErrorHandler(err, ...) end
end

local function installErrorWatcher()
	if (not _G.seterrorhandler) then return end
	local cur = _G.geterrorhandler and _G.geterrorhandler()
	if (cur == ccErrorHandler) then return end -- already on top
	prevErrorHandler = cur
	_G.seterrorhandler(ccErrorHandler)
end

installErrorWatcher()
if (_G.CreateFrame) then
	local watcher = _G.CreateFrame("Frame")
	watcher:RegisterEvent("PLAYER_LOGIN")
	watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	watcher:SetScript("OnEvent", installErrorWatcher)
end

-- Drop the generic "UI Error: an interface error occured. Click here..." chat
-- line (a direct AddMessage carrying a |Huierror|h link) ONLY when the matching
-- error was the benign 3481 assert. Toggled by "Hide UI Error Messages" (/cc),
-- default on. Real errors keep their notification, so they're not missed.
Module.OnAddMessage = function(self, chatFrame, msg, r, g, b, chatID, ...)
	if (not ns.db) or (not ns.db.hideUIErrors) then return end
	if (not msg) then return end
	if (not lastErrorWas3481) then return end

	if (string_find(msg, "Huierror", 1, true)) or (string_find(msg, "an interface error occ", 1, true)) then
		return true
	end
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

local onAddMessageProxy = function(...)
	return Module:OnAddMessage(...)
end

Module.OnEnable = function(self)
	self:RegisterBlacklistFilter(onAddMessageProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_COMBAT_MISC_INFO", onChatEventProxy)
end

Module.OnDisable = function(self)
	self:UnregisterBlacklistFilter(onAddMessageProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_COMBAT_MISC_INFO", onChatEventProxy)
end
