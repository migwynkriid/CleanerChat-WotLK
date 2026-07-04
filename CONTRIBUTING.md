# Contributing to CleanerChat

Thanks for your interest in improving CleanerChat! This document covers the
project layout, local checks, and the conventions used throughout the codebase.

CleanerChat targets **WoW 3.3.5a (interface 30300)**, which runs **Lua 5.1**.
Please keep that in mind: no `goto`, no integer division operator, no `//`
comments, etc. The CI lints against the `lua51` standard.

---

## Project layout

```
CleanerChat.toc          Manifest + load order
Embeds.xml               Bundled libraries (Ace3, LibSharedMedia, LibEasing, ...)
Core/
  Common/                Compatibility shims, Constants, Colors
  API/                   Output format strings + shared helpers (Utils.lua)
  Core.lua               Filter engine (blacklist/replacements + AddMessage hook)
  Options.lua            /cc options panel (AceConfig)
  Private.lua / Finalize.lua   Protected namespace setup/teardown
Components/
  Filters/               ChatCleaner message filters (one module per concern)
  UI/                    Glass chat-UI widgets (frames, tabs, edit box, ...)
  Components.xml         Loads Components/Filters/*
GlassUI/
  init.lua / constants.lua / utils.lua / compat.lua
  Modules/               Config, Fonts, Hyperlinks, TextProcessing, UIManager
GlassUI.xml              Loads GlassUI core, Components/UI/*, and Modules/*
Locale/                  AceLocale tables (enUS is the source of truth)
spec/                    busted unit tests for pure helpers
```

The addon is a fusion of two backported projects:

- **ChatCleaner** (message filtering) → `Core/` + `Components/Filters/`
- **Glass** (immersive chat UI) → `GlassUI/` + `Components/UI/`

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit together.

---

## Local checks

CI (`.github/workflows/validate.yml`) runs these on every PR; run them locally
first.

Install the toolchain (once):

```sh
# luacheck + busted via LuaRocks
luarocks install luacheck
luarocks install busted
```

Then, from the addon root:

```sh
# Lint (must be warning-free; CI fails on warnings)
luacheck .

# Unit tests
busted spec

# Optional: raw syntax check of every file
find Core Components GlassUI spec -name '*.lua' -exec luac5.1 -p {} +
```

`.luacheckrc` whitelists the WoW global environment and carries per-file
overrides (e.g. chat-filter callbacks legitimately ignore unused-argument 212).
If you add a file that needs an override, add a `["path/to/File.lua"]` entry.

---

## Adding a chat filter

Filters are self-registering AceAddon modules. To add one:

1. Create `Components/Filters/MyThing.lua`:

   ```lua
   local _, ns = ...
   local Module = ns:NewModule("MyThing")

   -- Self-populating pattern cache (compiles WoW global strings on demand).
   local P = ns.MakePatternCache()
   local safeMatch = ns.SafeMatch

   local G = { SOMETHING = SOME_GLOBAL_STRING }

   Module.OnChatEvent = function(self, chatFrame, event, message, author, ...)
     local item = safeMatch(message, P[G.SOMETHING])
     if (item) then
       return false, string_format(ns.out.something, ns.StripBrackets(item)), author, ...
     end
   end

   local onChatEventProxy = function(...) return Module:OnChatEvent(...) end

   Module.OnEnable = function(self)
     self:RegisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
   end
   Module.OnDisable = function(self)
     self:UnregisterMessageEventFilter("CHAT_MSG_SYSTEM", onChatEventProxy)
   end
   ```

2. Add `<Script file="Filters\MyThing.lua"/>` to `Components/Components.xml`.
3. If it is user-toggleable, add a `filters.mything` default in `Core/Core.lua`,
   a toggle in `Core/Options.lua`, and localized strings (see below). The module
   name must match the capitalized filter key (`mything` → `MyThing`).
4. Put any output format strings in `Core/API/Output.lua` (`ns.out.*`) — never
   inline literal color codes in a filter.

### Shared helpers (prefer these over re-implementing)

| Helper | Use for |
| --- | --- |
| `ns.MakePatternCache()` | Lazily compile + memoize WoW global-string patterns |
| `ns.SafeMatch(msg, pat)` | `string.match` that tolerates a nil pattern |
| `ns.StripBrackets(s)` | Remove `[ ]` from a link name, keep the hyperlink |
| `ns.PrintToFrame(frame, msg, chatType)` | Emit a colored line via `ChatTypeInfo` |
| `ns.CreateFrameBuffer(newState, flush)` | Batch same-frame bursts, flush next frame |

On the Glass side:

| Helper | Use for |
| --- | --- |
| `Core:Subscribe(EVENT, fn)` / `Core:Dispatch(EVENT, payload)` | Pub/sub bus |
| `Core:ResolveConfigKey(payload, windowId)` | Unwrap an `UPDATE_CONFIG` payload + window filter |
| `Glass` `Utils.SetSolidColor(tex, r, g, b, a)` | Solid-color a texture (3.3.5 safe) |

---

## Localization

`Locale/enUS.lua` is the source of truth. Every `L["..."]` key used in code must
exist there; CI verifies all other locales contain the same keys (missing keys
fall back to enUS). When you add a user-facing string:

1. Add the key to `Locale/enUS.lua`.
2. Add it (translated or copied) to the other `Locale/*.lua` files, or CI's
   "Locale completeness" step will fail.

---

## Pull requests

- Keep changes focused; one logical change per PR.
- Make sure `luacheck .` and `busted spec` pass locally.
- Don't introduce profanity or dismissive comments in code.
- Don't bump the version manually — releases are automated from `main`.
