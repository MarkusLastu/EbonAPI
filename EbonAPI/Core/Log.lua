EbonAPI = EbonAPI or {}
EbonAPI.Log = {}

local Log = EbonAPI.Log
local Lib = EbonAPI.Lib
local Handle = EbonAPI.Handle

local type, tostring, select = type, tostring, select
local format, concat = string.format, table.concat

Log.COLOR = {
  RESET = "|r",
}

Log.LEVELS = {
  error = "bad", problem_internal = "bad",
  problem = "warn", fail = "warn", offline = "warn", cut = "warn", warn = "warn", problem_text_missing = "warn",
  success = "ok",
  send = "net", recv = "net", chan = "net", wisp = "net", share = "net",
  boot = "info", module = "info", skin = "info", migration = "info", debug = "info", print = "info",
}

local function join(...)
  local count = select("#", ...)

  if count == 1 then
    return tostring((...))
  end

  local parts = {}

  for index = 1, count do
    parts[index] = tostring((select(index, ...)))
  end

  return concat(parts, " ")
end

local CAPACITY = 128

Log.CAPACITY = CAPACITY

local tAt, tKind, tOwner, tA, tB = {}, {}, {}, {}, {}
local cursor = 0
local filled = 0

local debugOwners = {}
local debugAll = false
local counts = {}

function Log.trace(kind, owner, a, b, at)
  cursor = cursor % CAPACITY + 1

  tAt[cursor] = at or (GetTime and GetTime() or 0)
  tKind[cursor] = kind
  tOwner[cursor] = owner
  tA[cursor] = a
  tB[cursor] = b
  counts[kind] = (counts[kind] or 0) + 1

  if filled < CAPACITY then
    filled = filled + 1
  end
end

function Log.count(kind)
  return counts[kind] or 0
end

function Log.kinds()
  return Lib.sortedKeys(counts)
end

function Log.isDebug(owner)
  return debugAll or debugOwners[owner] == true
end

function Log.setDebug(owner, enabled)
  if owner == nil or owner == "*" then
    debugAll = enabled and true or false
    return debugAll
  end

  debugOwners[owner] = enabled and true or nil

  return Log.isDebug(owner)
end

local function describe(a, b)
  if type(a) == "number" then
    local opcodes = EbonAPI.Opcodes
    local text = opcodes and opcodes.describe(a) or ("opcode " .. a)

    if b then
      return text .. "  " .. b .. "B"
    end

    return text
  end

  if b then
    return tostring(a) .. " " .. tostring(b)
  end

  return tostring(a)
end

function Log.dump(limit, kind)
  local lines = {}
  local now = GetTime and GetTime() or 0

  limit = limit or 20

  local index = cursor

  for _ = 1, filled do
    if not kind or tKind[index] == kind then
      lines[#lines + 1] = format("%6.1fs  %-5s  %-14s  %s",
        now - tAt[index], tKind[index], tOwner[index] or "-", describe(tA[index], tB[index]))

      if #lines >= limit then
        break
      end
    end

    index = index - 1

    if index == 0 then
      index = filled
    end
  end

  if #lines == 0 then
    return "empty trace"
  end

  return concat(lines, "\n")
end

function Log.levelOf(kind)
  return Log.LEVELS[kind] or "info"
end

function Log.rows(limit, kind)
  local rows = {}
  local now = GetTime and GetTime() or 0

  limit = limit or 20

  local index = cursor

  for _ = 1, filled do
    if not kind or tKind[index] == kind then
      rows[#rows + 1] = {
        age = now - tAt[index],
        at = tAt[index],
        kind = tKind[index],
        owner = tOwner[index],
        text = describe(tA[index], tB[index]),
        level = Log.levelOf(tKind[index]),
      }

      if #rows >= limit then
        break
      end
    end

    index = index - 1

    if index == 0 then
      index = filled
    end
  end

  return rows
end

function Log.print(owner, ...)
  Log.trace("print", owner, join(...))
end

local function uncoded(kind, owner, ...)
  local text = join(...)
  local Problems = EbonAPI.Problems

  Log.trace(kind, owner, text)
  Problems.report(Problems.make(owner or "EbonAPI", "EBONAPI.UNCODED", { text = text }))
end

function Log.warn(owner, ...)
  uncoded("warn", owner, ...)
end

function Log.success(owner, ...)
  Log.trace("success", owner, join(...))
end

function Log.error(owner, ...)
  uncoded("error", owner, ...)
end

function Log.debug(owner, ...)
  if Log.isDebug(owner) then
    Log.trace("debug", owner, join(...))
  end
end

local TRACE_CAPACITY = 32
local rings = {}

local function raw(value)
  local kind = type(value)

  if kind == "string" or kind == "number" or kind == "boolean" then
    return value
  end

  if value == nil then
    return nil
  end

  return kind
end

function Log.note(owner, kind, a, b)
  local ring = rings[owner]

  if not ring then
    ring = { at = {}, kind = {}, a = {}, b = {}, cursor = 0, filled = 0 }
    rings[owner] = ring
  end

  local cursor = ring.cursor % TRACE_CAPACITY + 1

  ring.cursor = cursor
  ring.at[cursor] = GetTime and GetTime() or 0
  ring.kind[cursor] = kind
  ring.a[cursor] = raw(a)
  ring.b[cursor] = raw(b)

  if ring.filled < TRACE_CAPACITY then
    ring.filled = ring.filled + 1
  end
end

function Log.recent(owner, limit)
  local lines = {}
  local ring = rings[owner]

  if not ring then
    return lines
  end

  local now = GetTime and GetTime() or 0
  local index = ring.cursor

  limit = limit or 10

  for _ = 1, ring.filled do
    if #lines >= limit then
      break
    end

    local text = ring.a[index] ~= nil and tostring(ring.a[index]) or ""

    if ring.b[index] ~= nil then
      text = text .. " " .. tostring(ring.b[index])
    end

    lines[#lines + 1] = format("%6.1fs  %-5s  %-14s  %s", now - ring.at[index], ring.kind[index], owner, text)

    index = index - 1

    if index == 0 then
      index = ring.filled
    end
  end

  return lines
end

function Handle:Trace(kind, a, b)
  if type(kind) ~= "string" or kind == "" then
    error("api:Trace: kind must be a non-empty string", 2)
  end

  Log.note(self.addonName, kind, a, b)
end

for name, key in pairs({ Print = "print", Warn = "warn", Error = "error", Success = "success", Debug = "debug" }) do
  Handle[name] = function(self, ...)
    Log[key](self.addonName, ...)
  end
end

function Handle:SetDebug(enabled)
  return Log.setDebug(self.addonName, enabled)
end

function Handle:IsDebug()
  return Log.isDebug(self.addonName)
end
