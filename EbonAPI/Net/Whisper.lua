EbonAPI = EbonAPI or {}
EbonAPI.Whisper = {}

local Whisper = EbonAPI.Whisper
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local Queue = EbonAPI.Queue
local Channel = EbonAPI.Channel
local Listeners = EbonAPI.Listeners
local Assembler = EbonAPI.Assembler
local Handle = EbonAPI.Handle

local type, tonumber, tostring, error, pcall = type, tonumber, tostring, error, pcall
local match, find, sub, len = string.match, string.find, string.sub, string.len
local ceil = math.ceil

local TAG = "EAS"
local PART_MAX = 400
local STREAM_TIMEOUT = 30
local STREAM_SWEEP = 5

Whisper.TAG = TAG
Whisper.PART_MAX = PART_MAX
Whisper.STREAM_TIMEOUT = STREAM_TIMEOUT

local plain = {}
local streamed = {}
local prefixes = {}
local listening = false
local serial = 0
local baseName = Queue.baseName

Whisper.received = 0
Whisper.drops = { tag = 0, bounds = 0, unknown = 0, expired = 0 }

local drops = Whisper.drops

EbonAPI.Problems.declare("EbonAPI", "EBONAPI", {
  ["WHISPER.REJECTED"] = { class = "rejet" },
})

local function reject(reason, sender, sample)
  drops[reason] = drops[reason] + 1

  EbonAPI.Problems.reject("EbonAPI", "WHISPER.REJECTED", {
    sender = sender, reason = reason, sample = sub(sample, 1, 60),
  })
end

local function now()
  return (GetTime and GetTime()) or 0
end

local streams = Assembler.new("EbonAPI:whispers", STREAM_TIMEOUT, STREAM_SWEEP, PART_MAX, Channel.expiry(drops))

local function clean(text)
  return match(text, "^|c%x%x%x%x%x%x%x%x%[[^%]]*%]|r%s*(.*)$") or text
end

local function keyFor(prefix, op)
  return prefix .. ":" .. op
end

local function onAddonMessage(prefix, text, distribution, sender)
  if distribution ~= "WHISPER" or not prefixes[prefix] or type(text) ~= "string" then
    return
  end

  sender = baseName(sender)

  if not sender then
    return
  end

  text = clean(text)

  local reserved = sub(text, 1, 4) == "EAS:"
  local op, id, k, n, slice

  if reserved then
    op, id, k, n, slice = match(text, "^(%w+):([^:]+):(%d+)/(%d+):(.*)$", 5)
  end

  if op then
    local entry = streamed[keyFor(prefix, op)]

    if not entry then
      reject("unknown", sender, text)
      return
    end

    local body, state = streams:add(sender .. "\1" .. prefix, op .. ":" .. id, tonumber(k), tonumber(n), slice, now())

    if state == "bounds" then
      reject("bounds", sender, text)
    elseif state == "progress" then
      entry.parts:fire(sender, id, op)
    elseif body then
      Whisper.received = Whisper.received + 1
      Log.trace("wisp", nil, prefix .. ":" .. op, len(body))
      entry.list:fire(sender, body, id, op)
    end

    return
  end

  local list = plain[prefix]

  if list then
    Whisper.received = Whisper.received + 1
    Log.trace("wisp", nil, prefix, len(text))
    list:fire(sender, text, distribution, prefix)
  elseif reserved then
    reject("tag", sender, text)
  end
end

local function checkPrefix(prefix, who)
  if type(prefix) ~= "string" or prefix == "" then
    error("EbonAPI.Whisper." .. who .. " expects a prefix, got " .. tostring(prefix), 3)
  end
end

local function checkOp(op, who)
  if type(op) ~= "string" or not match(op, "^%w+$") then
    error("EbonAPI.Whisper." .. who .. " expects an alphanumeric op, got " .. tostring(op), 3)
  end
end

local function register(prefix)
  if not prefixes[prefix] then
    prefixes[prefix] = 0

    if RegisterAddonMessagePrefix then
      pcall(RegisterAddonMessagePrefix, prefix)
    end
  end

  prefixes[prefix] = prefixes[prefix] + 1

  if not listening then
    listening = true
    Bus.onCore("CHAT_MSG_ADDON", onAddonMessage)
  end
end

local function unregister(prefix)
  local count = prefixes[prefix]

  if not count then
    return
  end

  if count <= 1 then
    prefixes[prefix] = nil
  else
    prefixes[prefix] = count - 1
  end
end

