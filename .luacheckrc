-- Luacheck configuration for CleanerChat WoW 3.3.5 addon
-- https://luacheck.readthedocs.io/

-- Lua version
std = "lua51"

-- Maximum line length (disabled - not a style linter)
max_line_length = false

-- Exclude third-party libraries
exclude_files = {
  "Libs/**",
  "APIDocumentation/**",
}

-- Ignore certain warnings globally
ignore = {
  "213",      -- Unused loop variable (common in WoW: for i = 1, count do)
  "542",      -- Empty if branch (sometimes intentional for clarity)
  "611",      -- Line contains only whitespace
  "612",      -- Line contains trailing whitespace
  "614",      -- Trailing whitespace in comment
}

-- Keep unused argument checking ON (we use per-file ignores for callbacks)
self = false

-- WoW Global Environment
-- These are read-only globals provided by the WoW client

read_globals = {
  -- Lua Standard (WoW provides these)
  "_G",
  "assert",
  "collectgarbage",
  "date",
  "debugstack",
  "error",
  "gcinfo",
  "getfenv",
  "getmetatable",
  "ipairs",
  "loadstring",
  "next",
  "pairs",
  "pcall",
  "print",
  "rawequal",
  "rawget",
  "rawset",
  "select",
  "setfenv",
  "setmetatable",
  "time",
  "tonumber",
  "tostring",
  "type",
  "unpack",
  "wipe",
  "xpcall",

  -- String library
  "string",
  "strbyte",
  "strchar",
  "strfind",
  "strformat",
  "strjoin",
  "strlen",
  "strlower",
  "strmatch",
  "strrep",
  "strrev",
  "strsplit",
  "strsub",
  "strtrim",
  "strupper",
  "format",
  "gsub",
  "gmatch",

  -- Table library
  "table",
  "tinsert",
  "tremove",
  "tsort",
  "tconcat",
  "sort",

  -- Math library
  "math",
  "abs",
  "ceil",
  "floor",
  "max",
  "min",
  "mod",
  "sqrt",
  "random",

  -- Bit operations
  "bit",

  -- WoW Frame API
  "CreateFrame",
  "CreateFont",
  "CreateColor",
  "CreateObjectPool",
  "getglobal",
  "setglobal",
  "UIParent",
  "WorldFrame",
  "Minimap",

  -- WoW API - Unit Functions
  "UnitName",
  "UnitClass",
  "UnitRace",
  "UnitLevel",
  "UnitHealth",
  "UnitHealthMax",
  "UnitMana",
  "UnitManaMax",
  "UnitPower",
  "UnitPowerMax",
  "UnitPowerType",
  "UnitExists",
  "UnitIsPlayer",
  "UnitIsUnit",
  "UnitIsDead",
  "UnitIsGhost",
  "UnitIsAFK",
  "UnitIsDND",
  "UnitIsConnected",
  "UnitInRaid",
  "UnitInParty",
  "UnitIsGroupLeader",
  "UnitIsGroupAssistant",
  "UnitOnTaxi",
  "UnitGUID",
  "UnitFactionGroup",
  "UnitInBattleground",
  "GetUnitName",

  -- WoW API - Player Functions
  "GetRealmName",
  "GetPlayerInfoByGUID",
  "GetNumGroupMembers",
  "GetNumPartyMembers",
  "GetNumRaidMembers",
  "GetNumSubgroupMembers",
  "IsInRaid",
  "IsInGroup",
  "IsInGuild",
  "GetGuildInfo",

  -- WoW API - Chat Functions
  "SendAddonMessage",
  "SendChatMessage",
  "GetChatTypeIndex",
  "SetChatColorNameByClass",
  "ChatFrame_AddMessageEventFilter",
  "ChatFrame_RemoveMessageEventFilter",
  "ChatFrame_AddMessageGroup",
  "ChatFrame_RemoveMessageGroup",
  "FCF_GetCurrentChatFrame",
  "FCF_SetWindowName",
  "FCF_DockFrame",
  "FCF_GetChatWindowInfo",
  "GetChatWindowInfo",
  "SetChatWindowShown",
  "FloatingChatFrame_OnLoad",
  "ChatEdit_GetActiveWindow",
  "ChatEdit_ActivateChat",
  "ChatEdit_DeactivateChat",

  -- WoW API - Chat Frames (globals)
  "CHAT_FRAMES",
  "ChatFrame1",
  "ChatFrame2",
  "ChatFrame3",
  "ChatFrame4",
  "ChatFrame5",
  "ChatFrame6",
  "ChatFrame7",
  "ChatFrame8",
  "ChatFrame9",
  "ChatFrame10",
  "DEFAULT_CHAT_FRAME",
  "SELECTED_CHAT_FRAME",
  "GENERAL_CHAT_DOCK",
  "GeneralDockManager",
  "ChatFrame1EditBox",
  "ChatFrameEditBox",

  -- WoW API - Item Functions
  "GetItemInfo",
  "GetItemIcon",
  "GetItemQualityColor",
  "GetContainerItemLink",
  "GetContainerItemInfo",
  "GetContainerNumSlots",
  "GetInboxItem",
  "GetInboxItemLink",
  "TakeInboxItem",
  "GetCursorInfo",
  "DeleteCursorItem",
  "PickupContainerItem",
  "UseContainerItem",

  -- WoW API - Auction Functions
  "StartAuction",
  "GetAuctionSellItemInfo",
  "ClickAuctionSellItemButton",

  -- WoW API - Money Functions
  "GetMoney",
  "GetCoinText",
  "GetCoinTextureString",
  "BreakUpLargeNumbers",

  -- WoW API - Loot Functions
  "GetLootSlotInfo",
  "GetLootSlotLink",
  "GetNumLootItems",
  "LootSlot",
  "CloseLoot",

  -- WoW API - Quest Functions
  "GetNumQuestLogEntries",
  "GetQuestLogTitle",
  "GetQuestLogRewardXP",
  "GetQuestLogRewardMoney",
  "GetNumQuestLogRewards",
  "GetQuestLogRewardInfo",
  "GetNumQuestLogChoices",
  "GetQuestLogChoiceInfo",
  "QuestLogFrame",

  -- WoW API - Reputation Functions
  "GetNumFactions",
  "GetFactionInfo",
  "CollapseFactionHeader",
  "ExpandFactionHeader",
  "SetWatchedFactionIndex",

  -- WoW API - Spell Functions
  "GetSpellInfo",
  "GetSpellLink",
  "GetSpellTexture",

  -- WoW API - Talent Functions
  "GetNumTalentTabs",
  "GetTalentTabInfo",
  "GetNumTalents",
  "GetTalentInfo",

  -- WoW API - Buff/Debuff Functions
  "UnitBuff",
  "UnitDebuff",
  "UnitAura",

  -- WoW API - Combat Log
  "CombatLogGetCurrentEventInfo",
  "CombatLog_Object_IsA",

  -- WoW API - Achievement Functions
  "GetAchievementInfo",
  "GetAchievementLink",
  "GetAchievementCriteriaInfo",
  "GetNumCompletedAchievements",

  -- WoW API - Guild Functions
  "GuildRoster",
  "GetNumGuildMembers",
  "GetGuildRosterInfo",

  -- WoW API - Trade Skill Functions
  "GetTradeSkillLine",
  "GetNumTradeSkills",
  "GetTradeSkillInfo",

  -- WoW API - Addon Functions
  "GetAddOnMetadata",
  "GetAddOnInfo",
  "IsAddOnLoaded",
  "LoadAddOn",
  "EnableAddOn",
  "DisableAddOn",

  -- WoW API - System Functions
  "GetBuildInfo",
  "GetLocale",
  "GetTime",
  "GetFramerate",
  "GetNetStats",
  "GetCVar",
  "SetCVar",
  "GetCVarBool",
  "RegisterCVar",
  "ReloadUI",
  "ShowUIPanel",
  "HideUIPanel",
  "ToggleGameMenu",
  "StaticPopup_Show",
  "StaticPopup_Hide",
  "PlaySound",
  "PlaySoundFile",
  "StopSound",

  -- WoW API - Secure Functions
  "hooksecurefunc",
  "issecurevariable",
  "securecall",
  "InCombatLockdown",
  "RegisterStateDriver",
  "UnregisterStateDriver",

  -- WoW API - Event Functions
  "GetCurrentEventID",

  -- WoW API - Tooltip
  "GameTooltip",
  "ItemRefTooltip",
  "GameTooltip_SetDefaultAnchor",

  -- WoW API - Cursor
  "GetCursorPosition",
  "SetCursor",
  "ResetCursor",

  -- WoW API - Instance
  "IsInInstance",

  -- WoW API - Misc
  "GetScreenWidth",
  "GetScreenHeight",
  "CopyTable",
  "tContains",
  "strtrim",
  "Mixin",
  "CreateFromMixins",
  "CreateAndInitFromMixin",
  "nop",
  "ClearOverrideBindings",
  "SetOverrideBinding",
  "SetOverrideBindingClick",

  -- WoW Global Strings - Achievements
  "ACHIEVEMENT_BROADCAST",

  -- WoW Global Strings - Auctions
  "AUCTIONS",
  "ERR_AUCTION_BID_PLACED",
  "ERR_AUCTION_REMOVED",
  "ERR_AUCTION_SOLD_S",
  "ERR_AUCTION_STARTED",
  "ERR_AUCTION_WON_S",

  -- WoW Global Strings - Chat Formats
  "CHAT_BATTLEGROUND_GET",
  "CHAT_BATTLEGROUND_LEADER_GET",
  "CHAT_GUILD_GET",
  "CHAT_INSTANCE_CHAT_GET",
  "CHAT_INSTANCE_CHAT_LEADER_GET",
  "CHAT_OFFICER_GET",
  "CHAT_PARTY_GET",
  "CHAT_PARTY_LEADER_GET",
  "CHAT_RAID_GET",
  "CHAT_RAID_LEADER_GET",
  "CHAT_RAID_WARNING_GET",
  "CHAT_YOU_CHANGED_NOTICE",
  "CHAT_YOU_CHANGED_NOTICE_BN",

  -- WoW Global Strings - Combat/Experience
  "COMBATLOG_ARENAPOINTSAWARD",
  "COMBATLOG_HONORAWARD",
  "COMBATLOG_HONORGAIN",
  "COMBATLOG_HONORGAIN_NO_RANK",
  "COMBATLOG_XPGAIN_FIRSTPERSON",
  "COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED",
  "HONOR_POINTS",
  "LEVEL_UP",
  "XP",

  -- WoW Global Strings - Errors
  "ERR_EXHAUSTION_NORMAL",
  "ERR_EXHAUSTION_WELLRESTED",
  "ERR_NOT_IN_INSTANCE_GROUP",
  "ERR_NOT_IN_RAID",
  "ERR_QUEST_ALREADY_ON",
  "ERR_ZONE_EXPLORED_XP",
  "ERR_QUEST_REWARD_EXP_I",

  -- WoW Global Strings - Loot Rolls
  "GREED",
  "LOOT_ROLL_ALL_PASSED",
  "LOOT_ROLL_DISENCHANT",
  "LOOT_ROLL_DISENCHANT_SELF",
  "LOOT_ROLL_GREED",
  "LOOT_ROLL_GREED_SELF",
  "LOOT_ROLL_NEED",
  "LOOT_ROLL_NEED_SELF",
  "LOOT_ROLL_PASSED",
  "LOOT_ROLL_PASSED_AUTO",
  "LOOT_ROLL_PASSED_SELF",
  "LOOT_ROLL_PASSED_SELF_AUTO",
  "LOOT_ROLL_WON",
  "LOOT_ROLL_YOU_WON",
  "NEED",
  "PASS",
  "ROLL_DISENCHANT",

  -- WoW Global Strings - Money
  "COPPER_AMOUNT",
  "COPPER_AMOUNT_SYMBOL",
  "GOLD_AMOUNT",
  "GOLD_AMOUNT_SYMBOL",
  "LARGE_NUMBER_SEPERATOR",
  "SILVER_AMOUNT",
  "SILVER_AMOUNT_SYMBOL",

  -- WoW Global Strings - Quests
  "BATTLE_PET_SOURCE_2",
  "CALENDAR_STATUS_ACCEPTED",
  "COMPLETE",
  "ERR_COMPLETED_TRANSMOG_SET_S",
  "ERR_QUEST_ACCEPTED_S",
  "ERR_QUEST_ALREADY_DONE",
  "ERR_QUEST_ALREADY_DONE_DAILY",
  "ERR_QUEST_COMPLETE_S",
  "ERR_QUEST_FAILED_TOO_MANY_DAILY_QUESTS_I",
  "NO_DAILY_QUESTS_REMAINING",
  "QUEST_LOG",

  -- WoW Global Strings - Reputation
  "FACTION_STANDING_DECREASED",
  "FACTION_STANDING_DECREASED_GENERIC",
  "FACTION_STANDING_INCREASED",
  "FACTION_STANDING_INCREASED_GENERIC",
  "REPUTATION",

  -- WoW Global Strings - Spells
  "ERR_LEARN_ABILITY_S",
  "ERR_LEARN_PASSIVE_S",
  "ERR_LEARN_RECIPE_S",
  "ERR_LEARN_SPELL_S",
  "ERR_SPELL_UNLEARNED_S",

  -- WoW Global Strings - Status
  "CLEARED_AFK",
  "CLEARED_DND",
  "DEFAULT_AFK_MESSAGE",
  "DEFAULT_DND_MESSAGE",
  "MARKED_AFK",
  "MARKED_AFK_MESSAGE",
  "MARKED_DND",

  -- WoW Global Strings - Tradeskills
  "SKILL_RANK_UP",
  "TRADE_SKILLS_LEARNED_TAB",
  "TRADE_SKILLS_UNLEARNED_TAB",

  -- WoW Global Strings - UI
  "CLOSE",

  -- WoW Global Tables
  "ITEM_QUALITY_COLORS",
  "RAID_CLASS_COLORS",
  "ChatTypeInfo",
  "ChatTypeGroup",
  "CHAT_CATEGORY_LIST",
  "CHAT_CONFIG_CHAT_LEFT",
  "SlashCmdList",
  "SLASH_RELOAD1",
  "hash_SlashCmdList",
  "NUM_CHAT_WINDOWS",
  "StaticPopupDialogs",

  -- WoW Global Frames
  "AuctionFrame",
  "AuctionHouseFrame",
  "AuctionsItemButton",
  "BankFrame",
  "ChatFrame1Background",
  "ChatFrame1TabHolder",
  "ClassTrainerFrame",
  "ContainerFrame1",
  "FriendsFrame",
  "GossipFrame",
  "GuildFrame",
  "LootFrame",
  "MailFrame",
  "MerchantFrame",
  "PetitionFrame",
  "PlayerFrame",
  "QuestFrame",
  "SpellBookFrame",
  "TargetFrame",
  "TradeFrame",
  "TradeSkillFrame",
  "InterfaceOptionsFrame",
  "InterfaceOptions_AddCategory",
  "SettingsPanel",
  "VideoOptionsFrame",

  -- WoW Template Mixins (may be nil in 3.3.5)
  "BackdropTemplateMixin",
  "SettingsListMixin",
  "SettingsSelectionPopoutMixin",

  -- WoW Backdrop
  "BACKDROP_TOOLTIP_16_16",
  "BACKDROP_DIALOG_32_32",

  -- Blizzard Chat Functions
  "FCF_OpenTemporaryWindow",
  "FCF_Close",
  "FCF_SetLocked",
  "FCF_Tab_OnClick",
  "FCF_ResetChatWindows",
  "FCFManager_GetNumDedicatedFrames",
  "ChatFrame_OnHyperlinkShow",

  -- C_* API namespaces
  "C_Timer",
  "C_ChatInfo",
  "C_Club",

  -- LibStub and Ace libraries
  "LibStub",

  -- Debugging
  "DevTools_Dump",
  "debugprofilestop",
}

