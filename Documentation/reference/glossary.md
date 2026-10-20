# Glossary

The words these pages use. Each has one meaning.

**Addon name**
: The name given to `EbonAPI:NewAddon`. Your identity in every service: chat tag, saved data bucket, channel messages, datasets.

**Ash, Soul Ashes**
: The currency of a run. `spendable` is what you can still spend, `committed` what is already committed.

**Body**
: The text carried by a message: a server message, a channel line, a whisper.

**Brick**
: One kind of control the interface is built from, such as a button or a check box. A skin chooses one brick per slot, or brings its own.

**Brick slot**
: The place of one kind of brick, such as `button` or `toggle`. There are 16.

**Bridge**
: The service that reads server messages and sends yours: `api:OnServer`, `api:SendServer`.

**Build**
: One slot of Echo builds, as the server describes it: a slot number, a name and its echoes.

**Card**
: The box of an addon under **Connected addons**: its icon, name and version, its notes and author, and its buttons.

**Channel**
: The shared line EbonAPI gives every addon for talking to other players' copies of the same addon. Its messages carry your addon name and an op. EbonAPI joins it by itself once an addon is connected.

**Connection options**
: The fourth argument of `EbonAPI:NewAddon`: `icon`, `url`, `updates` and `version`.

**Consumer**
: An addon registered with `NewAddon`. **Diagnostics → Reports → Status** and **Connected addons** list them.

**Contract error**
: A Lua error raised because a call broke the rules: wrong type, invalid name, body too long. A bug to fix.

**Dataset**
: What `api:Share` publishes: a name, a state and a text, spread between players by EbonAPI.

**Development build**
: A version text with a suffix, such as `1.2.0-3`. It is never announced to other players as a newer release.

**EbonAPI window**
: EbonAPI's settings window, opened from **Esc → EbonAPI**. Its tabs hold EbonAPI's pages and those of every addon that registered options.

**Echo profile**
: The class, build slots, echoes and ban lists of a player, as EbonAPI tracks them, with the events that announce a change. See the [Echo profile](../guides/echo-profile.md) guide.

**Echo, echoes**
: The perks of a build. Each has a spell id, a number of stacks and a locked flag.

**Element**
: One piece of the Kit, such as a button, a list or a table, made with `container:Add` or `api:Create`.

**Feature**
: A flag telling whether a piece of ProjectEbonhold is present: `api:HasFeature`, `FEATURE_CHANGED`.

**Handle**
: The object `EbonAPI:NewAddon` returns, `api` in every example. It carries every service.

**Hash**
: A short text computed from some content: the same content always gives the same hash. The echo profile events carry one, so you can tell that a build did not change without reading it.

**Key**
: What other players know of a dataset before they have its text: your addon name, the dataset name and its state.

**Kit**
: The windows and elements EbonAPI lends to addons for their own interface.

**Loadout**
: A skill tree layout from the server: an id, a name and the rank of each node.

**Migration**
: A function that runs once, per account or per character, to move saved data to a new layout.

**Minimap button**
: An addon's button around the minimap, from `api:MinimapButton`. The player places it, groups it in EbonAPI's button, or hides it.

**Options table**
: The description of an addon's settings, passed to `api:Options`. EbonAPI validates and renders it in its window. Its types and fields are listed in [Interface](../guides/interface.md#the-options-table).

**Op**
: The short alphanumeric word that names a kind of channel line or whisper stream within an addon.

**Opcode**
: The number that names a kind of server message. `EbonAPI.SS` and `EbonAPI.CS` give them names.

**Packet, part**
: A body too long for one message is sent in several pieces and put back together by the receiver.

**Palette**
: The named colors of a skin, such as `heading` or `muted`.

**Parameter**
: One appearance setting offered by EbonAPI: background, accent, scale, opacity, shadow, corners, tabs, locked. In an addon's own windows, the player's choice wins, then the addon's value, then the value of the player's skin.

**Peer**
: Another player exchanging with this one over the channel or by whisper.

**Prefix**
: The label of an addon whisper. Each addon chooses its own.

**Queue**
: The waiting line for everything EbonAPI sends, to the server, to the channel and to other players. Your calls join it, so a send can leave a moment after you call it. It sends one message every 0.15 seconds.

**Run**
: The current Ebonhold run, as the server describes it: soul points, resurrections, rerolls, banishes, freezes.

**Scope**
: Where a saved value lives: the account, or one character.

**Server state**
: What EbonAPI parsed from the server so far: run, intensity, ash, multiplier, builds, loadout. `api:State()`.

**Service**
: One group of handle methods: events, logging, storage, localization, connection, interface, Kit, minimap button, server, channel, whispers, sharing, versions, echo profile, performance.

**Session**
: A period of play. A new session starts when a character logs in 10 minutes or more after the last time it was seen.

**Skin**
: A Lua file that sets the look of the interface: its parameters, its palette and its bricks. The player picks one under **Appearance**.

**Skin parameter**
: One value a skin sets, such as `header.height`. There are 504, listed in [Skin parameters](skin-parameters.md).

**State (of a dataset)**
: The whole number that says how new a dataset is. By default, a higher state replaces a lower one.

**Sticky event**
: An event that keeps its last value and replays it to every later subscriber.

**Store**
: What `api:DB()` returns: `db.account`, `db.char` and the migration methods.

**Stream**
: A whisper body split into parts and reassembled on the other side, with an op and an id.

**Ticker**
: A function that runs again and again at an interval you choose, set with `api:Tick`.

**Trace**
: The last 128 events EbonAPI recorded, shown by **Diagnostics → Reports → Trace**.

**Translation table, `L`**
: The live table `api:Locale` returns, English underneath and the active language on top.

**Whisper**
: A message from your addon to one player. It does not show in chat.

**WoW event**
: An event of the game client, such as `PLAYER_ENTERING_WORLD`, listened to with `api:OnEvent`.
