EbonAPI = EbonAPI or {}
EbonAPI.Share = {}

local Share = EbonAPI.Share
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local DB = EbonAPI.DB
local Hash = EbonAPI.Hash
local Keys = EbonAPI.Keys
local Queue = EbonAPI.Queue
local Channel = EbonAPI.Channel
local Whisper = EbonAPI.Whisper
local Handle = EbonAPI.Handle

local type, pairs, next, error, tonumber, pcall = type, pairs, next, error, tonumber, pcall
local match, gmatch, len, sub, format, concat, sort = string.match, string.gmatch, string.len, string.sub, string.format, table.concat, table.sort
local random, floor, ceil = math.random, math.floor, math.ceil

local NAME = "EbonAPI"
local PREFIX = "EbonAPI"
local TEXT_MAX = 32768
local JOIN_DELAY = 2
local CHANGE_DELAY = 15
local DIRECT_DELAY = 5
local DIRECT_BUDGET = 48
local DIRECT_WINDOW = 60
local ANNOUNCE_HOLD = 60
local MANUAL_COOLDOWN = 30
local REPLY_MIN, REPLY_MAX = 1, 5
local ROUND_INTERVAL = 120
local PEER_TTL = 600
local FETCH_TIMEOUT = EbonAPI.Pace and EbonAPI.Pace.LIMIT_MIN or 30
local ACK_MAX = 120
local FETCH_WINDOW = 8
local FETCH_PER_PEER = 4
local SERVE_MAX = 2
local SERVED_KEEP = 8
local SERVED_LIST = 3
local NOTE_DELAY = 10
local COHORT_MAX = 4
local COHORT_TTL = 60
local ASK_TTL = 60
local RETRY_MIN, RETRY_MAX = 2, 5
local SERVE_WINDOW = 30
local REQUEST_COOLDOWN = 10
local LATE_TTL = 600
local MUTE_BASE = 300
local SLOW_TTL = 900
local SLOW_MAX = EbonAPI.Pace and EbonAPI.Pace.LIMIT_MAX or 180
local MUTE_MAX = 1800
local LEVEL = 3
local SUFFIX = ";" .. LEVEL
local PACKETS = Keys.PACKETS
local PART = Hash.LENGTH
local HEX = "0123456789abcdef"

Share.PREFIX = PREFIX
Share.TEXT_MAX = TEXT_MAX
Share.JOIN_DELAY = JOIN_DELAY
Share.CHANGE_DELAY = CHANGE_DELAY
Share.DIRECT_DELAY = DIRECT_DELAY
Share.DIRECT_BUDGET = DIRECT_BUDGET
Share.DIRECT_WINDOW = DIRECT_WINDOW
Share.ANNOUNCE_HOLD = ANNOUNCE_HOLD
Share.MANUAL_COOLDOWN = MANUAL_COOLDOWN
Share.REPLY_MAX = REPLY_MAX
Share.ROUND_INTERVAL = ROUND_INTERVAL
Share.FETCH_TIMEOUT = FETCH_TIMEOUT
Share.ACK_MAX = ACK_MAX
Share.FETCH_WINDOW = FETCH_WINDOW
Share.FETCH_PER_PEER = FETCH_PER_PEER
Share.SERVE_MAX = SERVE_MAX
Share.REQUEST_COOLDOWN = REQUEST_COOLDOWN
Share.LATE_TTL = LATE_TTL
Share.MUTE_BASE = MUTE_BASE
Share.SLOW_TTL = SLOW_TTL
Share.SLOW_MAX = SLOW_MAX
Share.MUTE_MAX = MUTE_MAX
Share.LEVEL = LEVEL

local store = nil
local enabled = false
local ticking = false
local rounding = false
local serveUntil = nil
local announceAt = nil
local lastManual = nil
local peers = {}
local replies = {}
local fetching = {}
local live = 0
local free = {}
local freeCount = 0
local waiting = {}
local wKey = {}
local holders, delayed, loads = {}, {}, {}
local serving, servedTo = {}, {}
local cohort = {}
local wFirst, wLast = 1, 0
local recent = {}
local late, lateAt, lateLimit = {}, {}, {}
local answered, mute, muteStep, lost = {}, {}, {}, {}
local slow = {}
local differing = {}
local asked = {}
local digits = {}
local rules = {}
local outbox, outOrder, outCount = {}, {}, 0
local outAt = nil
local lastMine, sentFrom = nil, nil
local inbound = false
local winAt, winLines = {}, {}
local winFirst, winLast = 1, 0

Share.sent = { lines = 0, keys = 0, data = 0, direct = 0 }
Share.received = 0
Share.refused = 0

local Problems = EbonAPI.Problems

Problems.declare("EbonAPI", "EBONAPI", {
  ["SHARE.REFUSED"] = { class = "rejet" },
  ["SHARE.FETCH_EXPIRED"] = { class = "echec", key = "peer", quiet = true },
  ["SHARE.LATE_ANSWER"] = { class = "rejet" },
})

local function refuse(sender, key, reason)
  Share.refused = Share.refused + 1

  Problems.reject("EbonAPI", "SHARE.REFUSED", { sender = sender, key = key, reason = reason })
end

local function now()
  return (GetTime and GetTime()) or 0
end

local function texts()
  if not store then
    store = DB.store("EbonAPI", { account = { shared = {} } })
  end

  local held = store.account.shared

  if type(held) ~= "table" then
    held = {}
    store.account.shared = held
  end

  return held
end

function Share.set(addon, name, state, text)
  state = Keys.check(addon, name, state, 3)

  if type(text) ~= "string" then
    error(format('EbonAPI: %s: share "%s": text must be a string, got %s', addon, name, type(text)), 2)
  end

  if len(text) > TEXT_MAX then
    error(format('EbonAPI: %s: share "%s": text is %d bytes long (maximum %d)', addon, name, len(text), TEXT_MAX), 2)
  end

  local held = texts()
  local own = held[addon]

  if Keys.get(addon, name) == state and ((own and own[name]) or "") ~= text then
    error(format('EbonAPI: %s: share "%s": text differs but the state is still %s (raise the state to share a new text)', addon, name, state), 2)
  end

  if not own then
    own = {}
    held[addon] = own
  end

  local changed = own[name] ~= text

  own[name] = text

  if Keys.put(addon, name, state) then
    changed = true
  end

  return changed
