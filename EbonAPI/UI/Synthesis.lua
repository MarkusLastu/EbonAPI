EbonAPI = EbonAPI or {}
EbonAPI.Synthesis = {}

local Synthesis = EbonAPI.Synthesis
local L = EbonAPI.L

local pcall, type, ipairs = pcall, type, ipairs
local format, gsub = string.format, string.gsub

-- Provisional limits, to be adjusted by the owner. The queue tiles take their level from
-- Queue.summary(), whose own limits live in Net/Queue.lua.
local LIMITS = {
  profileRejected = 0, -- more rejected profile bodies than this is a warning
  shareRefused = 0,    -- more refused share lines than this is a warning
  peMissing = 0,       -- more missing ProjectEbonhold parts than this is a warning
}

Synthesis.LIMITS = LIMITS

local NONE = "\226\128\148" -- an em dash: the source is not there

local RANK = { info = 0, ok = 1, warn = 2, bad = 3 }

-- Reads a source without ever raising: nil when the module, the function or the call is missing.
local function call(module, name, ...)
  local owner = EbonAPI[module]

  if type(owner) ~= "table" or type(owner[name]) ~= "function" then
    return nil
  end

  local ok, a, b, c, d, e = pcall(owner[name], ...)

  if not ok then
    return nil
  end

  return a, b, c, d, e
end

local function number(value)
  return type(value) == "number" and value or 0
end

local function decimal(value, places)
  return (gsub(format("%." .. places .. "f", value), "%.", L.NUMBER_DECIMAL))
end

local function signed(value)
  local text = decimal(value < 0 and -value or value, 1)

  if text == decimal(0, 1) then
    return "+" .. text
  end

  return (value < 0 and "-" or "+") .. text
end

local function seconds(value, places)
  return format(L.UI_SYNTH_SECONDS, decimal(number(value), places))
end

local function whole(value)
  local text = EbonAPI.Format and EbonAPI.Format.number and EbonAPI.Format.number(value)

  return text or format("%d", number(value))
end

local function item(id, label, value, sub, level, section)
  return {
    id = id,
    label = label,
    value = value,
    sub = sub or "",
    level = level,
    target = section and { section = section } or nil,
  }
end

local function missing(id, label, section)
  return item(id, label, NONE, "", "info", section)
end

local function bridge()
  local label = L.UI_SYNTH_BRIDGE
  local Bridge = EbonAPI.Bridge

  if type(Bridge) ~= "table" then
    return missing("pont", label, "srv")
  end

  if not Bridge.seen then
    return item("pont", label, L.UI_SYNTH_INACTIVE, L.UI_SYNTH_BRIDGE_NONE, "warn", "srv")
  end

  local since = type(GetTime) == "function" and type(Bridge.lastMessageAt) == "number"
    and GetTime() - Bridge.lastMessageAt or 0

  return item("pont", label, L.UI_SYNTH_ACTIVE,
    format(L.UI_SYNTH_BRIDGE_SUB, number(Bridge.received), seconds(since, 0)), "ok", "srv")
end

local function channel()
  local label = L.UI_SYNTH_CHANNEL
  local Channel = EbonAPI.Channel

  if type(Channel) ~= "table" then
    return missing("canal", label, "srv")
  end

  if call("Channel", "isJoined") then
    local index = call("Channel", "index")
    local since = call("Channel", "joinedFor")

    return item("canal", label, L.UI_SYNTH_JOINED,
      format(L.UI_SYNTH_CHANNEL_SUB, number(index), seconds(since, 0)), "ok", "srv")
  end

  if call("Channel", "isWanted") then
    return item("canal", label, L.UI_SYNTH_PENDING, "", "warn", "srv")
  end

  return item("canal", label, L.UI_SYNTH_OFF, "", "info", "srv")
end

local function profile()
  local label = L.UI_SYNTH_PROFILE
  local Profile = EbonAPI.Profile

  if type(Profile) ~= "table" then
    return missing("profil", label, "ech")
  end

  local rejected = number(Profile.rejected)
  local value = rejected > 0 and format(L.UI_SYNTH_PROFILE_REJECTED, rejected) or L.UI_SYNTH_PROFILE_NONE

  return item("profil", label, value, format(L.UI_SYNTH_PROFILE_RECEIVED, number(Profile.received)),
    rejected > LIMITS.profileRejected and "warn" or "ok", "ech")
