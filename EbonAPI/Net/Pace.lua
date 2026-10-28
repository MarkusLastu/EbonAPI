EbonAPI = EbonAPI or {}
EbonAPI.Pace = {}

local Pace = EbonAPI.Pace
local Bus = EbonAPI.Bus
local Queue = EbonAPI.Queue

local type = type
local huge = math.huge

local TICK_ID = "EbonAPI:pace"
local TICK = 1
local PAUSE = 5
local FALL_AFTER = 3
local WINDOW = 15
local LEVEL_GAIN, TREND_GAIN = 0.5, 0.25
local HORIZON = 10
local BUSY, EMPTY, SLACK = 2, 0.5, 0.5
local WINDOW_FALL, FALL_MIN = 0.10, 0.1
local REST_RATE, QUIET_OUT = 4, 1.5
local FORECAST_STEPS = { 150, 300 }
local BACKOFF_HOLD = 30
local FAIL_MIN, FAIL_SHARE = 3, 0.2
local WAIT_FACTOR = 2
local LIMIT_MIN, LIMIT_MAX = 30, 300
local RECENT = 20
local SUMMARY_WINDOW, CEILING_WARN = 60, 60
local RANK = { ok = 1, info = 2, warn = 3 }
local EPSILON = 0.01

Pace.TICK_ID = TICK_ID
Pace.TICK = TICK
Pace.PAUSE = PAUSE
Pace.FALL_AFTER = FALL_AFTER
Pace.WINDOW = WINDOW
Pace.LEVEL_GAIN = LEVEL_GAIN
Pace.TREND_GAIN = TREND_GAIN
Pace.HORIZON = HORIZON
Pace.REST_RATE = REST_RATE
Pace.QUIET_OUT = QUIET_OUT
Pace.FORECAST_STEPS = FORECAST_STEPS
Pace.BACKOFF_HOLD = BACKOFF_HOLD
Pace.FAIL_MIN = FAIL_MIN
Pace.FAIL_SHARE = FAIL_SHARE
Pace.WAIT_FACTOR = WAIT_FACTOR
Pace.LIMIT_MIN = LIMIT_MIN
Pace.LIMIT_MAX = LIMIT_MAX
Pace.SUMMARY_WINDOW = SUMMARY_WINDOW
Pace.CEILING_WARN = CEILING_WARN

local level, trend, ticks = 0, 0, 0
local since = 0
local lastLength, lastWorst = 0, 0
local atCeiling = 0
local limit = LIMIT_MIN
local running = false
local refused = false
local failedSeen, sentSeen, holdUntil = 0, 0, 0
local outs, fails, lens = {}, {}, {}

local rAt, rFrom, rTo, rWhy, rLevel, rTrend = {}, {}, {}, {}, {}, {}
local rNext, rCount = 1, 0

local function now()
  return (GetTime and GetTime()) or 0
end

local function number(value, fallback)
  if type(value) == "number" and value == value and value > -huge and value < huge then
    return value
  end

  return fallback
end

local function baseRate()
  return 1 / Queue.DEFAULT_INTERVAL
end

-- The rate now, as the queue reports it; the base rate when it does not (or says something invalid).
local function currentRate()
  if type(Queue.rate) ~= "function" then
    return baseRate()
  end

  local value = number(Queue.rate(), nil)

  return value and value > 0 and value or baseRate()
end

-- Without a ceiling from the queue the rate stays at its base: it never rises on a guess. The ceiling
-- is the one of the queue (AUTO_MAX_RATE), and never below the base rate.
local function topRate()
  local top = number(Queue.AUTO_MAX_RATE, 0)
  local base = baseRate()

  return top > base and top or base
end

-- The counters of the queue are read like everything else: a table that is missing, or a field of it,
-- counts as zero and never raises an error in the tick.
local function sentTotal()
  local sent = Queue.sent

  if type(sent) ~= "table" then
    return 0
  end

  return number(sent.server, 0) + number(sent.channel, 0) + number(sent.whisper, 0)
end

local function failedTotal()
  local dropped = Queue.dropped

  return type(dropped) == "table" and number(dropped.failed, 0) or 0
end

local function forecast()
  local value = level + HORIZON * trend

  return value > 0 and value or 0
end

-- Holt's smoothing of the queue length: a level and a trend per second.
local function observe(length)
  local before = level

  level = LEVEL_GAIN * length + (1 - LEVEL_GAIN) * (level + trend)
  trend = TREND_GAIN * (level - before) + (1 - TREND_GAIN) * trend
end

local function record(from, to, why)
  local index = rNext

  rAt[index], rFrom[index], rTo[index], rWhy[index] = now(), from, to, why
  rLevel[index], rTrend[index] = level, trend
  rNext = index % RECENT + 1

  if rCount < RECENT then
    rCount = rCount + 1
  end
