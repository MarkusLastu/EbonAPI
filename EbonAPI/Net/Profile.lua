EbonAPI = EbonAPI or {}
EbonAPI.Profile = {}

local Profile = EbonAPI.Profile
local Hash = EbonAPI.Hash
local Bus = EbonAPI.Bus
local DB = EbonAPI.DB
local Bridge = EbonAPI.Bridge
local Channel = EbonAPI.Channel
local State = EbonAPI.State
local Session = EbonAPI.Session
local CS = EbonAPI.CS
local Handle = EbonAPI.Handle

local type, tonumber, pairs, ipairs, next, error = type, tonumber, pairs, ipairs, next, error
local match, gmatch, byte, sub, len, concat, sort, format = string.match, string.gmatch, string.byte, string.sub, string.len, table.concat, table.sort, string.format
local floor = math.floor

local LETTER = "EbonAPI"
local ECHO_BASE = 200000
local ECHO_SPAN = 4096
local STACK_MAX = 63
local CLASS_MAX = 10
local SLOT_MAX = 20
local BUILD_ECHOES_MAX = 150
local BAN_LISTS_MAX = 20
local LIST_ECHOES_MAX = 150
local REQUEST_DELAY = 10
local REQUEST_INTERVAL = 30

Profile.ECHO_BASE = ECHO_BASE
Profile.REQUEST_DELAY = REQUEST_DELAY

local ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
local encode = {}
local decode = {}

for i = 0, 63 do
  local char = sub(ALPHABET, i + 1, i + 1)

  encode[i] = char
  decode[byte(char)] = i
end

