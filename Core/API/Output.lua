local _, ns = ...

-- Lua API
local _G = _G
local ipairs = ipairs
local rawset = rawset
local setmetatable = setmetatable
local string_gsub = string.gsub
local unpack = unpack

-- WoW Global Strings
local AUCTION_SOLD_MAIL = _G.AUCTION_SOLD_MAIL_SUBJECT -- "Auction successful: %s"
local AUCTION_CREATED = string_gsub(_G.ERR_AUCTION_STARTED, "%.", "") -- "Auction created."
local AUCTION_REMOVED = string_gsub(_G.ERR_AUCTION_REMOVED, "%.", "") -- "Auction cancelled."
local AUCTION_BID = string_gsub(_G.ERR_AUCTION_BID_PLACED or "Bid accepted.", "%.", "") -- "Bid accepted"
local AWAY = _G.FRIENDS_LIST_AWAY -- "Away"
local BUSY = _G.FRIENDS_LIST_BUSY -- "Busy"
local COMPLETE = _G.COMPLETE -- "Complete"
local RESTED = _G.TUTORIAL_TITLE26 -- "Rested"

-- Private API
-- Note: Colors should exist after Common/Colors.lua loads
local Colors = ns.Private and ns.Private.Colors

-- Output patterns.
-- *uses a simple color tag system for new strings.
ns.out = setmetatable(ns.out or {}, { __newindex = function(t,k,msg)

	-- Get colors safely (Colors may be nil if loaded out of order)
	local colors = Colors or (ns.Private and ns.Private.Colors)
	if (not colors) then
		-- Fallback: just strip color tags if no colors available
		msg = string_gsub(msg, "%*%w+%*", "")
		msg = string_gsub(msg, "%*%*", "")
		rawset(t,k,msg)
		return
	end

	-- Have to do this with an indexed table,
	-- as the order of the entires matters.
	for _,entry in ipairs({
		{ "%*title%*", 		colors.title.colorCode },
		{ "%*white%*", 		colors.highlight.colorCode },
		{ "%*offwhite%*", 	colors.offwhite.colorCode },
		{ "%*palered%*", 	colors.palered.colorCode },
		{ "%*red%*", 		colors.quest.red.colorCode },
		{ "%*darkorange%*", colors.quality.Legendary.colorCode },
		{ "%*orange%*", 	colors.quest.orange.colorCode },
		{ "%*yellow%*", 	colors.quest.yellow.colorCode },
		{ "%*green%*", 		colors.quest.green.colorCode },
		{ "%*gray%*", 		colors.quest.gray.colorCode },
		{ "%*%*", "|r" } -- Always keep this at the end.
	}) do
		msg = string_gsub(msg, unpack(entry))
	end
	rawset(t,k,msg)
end })

local out = ns.out

-- Local templates
local plus = "*green*+** %s"
local plus_yellow = "*green*+** *white*%s:** *yellow*%s**"

-- Output formats used in the modules.
-- *everything should be gathered here, in this file.
out.achievement = "%s: %s"
out.afk_added = "*orange*+ "..AWAY.."**"
out.afk_added_message = "*orange*+ "..AWAY..": ***white*%s**"
out.afk_cleared = "*green*- "..AWAY.."**"
out.auction_sold = "*green*"..string_gsub(AUCTION_SOLD_MAIL, "%%s", "*white*%%s**").."**"
out.auction_created_single = "*green*+** *white*"..AUCTION_CREATED..":** %s"
out.auction_created_multiple = "*green*+** *white*"..AUCTION_CREATED..":** %s *offwhite*x%d**"
out.auction_created_generic = "*green*+** *white*"..AUCTION_CREATED.."**"
out.auction_canceled_single = "*palered*- "..AUCTION_REMOVED.."**"
out.auction_won = "*green*+** *white*Won:** %s"
out.auction_bid = "*green*+** *white*"..AUCTION_BID.."**"
out.dnd_added = "*darkorange*+ "..BUSY.."**"
out.dnd_added_message = "*darkorange*+ "..BUSY..": ***white*%s**"
out.dnd_cleared = "*green*- "..BUSY.."**"
out.item_single = plus
out.item_multiple = "*green*+** %s *offwhite*(%d)**"
out.item_single_other = "%s*gray*:** %s"
out.item_multiple_other = "%s*gray*:** %s *offwhite*(%d)**"
out.craft_single_other = '%s *gray*created:** %s'
out.craft_multiple_other = '%s *gray*created:** %s *offwhite*(%d)**'
out.item_deficit = "*red*- %s**"
out.item_deficit_multiple = "*red*- %s** *offwhite*(%d)**"
out.money = plus
out.money_deficit = "*gray*-** %s"
out.objective_status = plus_yellow
out.quest_accepted = plus_yellow
out.quest_complete = plus_yellow
out.rested_added = "*green*+** *gray*"..RESTED.."**"
out.rested_cleared = "*orange*- "..RESTED.."**"
out.set_complete = plus_yellow
out.standing = "*green*+** *white*".."%d** *white*%s:** %s"
out.standing_generic = "*green*+** *gray*%s:** %s"
out.standing_deficit = "*red*-** *white*".."%d** *white*%s:** %s"
out.standing_deficit_generic = "*red*-** *palered** %s:** %s"
out.xp_levelup = "%s"
out.xp_named = "*green*+** *white*%d** *white*%s:** *yellow*%s**"
out.xp_unnamed = "*green*+** *white*%d** *white*%s**"

-- Loot roll outputs
out.roll_won_self = "*green*Won:** %s"
out.roll_won_other = "%s *green*Won:** %s"
out.roll_need_self = "*yellow*Need:** %s"
out.roll_need_other = "%s *yellow*Need:** %s"
out.roll_greed_self = "*green*Greed:** %s"
out.roll_greed_other = "%s *green*Greed:** %s"
out.roll_de_self = "*darkorange*DE:** %s"
out.roll_de_other = "%s *darkorange*DE:** %s"
out.roll_pass_self = "*gray*Pass:** %s"
out.roll_pass_other = "%s *gray*Pass:** %s"
out.roll_result_need = "*yellow*%d** *yellow*Need** *white*%s** %s"
out.roll_result_greed = "*green*%d** *green*Greed** *white*%s** %s"
out.roll_result_de = "*darkorange*%d** *darkorange*DE** *white*%s** %s"
out.roll_all_passed = "*gray*All Passed:** %s"

-- Level up outputs (3.3.5)
out.levelup_ding = "*yellow*Level %d**"
out.levelup_hp = "*green*+** *white*%d** *green*HP**"
out.levelup_stat = "*green*+** *white*%d** *green*%s**"
out.levelup_essence = "*green*+** *darkorange*Unspent Talent Essence**"

-- PvP currency outputs (Ascension)
out.arena_points = "*green*+** *white*%d** *green*Arena Points**"
out.arena_points_status = "*gray*Current:** *white*%d** *gray*/ %d**"
out.glory = "*green*+** *white*%d** *yellow*Glory**"
out.glory_progress = "*gray*%d Glory needed to reach the next rank**"
