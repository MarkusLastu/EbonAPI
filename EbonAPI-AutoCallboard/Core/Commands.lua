local Core = AutoCallboardCore or {}
AutoCallboardCore = Core
local L = AutoCallboardLocale

local tonumber = tonumber
local math = math

local trim = Core.trim

local BOOLEAN_TRUE_WORDS = { on = true, ["true"] = true, yes = true }
local BOOLEAN_FALSE_WORDS = { off = true, ["false"] = true, no = true }

local function parseBoolean(rest)
  local lowered = rest:lower()

  if BOOLEAN_TRUE_WORDS[lowered] then
    return true
  end

  if BOOLEAN_FALSE_WORDS[lowered] then
    return false
  end

  return nil
end

local DEBUG_COMMANDS = {
  etrace = "etrace",
  eventtrace = "etrace",
  inspect = "inspect",
  dump = "dump",
  cooldown = "cooldown",
  cd = "cooldown",
  log = "logs",
  logs = "logs",
  clearlogs = "clearlogs",
}

local function reject(kind, name, facts, fallback)
  local problem = Core.problem(name, facts)
  local RT = AutoCallboardRuntime
  local message = fallback

  if problem and RT and RT.api then
    message = RT.api:ProblemText(problem)
  end

  return { kind = kind, problem = problem, message = message }
end

local function invalid(command, rest, usage)
  return reject("invalid", "COMMAND.BAD_ARGUMENT",
      { command = command, value = rest ~= "" and rest or "-", usage = L[usage] }, L[usage])
end

local function parseText(rest, usage, field, command)
  if rest == "" then
    return invalid(command, rest, usage)
  end

  return { kind = "set", field = field, value = rest }
end

local function parseDebugFlag(rest, usage, action, command)
  local value = parseBoolean(rest)

  if value == nil then
    return invalid(command, rest, usage)
  end

  return { kind = "debug", action = action, value = value }
end

local SLASH_PARSERS = {
  name = function(rest) return parseText(rest, "USAGE_NAME", "targetName", "name") end,
  buttonfield = function(rest) return parseText(rest, "USAGE_BUTTONFIELD", "objectiveButtonField", "buttonfield") end,
  id = function(rest)
    local spellID = tonumber(rest)

    if not spellID then
      return invalid("id", rest, "USAGE_ID")
    end

    return { kind = "set", field = "summonSpellID", value = spellID }
  end,
  reroll = function(rest) return parseText(rest, "USAGE_REROLL", "rerollFrame", "reroll") end,
  maxrolls = function(rest)
    local value = tonumber(rest)

    if not value or value < 1 then
      return invalid("maxrolls", rest, "USAGE_MAXROLLS")
    end

    return { kind = "set", field = "maxRerolls", value = math.floor(value) }
  end,
  debug = function(rest)
    if rest == "" then
      return { kind = "debug", action = "open" }
    end

    return parseDebugFlag(rest, "USAGE_DEBUG", "enabled", "debug")
  end,
  watch = function(rest) return parseDebugFlag(rest, "USAGE_WATCH", "mouseWatch", "watch") end,
  sniff = function(rest)
    local lowered = rest:lower()

    if rest == "" or lowered == "dump" then
      return { kind = "debug", action = "sniffDump" }
    end

    if lowered == "clear" then
      return { kind = "debug", action = "sniffClear" }
    end

    return parseDebugFlag(rest, "USAGE_SNIFF", "sniffer", "sniff")
  end,
}

SLASH_PARSERS.spellid = SLASH_PARSERS.id
SLASH_PARSERS.sniffer = SLASH_PARSERS.sniff

function Core.parseSlash(input)
  local message = trim(input)

  if message == "" then
    return { kind = "version" }
  end

  local command, rest = message:match("^(%S+)%s*(.-)$")
  command = command and command:lower() or ""
  rest = trim(rest)

  local debugAction = DEBUG_COMMANDS[command]
  if debugAction then
    return { kind = "debug", action = debugAction }
  end

  local parser = SLASH_PARSERS[command]
  if parser then
    return parser(rest)
  end

  return reject("unknown", "COMMAND.UNKNOWN", { command = command }, L.CORE_UNKNOWN_COMMAND)
end
