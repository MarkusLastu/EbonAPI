EbonAPI = EbonAPI or {}
EbonAPI.Queue = {}

local Queue = EbonAPI.Queue
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local Problems = EbonAPI.Problems

local type, pairs, error, tostring, pcall = type, pairs, error, tostring, pcall
local match, gsub, find, lower, upper, char = string.match, string.gsub, string.find, string.lower, string.upper, string.char
local concat = table.concat

local SEND_INTERVAL = 0.15
local PEER_CAP = 500
local LANE_CAP = 250
local RESERVE = 50
local OFFLINE_HOLD = 60
local MASK_WINDOW = 300
local ANSWER_WINDOW = 5

Queue.SEND_INTERVAL = SEND_INTERVAL
Queue.PEER_CAP = PEER_CAP
Queue.LANE_CAP = LANE_CAP
Queue.RESERVE = RESERVE
Queue.OFFLINE_HOLD = OFFLINE_HOLD
Queue.MASK_WINDOW = MASK_WINDOW
Queue.ANSWER_WINDOW = ANSWER_WINDOW

local senders = {}
local gates = {}
local gateOpen = {}

local sPayload = {}
local sFirst, sLast = 1, 0

local mA, mB, mC, mDone, mNext = {}, {}, {}, {}, {}
local mSeq, mCount, mKey, mBody = {}, {}, {}, {}
local mTop, mFree = 0, 0

local laneOf = {}
local laneName = {}
local laneLive = {}
local laneCount = 0

local playerDest, kindDest = {}, {}
local dKind, dKey, dLive, dSmall, dBig = {}, {}, {}, {}, {}
local dLast, dCells, dSmallAt, dBigAt = {}, {}, {}, {}
local dTop = 0

local cDest, cLane, cNext = {}, {}, {}
local cSmallHead, cSmallTail, cBigHead, cBigTail = {}, {}, {}, {}
local cTop = 0

local smallTurn, bigTurn = 0, 0
local seq, limit = 0, 0
local held = false
local cur, curLeft, curTotal = 0, 0, 0
local bigLive = 0
local pLive = 0

local offlineUntil = {}
local recentWhisper = {}
local foreignWhisper = {}
local foreignLeft = {}
local addonWhisper = {}
local foreignSwept = 0
local lastText, lastAt, lastMasked
local judged = {}
local sending = false
local watching = false

Queue.sent = { server = 0, channel = 0, whisper = 0 }
Queue.dropped = { offline = 0, full = 0, failed = 0 }
Queue.hidden = { own = 0, addon = 0, unknown = 0 }

local sent = Queue.sent
local dropped = Queue.dropped

Problems.declare("EbonAPI", "EBONAPI", {
  ["QUEUE.FULL"] = { class = "refus", key = "addon", quiet = true },
  ["QUEUE.PEER_OFFLINE"] = { class = "refus", key = "player", silent = true },
  ["QUEUE.SEND_FAILED"] = { class = "echec", key = "addon", quiet = true },
  ["QUEUE.STREAM_CUT"] = { class = "partiel", key = "addon", quiet = true },
  ["QUEUE.LINE_HIDDEN"] = { class = "rejet" },
})

local function now()
  return (GetTime and GetTime()) or 0
end

local function baseName(name)
  if type(name) ~= "string" then
    return nil
  end

  name = match(name, "^([^%-]+)") or name

  if name == "" then
    return nil
  end

  return name
end

Queue.baseName = baseName

local ACCENTED = {}

for code = 128, 158 do
  if code ~= 151 then
    ACCENTED["\195" .. char(code)] = "\195" .. char(code + 32)
  end
end

local function fold(name)
  name = lower(name)

  if find(name, "\195", 1, true) then
    name = gsub(name, "\195[\128-\158]", ACCENTED)
  end

  return name
end

function Queue.register(kind, fn, ready)
  if type(kind) ~= "string" or type(fn) ~= "function" then
    error("EbonAPI.Queue.register expects a kind and a function", 2)
  end

  senders[kind] = fn
  gates[kind] = ready
end

local function rawWhisper(prefix, target, text)
  if not SendAddonMessage then
    return false, "SendAddonMessage is not available"
  end

  sending = true

  local ok, err = pcall(SendAddonMessage, prefix, text, "WHISPER", target)

  sending = false

  return ok, not ok and err or nil
