--[[

	The MIT License (MIT)

	Copyright (c) 2024 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local Addon, ns = ...

local Module = ns:NewModule("Blacklist")

-- Addon Localization
local L = LibStub("AceLocale-3.0"):GetLocale((...))

-- Build blacklist table safely (some globals may be nil in 3.3.5)
local B = {}
if ERR_NOT_IN_INSTANCE_GROUP then B[ERR_NOT_IN_INSTANCE_GROUP] = true end
if ERR_NOT_IN_RAID then B[ERR_NOT_IN_RAID] = true end
if ERR_QUEST_ALREADY_ON then B[ERR_QUEST_ALREADY_ON] = true end
Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	if (B[message]) then
		-- These problems mostly occur in battlegrounds and other PvP.
		return IsInInstance()
	end
end

Module.OnEnable = function(self)
	self:RegisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
end

Module.OnDisable = function(self)
	self:UnregisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
end
