EbonAPI = EbonAPI or {}
EbonAPI.Lib = {}

local Lib = EbonAPI.Lib

local type, tonumber, pairs, next = type, tonumber, pairs, next
local tostring, pcall = tostring, pcall
local floor, abs, huge, max, min = math.floor, math.abs, math.huge, math.max, math.min
local concat, remove, sort = table.concat, table.remove, table.sort
local len, sub, gsub, match, find, byte = string.len, string.sub, string.gsub, string.match, string.find, string.byte
local char, upper = string.char, string.upper

Lib.floor = floor
Lib.abs = abs
Lib.max = max
Lib.min = min
Lib.concat = concat

function Lib.report(err, owner)
  local Catch = EbonAPI.Catch

  EbonAPI.Log.trace("error", owner, tostring(err))
  Catch.report(err, owner)

  return Catch.forward(err)
end

local function upperLatin(second)
  local code = byte(second)

  if code == 183 then
    return "\195\183"
  end

  return "\195" .. char(code - 32)
end

function Lib.upper(text)
  text = gsub(upper(text or ""), "\195([\160-\190])", upperLatin)
  text = gsub(text, "\195\191", "\197\184")
  text = gsub(text, "\195\159", "SS")

  return (gsub(text, "\197\147", "\197\146"))
end

local ICONS = "Interface\\Icons\\"

function Lib.icon(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end

  if find(value, "[\\/]") then
    return value
  end

  return ICONS .. value
end

function Lib.safeCall(fn, ...)
  local ok, err = pcall(fn, ...)

  if not ok then
    Lib.report(err)
  end

  return ok
end

function Lib.safeGet(fn, ...)
  local ok, result = pcall(fn, ...)

  if not ok then
    Lib.report(result)
    return nil, result
  end

  return result
end

function Lib.num(value, fallback)
  value = tonumber(value)

  if not value or value ~= value or value == huge or value == -huge then
    return fallback or 0
  end

  return value
end

function Lib.int(value, fallback)
  return floor(Lib.num(value, fallback))
end

function Lib.bool(value)
  return value and true or false
end

function Lib.copper(value)
  return max(0, floor(Lib.num(value)))
end

function Lib.count(t)
  local total = 0

  for _ in pairs(t) do
    total = total + 1
  end

  return total
end

function Lib.isEmpty(t)
  return next(t) == nil
end

function Lib.copyShallow(source, target)
  target = target or {}

  for key, value in pairs(source) do
    target[key] = value
  end

  return target
end

function Lib.copyDeep(source, seen)
  if type(source) ~= "table" then
    return source
  end

  seen = seen or {}

  if seen[source] then
    return seen[source]
  end

  local copy = {}
  seen[source] = copy

  for key, value in pairs(source) do
    copy[key] = Lib.copyDeep(value, seen)
  end

  return copy
end

function Lib.applyDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      if target[key] == nil then
        target[key] = {}
      end

      if type(target[key]) == "table" then
        Lib.applyDefaults(target[key], value)
      end
    elseif target[key] == nil then
      target[key] = value
    end
  end

  return target
end

function Lib.indexOf(list, value)
  for index = 1, #list do
    if list[index] == value then
      return index
    end
  end

  return nil
end

function Lib.removeValue(list, value)
  local index = Lib.indexOf(list, value)

  if not index then
    return false
  end

  remove(list, index)

  return true
end

function Lib.keys(t, into)
  into = into or {}

  for key in pairs(t) do
    into[#into + 1] = key
  end

  return into
end

function Lib.sortedKeys(t)
  local keys = Lib.keys(t)

  sort(keys, function(a, b)
    local numberA, numberB = type(a) == "number", type(b) == "number"

    if numberA and numberB then
      return a < b
    end

    if numberA ~= numberB then
      return numberA
    end

    return tostring(a) < tostring(b)
  end)

  return keys
end

function Lib.trim(value)
  return (match(value, "^%s*(.-)%s*$"))
end

function Lib.split(value, separator, into)
  for index = #into, 1, -1 do
    into[index] = nil
  end

  if type(value) ~= "string" then
    return into, 0
  end

  local start = 1
  local count = 0
  local width = len(separator)

  while true do
    local stop = find(value, separator, start, true)

    count = count + 1

    if not stop then
      into[count] = sub(value, start)
      break
    end

    into[count] = sub(value, start, stop - 1)
    start = stop + width
  end

  return into, count
end

function Lib.stripColor(value)
  value = gsub(value, "|c%x%x%x%x%x%x%x%x", "")
  value = gsub(value, "|r", "")

  return value
end

function Lib.colorize(color, text)
  return color .. tostring(text) .. "|r"
end

function Lib.cutUtf8(body, start, budget)
  local length = len(body)
  local stop = start + budget - 1

  if stop >= length then
    return length
  end

  local following = byte(body, stop + 1)

  while stop > start and following >= 128 and following <= 191 do
    stop = stop - 1
    following = byte(body, stop + 1)
  end

  while stop < length and following >= 128 and following <= 191 do
    stop = stop + 1
    following = byte(body, stop + 1)
  end

  return stop
end

function Lib.splitUtf8(body, budget, into)
  local length = len(body)
  local start = 1
  local count = 0

  repeat
    local stop = Lib.cutUtf8(body, start, budget)

    count = count + 1
    into[count] = sub(body, start, stop)
    start = stop + 1
  until start > length

  for index = #into, count + 1, -1 do
    into[index] = nil
  end

  return into, count
end
