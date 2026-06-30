local _, ns = ...

local Module = ns:NewModule("Money", "LibMoreEvents-1.0")

-- GLOBALS: ChatTypeInfo, GetMoney
-- GLOBALS: AuctionFrame, ClassTrainerFrame, LootFrame, MailFrame, MerchantFrame
-- Lua API
local math_abs = math.abs
local math_floor = math.floor
local math_mod = math.fmod
local setmetatable = setmetatable
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local tonumber = tonumber

-- WoW Globals (some may be nil in older clients like 3.3.5)
local G = {
	GOLD_AMOUNT = GOLD_AMOUNT,
	GOLD_AMOUNT_SYMBOL = GOLD_AMOUNT_SYMBOL,
	SILVER_AMOUNT = SILVER_AMOUNT,
	SILVER_AMOUNT_SYMBOL = SILVER_AMOUNT_SYMBOL,
	COPPER_AMOUNT = COPPER_AMOUNT,
	COPPER_AMOUNT_SYMBOL = COPPER_AMOUNT_SYMBOL,
	LARGE_NUMBER_SEPERATOR = LARGE_NUMBER_SEPERATOR or ",",
}

-- Return a coin texture string.
-- Uses custom coins.tga atlas (64x64 with 4 quadrants: TL=gold, TR=silver, BL=copper, BR=empty)
local COINS_TEXTURE = [[Interface\AddOns\CleanerChat\Assets\coins]]
local Coin = setmetatable({}, {
	__index = function(t, k)
		local frame = DEFAULT_CHAT_FRAME or ChatFrame1
		local _, fontHeight = frame:GetFont()

		fontHeight = fontHeight or 14
		-- Scale icon larger than font (1.6x) for better visibility
		local size = math_floor(fontHeight * 1.6)
		if size < 12 then
			size = 12
		end

		-- Use custom coins.tga texture atlas (64x64 with 4 quadrants, 32x32 each)
		-- Format: |Tpath:height:width:xOffset:yOffset:texWidth:texHeight:left:right:top:bottom|t
		-- Texture coordinates in pixels: left, right, top, bottom
		if k == "Gold" then
			-- Top-left quadrant: 0-32, 0-32
			return string_format([[|T%s:%d:%d:0:0:64:64:0:32:0:32|t]], COINS_TEXTURE, size, size)
		elseif k == "Silver" then
			-- Top-right quadrant: 32-64, 0-32
			return string_format([[|T%s:%d:%d:0:0:64:64:32:64:0:32|t]], COINS_TEXTURE, size, size)
		elseif k == "Copper" then
			-- Bottom-left quadrant: 0-32, 32-64
			return string_format([[|T%s:%d:%d:0:0:64:64:0:32:32:64|t]], COINS_TEXTURE, size, size)
		end
	end,
})

-- Search Pattern Cache (self-populating via ns.MakePattern on first lookup).
local P = ns.MakePatternCache()

-- Remove large number formatting
local simplifyNumbers = function(message)
	if G.LARGE_NUMBER_SEPERATOR and G.LARGE_NUMBER_SEPERATOR ~= "" then
		return string_gsub(message or "", "(%d)%" .. G.LARGE_NUMBER_SEPERATOR .. "(%d)", "%1%2")
	else
		return message or ""
	end
end

-- Add pretty spacing to large numbers using spaces as the thousands separator.
local prettify = function(value)
	if value >= 1e9 then
		local billions = math_floor(value / 1e9)
		local millions = math_floor((value - billions * 1e9) / 1e6)
		local thousands = math_floor((value - billions * 1e9 - millions * 1e6) / 1e3)
		local remainder = math_mod(value, 1e3)

		return string_format("%d %03d %03d %03d", billions, millions, thousands, remainder)
	elseif value >= 1e6 then
		local millions = math_floor(value / 1e6)
		local thousands = math_floor((value - millions * 1e6) / 1e3)
		local remainder = math_mod(value, 1e3)

		return string_format("%d %03d %03d", millions, thousands, remainder)
	elseif value >= 1e3 then
		local thousands = math_floor(value / 1e3)
		local remainder = math_mod(value, 1e3)

		return string_format("%d %03d", thousands, remainder)
	else
		return value .. ""
	end
end