end

-- Every change of rate restarts the window: a decision is judged on seconds measured at the rate it
-- concerns, never on a mix.
local function apply(rate, target, why)
  refused = Queue.setRate(target, "auto") == false
  since = 0

  if not refused then
    record(rate, target, why)
  end
end

-- One step more for each threshold the forecast has passed.
local function stepFor(expected)
  local step = 1

  for index = 1, #FORECAST_STEPS do
    if expected > FORECAST_STEPS[index] then
      step = step + 1
    end
  end

  return step
end

-- The rings hold the WINDOW last seconds, one slot per tick. ago(0) is the newest slot.
local function slotAgo(back)
  return (ticks - back) % WINDOW + 1
end

-- Sum of the n newest values of a ring.
local function sumLast(ring, n)
  local total = 0

  for back = 0, n - 1 do
    total = total + (ring[slotAgo(back)] or 0)
  end

  return total
end

local function maxLast(ring, n)
  local top = 0

  for back = 0, n - 1 do
    local value = ring[slotAgo(back)] or 0

    top = value > top and value or top
  end

  return top
end

local function minLast(ring, n)
  local low = huge

  for back = 0, n - 1 do
    local value = ring[slotAgo(back)] or 0

    low = value < low and value or low
  end

  return low
end

-- The rules, evaluated at every tick (the back-off comes first, and a hold silences the rest):
--  * rise: only on a full WINDOW (15 s) measured entirely at the current rate, with the queue never
--    empty, busy on average (above BUSY) and not falling by about 10% (WINDOW_FALL) from the first
--    second to the last. A burst empties by itself and never gets here. Step: 1, 2 or 3 by Holt's
--    forecast at HORIZON (FORECAST_STEPS), never above the ceiling.
--  * fall above the normal rate: once the queue stayed empty for FALL_AFTER seconds and the sends were
--    below the rate, straight back to the base in one decision.
--  * fall below the normal rate: on a full WINDOW with the queue empty and fewer than QUIET_OUT sends
--    per second, one step of 1 down to REST_RATE.
local function decide(rate)
  local base, top = baseRate(), topRate()
  local target, why

  if since >= WINDOW and rate < top - EPSILON and minLast(lens, WINDOW) >= 1
    and sumLast(lens, WINDOW) / WINDOW > BUSY
    and (lens[slotAgo(0)] or 0) > (lens[slotAgo(WINDOW - 1)] or 0) * (1 - WINDOW_FALL) - FALL_MIN then
    target = rate + stepFor(forecast())
    target = target < top and target or top
    why = "rise"
  elseif rate > base + EPSILON then
    if since >= FALL_AFTER and maxLast(lens, FALL_AFTER) < EMPTY
      and sumLast(outs, FALL_AFTER) / FALL_AFTER < rate - SLACK then
      target = base
      why = "fall"
    end
  elseif rate > REST_RATE + EPSILON and since >= WINDOW and maxLast(lens, WINDOW) < EMPTY
    and sumLast(outs, WINDOW) / WINDOW < QUIET_OUT then
    target = rate - 1
    target = target > REST_RATE and target or REST_RATE
    why = "fall"
  end

  if target then
    apply(rate, target, why)
  end
end

-- Sends fail for local reasons too (a channel not joined yet, a whisper the client refuses): only a
-- real share of the sends of the last seconds counts, not a few failures in a quiet moment.
local function failing()
  local failed = sumLast(fails, PAUSE)

  return failed >= FAIL_MIN and failed >= FAIL_SHARE * (failed + sumLast(outs, PAUSE))
end

-- The server does not say when it is flooded: sends that fail are the only sign, so the rate is
-- halved (not below REST_RATE) and held for a while. The failures are counted again from nothing afterwards.
local function backOff(rate)
  local target = rate / 2

  holdUntil = now() + BACKOFF_HOLD
  target = target > REST_RATE and target or REST_RATE

  for index = 1, WINDOW do
    fails[index] = 0
  end

  if target < rate - EPSILON then
    apply(rate, target, "failed")
  end
end

-- What a request may wait in silence: twice the worst wait of the last minute plus the time to empty
-- the queue at the current pace (never faster than the normal interval: at rest it empties slower).
-- The holders keep their own pace.
local function refreshLimit(worst)
  local ahead = trend > 0 and level + HORIZON * trend or level
  local interval = 1 / currentRate()
  local seconds

  interval = interval > Queue.DEFAULT_INTERVAL and interval or Queue.DEFAULT_INTERVAL
  ahead = ahead > 0 and ahead or 0
  seconds = WAIT_FACTOR * (worst + ahead * interval)

  if seconds < LIMIT_MIN then
    seconds = LIMIT_MIN
  elseif seconds > LIMIT_MAX then
    seconds = LIMIT_MAX
  end

  limit = seconds
