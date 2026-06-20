# CleanerChat

A World of Warcraft (3.3.5a / WotLK) addon that **cleans up and overhauls** the chat — it filters message clutter *and* replaces the default chat frame with an immersive, modern chat UI.

## Description

CleanerChat filters and reformats chat messages to reduce clutter and improve readability. It handles:

- **Loot messages** - Consolidates multiple loot pickups into cleaner summaries
- **Loot rolls** - Cleans up Need, Greed, Disenchant, and Pass roll messages
- **Money** - Formats gold/silver/copper with icons
- **Experience & Reputation** - Cleaner XP and rep gain messages
- **Achievements** - Streamlined achievement notifications
- **Spells & Abilities** - Consolidated spell learning messages
- **Auctions** - Cleaner auction house notifications
- **Quest updates** - Simplified quest progress messages
- **Quest rewards** - Formats reward item messages
- **Crafting** - Reformats "creates" broadcasts
- **Channel names** - Shortened channel prefixes
- **Player names** - Class-colored names in chat
- **Item quality** - Color-coded item names by rarity

## Chat Overhaul

Beyond cleaning messages, CleanerChat **replaces the default chat UI** with an integrated, WotLK-backported build of the **Glass** immersive chat addon:

- **Sliding messages** that fade in, fade out when idle, and reappear on mouse-over
- **Auto-hiding tab bar** at the top that fades when idle and reveals on hover
- **Restyled edit box** that appears instantly when you press Enter
- **Movable frame** - drag it anywhere with `/cc lock`, then lock to save
- **Combat log** rendered inside the same UI
- **Clickable links** - item, spell, quest and similar links open their tooltip / preview
- **URL detection** - web links in chat become clickable and open a small box you can copy from (Ctrl+C)
- **Fully configurable** - fonts, background opacity, fade/slide timings, frame size & position, plus a dedicated **Top bar** section, all under `/cc`

## Installation

1. Download the addon.
2. Extract to `Interface\AddOns\CleanerChat`.
3. Restart WoW or type `/reload`.

## Commands

- `/cc` or `/cleanerchat` - Open the options panel. Chat filters **and** the chat UI settings are organized into categories (Filters, General, Edit box, Messages, Top bar, Profiles).
- `/cc lock` - Unlock the chat frame to drag it; lock it again to save the position.

## Compatibility

Built for the 3.3.5a (WotLK, interface `30300`) client and tested on the Ascension WoW private server. Includes:

- A `C_Timer` polyfill for timer functionality
- `C_AddOns` compatibility shims
- Safe pattern matching with nil checks
- Loot roll formatting (Need/Greed/Disenchant/Pass)
- Quest reward and crafting message formatting
- A WotLK backport of the Glass chat UI (animation, hyperlink and texture shims)

## Credits

- The **chat cleaning** was inspired by the ChatCleaner addon by Lars Norberg (Goldpaw).
- The **chat overhaul** integrates a WotLK-backported build of the **Glass** immersive chat addon.

CleanerChat is an independent project maintained by migwynkriid.

## License

Custom License - see [LICENSE.txt](LICENSE.txt).
