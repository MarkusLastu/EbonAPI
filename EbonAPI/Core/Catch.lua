EbonAPI = EbonAPI or {}
EbonAPI.Catch = {}

local Catch = EbonAPI.Catch

local type, tostring, pcall, pairs = type, tostring, pcall, pairs
local find, sub, lower, gsub, match, gmatch = string.find, string.sub, string.lower, string.gsub, string.match, string.gmatch

local FOLDER = "addons[\\/]([^\\/]+)[\\/]"
local PE_PATH = "addons\\projectebonhold\\"
local MAX_RAW = 30
local MAX_RING = 30
local MAX_BURSTS = 64
local MAX_NEIGHBORS = 5
local NEIGHBOR_SECONDS = 10
local STACK_LINES = 8
local MAX_QUEUE = 8
local MAX_DRAIN = 16

local previous, older
local busy, forwarding, ready, listening = false, false, false, false
local folders, globalOwner
local declared, declaredGlobals = {}, {}
local bursts, burstCount = {}, 0
local raw, rawCount = {}, 0
local ringName, ringMessage, ringAt = {}, {}, {}
local ringHead, ringCount = 0, 0
local queue, queueCount = {}, 0

Catch.internal = nil
Catch.internalCount = 0
Catch.lost = 0

local function reportInternal(err)
  pcall(EbonAPI.Problems.bug, "EbonAPI", "catch", tostring(err))
end

local function internal(err)
  Catch.internal = err
  Catch.internalCount = Catch.internalCount + 1

  if ready then
    reportInternal(err)
  end
end

local function guarded(fn, ...)
  local ok, err = pcall(fn, ...)

  if not ok then
    internal(err)
  end

  return ok
end

