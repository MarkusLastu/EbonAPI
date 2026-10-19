# Options window

EbonAPI has no slash command. Everything a player or a developer needs is in its window.

## Opening it

| From | How |
| --- | --- |
| The game menu | **Esc → EbonAPI**, the button just above **Log Out** |
| The interface options | **Interface → AddOns → EbonAPI → Open the EbonAPI window** |
| The minimap | EbonAPI's own button: a right-click, or a click when no addon is grouped in it; see [Minimap button](../guides/minimap.md) |
| Code | `EbonAPI:OpenOptions()`, or `api:OpenOptions()` for your own tab; see [Interface](../guides/interface.md) |

**Esc** closes it. The window keeps its position between sessions. **Lock positions** keeps the windows and the minimap buttons from moving.

## EbonAPI's pages

| Page | Contents |
| --- | --- |
| General | **Language**: the shared language; every addon that follows it changes too. **Minimap button**: **Always show the EbonAPI button**, **Lock its position**, **Reset its position** |
| Appearance | **Skin** (the list of skins; **Reload the interface** appears while a chosen skin waits for a reload), **Colors** (**Background**, **Accent**), **Windows** (**Interface scale**, **Background opacity**, **Shadow under windows**, **Corners**), **Layout** (**Tabs** on the left or on the right, **Lock positions**), **Defaults** |
| Connected addons | one card per addon: icon, version, notes and author, a newer version when one was seen, **Settings**, **Project page** and its minimap button; see [Your card](../guides/connection.md#your-card). A skin may show a plain list instead |
| Diagnostics | the reports below, the debug switches, the performance tools |

Each connected addon that registered options has its own tab in the column, under **Addons**; its groups are tabs under it. The search box at the top finds an option by name in every tab.

**Defaults** gives every appearance setting its default value back. Addons then apply their own values again. A skin chosen under **Skin** applies when the interface reloads.

The skin decides how the window is laid out: some skins open each page in a window of its own, others add an icon bar, editor tabs or a status bar. See [Skins](../guides/skins.md).

## Diagnostics

The **Result** area shows the report you chose. **Status** and **Senders** are in the player's language. **Trace**, **Saved data** and **Opcodes** are always in English.

| Control | Effect |
| --- | --- |
| **Reports → Status** | the state of every service and of the registered addons |
| **Reports → Trace** | the 30 latest trace entries, newest first, filtered by **Trace filter**; `empty trace` when there is none |
| **Reports → Trace filter** | **Everything**, or one of the kinds traced so far this session, such as `recv`, `chan` or `share` |
| **Reports → Saved data** | a summary of the saved data, one line per addon |
| **Reports → Opcodes** | the known opcodes, server to client then client to server |
| **Reports → Senders** | the senders observed on the server bridge, each with its count, then a `strict = ` line; `no sender observed` when there is none |
| **Errors → Show network errors** | shows on screen what EbonAPI always records in its journal: a player who went offline, a full send queue, a shared value that came late; off by default |
| **Debug messages → All addons** | turns `api:Debug` output on for every addon |
| **Debug messages → Addon**, **For the chosen addon** | turns it on for one addon; unavailable while **All addons** is on |
| **Performance → Addon** | **All addons** or one addon |
| **Performance → Measure** | for one addon: memory, running frames and CPU; for **All addons**: one line per addon with its memory and its running frames. The addon list includes EbonAPI itself. See [Performance](../guides/performance.md) |
| **Performance → Reset counters** | a new baseline for memory and CPU |
| **Performance → Free memory** | a full collection, memory before and after |

## Reading Status

| Line | Meaning |
| --- | --- |
| `version 2.0.0` | EbonAPI's version |
| `consumers: AutoCallboard, MyAddon` | the addons that called `NewAddon`; `no consumer registered` when there is none |
| `server bridge: 42 messages received, last 3s ago` | server messages seen this session; `server bridge: no message received yet` before the first |
| `sent=5 queued=0 streams=0` | messages sent to the server, messages waiting to be sent, and multi-part server messages being put together |
| `channel ebonapi: joined (index 5, for 120s)` | the shared channel; `joining... (2 requests)` while trying; `not needed by any consumer` without addons |
| `queue: server=0 peers=3  sent channel=12 whispers=40` | lines waiting for the server and for other players, then channel lines and whispers sent |
| `refused: offline=2 queue full=0 failed=0  lines dropped=0` | only when something was refused |
| `profile: sent P=1 D=3 X=0, received 8, rejected 0` | echo profile announcements sent, received, and rejected as malformed |
| `versions: EbonAPI 2.0.0, MyAddon 1.2.0 (1.3.0 available)` | every addon that declared a version, EbonAPI included |
| `shares: 4 key(s) from 2 addon(s), 6 player(s) seen, 3 received, 0 refused` | the sharing service |
| `rejected=...` and `unreadable bodies=...` | only when a server message or a saved entry had to be dropped or repaired |
| `ProjectEbonhold: detected` | or `absent`; followed by the features present, then the missing ones in grey after `none:` |
| `character scope: Alice-Ebonhold` | the key of the character's saved data; `not resolved yet` before it is known |

## Reading Trace

Each line gives the age of the entry, its kind, the addon concerned and a description.

When a player reports a problem, ask for a screenshot of **Diagnostics → Reports** after **Status**, then after **Trace**.
