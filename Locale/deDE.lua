local L = LibStub("AceLocale-3.0"):NewLocale((...), "deDE")
if not L then
	return
end

-- CleanerChat multi-window menu / startup message
L["New detached window"] = "Neues separates Fenster"
L["Delete window"] = "Fenster löschen"
L["CleanerChat settings"] = "CleanerChat-Einstellungen"
L["Use %s for settings."] = "Verwende %s für die Einstellungen."

L["Channel Name Style"] = "Kanalnamen-Stil"
L["Choose whether to show the channel's full name or just its first letter. Requires the Chat Channel Names filter."] =
	'Legt fest, ob der vollständige Kanalname oder nur dessen erster Buchstabe angezeigt wird. Erfordert den Filter "Chat-Kanalnamen".'
L['Shortened (e.g. "[G]")'] = 'Gekürzt (z. B. "[G]")'
L['Full name (e.g. "[General]")'] = 'Vollständiger Name (z. B. "[General]")'
L["Show Channel Number"] = "Kanalnummer anzeigen"
L['Prefix the channel display with its number, e.g. "1. ". Requires the Chat Channel Names filter.'] =
	'Stellt der Kanalanzeige die Nummer voran, z. B. "1. ". Erfordert den Filter "Chat-Kanalnamen".'
L["Capitalize Channel Name"] = "Kanalnamen großschreiben"
L["Capitalize the first letter of the channel name or initial. Requires the Chat Channel Names filter."] =
	'Schreibt den ersten Buchstaben des Kanalnamens bzw. der Abkürzung groß. Erfordert den Filter "Chat-Kanalnamen".'
L["Capitalize Player Names"] = "Spielernamen großschreiben"
L["Capitalize the first letter of player names shown in chat. Requires the Player Names filter."] =
	'Schreibt den ersten Buchstaben der im Chat angezeigten Spielernamen groß. Erfordert den Filter "Spielernamen".'
L["Prettify Money"] = "Gold formatieren"
L['Display money gains and losses with coin icons (e.g. "+ 28"). When off, uses the default Blizzard text format.'] =
	'Zeigt Geldgewinne und -verluste mit Münzsymbolen an (z. B. "+ 28"). Bei Deaktivierung wird das Standard-Blizzard-Textformat verwendet.'
L["Hide Crafting Broadcasts"] = "Herstellungsmeldungen ausblenden"
L['Hide the "<name> created: <item>" messages shown when other players craft items nearby. Requires the Learning (Crafting) filter.'] =
	'Blendet die Meldungen "<name> created: <item>" aus, die erscheinen, wenn andere Spieler in der Nähe Gegenstände herstellen. Erfordert den Filter "Lernen (Handwerk)".'
L["Hide UI Error Messages on Login from CleanerChat"] = "UI-Fehlermeldungen beim Anmelden von CleanerChat ausblenden"
L['Hide the "UI Error: an interface error occurred" notifications the server prints to chat when a UI error happens.'] =
	'Blendet die Benachrichtigungen "UI Error: an interface error occurred" aus, die der Server bei einem UI-Fehler im Chat ausgibt.'
L["Show Startup Message"] = "Startnachricht anzeigen"
L["Print a message on login showing how to open CleanerChat settings."] =
	"Zeigt beim Anmelden eine Nachricht an, wie die CleanerChat-Einstellungen geöffnet werden."
L["Settings changed - the UI will reload when you close this window."] =
	"Einstellungen geändert – die Benutzeroberfläche wird neu geladen, wenn du dieses Fenster schließt."
L["Filter Selection"] = "Filterauswahl"
L["Achievements"] = "Erfolge"
L["Simplify Achievement messages."] = "Vereinfacht Erfolgsmeldungen."
L["Auctions"] = "Auktionen"
L["Simplify auction house messages: listings created, cancelled, sold, won and bids placed."] =
	"Vereinfacht Auktionshaus-Nachrichten: erstellte, abgebrochene, verkaufte und gewonnene Auktionen sowie abgegebene Gebote."
L["Chat Channel Names"] = "Chat-Kanalnamen"
L["Abbreviate and simplify chat channel display names."] = "Kürzt und vereinfacht die angezeigten Chat-Kanalnamen."
L["Experience"] = "Erfahrung"
L["Abbreviate and simplify experience- and level gains."] = "Kürzt und vereinfacht Erfahrungs- und Stufengewinne."
L["Loot"] = "Beute"
L["Abbreviate and simplify loot-, currency- and received item messages."] =
	"Kürzt und vereinfacht Meldungen über Beute, Währung und erhaltene Gegenstände."
