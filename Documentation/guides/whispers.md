# 💬 Whispers

Send a short line, or a long text, to one player. Nothing shows in anyone's chat.

## What it does

- **Plain whispers**: one hidden message to one player, under a prefix you choose.
- **Streams**: a long text, up to about 90 KB, delivered to the player in one piece. An optional function is called each time a part arrives, so you can show progress.
- Notices when a player is offline: the whispers still waiting for that player are dropped and `PEER_OFFLINE` tells you.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)
local PREFIX = "MyAddonW"

local L = api:Locale({
  enUS = {
    WHISPER_FROM = "%s whispers: %s",
    ROUTE_RECEIVED = "Route %s received from %s, %d bytes",
  },
  frFR = {
    WHISPER_FROM = "%s vous chuchote : %s",
    ROUTE_RECEIVED = "Itinéraire %s reçu de %s, %d octets",
  },
})

api:OnWhisper(PREFIX, function(sender, text)
  api:Print(string.format(L.WHISPER_FROM, sender, text))
end)

api:Whisper(PREFIX, "Alice", "ping")
```

A stream, for anything longer than a line:

```lua
local L = api:L()     -- the table registered above

api:OnWhisperStream(PREFIX, "ROUTE", function(sender, body, id)
  api:Print(string.format(L.ROUTE_RECEIVED, id, sender, #body))
end, function(sender, id)
  api:Debug("receiving route " .. id .. " from " .. sender)
end)

api:WhisperStream(PREFIX, "Alice", "ROUTE", "frostfire", routeText)
```

## How it works

**Prefix.** The prefix is the label the game attaches to every hidden message, so that each addon recognizes its own. Pick one that no other addon uses, and keep it short: it takes room from your text.

**Plain whispers.** `api:Whisper(prefix, target, text)` queues one message. The receiver's function gets `fn(sender, text, distribution, prefix)`; `distribution` is the game's name for how the message arrived: it is always `"WHISPER"`, because your function is called for whispers only. The text must fit in 255 bytes minus the length of the prefix minus one. A longer text is a contract error.

**Streams.** `api:WhisperStream(prefix, target, op, id, body)` queues the whole body or nothing. A body too large for 400 parts is a contract error. The **op** is a short word of letters and digits, chosen by you, that says what kind of stream it is. The receiver's function gets `fn(sender, body, id, op)` once the whole body has arrived. The optional `onPart(sender, id, op)` is called for every part that arrives before the last one. If the parts stop arriving for 30 seconds, the body is discarded.

**Stream id.** The `id` is yours: pass a string without `:` to name the stream, or `nil` to let EbonAPI number it. The receiver sees it, which makes replies easy to match.

**Pace.** Whispers leave through a queue shared with the channel, one item every 0.15 seconds. An item is one part of a message, so a body that needs 100 parts takes at least 15 seconds, and longer when other addons are sending at the same time.

**Offline players.** When the game answers that the player is not found, EbonAPI drops every whisper still waiting for that player, fires `PEER_OFFLINE(name, dropped)`, and refuses new whispers to that player for 60 seconds. `api:Whisper`, `api:WhisperAll` and `api:WhisperStream` return `false` during that time. The game's "player not found" line stays out of every chat window, whoever whispered: EbonAPI, another addon or no one EbonAPI knows of. Only the line of a whisper the player wrote with `/w` (or a reply addon sent as a chat whisper) is kept, once per whisper. EbonAPI records each hidden line in its journal with the cause, `own`, `addon` or `unknown`. Players never see these conditions; **Diagnostics → Errors → Show network errors** shows the other network conditions as red lines. A player going offline is never shown, it is only recorded. The case of the player's name does not matter, and `PEER_OFFLINE` carries the name as the game wrote it.

**Names.** Targets and senders are character names without the realm.

**When your addon unloads.** Every whisper and stream listener your handle added is removed.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:OnWhisper(prefix, fn)` | prefix, `fn(sender, text, distribution, prefix)` | `true`, or `false` if this function is already registered for this prefix | prefix is not a non-empty string, fn is not a function |
| `api:OffWhisper(prefix, fn)` | prefix, function | `true` if something was removed | |
| `api:Whisper(prefix, target, text)` | prefix, player name, string | `true` when queued, `false` when refused | prefix invalid, text missing or too long |
| `api:WhisperAll(prefix, target, parts, count?)` | prefix, player name, list of strings, how many of them to send (all by default) | `true` when all are queued, `false` when none was queued | prefix invalid, or any of the parts to send missing or too long (nothing is queued then) |
| `api:OnWhisperStream(prefix, op, fn, onPart?)` | prefix, op, `fn(sender, body, id, op)`, `onPart(sender, id, op)` | `true`, or `false` if `fn` is already registered for this prefix and op | prefix invalid, op not alphanumeric, fn is not a function |
| `api:OffWhisperStream(prefix, op, fn)` | prefix, op, function | `true` if something was removed; the `onPart` given with `fn` is removed with it | |
| `api:WhisperStream(prefix, target, op, id, body)` | prefix, player name, op, string or `nil`, string | `true` when queued, `false` when the player is offline or the queue has no room | prefix invalid, op invalid, body not a string, id invalid, prefix and op leave no room, body needs more than 400 parts |

`api:WhisperAll` sends several plain messages to one player as a block: either every message is queued, or none. With `count` at 0 it returns `true` and sends nothing.

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `PEER_OFFLINE` | player name, whispers dropped | no | the game reported a player you whispered as not found |
| `SEND_FAILED` | `"whisper"`, prefix, target | no | the game refused a whisper when EbonAPI sent it |

## Limits

| | Value |
| --- | --- |
| Plain whisper | 255 bytes minus the prefix and one |
| Stream | 400 parts; about 90 KB with a short prefix, op and id |
| Incomplete stream | discarded after 30 seconds without a new part |
| Offline hold | 60 seconds without whispers to a player reported not found |
| Queue | 500 waiting items for whispers and channel messages together (a stream takes one item per part), one item leaving every 0.15 seconds |

### Error messages

| Message | When |
| --- | --- |
| `EbonAPI.Whisper.on expects a prefix, got <value>` | `OnWhisper` with an invalid prefix (`onStream` and `stream` use the same message with their own name) |
| `EbonAPI.Whisper.onStream expects an alphanumeric op, got <value>` | `OnWhisperStream` or `WhisperStream` with an invalid op (`stream` for the second) |
| `EbonAPI.Whisper.on expects a function for MyAddonW, got <type>` | `OnWhisper` without a function |
| `EbonAPI.Whisper.onStream expects a function for MyAddonW:ROUTE, got <type>` | `OnWhisperStream` without a function |
| `EbonAPI.Channel.whisper expects a prefix, got <value>` | `Whisper` with an invalid prefix |
| `EbonAPI.Channel.whisper: text missing or beyond <room> bytes for prefix MyAddonW` | the text is not a string or too long |
| `EbonAPI.Channel.whisperAll expects a prefix, got <value>` | `WhisperAll` with an invalid prefix |
| `EbonAPI.Channel.whisperAll: text missing or beyond <room> bytes for prefix MyAddonW` | one of the parts to send is not a string or too long; nothing is queued |
| `EbonAPI.Whisper.stream expects a text body for MyAddonW:ROUTE, got <type>` | `WhisperStream` with a body that is not a string |
| `EbonAPI.Whisper.stream: invalid stream id for MyAddonW:ROUTE` | the id is empty, not a string, or contains `:` |
| `EbonAPI.Whisper.stream: header too long for MyAddonW:ROUTE` | the prefix, op and id leave no room for a body |
| `EbonAPI.Whisper.stream: body of <length> bytes for MyAddonW:ROUTE, the limit is <limit> bytes` | the body needs more than 400 parts |

!!! tip "🎮 Try it"
    In the EbonAPI window, **Diagnostics → Reports → Trace** with the **Trace filter** on `wisp` lists the messages and streams received. The queue lines of **Status** read `queue: server=0 peers=0  sent channel=0 whispers=3`, and, when something was refused or dropped, `refused: offline=1 queue full=0 failed=0  lines dropped=0`.

## See also

- [Channel](channel.md) to reach everyone at once.
- [Sharing](sharing.md) when the goal is a dataset every player ends up with.
