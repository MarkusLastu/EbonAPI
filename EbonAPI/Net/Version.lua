EbonAPI = EbonAPI or {}
EbonAPI.Version = {}

local Version = EbonAPI.Version
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local DB = EbonAPI.DB
local Session = EbonAPI.Session
local Handle = EbonAPI.Handle
local L = EbonAPI.L

local type, tonumber, tostring, pairs, error = type, tonumber, tostring, pairs, error
local match, gmatch, format, len, concat, sort = string.match, string.gmatch, string.format, string.len, table.concat, table.sort
local random, max = math.random, math.max

local TEXT_MAX = 20
local REPLY_TICK = 1
local REPLY_MIN, REPLY_MAX = 2, 8
local REPLY_COOLDOWN = 30

Version.REPLY_MIN = REPLY_MIN
Version.REPLY_MAX = REPLY_MAX
Version.REPLY_COOLDOWN = REPLY_COOLDOWN

local entries = {}
local names = {}
local store = nil
local enabled = false
local replyAt, lastReplyAt = nil, nil
local notified = {}

Version.said = 0
Version.heard = 0

local function now()
  return (GetTime and GetTime()) or 0
end

function Version.parse(text)
  if type(text) ~= "string" or len(text) > TEXT_MAX then
    return nil
  end

  local major, minor, patch, build = match(text, "^(%d+)%.(%d+)%.(%d+)(.*)$")

  if not major or (build ~= "" and not match(build, "^%-%d+$")) then
    return nil
  end

  return { tonumber(major), tonumber(minor), tonumber(patch) }, build == ""
end

function Version.compare(a, b)
  for i = 1, 3 do
    if a[i] ~= b[i] then
      return (a[i] < b[i]) and -1 or 1
    end
  end

  return 0
end

function Version.isNewer(candidate, reference)
  local parsed, release = Version.parse(candidate)

  if not parsed or not release then
    return false
  end

  local mine = Version.parse(reference)

  return mine ~= nil and Version.compare(parsed, mine) > 0
end

local function versions()
  if not store then
    return nil
  end

  local held = store.account.versions

  if type(held) ~= "table" then
    held = {}
    store.account.versions = held
  end

  return held
end

function Version.available(name)
  local entry = entries[name]
  local held = versions()

  if not entry or not held then
    return nil
  end

  local latest = held[name]

  if type(latest) == "string" and Version.isNewer(latest, entry.text) then
    return latest, entry.text
  end

  return nil
end

local function notify(entry)
  local latest, own = Version.available(entry.name)

  if not latest or notified[entry.name] == latest then
    return false
  end

  notified[entry.name] = latest

  local text = format(L.UPDATE_AVAILABLE, latest, own)
  local url = EbonAPI:AddonLink(entry.name)

  if url then
    text = text .. " " .. url
  end

  Log.trace("print", entry.name, text)
  EbonAPI:Emit("UPDATE_AVAILABLE", entry.name, latest, own, url)

  return true
end

local function settle(entry)
  local held = versions()

  if not held then
    return
  end

  local latest = held[entry.name]

  if latest ~= nil and not Version.isNewer(latest, entry.text) then
    held[entry.name] = nil
  end

  if Session.isNew() then
    notify(entry)
  else
    notified[entry.name] = Version.available(entry.name)
  end
end

function Version.register(name, text)
  if type(name) ~= "string" or not match(name, "^[%w_]+$") then
    error("EbonAPI.Version.register expects an addon name, got " .. tostring(name), 2)
  end

  local parsed, release = Version.parse(text)

  if not parsed then
    return false
  end

  local entry = entries[name]

  if not entry then
    entry = { name = name }
    entries[name] = entry
    names[#names + 1] = name
    sort(names)
  end

  entry.text = text
  entry.parsed = parsed
  entry.release = release

  if enabled then
    settle(entry)
  end

  return true
end

function Version.line()
  local parts = {}

  for i = 1, #names do
    local entry = entries[names[i]]

    if entry.release then
      parts[#parts + 1] = entry.name .. "=" .. entry.text
    end
  end

  if #parts == 0 then
    return nil
  end

  return concat(parts, ",")
end

local function say()
  if not Version.line() or not EbonAPI.Share.beacon() then
    return false
  end

  Version.said = Version.said + 1

  return true
end

local function tickReply()
  if not replyAt then
    Bus.untick("EbonAPI:reply")
    return
  end

  local current = now()

  if current < replyAt then
    return
  end

  replyAt = nil
  lastReplyAt = current
  Bus.untick("EbonAPI:reply")
  say()
end

local function learn(entry, text)
  local held = versions()

  if not held then
    return
  end

  local known = held[entry.name]

  if type(known) ~= "string" or Version.isNewer(text, known) then
    held[entry.name] = text
  end

  notify(entry)
end

function Version.onBeacon(_, body)
  Version.heard = Version.heard + 1

  local theirs = {}
  local behind = false

  for name, text in gmatch(body, "([%w_]+)=([^,]+)") do
    local entry = entries[name]

    if entry then
      local parsed, release = Version.parse(text)

      if parsed then
        theirs[name] = parsed

        local order = Version.compare(parsed, entry.parsed)

        if order > 0 and release then
          learn(entry, text)
        elseif order < 0 and entry.release then
          behind = true
        end
      end
    end
  end

  local covered = true

  for _, entry in pairs(entries) do
    if entry.release then
      local given = theirs[entry.name]

      if not given or Version.compare(given, entry.parsed) < 0 then
        covered = false
        break
      end
    end
  end

  local current = now()

  if covered then
    replyAt = nil
    lastReplyAt = current
    return
  end

  if behind and not replyAt and Version.line() then
    replyAt = current + REPLY_MIN + random() * (REPLY_MAX - REPLY_MIN)

    if lastReplyAt then
      replyAt = max(replyAt, lastReplyAt + REPLY_COOLDOWN)
    end

    Bus.tick("EbonAPI:reply", REPLY_TICK, tickReply)
  end
end

function Version.summary()
  local parts = {}

  for i = 1, #names do
    local entry = entries[names[i]]
    local latest = Version.available(entry.name)

    if latest then
      parts[#parts + 1] = format(L.VERSION_UPDATE, entry.name, entry.text, latest)
    else
      parts[#parts + 1] = entry.name .. " " .. entry.text
    end
  end

  return concat(parts, ", ")
end

function Version.enable()
  if enabled then
    return false
  end

  replyAt, lastReplyAt = nil, nil

  store = DB.store("EbonAPI", { account = { versions = {} } })

  Version.register("EbonAPI", EbonAPI.version)

  enabled = true

  for _, entry in pairs(entries) do
    settle(entry)
  end

  return true
end

function Version.disable()
  if not enabled then
    return false
  end

  enabled = false

  Bus.untick("EbonAPI:reply")

  for name in pairs(notified) do
    notified[name] = nil
  end

  return true
end

function Handle:Version(text, url)
  if url and Version.parse(text) then
    self.link = url
  end

  return Version.register(self.addonName, text)
end

function Handle:AvailableUpdate()
  return Version.available(self.addonName)
end
