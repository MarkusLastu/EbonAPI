EbonAPI = EbonAPI or {}
EbonAPI.Channel = {}

local Channel = EbonAPI.Channel
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local Queue = EbonAPI.Queue
local Listeners = EbonAPI.Listeners
local Assembler = EbonAPI.Assembler
local Handle = EbonAPI.Handle
local L = EbonAPI.L

local type, tonumber, tostring, error, pcall = type, tonumber, tostring, error, pcall
local match, find, lower, len, format, sub = string.match, string.find, string.lower, string.len, string.format, string.sub
local ceil = math.ceil
local remove = table.remove

local NAME = "ebonapi"
local TAG = "EA1"
local PACKET_MAX = 16
local ASSEMBLY_TIMEOUT = 30
local ASSEMBLY_SWEEP = 5
local JOIN_TICK = 1
local JOIN_RETRY = 10
local JOIN_WARN = 3

Channel.NAME = NAME
Channel.TAG = TAG
Channel.LINE_MAX = 255
Channel.PACKET_MAX = PACKET_MAX
Channel.ASSEMBLY_TIMEOUT = ASSEMBLY_TIMEOUT

local listeners = {}
local wanted = false
local enabled = false
local joined = false
local index = nil
local joinAttempts = 0
local joinedAt = nil
local warned = false
local serial = 0
local baseName = Queue.baseName

Channel.received = 0
Channel.drops = { tag = 0, bounds = 0, expired = 0 }

local drops = Channel.drops

EbonAPI.Problems.declare("EbonAPI", "EBONAPI", {
  ["CHANNEL.REJECTED"] = { class = "rejet" },
  ["STREAM.EXPIRED"] = { class = "rejet" },
})

function Channel.expiry(counts)
  return function(owner, id, record)
    counts.expired = counts.expired + 1

    EbonAPI.Problems.reject("EbonAPI", "STREAM.EXPIRED", {
      sender = match(owner, "^[^\1]*"), id = id, got = record.count, total = record.total,
    })
  end
end

local function reject(reason, sender, sample)
  drops[reason] = drops[reason] + 1

  EbonAPI.Problems.reject("EbonAPI", "CHANNEL.REJECTED", {
    sender = sender, reason = reason, sample = sample and sub(sample, 1, 60),
  })
end

local function now()
  return (GetTime and GetTime()) or 0
end

local function myName()
  return (UnitName and UnitName("player")) or ""
end

local streams = Assembler.new("EbonAPI:assembly", ASSEMBLY_TIMEOUT, ASSEMBLY_SWEEP, PACKET_MAX, Channel.expiry(drops))

local function keyFor(addon, op)
  return addon .. ":" .. op
end

local function checkAddon(addon, who)
  if type(addon) ~= "string" or not match(addon, "^[%w_]+$") then
    error(who .. ' expects an addon name (letters, digits and "_"), got ' .. tostring(addon), 3)
  end
end

local function checkOp(op, who, addon)
  if type(op) ~= "string" or not match(op, "^%w+$") then
    error(who .. " expects an alphanumeric op for " .. addon .. ", got " .. tostring(op), 3)
  end
end

