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

local Module = ns:NewModule("Loot")

-- Addon Localization
local L = LibStub("AceLocale-3.0"):GetLocale((...))

-- GLOBALS: UnitClass
-- GLOBALS: MerchantFrame, ChatTypeInfo, DEFAULT_CHAT_FRAME, ChatFrame1
-- GLOBALS: hooksecurefunc, GetContainerItemLink, GetContainerItemInfo
-- GLOBALS: TakeInboxItem, GetInboxItem, GetInboxItemLink

-- Lua API
local ipairs = ipairs
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_sub = string.sub
local table_insert = table.insert
local table_remove = table.remove
local tonumber = tonumber

-- WoW Globals (keep nil if missing - empty string patterns match everything!)
local G = {

	-- 3.3.5 globals
	HONOR_POINTS = HONOR_POINTS or "Honor Points", -- "Honor Points"
	COMBATLOG_HONORAWARD = COMBATLOG_HONORAWARD, -- "You have been awarded %d honor points."
	COMBATLOG_HONORGAIN  = COMBATLOG_HONORGAIN, -- "%s dies, honorable kill Rank: %s (%d Honor Points)"
	COMBATLOG_HONORGAIN_NO_RANK  = COMBATLOG_HONORGAIN_NO_RANK, -- "%s dies, honorable kill (%d Honor Points)"
	COMBATLOG_ARENAPOINTSAWARD = COMBATLOG_ARENAPOINTSAWARD, -- "You have been awarded %d arena points."

	-- 3.3.5 Quest reward items (no trailing period in Ascension client)
	QUEST_LOG_RECEIVED_ITEM = "Received item: %s", -- Quest reward item message
	QUEST_LOG_RECEIVED_ITEM_MULTIPLE = "Received item: %sx%d", -- Quest reward item message with count
	QUEST_LOG_RECEIVED_COUNT_OF_ITEM = "Received %d of item: %s", -- "Received 125 of item: [Rune of Ascension]"

	-- Loot roll messages (3.3.5) - use globals if available, otherwise hardcode
	LOOT_ROLL_YOU_WON = LOOT_ROLL_YOU_WON, -- "You won: %s"
	LOOT_ROLL_WON = LOOT_ROLL_WON, -- "%s won: %s"
	LOOT_ROLL_PASSED_SELF = LOOT_ROLL_PASSED_SELF, -- "You passed on: %s"
	LOOT_ROLL_PASSED = LOOT_ROLL_PASSED, -- "%s passed on: %s"
	LOOT_ROLL_PASSED_AUTO = LOOT_ROLL_PASSED_AUTO, -- "%s automatically passed on: %s"
	LOOT_ROLL_PASSED_SELF_AUTO = LOOT_ROLL_PASSED_SELF_AUTO, -- "You automatically passed on: %s because you cannot loot that item."
	LOOT_ROLL_GREED_SELF = LOOT_ROLL_GREED_SELF, -- "You have selected Greed for: %s"
	LOOT_ROLL_GREED = LOOT_ROLL_GREED, -- "%s has selected Greed for: %s"
	LOOT_ROLL_NEED_SELF = LOOT_ROLL_NEED_SELF, -- "You have selected Need for: %s"
	LOOT_ROLL_NEED = LOOT_ROLL_NEED, -- "%s has selected Need for: %s"
	LOOT_ROLL_DISENCHANT_SELF = LOOT_ROLL_DISENCHANT_SELF, -- "You have selected Disenchant for: %s"
	LOOT_ROLL_DISENCHANT = LOOT_ROLL_DISENCHANT, -- "%s has selected Disenchant for: %s"
	LOOT_ROLL_ALL_PASSED = LOOT_ROLL_ALL_PASSED, -- "Everyone passed on: %s"
	NEED = NEED or "Need",
	GREED = GREED or "Greed",
	PASS = PASS or "Pass",
	ROLL_DISENCHANT = ROLL_DISENCHANT or "Disenchant"

}

-- Convert a WoW global string to a search pattern
local makePattern = ns.MakePattern

-- Search Pattern Cache.
-- This will generate the pattern on the first lookup.
local P = setmetatable({}, { __index = function(t,k)
	if (k == nil) or (k == "") then return nil end
	rawset(t,k,makePattern(k))
	return rawget(t,k)
end })

