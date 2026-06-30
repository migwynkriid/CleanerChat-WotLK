local _, ns = ...

local Module = ns:NewModule("Auctions")

-- GLOBALS: hooksecurefunc, StartAuction, GetAuctionSellItemInfo
-- GLOBALS: ITEM_QUALITY_COLORS, ClickAuctionSellItemButton

-- Lua API
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match

-- WoW Globals
local G = {
	AUCTION_REMOVED = ERR_AUCTION_REMOVED, -- "Auction cancelled."
	AUCTION_SOLD = ERR_AUCTION_SOLD_S, -- "A buyer has been found for your auction of %s."
	AUCTION_STARTED = ERR_AUCTION_STARTED, -- "Auction created."
	AUCTION_WON = string_gsub(ERR_AUCTION_WON_S or "You won an auction for %s", "%.$", ""), -- "You won an auction for %s"
	BID_PLACED = ERR_AUCTION_BID_PLACED or "Bid accepted.", -- "Bid accepted."
	AUCTIONS = AUCTIONS, -- "Auctions"
}

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

-- Auctions don't carry item info in their "Auction created." system message, so
-- we cache the item from the sell slot (placed via ClickAuctionSellItemButton,
-- before StartAuction can clear it) plus the per-stack quantity (StartAuction's
-- arg), then attach them to the "Auction created." line when it fires.
Module.CacheSellItem = function(self)
	local name, _, count, quality = GetAuctionSellItemInfo()
	if not name then
		return
	end

	-- Best-effort quality colouring (3.3.5 has no sell-slot item-link API).
	local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	self.sellItem = (color and color.hex or "") .. name .. "|r"
	self.sellCount = count or 1
end

Module.BuildAuctionLine = function(self)
	local item = self.sellItem
	if not item then
		return ns.out.auction_created_generic
	end

	local quantity = self.postQuantity or self.sellCount or 1
	if quantity > 1 then
		return string_format(ns.out.auction_created_multiple, item, quantity)
	end
	return string_format(ns.out.auction_created_single, item)
end

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	if ns:IsProtectedMessage(message) then
		return
	end

	-- Auction created. Replace the generic system line with a detailed
	-- "+ Auction created: <item> x<qty>" line (item cached from the sell slot).
	if message == G.AUCTION_STARTED then
		return false, self:BuildAuctionLine(), author, ...

	-- Auction cancelled. Show it immediately, per cancellation.
	elseif message == G.AUCTION_REMOVED then
		return false, ns.out.auction_canceled_single, author, ...

	-- Bid accepted (you placed a bid).
	elseif message == G.BID_PLACED then
		return false, ns.out.auction_bid, author, ...
	end

	-- Auction sold (a buyer was found for your auction).
	local item = string_match(message, P[G.AUCTION_SOLD])
	if item then
		return false, string_format(ns.out.auction_sold, item), author, ...
	end

	-- Auction won (you bought/won an item).
	local won = string_match(message, P[G.AUCTION_WON])
	if won then
		return false, string_format(ns.out.auction_won, won), author, ...
	end
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

Module.OnEnable = function(self)
	-- Cache the item (before StartAuction clears the slot) + the per-stack
	-- quantity so the "Auction created." line can show what was listed.
	if not self.auctionHooked then
		self.auctionHooked = true
		hooksecurefunc("ClickAuctionSellItemButton", function()
			if Module:IsEnabled() then
				Module:CacheSellItem()
			end
		end)
		hooksecurefunc("StartAuction", function(_, _, _, stackSize)
			if Module:IsEnabled() then
				Module:CacheSellItem()
				Module.postQuantity = stackSize
			end
		end)
	end

	self:RegisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
end

Module.OnDisable = function(self)
	self:UnregisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
end