function Whisper.on(prefix, fn, handle)
  checkPrefix(prefix, "on")

  if type(fn) ~= "function" then
    error("EbonAPI.Whisper.on expects a function for " .. prefix .. ", got " .. type(fn), 2)
  end

  local list = plain[prefix]

  if not list then
    list = Listeners.new()
    plain[prefix] = list
  end

  if not list:add(fn) then
    return false
  end

  register(prefix)

  if handle then
    local owned = handle._whisper

    if not owned then
      owned = {}
      handle._whisper = owned
    end

    owned[#owned + 1] = prefix
    owned[#owned + 1] = fn
  end

  return true
end

function Whisper.off(prefix, fn)
  local list = plain[prefix]

  if not list or not list:remove(fn) then
    return false
  end

  if list.n == 0 then
    plain[prefix] = nil
  end

  unregister(prefix)

  return true
end

function Whisper.onStream(prefix, op, fn, onPart, handle)
  checkPrefix(prefix, "onStream")
  checkOp(op, "onStream")

  if type(fn) ~= "function" then
    error("EbonAPI.Whisper.onStream expects a function for " .. prefix .. ":" .. op .. ", got " .. type(fn), 2)
  end

  local key = keyFor(prefix, op)
  local entry = streamed[key]

  if not entry then
    entry = { list = Listeners.new(), parts = Listeners.new(), partOf = {} }
    streamed[key] = entry
  end

  if not entry.list:add(fn) then
    return false
  end

  if type(onPart) == "function" then
    entry.parts:add(onPart)
    entry.partOf[fn] = onPart
  end

  register(prefix)

  if handle then
    local owned = handle._whisperStreams

    if not owned then
      owned = {}
      handle._whisperStreams = owned
    end

    owned[#owned + 1] = { prefix, op, fn }
  end

  return true
end

function Whisper.offStream(prefix, op, fn)
  local key = keyFor(prefix, op)
  local entry = streamed[key]

  if not entry or not entry.list:remove(fn) then
    return false
  end

  local onPart = entry.partOf[fn]

  if onPart then
    entry.parts:remove(onPart)
    entry.partOf[fn] = nil
  end

  if entry.list.n == 0 then
    streamed[key] = nil
  end

  unregister(prefix)

  return true
end

function Whisper.stream(prefix, target, op, id, body, lane, single)
  checkPrefix(prefix, "stream")
  checkOp(op, "stream")

  if type(body) ~= "string" then
    error("EbonAPI.Whisper.stream expects a text body for " .. prefix .. ":" .. op .. ", got " .. type(body), 2)
  end

  local named = id ~= nil

  if id == nil then
    serial = serial % 1048575 + 1
    id = tostring(serial)
  elseif type(id) ~= "string" or id == "" or find(id, ":", 1, true) then
    error("EbonAPI.Whisper.stream: invalid stream id for " .. prefix .. ":" .. op, 2)
  end

  local head = TAG .. ":" .. op .. ":" .. id .. ":"
  local budget = Channel.LINE_MAX - len(prefix) - 1 - len(head) - 8

  if budget < 1 then
    error("EbonAPI.Whisper.stream: header too long for " .. prefix .. ":" .. op, 2)
  end

  local length = len(body)
  local parts = {}
  local total = PART_MAX + 1

  if ceil(length / budget) <= PART_MAX then
    local _, count = Lib.splitUtf8(body, budget, parts)

    total = count
  end

  if total > PART_MAX then
    error("EbonAPI.Whisper.stream: body of " .. length .. " bytes for " .. prefix .. ":" .. op
      .. ", the limit is " .. (PART_MAX * budget) .. " bytes", 2)
  end

  target = baseName(target)

  if not target then
    return false
  end

  for part = 1, total do
    parts[part] = head .. part .. "/" .. total .. ":" .. parts[part]
  end

  return Channel.whisperAll(prefix, target, parts, total, lane, named and head or op, body, single)
end

function Whisper.streamCount()
  return streams:count()
end

function Whisper.droppedTotal()
  return drops.tag + drops.bounds + drops.unknown + drops.expired
end

function Handle:OnWhisper(prefix, fn)
  return Whisper.on(prefix, fn, self)
end

function Handle:OffWhisper(prefix, fn)
  local owned = self._whisper

  if owned then
    for i = #owned - 1, 1, -2 do
      if owned[i] == prefix and owned[i + 1] == fn then
        table.remove(owned, i + 1)
        table.remove(owned, i)
      end
    end
  end

  return Whisper.off(prefix, fn)
end

function Handle:OnWhisperStream(prefix, op, fn, onPart)
  return Whisper.onStream(prefix, op, fn, onPart, self)
end

function Handle:OffWhisperStream(prefix, op, fn)
  local owned = self._whisperStreams

  if owned then
    for i = #owned, 1, -1 do
      local entry = owned[i]

      if entry[1] == prefix and entry[2] == op and entry[3] == fn then
        table.remove(owned, i)
      end
    end
  end

  return Whisper.offStream(prefix, op, fn)
end

function Handle:WhisperStream(prefix, target, op, id, body)
  return Whisper.stream(prefix, target, op, id, body, self.addonName)
end

EbonAPI:AddTeardown(function(handle)
  local owned = handle._whisper

  if owned then
    for i = #owned - 1, 1, -2 do
      Whisper.off(owned[i], owned[i + 1])
      owned[i + 1] = nil
      owned[i] = nil
    end
  end

  local streamsOwned = handle._whisperStreams

  if streamsOwned then
    for i = #streamsOwned, 1, -1 do
      local entry = streamsOwned[i]

      Whisper.offStream(entry[1], entry[2], entry[3])
      streamsOwned[i] = nil
    end
  end
end)