local formatMoney = function(gold, silver, copper, colorCode)
	colorCode = colorCode or "|cfff0f0f0"
	local parts = {}
	if gold and gold > 0 then
		local goldStr = (ns.db == nil or ns.db.moneyPrettify) and prettify(gold) or tostring(gold)
		parts[#parts + 1] = string_format("%s%s|r%s", colorCode, goldStr, Coin["Gold"])
	end
	if silver and silver > 0 then
		parts[#parts + 1] = string_format("%s%d|r%s", colorCode, silver, Coin["Silver"])
	end
	if copper and copper > 0 then
		parts[#parts + 1] = string_format("%s%d|r%s", colorCode, copper, Coin["Copper"])
	end
	-- Fallback if all values are 0
	if #parts == 0 then
		return colorCode .. "0|r" .. Coin["Copper"]
	end
	-- Add space after each icon except the last one when there are multiple currencies
	if #parts > 1 then
		for i = 1, #parts - 1 do
			parts[i] = parts[i] .. " "
		end
	end
	return table.concat(parts)
end

local parseForMoney = function(message)
	-- Remove large number formatting
	message = simplifyNumbers(message)

	-- Basic old-style parsing first.
	-- Doing it in two steps to limit number of needed function calls.
	local gold = string_match(message, P[G.GOLD_AMOUNT]) -- "%d Gold"
	local gold_amount = gold and tonumber(gold) or 0

	local silver = string_match(message, P[G.SILVER_AMOUNT]) -- "%d Silver"
	local silver_amount = silver and tonumber(silver) or 0

	local copper = string_match(message, P[G.COPPER_AMOUNT]) -- "%d Copper"
	local copper_amount = copper and tonumber(copper) or 0

	-- Otherwise, fall back to parsing coin icons / colorblind symbols.
	if (gold_amount == 0) and (silver_amount == 0) and (copper_amount == 0) then
		-- Detect which coin types are present (icon or colorblind symbol).
		local hasGold, hasSilver, hasCopper
		if _G.ENABLE_COLORBLIND_MODE == "1" then
			hasGold = string_find(message, "%d" .. G.GOLD_AMOUNT_SYMBOL)
			hasSilver = string_find(message, "%d" .. G.SILVER_AMOUNT_SYMBOL)
			hasCopper = string_find(message, "%d" .. G.COPPER_AMOUNT_SYMBOL)
		else
			hasGold = string_find(message, "(UI%-GoldIcon)")
			hasSilver = string_find(message, "(UI%-SilverIcon)")
			hasCopper = string_find(message, "(UI%-CopperIcon)")
		end

		-- These patterns should work for both coins and symbols. Let's parse!
		if hasGold or hasSilver or hasCopper then
			-- Now kill off texture strings, replace with space for number separation.
			message = string_gsub(message, "\124T(.-)\124t", " ")

			-- Strip color codes so they don't interfere with number parsing.
			message = string_gsub(message, "\124[cC]%x%x%x%x%x%x%x%x", "")
			message = string_gsub(message, "\124[rR]", "")

			-- Parse each present coin type explicitly to minimize function calls.
			if hasGold then
				if hasSilver and hasCopper then
					gold_amount, silver_amount, copper_amount = string_match(message, "(%d+).*%s+(%d+).*%s+(%d+).*")
					return tonumber(gold_amount) or 0, tonumber(silver_amount) or 0, tonumber(copper_amount) or 0
				elseif hasSilver then
					gold_amount, silver_amount = string_match(message, "(%d+).*%s+(%d+).*")
					return tonumber(gold_amount) or 0, tonumber(silver_amount) or 0, 0
				elseif hasCopper then
					gold_amount, copper_amount = string_match(message, "(%d+).*%s+(%d+).*")
					return tonumber(gold_amount), 0, tonumber(copper_amount) or 0
				else
					gold_amount = string_match(message, "(%d+).*%s")
					return tonumber(gold_amount) or 0, 0, 0
				end
			elseif hasSilver then
				if hasCopper then
					silver_amount, copper_amount = string_match(message, "(%d+).*%s+(%d+).*")
					return 0, tonumber(silver_amount) or 0, tonumber(copper_amount) or 0
				else
					silver_amount = string_match(message, "(%d+).*%s")
					return 0, tonumber(silver_amount) or 0, 0
				end
			elseif hasCopper then
				copper_amount = string_match(message, "(%d+).*%s")
				return 0, 0, tonumber(copper_amount) or 0
			end
		end
	end

	return gold_amount, silver_amount, copper_amount
end

Module.OnAddMessage = function(self, chatFrame, msg, r, g, b, chatID, ...)
	-- If prettify is disabled, let all money messages through unchanged.
	if (ns.db ~= nil) and not ns.db.moneyPrettify then
		return
	end

	-- Don't blacklist the clean money line we emit ourselves -- it carries coin
	-- icons too, so it would otherwise match here and get dropped.
	if self.emittingOwnMessage then
		return
	end

	local gold, silver, copper = parseForMoney(msg)
	if gold + silver + copper > 0 then
		return true
	end
end

Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
	if event == "CHAT_MSG_MONEY" then
		-- If prettify is disabled, let the default message through.
		if (ns.db ~= nil) and not ns.db.moneyPrettify then
			return
		end
		-- We always hide this when this filter is active,
		-- so no need for any checks of any sort here.
		return true
	end
end

-- Output our own clean money line.
-- This has to reach every display layer, including the Glass chat UI, which
-- renders through a post-hook on the frame's AddMessage. The previous code
-- called the *cached original* AddMessage to dodge our money blacklist -- but
-- that bypasses Glass, and since Glass hides the native chat frame the money
-- line ended up invisible. Instead we call the public AddMessage (so Glass sees
-- it) and set a guard flag so our own blacklist filter lets this one line pass.
Module.AddMessage = function(self, msg, r, g, b, chatID, ...)
	if (not msg) or (msg == "") then
		return
	end

	local chatFrame = DEFAULT_CHAT_FRAME or ChatFrame1
	if (not chatFrame) or not chatFrame.AddMessage then
		print(msg)
		return
	end

	self.emittingOwnMessage = true
	-- pcall so a rendering error can never leave the guard flag stuck on, which
	-- would silently disable money filtering for every later message.
	local ok = pcall(chatFrame.AddMessage, chatFrame, msg, r, g, b)
	self.emittingOwnMessage = false

	if not ok then
		print(msg)
	end
end

Module.OnEvent = function(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		self.playerMoney = GetMoney()
	elseif event == "LOOT_OPENED" then
		-- Track that we're actively looting
		self.isLooting = true
	elseif event == "LOOT_CLOSED" then
		-- Track when loot closed so we can catch money events that fire slightly after
		self.isLooting = false
		self.lootClosedTime = GetTime()
	elseif event == "PLAYER_MONEY" then
		local currentMoney = GetMoney()

		-- If prettify is disabled, skip our custom output entirely.
		if (ns.db ~= nil) and not ns.db.moneyPrettify then
			self.playerMoney = currentMoney
			return
		end

		-- Money changes are reported immediately as they happen, including while a
		-- vendor/mail/trainer window is open -- buying and selling each fire
		-- PLAYER_MONEY, so each transaction prints its own gain/loss line. We still
		-- suppress the auction house where money moves around (deposits, bids) in
		-- ways that would just be noise. Flight master costs are shown normally.
		local atAuction = (AuctionHouseFrame and AuctionHouseFrame:IsShown())
			or (AuctionFrame and AuctionFrame:IsShown())
		-- Suppress only auction house; flight master payments should be visible
		if atAuction then
			self.playerMoney = currentMoney

			return
		end

		if self.playerMoney then
			local money = currentMoney - self.playerMoney

			if money ~= 0 then
				local value = math_abs(money)
				local g = math_floor(value / 1e4)
				local s = math_floor((value - (g * 1e4)) / 100)
				local c = math_mod(value, 100)

				-- Get chat color info (with fallback)
				local info = ChatTypeInfo and ChatTypeInfo["MONEY"]
				local r = info and info.r or 1
				local gb = info and info.g or 1
				local b = info and info.b or 0

				if money > 0 then
					-- Check if we should buffer for one-line quest rewards.
					-- Skip buffering when vendor/mail/trainer/loot windows are open -- those
					-- are transactions or mob loot, not quest rewards, and should display immediately.
					-- Also skip if we recently looted (within 0.5s) since PLAYER_MONEY can fire after loot frame closes.
					local atVendor = MerchantFrame and MerchantFrame:IsShown()
					local atMail = MailFrame and MailFrame:IsShown()
					local atTrainer = ClassTrainerFrame and ClassTrainerFrame:IsShown()
					local atLoot = self.isLooting or (LootFrame and LootFrame:IsShown())
					local recentlyLooted = self.lootClosedTime and (GetTime() - self.lootClosedTime) < 0.5
					if
						not atVendor
						and not atMail
						and not atTrainer
						and not atLoot
						and not recentlyLooted
						and (ns.db and ns.db.oneLineQuestRewards)
					then
						local chatFrame = DEFAULT_CHAT_FRAME or ChatFrame1
						if chatFrame then
							local moneyText = formatMoney(g, s, c)
							if ns:AddQuestReward(chatFrame, "money", moneyText) then
								self.playerMoney = currentMoney
								return -- Suppress, will be output with combined rewards
							end
						end
					end

					local msg = string_format(ns.out.money, formatMoney(g, s, c))
					self:AddMessage(msg, r, gb, b)
				elseif money < 0 then
					local palered = ns.Colors and ns.Colors.palered and ns.Colors.palered.colorCode or "|cffcc4444"
					local msg = string_format(ns.out.money_deficit, formatMoney(g, s, c, palered))
					self:AddMessage(msg, r, gb, b)
				end
			end
		end

		self.playerMoney = currentMoney
	end
end

local onChatEventProxy = function(...)
	return Module:OnChatEvent(...)
end

local onAddMessageProxy = function(...)
	return Module:OnAddMessage(...)
end

Module.OnEnable = function(self)
	self.playerMoney = GetMoney()
	self.isLooting = false
	self.lootClosedTime = nil

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_MONEY", "OnEvent")
	self:RegisterEvent("LOOT_OPENED", "OnEvent")
	self:RegisterEvent("LOOT_CLOSED", "OnEvent")

	self:RegisterBlacklistFilter(onAddMessageProxy)

	self:RegisterMessageEventFilter("CHAT_MSG_MONEY", onChatEventProxy)
end

Module.OnDisable = function(self)
	self.playerMoney = 0
	self.isLooting = false
	self.lootClosedTime = nil

	self:UnregisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:UnregisterEvent("PLAYER_MONEY", "OnEvent")
	self:UnregisterEvent("LOOT_OPENED", "OnEvent")
	self:UnregisterEvent("LOOT_CLOSED", "OnEvent")

	self:UnregisterBlacklistFilter(onAddMessageProxy)

	self:UnregisterMessageEventFilter("CHAT_MSG_MONEY", onChatEventProxy)
end