end

local function sweep(list, current)
  for other, at in pairs(list) do
    if current - at > ANSWER_WINDOW then
      list[other] = nil
    end
  end
end

-- Whispers EbonAPI did not queue. A chat whisper (SendChatMessage: the player's /w, a reply
-- addon) keeps its "not found" line: one line per whisper the game could not deliver, counted.
-- Every other "not found" line stays out of the chat: the whispers of EbonAPI, the addon messages
-- of any other addon, and the ones nobody here accounts for. The player did not write them.
local function noteForeign(kind, target, visible)
  if sending or (kind ~= "WHISPER" and (type(kind) ~= "string" or upper(kind) ~= "WHISPER")) then
    return
  end

  local name = baseName(target)
  local key = name and fold(name)

  if not key then
    return
  end

  local current = now()

  if current - foreignSwept > ANSWER_WINDOW then
    foreignSwept = current
    sweep(foreignWhisper, current)
    sweep(addonWhisper, current)

    for other in pairs(foreignLeft) do
      if not foreignWhisper[other] then
        foreignLeft[other] = nil
      end
    end
  end

  if not visible then
    addonWhisper[key] = current
    return
  end

  if not foreignWhisper[key] or current - foreignWhisper[key] > ANSWER_WINDOW then
    foreignLeft[key] = 0
  end

  foreignWhisper[key] = current
  foreignLeft[key] = foreignLeft[key] + 1
end

-- A chat whisper the game delivered comes back as CHAT_MSG_WHISPER_INFORM: no "not found" line is
-- due for it any more.
local function onInform(_, target)
  local name = baseName(target)
  local key = name and fold(name)
  local left = key and foreignLeft[key]

  if left and left > 0 then
    foreignLeft[key] = left - 1
  end
end

Bus.onCore("CHAT_MSG_WHISPER_INFORM", onInform)

local offlineTemplate, offlinePattern