end

local function share()
  local label = L.UI_SYNTH_SHARE
  local keys, _, peers, received, refused = call("Share", "summary")

  if keys == nil then
    return missing("partage", label, "ech")
  end

  return item("partage", label, format(L.UI_SYNTH_SHARE_VALUE, number(peers)),
    format(L.UI_SYNTH_SHARE_SUB, number(keys), number(received)),
    number(refused) > LIMITS.shareRefused and "warn" or "ok", "ech")
end

local function ebonhold()
  local label = L.UI_SYNTH_PE
  local present, absent = call("Ebonhold", "Summary")

  if type(present) ~= "table" then
    return missing("pe", label, "pe")
  end

  absent = type(absent) == "table" and absent or {}

  local found = call("Ebonhold", "IsPresent") and true or false
  local level = found and #absent <= LIMITS.peMissing and "ok" or "warn"

  return item("pe", label, found and L.UI_SYNTH_DETECTED or L.UI_SYNTH_ABSENT,
    format(L.UI_SYNTH_PE_SUB, #present), level, "pe")
end

function Synthesis.connection()
  return { bridge(), channel(), profile(), share(), ebonhold() }
end

local function queueItem(entry)
  local id, level, value = entry.id, entry.level, number(entry.value)
  local label, text, sub

  if id == "length" then
    label = L.UI_SYNTH_QUEUE_LENGTH
    text = format(L.UI_SYNTH_LENGTH_VALUE, whole(value), whole(number(entry.max)))
    sub = L.UI_SYNTH_LENGTH_SUB
  elseif id == "oldest" then
    label = L.UI_SYNTH_QUEUE_OLDEST
    text = seconds(value, 0)
    sub = L.UI_SYNTH_OLDEST_SUB
  elseif id == "flow" then
    label = L.UI_SYNTH_QUEUE_FLOW
    text = format(L.UI_SYNTH_RATE, signed(value))
    sub = format(L.UI_SYNTH_FLOW_SUB, decimal(number(entry.inRate), 1), decimal(number(entry.outRate), 1))
  elseif id == "wait" then
    label = L.UI_SYNTH_QUEUE_WAIT
    text = seconds(value, 1)
    sub = format(L.UI_SYNTH_WAIT_SUB, seconds(number(entry.peak), 1))
  elseif id == "dropped" then
    label = L.UI_SYNTH_QUEUE_DROPPED
    text = whole(value)
    sub = format(L.UI_SYNTH_DROPPED_SUB, number(entry.offline), number(entry.full), number(entry.failed))

    if number(entry.recent) > 0 then
      sub = sub .. " · " .. format(L.UI_SYNTH_DROPPED_RECENT, number(entry.recent))
    end
  elseif id == "held" then
    label = L.UI_SYNTH_QUEUE_HELD
    text = whole(value)
    sub = format(L.UI_SYNTH_HELD_SUB, number(entry.probes), number(entry.offline), number(entry.paused))
  elseif id == "discarded" then
    label = L.UI_SYNTH_QUEUE_DISCARDED
    text = whole(value)
    sub = L.UI_SYNTH_DISCARDED_SUB
  else
    return nil
  end

  return {
    id = id,
    label = label,
    value = text,
    sub = sub,
    level = RANK[level] and level or "info",
    target = entry.tab and { queue = entry.tab } or nil,
  }
end

-- The pace tiles: the dynamic wait limit and the send rate, from Pace.summary(). No target: a click does nothing.
local function paceItem(entry)
  local id = entry.id
  local label, text, sub

  if id == "limit" then
    label = L.UI_SYNTH_PACE_LIMIT
    text = type(entry.value) == "number" and seconds(entry.value, 0) or NONE
    sub = format(L.UI_SYNTH_PACE_LIMIT_SUB,
      type(entry.floor) == "number" and seconds(entry.floor, 0) or NONE,
      type(entry.ceiling) == "number" and seconds(entry.ceiling, 0) or NONE)
  elseif id == "pace" then
    label = L.UI_SYNTH_PACE_RATE
    text = type(entry.value) == "number" and format(L.UI_SYNTH_RATE, decimal(entry.value, 1)) or NONE
    sub = format(L.UI_SYNTH_PACE_SUB,
      type(entry.ceiling) == "number" and decimal(entry.ceiling, 1) or NONE,
      whole(entry.decisions))
  else
    return nil
  end

  return {
    id = id,
    label = label,
    value = text,
    sub = sub,
    level = RANK[entry.level] and entry.level or "info",
  }
end

function Synthesis.queue()
  local Queue = EbonAPI.Queue

  if EbonAPI.QueueView == nil or type(Queue) ~= "table" or Queue.summary == nil then
    return {}
  end

  local ok, entries = pcall(Queue.summary)

  if not ok or type(entries) ~= "table" then
    return {}
  end

  local items = {}

  for _, entry in ipairs(entries) do
    local built = type(entry) == "table" and queueItem(entry)

    if built then
      items[#items + 1] = built
    end
  end

  local Pace = EbonAPI.Pace

  if type(Pace) == "table" and type(Pace.summary) == "function" then
    local paced, list = pcall(Pace.summary)

    if paced and type(list) == "table" then
      for _, entry in ipairs(list) do
        local built = type(entry) == "table" and paceItem(entry)

        if built then
          items[#items + 1] = built
        end
      end
    end
  end

  return items
end

function Synthesis.status()
  local groups = {}
  local sets = {
    { id = "connexion", label = L.UI_SYNTH_GROUP_CONNECTION, items = Synthesis.connection() },
    { id = "file", label = L.UI_SYNTH_GROUP_QUEUE, items = Synthesis.queue() },
  }

  for _, group in ipairs(sets) do
    if #group.items > 0 then
      groups[#groups + 1] = group
    end
  end

  return groups
end

local function filterItem(id, label, count, sub, level)
  return {
    id = id,
    label = label,
    value = whole(count),
    sub = sub or "",
    level = level,
    target = { filter = id },
  }
end

function Synthesis.traces()
  local Log = EbonAPI.Log

  if type(Log) ~= "table" or type(Log.rows) ~= "function" or type(Log.CAPACITY) ~= "number" then
    return {}
  end

  local ok, rows = pcall(Log.rows, Log.CAPACITY)

  if not ok or type(rows) ~= "table" then
    return {}
  end

  local sums = { bad = 0, warn = 0, net = 0, oth = 0 }

  for _, row in ipairs(rows) do
    local level = type(row) == "table" and row.level
    local key = (level == "bad" or level == "warn" or level == "net") and level or "oth"

    sums[key] = sums[key] + 1
  end

  return {
    {
      id = "niveaux",
      label = L.UI_SYNTH_GROUP_LEVELS,
      items = {
        filterItem("all", L.UI_SYNTH_LEVEL_ALL, #rows, L.UI_SYNTH_LEVEL_ALL_SUB, "info"),
        filterItem("bad", L.UI_SYNTH_LEVEL_BAD, sums.bad, "", sums.bad > 0 and "bad" or "ok"),
        filterItem("warn", L.UI_SYNTH_LEVEL_WARN, sums.warn, "", sums.warn > 0 and "warn" or "ok"),
        filterItem("net", L.UI_SYNTH_LEVEL_NET, sums.net, "", "info"),
        filterItem("oth", L.UI_SYNTH_LEVEL_OTHER, sums.oth, "", "info"),
      },
    },
  }
end

function Synthesis.opcodes()
  local ss, cs = call("Opcodes", "counts")

  if type(ss) ~= "number" or type(cs) ~= "number" then
    return {}
  end

  return {
    {
      id = "sens",
      label = L.UI_SYNTH_GROUP_OPCODES,
      items = {
        filterItem("all", L.UI_SYNTH_OPCODES_ALL, ss + cs, "", "info"),
        filterItem("ss", L.UI_SYNTH_OPCODES_SS, ss, L.UI_SYNTH_OPCODES_SS_SUB, "info"),
        filterItem("cs", L.UI_SYNTH_OPCODES_CS, cs, L.UI_SYNTH_OPCODES_CS_SUB, "info"),
      },
    },
  }
end

function Synthesis.forReport(name)
  if name == "status" then
    return Synthesis.status()
  end

  if name == "trace" then
    return Synthesis.traces()
  end

  if name == "opcodes" then
    return Synthesis.opcodes()
  end

  return nil
end

function Synthesis.worst(groups)
  local worst = "ok"

  for _, group in ipairs(groups or {}) do
    for _, entry in ipairs(group.items or {}) do
      if (RANK[entry.level] or 0) > RANK[worst] then
        worst = entry.level
      end
    end
  end

  return worst
end
