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
local floor, sort, sub = math.floor, table.sort, string.sub

local SEND_INTERVAL = 0.15
local PEER_CAP = 500
local LANE_CAP = 250
local RESERVE = 50
local OFFLINE_HOLD = 60
local MASK_WINDOW = 300
local ANSWER_WINDOW = 5
local CHAT_PAUSE = 1
local PROBE_WAIT = 1.5
local ALIVE_TTL = 120

Queue.SEND_INTERVAL = SEND_INTERVAL
Queue.DEFAULT_INTERVAL = SEND_INTERVAL
Queue.MIN_RATE, Queue.MAX_RATE = 1, 100
Queue.BURST_BELOW, Queue.BURST_MAX = 0.05, 8
Queue.AUTO_MAX_RATE = 20
Queue.hSmall, Queue.hParts = {}, {}
Queue.PROBE_WAIT = PROBE_WAIT
Queue.ALIVE_TTL = ALIVE_TTL
Queue.PEER_CAP = PEER_CAP
Queue.LANE_CAP = LANE_CAP
Queue.RESERVE = RESERVE
Queue.OFFLINE_HOLD = OFFLINE_HOLD
Queue.MASK_WINDOW = MASK_WINDOW
Queue.ANSWER_WINDOW = ANSWER_WINDOW
Queue.CHAT_PAUSE = CHAT_PAUSE

local senders = {}
local gates = {}
local gateOpen = {}
local merges = {}
local holdUntil = {}
local pauseSeen = false
local afterSmall = false
local tookSmall = false
local aliveAt, aliveSwept = {}, 0
local dProbe = {}

local mAt, sAt = {}, {}
local HISTORY, RECENT, DEST_STATS = 360, 200, 300
local STEPS = { 1, 5, 15, 30, 60, 120 }
local hSec, hIn, hOut, hLen, hWaitSum, hWaitMax = {}, {}, {}, {}, {}, {}
local hDrop = {}
local lastSec, secondOf
local laneStat, destStat = {}, {}
local destCount = 0
local rAt, rWho, rKind, rLane, rOp, rDetail, rWait, rOk = {}, {}, {}, {}, {}, {}, {}, {}
local rNext, rCount = 1, 0
local statsSince

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

local function drop(kind, count)
  dropped[kind] = dropped[kind] + count

  local i = secondOf(now())

  hDrop[i] = hDrop[i] + count
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

function Queue.register(kind, fn, ready, merge)
  if type(kind) ~= "string" or type(fn) ~= "function" then
    error("EbonAPI.Queue.register expects a kind and a function", 2)
  end

  senders[kind] = fn
  gates[kind] = ready
  merges[kind] = merge
end

function Queue.hold(kind, seconds)
  holdUntil[kind] = now() + seconds
end

function Queue.mark(on)
  sending = on and true or false
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
-- addon) shows its "not found" line: one line per whisper the game could not deliver, counted.
-- An addon message, which the player never sees, hides it, whoever sends it: the server requests
-- of the Bridge and of ProjectEbonhold, and the whispers of any other addon.
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
  mAt[slot] = nil
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
  dProbe[dest] = nil

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

  drop("offline", removed)

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
    drop("failed", 1)
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
  local payload, at = sPayload[sFirst], sAt[sFirst]

  sPayload[sFirst], sAt[sFirst] = nil, nil
  sFirst = sFirst + 1

  if sFirst > sLast then
    sFirst, sLast = 1, 0
  end

  return payload, at
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

local function paused(kind)
  local at = holdUntil[kind]

  if at and now() < at then
    pauseSeen = true
    return true
  end

  return false
end

local function open(kind)
  return ready(kind) and not paused(kind)
end

local function aliveNow(key)
  local at = aliveAt[key]

  return at ~= nil and now() - at <= ALIVE_TTL
end

-- A player who wrote to us lately is online. Called for every line that comes from a player.
function Queue.heard(name)
  local base = baseName(name)

  if not base then
    return
  end

  local current = now()

  if current - aliveSwept > ALIVE_TTL then
    aliveSwept = current

    for other, at in pairs(aliveAt) do
      if current - at > ALIVE_TTL then
        aliveAt[other] = nil
      end
    end
  end

  aliveAt[fold(base)] = current
end

