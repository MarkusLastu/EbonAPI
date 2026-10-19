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
local random, floor = math.random, math.floor

local NAME = "EbonAPI"
local PREFIX = "EbonAPI"
local TEXT_MAX = 32768
local JOIN_DELAY = 2
local CHANGE_DELAY = 15
local ANNOUNCE_HOLD = 60
local MANUAL_COOLDOWN = 30
local REPLY_MIN, REPLY_MAX = 1, 5
local ROUND_INTERVAL = 120
local PEER_TTL = 600
local FETCH_TIMEOUT = 30
local FETCH_WINDOW = 8
local SERVE_WINDOW = 30
local REQUEST_COOLDOWN = 10
local LATE_TTL = 600
local LEVEL = 2
local SUFFIX = ";" .. LEVEL
local PACKETS = Keys.PACKETS
local PART = Hash.LENGTH
local HEX = "0123456789abcdef"

Share.PREFIX = PREFIX
Share.TEXT_MAX = TEXT_MAX
Share.JOIN_DELAY = JOIN_DELAY
Share.CHANGE_DELAY = CHANGE_DELAY
Share.ANNOUNCE_HOLD = ANNOUNCE_HOLD
Share.MANUAL_COOLDOWN = MANUAL_COOLDOWN
Share.REPLY_MAX = REPLY_MAX
Share.ROUND_INTERVAL = ROUND_INTERVAL
Share.FETCH_TIMEOUT = FETCH_TIMEOUT
Share.FETCH_WINDOW = FETCH_WINDOW
Share.REQUEST_COOLDOWN = REQUEST_COOLDOWN
Share.LATE_TTL = LATE_TTL
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
local wKey, wPeer, wState = {}, {}, {}
local wFirst, wLast = 1, 0
local recent = {}
local late, lateAt = {}, {}
local differing = {}
local digits = {}
local rules = {}

Share.sent = { lines = 0, keys = 0, data = 0 }
Share.received = 0
Share.refused = 0

local Problems = EbonAPI.Problems

