local L = LibStub("AceLocale-3.0"):NewLocale((...), "enUS", true, true)

-- These are chat channel abbreviations.
-- For the most part these match the /slash command to type in these channels,
-- so unless that command is something else in different regions, don't localize it!
L["BGL"] = true -- Battleground Leader (WoW Classic)
L["BG"] = true -- Battleground (WoW Classic)
L["PL"] = true -- Party Leader
L["P"] = true -- Party
L["RL"] = true -- Raid Leader
L["R"] = true -- Raid
L["IL"] = true -- Instance Leader (WoW Retail)
L["I"] = true -- Instance (WoW Retail)
L["G"] = true -- Guild
L["O"] = true -- Officer
L["DG"] = true -- Dungeon Guide (Ascension)

L["Channel Name Style"] = true
L["Choose whether to show the channel's full name or just its first letter. Requires the Chat Channel Names filter."] =
	true
L['Shortened (e.g. "[G]")'] = true
L['Full name (e.g. "[General]")'] = true

L["Show Channel Number"] = true
L['Prefix the channel display with its number, e.g. "1. ". Requires the Chat Channel Names filter.'] = true

L["Capitalize Channel Name"] = true
L["Capitalize the first letter of the channel name or initial. Requires the Chat Channel Names filter."] = true

L["Capitalize Player Names"] = true
L["Capitalize the first letter of player names shown in chat. Requires the Player Names filter."] = true

L["Prettify Money"] = true
L['Display money gains and losses with coin icons (e.g. "+ 28"). When off, uses the default Blizzard text format.'] =
	true

L["Hide Crafting Broadcasts"] = true
L['Hide the "<name> created: <item>" messages shown when other players craft items nearby. Requires the Learning (Crafting) filter.'] =
	true

L["Hide UI Error Messages on Login from CleanerChat"] = true
L['Hide the "UI Error: an interface error occurred" notifications the server prints to chat when a UI error happens.'] =
	true

L["Show Startup Message"] = true
L["Print a message on login showing how to open CleanerChat settings."] = true
L["Use %s for settings."] = true

L["Chat Debug Capture"] = true
L["Print the raw text and underlying event for every chat line, for diagnosing filters (same as /ccdebug). Stays on across /reload."] =
	true

L["Settings changed - the UI will reload when you close this window."] = true

-- Chat tab right-click menu (CleanerChat multi-window)
L["CleanerChat settings"] = true
L["New detached window"] = true
L["Delete window"] = true

L["Filter Selection"] = true

L["Achievements"] = true
L["Simplify Achievement messages."] = true

L["Auctions"] = true
L["Simplify auction house messages: listings created, cancelled, sold, won and bids placed."] = true

L["Chat Channel Names"] = true
L["Abbreviate and simplify chat channel display names."] = true

L["Experience"] = true
L["Abbreviate and simplify experience- and level gains."] = true

L["Loot"] = true
L["Abbreviate and simplify loot-, currency- and received item messages."] = true

L["Player Names"] = true
L["Remove brackets from player names."] = true

L["Quests"] = true
L["Simplify quest completion- and progress messages."] = true

L["Reputation"] = true
L["Simplify messages about reputation gain and loss."] = true

L["Learning (Spells)"] = true
L["Blacklist messages about new or removed spells, typically spammed on specialization changes."] = true

L["Player Status"] = true
L["Simplify status messages about AFK, DND and being rested."] = true

L["Learning (Crafting)"] = true
L["Simplify messages about new or improved trade skills."] = true

L["One Line Quest Rewards"] = true
L["Combine quest rewards (items, currency, experience) into a single line. Reputation gains remain separate per faction."] =
	true

L["Show Item Destruction"] = true
L["Display a message when you destroy (delete) an item."] = true

L["Show Vendor Sales"] = true
L["Prettify Guild Status"] = true
L["Simplify guild online/offline messages to show just the player name."] = true
L["Display a message when you sell an item to a vendor."] = true

-- Glass UI Config Strings
-- Category/Section Names
L["Glass"] = true
L["General"] = true
L["Frame Position"] = true
L["Lock frame"] = true
L["Unlock frame"] = true
L["Appearance"] = true
L["Font"] = true
L["Font to use for the edit box text."] = true
L["Font to use for chat messages."] = true
L["Font to use for the chat tab text."] = true
L["Frame"] = true
L["X offset"] = true
L["Width"] = true
L["Y offset"] = true
L["Height"] = true
L["Anchor"] = true
L["Top left"] = true
L["Top right"] = true
L["Bottom left"] = true
L["Bottom right"] = true

-- Font Flags
L["None"] = true
L["Outline"] = true
L["Thick Outline"] = true
L["Monochrome"] = true
L["Monochrome Outline"] = true
L["Monochrome Thick Outline"] = true
L["Outline Monochrome"] = true