-- Whether the player is known to be online: heard from, or a first whisper that was not answered
-- "not found", in the last ALIVE_TTL seconds.
function Queue.alive(target)
  local base = baseName(target)

  return base ~= nil and aliveNow(fold(base))
end

-- A player we have not heard from gets one message first. The rest of what waits for them is held
-- for PROBE_WAIT seconds, long enough for the game to answer "not found"; if it does, the whole
-- wait is purged, a handful of messages at most instead of a pile. If it does not, they are online.
local function probing(dest)
  local at = dProbe[dest]

  if not at then
    return false
  end

  local current = now()

  if current < at then
    pauseSeen = true
    return true
  end

  dProbe[dest] = nil
  aliveAt[dKey[dest]] = current

  return false
end

local function openDest(dest)
  return open(dKind[dest]) and not (dProbe[dest] and probing(dest))
end

local function popSmall(dest, take)
  local cell = dSmallAt[dest]

  if cell == 0 then
    cell = dLast[dest]
  end

  for _ = 1, dCells[dest] do
    cell = cNext[cell]

    local slot = cSmallHead[cell]

    if slot ~= 0 and mSeq[slot] <= limit then
      if take then
        local after = mNext[slot]

        cSmallHead[cell] = after

        if after == 0 then
          cSmallTail[cell] = 0
        end

        dSmall[dest] = dSmall[dest] - 1
        dSmallAt[dest] = cell
        tookSmall = true
      end

      return slot, cell
    end
  end

  return nil
end

local function takeSmall()
  local dest = smallTurn

  for _ = 1, dTop do
    dest = dest % dTop + 1

    if dSmall[dest] > 0 and openDest(dest) then
      local slot, cell = popSmall(dest, true)

      if slot then
        smallTurn = dest

        return slot, cell
      end
    end
  end

  return nil
end

local function takePart()
  tookSmall = false

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

    if dBig[dest] > 0 and openDest(dest) then
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
  drop("failed", removed)
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
    if dBig[dest] > 0 and openDest(dest) then
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
    local kind = dKind[cDest[cur]]

    if ready(kind) then
      local keep = limit

      limit = seq

      if paused(kind) or probing(cDest[cur]) then
        local slot, cell = takeSmall()

        limit = keep

        return slot, cell
      end

      if not afterSmall then
        local slot, cell = takeSmall()

        if slot then
          afterSmall = true
          limit = keep

          return slot, cell
        end
      end

      afterSmall = false
      limit = keep

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
  afterSmall = false
end

local texts, extraSlot, extraCell, usedLane = {}, {}, {}, {}

local function gather(kind, dest, first, firstCell)
  local merge = merges[kind]
  local count = 0

  if not merge then
    return 0
  end

  texts[1] = first
  usedLane[cLane[firstCell]] = true

  local line

  while true do
    local slot = popSmall(dest, false)

    if not slot or mB[slot] ~= nil or mC[slot] ~= nil or mA[slot] == nil then
      break
    end

    texts[count + 2] = mA[slot]

    local joined = merge(texts, count + 2)

    if not joined then
      texts[count + 2] = nil
      break
    end

    local cell
    slot, cell = popSmall(dest, true)
    usedLane[cLane[cell]] = true
    count = count + 1
    extraSlot[count], extraCell[count] = slot, cell
    line = joined
  end

  for index = 1, count + 1 do
    texts[index] = nil
  end

  for lane in pairs(usedLane) do
    usedLane[lane] = nil
  end

  return count, line
end

local function total()
  return pLive + (sLast >= sFirst and sLast - sFirst + 1 or 0)
end

-- The history keeps one cell per second: what came in, what went out, how long the sent messages
-- waited and how long the queue was at the end of the second. A second nobody touched is closed
-- the next time something asks, with the length it had.
secondOf = function(current)
  local sec = floor(current)

  if sec ~= lastSec then
    local from = lastSec and lastSec + 1 or sec

    if sec - from >= HISTORY then
      from = sec - HISTORY + 1
    end

    for at = from, sec do
      local i = at % HISTORY + 1

      hSec[i], hIn[i], hOut[i], hWaitSum[i], hWaitMax[i], hLen[i] = at, 0, 0, 0, 0, total()
      hDrop[i] = 0
      Queue.hSmall[i], Queue.hParts[i] = 0, 0
    end

    lastSec = sec
  end

  return sec % HISTORY + 1
