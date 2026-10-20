# Limits

Every size, count and delay a developer may run into, in one place. Sizes are in bytes. The values that a skin sets (sizes, spacing, durations of the interface elements) are in [Skin parameters](skin-parameters.md).

## Names

| | Limit |
| --- | --- |
| Addon name | 1 to 32 characters, `A-Z a-z 0-9 _` (`EbonAPI.NAME_MAX` is 32) |
| Dataset name, share key name | 1 to 32 characters, `A-Z a-z 0-9 _` |
| Channel op, whisper stream op | letters and digits |
| Whisper prefix | a non-empty text |
| Whisper stream id | a non-empty text without `:`, or `nil` to let EbonAPI choose |
| Version text | `major.minor.patch`, optionally followed by `-` and digits, at most 20 characters |
| Window id, shortcut id | letters, digits and `_`, at least one |
| Connection options | `icon`, `url`, `updates`, `version` |

## Events and tickers

| | Limit |
| --- | --- |
| Arguments of an event | 6, after the event name. A seventh is dropped |
| Ticker interval | a number of seconds, more than `0`. Any other value raises an error |
| Ticker rate | a ticker runs at most once per frame. The time a slow frame adds beyond the interval is taken off the next wait, so the ticker does not drift. Missed runs are not made up |

## Localization

| | Limit |
| --- | --- |
| Fallback language | `enUS`. Every `L` table is filled with `enUS` first, then with the active language |
| Language alias | `esMX` uses `esES` when no addon registers `esMX` |
| Missing key | `L[key]` is `nil`. A widget bound with `api:Localized` shows the key itself |

## Interface

| | Limit |
| --- | --- |
| Parameters | `background` and `accent` 0x000000 to 0xFFFFFF, `scale` 0.2 to 1.4, `opacity` 0.25 to 1, `shadow` 0 to 1, `corners` 0 to 16 whole, `tabs` `LEFT` or `RIGHT`, `locked` boolean |
| Slider steps in the EbonAPI window | `scale` 0.05, `opacity` 0.01, `shadow` 0.05, `corners` 1 |
| Option types | `group`, `header`, `description`, `toggle`, `range`, `select`, `color`, `execute`, `input` |
| Option width | `half`, `normal`, `double`, `full`, or a number |
| Option order | 100 when `order` is missing or is not a number |
| Inherited from the parent group | `handler`, `get`, `set`, `func`, `disabled`, `hidden`. For the first four, the nearest group wins. A group with `disabled` or `hidden` true applies it to everything inside, and a child cannot cancel it |
| Option fields that can be a method name | `get`, `set`, `func`, `disabled`, `hidden`, `values` |
| Option `range` step | `step`, else 0.01 for a percent, else 1 when the range spans 10 or more, else 0.01. The value is kept between `min` and `max` |
| Option `input` with `multiline = true` | the number of lines comes from the skin (`widgets.input.lines`, 2 to 30) |
| Tabs in the column | the root of an options table and one level of groups |
| Control width unit | the skin's `page.unit`, 170 pixels in Azeroth, from 60 to 600 |
| Pages remembered for back and forward | 50 |
| Tabs open at once in the page strip | the skin's `page.strip.tabs`, 1 to 12, 1 in Azeroth. With 1, no tab is remembered. When there are more, the oldest other tab closes |
| Kit elements | 28, listed in [Elements](elements.md) |
| Kit `layout` | `VERTICAL`, `HORIZONTAL`, `GRID`, `FLOW`, `NONE` |
| Kit `move` | `ALWAYS`, `SHIFT`, `HANDLE`, `NONE` |
| Kit `combat` | `HIDE`, `FADE` |
| Kit `scroll` | `NONE`, `VERTICAL`, `HORIZONTAL`, `BOTH` |
| Dialogs | one at a time: opening a dialog cancels the open one |
| Dialog text field | `maxLetters`, unlimited when absent |
| Notifications | no limit on their number |
| Key chosen with a `shortcut` element | `LSHIFT`, `RSHIFT`, `LCTRL`, `RCTRL`, `LALT` and `RALT` alone cannot be the key. A combination is saved as `ALT-CTRL-SHIFT-` then the key. `api:SetShortcut` stores the text as given |
| Kit timer text | refreshed every `kit.timer.every` seconds, 0.01 to 1, 0.1 (ten times a second) in Azeroth |
| Kit `FLOW` layout | without `wrap`, a line wraps at the container's `width` minus twice its padding, else at the skin's `kit.wrap`, 40 to 2000, 320 in Azeroth |
| Minimap button | one per addon; `display` `BUTTON`, `GROUP` or `HIDDEN` |
| Minimap shapes understood | `ROUND`, `SQUARE`, `CORNER-*`, `SIDE-*`, `TRICORNER-*`. Any other shape is drawn as `ROUND` |