-- Edit Box
L["Edit box"] = true
L["Font size"] = true
L["Font style"] = true
L["Add an outline to the edit box text so it stands out instead of looking flat."] = true
L["Background opacity"] = true
L["Background color"] = true
L["The colour of the edit box background."] = true
L["Position"] = true
L["Above"] = true
L["Below"] = true
L["Vertical offset"] = true
L["Behavior"] = true
L["Show chat on focus"] = true
L["When enabled, opening the edit box (pressing Enter or clicking) reveals the chat messages."] = true

-- Messages
L["Messages"] = true
L["Add an outline to chat message text so it stands out instead of looking flat."] = true
L["The colour of the chat message background."] = true
L["Leading"] = true
L["Line padding"] = true
L["Left padding"] = true
L["Controls the blank space on the left side of messages."] = true
L["Message history"] = true
L["Maximum number of messages to keep in memory per chat window. Higher values use more memory."] = true
L["Animations"] = true
L["Disable animations"] = true
L["Show messages instantly with no slide or fade -- the chat becomes static. The timing sliders below have no effect while this is on."] =
	true
L["Keep messages visible"] = true
L["Messages never fade out -- they stay on screen permanently. Overrides the fade out delay and duration below."] = true
L["Fade out delay"] = true
L["Fade in duration"] = true
L["Fade out duration"] = true
L["Slide in duration"] = true
L["Misc"] = true
L["Indent on line wrap"] = true
L["Adds an indent when a message wraps beyond a single line."] = true
L["Mouse over tooltips"] = true
L["Should tooltips appear when hovering over chat links."] = true
L["Text icons Y offset"] = true
L["Adjust this if text icons aren't centered."] = true
L["Show messages on hover"] = true
L["When enabled, hovering over the chat reveals faded messages. When disabled, only scrolling reveals them."] = true

-- Scroll Indicator
L["Scroll Indicator"] = true
L["Hide scroll indicator"] = true
L['Hide the "Unread messages" and "Bring me to the present" indicator completely.'] = true
L["Indicator text color"] = true
L['Color of the "Unread messages" and "Bring me to the present" text.'] = true
L["Indicator text opacity"] = true
L["Opacity of the scroll indicator text."] = true
L["Indicator background color"] = true
L["Background color behind the scroll indicator text."] = true
L["Indicator background opacity"] = true
L["Opacity of the scroll indicator background."] = true

-- Top Bar
L["Top bar"] = true
L["Add an outline to the chat tab text so it stands out instead of looking flat."] = true
L["The colour of the top bar background."] = true
L["Show and hide the top bar instantly with no fade -- the tabs become static. The timing sliders below have no effect while this is on."] =
	true
L["Keep tabs visible"] = true
L["Chat tabs never fade out -- they stay on screen permanently. Overrides the fade out delay and duration below."] =
	true
L["Show tabs on hover"] = true
L["When enabled, chat tabs fade out when idle and reappear on mouse hover. When disabled, tabs are always visible."] =
	true
L["Tab widths refit on /reload."] = true

-- Tab Button Style
L["Tab Style"] = true
L["Choose the visual style for chat tab buttons."] = true
L["Minimal"] = true
L["Outline"] = true
L["Tab Corner Style"] = true
L["Shape of tab button corners."] = true
L["Square"] = true
L["Rounded"] = true
L["Tab active color"] = true
L["Color of the selected/active tab background and text."] = true
L["Tab inactive color"] = true
L["Color of unselected tab backgrounds."] = true
L["Tab background opacity"] = true
L["Opacity of the tab background and border."] = true
L["Tab spacing"] = true
L["Horizontal spacing between tab buttons."] = true
L["Tab border thickness"] = true
L["Thickness of the outline border."] = true
L["Tab padding"] = true
L["Padding from the dock edge."] = true

-- Timestamps
L["Show timestamps"] = true
L["Prepend each message with a timestamp in [HH:MM] format."] = true

-- Buttons
L["Buttons"] = true
L["Hide Chat Menu button"] = true
L["Hide the Chat Menu (speech bubble) button that provides access to languages and emotes."] = true
L["Hide Social button"] = true
L["Hide the Social (friends) button that appears to the left of the chat frame."] = true

-- About
L["About"] = true
L["Author"] = true
L["Credits"] = true
L["CleanerChat stands on the shoulders of two excellent addons. All credit for the original work belongs to their creators."] =
	true
L["The immersive chat UI is built on Glass by mixxorz. This project keeps the spirit of Glass alive on 3.3.5."] = true
L["The message filtering is based on ChatCleaner by Lars Norberg (Goldpaw). Backported to 3.3.5."] = true