end

local function laneEntry(lane)
  local item = laneStat[lane]

  if not item then
    item = { sent = 0, queued = 0, failed = 0, wait = 0, max = 0, last = 0, buckets = { 0, 0, 0, 0, 0, 0, 0 } }
    laneStat[lane] = item
  end

  return item
end

local function destEntry(key, name, kind)
  local item = destStat[key]

  if not item then
    if destCount >= DEST_STATS then
      local oldest, oldestAt

      for other, entry in pairs(destStat) do
        if not oldestAt or entry.last < oldestAt then
          oldest, oldestAt = other, entry.last
        end
      end

      if oldest then
        destStat[oldest] = nil
        destCount = destCount - 1
      end
    end

    item = { name = name, kind = kind, queued = 0, sent = 0, failed = 0, wait = 0, max = 0, last = 0, lane = "" }
    destStat[key] = item
    destCount = destCount + 1
  end

  return item
end

-- What a message is, for the eye: its operation and a short detail.
local function describe(kind, a, b, c)
  if kind == "whisper" then
    local text = c or ""
    local op, id, k, n = match(text, "^EAS:(%w+):([^:]+):(%d+)/(%d+):")

    if op then
      return op, id, tonumber(k), tonumber(n)
    end

    local head, rest = match(text, "^(%a):(.*)")

    if head then
      return head, sub(rest, 1, 40)
    end

    return "?", sub(text, 1, 40)
  elseif kind == "channel" then
    local text = a or ""

    return match(text, "^EA%d:[%w_]+:(%w+)") or "line", sub(text, 1, 40)
  end

  return "server", ""
end

local function recordArrival(lane, kind, key, who, count)
  local current = now()
  local i = secondOf(current)
  local item = laneEntry(lane)
  local dest = destEntry(key, who, kind)

  statsSince = statsSince or current
  hIn[i] = hIn[i] + count
  hLen[i] = total()
  item.queued = item.queued + count
  dest.queued = dest.queued + count
end

local function recordSend(kind, lane, key, who, op, detail, queuedAt, ok, ring, part)
  local current = now()
  local wait = queuedAt and current - queuedAt or 0
  local i = secondOf(current)
  local item = laneEntry(lane)
  local dest = destEntry(key, who, kind)
  local step = 1

  statsSince = statsSince or current
  hOut[i] = hOut[i] + 1
  hWaitSum[i] = hWaitSum[i] + wait
  hLen[i] = total()

  if wait > hWaitMax[i] then
    hWaitMax[i] = wait
  end

  local peaks = part and Queue.hParts or Queue.hSmall

  if wait > peaks[i] then
    peaks[i] = wait
  end

  while step <= #STEPS and wait > STEPS[step] do
    step = step + 1
  end

  item.last, dest.last, dest.lane = current, current, lane
  item.wait, dest.wait = item.wait + wait, dest.wait + wait
  item.buckets[step] = item.buckets[step] + 1

  if wait > item.max then
    item.max = wait
  end

  if wait > dest.max then
    dest.max = wait
  end

  if ok then
    item.sent, dest.sent = item.sent + 1, dest.sent + 1
  else
    item.failed, dest.failed = item.failed + 1, dest.failed + 1
  end

  if ring then
    local n = rNext

    rAt[n], rWho[n], rKind[n], rLane[n], rOp[n], rDetail[n], rWait[n], rOk[n] =
      current, who, kind, lane, op, detail, wait, ok and true or false
    rNext = n % RECENT + 1

    if rCount < RECENT then
      rCount = rCount + 1
    end
  end
end