## Skins

| | Limit |
| --- | --- |
| Skin parameters | 504, listed in [Skin parameters](skin-parameters.md): 8 player settings, 33 palette colors and 463 others |
| Brick slots | 17 |
| Colors | whole number 0x000000 to 0xFFFFFF; palette transparency 0 to 1 |
| Contrast | `contrast.minimum` 1 to 21 (4.5 in Azeroth), `contrast.light` 0 to 1 (0.96), `contrast.dark` 0 to 1 (0.04) |
| Skin choice | read once per session, at EbonAPI's own load: a new skin applies at the next reload of the interface |
| Default skin | `Azeroth`. A skin without `parent` starts from it |
| Skin files | `Interface\AddOns\EbonAPI\Skins\<skin name>\` |

## Sending

| | Limit |
| --- | --- |
| Queue pace | one line every 0.15 seconds, shared by every addon. Server messages go before channel and whisper lines |
| Channel and whisper queue | 500 lines waiting; a call that would go beyond returns `false` |
| Server messages | never refused for lack of room |
| Offline hold | 60 seconds without whispers to a player reported not found |

## Server

| | Limit |
| --- | --- |
| Outgoing message | 240 bytes for the opcode (as digits), one separator byte and the body together |
| Incoming message | 400 parts at most. It is dropped when no new part arrives for 20 seconds (`STREAM_TIMEOUT`) |
| `api:RequestServer` throttle | none unless you pass a `minInterval` above 0 |
| Soul Ashes amount | a whole number up to 18,446,744,073,709,551,615; a message with a larger amount is rejected |

The opcodes are listed in the [Server guide](../guides/server.md#opcodes).

## Channel

| | Limit |
| --- | --- |
| Packets per body | 16 |
| Body | about 3,600 bytes with short names; the error message gives the exact figure. It cannot contain `\|` |
| Reassembly | 30 seconds without a new part |

## Whispers

| | Limit |
| --- | --- |
| Plain whisper | 255 bytes minus the prefix and one separator |
| Stream | 400 parts, about 90 KB with a short prefix, op and id. A larger body raises an error that gives the exact figure |
| Reassembly | 30 seconds without a new part |

## Sharing

| | Limit |
| --- | --- |
| Text | 32,768 bytes |
| State | whole number from 0 to 9,007,199,254,740,991 |
| Announce | 2 seconds after joining the channel, 15 seconds after a change (later changes do not extend the wait), manual once every 30 seconds |

## Echo profile

| | Limit |
| --- | --- |
| Classes | 1 to 10 |
| Slots | 1 to 20 |
| Echoes per build | 150, stacks up to 63; extra echoes are dropped |
| Locked echoes per build | 150; extra ids are dropped |
| Ban lists | 20 lists of 150 echoes; extra lists and ids are dropped |
| Echo spell ids | 200000 to 204095 |

## Numbers and sizes

| | Limit |
| --- | --- |
| `Format.compact` | Below 10000: the number rounded to a whole number, digits grouped by three (`5 000`). `k` with one decimal from 10000, `M` with two decimals from 999,950 (shown as `1.00M`), `G` with two decimals from 999,995,000 (shown as `1.00G`). The unit letters and the group separator follow the player's language |
| `Format.bytes` | KB, then MB from 1,048,576 bytes |

## Sessions and diagnostics

| | Limit |
| --- | --- |
| New session | after 10 minutes away |
| Update notice | once per session and per version |
| Trace | the last 128 entries kept; the window shows the last 30 |
| Performance reports kept | 20 per addon, the oldest is removed |
| Debug target in the window | `EbonAPI` until the player chooses another addon |