end

function Share.remove(addon, name)
  local held = texts()
  local own = held[addon]

  if own then
    own[name] = nil

    if next(own) == nil then
      held[addon] = nil
    end
  end

  return Keys.remove(addon, name)
end

function Share.get(addon, name)
  local own = texts()[addon]

  if not own then
    return nil, Keys.get(addon, name)
  end

  return own[name], Keys.get(addon, name)
end

-- The parts line, cut to a body budget when one is given (a channel line of the 2.1.x format).
local function line(budget)
  local addons = Keys.addons()
  local room = budget and budget - len(SUFFIX)
  local out = {}
  local size = -1

  for i = 1, #addons do
    local item = addons[i] .. "=" .. Keys.part(addons[i])

    size = size + len(item) + 1

    if room and size > room then
      break
    end

    out[i] = item
  end

  return concat(out, ",") .. SUFFIX
end

Share.line = line

local function parseBeacon(body)
  return match(body, "^([^;]*);([%w%-_]+);(%d+)$")
end

local function escape(text)
  return (string.gsub(text, "[%c|`]", function(char)
    return format("`%02x", string.byte(char))
  end))
end

local function unescape(text)
  local bad = false
  local plain = string.gsub(text, "`(%x?%x?)", function(code)
    if len(code) ~= 2 then
      bad = true
      return ""
    end

    return string.char(tonumber(code, 16))
  end)

  if bad then
    return nil
  end

  return plain
end

local function parseLine(body)
  local parts = {}

  for addon, part in gmatch(body, "([%w_]+)=([%w%-_]+)") do
    if len(part) == Hash.LENGTH then
      parts[addon] = part
    end
  end

  return parts
end