-- Safe pattern match that handles nil patterns
local safeMatch = function(msg, pattern)
	if (not pattern) then return nil end
	return string_match(msg, pattern)
end

Module.OnAddMessage = function(self, chatFrame, msg, r, g, b, chatID, ...)

	-- Not sure any of these Honor entries are parsed, or even needed.

	-- "%s dies, honorable kill Rank: %s (%d Honor Points)"
	if (safeMatch(msg,P[G.COMBATLOG_HONORGAIN])) then
		return true
	end

	-- "%s dies, honorable kill (%d Honor Points)"
	if (safeMatch(msg,P[G.COMBATLOG_HONORGAIN_NO_RANK])) then
		return true
	end

	-- "You have been awarded %d honor points."
	if (safeMatch(msg,P[G.COMBATLOG_HONORAWARD])) then
		return true
	end

	-- "You have been awarded %d arena points."
	if (safeMatch(msg,P[G.COMBATLOG_ARENAPOINTSAWARD])) then
		return true
	end

end

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	if (ns:IsProtectedMessage(message)) then return end

	if (event == "CHAT_MSG_COMBAT_HONOR_GAIN") then
		return true

	elseif (event == "CHAT_MSG_CURRENCY") then
		for i,pattern in ipairs(self.patterns) do

			-- We use the pattern only as an identifier, not for information.
			local item, count = string_match(message,pattern)
			if (item) then
				-- Note: Currencies don't appear to be the same format as this.
				-- The patterns above tend to fail on the number,
				-- so we do this ugly non-localized hack instead.
				-- |cffffffff|Hitem:itemID:::::|h[display name]|h|r
				local first, last = string_find(message, "|c(.+)|r")
				if (first and last) then

					-- Find the actual item name
					local item = string_sub(message, first, last)
					item = string_gsub(item, "[%[/%]]", "") -- kill brackets

					-- Parse our way to the item count
					local countString = string_sub(message, last + 1)
					local count = tonumber(string_match(countString, "(%d+)"))
					if (count) and (count > 1) then
						return false, string_format(ns.out.item_multiple, item, count), author, ...
					else
						return false, string_format(ns.out.item_single, item), author, ...
					end
				end
			end
		end

	elseif (event == "CHAT_MSG_LOOT") then

		-- Handle loot roll messages first
		local item, name, roll

		-- Extract item from message (colored item link)
		local extractItem = function(msg)
			local first, last = string_find(msg, "|c%x%x%x%x%x%x%x%x|Hitem.-%]|h|r")
			if (first and last) then
				local itemLink = string_sub(msg, first, last)
				return string_gsub(itemLink, "[%[/%]]", "") -- kill brackets
			end
			return nil
		end

		-- "You won: %s"
		item = safeMatch(message, P[G.LOOT_ROLL_YOU_WON])
		if (item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_won_self, item), author, ...
		end

		-- "%s won: %s"
		name, item = safeMatch(message, P[G.LOOT_ROLL_WON])
		if (name and item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_won_other, name, item), author, ...
		end

		-- "You have selected Need for: %s"
		item = safeMatch(message, P[G.LOOT_ROLL_NEED_SELF])
		if (item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_need_self, item), author, ...
		end

		-- "%s has selected Need for: %s"
		name, item = safeMatch(message, P[G.LOOT_ROLL_NEED])
		if (name and item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_need_other, name, item), author, ...
		end

		-- "You have selected Greed for: %s"
		item = safeMatch(message, P[G.LOOT_ROLL_GREED_SELF])
		if (item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_greed_self, item), author, ...
		end

		-- "%s has selected Greed for: %s"
		name, item = safeMatch(message, P[G.LOOT_ROLL_GREED])
		if (name and item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_greed_other, name, item), author, ...
		end

		-- "You have selected Disenchant for: %s"
		item = safeMatch(message, P[G.LOOT_ROLL_DISENCHANT_SELF])
		if (item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_de_self, item), author, ...
		end

		-- "%s has selected Disenchant for: %s"
		name, item = safeMatch(message, P[G.LOOT_ROLL_DISENCHANT])
		if (name and item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_de_other, name, item), author, ...
		end

		-- "You passed on: %s"
		item = safeMatch(message, P[G.LOOT_ROLL_PASSED_SELF])
		if (item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_pass_self, item), author, ...
		end

		-- "%s passed on: %s"
		name, item = safeMatch(message, P[G.LOOT_ROLL_PASSED])
		if (name and item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_pass_other, name, item), author, ...
		end

		-- "You automatically passed on: %s"
		item = safeMatch(message, P[G.LOOT_ROLL_PASSED_SELF_AUTO])
		if (item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_pass_self, item), author, ...
		end

		-- "%s automatically passed on: %s"
		name, item = safeMatch(message, P[G.LOOT_ROLL_PASSED_AUTO])
		if (name and item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_pass_other, name, item), author, ...
		end

		-- "Need Roll - %d for %s by %s" (hyphen must be escaped in Lua patterns)
		roll, item, name = string_match(message, "Need Roll %- (%d+) for (.+) by (.+)")
		if (roll and item and name) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_result_need, tonumber(roll), name, item), author, ...
		end

		-- "Greed Roll - %d for %s by %s"
		roll, item, name = string_match(message, "Greed Roll %- (%d+) for (.+) by (.+)")
		if (roll and item and name) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_result_greed, tonumber(roll), name, item), author, ...
		end

		-- "Disenchant Roll - %d for %s by %s"
		roll, item, name = string_match(message, "Disenchant Roll %- (%d+) for (.+) by (.+)")
		if (roll and item and name) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_result_de, tonumber(roll), name, item), author, ...
		end

		-- "Everyone passed on: %s"
		item = safeMatch(message, P[G.LOOT_ROLL_ALL_PASSED])
		if (item) then
			item = string_gsub(item, "[%[/%]]", "")
			return false, string_format(ns.out.roll_all_passed, item), author, ...
		end

		-- Handle regular loot patterns
		for i,pattern in ipairs(self.patterns) do

			-- We use the pattern only as an identifier, not for information.
			local results = { string_match(message,pattern) }
			if (#results > 0) then

				local item, count, name
				for i,j in ipairs(results) do
					local k = tonumber(j)
					if (k) then
						table_remove(results,i)
						count = k
						break
					end
				end

				if (#results == 2) then
					for i,j in ipairs(results) do
						if (string_find(j, "|c%x%x%x%x%x%x%x%x|Hitem")) then
							item = table_remove(results,i)
							item = string_gsub(item, "[%[/%]]", "") -- kill brackets
							break
						end
					end
					name = string_gsub(results[1], "[%[/%]]", "")

				elseif (#results == 1) then
					item = string_gsub(results[1], "[%[/%]]", "") -- kill brackets
				end

				if (item) then
					if (count) and (count > 1) then
						if (name) then
							return false, string_format(ns.out.item_multiple_other, name, item, count), author, ...
						else
							return false, string_format(ns.out.item_multiple, item, count), author, ...
						end
					else
						if (name) then
							return false, string_format(ns.out.item_single_other, name, item), author, ...
						else
							return false, string_format(ns.out.item_single, item), author, ...
						end
					end
				end

			end
		end

	elseif (event == "CHAT_MSG_SYSTEM") then

		-- 3.3.5 / Ascension quest rewards are announced TWICE: once as a real
		-- CHAT_MSG_LOOT ("You receive item/currency...") and once as this
		-- CHAT_MSG_SYSTEM echo ("Received N of item: [X].").  We suppress the
		-- system echo so each reward only shows once. The CHAT_MSG_LOOT copy
		-- (cleaner, no trailing period) is the one kept, and normal looting -
		-- which only ever fires CHAT_MSG_LOOT - is unaffected.

		-- "Received 125 of item: [Item Name]"
		local count, item = safeMatch(message, P[G.QUEST_LOG_RECEIVED_COUNT_OF_ITEM])
		if (count and item) then
			return true
		end

		-- "Received item: [Item Name]x5"
		item, count = safeMatch(message, P[G.QUEST_LOG_RECEIVED_ITEM_MULTIPLE])
		if (item) then
			return true
		end

		item = safeMatch(message, P[G.QUEST_LOG_RECEIVED_ITEM])
		if (item) then
			return true
		end

	end
end

Module.OnInitialize = function(self)
	self.patterns = {}

	for i,global in ipairs({

		-- These all return item,
		-- and optionally an item count.
		"LOOT_ITEM_CREATED_SELF_MULTIPLE", 			-- "You create: %sx%d."
		"LOOT_ITEM_CREATED_SELF", 					-- "You create: %s."
		"LOOT_ITEM_SELF_MULTIPLE", 					-- "You receive loot: %sx%d."
		"LOOT_ITEM_SELF", 							-- "You receive loot: %s."
		"LOOT_ITEM_PUSHED_SELF_MULTIPLE", 			-- "You receive item: %sx%d."
		"LOOT_ITEM_PUSHED_SELF", 					-- "You receive item: %s."
		"LOOT_ITEM_REFUND", 						-- "You are refunded: %s."
		"LOOT_ITEM_REFUND_MULTIPLE", 				-- "You are refunded: %sx%d."
		"CURRENCY_GAINED", 							-- "You receive currency: %s."
		"CURRENCY_GAINED_MULTIPLE", 				-- "You receive currency: %s x%d."
		"CURRENCY_GAINED_MULTIPLE_BONUS", 			-- "You receive currency: %s x%d. (Bonus Objective)" -- Redundant?

		-- These apply to other players and will include player NAMES, not always links.
		-- but should hopefully still work as identifiers for the messages. Needs testing.
		"LOOT_ITEM", 								-- "%s receives loot: %s."
		"LOOT_ITEM_BONUS_ROLL", 					-- "%s receives bonus loot: %s."
		"LOOT_ITEM_BONUS_ROLL_MULTIPLE", 			-- "%s receives bonus loot: %sx%d."
		"LOOT_ITEM_MULTIPLE", 						-- "%s receives loot: %sx%d."
		"LOOT_ITEM_PUSHED", 						-- "%s receives item: %s."
		"LOOT_ITEM_PUSHED_MULTIPLE", 				-- "%s receives item: %sx%d."

		-- Don't filter these here,
		-- they are pure text for both names and items!
		--"CREATED_ITEM", 							-- "%s creates: %s."
		--"CREATED_ITEM_MULTIPLE", 					-- "%s creates: %sx%d."

	}) do
		-- Always check if the global exists,
		-- as a lot of these strings and filters
		-- do not apply to the classic clients.
		local msg = _G[global]
		if (msg) then
			table_insert(self.patterns, makePattern(msg))
		end
	end

	-- Add hardcoded patterns for 3.3.5 quest reward messages
	-- These use "Received item:" instead of "You receive item:"
	table_insert(self.patterns, makePattern(G.QUEST_LOG_RECEIVED_ITEM))
	table_insert(self.patterns, makePattern(G.QUEST_LOG_RECEIVED_ITEM_MULTIPLE))
	table_insert(self.patterns, makePattern(G.QUEST_LOG_RECEIVED_COUNT_OF_ITEM))

end

-- Selling an item to a vendor generates no chat message of its own -- only the
-- coin gain -- so the bag side of the trade was invisible. Buying shows
-- "+ item" / "- money", but selling only showed "+ money". Mirror it: emit a
-- matching "- item" deficit line when the player sells.
Module.ReportItemSold = function(self, link, count)
	if (not link) then return end

	-- Match the loot styling: strip the [] from the link (keeps the |H..|h
	-- hyperlink + quality colour so the line stays clickable and coloured).
	local item = string_gsub(link, "[%[/%]]", "")

	local msg
	if (count and count > 1) then
		msg = string_format(ns.out.item_deficit_multiple, item, count)
	else
		msg = string_format(ns.out.item_deficit, item)
	end

	local info = ChatTypeInfo and ChatTypeInfo["LOOT"]
	local r = info and info.r or 1
	local g = info and info.g or 1
	local b = info and info.b or 1

	local chatFrame = DEFAULT_CHAT_FRAME or ChatFrame1
	if (chatFrame) and (chatFrame.AddMessage) then
		chatFrame:AddMessage(msg, r, g, b)
	end
end

-- Taking an item from the mailbox is silent on 3.3.5 (no loot chat message),
-- so the "+ item" line you get from looting never appeared for mail. Hook the
-- mail-take function and emit a matching "+ item" line. The cached attachment
-- is still readable in the post-hook (not cleared until the server's
-- MAIL_INBOX_UPDATE), so we read it there.
Module.ReportMailItem = function(self, mailID, attachIndex)
	local link = GetInboxItemLink and GetInboxItemLink(mailID, attachIndex)
	if (not link) then return end

	local _, _, count = GetInboxItem(mailID, attachIndex)

	-- Strip the [] from the link (keeps the |H hyperlink + quality colour).
	local item = string_gsub(link, "[%[/%]]", "")

	local msg
	if (count and count > 1) then
		msg = string_format(ns.out.item_multiple, item, count)
	else
		msg = string_format(ns.out.item_single, item)
	end

	local info = ChatTypeInfo and ChatTypeInfo["LOOT"]
	local r = info and info.r or 1
	local g = info and info.g or 1
	local b = info and info.b or 1

	local chatFrame = DEFAULT_CHAT_FRAME or ChatFrame1
	if (chatFrame) and (chatFrame.AddMessage) then
		chatFrame:AddMessage(msg, r, g, b)
	end
end

local onAddMessageProxy = function(...)
	return Module:OnAddMessage(...)
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

Module.OnEnable = function(self)
	self:RegisterBlacklistFilter(onAddMessageProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_COMBAT_HONOR_GAIN", onChatEventProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_CURRENCY", onChatEventProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_LOOT", onChatEventProxy)
	self:RegisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)

	-- Track vendor sales so they show a "- item" line (see ReportItemSold).
	-- Right-clicking a bag item while the merchant window is open sells it.
	-- We use hooksecurefunc (a SECURE post-hook) -- NOT a replacement of the
	-- global UseContainerItem, which would taint the secure function and break
	-- using items ("AddOn tainted the call of the secure function"). The item
	-- removal is server-confirmed (async), so the item is still in the slot
	-- during the post-hook; we capture it there, then poll to confirm the sale.
	if (not self.merchantHooked) then
		self.merchantHooked = true
		hooksecurefunc("UseContainerItem", function(bag, slot)
			if not Module:IsEnabled() then return end
			if not MerchantFrame or not MerchantFrame:IsShown() then return end

			-- Capture the item (still present -- removal is async).
			local link = GetContainerItemLink(bag, slot)
			if not link then return end
			local _, countBefore = GetContainerItemInfo(bag, slot)
			countBefore = countBefore or 1

			-- The server confirms the item removal asynchronously and latency
			-- varies, so a single fixed delay is unreliable (it often checks
			-- before the bag updates, sees the item still there, and reports
			-- nothing). Instead POLL the slot until it changes, then report.
			-- If after ~1s it never changed, the vendor rejected the item
			-- (unsellable) so we report nothing -- no false positive.
			if C_Timer and C_Timer.After then
				local attempts = 0
				local function check()
					attempts = attempts + 1
					local linkAfter = GetContainerItemLink(bag, slot)
					local _, countAfter = GetContainerItemInfo(bag, slot)
					countAfter = countAfter or 0

					if not linkAfter then
						-- Slot empty = sold the whole stack
						Module:ReportItemSold(link, countBefore)
					elseif linkAfter == link and countAfter < countBefore then
						-- Same item, fewer of them = sold part of the stack
						Module:ReportItemSold(link, countBefore - countAfter)
					elseif attempts < 12 then
						-- Bag not updated yet, keep polling
						C_Timer.After(0.1, check)
					end
				end
				C_Timer.After(0.05, check)
			else
				-- No timer available: report immediately
				Module:ReportItemSold(link, countBefore)
			end
		end)
	end

	-- Taking items from the mailbox is silent on 3.3.5, so hook the mail-take
	-- function and emit a "+ item" line (see ReportMailItem). Covers the default
	-- mail UI -- clicking an attachment calls TakeInboxItem. hooksecurefunc = no
	-- taint; the attachment is still readable in the post-hook.
	if (not self.mailHooked) then
		self.mailHooked = true
		hooksecurefunc("TakeInboxItem", function(mailID, attachIndex)
			if (Module:IsEnabled()) then
				Module:ReportMailItem(mailID, attachIndex)
			end
		end)
	end
end

Module.OnDisable = function(self)
	self:UnregisterBlacklistFilter(onAddMessageProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_COMBAT_HONOR_GAIN", onChatEventProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_CURRENCY", onChatEventProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_LOOT", onChatEventProxy)
	self:UnregisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
end