end

local function stop()
  running = false
  level, trend, ticks, since = 0, 0, 0, 0
  lastLength, lastWorst, atCeiling = 0, 0, 0
  limit = LIMIT_MIN

  Bus.untick(TICK_ID)
end

local function tick()
  local length, worst, rate = 0, 0, nil
  local total, failed = sentTotal(), failedTotal()
  local sentNow, failedNow = total - sentSeen, failed - failedSeen
  local slot

  if type(Queue.gauge) == "function" then
    length, worst, rate = Queue.gauge()
  end

  length, worst = number(length, 0), number(worst, 0)
  rate = number(rate, baseRate())
  lastLength, lastWorst = length, worst
  ticks = ticks + 1
  since = since + 1
  slot = ticks % WINDOW + 1
  sentSeen, failedSeen = total, failed
  outs[slot] = sentNow > 0 and sentNow or 0
  fails[slot] = failedNow > 0 and failedNow or 0
  lens[slot] = length

  observe(length)

  local ctl = _G.ChatThrottleLib

  if failing() then
    backOff(rate)
  elseif ctl and ctl.bQueueing then
    since = 0
  elseif now() >= holdUntil then
    decide(rate)
  end

  refreshLimit(worst)
  atCeiling = limit >= LIMIT_MAX and atCeiling + 1 or 0

  if length == 0 and limit <= LIMIT_MIN and (refused or rate <= REST_RATE + EPSILON) then
    stop()
  end
end

-- Called by the queue when it goes from empty to filled, in the path of a send: it only reads the
-- queue and arms the tick, it never sets the rate. Idle again once the queue is empty, the limit has
-- fallen back to its floor (up to a minute after a wait over 15 seconds) and the rate has come down to
-- REST_RATE (about 15 seconds a step, 45 at most from the normal rate) or the queue refuses the changes.
-- The window starts again at every wake. It is marked running only once everything is read, so that no
-- failure can leave it running without a tick.
function Pace.wake()
  if running then
    return
  end

  local start = number(Queue.length(), 0)
  local failedStart, sentStart = failedTotal(), sentTotal()

  level, trend, ticks, since = start, 0, 0, 0
  failedSeen, sentSeen = failedStart, sentStart
  refused = false

  for index = 1, WINDOW do
    outs[index], fails[index], lens[index] = 0, 0, 0
  end

  running = true

  Bus.tick(TICK_ID, TICK, tick)
end

-- Seconds a request may wait in silence. A plain read: the tick of every second keeps it up to date.
function Pace.limit()
  return limit
end

function Pace.state()
  return {
    running = running, length = lastLength, worst = lastWorst, level = level, trend = trend,
    forecast = forecast(), rate = currentRate(), base = baseRate(), top = topRate(), rest = REST_RATE,
    limit = limit, held = holdUntil > now(), refused = refused,
  }
end

-- A short read for a status display, in the shape of Queue.summary(): a list of { id, value, level, ... }
-- and the worst level. Only raw numbers; a value that does not exist yet is left out, never zero.
function Pace.summary()
  local current = now()
  local rate = type(Queue.rate) == "function" and number(Queue.rate(), nil) or nil
  local decisions = 0
  local items = {}
  local worst = "ok"

  for index = 1, rCount do
    if current - rAt[index] <= SUMMARY_WINDOW then
      decisions = decisions + 1
    end
  end

  items[1] = {
    id = "limit", value = limit, floor = LIMIT_MIN, ceiling = LIMIT_MAX,
    level = atCeiling >= CEILING_WARN and "warn" or (limit > LIMIT_MIN and "info" or "ok"),
  }
  items[2] = {
    id = "pace", value = rate, floor = REST_RATE, ceiling = topRate(), decisions = decisions,
    level = rate and rate > baseRate() + EPSILON and "info" or "ok",
  }

  for index = 1, #items do
    if RANK[items[index].level] > RANK[worst] then
      worst = items[index].level
    end
  end

  return items, worst
end

-- The last decisions on the rate, newest first.
function Pace.recent(count)
  local rows = {}
  local n = rCount < (count or RECENT) and rCount or (count or RECENT)
  local index = rNext

  for position = 1, n do
    index = index == 1 and RECENT or index - 1
    rows[position] = {
      at = rAt[index], from = rFrom[index], to = rTo[index], why = rWhy[index],
      level = rLevel[index], trend = rTrend[index],
    }
  end

  return rows
end

Queue.onWake = Pace.wake