function Queue.sendOne()
  if sFirst <= sLast then
    local payload, queuedAt = popServer()
    local ok = dispatch("server", payload, nil, nil, "EbonAPI")

    recordSend("server", "EbonAPI", "server", "server", "server", "", queuedAt, ok, true)
  else
    pauseSeen = false
    tookSmall = false

    local slot, cell = takePeer()

    if slot then
      local dest = cDest[cell]
      local kind = dKind[dest]
      local lane, key = laneName[cLane[cell]], dKey[dest]
      local queuedAt = mAt[slot]
      local a, b, c, done = release(slot, cell)
      local extra, line = 0

      if tookSmall and b == nil and c == nil then
        extra, line = gather(kind, dest, a, cell)
      end

      if kind == "whisper" then
        recentWhisper[dKey[dest]] = now()
        watch()

        if dLive[dest] > 0 and not dProbe[dest] and not aliveNow(dKey[dest]) then
          dProbe[dest] = now() + PROBE_WAIT
        end
      end

      local ok = dispatch(kind, line or a, b, c, lane)
      local dones
      local who = kind == "whisper" and b or kind
      local op, detail, part, parts = describe(kind, line or a, b, c)

      recordSend(kind, lane, key, who, op, part and detail .. " " .. part .. "/" .. parts or detail,
        queuedAt, ok, true, part ~= nil)

      if extra > 0 then
        dones = {}

        for index = 1, extra do
          local at = mAt[extraSlot[index]]
          local _, _, _, last = release(extraSlot[index], extraCell[index])

          dones[index] = last
          recordSend(kind, lane, key, who, op, detail, at, ok, false)
        end
      end

      if done then
        Lib.safeCall(done, ok and true or false)
      end

      for index = 1, extra do
        if dones[index] then
          Lib.safeCall(dones[index], ok and true or false)
        end
      end
    elseif pLive > 0 then
      if not pauseSeen then
        Bus.untick("EbonAPI:queue")
      end

      return false
    end
  end

  if pLive == 0 then
    if dTop > 0 then
      forget()
    end

    if sFirst > sLast then
      Queue.awake = false
      Bus.untick("EbonAPI:queue")
    end
  end

  return true
end

-- Up to 20 messages per second the ticker of the bus gives one message per tick. Above that, one frame
-- of the game lasts longer than the interval: the time elapsed since the last tick says how many
-- messages are due, and at most BURST_MAX leave in one frame.
local function drain()
  local ctl = _G.ChatThrottleLib

  -- CTL users (WIM, Ace addons) stall while our traffic keeps its budget negative.
  if ctl and ctl.bQueueing then
    return
  end

  local count = 1

  if SEND_INTERVAL < Queue.BURST_BELOW then
    local current = now()
    local last = Queue.creditAt
    local credit = Queue.credit or 0

    Queue.creditAt = current

    if last and current - last < 1 then
      credit = credit + (current - last) / SEND_INTERVAL
    else
      credit = credit + 1
    end

    count = floor(credit + 0.001)

    if count > Queue.BURST_MAX then
      count = Queue.BURST_MAX
    end

    Queue.credit = credit - count > 1 and 1 or credit - count

    if count < 1 then
      return
    end
  end

  local done = 0
  local ring = Queue.guarded and Queue.ring

  for _ = 1, count do
    if ring and ring[Queue.ringAt] and now() - ring[Queue.ringAt] < 1 then
      break
    end

    if Queue.sendOne() == false then
      break
    end

    done = done + 1

    if ring then
      ring[Queue.ringAt] = now()
      Queue.ringAt = Queue.ringAt % Queue.AUTO_MAX_RATE + 1
    end

    if pLive == 0 and sFirst > sLast then
      break
    end
  end

  if count > done and SEND_INTERVAL < Queue.BURST_BELOW then
    local credit = (Queue.credit or 0) + count - done

    Queue.credit = credit > 1 and 1 or credit
  end
end

local function arm()
  if not Queue.awake then
    Queue.awake = true

    if Queue.onWake then
      Lib.safeCall(Queue.onWake)
    end
  end

  Bus.tick("EbonAPI:queue", SEND_INTERVAL, drain)
end

function Queue.wake()
  if sFirst <= sLast or pLive > 0 then
    arm()
  end
end

-- The pacing sets the rate with the source "auto": up to AUTO_MAX_RATE per second, and never more than
-- that many sends in any second. Without a source the rate is free from 1 to 100 per second, with no
-- guard. A reload brings back the normal pace.
function Queue.setInterval(interval)
  if interval == SEND_INTERVAL then
    return
  end

  SEND_INTERVAL = interval
  Queue.SEND_INTERVAL = interval
  Queue.credit, Queue.creditAt = 0, nil
  Queue.wake()
end

function Queue.rate()
  return 1 / SEND_INTERVAL
