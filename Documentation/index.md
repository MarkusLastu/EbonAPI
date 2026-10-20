# EbonAPI for addon developers

**The shared foundation of Ebonhold addons: server, players, data, language and interface.**

EbonAPI 2.0.0 · World of Warcraft 3.3.5a (Interface 30300) · Lua 5.1

EbonAPI is an addon that other addons build on. It does, once and for all of them, what every Ebonhold addon would otherwise rewrite: read what the server sends, talk to the other players, save data, follow the player's language, draw windows and settings, announce updates, and help you find what went wrong. Your addon asks for a **handle** and reaches every service through it.

These pages are written for developers. Players should read the [addon README on GitHub](https://github.com/Siphelis/EbonAPI#readme) instead.

## Start here

<div class="grid cards" markdown>

-   :material-rocket-launch:{ .lg .middle } __1 · Getting started__

    ---

    Load EbonAPI, get your handle, start when `READY` fires.

    [:octicons-arrow-right-24: Getting started](getting-started.md)

-   :material-compass:{ .lg .middle } __2 · Concepts__

    ---

    The handle, the lifecycle, events, names, sending and errors.

    [:octicons-arrow-right-24: Concepts](concepts.md)

-   :material-satellite-variant:{ .lg .middle } __3 · Talk to the server__

    ---

    Receive run data, Soul Ashes and builds. Send requests.

    [:octicons-arrow-right-24: Server](guides/server.md)

-   :material-account-group:{ .lg .middle } __4 · Talk to other players__

    ---

    Broadcast, whisper, and share datasets that spread on their own.

    [:octicons-arrow-right-24: Channel](guides/channel.md)

-   :material-chef-hat:{ .lg .middle } __5 · Cookbook__

    ---

    Complete addons to copy, each one explained line by line.

    [:octicons-arrow-right-24: Cookbook](cookbook/index.md)

</div>

## Services

Every service hangs off the handle returned by `EbonAPI:NewAddon`. Use only the ones you need.

| Service | Gives you | Guide |
| --- | --- | --- |
| 🚀 Lifecycle and events | `READY`, EbonAPI events, values EbonAPI remembers for late subscribers (sticky events), WoW events, tickers | [Events](guides/events.md) |
| 📝 Logging | Chat output tagged with your addon name, a debug toggle, a trace | [Logging](guides/logging.md) |
| 💾 Storage | Account and character data with defaults and one-shot migrations | [Storage](guides/storage.md) |
| 🌍 Localization | One language for every addon, English fallback, self-refreshing widgets | [Localization](guides/localization.md) |
| 🔌 Connection | Your icon and project link, your card in the EbonAPI window, links opened for the player | [Connecting your addon](guides/connection.md) |
| 🪟 Interface | Your settings in the EbonAPI window, shared appearance parameters for your own | [Interface](guides/interface.md) |
| 🧱 Kit | Windows and 28 elements for your own interface, dialogs, menus, notifications, shortcuts | [Kit](guides/kit.md) |
| 🧭 Minimap button | A button around the minimap that the player places, groups or hides | [Minimap button](guides/minimap.md) |
| 🎨 Skins | The whole look of the interface, chosen by the player, written in a Lua file | [Skins](guides/skins.md) |
| 🛰️ Server bridge | Server messages by opcode (the number that names a kind of message), parsed run state, throttled requests | [Server](guides/server.md) |
| 🏰 ProjectEbonhold | Feature detection and safe access to the client services | [ProjectEbonhold](guides/ebonhold.md) |
| 📡 Channel | Broadcast to every player who runs your addon | [Channel](guides/channel.md) |
| 💬 Whispers | Direct messages and long streams to one player | [Whispers](guides/whispers.md) |
| 🔄 Sharing | Publish datasets; EbonAPI spreads them between players | [Sharing](guides/sharing.md) |
| 🆕 Versions | Update notices when a newer release is seen | [Versions](guides/versions.md) |
| 🧬 Echo profiles | Class, build slots and ban lists of other players | [Echo profile](guides/echo-profile.md) |
| 📊 Performance | Memory, CPU and running frames per addon | [Performance](guides/performance.md) |

## Reference

| Page | Contents |
| --- | --- |
| [Handle](reference/handle.md) | Every method of the handle, grouped by service |
| [Events catalog](reference/events.md) | Every event, its arguments, and whether it is sticky |
| [Elements](reference/elements.md) | The 28 elements of the Kit, their fields and methods |
| [Skin parameters](reference/skin-parameters.md) | Every parameter a skin can set |
| [Modules](reference/modules.md) | `EbonAPI.State`, `EbonAPI.Ebonhold`, `EbonAPI.Profile`, `EbonAPI.Format`, `EbonAPI.Lib`, opcodes, constants |
| [Limits](reference/limits.md) | Every size, count and delay, in one table |
| [Errors](reference/errors.md) | Every error message and how to fix the call |
| [Options window](reference/options-window.md) | How players open it, its pages, and the diagnostics while you develop |
| [Glossary](reference/glossary.md) | The words these pages use, one meaning each |

## Conventions

- `api` always means the handle returned by `EbonAPI:NewAddon`.
- `MyAddon` is the example addon. Replace it with your own name.
- A code block with a file name above it goes in that file. The others are excerpts: they expect `api` to exist already.
- Callouts mark what matters:

!!! note
    A rule worth knowing before you write the next line.

!!! tip "🎮 Try it"
    Where to see the result in game, in the EbonAPI window.

!!! warning
    A trap that breaks your addon if you miss it.
