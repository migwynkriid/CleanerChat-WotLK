<div align="center">

# CleanerChat

**Clean up the clutter. Overhaul the chat.**

A World of Warcraft **3.3.5a (WotLK)** addon that filters chat message clutter *and* replaces the
default chat frame with an immersive, modern chat UI.

<br />

[![Version](https://img.shields.io/badge/version-2.9-DFBA69?style=for-the-badge)](CleanerChat.toc)
[![WoW](https://img.shields.io/badge/WoW-3.3.5a%20WotLK-1784b8?style=for-the-badge)](#compatibility)
[![Interface](https://img.shields.io/badge/interface-30300-555?style=for-the-badge)](#compatibility)
[![License](https://img.shields.io/badge/license-Custom-lightgrey?style=for-the-badge)](LICENSE.txt)

[![Lua](https://img.shields.io/badge/Lua-5.1-000080?style=flat&logo=lua&logoColor=white)](https://www.lua.org/)
[![Ascension](https://img.shields.io/badge/tested%20on-Ascension%20WoW-e8782b?style=flat)](https://ascension.gg/)
[![Stars](https://img.shields.io/github/stars/migwynkriid/CleanerChat-WotLK?style=flat&color=DFBA69)](https://github.com/migwynkriid/CleanerChat-WotLK/stargazers)
[![Issues](https://img.shields.io/github/issues/migwynkriid/CleanerChat-WotLK?style=flat)](https://github.com/migwynkriid/CleanerChat-WotLK/issues)
[![Downloads](https://img.shields.io/github/downloads/migwynkriid/CleanerChat-WotLK/total.svg?style=flat)](https://github.com/migwynkriid/CleanerChat-WotLK/releases)
[![Last commit](https://img.shields.io/github/last-commit/migwynkriid/CleanerChat-WotLK?style=flat)](https://github.com/migwynkriid/CleanerChat-WotLK/commits)

![CleanerChat in action](https://i.imgur.com/8lj13ch.gif)

<img width="1250" height="250" alt="image" src="https://github.com/user-attachments/assets/ac9895d1-5ae3-429b-96fe-c42f061c72d8" />

https://github.com/user-attachments/assets/39dade08-35d7-41ef-b203-68c314116d25

</div>

<div align="center">

</div>

---

## What it does

CleanerChat does two things at once:

| | |
| --- | --- |
| **Cleans** | Filters and reformats chat messages to cut clutter and improve readability. |
| **Overhauls** | Replaces the default chat frame with an integrated, WotLK-backported build of the **Glass** immersive chat UI. |

Everything is configurable from a single options panel — just type `/cc`.

---

## Chat cleaning

CleanerChat filters and reformats chat to reduce noise. Each filter can be toggled individually under `/cc → Filters`.

| Filter | What it does |
| --- | --- |
| **Loot messages** | Consolidates multiple loot pickups into cleaner summaries |
| **Loot rolls** | Cleans up Need, Greed, Disenchant and Pass roll messages |
| **Money** | Formats gold/silver/copper with icons |
| **Experience & Reputation** | Cleaner XP and rep gain messages |
| **Achievements** | Streamlined achievement notifications |
| **Spells & Abilities** | Consolidated spell-learning messages |
| **Auctions** | Cleaner auction house notifications |
| **Quest updates** | Simplified quest progress messages |
| **Quest rewards** | Formats reward item messages |
| **Crafting** | Reformats "creates" broadcasts |
| **Channel names** | Shortened channel prefixes |
| **Player names** | Class-colored names in chat |
| **Item quality** | Color-coded item names by rarity |

---

## Chat overhaul

Beyond cleaning messages, CleanerChat **replaces the default chat UI** with an integrated, WotLK-backported build of the **Glass** immersive chat addon:

- **Sliding messages** that fade in, fade out when idle, and reappear on mouse-over
- **Auto-hiding tab bar** at the top that fades when idle and reveals on hover
- **Restyled edit box** that appears instantly when you press Enter
- **Movable frame** — drag it anywhere with `/cc lock`, then lock to save
- **Combat log** rendered inside the same UI
- **Clickable links** — item, spell, quest and similar links open their tooltip / preview
- **URL detection** — web links in chat become clickable and open a small box you can copy from (Ctrl+C)
- **Fully configurable** — fonts, background **colors** & opacity, fade/slide timings, frame size & position, plus a dedicated **Top bar** section, all under `/cc`

---

## Installation

1. Download the addon.
2. Extract it to `Interface\AddOns\CleanerChat`.
3. Restart WoW or type `/reload`.

---

## Commands

| Command | Description |
| --- | --- |
| `/cc` &nbsp;·&nbsp; `/cleanerchat` | Open the options panel. Filters **and** chat-UI settings are organized into categories (Filters, General, Edit box, Messages, Top bar, Profiles). |
| `/cc lock` | Unlock the chat frame to drag it; lock it again to save the position. |
| `/ccdebug` | Toggle raw chat / event capture for diagnosing filters (also a checkbox under **General**). |

---

## Compatibility

Built for the **3.3.5a** (WotLK, interface `30300`) client.

> **Note:** CleanerChat is primarily developed and tested on **[Ascension WoW](https://ascension.gg/)**. While it should work on native 3.3.5a clients, there may be minor differences in styling or behavior. If you encounter any issues on a non-Ascension client, please [open an issue](https://github.com/migwynkriid/CleanerChat-WotLK/issues) — compatibility patches will be provided as needed.
>
> **Other customized servers:** Heavily modified private servers (beyond the standard 3.3.5a experience) may or may not work with CleanerChat. Compatibility is not guaranteed for such environments.

Includes:

- A `C_Timer` polyfill for timer functionality
- `C_AddOns` compatibility shims
- Safe pattern matching with nil checks
- Loot roll formatting (Need / Greed / Disenchant / Pass)
- Quest reward and crafting message formatting
- A WotLK backport of the Glass chat UI (animation, hyperlink and texture shims)

---

## Credits

> CleanerChat stands on the shoulders of two excellent addons. **All credit for the original work belongs to their creators** — this project simply backports them to 3.3.5, strips out the parts that don't exist on the WotLK client, cleans them up, and makes them run smoothly on the 3.3.5 client.

### Glass — the chat overhaul

The immersive chat UI is built on **[Glass](https://www.curseforge.com/wow/addons/glass)** by **mixxorz**. The community absolutely loved Glass, and this project exists to **keep the spirit of Glass alive** on 3.3.5. The build here is **backported** to WotLK: non-available retail/modern APIs were stripped out and replaced with compatibility shims, and the code was cleaned up to work on the 3.3.5 client. Thank you, **mixxorz**!

### ChatCleaner — the chat cleaning

The message filtering and reformatting is based on **[ChatCleaner](https://github.com/GoldpawsStuff/ChatCleaner)** by Lars Norberg (Goldpaw / GoldpawsStuff). Like Glass, it has also been **backported** to 3.3.5 — stripped of features and APIs that aren't available on WotLK, cleaned up, and made to work on the 3.3.5 client. Thank you, **Goldpaw**!

### Assets

The coin icons (`Assets/coins.tga`) are from the original **ChatCleaner** addon by Goldpaw.

CleanerChat is an independent project maintained by **migwynkriid**, who bundles backported, cleaned-up builds of both addons into one and is currently the sole maintainer of the project.

---

## License

Custom License — see [LICENSE.txt](LICENSE.txt).