local function folderOf(text, lowered, init)
  local first, last, folder = find(lowered, FOLDER, init)

  if not first then
    return nil
  end

  return folder, sub(text, last - #folder, last - 1), last + 1
end

local function build()
  folders, globalOwner = {}, {}

  local count = GetNumAddOns and GetNumAddOns() or 0
  local names, deps = {}, {}

  for index = 1, count do
    local name = GetAddOnInfo(index)

    if name then
      names[index] = name
      deps[index] = GetAddOnDependencies and { GetAddOnDependencies(index) } or {}
    end
  end

  local connected = { ebonapi = true }
  local changed = true

  while changed do
    changed = false

    for index = 1, count do
      local name = names[index]
      local key = name and lower(name)

      if key and not connected[key] then
        local list = deps[index]

        for position = 1, #list do
          if connected[lower(list[position])] then
            connected[key] = true
            changed = true
            break
          end
        end
      end
    end
  end

  for index = 1, count do
    local name = names[index]
    local key = name and lower(name)

    if key and connected[key] then
      folders[key] = declared[key] or name
    end
  end

  for key, name in pairs(declared) do
    folders[key] = name
  end

  for _, name in pairs(folders) do
    if not declaredGlobals[name] then
      globalOwner[name] = name
    end
  end

  for name, list in pairs(declaredGlobals) do
    for position = 1, #list do
      if type(list[position]) == "string" then
        globalOwner[list[position]] = name
      end
    end
  end
end

function Catch.declare(name, stack, globals)
  local lowered = lower(stack or "")
  local folder = folderOf(stack, lowered, 1)

  if folder then
    declared[folder] = name

    if folders then
      folders[folder] = name
    end
  end

  if type(globals) == "table" then
    declaredGlobals[name] = globals
  end

  if globalOwner then
    globalOwner[name] = globalOwner[name] or name

    if type(globals) == "table" then
      for position = 1, #globals do
        if type(globals[position]) == "string" then
          globalOwner[globals[position]] = name
        end
      end
    end
  end
end

local function connectedIn(text, lowered)
  local init = 1

  while true do
    local folder, _, following = folderOf(text, lowered, init)

    if not folder then
      return nil
    end

    local name = folders[folder]

    if name then
      return name
    end

    init = following
  end
end

local function triggerFile(message, line)
  local file = match(message, "^(.-):%d+:") or match(line, "^(.-):%d+:")

  return file and (match(file, "[Aa]dd[Oo]ns\\(.*)$") or file) or nil
end

local function foreignName(message, lm, stack, ls)
  local folder, original = folderOf(message, lm, 1)

  if not folder then
    folder, original = folderOf(stack, ls, 1)
  end

  if folder then
    return find(folder, "^blizzard_") and "Blizzard" or original
  end

  if find(lm, "interface\\framexml", 1, true) or find(ls, "interface\\framexml", 1, true)
    or find(lm, "blizzard_", 1, true) or find(ls, "blizzard_", 1, true) then
    return "Blizzard"
  end

  return "?"
end

local function attribute(message, stack)
  local lm, ls = lower(message), lower(stack)
  local line = match(stack, "^[^\n]*")
  local name = connectedIn(message, lm) or connectedIn(line, lower(line))

  if name then
    return name
  end

  name = connectedIn(stack, ls)

  if name then
    return name, triggerFile(message, line)
  end

  if find(lm, PE_PATH, 1, true) or find(ls, PE_PATH, 1, true) then
    return "ProjectEbonhold"
  end

  local chunk = match(message, '^%[string "(.-)"%]') or match(line, '^%[string "(.-)"%]')

  if chunk then
    for id in gmatch(chunk, "[%a_][%w_]*") do
      name = globalOwner[id]

      if name then
        return name
      end
    end
  end

  return nil, nil, foreignName(message, lm, stack, ls)
end

local function trimStack(stack)
  local position = 0

  for _ = 1, STACK_LINES do
    position = find(stack, "\n", position + 1, true)

    if not position then
      return stack
    end
  end

  return sub(stack, 1, position - 1)
end

local function foreign(name, message, at)
  message = sub(message, 1, 200)

  local index = ringHead % MAX_RING + 1

  ringHead = index
  ringName[index], ringMessage[index], ringAt[index] = name, message, at

  if ringCount < MAX_RING then
    ringCount = ringCount + 1
  end

  EbonAPI.Problems.foreign(name, message, at)
end

local function again(template, at)
  return {
    code = template.code, addon = template.addon, class = template.class, facts = template.facts,
    key = template.key, where = template.where, stack = template.stack, at = at,
  }
end

local function remember(signature, value)
  if burstCount >= MAX_BURSTS then
    bursts, burstCount = {}, 0
  end

  bursts[signature] = value
  burstCount = burstCount + 1
end

local function bug(addon, message, stack, at, triggered, signature)
  local Problems = EbonAPI.Problems

  remember(signature, again(Problems.bug(addon, Problems.where(message), message, trimStack(stack), at, triggered), at))
end

local function record(message, stack, owner, own, at)
  at = at or time()

  if not ready then
    if rawCount >= MAX_RAW then
      Catch.lost = Catch.lost + 1
      return
    end

    local base = rawCount * 5

    rawCount = rawCount + 1
    raw[base + 1], raw[base + 2], raw[base + 3], raw[base + 4], raw[base + 5] = message, stack, owner, own, at
    return
  end

  local signature = (owner or "") .. "\031" .. gsub(message, "0x%x+", "") .. "\031" .. stack
  local seen = bursts[signature]

  if seen then
    if type(seen) == "string" then
      foreign(seen, message, at)
    else
      EbonAPI.Problems.report(again(seen, at))
    end

    return
  end

  if not folders then
    build()
  end

  local addon, triggered, other

  if owner and (owner == "EbonAPI" or EbonAPI._addons[owner]) then
    addon = owner
  else
    addon, triggered, other = attribute(message, stack)
  end

  if addon then
    return bug(addon, message, stack, at, triggered, signature)
  end

  if own then
    return bug("EbonAPI", message, stack, at, nil, signature)
  end

  remember(signature, other)
  foreign(other, message, at)
end

local function pourLost()
  local journal = ready and Catch.lost > 0 and EbonAPI.Problems.journal()

  if journal then
    journal.lost = (journal.lost or 0) + Catch.lost
    Catch.lost = 0
  end
end

local function capture(message, stack, owner, own, at)
  if busy then
    if queueCount >= MAX_QUEUE then
      Catch.lost = Catch.lost + 1
      return
    end

    local base = queueCount * 4

    queueCount = queueCount + 1
    queue[base + 1], queue[base + 2], queue[base + 3], queue[base + 4] = message, stack, owner, own
    return
  end

  busy = true
  guarded(record, message, stack, owner, own, at)

  local rounds = 0

  while queueCount > 0 do
    if rounds >= MAX_DRAIN then
      Catch.lost = Catch.lost + queueCount

      for index = 1, queueCount * 4 do
        queue[index] = nil
      end

      queueCount = 0
      break
    end

    rounds = rounds + 1

    local base = (queueCount - 1) * 4
    local queuedMessage, queuedStack, queuedOwner, queuedOwn = queue[base + 1], queue[base + 2], queue[base + 3], queue[base + 4]

    queue[base + 1], queue[base + 2], queue[base + 3], queue[base + 4] = nil, nil, nil, nil
    queueCount = queueCount - 1
    guarded(record, queuedMessage, queuedStack, queuedOwner, queuedOwn)
  end

  busy = false
  pourLost()
end

local function call(handler, message)
  guarded(handler, message)

  return true
end

function Catch.forward(message)
  if forwarding then
    return older ~= nil and call(older, message)
  end

  if not previous then
    return false
  end

  forwarding = true
  call(previous, message)
  forwarding = false

  return true
end

local function catch(message)
  if not forwarding then
    capture(tostring(message), debugstack and debugstack(3, 12, 0) or "", nil, false)
  end

  return Catch.forward(message)
end

function Catch.report(err, owner)
  capture(tostring(err), debugstack and debugstack(2, 12, 0) or "", owner, true)
end

function Catch.neighbors(now)
  local list, count = nil, 0

  for step = 0, ringCount - 1 do
    local index = (ringHead - 1 - step) % MAX_RING + 1
    local at = ringAt[index]

    if now - at > NEIGHBOR_SECONDS or count >= MAX_NEIGHBORS then
      break
    end

    list = list or {}
    count = count + 1

    local place = match(ringMessage[index], "([^\\/:]+:%d+):")

    list[count] = ringName[index] .. " " .. (place or sub(ringMessage[index], 1, 60)) .. " (" .. date("%H:%M:%S", at) .. ")"
  end

  return list
end

local function action(code, addon, name)
  if not ready then
    return
  end

  if not folders then
    build()
  end

  addon, name = tostring(addon or "?"), tostring(name or "?")

  local handle = folders[lower(addon)]

  if handle then
    local Problems = EbonAPI.Problems

    Problems.report(Problems.make(handle, code, { action = name }))
  else
    foreign(addon, code .. ": " .. name, time())
  end
end

local ACTIONS = {
  ADDON_ACTION_BLOCKED = "EBONAPI.GAME.ACTION_BLOCKED",
  ADDON_ACTION_FORBIDDEN = "EBONAPI.GAME.ACTION_FORBIDDEN",
}

function Catch.login()
  local current = geterrorhandler and geterrorhandler()

  if current and current ~= catch then
    older, previous = previous, current
    seterrorhandler(catch)
  end

  if not listening and EbonAPI.Bus then
    listening = true

    for event, code in pairs(ACTIONS) do
      EbonAPI.Bus.onCore(event, function(addon, name)
        guarded(action, code, addon, name)
      end)
    end
  end
end

function Catch.problemsReady()
  local Problems = EbonAPI.Problems
  local attach = Problems.attach

  ready = true

  Problems.attach = function()
    local attached = attach()

    pourLost()

    return attached
  end

  local count = rawCount

  rawCount = 0

  for index = 0, count - 1 do
    local base = index * 5
    local message, stack, owner, own, at = raw[base + 1], raw[base + 2], raw[base + 3], raw[base + 4], raw[base + 5]

    raw[base + 1], raw[base + 2], raw[base + 3], raw[base + 4], raw[base + 5] = nil, nil, nil, nil, nil
    capture(message, stack, owner, own, at)
  end

  if Catch.internal ~= nil then
    reportInternal(Catch.internal)
  end

  pourLost()
end

Catch.catch = catch

if geterrorhandler and seterrorhandler then
  previous = geterrorhandler()
  seterrorhandler(catch)
end