local function offlinePlayer(message)
  local template = ERR_CHAT_PLAYER_NOT_FOUND_S

  if type(template) ~= "string" or type(message) ~= "string"
    or not find(template, "%s", 1, true) then
    return nil
  end

  if template ~= offlineTemplate then
    local escaped = gsub(template, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")

    offlineTemplate, offlinePattern = template, (gsub(escaped, "%%%%s", "(.+)"))
  end

  return baseName(match(message, offlinePattern))
end

local onSystem

local function unwatch()
  if watching then
    watching = false
    Bus.offCore("CHAT_MSG_SYSTEM", onSystem)
  end
end

local function watch()
  if not watching then
    watching = true
    Bus.onCore("CHAT_MSG_SYSTEM", onSystem)
  end
end

local function settle(dones, count)
  for index = 1, count do
    Lib.safeCall(dones[index], false)
  end
end

local function release(slot, cell)
  local a, b, c, done = mA[slot], mB[slot], mC[slot], mDone[slot]
  local lane, dest = cLane[cell], cDest[cell]

  mA[slot], mB[slot], mC[slot], mDone[slot], mKey[slot], mBody[slot] = nil, nil, nil, nil, nil, nil
  mNext[slot] = mFree
  mFree = slot
  laneLive[lane] = laneLive[lane] - 1
  dLive[dest] = dLive[dest] - 1
  pLive = pLive - 1

  return a, b, c, done
end

local function strip(heads, tails, cell, dones)
  local slot = heads[cell]
  local removed = 0

  while slot ~= 0 do
    local after = mNext[slot]
    local _, _, _, done = release(slot, cell)

    if done then
      dones[#dones + 1] = done
    end

    removed = removed + 1
    slot = after
  end

  heads[cell], tails[cell] = 0, 0

  return removed
end

local function purgeWhispers(target, lanes)
  local dest = playerDest[target]

  if not dest or dLive[dest] == 0 then
    return 0
  end

  local dones = {}
  local removed = 0
  local cell = dLast[dest]

  for _ = 1, dCells[dest] do
    cell = cNext[cell]
    local own = strip(cSmallHead, cSmallTail, cell, dones) + strip(cBigHead, cBigTail, cell, dones)

    removed = removed + own

    if own > 0 and lanes then
      lanes[#lanes + 1] = laneName[cLane[cell]]
    end
  end

  if dBig[dest] > 0 then
    bigLive = bigLive - dBig[dest]
    held = false
  end

  dSmall[dest], dBig[dest] = 0, 0

  if cur ~= 0 and cDest[cur] == dest then
    cur, curLeft = 0, 0
  end

  settle(dones, #dones)

  return removed
end

local function heldOffline(key)
  local until_ = offlineUntil[key]

  if not until_ then
    return false
  end

  if now() >= until_ then
    offlineUntil[key] = nil
    return false
  end

  return true
end

function Queue.isOffline(target)
  return heldOffline(fold(target))
end

onSystem = function(message)
  local current = now()
  local alive = false

  for name, at in pairs(recentWhisper) do
    if current - at > MASK_WINDOW then
      recentWhisper[name] = nil
    else
      alive = true
    end
  end

  if not alive then
    unwatch()
    return
  end

  local name = offlinePlayer(message)
  local key = name and fold(name)

  if not key or not recentWhisper[key] or heldOffline(key) then
    return
  end

  offlineUntil[key] = current + OFFLINE_HOLD

  local lanes = {}
  local removed = purgeWhispers(key, lanes)

  dropped.offline = dropped.offline + removed

  Log.trace("offline", nil, name, removed, current)

  if removed > 0 then
    Problems.report(Problems.new("EbonAPI", "QUEUE.PEER_OFFLINE", {
      player = name, addon = concat(lanes, ", "), purged = removed,
    }))
  end

  EbonAPI:Emit("PEER_OFFLINE", name, removed)
end

local function dispatch(kind, a, b, c, lane)
  local fn = senders[kind]
  local ok, err

  if fn ~= nil then
    ok, err = fn(a, b, c)
  else
    err = "no sender is registered for " .. kind
  end

  if ok then
    sent[kind] = (sent[kind] or 0) + 1
    Log.trace("send", nil, kind, a)
  else
    dropped.failed = dropped.failed + 1
    Log.trace("fail", nil, kind, a)

    Problems.report(Problems.new("EbonAPI", "QUEUE.SEND_FAILED", {
      addon = lane, kind = kind, target = kind == "whisper" and b or kind,
      error = tostring(err or "the send function returned false"),
    }))

    EbonAPI:Emit("SEND_FAILED", kind, a, b)
  end

  return ok
end

local function popServer()
  local payload = sPayload[sFirst]

  sPayload[sFirst] = nil
  sFirst = sFirst + 1

  if sFirst > sLast then
    sFirst, sLast = 1, 0
  end

  return payload
end

local function ready(kind)
  local state = gateOpen[kind]

  if state == nil then
    local gate = gates[kind]

    state = not gate or (gate() and true or false)
    gateOpen[kind] = state
  end

  return state
end

local function takeSmall()
  local dest = smallTurn

  for _ = 1, dTop do
    dest = dest % dTop + 1

    if dSmall[dest] > 0 and ready(dKind[dest]) then
      local cell = dSmallAt[dest]

      if cell == 0 then
        cell = dLast[dest]
      end

      for _ = 1, dCells[dest] do
        cell = cNext[cell]

        local slot = cSmallHead[cell]

        if slot ~= 0 and mSeq[slot] <= limit then
          local after = mNext[slot]

          cSmallHead[cell] = after

          if after == 0 then
            cSmallTail[cell] = 0
          end

          dSmall[dest] = dSmall[dest] - 1
          dSmallAt[dest] = cell
          smallTurn = dest

          return slot, cell
        end
      end
    end
  end

  return nil
end

local function takePart()
  local cell = cur
  local dest = cDest[cell]
  local slot = cBigHead[cell]
  local after = mNext[slot]

  cBigHead[cell] = after

  if after == 0 then
    cBigTail[cell] = 0
  end

  dBig[dest] = dBig[dest] - 1
  bigLive = bigLive - 1
  curLeft = curLeft - 1

  if curLeft == 0 then
    cur = 0
    held = false
  end

  return slot, cell
end

local function takeBig()
  local dest = bigTurn

  for _ = 1, dTop do
    dest = dest % dTop + 1

    if dBig[dest] > 0 and ready(dKind[dest]) then
      local cell = dBigAt[dest]

      if cell == 0 then
        cell = dLast[dest]
      end

      for _ = 1, dCells[dest] do
        cell = cNext[cell]

        local slot = cBigHead[cell]

        if slot ~= 0 then
          dBigAt[dest] = cell
          bigTurn = dest
          curTotal = mCount[slot]
          cur, curLeft = cell, curTotal

          return takePart()
        end
      end
    end
  end

  return nil
end

local function cut()
  local cell = cur
  local dest = cDest[cell]
  local removed = curLeft
  local total = curTotal
  local headA, headB, headC, done

  for index = 1, removed do
    local slot = cBigHead[cell]

    cBigHead[cell] = mNext[slot]

    local a, b, c, last = release(slot, cell)

    if index == 1 then
      headA, headB, headC = a, b, c
    end

    done = last or done
  end

  if cBigHead[cell] == 0 then
    cBigTail[cell] = 0
  end

  dBig[dest] = dBig[dest] - removed
  bigLive = bigLive - removed
  dropped.failed = dropped.failed + removed
  cur, curLeft = 0, 0
  held = false

  Log.trace("cut", nil, dKind[dest], removed)

  local kind = dKind[dest]
  local op = match(kind == "whisper" and headC or headA, "^EAS:(%w+):")
    or match(headA or "", "^EA1:[%w_]+:(%w+):")

  Problems.report(Problems.new("EbonAPI", "QUEUE.STREAM_CUT", {
    addon = laneName[cLane[cell]], op = op or "unknown", sent = total - removed, total = total,
  }))

  EbonAPI:Emit("SEND_FAILED", kind, headA, headB)

  if done then
    Lib.safeCall(done, false)
  end
end

local function bigReady()
  for dest = 1, dTop do
    if dBig[dest] > 0 and ready(dKind[dest]) then
      return true
    end
  end

  return false
end

local function takePeer()
  for kind in pairs(gateOpen) do
    gateOpen[kind] = nil
  end

  if cur ~= 0 then
    if ready(dKind[cDest[cur]]) then
      return takePart()
    end

    cut()
  end

  if not held then
    limit = seq
    held = bigLive > 0 and bigReady()
  end

  local slot, cell = takeSmall()

  if slot or not held then
    return slot, cell
  end

  slot, cell = takeBig()

  if slot then
    return slot, cell
  end

  held = false

  if limit == seq then
    return nil
  end

  limit = seq

  return takeSmall()
end

local function forget()
  for name in pairs(laneOf) do
    laneName[laneOf[name]] = nil
    laneOf[name] = nil
  end

  for name in pairs(playerDest) do
    playerDest[name] = nil
  end

  for kind in pairs(kindDest) do
    kindDest[kind] = nil
  end

  laneCount, dTop, cTop = 0, 0, 0
  smallTurn, bigTurn = 0, 0
  seq, limit = 0, 0
  held = false
  cur, curLeft = 0, 0
  bigLive = 0
end

local function drain()
  if sFirst <= sLast then
    dispatch("server", popServer(), nil, nil, "EbonAPI")
  else
    local slot, cell = takePeer()

    if slot then
      local dest = cDest[cell]
      local kind = dKind[dest]
      local a, b, c, done = release(slot, cell)

      if kind == "whisper" then
        recentWhisper[dKey[dest]] = now()
        watch()
      end

      local ok = dispatch(kind, a, b, c, laneName[cLane[cell]])

      if done then
        Lib.safeCall(done, ok and true or false)
      end
    elseif pLive > 0 then
      Bus.untick("EbonAPI:queue")
      return
    end
  end

  if pLive == 0 then
    if dTop > 0 then
      forget()
    end

    if sFirst > sLast then
      Bus.untick("EbonAPI:queue")
    end
  end
end

local function arm()
  Bus.tick("EbonAPI:queue", SEND_INTERVAL, drain)
end

function Queue.wake()
  if sFirst <= sLast or pLive > 0 then
    arm()
  end
end

local function refuse(done)
  if done then
    Lib.safeCall(done, false)
  end

  return false
end

function Queue.pushServer(payload)
  sLast = sLast + 1
  sPayload[sLast] = payload

  arm()

  return true
end

function Queue.room(lane)
  local free = PEER_CAP - pLive

  if free < 0 then
    free = 0
  end

  if lane == nil then
    return free
  end

  local index = laneOf[lane]
  local own = LANE_CAP - (index and laneLive[index] or 0)

  if own < 0 then
    own = 0
  end

  return own < free and own or free
end

function Queue.waitingFor(target)
  local name = baseName(target)
  local dest = name and playerDest[fold(name)]

  return dest and dLive[dest] or 0
end

local function laneFor(lane)
  local index = laneCount + 1

  laneCount = index
  laneOf[lane] = index
  laneName[index] = lane
  laneLive[index] = 0

  return index
end

local function destFor(map, key, kind)
  local dest = dTop + 1

  dTop = dest
  map[key] = dest
  dKind[dest], dKey[dest] = kind, key
  dLive[dest], dSmall[dest], dBig[dest] = 0, 0, 0
  dLast[dest], dCells[dest], dSmallAt[dest], dBigAt[dest] = 0, 0, 0, 0

  return dest
end

local function cellFor(dest, lane)
  local last = dLast[dest]
  local cell = last

  for _ = 1, dCells[dest] do
    cell = cNext[cell]

    if cLane[cell] == lane then
      return cell
    end
  end

  cell = cTop + 1
  cTop = cell
  cDest[cell], cLane[cell] = dest, lane
  cSmallHead[cell], cSmallTail[cell], cBigHead[cell], cBigTail[cell] = 0, 0, 0, 0

  if last == 0 then
    cNext[cell] = cell
  else
    cNext[cell] = cNext[last]
    cNext[last] = cell
  end

  dLast[dest] = cell
  dCells[dest] = dCells[dest] + 1

  return cell
end

local function add(heads, tails, cell, a, b, c, done)
  local slot = mFree

  if slot ~= 0 then
    mFree = mNext[slot]
  else
    slot = mTop + 1
    mTop = slot
  end

  mA[slot], mB[slot], mC[slot], mDone[slot], mNext[slot] = a, b, c, done, 0

  local tail = tails[cell]

  if tail == 0 then
    heads[cell] = slot
  else
    mNext[tail] = slot
  end

  tails[cell] = slot

  local lane, dest = cLane[cell], cDest[cell]

  laneLive[lane] = laneLive[lane] + 1
  dLive[dest] = dLive[dest] + 1
  pLive = pLive + 1

  return slot
end

local function listed(slot, a, key, body, single)
  while slot ~= 0 do
    local own = mBody[slot]

    if own ~= nil and mKey[slot] == key and mA[slot] == a and (single or own == body) then
      return true
    end

    slot = mNext[slot]
  end

  return false
end

local function waiting(dest, a, key, body, single)
  local cell = dLast[dest]

  for _ = 1, dCells[dest] do
    cell = cNext[cell]

    if listed(cSmallHead[cell], a, key, body, single) or listed(cBigHead[cell], a, key, body, single) then
      return true
    end
  end

  return false
end

local function submit(kind, a, b, c, parts, count, lane, done, key, body, single)
  local plain = kind == "whisper"

  if lane == nil then
    lane = plain and a or kind
  end

  local map, name = kindDest, kind

  if plain then
    map, name = playerDest, fold(b)
  end

  local dest = map[name]
  local own = plain and not done and body ~= nil

  if own and dest and waiting(dest, a, key, body, single) then
    return true, "waiting"
  end

  local index = laneOf[lane]
  local live = index and laneLive[index] or 0

  local full

  if count == 1 then
    if pLive >= PEER_CAP + RESERVE then
      full = "peers"
    end
  elseif count > 1 then
    if count > PEER_CAP - pLive then
      full = "peers"
    elseif live > 0 and live + count > LANE_CAP then
      full = "lane"
    end
  end

  if full then
    dropped.full = dropped.full + 1

    Problems.report(Problems.new("EbonAPI", "QUEUE.FULL", {
      addon = lane, queue = full, kind = kind, parts = count,
      waiting = full == "lane" and live or pLive,
    }))

    return false, "full"
  end

  if plain and heldOffline(name) then
    return false, "offline"
  end

  if count < 1 then
    return true
  end

  dest = dest or destFor(map, name, kind)

  local cell = cellFor(dest, index or laneFor(lane))
  local heads, tails = cSmallHead, cSmallTail

  if count > 1 then
    heads, tails = cBigHead, cBigTail
  end

  local first

  for part = 1, count do
    local head, text = a, c

    if parts then
      if a == nil then
        head = parts[part]
      else
        text = parts[part]
      end
    end

    local slot = add(heads, tails, cell, head, b, text, part == count and done or nil)

    first = first or slot
  end

  if own then
    mKey[first], mBody[first] = key, body
  end

  if count > 1 then
    mCount[first] = count
    dBig[dest] = dBig[dest] + count
    bigLive = bigLive + count
  else
    seq = seq + 1
    mSeq[first] = seq
    dSmall[dest] = dSmall[dest] + 1
  end

  arm()

  return true
end

function Queue.push(kind, a, b, c, done, lane)
  if type(kind) ~= "string" or not senders[kind] then
    error("EbonAPI.Queue.push: unknown kind " .. tostring(kind), 2)
  end

  local ok, why = submit(kind, a, b, c, nil, 1, lane, done, false, c)

  if ok then
    return true, why
  end

  if why == "offline" then
    dropped.offline = dropped.offline + 1
  end

  return refuse(done)
end

function Queue.pushAll(kind, a, b, parts, count, lane, done, key, body, single)
  if type(kind) ~= "string" or not senders[kind] then
    error("EbonAPI.Queue.pushAll: unknown kind " .. tostring(kind), 2)
  end

  return submit(kind, a, b, nil, parts, count, lane, done, key or false, body, single)
end

function Queue.serverLength()
  return sLast - sFirst + 1
end

function Queue.peerLength()
  return pLive
end

function Queue.length()
  return Queue.serverLength() + pLive
end

function Queue.clear()
  for index = sFirst, sLast do
    sPayload[index] = nil
  end

  local dones, count = {}, 0

  for slot = 1, mTop do
    if mDone[slot] then
      count = count + 1
      dones[count] = mDone[slot]
    end

    mA[slot], mB[slot], mC[slot], mDone[slot], mNext[slot] = nil, nil, nil, nil, nil
    mSeq[slot], mCount[slot], mKey[slot], mBody[slot] = nil, nil, nil, nil
  end

  sFirst, sLast = 1, 0
  mTop, mFree = 0, 0
  pLive = 0

  forget()

  Bus.untick("EbonAPI:queue")

  settle(dones, count)
end

Queue.register("whisper", rawWhisper)

-- Whether the line stays out of the chat, and why: "own" EbonAPI whispered the player,
-- "addon" another addon did, "unknown" nobody here did. Only a chat whisper the player (or a
-- reply addon) sent keeps its line, once per whisper.
local function masked(key, current)
  local at = foreignWhisper[key]

  if at and current - at <= ANSWER_WINDOW and foreignLeft[key] > 0 then
    foreignLeft[key] = foreignLeft[key] - 1
    return false
  end

  at = recentWhisper[key]

  if at and current - at <= MASK_WINDOW then
    return true, "own"
  end

  at = offlineUntil[key]

  if at and current < at then
    return true, "own"
  end

  at = addonWhisper[key]

  if at and current - at <= ANSWER_WINDOW then
    return true, "addon"
  end

  return true, "unknown"
end

-- Every chat frame that shows system lines runs the filter on the same line: the line is judged
-- once, and the other frames get the same answer. A frame that asks again holds a new line.
function Queue.ownOffline(message, frame)
  local name = offlinePlayer(message)

  if not name then
    return false
  end

  local current = now()

  if frame and message == lastText and current == lastAt and not judged[frame] then
    judged[frame] = true
    return lastMasked
  end

  for other in pairs(judged) do
    judged[other] = nil
  end

  if frame then
    judged[frame] = true
  end

  local hide, cause = masked(fold(name), current)

  if hide then
    local hidden = Queue.hidden

    hidden[cause] = hidden[cause] + 1
    Problems.reject("EbonAPI", "QUEUE.LINE_HIDDEN", { player = name, reason = cause })
  end

  lastText, lastAt, lastMasked = message, current, hide

  return hide
end

function Queue.foreignCount()
  local count = 0

  for _ in pairs(foreignWhisper) do
    count = count + 1
  end

  return count
end

if hooksecurefunc then
  if SendChatMessage then
    hooksecurefunc("SendChatMessage", function(_, kind, _, target)
      noteForeign(kind, target, true)
    end)
  end

  if SendAddonMessage then
    hooksecurefunc("SendAddonMessage", function(_, _, kind, target)
      noteForeign(kind, target)
    end)
  end
end

if ChatFrame_AddMessageEventFilter then
  ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(frame, _, message)
    return Queue.ownOffline(message, frame)
  end)
end