end

function Queue.setRate(perSecond, source)
  if type(perSecond) ~= "number" or perSecond ~= perSecond then
    return false
  end

  local auto = source == "auto"
  local top = auto and Queue.AUTO_MAX_RATE or Queue.MAX_RATE

  if perSecond < Queue.MIN_RATE then
    perSecond = Queue.MIN_RATE
  elseif perSecond > top then
    perSecond = top
  end

  Queue.guarded = auto

  if auto and not Queue.ring then
    Queue.ring, Queue.ringAt = {}, 1
  end

  Queue.setInterval(1 / perSecond)

  return true
end

local function refuse(done)
  if done then
    Lib.safeCall(done, false)
  end

  return false
end

function Queue.pushServer(payload)
  sLast = sLast + 1
  sPayload[sLast], sAt[sLast] = payload, now()
  recordArrival("EbonAPI", "server", "server", "server", 1)

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

-- Which cap a batch of count messages for a lane would break ("peers" or "lane"), nil when it fits,
-- then the messages the lane has waiting. The one test behind both the refusal of a submit and
-- Queue.fits.
local function overflow(lane, count)
  local index = laneOf[lane]
  local live = index and laneLive[index] or 0

  if count == 1 then
    if pLive >= PEER_CAP + RESERVE then
      return "peers", live
    end
  elseif count > 1 then
    if count > PEER_CAP - pLive then
      return "peers", live
    elseif live > 0 and live + count > LANE_CAP then
      return "lane", live
    end
  end

  return nil, live
end

-- Whether count more messages for a lane would be accepted: a sender asks before it builds a big
-- batch (a service reply, a request), and declines or defers when it would only be refused.
function Queue.fits(lane, count)
  return overflow(lane, count) == nil
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
  dProbe[dest] = nil

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
  mAt[slot] = now()

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
  local full, live = overflow(lane, count)

  if full then
    drop("full", 1)

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

  recordArrival(lane, kind, name, plain and b or kind, count)

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
    drop("offline", 1)
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

-- Views for the diagnostic window. They only read: nothing here moves a message.

local function holdOf(dest)
  local current = now()
  local probe = dProbe[dest]

  if probe and probe > current then
    return "probe", probe - current
  end

  if dKind[dest] == "whisper" then
    local until_ = offlineUntil[dKey[dest]]

    if until_ and until_ > current then
      return "offline", until_ - current
    end
  end

  local pause = holdUntil[dKind[dest]]

  if pause and pause > current then
    return "pause", pause - current
  end

  return nil
end

local function itemOf(dest, cell, slot, current)
  local kind = dKind[dest]
  local a, b, c = mA[slot], mB[slot], mC[slot]
  local op, detail, part, parts = describe(kind, a, b, c)
  local held, heldFor = holdOf(dest)

  return {
    who = kind == "whisper" and (b or dKey[dest]) or kind, kind = kind, lane = laneName[cLane[cell]],
    op = op, detail = part and detail .. " " .. part .. "/" .. parts or detail,
    age = current - (mAt[slot] or current), held = held, heldFor = heldFor,
  }
end