local CLASS_TOKENS = {
  "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
  "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

local CLASS_INDEX = {}

for i, token in ipairs(CLASS_TOKENS) do
  CLASS_INDEX[token] = i
end

Profile.sent = { P = 0, D = 0, X = 0 }
Profile.received = 0
Profile.rejected = 0

local sent = Profile.sent

local store = nil
local enabled = false
local pendingBuilds = false
local pendingBans = false
local bansText, bansHash = nil, nil
local inflight = {}
local packed = {}
local chars = {}
local lockedIds = {}

function Profile.ClassIndex(token)
  return CLASS_INDEX[token]
end

function Profile.ClassToken(index)
  return CLASS_TOKENS[index]
end

function Profile.PlayerClass()
  if not UnitClass then
    return nil
  end

  local _, token = UnitClass("player")

  return CLASS_INDEX[token]
end

function Profile.Signature(text)
  return Hash.digest(text)
end

function Profile.EncodeEchoes(raw)
  local count = 0

  if type(raw) == "string" then
    for id, stacks in gmatch(raw, "(%d+)%.(%d+)") do
      id = tonumber(id) - ECHO_BASE
      stacks = tonumber(stacks)

      if id >= 0 and id < ECHO_SPAN and count < BUILD_ECHOES_MAX then
        if stacks > STACK_MAX then
          stacks = STACK_MAX
        end

        count = count + 1
        packed[count] = id * 64 + stacks
      end
    end
  end

  for i = #packed, count + 1, -1 do
    packed[i] = nil
  end

  sort(packed)

  local n = 0

  for i = 1, count do
    local value = packed[i]
    local id = floor(value / 64)

    chars[n + 1] = encode[floor(id / 64)]
    chars[n + 2] = encode[id % 64]
    chars[n + 3] = encode[value - id * 64]
    n = n + 3
  end

  return concat(chars, "", 1, n), count
end

function Profile.DecodeBuild(text)
  if type(text) ~= "string" or len(text) % 3 ~= 0 then
    return nil
  end

  local ids, stacks = {}, {}
  local count = 0

  for i = 1, len(text), 3 do
    local hi, lo, s = decode[byte(text, i)], decode[byte(text, i + 1)], decode[byte(text, i + 2)]

    if not hi or not lo or not s then
      return nil
    end

    count = count + 1
    ids[count] = ECHO_BASE + hi * 64 + lo
    stacks[count] = s
  end

  return ids, stacks, count
end

local function encodeIds(list, limit)
  local values = {}
  local count = 0

  for i = 1, #list do
    local id = tonumber(list[i])

    if id then
      id = id - ECHO_BASE

      if id >= 0 and id < ECHO_SPAN and id == floor(id) and count < limit then
        count = count + 1
        values[count] = id
      end
    end
  end

  sort(values)

  local out = {}

  for i = 1, count do
    out[i] = encode[floor(values[i] / 64)] .. encode[values[i] % 64]
  end

  return concat(out), count
end

local function decodeIds(text)
  if len(text) % 2 ~= 0 then
    return nil
  end

  local ids = {}
  local count = 0

  for i = 1, len(text), 2 do
    local hi, lo = decode[byte(text, i)], decode[byte(text, i + 1)]

    if not hi or not lo then
      return nil
    end

    count = count + 1
    ids[count] = ECHO_BASE + hi * 64 + lo
  end

  return ids, count
end

function Profile.EncodeLocked(ids)
  return encodeIds(ids, BUILD_ECHOES_MAX)
end

function Profile.DecodeLocked(text)
  if type(text) ~= "string" then
    return nil
  end

  return decodeIds(text)
end

function Profile.EncodeBans(lists)
  local texts = {}

  for _, list in ipairs(lists) do
    local text, count = encodeIds(list, LIST_ECHOES_MAX)

    if count > 0 and #texts < BAN_LISTS_MAX then
      texts[#texts + 1] = text
    end
  end

  sort(texts)

  return concat(texts, ";"), #texts
end

function Profile.DecodeBans(text)
  if type(text) ~= "string" then
    return nil
  end

  local lists = {}

  if text == "" then
    return lists
  end

  for chunk in gmatch(text, "[^;]+") do
    local ids = decodeIds(chunk)

    if not ids then
      return nil
    end

    lists[#lists + 1] = ids
  end

  return lists
end

EbonAPI.Problems.declare("EbonAPI", "EBONAPI", {
  ["PROFILE.REJECTED"] = { class = "rejet" },
})

local function reject(sender, reason, body)
  Profile.rejected = Profile.rejected + 1

  EbonAPI.Problems.reject("EbonAPI", "PROFILE.REJECTED", {
    sender = sender, reason = reason, sample = sub(body, 1, 60),
  })
end

local function onSlots(sender, body)
  local class, list = match(body, "^(%d+):([%d%.]*)$")

  class = tonumber(class)

  if not class then
    return reject(sender, "slots: malformed message", body)
  end

  if class < 1 or class > CLASS_MAX then
    return reject(sender, "slots: class " .. class .. " is outside 1 to " .. CLASS_MAX, body)
  end

  local slots = {}

  for slot in gmatch(list, "%d+") do
    slot = tonumber(slot)

    if slot < 1 or slot > SLOT_MAX then
      return reject(sender, "slots: slot " .. slot .. " is outside 1 to " .. SLOT_MAX, body)
    end

    slots[#slots + 1] = slot
  end

  Profile.received = Profile.received + 1
  EbonAPI:Emit("PROFILE_SLOTS", sender, class, slots)
end

local function onBuild(sender, body)
  local class, slot, hash, echoes, locked = match(body, "^(%d+):(%d+):([%w%-_]+):([%w%-_]*):([%w%-_]*)$")

  if not class then
    class, slot, hash, echoes = match(body, "^(%d+):(%d+):([%w%-_]+):([%w%-_]*)$")
  end

  class, slot = tonumber(class), tonumber(slot)

  if not class then
    return reject(sender, "build: malformed message", body)
  end

  if class < 1 or class > CLASS_MAX then
    return reject(sender, "build: class " .. class .. " is outside 1 to " .. CLASS_MAX, body)
  end

  if slot < 1 or slot > SLOT_MAX then
    return reject(sender, "build: slot " .. slot .. " is outside 1 to " .. SLOT_MAX, body)
  end

  if len(echoes) % 3 ~= 0 or len(echoes) > BUILD_ECHOES_MAX * 3 then
    return reject(sender, "build: echo list of " .. len(echoes) .. " characters is not a multiple of 3 up to " .. BUILD_ECHOES_MAX * 3, body)
  end

  if locked and (len(locked) % 2 ~= 0 or len(locked) > BUILD_ECHOES_MAX * 2) then
    return reject(sender, "build: locked list of " .. len(locked) .. " characters is not a multiple of 2 up to " .. BUILD_ECHOES_MAX * 2, body)
  end

  local signed = class .. ":" .. slot .. ":" .. echoes

  if locked then
    signed = signed .. ":" .. locked
  end

  if Profile.Signature(signed) ~= hash then
    return reject(sender, "build: signature does not match", body)
  end

  Profile.received = Profile.received + 1
  EbonAPI:Emit("PROFILE_BUILD", sender, class, slot, hash, echoes, locked)
end

local function onBans(sender, body)
  local class, hash, lists = match(body, "^(%d+):([%w%-_]+):([%w%-_;]*)$")

  class = tonumber(class)

  if not class then
    return reject(sender, "bans: malformed message", body)
  end

  if class < 1 or class > CLASS_MAX then
    return reject(sender, "bans: class " .. class .. " is outside 1 to " .. CLASS_MAX, body)
  end

  local count = 0

  for chunk in gmatch(lists, "[^;]+") do
    count = count + 1

    if count > BAN_LISTS_MAX then
      return reject(sender, "bans: more than " .. BAN_LISTS_MAX .. " lists", body)
    end

    if len(chunk) % 2 ~= 0 or len(chunk) > LIST_ECHOES_MAX * 2 then
      return reject(sender, "bans: list of " .. len(chunk) .. " characters is not a multiple of 2 up to " .. LIST_ECHOES_MAX * 2, body)
    end
  end

  if Profile.Signature(class .. ":" .. lists) ~= hash then
    return reject(sender, "bans: signature does not match", body)
  end

  Profile.received = Profile.received + 1
  EbonAPI:Emit("PROFILE_BANS", sender, class, hash, lists)
end

local function reference()
  if not store or not store.char then
    return nil
  end

  local ref = store.char.profile

  if type(ref) ~= "table" then
    ref = { slots = {} }
    store.char.profile = ref
  end

  if type(ref.slots) ~= "table" then
    ref.slots = {}
  end

  return ref
end

local function lockedOf(build)
  local list = State.BuildEchoes(build)
  local count = 0

  for i = 1, #list do
    if list[i].locked then
      count = count + 1
      lockedIds[count] = list[i].spellId
    end
  end

  for i = #lockedIds, count + 1, -1 do
    lockedIds[i] = nil
  end

  return lockedIds
end

local function say(key, op, body, apply)
  if inflight[key] == body then
    return true
  end

  local queued = Channel.say(LETTER, op, body, function(ok)
    if inflight[key] == body then
      inflight[key] = nil
    end

    if ok then
      apply()
    end
  end)

  if not queued then
    return false
  end

  inflight[key] = body
  sent[op] = sent[op] + 1

  return true
end

local function flush()
  if not enabled or not Channel.isWanted() then
    return false
  end

  local class = Profile.PlayerClass()
  local ref = reference()

  if not class or not ref then
    return false
  end

  if not Channel.isJoined() then
    return false
  end

  local complete = true
  local builds = State.GetBuilds()

  if builds and type(builds.slots) == "table" then
    local order = {}
    local hashes = {}
    local texts = {}
    local locks = {}

    for slot, build in pairs(builds.slots) do
      slot = tonumber(slot)

      if slot and slot >= 1 and slot <= SLOT_MAX and type(build) == "table" then
        local text = Profile.EncodeEchoes(build.echoes)
        local locked = Profile.EncodeLocked(lockedOf(build))

        order[#order + 1] = slot
        texts[slot] = text
        locks[slot] = locked
        hashes[slot] = Profile.Signature(class .. ":" .. slot .. ":" .. text .. ":" .. locked)
      end
    end

    sort(order)

    local layout = class .. ":" .. concat(order, ".")
    local known = ref.slots

    if pendingBuilds or ref.layout ~= layout then
      local queued = say("P", "P", layout, function()
        for slot in pairs(known) do
          if texts[slot] == nil then
            known[slot] = nil
          end
        end

        ref.layout = layout
      end)

      if not queued then
        complete = false
      end
    end

    for i = 1, #order do
      local slot = order[i]
      local hash = hashes[slot]

      if pendingBuilds or known[slot] ~= hash then
        local queued = say(slot, "D", class .. ":" .. slot .. ":" .. hash .. ":" .. texts[slot] .. ":" .. locks[slot], function()
          known[slot] = hash
        end)

        if not queued then
          complete = false
        end
      end
    end

    if complete then
      pendingBuilds = false
    end
  else
    complete = false
  end

  if bansText and (pendingBans or ref.bans ~= bansHash) then
    local hash = bansHash

    if say("X", "X", class .. ":" .. hash .. ":" .. bansText, function()
      ref.bans = hash
    end) then
      pendingBans = false
    else
      complete = false
    end
  end

  return complete
end

Profile.flush = flush

function Profile.SetBans(addon, lists)
  if type(lists) ~= "table" then
    error(format("EbonAPI: %s: SetProfileBans expects a table of lists, got %s", addon, type(lists)), 2)
  end

  for i = 1, #lists do
    if type(lists[i]) ~= "table" then
      error(format("EbonAPI: %s: SetProfileBans expects a table of lists of echo ids, list %d is a %s", addon, i, type(lists[i])), 2)
    end
  end

  local class = Profile.PlayerClass()

  if not class then
    return false
  end

  local text = Profile.EncodeBans(lists)

  bansText = text
  bansHash = Profile.Signature(class .. ":" .. text)

  flush()

  return true
end

local function onBuilds()
  flush()
end

local function onJoined()
  flush()
end

local function requestBuilds()
  Bus.untick("EbonAPI:profile")

  if not Channel.isWanted() then
    return
  end

  Bridge.request(CS.REFRESH_PERKS, "", REQUEST_INTERVAL)
  Bridge.request(CS.REFRESH_BUILDS, "", REQUEST_INTERVAL)
end

function Profile.enable()
  if enabled then
    return false
  end

  enabled = true

  store = DB.store("EbonAPI", { character = { profile = { slots = {} } } })

  pendingBuilds = reference() ~= nil and Session.isNew()
  pendingBans = pendingBuilds

  if next(EbonAPI._addons) ~= nil then
    Channel.require()

    if pendingBuilds then
      Bus.tick("EbonAPI:profile", REQUEST_DELAY, requestBuilds)
    end
  end

  Channel.on(LETTER, "P", onSlots)
  Channel.on(LETTER, "D", onBuild)
  Channel.on(LETTER, "X", onBans)

  EbonAPI:On("SERVER_BUILDS", onBuilds)
  EbonAPI:On("CHANNEL_JOINED", onJoined)

  return true
end

function Profile.disable()
  if not enabled then
    return false
  end

  enabled = false

  Channel.off(LETTER, "P", onSlots)
  Channel.off(LETTER, "D", onBuild)
  Channel.off(LETTER, "X", onBans)

  EbonAPI:Off("SERVER_BUILDS", onBuilds)
  EbonAPI:Off("CHANNEL_JOINED", onJoined)

  Bus.untick("EbonAPI:profile")

  return true
end

EbonAPI._consumerHook = function()
  if not enabled then
    return
  end

  Channel.require()

  if pendingBuilds then
    Bus.tick("EbonAPI:profile", REQUEST_DELAY, requestBuilds)
  end
end

function Profile.reference()
  return reference()
end

function Handle:SetProfileBans(lists)
  return Profile.SetBans(self.addonName, lists)
end