-- Globals that the addon may SET (write to)
globals = {
  -- _G table itself (for polyfills)
  "_G",

  -- Addon namespace (set in XML/TOC)
  "CleanerChat",
  "CleanerChatDB",
  "CleanerChat_DB",
  "CleanerChatGlassDB",

  -- Glass UI globals
  "Glass",

  -- Chat frame globals the addon modifies
  "SELECTED_CHAT_FRAME",
  "SELECTED_DOCK_FRAME",
  "FCF_GetCurrentChatFrame",
  "FCF_GetNumActiveChatFrames",
  "IsCombatLog",

  -- Combat log frame
  "CombatLogQuickButtonFrame",

  -- Polyfills the addon creates
  "BackdropTemplateMixin",
  "CreateFromMixins",
  "CreateAndInitFromMixin",
  "CopyTable",
  "C_Timer",
  "Enum",
  "Mixin",
  "MouseIsOver",
  "CreateObjectPool",
  "nop",
  "SettingsListMixin",
  "SettingsSelectionPopoutMixin",
  "tContains",
  "UnitNameUnmodified",
  "UnitEffectiveLevel",
  "GetAddOnEnableState",
  "wipe",

  -- SlashCmdList entries
  "SlashCmdList",
  "SLASH_CLEANERCHAT1",
  "SLASH_CLEANERCHAT2",
  "SLASH_CC1",
  "SLASH_CCDEBUG1",
  "SLASH_GLASS1",
}