Problems.declare("EbonAPI", "EBONAPI", {
  ["SHARE.REFUSED"] = { class = "rejet" },
  ["SHARE.FETCH_EXPIRED"] = { class = "echec", key = "key", quiet = true },
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

local function line()
  local addons = Keys.addons()
  local room = Channel.bodyMax(NAME, "F") - len(SUFFIX)
  local out = {}
  local size = -1

  for i = 1, #addons do
    local item = addons[i] .. "=" .. Keys.part(addons[i])

    size = size + len(item) + 1

    if size > room then
      break
    end

    out[i] = item
  end

  return concat(out, ",") .. SUFFIX
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

local function arm()
  if not ticking then
    ticking = true
    Bus.tick("EbonAPI:share", 1, tick)
  end
end

local function idle()
  return announceAt == nil and next(replies) == nil and next(fetching) == nil
end

local function busy()
  return live > 0 or wFirst <= wLast
end

local function announce()
  if not Channel.isJoined() then
    announceAt = nil
    return false
  end

  if not Channel.say(NAME, "F", line()) then
    return false
  end

  announceAt = nil
  Share.sent.lines = Share.sent.lines + 1
  serveUntil = now() + SERVE_WINDOW
  Log.trace("share", nil, "F")

  return true
end

local function schedule(delay)
  if not announceAt then
    announceAt = now() + delay
    arm()
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

  if not slot.queued then
    release(slot)
  end
end

local function forget(peer)
  local cancelled = 0

  for index = wFirst, wLast do
    if wPeer[index] == peer then
      waiting[wKey[index]] = nil
      wKey[index], wPeer[index], wState[index] = false, nil, nil
      cancelled = cancelled + 1
    end
  end

  return cancelled
end

local function touch(peer)
  local current = now()

  for _, fetch in pairs(fetching) do
    if fetch.peer == peer and not fetch.queued then
      fetch.at = current
    end
  end
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

  for peer, at in pairs(replies) do
    if current >= at then
      replies[peer] = nil
      whisperLine(peer, "F")
    end
  end

  for key, fetch in pairs(fetching) do
    if not fetch.queued and current - fetch.at > FETCH_TIMEOUT then
      local peer, silent = fetch.peer, floor(current - fetch.at)

      late[key], lateAt[key] = peer, current

      local cancelled = forget(peer)

      close(key)
      Log.trace("share", nil, "timeout", key)
      Problems.report(Problems.new("EbonAPI", "SHARE.FETCH_EXPIRED",
        { peer = peer, key = key, seconds = silent, cancelled = cancelled }))
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
      late[key], lateAt[key] = nil, nil
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

local function remember(sender, body)
  local parts = parseLine(body)
  local info = peers[sender]

  if not info then
    info = {}
    peers[sender] = info
    armRound()
  end

  info.parts = parts
  info.level = tonumber(match(body, ";(%d+)$")) or 1
  info.at = now()

  return parts, info.level
end

local function requestKeys(peer, addons)
  if #addons == 0 or throttled(peer, "Q") then
    return false
  end

  local ok, note = Whisper.stream(PREFIX, peer, "Q", nil, concat(addons, ","), nil, true)

  if not ok then
    return false
  end

  if note ~= "waiting" then
    Share.sent.keys = Share.sent.keys + 1
  end

  return true
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

local function onChannelLine(sender, body)
  local parts = remember(sender, body)
  local _, any = compare(parts)

  if any and not busy() then
    replies[sender] = now() + REPLY_MIN + random() * (REPLY_MAX - REPLY_MIN)
    arm()
  end
end

local function onChannelServed(sender)
  replies[sender] = nil
end

local function onLineStream(sender, body, _, op)
  local parts, level = remember(sender, body)

  if op == "F" then
    if serveUntil and now() <= serveUntil then
      Channel.say(NAME, "S", "")
    end

    serveUntil = nil

    whisperLine(sender, "f")
  end

  if level >= LEVEL then
    requestPackets(sender, (compare(parts)), op == "F")
  else
    requestKeys(sender, (compare(parts)))
  end
end

local function sendKeys(peer, addon, names)
  local count = #names

  if count == 0 then
    return
  end

  for i = 1, count do
    names[i] = names[i] .. "=" .. Keys.get(addon, names[i])
  end

  local ok, note = Whisper.stream(PREFIX, peer, "K", addon, concat(names, ";"), addon, true)

  if ok and note ~= "waiting" then
    Share.sent.keys = Share.sent.keys + 1
  end
end

local function onQueryStream(sender, body)
  if throttled(sender, "K") then
    return
  end

  for addon in gmatch(body, "[%w_]+") do
    sendKeys(sender, addon, Keys.names(addon))
  end
end

local function onPacketsStream(sender, body, addon)
  if not match(addon, "^[%w_]+$") or len(body) ~= PACKETS * PART or throttled(sender, "B" .. addon) then
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
      slot.at = now()
    elseif fetching[key] == slot then
      close(key)
      pump()
    end
  end

  return slot
end

local function start(peer, addon, key)
  local slot = take()

  slot.key, slot.peer, slot.queued = key, peer, true

  if not Channel.whisper(PREFIX, peer, "G:" .. key, slot.done, addon) then
    slot.key = nil
    release(slot)
    return
  end

  fetching[key] = slot
  live = live + 1
  late[key], lateAt[key] = nil, nil
  arm()
end

pump = function()
  while live < FETCH_WINDOW and wFirst <= wLast do
    local index = wFirst
    local key, peer, state = wKey[index], wPeer[index], wState[index]

    wKey[index], wPeer[index], wState[index] = nil, nil, nil
    wFirst = index + 1

    if key then
      local addon, name = match(key, "^([%w_]+)%.([%w_]+)$")

      waiting[key] = nil

      if not Queue.isOffline(peer) and wanted(addon, name, state, Keys.get(addon, name)) then
        start(peer, addon, key)
      end
    end
  end

  if wFirst > wLast then
    wFirst, wLast = 1, 0
  end
end

local function enqueue(peer, key, state)
  if fetching[key] or waiting[key] then
    return
  end

  wLast = wLast + 1
  wKey[wLast], wPeer[wLast], wState[wLast] = key, peer, state
  waiting[key] = true
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
        enqueue(sender, addon .. "." .. name, state)
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

    if state then
      ok, note = Whisper.stream(PREFIX, sender, "D", rest, state .. "|" .. (held or ""), addon, true)
    end

    if not ok then
      recent[sender .. ":G" .. rest] = nil
      Channel.whisper(PREFIX, sender, "X:" .. rest, nil, addon)
    elseif note ~= "waiting" then
      Share.sent.data = Share.sent.data + 1
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
      close(rest)
      touch(sender)
      pump()
    end
  end
end

local function onDataPart(sender, id)
  local fetch = fetching[id]

  if fetch and fetch.peer == sender and not fetch.queued then
    touch(sender)
  end
end

local function onDataStream(sender, body, id)
  local fetch = fetching[id]

  if fetch and fetch.peer == sender then
    close(id)
  elseif late[id] == sender and now() - lateAt[id] <= LATE_TTL then
    late[id], lateAt[id] = nil, nil
  else
    return
  end

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
  Keys.put(addon, name, state)
  Share.received = Share.received + 1
  Log.trace("share", nil, id, len(text))
  EbonAPI:Emit("SHARE_RECEIVED", addon, name, state, sender)
  pump()
end

local function onKeyChanged()
  if enabled then
    schedule(CHANGE_DELAY)
  end
end

local function onJoined()
  schedule(JOIN_DELAY)
end

local function onPeerOffline(_, name)
  peers[name] = nil
  replies[name] = nil

  for key, fetch in pairs(fetching) do
    if fetch.peer == name then
      close(key)
    end
  end

  forget(name)
  pump()
end

round = function()
  local current = now()
  local candidates = {}

  for peer, info in pairs(peers) do
    if current - info.at > PEER_TTL then
      peers[peer] = nil
    else
      local _, any = compare(info.parts)

      if any then
        candidates[#candidates + 1] = peer
      end
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

function Share.isFetching(addon, name)
  return fetching[addon .. "." .. name] ~= nil
end

function Share.isWaiting(addon, name)
  return waiting[addon .. "." .. name] ~= nil
end

function Share.enable()
  if enabled then
    return false
  end

  enabled = true

  texts()

  Channel.on(NAME, "F", onChannelLine)
  Channel.on(NAME, "S", onChannelServed)
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

  return true
end

function Share.disable()
  if not enabled then
    return false
  end

  enabled = false

  Channel.off(NAME, "F", onChannelLine)
  Channel.off(NAME, "S", onChannelServed)
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

  Bus.untick("EbonAPI:share-round")
  Bus.untick("EbonAPI:share")

  for key in pairs(peers) do peers[key] = nil end
  for key in pairs(replies) do replies[key] = nil end
  for key in pairs(fetching) do close(key) end
  for key in pairs(waiting) do waiting[key] = nil end
  for index = wFirst, wLast do wKey[index], wPeer[index], wState[index] = nil, nil, nil end
  for key in pairs(recent) do recent[key] = nil end
  for key in pairs(late) do late[key], lateAt[key] = nil, nil end

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