local function compare(theirs)
  local wanted, any = {}, false
  local addons = Keys.addons()
  local mine = {}

  for i = 1, #addons do
    local addon = addons[i]

    mine[addon] = Keys.part(addon)

    if not theirs[addon] then
      any = true
    end
  end

  for addon, part in pairs(theirs) do
    if mine[addon] ~= part then
      wanted[#wanted + 1] = addon
      any = true
    end
  end

  sort(wanted, Hash.before)

  return wanted, any
end

local function throttled(peer, kind)
  local key = peer .. ":" .. kind
  local current = now()
  local last = recent[key]

  if last and current - last < REQUEST_COOLDOWN then
    return true
  end

  recent[key] = current

  return false
end

local tick
local pump
local enqueue

local function arm()
  if not ticking then
    ticking = true
    Bus.tick("EbonAPI:share", 1, tick)
  end
end

local function idle()
  return announceAt == nil and outAt == nil and next(replies) == nil and next(fetching) == nil
    and next(delayed) == nil and wFirst > wLast
end

local function busy()
  return live > 0 or wFirst <= wLast or next(delayed) ~= nil
end

local function announce()
  if not Channel.isJoined() then
    announceAt = nil
    return false
  end

  local body = (EbonAPI.Version.line() or "") .. ";" .. Keys.globalDigest() .. SUFFIX

  if not Channel.say(NAME, "B", body) then
    return false
  end

  announceAt = nil
  Share.sent.lines = Share.sent.lines + 1
  serveUntil = now() + SERVE_WINDOW
  Log.trace("share", nil, "B")
  -- Legacy.lua loads after Share.lua and calls back into it: look it up at call time.
  EbonAPI.Legacy.announce()

  return true
end

local function schedule(delay)
  if not announceAt then
    announceAt = now() + delay
    arm()
  end
end

local function windowUsed(current)
  while winFirst <= winLast and current - winAt[winFirst] >= DIRECT_WINDOW do
    winAt[winFirst], winLines[winFirst] = nil, nil
    winFirst = winFirst + 1
  end

  if winFirst > winLast then
    winFirst, winLast = 1, 0
    return 0
  end

  local used = 0

  for index = winFirst, winLast do
    used = used + winLines[index]
  end

  return used
end

local function advance(old, new)
  if not old or not new or old == new then
    return
  end

  for _, info in pairs(peers) do
    if info.digest == old then
      info.digest = new
    end
  end
end

local function flushOutbox()
  local current = now()
  local used = windowUsed(current)
  local kept, keptCount = {}, 0
  local blocked = false

  for index = 1, outCount do
    local key = outOrder[index]
    local addon, name = match(key, "^([%w_]+)%.([%w_]+)$")
    local held, state = Share.get(addon, name)

    if state ~= nil and not blocked then
      local body = key .. ":" .. state .. ":" .. escape(held or "")
      local op = "U"
      local lines = Channel.packets(NAME, op, body)

      if not lines then
        op, body, lines = "N", key .. ":" .. state, 1
      end

      if used + lines > DIRECT_BUDGET then
        blocked = true
        keptCount = keptCount + 1
        kept[keptCount] = key
      elseif Channel.say(NAME, op, body) then
        outbox[key] = nil
        used = used + lines
        winLast = winLast + 1
        winAt[winLast], winLines[winLast] = current, lines
        Share.sent.direct = Share.sent.direct + lines
        Log.trace("share", nil, op, key)
      else
        blocked = true
        keptCount = keptCount + 1
        kept[keptCount] = key
      end
    elseif state == nil then
      outbox[key] = nil
    else
      keptCount = keptCount + 1
      kept[keptCount] = key
    end
  end

  for index = 1, outCount do
    outOrder[index] = kept[index]
  end

  outCount = keptCount

  if outCount == 0 then
    outAt = nil
    advance(sentFrom, Keys.globalDigest())
    sentFrom = nil
  elseif winFirst <= winLast then
    outAt = winAt[winFirst] + DIRECT_WINDOW
  else
    outAt = current + 1
  end
end

local function release(slot)
  slot.peer = nil
  freeCount = freeCount + 1
  free[freeCount] = slot
end

local function close(key)
  local slot = fetching[key]

  fetching[key] = nil
  live = live - 1
  slot.key = nil

  local count = (loads[slot.peer] or 1) - 1

  loads[slot.peer] = count > 0 and count or nil

  if not loads[slot.peer] then
    lost[slot.peer] = nil
  end

  if not slot.queued then
    release(slot)
  end
end

local function forget(peer)
  local dropped = 0

  for _, list in pairs(holders) do
    if list[peer] then
      list[peer] = nil
      dropped = dropped + 1
    end
  end

  return dropped
end

-- A holder that has never answered and stays silent is not asked again for a while: 5 minutes, then
-- twice as long each time. A holder that has answered before is only slow: it keeps its place.
-- Any answer from a muted holder, even a late one, clears that.
local function muted(peer)
  local until_ = mute[peer]

  if not until_ then
    return false
  end

  if now() >= until_ then
    mute[peer] = nil
    return false
  end

  return true
end

-- The silence given to a holder when nothing else is known: the limit of the moment from Pace, never
-- under FETCH_TIMEOUT, which is also what it falls back on when Pace is missing or answers no number.
local function paceLimit()
  local Pace = EbonAPI.Pace
  local value = Pace and Pace.limit and Pace.limit()

  if type(value) == "number" and value >= FETCH_TIMEOUT then
    return value
  end

  return FETCH_TIMEOUT
end

-- What the queue looked like, for the journal: it tells whether a limit was right.
local function paceFacts(facts)
  local Pace = EbonAPI.Pace
  local state = Pace and Pace.state and Pace.state()

  if state then
    facts.queue, facts.worst, facts.rate, facts.common = state.length, state.worst, state.rate, state.limit
  end

  return facts
end

local function clearLate(key)
  late[key], lateAt[key], lateLimit[key] = nil, nil, nil
end

-- A holder that once answered late is given 25% more than its last delay, up to SLOW_MAX, for the
-- next 15 minutes; the longer of that and the limit of the moment is what any holder gets.
local function timeoutOf(peer)
  local base = paceLimit()
  local seen = slow[peer]

  if not seen then
    return base
  end

  if now() - seen.at > SLOW_TTL then
    slow[peer] = nil

    return base
  end

  local wait = ceil(seen.seconds * 1.25)

  if wait <= base then
    return base
  end

  return wait < SLOW_MAX and wait or SLOW_MAX
end

-- What a request in flight may wait in silence: the limit it was sent under, or the limit of the moment
-- when that is longer. A queue that empties meanwhile does not cut a wait the holder may still need.
local function allowedFor(fetch)
  local sent, current = fetch.limit, timeoutOf(fetch.peer)

  return sent and sent > current and sent or current
end

local function heardAnswer(peer)
  answered[peer] = true
  mute[peer], muteStep[peer] = nil, nil
end

-- A holder that stayed silent without ever answering is asked for one value at a time until it
-- answers; the others get FETCH_PER_PEER requests in flight.
local function mayAsk(peer)
  return muteStep[peer] and 1 or FETCH_PER_PEER
end

local function addHolder(key, peer, state, far)
  local list = holders[key]

  if not list then
    list = {}
    holders[key] = list
  end

  local held = list[peer]

  if held then
    held.state = state
  else
    list[peer] = { state = state, skip = 0, far = far }
  end
end

local function selfName()
  return (UnitName and UnitName("player")) or ""
end

-- A message from the peer proves it is alive, but never pulls forward a date it
-- announced with "W": it may be busy for longer than the usual silence.
local function touch(peer)
  local current = now()

  for _, fetch in pairs(fetching) do
    if fetch.peer == peer and not fetch.queued then
      fetch.at = fetch.at > current and fetch.at or current
    end
  end
end

local function understands(peer)
  return (Share.peerLevel(peer) or 0) >= LEVEL
end

local function waitLine(key, seconds)
  return "W:" .. key .. ":" .. seconds
end

local function parseWait(rest)
  local key, seconds = match(rest, "^([%w_]+%.[%w_]+):(%d+)$")

  return key, tonumber(seconds)
end

-- Upper bound of the delay before the first part of a reply can leave: every
-- message already waiting in the peer queue goes out first. Nil when half of the
-- least silence of FETCH_TIMEOUT a requester gives covers it (the other half is
-- left to the request and the reply to cross), so that no notice is queued, a
-- notice costing a send slot, unless the requester could give up before the reply.
local function replyDelay()
  local seconds = Queue.peerLength() * Queue.SEND_INTERVAL

  if seconds <= FETCH_TIMEOUT / 2 then
    return nil
  end

  return seconds < ACK_MAX and ceil(seconds) or ACK_MAX
end

local function whisperLine(peer, op)
  local ok, note = Whisper.stream(PREFIX, peer, op, nil, line(), nil, true)

  if not ok then
    return false
  end

  if note ~= "waiting" then
    Share.sent.lines = Share.sent.lines + 1
  end

  return true
end

tick = function()
  local current = now()

  if announceAt and current >= announceAt and (not busy() or current - announceAt >= ANNOUNCE_HOLD) then
    announce()
  end

  if outAt and current >= outAt then
    if Channel.isJoined() then
      flushOutbox()
    else
      outAt = nil
    end
  end

  for peer, at in pairs(replies) do
    if current >= at then
      replies[peer] = nil
      whisperLine(peer, "F")
    end
  end

  for key, fetch in pairs(fetching) do
    local allowed = not fetch.queued and allowedFor(fetch)

    if allowed and current - fetch.at > allowed then
      local peer = fetch.peer
      local incident = lost[peer]

      late[key], lateAt[key], lateLimit[key] = peer, current, allowed

      if incident then
        incident.requests = incident.requests + 1

        local entry = Problems.entry(incident.problem)

        if entry.facts then
          entry.facts.requests = incident.requests
        end
      else
        if not answered[peer] and not muted(peer) then
          local step = muteStep[peer] and muteStep[peer] * 2 or MUTE_BASE

          step = step < MUTE_MAX and step or MUTE_MAX
          muteStep[peer] = step
          mute[peer] = current + step
        end

        local problem = Problems.new("EbonAPI", "SHARE.FETCH_EXPIRED", paceFacts(
          { peer = peer, key = key, seconds = floor(current - fetch.at), dropped = forget(peer), requests = 1 }))

        lost[peer] = { requests = 1, problem = problem }
        Problems.report(problem)
      end

      close(key)
      delayed[key] = current
      Log.trace("share", nil, "timeout", key)
    end
  end

  for key, at in pairs(delayed) do
    if current >= at then
      delayed[key] = nil
      enqueue(key)
    end
  end

  pump()

  for key, at in pairs(recent) do
    if current - at > REQUEST_COOLDOWN then
      recent[key] = nil
    end
  end

  for key, at in pairs(lateAt) do
    if current - at > LATE_TTL then
      clearLate(key)
    end
  end

  if idle() then
    ticking = false
    Bus.untick("EbonAPI:share")
  end
end

local round

local function armRound()
  if not rounding then
    rounding = true
    Bus.tick("EbonAPI:share-round", ROUND_INTERVAL, round)
  end
end

local function remember(sender, digest, level)
  local info = peers[sender]

  if not info then
    info = {}
    peers[sender] = info
    armRound()
  end

  info.digest = digest
  info.level = level
  info.at = now()

  return info
end

local function digestOf(parts)
  local addons = {}

  for addon in pairs(parts) do
    addons[#addons + 1] = addon
  end

  sort(addons, Hash.before)

  for i = 1, #addons do
    addons[i] = parts[addons[i]]
  end

  return Hash.digest(concat(addons))
end

local function lineLevel(body)
  return tonumber(match(body, ";(%d+)$")) or 1
end

local function requestPackets(peer, addons, absent)
  local count = #addons

  if absent then
    count = 0

    for i = 1, #addons do
      if not Keys.part(addons[i]) then
        count = count + 1
        addons[count] = addons[i]
      end
    end
  end

  if count == 0 or throttled(peer, "Q") then
    return false
  end

  for i = 1, count do
    local addon = addons[i]
    local ok, note = Whisper.stream(PREFIX, peer, "B", addon, concat(Keys.packets(addon)), addon, true)

    if ok and note ~= "waiting" then
      Share.sent.keys = Share.sent.keys + 1
    end
  end

  return true
end

-- A peer announced itself on the channel, in a beacon or in a 2.1.x parts line.
function Share.hear(sender, digest, level)
  remember(sender, digest, level)

  if digest ~= Keys.globalDigest() and not busy() then
    replies[sender] = now() + REPLY_MIN + random() * (REPLY_MAX - REPLY_MIN)
    arm()
  end
end

Share.lineLevel = lineLevel

function Share.lineDigest(body)
  return digestOf(parseLine(body))
end

local function onChannelLine(sender, body)
  local versions, digest, level = parseBeacon(body)

  if not digest then
    return
  end

  EbonAPI.Version.onBeacon(sender, versions)
  Share.hear(sender, digest, tonumber(level))
end

local function onChannelServed(sender)
  replies[sender] = nil
end

local function pending(addon)
  local prefix = addon .. "."

  for key in pairs(holders) do
    if sub(key, 1, #prefix) == prefix then
      return true
    end
  end

  return false
end

-- One key list per addon digest while catching up: a peer whose digest was already asked for
-- becomes a holder of the waiting keys of that addon.
local function askedFor(peer, addon, part)
  local list = asked[addon]

  if not list then
    list = {}
    asked[addon] = list
  end

  list[part] = { first = peer, same = {}, at = now() }
end

local function shareList(peer, addon, part)
  local list = asked[addon]
  local entry = list and list[part]

  if not entry then
    return false
  end

  if now() - entry.at > ASK_TTL and not pending(addon) then
    asked[addon] = nil

    return false
  end

  if entry.first ~= peer then
    entry.same[peer] = true
  end

  local prefix = addon .. "."

  for key, held in pairs(holders) do
    if sub(key, 1, #prefix) == prefix and held[entry.first] then
      addHolder(key, peer, held[entry.first].state, true)
    end
  end

  return true
end

local function onLineStream(sender, body, _, op)
  local parts = parseLine(body)

  remember(sender, digestOf(parts), lineLevel(body))

  if op == "F" then
    if serveUntil and now() <= serveUntil then
      Channel.say(NAME, "S", "")
    end

    serveUntil = nil

    whisperLine(sender, "f")
  end

  local addons = compare(parts)
  local count = 0

  for i = 1, #addons do
    local addon = addons[i]

    if not shareList(sender, addon, parts[addon]) then
      count = count + 1
      addons[count] = addon
    end
  end

  for i = #addons, count + 1, -1 do
    addons[i] = nil
  end

  local names = {}

  for i = 1, count do
    names[i] = addons[i]
  end

  if requestPackets(sender, addons, op == "F") then
    for i = 1, count do
      if not (op == "F" and Keys.part(names[i])) then
        askedFor(sender, names[i], parts[names[i]])
      end
    end
  end
end

local function cohortLine(peer, addon)
  if not understands(peer) or throttled(peer, "H") then
    return
  end

  local mine = Keys.globalDigest()
  local names, count, seen = {}, 0, 0

  for name, info in pairs(peers) do
    if name ~= peer and info.digest == mine and not Queue.isOffline(name) then
      seen = seen + 1

      if count < COHORT_MAX then
        count = count + 1
        names[count] = name
      elseif random(seen) <= COHORT_MAX then
        names[random(COHORT_MAX)] = name
      end
    end
  end

  if count > 0 then
    Channel.whisper(PREFIX, peer, "H:" .. concat(names, ","), nil, addon)
  end
end

-- Whether a stream of body, sent as op under id in the lane of addon, fits in the send queue. A
-- sender asks before it builds a big stream and declines or defers when it would be refused (a
-- refusal is reported as QUEUE.FULL, which is for senders that cannot know).
local function streamFits(addon, op, id, body)
  return Queue.fits(addon, Whisper.partCount(PREFIX, op, id, body))
end

local function sendKeys(peer, addon, names)
  local count = #names

  if count == 0 then
    return
  end

  for i = 1, count do
    names[i] = names[i] .. "=" .. Keys.get(addon, names[i])
  end

  local body = concat(names, ";")

  -- No room: the peer asks again (its next packets request), the list is not worth a refusal.
  if not streamFits(addon, "K", addon, body) then
    Log.trace("share", nil, "keys deferred", addon)

    return
  end

  cohortLine(peer, addon)

  local ok, note = Whisper.stream(PREFIX, peer, "K", addon, body, addon, true)

  if ok and note ~= "waiting" then
    Share.sent.keys = Share.sent.keys + 1
  end
end

-- While this client is still catching up an addon, the keys it lacks are already being fetched:
-- answering a peer's packets for that addon would only bring back a full key list.
local function onPacketsStream(sender, body, addon)
  if not match(addon, "^[%w_]+$") or len(body) ~= PACKETS * PART or pending(addon)
      or throttled(sender, "B" .. addon) then
    return
  end

  local mine = Keys.packets(addon)
  local count = 0

  for packet = 0, PACKETS - 1 do
    local at = packet * PART

    if sub(body, at + 1, at + PART) ~= mine[packet + 1] then
      count = count + 1
      digits[count] = sub(HEX, packet + 1, packet + 1)
      differing[packet] = true
    else
      differing[packet] = nil
    end
  end

  if count == 0 then
    return
  end

  local list = concat(digits, "", 1, count)

  sendKeys(sender, addon, Keys.namesIn(addon, differing))
  Channel.whisper(PREFIX, sender, "R:" .. addon .. ":" .. list, nil, addon)
end

-- A 2.1.x client that does not know our level asks for the keys of some addons: it gets the list.
local function onQueryStream(sender, body)
  if throttled(sender, "K") then
    return
  end

  for addon in gmatch(body, "[%w_]+") do
    sendKeys(sender, addon, Keys.names(addon))
  end
end

local function wanted(addon, name, theirs, mine)
  if mine == theirs then
    return false
  end

  local rule = rules[addon]

  if rule then
    local ok, result = pcall(rule, name, theirs, mine)

    if not ok then
      Lib.report(result, addon)
      return false
    end

    return result and true or false
  end

  return mine == nil or tonumber(theirs) > tonumber(mine)
end

local function take()
  local slot = free[freeCount]

  if slot then
    free[freeCount] = nil
    freeCount = freeCount - 1

    return slot
  end

  slot = {}

  slot.done = function(ok)
    local key = slot.key

    slot.queued = false

    if not key then
      release(slot)
    elseif ok then
      slot.at, slot.limit = now(), paceLimit()
    elseif fetching[key] == slot then
      close(key)
      pump()
    end
  end

  return slot
end

local function start(peer, addon, key)
  local slot = take()

  slot.key, slot.peer, slot.queued, slot.announced, slot.limit = key, peer, true, false, nil

  if not Channel.whisper(PREFIX, peer, "G:" .. key, slot.done, addon) then
    slot.key = nil
    release(slot)
    return false
  end

  fetching[key] = slot
  live = live + 1
  loads[peer] = (loads[peer] or 0) + 1
  clearLate(key)
  arm()

  return true
end

local function pick(key, addon, name)
  local list = holders[key]

  if not list then
    return nil, false
  end

  local current = now()
  local mine = Keys.get(addon, name)
  local best, bestLoad, ties = nil, nil, 0
  local usable, retry = false, nil

  for peer, held in pairs(list) do
    if Queue.isOffline(peer) or not wanted(addon, name, held.state, mine) then
      list[peer] = nil
    elseif muted(peer) then
      retry = (retry and retry < mute[peer]) and retry or mute[peer]
    else
      usable = true

      if held.skip <= current then
        local load = loads[peer] or 0

        if load < mayAsk(peer) then
          load = load * 2 + (held.far and 0 or 1)

          if not bestLoad or load < bestLoad then
            best, bestLoad, ties = peer, load, 1
          elseif load == bestLoad then
            ties = ties + 1

            if random(ties) == 1 then
              best = peer
            end
          end
        end
      end
    end
  end

  return best, usable, retry
end

pump = function()
  local count = wLast - wFirst + 1

  while count > 0 and live < FETCH_WINDOW do
    count = count - 1

    local index = wFirst
    local key = wKey[index]

    wKey[index] = nil
    wFirst = index + 1

    if key then
      local addon, name = match(key, "^([%w_]+)%.([%w_]+)$")
      local peer, any, retry = pick(key, addon, name)

      if peer then
        waiting[key] = nil

        if not start(peer, addon, key) then
          holders[key] = nil
        end
      elseif any then
        wLast = wLast + 1
        wKey[wLast] = key
      elseif retry then
        waiting[key] = nil
        delayed[key] = retry
        arm()
      else
        waiting[key] = nil
        holders[key] = nil
      end
    end
  end

  if wFirst > wLast then
    wFirst, wLast = 1, 0
  end
end

enqueue = function(key)
  if fetching[key] or waiting[key] or delayed[key] then
    return
  end

  wLast = wLast + 1
  wKey[wLast] = key
  waiting[key] = true
end

local function onAnnounced(sender, body)
  local addon, name, state = match(body, "^([%w_]+)%.([%w_]+):(%d+)$")

  if not addon or sender == selfName() then
    return
  end

  state = Keys.read(name, state)

  if not state or not wanted(addon, name, state, Keys.get(addon, name)) then
    return
  end

  local key = addon .. "." .. name

  addHolder(key, sender, state)

  if not fetching[key] and not waiting[key] and not delayed[key] then
    delayed[key] = now() + random() * NOTE_DELAY
    arm()
  end
end

local function onKeysStream(sender, body, addon)
  if not match(addon, "^[%w_]+$") then
    return refuse(sender, addon, "addon name is not letters, digits or underscores")
  end

  for name, state in gmatch(body, "([%w_]+)=(%d+)") do
    local reason

    state, reason = Keys.read(name, state)

    if reason then
      refuse(sender, addon .. "." .. name, reason)
    else
      local mine = Keys.get(addon, name)

      if wanted(addon, name, state, mine) then
        local key = addon .. "." .. name

        addHolder(key, sender, state)

        local entry = asked[addon]

        if entry then
          for _, item in pairs(entry) do
            if item.first == sender then
              for peer in pairs(item.same) do
                addHolder(key, peer, state, true)
              end
            end
          end
        end

        local group = cohort[sender]

        if group and now() - group.at <= COHORT_TTL then
          local list = holders[key]

          for index = 1, #group do
            if not list[group[index]] then
              addHolder(key, group[index], state, true)
            end
          end
        end

        enqueue(key)
      end
    end
  end

  pump()
end

local function onWhisper(sender, text)
  local op, rest = match(text, "^(%a):(.*)$")

  if op == "G" then
    local addon, name = match(rest, "^([%w_]+)%.([%w_]+)$")

    if not addon or throttled(sender, "G" .. rest) then
      return
    end

    local held, state = Share.get(addon, name)
    local ok, note = false, nil

    if state and (serving[rest] or 0) >= SERVE_MAX and understands(sender) then
      local sent = servedTo[rest]
      local names = {}

      if sent and sent.state == state then
        for index = #sent, 1, -1 do
          if sent[index] ~= sender and #names < SERVED_LIST then
            names[#names + 1] = sent[index]
          end
        end
      end

      recent[sender .. ":G" .. rest] = nil
      Channel.whisper(PREFIX, sender, "Y:" .. rest .. ":" .. concat(names, ","), nil, addon)

      return
    end

    local body = state and state .. "|" .. (held or "")

    -- No room for the reply: declined like any refusal, the requester asks another holder.
    if state and not streamFits(addon, "D", rest, body) then
      state = nil
    end

    if state then
      local delay = understands(sender) and replyDelay()

      if delay then
        Channel.whisper(PREFIX, sender, waitLine(rest, delay), nil, addon)
      end

      serving[rest] = (serving[rest] or 0) + 1
      ok, note = Whisper.stream(PREFIX, sender, "D", rest, body, addon, true, function(sentOk)
        local count = (serving[rest] or 1) - 1

        serving[rest] = count > 0 and count or nil

        if sentOk then
          local sent = servedTo[rest]

          if not sent or sent.state ~= state then
            sent = { state = state }
            servedTo[rest] = sent
          end

          for index = #sent, 1, -1 do
            if sent[index] == sender then
              table.remove(sent, index)
            end
          end

          sent[#sent + 1] = sender

          if #sent > SERVED_KEEP then
            table.remove(sent, 1)
          end
        end
      end)

      if not ok then
        local count = (serving[rest] or 1) - 1

        serving[rest] = count > 0 and count or nil
      end
    end

    if not ok then
      recent[sender .. ":G" .. rest] = nil
      Channel.whisper(PREFIX, sender, "X:" .. rest, nil, addon)
    elseif note ~= "waiting" then
      Share.sent.data = Share.sent.data + 1
    end
  elseif op == "W" then
    local key, seconds = parseWait(rest)

    if not key then
      return refuse(sender, rest, "wait notice is not a key and a number of seconds")
    end

    local fetch = fetching[key]

    if fetch and fetch.peer == sender and not fetch.queued and not fetch.announced then
      fetch.announced = true
      fetch.at = now() + (seconds < ACK_MAX and seconds or ACK_MAX)
    end
  elseif op == "R" then
    local addon, list = match(rest, "^([%w_]+):(%x+)$")

    if not addon or throttled(sender, "R" .. addon) then
      return
    end

    for packet = 0, PACKETS - 1 do
      differing[packet] = nil
    end

    for digit in gmatch(list, "%x") do
      differing[tonumber(digit, 16)] = true
    end

    sendKeys(sender, addon, Keys.namesIn(addon, differing))
  elseif op == "X" then
    local fetch = fetching[rest]

    if fetch and fetch.peer == sender then
      heardAnswer(sender)

      local list = holders[rest]

      if list then
        list[sender] = nil
      end

      close(rest)
      touch(sender)
      enqueue(rest)
      pump()
    end
  elseif op == "H" then
    local group = { at = now() }
    local me = selfName()

    for name in gmatch(rest, "[^,:|]+") do
      if name ~= me and name ~= sender and #group < COHORT_MAX then
        group[#group + 1] = name
      end
    end

    cohort[sender] = group

    for key, list in pairs(holders) do
      local held = list[sender]

      if held then
        for index = 1, #group do
          if not list[group[index]] then
            addHolder(key, group[index], held.state, true)
          end
        end
      end
    end
  elseif op == "Y" then
    local key, names = match(rest, "^([%w_]+%.[%w_]+):(.*)$")
    local fetch = key and fetching[key]

    if fetch and fetch.peer == sender then
      heardAnswer(sender)

      local list = holders[key]
      local held = list and list[sender]

      if held then
        local me = selfName()

        for name in gmatch(names, "[^,:|]+") do
          if name ~= me and name ~= sender then
            addHolder(key, name, held.state, true)
          end
        end
      end

      close(key)
      touch(sender)
      delayed[key] = now() + RETRY_MIN + random() * (RETRY_MAX - RETRY_MIN)
      arm()
      pump()
    end
  end
end

local function onDataPart(sender, id)
  local fetch = fetching[id]

  if fetch and fetch.peer == sender and not fetch.queued then
    heardAnswer(sender)
    touch(sender)
  end
end

local function onDataStream(sender, body, id)
  local fetch = fetching[id]

  if fetch and fetch.peer == sender then
    close(id)
  elseif late[id] == sender and now() - lateAt[id] <= LATE_TTL then
    local waited = floor(now() - lateAt[id]) + lateLimit[id]

    slow[sender] = { seconds = waited, at = now() }
    Problems.reject("EbonAPI", "SHARE.LATE_ANSWER", paceFacts({
      reason = sender, peer = sender, key = id, seconds = waited,
    }))
    clearLate(id)
  else
    return
  end

  heardAnswer(sender)
  holders[id], delayed[id] = nil, nil

  touch(sender)

  local addon, name = match(id, "^([%w_]+)%.([%w_]+)$")
  local state, text = match(body, "^([^|]*)|(.*)$")
  local reason

  if not addon then
    reason = "stream id is not addon.key"
  elseif not state then
    reason = "body has no state before the first |"
  else
    state, reason = Keys.read(name, state)
  end

  if not reason and len(text) > TEXT_MAX then
    reason = "text of " .. len(text) .. " characters exceeds " .. TEXT_MAX
  end

  if not reason then
    local mine = Keys.get(addon, name)

    if not wanted(addon, name, state, mine) then
      reason = "the state is not newer than the one already held"
    end
  end

  if reason then
    refuse(sender, id, reason)
    pump()
    return
  end

  local held = texts()
  local own = held[addon]

  if not own then
    own = {}
    held[addon] = own
  end

  own[name] = text
  local before = Keys.globalDigest()
  inbound = true
  Keys.put(addon, name, state)
  inbound = false
  advance(before, Keys.globalDigest())
  Share.received = Share.received + 1
  Log.trace("share", nil, id, len(text))
  EbonAPI:Emit("SHARE_RECEIVED", addon, name, state, sender)
  pump()
end

local function onDirectLine(sender, body)
  local addon, name, state, text = match(body, "^([%w_]+)%.([%w_]+):(%d+):(.*)$")

  if addon then
    state = Keys.read(name, state)
    text = unescape(text)
  end

  if not addon or not state or not text or len(text) > TEXT_MAX or not wanted(addon, name, state, Keys.get(addon, name)) then
    Share.refused = Share.refused + 1
    return
  end

  local key = addon .. "." .. name

  if waiting[key] then
    for index = wFirst, wLast do
      if wKey[index] == key then
        wKey[index] = false
      end
    end

    waiting[key] = nil
  end

  holders[key], delayed[key] = nil, nil

  local held = texts()
  local own = held[addon]
  local before = Keys.globalDigest()

  if not own then
    own = {}
    held[addon] = own
  end

  own[name] = text
  inbound = true
  Keys.put(addon, name, state)
  inbound = false
  advance(before, Keys.globalDigest())
  Share.received = Share.received + 1
  Log.trace("share", nil, key, len(text))
  EbonAPI:Emit("SHARE_RECEIVED", addon, name, state, sender)
end

local function onKeyChanged(_, addon, name, state)
  if not enabled then
    return
  end

  local before = lastMine
  lastMine = Keys.globalDigest()

  if inbound then
    if sentFrom then
      sentFrom = false
    end

    return
  end

  if state == nil or not before then
    sentFrom = false
    return
  end

  if sentFrom == false and outCount == 0 then
    sentFrom = nil
  end

  if sentFrom == nil then
    sentFrom = before
  end

  local key = addon .. "." .. name

  if not outbox[key] then
    outbox[key] = true
    outCount = outCount + 1
    outOrder[outCount] = key
  end

  if not outAt then
    outAt = now() + DIRECT_DELAY
    arm()
  end
end

local function onJoined()
  schedule(JOIN_DELAY)

  if outCount > 0 and not outAt then
    outAt = now()
    arm()
  end
end

local function onPeerOffline(_, name)
  peers[name] = nil
  replies[name] = nil

  forget(name)
  cohort[name] = nil

  for key, fetch in pairs(fetching) do
    if fetch.peer == name then
      close(key)
      enqueue(key)
    end
  end

  pump()
end

round = function()
  local current = now()
  local candidates = {}
  local mine = Keys.globalDigest()

  for peer, info in pairs(peers) do
    if current - info.at > PEER_TTL then
      peers[peer] = nil
    elseif info.digest ~= mine then
      candidates[#candidates + 1] = peer
    end
  end

  if next(peers) == nil then
    rounding = false
    Bus.untick("EbonAPI:share-round")
  end

  if #candidates == 0 or busy() then
    return
  end

  sort(candidates)
  whisperLine(candidates[random(#candidates)], "F")
end

function Share.announce()
  local current = now()

  if lastManual and current - lastManual < MANUAL_COOLDOWN then
    return false
  end

  if not announce() then
    return false
  end

  lastManual = current

  return true
end

function Share.beacon()
  return announce()
end

function Share.summary()
  local addons = Keys.addons()
  local keys = 0

  for i = 1, #addons do
    keys = keys + #Keys.names(addons[i])
  end

  return keys, #addons, Lib.count(peers), Share.received, Share.refused
end

function Share.peerCount()
  return Lib.count(peers)
end

function Share.peerLevel(name)
  local info = peers[name]

  return info and info.level
end

function Share.legacyPeerHeard()
  local current = now()

  for _, info in pairs(peers) do
    if info.level < LEVEL and current - info.at <= PEER_TTL then
      return true
    end
  end

  return false
end

function Share.isFetching(addon, name)
  return fetching[addon .. "." .. name] ~= nil
end

-- The holders we know and the requests in flight, for the diagnostic window. It only reads.
function Share.view()
  local current = now()
  local rows, index, held = {}, {}, {}

  for _, list in pairs(holders) do
    for peer in pairs(list) do
      held[peer] = (held[peer] or 0) + 1
    end
  end

  local function row(peer)
    if index[peer] then
      return
    end

    local info, seen = peers[peer], slow[peer]
    local item = {
      peer = peer, inflight = loads[peer] or 0, keys = held[peer] or 0, answered = answered[peer] and true or false,
      slow = seen and seen.seconds or nil, level = info and info.level or nil,
      heard = info and current - info.at or nil, timeout = timeoutOf(peer),
    }

    if muted(peer) then
      item.muted, item.step = mute[peer] - current, muteStep[peer]
    end

    index[peer] = item
    rows[#rows + 1] = item
  end

  for peer in pairs(peers) do
    row(peer)
  end

  for peer in pairs(loads) do
    row(peer)
  end

  for peer in pairs(mute) do
    row(peer)
  end

  for peer in pairs(slow) do
    row(peer)
  end

  for peer in pairs(held) do
    row(peer)
  end

  sort(rows, function(x, y)
    if x.inflight ~= y.inflight then
      return x.inflight > y.inflight
    end

    return x.peer < y.peer
  end)

  local flights = {}

  for key, fetch in pairs(fetching) do
    flights[#flights + 1] = {
      key = key, peer = fetch.peer, queued = fetch.queued and true or false,
      age = not fetch.queued and current - fetch.at or nil, limit = allowedFor(fetch),
    }
  end

  sort(flights, function(x, y)
    return (x.age or -1) > (y.age or -1)
  end)

  local delayedCount, lateCount = 0, 0

  for _ in pairs(delayed) do
    delayedCount = delayedCount + 1
  end

  for _ in pairs(late) do
    lateCount = lateCount + 1
  end

  return {
    window = FETCH_WINDOW, perPeer = FETCH_PER_PEER, live = live, timeout = paceLimit(),
    waiting = wFirst <= wLast and wLast - wFirst + 1 or 0, delayed = delayedCount, late = lateCount,
  }, rows, flights
end

function Share.isMuted(peer)
  return muted(peer)
end

function Share.isWaiting(addon, name)
  return waiting[addon .. "." .. name] ~= nil
end

function Share.enable()
  if enabled then
    return false
  end

  enabled = true
  lastMine = Keys.globalDigest()

  texts()

  Channel.on(NAME, "B", onChannelLine)
  Channel.on(NAME, "S", onChannelServed)
  Channel.on(NAME, "U", onDirectLine)
  Channel.on(NAME, "N", onAnnounced)
  Whisper.on(PREFIX, onWhisper)
  Whisper.onStream(PREFIX, "F", onLineStream)
  Whisper.onStream(PREFIX, "f", onLineStream)
  Whisper.onStream(PREFIX, "Q", onQueryStream)
  Whisper.onStream(PREFIX, "B", onPacketsStream)
  Whisper.onStream(PREFIX, "K", onKeysStream)
  Whisper.onStream(PREFIX, "D", onDataStream, onDataPart)

  EbonAPI:On("SHARE_KEY_CHANGED", onKeyChanged)
  EbonAPI:On("PEER_OFFLINE", onPeerOffline)
  EbonAPI:On("CHANNEL_JOINED", onJoined)

  EbonAPI.Legacy.enable()

  return true
end

function Share.disable()
  if not enabled then
    return false
  end

  enabled = false

  Channel.off(NAME, "B", onChannelLine)
  Channel.off(NAME, "S", onChannelServed)
  Channel.off(NAME, "U", onDirectLine)
  Channel.off(NAME, "N", onAnnounced)
  Whisper.off(PREFIX, onWhisper)
  Whisper.offStream(PREFIX, "F", onLineStream)
  Whisper.offStream(PREFIX, "f", onLineStream)
  Whisper.offStream(PREFIX, "Q", onQueryStream)
  Whisper.offStream(PREFIX, "B", onPacketsStream)
  Whisper.offStream(PREFIX, "K", onKeysStream)
  Whisper.offStream(PREFIX, "D", onDataStream)

  EbonAPI:Off("SHARE_KEY_CHANGED", onKeyChanged)
  EbonAPI:Off("PEER_OFFLINE", onPeerOffline)
  EbonAPI:Off("CHANNEL_JOINED", onJoined)

  EbonAPI.Legacy.disable()

  Bus.untick("EbonAPI:share-round")
  Bus.untick("EbonAPI:share")

  for key in pairs(peers) do peers[key] = nil end
  for key in pairs(replies) do replies[key] = nil end
  for key in pairs(fetching) do close(key) end
  for key in pairs(waiting) do waiting[key] = nil end
  for index = wFirst, wLast do wKey[index] = nil end
  for key in pairs(holders) do holders[key] = nil end
  for key in pairs(asked) do asked[key] = nil end
  for key in pairs(delayed) do delayed[key] = nil end
  for key in pairs(loads) do loads[key] = nil end
  for key in pairs(serving) do serving[key] = nil end
  for key in pairs(servedTo) do servedTo[key] = nil end
  for key in pairs(cohort) do cohort[key] = nil end
  for key in pairs(recent) do recent[key] = nil end
  for key in pairs(late) do clearLate(key) end
  for key in pairs(answered) do answered[key] = nil end
  for key in pairs(slow) do slow[key] = nil end
  for key in pairs(mute) do mute[key], muteStep[key] = nil, nil end
  for key in pairs(lost) do lost[key] = nil end

  for key in pairs(outbox) do outbox[key] = nil end
  for index = 1, outCount do outOrder[index] = nil end
  for index = winFirst, winLast do winAt[index], winLines[index] = nil, nil end

  outCount = 0
  outAt = nil
  inbound = false
  winFirst, winLast = 1, 0
  wFirst, wLast = 1, 0
  ticking = false
  rounding = false
  serveUntil = nil
  announceAt = nil

  return true
end

function Handle:Share(name, state, text)
  return Share.set(self.addonName, name, state, text)
end

function Handle:Unshare(name)
  return Share.remove(self.addonName, name)
end

function Handle:GetShared(name, addon)
  return Share.get(addon or self.addonName, name)
end

function Handle:SharedNames(addon)
  return Keys.names(addon or self.addonName)
end

function Handle:ShareRule(fn)
  if fn ~= nil and type(fn) ~= "function" then
    error("EbonAPI: " .. self.addonName .. ": ShareRule expects a function or nil, got " .. type(fn), 2)
  end

  rules[self.addonName] = fn

  return true
end

function Handle:SyncShares()
  return Share.announce()
end

EbonAPI:AddTeardown(function(handle)
  rules[handle.addonName] = nil
end)