-- Per-file overrides
files = {
  -- Locale files use L as a table that gets populated
  ["Locale/*.lua"] = {
    globals = { "L" },
    ignore = { "211" },  -- Unused local variable (L is used by AceLocale)
  },

  -- Compat layers create global polyfills - allow _G modifications
  ["GlassUI/compat.lua"] = {
    ignore = { "122", "212" },  -- _G polyfills + callback signatures
    globals = {
      "_G",
      "BackdropTemplateMixin",
      "C_Timer",
      "CopyTable",
      "CreateAndInitFromMixin",
      "CreateFromMixins",
      "CreateObjectPool",
      "Enum",
      "FCF_GetNumActiveChatFrames",
      "IsCombatLog",
      "Mixin",
      "MouseIsOver",
      "nop",
      "SettingsListMixin",
      "SettingsSelectionPopoutMixin",
      "tContains",
      "wipe",
    },
  },

  ["Core/Common/Compatibility.lua"] = {
    ignore = { "122", "212" },  -- _G polyfills + callback signatures
    globals = {
      "_G",
      "C_Timer",
      "CopyTable",
      "CreateFromMixins",
      "GetAddOnEnableState",
      "UnitEffectiveLevel",
      "UnitNameUnmodified",
    },
  },

  -- Core creates the addon namespace
  ["Core/Core.lua"] = {
    ignore = { "212" },  -- Callback signatures
    globals = { "CleanerChat_DB", "ns" },
  },

  -- Options uses AceConfig callbacks with required `info` parameter
  ["Core/Options.lua"] = {
    ignore = { "212" },  -- AceConfig get/set callbacks require info arg
  },

  -- Private.lua sets up shared state
  ["Core/Private.lua"] = {
    ignore = { "212" },  -- Callback signatures
    globals = { "ns" },
  },

  -- Init creates Glass namespace
  ["GlassUI/init.lua"] = {
    ignore = { "122" },  -- Setting Glass global
    globals = { "Glass" },
  },

  -- Config uses AceConfig callbacks with required `info` parameter
  ["GlassUI/Modules/Config.lua"] = {
    ignore = { "212/info" },  -- AceConfig get/set callbacks require info arg
  },

  -- UIManager modifies chat frame globals
  ["GlassUI/Modules/UIManager.lua"] = {
    ignore = { "122", "212" },  -- Modifying chat frame functions + callbacks
    globals = {
      "CombatLogQuickButtonFrame",
      "FCF_GetCurrentChatFrame",
    },
  },

  -- Hyperlinks has callback signatures
  ["GlassUI/Modules/Hyperlinks.lua"] = {
    ignore = { "212" },  -- Callback signatures
  },

  -- ChatTab modifies SELECTED_CHAT_FRAME
  ["Components/UI/ChatTab.lua"] = {
    ignore = { "122", "212" },  -- Setting SELECTED_CHAT_FRAME + callbacks
    globals = {
      "SELECTED_CHAT_FRAME",
      "SELECTED_DOCK_FRAME",
    },
  },

  -- Debug component adds slash commands
  ["Components/Filters/_Debug.lua"] = {
    ignore = { "122", "212" },  -- Adding to SlashCmdList + callbacks
    globals = {
      "SlashCmdList",
      "SLASH_CCDEBUG1",
    },
  },

  -- Loot uses StaticPopupDialogs
  ["Components/Filters/Loot.lua"] = {
    ignore = { "212" },  -- Callback signatures
    globals = { "StaticPopupDialogs" },
  },

  -- Chat filter components have callbacks with fixed signatures
  -- (self, chatFrame, event/msg, r, g, b, chatID, ...)
  ["Components/Filters/Achievements.lua"] = {
    ignore = { "212" },  -- Chat filter callback signature
  },
  ["Components/Filters/Auctions.lua"] = {
    ignore = { "212" },  -- Chat filter callback signature
  },
  ["Components/Filters/Blacklist.lua"] = {
    ignore = { "212" },  -- Chat filter callback signature
  },
  ["Components/Filters/Empty.lua"] = {
    ignore = { "212" },  -- Chat filter callback signature
  },
  ["Components/Filters/Experience.lua"] = {
    ignore = { "212" },  -- Chat filter callback signature
  },
  ["Components/Filters/Money.lua"] = {
    ignore = { "212" },  -- Chat filter callback signature
  },
  ["Components/Filters/Quests.lua"] = {
    ignore = { "212" },  -- Chat filter callback signature
  },
  ["Components/Filters/Reputation.lua"] = {
    ignore = { "212" },  -- Chat filter callback signature
  },
  ["Components/UI/SlidingMessageFrame.lua"] = {
    ignore = { "212" },  -- Callback signatures
  },
  ["Components/Filters/Spells.lua"] = {
    ignore = { "212" },  -- Chat filter callback signature
  },
  ["Components/Filters/Status.lua"] = {
    ignore = { "212" },  -- Chat filter callback signature
  },
  ["Components/Filters/Tradeskills.lua"] = {
    ignore = { "212" },  -- Chat filter callback signature
  },

  -- Unit tests run under the busted framework (describe/it/assert/before_each)
  -- and intentionally stub WoW globals (ChatTypeInfo, C_Timer) on _G to exercise
  -- the helpers, so allow assigning to those otherwise read-only global fields.
  ["spec/*.lua"] = {
    std = "+busted",
    ignore = { "122" }, -- W122: setting read-only field of _G (intentional test stubs)
  },
}