function Channel.on(addon, op, fn, handle)
  checkAddon(addon, "EbonAPI.Channel.on")
  checkOp(op, "EbonAPI.Channel.on", addon)

  if type(fn) ~= "function" then
    error("EbonAPI.Channel.on expects a function for " .. addon .. ":" .. op .. ", got " .. type(fn), 2)
  end

  local key = keyFor(addon, op)
  local list = listeners[key]

  if not list then
    list = Listeners.new()
    listeners[key] = list
  end

  if not list:add(fn) then
    return false
  end

  if handle then
    Channel.require()

    local owned = handle._channel

    if not owned then
      owned = {}
      handle._channel = owned
    end

    owned[#owned + 1] = op
    owned[#owned + 1] = fn
  end

  return true
end

function Channel.off(addon, op, fn)
  local key = keyFor(addon, op)
  local list = listeners[key]

  if not list or not list:remove(fn) then
    return false
  end

  if list.n == 0 then
    listeners[key] = nil
  end

  return true
end

function Channel.listenerCount(addon, op)
  local list = listeners[keyFor(addon, op)]

  return list and list.n or 0
end

local function hide(name)
  if not ChatFrame_RemoveChannel then
    return
  end

  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local frame = _G["ChatFrame" .. i]

    if frame then
      pcall(ChatFrame_RemoveChannel, frame, name)
    end
  end
end

local function resolve(name)
  if GetChannelName then
    local id = GetChannelName(name)

    if type(id) == "number" and id > 0 then
      return id
    end
  end

  if GetChannelList then
    local list = { GetChannelList() }

    for i = 1, #list, 2 do
      local id, found = tonumber(list[i]), list[i + 1]

      if id and id > 0 and type(found) == "string" and lower(found) == name then
        return id
      end
    end
  end

  return nil
end

local onChannelMessage
local tryJoin

local function lose()
  if not joined then
    return
  end

  joined = false
  index = nil
  joinedAt = nil
  joinAttempts = 0
  EbonAPI:ClearSticky("CHANNEL_JOINED")
  Log.trace("chan", nil, "lost")
  EbonAPI:Emit("CHANNEL_LOST")

  if enabled and wanted and not tryJoin() then
    Bus.tick("EbonAPI:channel", JOIN_TICK, tryJoin)
  end
end

tryJoin = function()
  local id = resolve(NAME)

  if not id then
    local attempt = joinAttempts

    joinAttempts = attempt + 1

    if attempt % JOIN_RETRY == 0 and JoinChannelByName then
      pcall(JoinChannelByName, NAME)

      id = resolve(NAME)

      if not warned and joinAttempts > JOIN_RETRY * JOIN_WARN then
        warned = true
        EbonAPI.Problems.degrade(EbonAPI.Problems.new("EbonAPI", "CHANNEL.NOT_JOINED",
          { attempts = ceil(joinAttempts / JOIN_RETRY), seconds = joinAttempts * JOIN_TICK }))
      end
    end
  end

  if id then
    index = id

    if not joined then
      joined = true
      joinedAt = now()

      if warned then
        warned = false
        EbonAPI.Problems.restore("EbonAPI", "CHANNEL.NOT_JOINED")
      end

      hide(NAME)
      Bus.untick("EbonAPI:channel")
      Bus.onCore("CHAT_MSG_CHANNEL", onChannelMessage)
      Log.trace("chan", nil, "joined", id)
      EbonAPI:Emit("CHANNEL_JOINED", id)
      Queue.wake()
    end

    return true
  end

  return false
end

local function ours(channelString, channelBase)
  if type(channelBase) == "string" and channelBase ~= "" then
    return lower(channelBase) == NAME
  end

  return type(channelString) == "string" and find(lower(channelString), NAME, 1, true) ~= nil
end

local function onNotice(kind, _, _, channelString, _, _, _, _, channelBase)
  if not ours(channelString, channelBase) then
    return
  end

  if kind == "YOU_LEFT" or kind == "SUSPENDED" then
    lose()
  elseif kind == "YOU_JOINED" and wanted and not joined then
    tryJoin()
  end
end

local function recheck()
  if not wanted then
    return
  end

  if not joined then
    if enabled and not tryJoin() then
      Bus.tick("EbonAPI:channel", JOIN_TICK, tryJoin)
    end

    return
  end

  local id = resolve(NAME)

  if id then
    index = id
  else
    lose()
  end
end

function Channel.require()
  if wanted then
    return joined
  end

  wanted = true

  if enabled and not joined then
    if not tryJoin() then
      Bus.tick("EbonAPI:channel", JOIN_TICK, tryJoin)
    end
  end

  return joined
end

function Channel.enable()
  if enabled then
    return false
  end

  enabled = true

  Bus.onCore("CHAT_MSG_CHANNEL_NOTICE", onNotice)
  Bus.onCore("CHANNEL_UI_UPDATE", recheck)
  Bus.onCore("PLAYER_ENTERING_WORLD", recheck)

  if wanted and not joined and not tryJoin() then
    Bus.tick("EbonAPI:channel", JOIN_TICK, tryJoin)
  end

  return true
end

function Channel.disable()
  if not enabled then
    return false
  end

  enabled = false

  lose()

  joinAttempts = 0
  warned = false

  Bus.offCore("CHAT_MSG_CHANNEL", onChannelMessage)
  Bus.offCore("CHAT_MSG_CHANNEL_NOTICE", onNotice)
  Bus.offCore("CHANNEL_UI_UPDATE", recheck)
  Bus.offCore("PLAYER_ENTERING_WORLD", recheck)
  Bus.untick("EbonAPI:channel")
  streams:clear()

  return true
end

function Channel.isWanted()
  return wanted
end

function Channel.isJoined()
  return joined
end

function Channel.index()
  return index
end

function Channel.joinedFor()
  if not joinedAt then
    return nil
  end

  return now() - joinedAt
end

function Channel.requests()
  return ceil(joinAttempts / JOIN_RETRY)
end

local function deliver(addon, op, sender, body, at)
  Channel.received = Channel.received + 1
  Log.trace("chan", nil, addon .. ":" .. op, len(body), at)

  local list = listeners[keyFor(addon, op)]

  if list then
    list:fire(sender, body, addon, op)
  end
end

local function fromOurChannel(channelIndex, channelString, channelBase)
  if channelIndex ~= nil and channelIndex == index then
    return true
  end

  if not ours(channelString, channelBase) then
    return false
  end

  if type(channelIndex) == "number" and channelIndex > 0 then
    index = channelIndex
  end

  return true
end

onChannelMessage = function(text, sender, _, channelString, _, _, _, channelIndex, channelBase)
  if not fromOurChannel(channelIndex, channelString, channelBase) then
    return
  end

  if type(text) ~= "string" then
    return
  end

  local start = find(text, "EA1:", 1, true)

  if not start then
    reject("tag", sender, text)
    return
  end

  local addon, op, number, k, n, body = match(text, "^([%w_]+):(%w+):(%d+)%.(%d+)/(%d+):(.*)$", start + 4)

  if not addon then
    reject("tag", sender, text)
    return
  end

  sender = baseName(sender)

  if not sender or sender == myName() then
    return
  end

  local at = now()

  if k == "1" and n == "1" then
    deliver(addon, op, sender, body, at)
    return
  end

  local whole, state = streams:add(sender, addon .. ":" .. op .. ":" .. number, tonumber(k), tonumber(n), body, at)

  if state == "bounds" then
    reject("bounds", sender, text)
    return
  end

  if whole then
    deliver(addon, op, sender, whole, at)
  end
end

function Channel.streamCount()
  return streams:count()
end

local function channelReady()
  if not joined then
    return false
  end

  local id = resolve(NAME)

  if id then
    index = id
    return true
  end

  lose()

  return false
end

local function rawChannel(text)
  if not SendChatMessage then
    return false, "SendChatMessage is not available"
  end

  if not index then
    return false, "the channel has no index"
  end

  local ok, err = pcall(SendChatMessage, text, "CHANNEL", nil, index)

  return ok, not ok and err or nil
end

local slices = {}

function Channel.bodyMax(addon, op)
  return PACKET_MAX * (Channel.LINE_MAX - len(TAG .. ":" .. addon .. ":" .. op .. ":999999.") - 6)
end

function Channel.say(addon, op, body, done)
  checkAddon(addon, "EbonAPI.Channel.say")
  checkOp(op, "EbonAPI.Channel.say", addon)

  body = body or ""

  if type(body) ~= "string" then
    error("EbonAPI.Channel.say expects a text body for " .. addon .. ":" .. op .. ", got " .. type(body), 2)
  end

  if find(body, "|", 1, true) then
    error("EbonAPI.Channel.say: the body of " .. addon .. ":" .. op .. " contains '|'", 2)
  end

  local number = serial % 999999 + 1
  local head = TAG .. ":" .. addon .. ":" .. op .. ":" .. number .. "."
  local budget = Channel.LINE_MAX - len(head) - 6

  if budget < 1 then
    error("EbonAPI.Channel.say: op too long for " .. addon .. ":" .. op, 2)
  end

  local length = len(body)
  local total = PACKET_MAX + 1

  if ceil(length / budget) <= PACKET_MAX then
    local _, count = Lib.splitUtf8(body, budget, slices)

    total = count
  end

  if total > PACKET_MAX then
    error("EbonAPI.Channel.say: body of " .. length .. " bytes for " .. addon .. ":"
      .. op .. ", the limit is " .. (PACKET_MAX * budget) .. " bytes", 2)
  end

  Channel.require()

  if not joined then
    return false, "not_joined"
  end

  for packet = 1, total do
    slices[packet] = head .. packet .. "/" .. total .. ":" .. slices[packet]
  end

  if not Queue.pushAll("channel", nil, nil, slices, total, addon, done) then
    return false, "full"
  end

  serial = number

  return true
end

local function checkWhisper(prefix, text, who)
  if type(prefix) ~= "string" or prefix == "" then
    error(who .. " expects a prefix, got " .. tostring(prefix), 3)
  end

  local room = Channel.LINE_MAX - len(prefix) - 1

  if type(text) ~= "string" or len(text) > room then
    error(who .. ": text missing or beyond " .. room .. " bytes for prefix " .. prefix, 3)
  end
end

function Channel.whisper(prefix, target, text, done, lane)
  checkWhisper(prefix, text, "EbonAPI.Channel.whisper")

  target = baseName(target)

  if not target then
    return false
  end

  return Queue.push("whisper", prefix, target, text, done, lane or prefix)
end

function Channel.whisperAll(prefix, target, parts, count, lane, key, body, single)
  count = count or #parts
  lane = lane or prefix

  if count == 0 then
    return true
  end

  for i = 1, count do
    checkWhisper(prefix, parts[i], "EbonAPI.Channel.whisperAll")
  end

  target = baseName(target)

  if not target then
    return false
  end

  if body == nil and count == 1 then
    key, body = false, parts[1]
  end

  local ok, why = Queue.pushAll("whisper", prefix, target, parts, count, lane, nil, key, body, single)

  if ok then
    return true, why
  end

  return false
end

function Channel.droppedTotal()
  return drops.tag + drops.bounds + drops.expired
end

function Handle:OnChannel(op, fn)
  return Channel.on(self.addonName, op, fn, self)
end

function Handle:OffChannel(op, fn)
  local owned = self._channel

  if owned then
    for i = #owned - 1, 1, -2 do
      if owned[i] == op and owned[i + 1] == fn then
        remove(owned, i + 1)
        remove(owned, i)
      end
    end
  end

  return Channel.off(self.addonName, op, fn)
end

function Handle:Say(op, body)
  return Channel.say(self.addonName, op, body)
end

function Handle:Whisper(prefix, target, text)
  return Channel.whisper(prefix, target, text, nil, self.addonName)
end

function Handle:WhisperAll(prefix, target, parts, count)
  return Channel.whisperAll(prefix, target, parts, count, self.addonName)
end

function Handle:IsChannelJoined()
  return joined
end

EbonAPI:AddTeardown(function(handle)
  local owned = handle._channel

  if not owned then
    return
  end

  for i = #owned - 1, 1, -2 do
    Channel.off(handle.addonName, owned[i], owned[i + 1])
    owned[i + 1], owned[i] = nil, nil
  end
end)

Queue.register("channel", rawChannel, channelReady)

EbonAPI:DeclareSticky("CHANNEL_JOINED")