-- Every message waiting, one row per small message and one per stream, in the order the queue will
-- most likely send them: the small messages go round by destination, a stream waits until they are
-- done and then shares the pace with them. The order and the "eta" are an estimate, the ages are not.
function Queue.content()
  local current = now()
  local rows, count = {}, 0
  local small, smallTotal = {}, 0

  for dest = 1, dTop do
    if dSmall[dest] > 0 then
      local cells, cellCount = {}, 0
      local cell = dSmallAt[dest]

      if cell == 0 then
        cell = dLast[dest]
      end

      for _ = 1, dCells[dest] do
        cell = cNext[cell]
        cellCount = cellCount + 1
        cells[cellCount] = { cell = cell, slot = cSmallHead[cell] }
      end

      local list, n = {}, 0
      local more = true

      while more do
        more = false

        for index = 1, cellCount do
          local item = cells[index]

          if item.slot ~= 0 then
            n = n + 1
            list[n] = { slot = item.slot, cell = item.cell }
            item.slot = mNext[item.slot]

            if item.slot ~= 0 then
              more = true
            end
          end
        end
      end

      small[dest] = list
      smallTotal = smallTotal + n
    end
  end

  local order, orderCount = {}, 0
  local turn = smallTurn

  for _ = 1, dTop do
    turn = turn % dTop + 1

    if small[turn] then
      orderCount = orderCount + 1
      order[orderCount] = turn
    end
  end

  local rank, round = 0, 1
  local pace = SEND_INTERVAL * (cur ~= 0 and 2 or 1)
  local more = orderCount > 0

  while more do
    more = false

    for index = 1, orderCount do
      local entry = small[order[index]][round]

      if entry then
        rank = rank + 1
        entry.rank = rank
        more = true
      end
    end

    round = round + 1
  end

  for dest = 1, dTop do
    local list = small[dest]

    if list then
      for place = 1, #list do
        local entry = list[place]
        local row = itemOf(dest, entry.cell, entry.slot, current)

        row.parts, row.left, row.place, row.rank, row.eta = 1, 1, place, entry.rank, entry.rank * pace
        count = count + 1
        rows[count] = row
      end
    end
  end

  local ahead = smallTotal + (cur ~= 0 and curLeft * 2 or 0)
  local turn2 = bigTurn

  for _ = 1, dTop do
    turn2 = turn2 % dTop + 1

    if dBig[turn2] > 0 then
      local cell = dBigAt[turn2]

      if cell == 0 then
        cell = dLast[turn2]
      end

      local place = 0

      for _ = 1, dCells[turn2] do
        cell = cNext[cell]

        local slot = cBigHead[cell]
        local guard = 0

        if cell == cur and curLeft > 0 and slot ~= 0 then
          local row = itemOf(turn2, cell, slot, current)

          place = place + 1
          row.parts, row.left, row.place, row.eta, row.current = curTotal, curLeft, place, 0, true
          count = count + 1
          rows[count] = row

          for _ = 1, curLeft do
            if slot ~= 0 then
              slot = mNext[slot]
            end
          end
        end

        while slot ~= 0 and guard < 2000 do
          local parts = mCount[slot] or 1
          local row = itemOf(turn2, cell, slot, current)

          guard = guard + 1
          place = place + 1
          row.parts, row.left, row.place, row.eta = parts, parts, place, ahead * SEND_INTERVAL
          count = count + 1
          rows[count] = row
          ahead = ahead + parts * 2

          for _ = 1, parts do
            if slot ~= 0 then
              slot = mNext[slot]
            end
          end
        end
      end
    end
  end

  sort(rows, function(x, y)
    if x.eta ~= y.eta then
      return x.eta < y.eta
    end

    return x.age > y.age
  end)

  for index = 1, count do
    rows[index].pos = index
  end

  return rows
end

local function window(seconds)
  secondOf(now())

  local ins, outs, waits, peak = 0, 0, 0, 0
  local last = lastSec - 1

  for at = last - seconds + 1, last do
    local i = at % HISTORY + 1

    if hSec[i] == at then
      ins, outs, waits = ins + hIn[i], outs + hOut[i], waits + hWaitSum[i]

      if hWaitMax[i] > peak then
        peak = hWaitMax[i]
      end
    end
  end

  return ins / seconds, outs / seconds, outs > 0 and waits / outs or 0, peak
end