L["Player Names"] = "Spielernamen"
L["Remove brackets from player names."] = "Entfernt die Klammern um Spielernamen."
L["Quests"] = "Quests"
L["Simplify quest completion- and progress messages."] = "Vereinfacht Meldungen über Questabschluss und -fortschritt."
L["Reputation"] = "Ruf"
L["Simplify messages about reputation gain and loss."] = "Vereinfacht Meldungen über Rufgewinn und -verlust."
L["Learning (Spells)"] = "Lernen (Zauber)"
L["Blacklist messages about new or removed spells, typically spammed on specialization changes."] =
	"Blockiert Meldungen über neue oder entfernte Zauber, die typischerweise bei Spezialisierungswechseln gespammt werden."
L["Player Status"] = "Spielerstatus"
L["Simplify status messages about AFK, DND and being rested."] =
	"Vereinfacht Statusmeldungen zu AFK, BNS (Nicht stören) und dem Ausgeruht-Status."
L["Learning (Crafting)"] = "Lernen (Handwerk)"
L["Simplify messages about new or improved trade skills."] =
	"Vereinfacht Meldungen über neue oder verbesserte Berufsfertigkeiten."

L["One Line Quest Rewards"] = "Questbelohnungen in einer Zeile"
L["Combine quest rewards (items, currency, experience) into a single line. Reputation gains remain separate per faction."] =
	"Fasse Questbelohnungen (Gegenstände, Währung, Erfahrung) in einer Zeile zusammen. Rufgewinne bleiben pro Fraktion getrennt."

L["Show Item Destruction"] = "Gegenstandszerstörung anzeigen"
L["Display a message when you destroy (delete) an item."] =
	"Zeigt eine Nachricht an, wenn du einen Gegenstand zerstörst (löschst)."

L["Show Vendor Sales"] = "Verkauf an Händler anzeigen"
L["Prettify Guild Status"] = "Gildenstatus verschönern"
L["Simplify guild online/offline messages to show just the player name."] =
	"Vereinfacht Gilden-Online/Offline-Nachrichten auf nur den Spielernamen."
L["Display a message when you sell an item to a vendor."] =
	"Zeigt eine Nachricht an, wenn du einen Gegenstand an einen Händler verkaufst."

L["Chat Debug Capture"] = "Chat-Debug-Erfassung"
L["Print the raw text and underlying event for every chat line, for diagnosing filters (same as /ccdebug). Stays on across /reload."] =
	"Gibt den Rohtext und das zugrunde liegende Ereignis für jede Chat-Zeile aus, um Filter zu diagnostizieren (wie /ccdebug). Bleibt nach /reload aktiv."

-- Glass UI Config Strings
L["Glass"] = "Glass"
L["General"] = "Allgemein"
L["Frame Position"] = "Rahmenposition"
L["Lock frame"] = "Rahmen sperren"
L["Unlock frame"] = "Rahmen entsperren"
L["Appearance"] = "Aussehen"
L["Font"] = "Schriftart"
L["Font to use for the edit box text."] = "Schriftart für den Text des Eingabefelds."
L["Font to use for chat messages."] = "Schriftart für Chatnachrichten."
L["Font to use for the chat tab text."] = "Schriftart für den Text der Chat-Tabs."
L["Frame"] = "Rahmen"
L["X offset"] = "X-Versatz"
L["Width"] = "Breite"
L["Y offset"] = "Y-Versatz"
L["Height"] = "Höhe"
L["Anchor"] = "Anker"
L["Top left"] = "Oben links"
L["Top right"] = "Oben rechts"
L["Bottom left"] = "Unten links"
L["Bottom right"] = "Unten rechts"
L["None"] = "Keine"
L["Outline"] = "Umriss"
L["Thick Outline"] = "Dicker Umriss"
L["Monochrome"] = "Einfarbig"
L["Monochrome Outline"] = "Einfarbiger Umriss"
L["Monochrome Thick Outline"] = "Dicker einfarbiger Umriss"
L["Outline Monochrome"] = "Umriss einfarbig"
L["Edit box"] = "Eingabefeld"
L["Font size"] = "Schriftgröße"
L["Font style"] = "Schriftstil"
L["Add an outline to the edit box text so it stands out instead of looking flat."] =
	"Fügt dem Eingabefeld-Text einen Umriss hinzu, damit er hervorsticht anstatt flach auszusehen."
L["Background opacity"] = "Hintergrund-Deckkraft"
L["Background color"] = "Hintergrundfarbe"
L["The colour of the edit box background."] = "Die Farbe des Eingabefeld-Hintergrunds."
L["Position"] = "Position"
L["Above"] = "Oben"
L["Below"] = "Unten"
L["Vertical offset"] = "Vertikaler Versatz"
L["Behavior"] = "Verhalten"
L["Show chat on focus"] = "Chat bei Fokus anzeigen"
L["When enabled, opening the edit box (pressing Enter or clicking) reveals the chat messages."] =
	"Wenn aktiviert, zeigt das Öffnen des Eingabefelds (Enter drücken oder klicken) die Chat-Nachrichten an."
