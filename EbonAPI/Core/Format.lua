EbonAPI = EbonAPI or {}
EbonAPI.Format = {}

local Format = EbonAPI.Format
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local L = EbonAPI.L

local tostring = tostring
local floor, ceil, abs, max = math.floor, math.ceil, math.abs, math.max
local format, len, sub = string.format, string.len, string.sub
local concat, insert = table.concat, table.insert

local COMPACT = {
  { below = 999950, divisor = 1000, format = "COMPACT_K" },
  { below = 999995000, divisor = 1000000, format = "COMPACT_M" },
  { divisor = 1000000000, format = "COMPACT_G" },
}

function Format.number(value)
  value = Lib.num(value)

  local size = abs(value)
  local rounded = size % 1 == 0 and size or floor(size + 0.5)
  local negative = value < 0 and rounded > 0
  local text = format("%.0f", rounded)
  local grouped = ""

  while len(text) > 3 do
    grouped = L.THOUSANDS_SEPARATOR .. sub(text, -3) .. grouped
    text = sub(text, 1, len(text) - 3)
  end

  grouped = text .. grouped

  if negative then
    return "-" .. grouped
  end

  return grouped
end

function Format.compact(value)
  value = Lib.num(value)

  local size = abs(value)

  if size < 10000 then
    return Format.number(value)
  end

  local tier

  for index = 1, #COMPACT do
    tier = COMPACT[index]

    if not tier.below or size < tier.below then
      break
    end
  end

  local text = format(L[tier.format], size / tier.divisor)

  if value < 0 then
    return "-" .. text
  end

  return text
end

function Format.percent(value)
  return format("%.1f%%", Lib.num(value))
end

function Format.pair(current, maximum)
  return Format.compact(current) .. " / " .. Format.compact(maximum)
end

function Format.rate(value)
  return Format.compact(value) .. (L.PER_HOUR or "/h")
end

function Format.bytes(value)
  value = Lib.num(value)

  if value >= 1048576 then
    return format(L.BYTES_MB, value / 1048576)
  end

  return format(L.BYTES_KB, value / 1024)
end

function Format.boolean(value)
  if value then
    return L.YES or "yes"
  end

  return L.NO or "no"
end

local function splitCopper(value)
  local total = Lib.copper(abs(Lib.num(value)))
  local gold = floor(total / 10000)
  local silver = floor((total - gold * 10000) / 100)

  return gold, silver, total - gold * 10000 - silver * 100, Lib.num(value) < 0 and total > 0
end

local function unit(count, key, color)
  if color then
    return count .. color .. L[key] .. Log.COLOR.RESET
  end

  return count .. L[key]
end

local function amount(value, colors)
  local gold, silver, copper, negative = splitCopper(value)
  local parts = {}

  if gold > 0 then
    insert(parts, unit(Format.number(gold), "UNIT_GOLD_SHORT", colors and colors.GOLD))
  end

  if gold > 0 or silver > 0 then
    insert(parts, unit(silver, "UNIT_SILVER_SHORT", colors and colors.SILVER))
  end

  insert(parts, unit(copper, "UNIT_COPPER_SHORT", colors and colors.COPPER))

  local text = concat(parts, " ")

  if negative then
    return "-" .. text
  end

  return text
end

function Format.money(value)
  return amount(value)
end

function Format.moneyRich(value)
  return amount(value, Log.COLOR)
end

function Format.duration(seconds)
  seconds = max(0, Lib.int(seconds))

  local hours = floor(seconds / 3600)
  local minutes = floor((seconds - hours * 3600) / 60)
  local rest = seconds - hours * 3600 - minutes * 60

  local h = L.UNIT_HOUR_SHORT or "h"
  local m = L.UNIT_MIN_SHORT or "m"
  local s = L.UNIT_SEC_SHORT or "s"

  if hours > 0 then
    return hours .. h .. " " .. minutes .. m
  end

  if minutes > 0 then
    return minutes .. m .. " " .. rest .. s
  end

  return rest .. s
end

function Format.seconds(value)
  return tostring(max(0, Lib.int(value))) .. (L.UNIT_SEC_SHORT or "s")
end

function Format.secondsRemaining(untilTime)
  if not untilTime or not GetTime then
    return Format.duration(0)
  end

  return Format.duration(ceil(untilTime - GetTime()))
end

function Format.list(values, separator)
  if type(values) ~= "table" then
    return ""
  end

  local parts = {}

  for index = 1, #values do
    parts[index] = tostring(values[index])
  end

  return concat(parts, separator or ", ")
end