-- The whole picture in one pass: the totals, what waits, and the counters by addon and by recipient.
function Queue.view()
  local current = now()
  local rows = Queue.content()
  local waitingServer = sLast >= sFirst and sLast - sFirst + 1 or 0
  local snap = {
    at = current, capacity = PEER_CAP, laneCap = LANE_CAP, interval = SEND_INTERVAL,
    total = total(), peers = pLive, server = waitingServer, parts = bigLive,
    whispers = 0, channel = 0, oldest = 0, since = statsSince,
    dropped = { offline = dropped.offline, full = dropped.full, failed = dropped.failed },
    sent = { server = sent.server, channel = sent.channel, whisper = sent.whisper },
    rate = {},
  }

  for dest = 1, dTop do
    if dKind[dest] == "whisper" then
      snap.whispers = snap.whispers + dLive[dest]
    elseif dKind[dest] == "channel" then
      snap.channel = snap.channel + dLive[dest]
    end
  end

  for index = 1, #rows do
    if rows[index].age > snap.oldest then
      snap.oldest = rows[index].age
    end
  end

  snap.drain = snap.total * SEND_INTERVAL

  local r = snap.rate

  r.in10, r.out10, r.wait10, r.peak10 = window(10)
  r.in60, r.out60, r.wait60, r.peak60 = window(60)

  local lanes = {}

  for name, item in pairs(laneStat) do
    local index = laneOf[name]
    local done = item.sent + item.failed

    lanes[#lanes + 1] = {
      lane = name, waiting = index and laneLive[index] or 0, queued = item.queued, sent = item.sent,
      failed = item.failed, avg = done > 0 and item.wait / done or 0, max = item.max,
      last = item.last > 0 and current - item.last or nil, buckets = item.buckets,
    }
  end

  sort(lanes, function(x, y)
    if x.waiting ~= y.waiting then
      return x.waiting > y.waiting
    end

    return x.sent > y.sent
  end)

  local dests = {}

  for key, item in pairs(destStat) do
    local dest = item.kind == "whisper" and playerDest[key] or kindDest[key]
    local held, heldFor

    if dest then
      held, heldFor = holdOf(dest)
    end

    local done = item.sent + item.failed

    dests[#dests + 1] = {
      who = item.name, kind = item.kind, lane = item.lane,
      waiting = key == "server" and waitingServer or (dest and dLive[dest] or 0),
      queued = item.queued, sent = item.sent, failed = item.failed, avg = done > 0 and item.wait / done or 0,
      max = item.max, last = item.last > 0 and current - item.last or nil, held = held, heldFor = heldFor,
    }
  end

  sort(dests, function(x, y)
    if x.waiting ~= y.waiting then
      return x.waiting > y.waiting
    end

    return x.sent > y.sent
  end)

  return snap, rows, lanes, dests
end

-- A short read of the queue for a status display: a list of { id, value, level, ... } and the worst
-- level. The values are raw numbers; the level is "ok", "warn" or "bad", decided here with LIMITS.
-- "tab" names the tab of the queue window that shows the detail.
local LIMITS = {
  fill = { 0.4, 0.8 }, oldest = { 10, 30 }, flow = { 1, 3 }, wait = { 5, 20 }, drops = 60,
}
local RANK = { ok = 1, warn = 2, bad = 3 }

local function grade(value, limit)
  if value >= limit[2] then
    return "bad"
  end

  return value >= limit[1] and "warn" or "ok"
end

local function oldestAge(current)
  local oldest = 0

  for dest = 1, dTop do
    local cell = dLast[dest]

    for _ = 1, dCells[dest] do
      cell = cNext[cell]

      local small, big = cSmallHead[cell], cBigHead[cell]
      local at = small ~= 0 and mAt[small]

      if at and current - at > oldest then
        oldest = current - at
      end

      at = big ~= 0 and mAt[big]

      if at and current - at > oldest then
        oldest = current - at
      end
    end
  end

  if sLast >= sFirst and sAt[sFirst] and current - sAt[sFirst] > oldest then
    oldest = current - sAt[sFirst]
  end

  return oldest
end

local function recentDrops(seconds)
  secondOf(now())

  local sum = 0

  for at = lastSec - seconds + 1, lastSec do
    local i = at % HISTORY + 1

    if hSec[i] == at then
      sum = sum + hDrop[i]
    end
  end

  return sum
end