L["Messages"] = "Nachrichten"
L["Add an outline to chat message text so it stands out instead of looking flat."] =
	"Fügt den Chat-Nachrichten einen Umriss hinzu, damit sie hervorstechen anstatt flach auszusehen."
L["The colour of the chat message background."] = "Die Farbe des Chat-Nachrichten-Hintergrunds."
L["Leading"] = "Zeilenabstand"
L["Line padding"] = "Zeilenabstand"
L["Left padding"] = "Linker Abstand"
L["Controls the blank space on the left side of messages."] =
	"Steuert den Leerraum auf der linken Seite der Nachrichten."
L["Message history"] = "Nachrichtenverlauf"
L["Maximum number of messages to keep in memory per chat window. Higher values use more memory."] =
	"Maximale Anzahl an Nachrichten, die pro Chat-Fenster im Speicher gehalten werden. Höhere Werte verbrauchen mehr Speicher."
L["Animations"] = "Animationen"
L["Disable animations"] = "Animationen deaktivieren"
L["Show messages instantly with no slide or fade -- the chat becomes static. The timing sliders below have no effect while this is on."] =
	"Zeigt Nachrichten sofort ohne Gleiten oder Einblenden -- der Chat wird statisch. Die Timing-Regler unten haben keine Wirkung, solange dies aktiviert ist."
L["Keep messages visible"] = "Nachrichten sichtbar halten"
L["Messages never fade out -- they stay on screen permanently. Overrides the fade out delay and duration below."] =
	"Nachrichten verblassen nie -- sie bleiben permanent auf dem Bildschirm. Überschreibt die Ausblendeverzögerung und -dauer unten."
L["Fade out delay"] = "Ausblendeverzögerung"
L["Fade in duration"] = "Einblenddauer"
L["Fade out duration"] = "Ausblenddauer"
L["Slide in duration"] = "Gleitdauer"
L["Misc"] = "Sonstiges"
L["Indent on line wrap"] = "Einzug bei Zeilenumbruch"
L["Adds an indent when a message wraps beyond a single line."] =
	"Fügt einen Einzug hinzu, wenn eine Nachricht über eine einzelne Zeile hinausgeht."
L["Mouse over tooltips"] = "Tooltips bei Mauszeiger"
L["Should tooltips appear when hovering over chat links."] =
	"Ob Tooltips erscheinen sollen, wenn man mit der Maus über Chat-Links fährt."
L["Text icons Y offset"] = "Text-Icons Y-Versatz"
L["Adjust this if text icons aren't centered."] = "Passe dies an, wenn Text-Icons nicht zentriert sind."
L["Show messages on hover"] = "Nachrichten bei Hover anzeigen"
L["When enabled, hovering over the chat reveals faded messages. When disabled, only scrolling reveals them."] =
	"Wenn aktiviert, zeigt das Überfahren des Chats verblasste Nachrichten an. Wenn deaktiviert, zeigt nur Scrollen sie an."
L["Scroll Indicator"] = "Scroll-Anzeige"
L["Hide scroll indicator"] = "Scroll-Anzeige ausblenden"
L['Hide the "Unread messages" and "Bring me to the present" indicator completely.'] =
	'Blendet die Anzeige für "Ungelesene Nachrichten" und "Zur Gegenwart bringen" vollständig aus.'
L["Indicator text color"] = "Anzeige-Textfarbe"
L['Color of the "Unread messages" and "Bring me to the present" text.'] =
	'Farbe des Textes "Ungelesene Nachrichten" und "Zur Gegenwart bringen".'
L["Indicator text opacity"] = "Anzeige-Textdeckkraft"
L["Opacity of the scroll indicator text."] = "Deckkraft des Scroll-Anzeige-Textes."
L["Indicator background color"] = "Anzeige-Hintergrundfarbe"
L["Background color behind the scroll indicator text."] = "Hintergrundfarbe hinter dem Scroll-Anzeige-Text."
L["Indicator background opacity"] = "Anzeige-Hintergrunddeckkraft"
L["Opacity of the scroll indicator background."] = "Deckkraft des Scroll-Anzeige-Hintergrunds."
L["Top bar"] = "Obere Leiste"
L["Add an outline to the chat tab text so it stands out instead of looking flat."] =
	"Fügt dem Chat-Tab-Text einen Umriss hinzu, damit er hervorsticht anstatt flach auszusehen."
L["The colour of the top bar background."] = "Die Farbe des Hintergrunds der oberen Leiste."
L["Show and hide the top bar instantly with no fade -- the tabs become static. The timing sliders below have no effect while this is on."] =
	"Zeigt und verbirgt die obere Leiste sofort ohne Einblenden -- die Tabs werden statisch. Die Timing-Regler unten haben keine Wirkung, solange dies aktiviert ist."
L["Keep tabs visible"] = "Tabs sichtbar halten"
L["Chat tabs never fade out -- they stay on screen permanently. Overrides the fade out delay and duration below."] =
	"Chat-Tabs verblassen nie -- sie bleiben permanent auf dem Bildschirm. Überschreibt die Ausblendeverzögerung und -dauer unten."
L["Show tabs on hover"] = "Tabs bei Hover anzeigen"
L["When enabled, chat tabs fade out when idle and reappear on mouse hover. When disabled, tabs are always visible."] =
	"Wenn aktiviert, verblassen Chat-Tabs im Leerlauf und erscheinen wieder bei Mauszeiger. Wenn deaktiviert, sind Tabs immer sichtbar."
L["Tab widths refit on /reload."] = "Tab-Breiten passen sich bei /reload an."

-- Tab Button Style
L["Tab Style"] = "Tab-Stil"
L["Choose the visual style for chat tab buttons."] = "Wähle den visuellen Stil für Chat-Tab-Schaltflächen."
L["Minimal"] = "Minimal"
L["Tab Corner Style"] = "Tab-Ecken-Stil"
L["Shape of tab button corners."] = "Form der Tab-Schaltflächen-Ecken."
L["Square"] = "Eckig"
L["Rounded"] = "Abgerundet"
L["Tab active color"] = "Tab Aktiv-Farbe"
L["Color of the selected/active tab background and text."] =
	"Farbe des Hintergrunds und Textes des ausgewählten/aktiven Tabs."
L["Tab inactive color"] = "Tab Inaktiv-Farbe"
L["Color of unselected tab backgrounds."] = "Farbe der Hintergründe nicht ausgewählter Tabs."
L["Tab background opacity"] = "Tab-Hintergrund-Deckkraft"
L["Opacity of the tab background and border."] = "Deckkraft des Tab-Hintergrunds und -Rahmens."
L["Tab spacing"] = "Tab-Abstand"
L["Horizontal spacing between tab buttons."] = "Horizontaler Abstand zwischen Tab-Schaltflächen."
L["Tab border thickness"] = "Tab-Rahmendicke"
L["Thickness of the outline border."] = "Dicke des Umrissrahmens."
L["Tab padding"] = "Tab-Innenabstand"
L["Padding from the dock edge."] = "Abstand vom Dock-Rand."

L["Show timestamps"] = "Zeitstempel anzeigen"
L["Prepend each message with a timestamp in [HH:MM] format."] =
	"Stellt jeder Nachricht einen Zeitstempel im Format [HH:MM] voran."

-- Buttons
L["Buttons"] = "Schaltflächen"
L["Hide Chat Menu button"] = "Chat-Menü-Schaltfläche ausblenden"
L["Hide the Chat Menu (speech bubble) button that provides access to languages and emotes."] =
	"Blendet die Chat-Menü-Schaltfläche (Sprechblase) aus, die Zugriff auf Sprachen und Emotes bietet."
L["Hide Social button"] = "Social-Schaltfläche ausblenden"
L["Hide the Social (friends) button that appears to the left of the chat frame."] =
	"Blendet die Social-Schaltfläche (Freunde) aus, die links vom Chat-Fenster erscheint."

-- About
L["About"] = "Über"
L["Author"] = "Autor"
L["Credits"] = "Danksagungen"
L["CleanerChat stands on the shoulders of two excellent addons. All credit for the original work belongs to their creators."] =
	"CleanerChat baut auf zwei hervorragenden Addons auf. Alle Anerkennung für die ursprüngliche Arbeit gebührt ihren Erstellern."
L["The immersive chat UI is built on Glass by mixxorz. This project keeps the spirit of Glass alive on 3.3.5."] =
	"Die immersive Chat-Oberfläche basiert auf Glass von mixxorz. Dieses Projekt hält den Geist von Glass auf 3.3.5 am Leben."
L["The message filtering is based on ChatCleaner by Lars Norberg (Goldpaw). Backported to 3.3.5."] =
	"Die Nachrichtenfilterung basiert auf ChatCleaner von Lars Norberg (Goldpaw). Rückportiert auf 3.3.5."

-- Channel abbreviations (match slash commands)
L["BGL"] = "BGL"
L["BG"] = "BG"
L["PL"] = "PL"
L["P"] = "P"
L["RL"] = "RL"
L["R"] = "R"
L["IL"] = "IL"
L["I"] = "I"
L["G"] = "G"
L["O"] = "O"
L["DG"] = "DG"