function Queue.summary()
  local current = now()
  local length = total()
  local items, worst = {}, "ok"
  local function add(item)
    items[#items + 1] = item

    if RANK[item.level] > RANK[worst] then
      worst = item.level
    end
  end

  local inRate, outRate, wait, peak = window(10)
  local oldest = oldestAge(current)
  local net = inRate - outRate
  local count = dropped.offline + dropped.full + dropped.failed
  local recent = recentDrops(LIMITS.drops)
  local probes, offline, paused = 0, 0, 0

  for dest = 1, dTop do
    local held = holdOf(dest)

    if held == "probe" then
      probes = probes + 1
    elseif held == "offline" then
      offline = offline + 1
    elseif held == "pause" then
      paused = paused + 1
    end
  end

  local discarded = 0

  for _, module in ipairs({ EbonAPI.Channel, EbonAPI.Whisper }) do
    if module and module.droppedTotal then
      discarded = discarded + module.droppedTotal()
    end
  end

  add({ id = "length", value = length, max = PEER_CAP, level = grade(length / PEER_CAP, LIMITS.fill), tab = "content" })
  add({ id = "oldest", value = oldest, level = grade(oldest, LIMITS.oldest), tab = "content" })
  add({ id = "flow", value = net, inRate = inRate, outRate = outRate, level = grade(net, LIMITS.flow), tab = "history" })
  add({ id = "wait", value = wait, peak = peak, level = grade(wait, LIMITS.wait), tab = "lanes" })
  add({
    id = "dropped", value = count, offline = dropped.offline, full = dropped.full, failed = dropped.failed,
    recent = recent, level = recent > 0 and "bad" or (count > 0 and "warn" or "ok"), tab = "lanes",
  })
  add({
    id = "held", value = probes + offline + paused, probes = probes, offline = offline, paused = paused,
    level = "ok", tab = "people",
  })
  add({ id = "discarded", value = discarded, level = discarded > 0 and "warn" or "ok" })

  return items, worst
end

-- The last messages that left, newest first.
function Queue.recent(limit)
  local current = now()
  local rows = {}
  local n = rCount < (limit or RECENT) and rCount or (limit or RECENT)
  local index = rNext

  for position = 1, n do
    index = (index - 2) % RECENT + 1
    rows[position] = {
      ago = current - rAt[index], who = rWho[index], kind = rKind[index], lane = rLane[index],
      op = rOp[index], detail = rDetail[index], wait = rWait[index], ok = rOk[index],
    }
  end

  return rows
end

-- One value per second, oldest first: the length at the end of the second, what came in, what
-- went out, the mean wait of what went out, and the longest wait.
function Queue.history(seconds)
  seconds = seconds and seconds < HISTORY and seconds or HISTORY
  secondOf(now())

  local out = { len = {}, ins = {}, outs = {}, wait = {}, peak = {}, seconds = seconds, last = lastSec }

  for step = 1, seconds do
    local at = lastSec - seconds + step
    local i = at % HISTORY + 1

    if hSec[i] == at then
      out.len[step], out.ins[step], out.outs[step] = hLen[i], hIn[i], hOut[i]
      out.wait[step] = hOut[i] > 0 and hWaitSum[i] / hOut[i] or 0
      out.peak[step] = hWaitMax[i]
    else
      out.len[step], out.ins[step], out.outs[step], out.wait[step], out.peak[step] = 0, 0, 0, 0, 0
    end
  end

  return out
end

-- Four numbers for the pacing, without building a list: the length now, the longest wait of the small
-- messages that left in the last 60 seconds, the rate in use, and the longest wait of the parts of streams.
function Queue.gauge()
  secondOf(now())

  local small, parts = 0, 0

  for at = lastSec - 59, lastSec do
    local i = at % HISTORY + 1

    if hSec[i] == at then
      if Queue.hSmall[i] > small then
        small = Queue.hSmall[i]
      end

      if Queue.hParts[i] > parts then
        parts = Queue.hParts[i]
      end
    end
  end

  return total(), small, 1 / SEND_INTERVAL, parts
end

function Queue.resetStats()
  for key in pairs(laneStat) do
    laneStat[key] = nil
  end

  for key in pairs(destStat) do
    destStat[key] = nil
  end

  destCount = 0
  rNext, rCount = 1, 0

  for index = 1, HISTORY do
    hSec[index] = nil
  end

  lastSec = nil
  statsSince = nil
end

function Queue.clear()
  for index = sFirst, sLast do
    sPayload[index], sAt[index] = nil, nil
  end

  local dones, count = {}, 0

  for slot = 1, mTop do
    if mDone[slot] then
      count = count + 1
      dones[count] = mDone[slot]
    end

    mA[slot], mB[slot], mC[slot], mDone[slot], mNext[slot] = nil, nil, nil, nil, nil
    mSeq[slot], mCount[slot], mKey[slot], mBody[slot], mAt[slot] = nil, nil, nil, nil, nil
  end

  sFirst, sLast = 1, 0
  mTop, mFree = 0, 0
  pLive = 0

  forget()

  Queue.awake = false
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
      if not sending then
        Queue.hold("channel", CHAT_PAUSE)
      end

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
