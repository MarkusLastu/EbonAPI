local Core = AutoCallboardCore or {}
AutoCallboardCore = Core

local type, tonumber, tostring, ipairs, pcall, error = type, tonumber, tostring, ipairs, pcall, error
local string, table, math = string, table, math

local RT = AutoCallboardRuntime

local function Problem(name, facts, cause)
  return RT.api:Problem(name, facts, cause)
end

local function Report(name, facts, cause)
  return RT.api:Report(RT.api:Problem(name, facts, cause))
end

Core.ROUTE_CODE_PREFIX = "ACB1"
Core.ROUTE_CODE_ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789()"
Core.ROUTE_HASH_LENGTH = 12

local PREFIX = Core.ROUTE_CODE_PREFIX
local ALPHABET = Core.ROUTE_CODE_ALPHABET
local DIGIT = {}
local BYTE_DIGIT = {}

for i = 1, #(ALPHABET) do
  DIGIT[string.sub(ALPHABET, i, i)] = i - 1
  BYTE_DIGIT[string.byte(ALPHABET, i)] = i - 1
end

Core.ROUTE_CODE_DIGIT = DIGIT

local ACTION_KINDS = { "gossip", "available", "active", "accept", "confirm", "complete", "turnin" }
local ACTION_INDEX = {}

for i, kind in ipairs(ACTION_KINDS) do
  ACTION_INDEX[kind] = i - 1
end

local INDEXED_ACTIONS = { gossip = true, available = true, active = true }
local QUEST_ACTIONS = { available = true, active = true, accept = true, confirm = true, turnin = true }
local CHANGES = { "in", "done", "out" }
local CHANGE_INDEX = { ["in"] = 0, done = 1, out = 2 }

local XY_BITS = 10
local XY_MAX = 1023
local MAX_NAME_BYTES = 160
local MAX_MAP_BYTES = 64
local MAX_MAPS = 64
local MAX_IDS = 4096
local MAX_REFS = 32
local MAX_ACTIONS = 64
local MAX_ID = 16777215
local MAX_VAR_ROUNDS = 8

local P1, P2 = 4294967291, 4294967279

local function Width(count)
  local bits, capacity = 0, 1

  while capacity < count do
    capacity = capacity * 2
    bits = bits + 1
  end

  return bits
end

local function Chars(value, count)
  local out = {}

  for i = 1, count do
    local digit = value % 64
    out[i] = string.sub(ALPHABET, digit + 1, digit + 1)
    value = (value - digit) / 64
  end

  return table.concat(out)
end

local function Digest(text)
  local h1, h2 = 0, 0

  for i = 1, #(text) do
    local byte = string.byte(text, i)
    h1 = (h1 * 131 + byte + 1) % P1
    h2 = (h2 * 137 + byte + 7) % P2
  end

  return h1, h2
end

local function Checksum(body)
  local h1 = Digest(body)

  return Chars(h1 % 262144, 3)
end

Core.routeCodeChecksum = Checksum

function Core.codeHash(code)
  if type(code) ~= "string" or code == "" then
    return nil
  end

  local h1, h2 = Digest(code)

  return Chars(h1, 6) .. Chars(h2, 6)
end

function Core.sanitizeRouteHash(value)
  if type(value) ~= "string" or #(value) ~= Core.ROUTE_HASH_LENGTH
      or string.find(value, "[^a-zA-Z0-9()]") then
    return nil
  end

  return value
end

local function HashPart(a, b, c, d, e, f)
  a, b, c, d, e, f = BYTE_DIGIT[a], BYTE_DIGIT[b], BYTE_DIGIT[c], BYTE_DIGIT[d], BYTE_DIGIT[e], BYTE_DIGIT[f]

  if not (a and b and c and d and e and f) then
    return nil
  end

  return a + 64 * (b + 64 * (c + 64 * (d + 64 * (e + 64 * f))))
end

function Core.routeHashParts(hash)
  if type(hash) ~= "string" or #(hash) ~= Core.ROUTE_HASH_LENGTH then
    return nil
  end

  local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12 = string.byte(hash, 1, 12)
  local first, second = HashPart(b1, b2, b3, b4, b5, b6), HashPart(b7, b8, b9, b10, b11, b12)

  if not first or not second then
    return nil
  end

  return first, second
end

local function Writer()
  local chars, acc, bits, scale = {}, 0, 0, 1
  local writer = {}

  function writer.put(value, count)
    value = math.floor(tonumber(value) or 0)

    for _ = 1, count do
      local bit = value % 2
      value = (value - bit) / 2
      acc = acc + bit * scale
      scale = scale * 2
      bits = bits + 1

      if bits == 6 then
        chars[#(chars) + 1] = string.sub(ALPHABET, acc + 1, acc + 1)
        acc, bits, scale = 0, 0, 1
      end
    end
  end

  function writer.var(value, group)
    value = math.floor(tonumber(value) or 0)

    if value < 0 then
      value = 0
    end

    local base = 2 ^ group

    repeat
      local part = value % base
      value = (value - part) / base
      writer.put(part, group)
      writer.put(value > 0 and 1 or 0, 1)
    until value <= 0
  end

  function writer.bytes(text, limit, group)
    text = tostring(text or "")

    if #(text) > limit then
      Report("ROUTECODE.TEXT_TRUNCATED", { bytes = #(text), limit = limit })
      text = string.sub(text, 1, limit)
    end

    writer.var(#(text), group)

    for i = 1, #(text) do
      writer.put(string.byte(text, i), 8)
    end
  end

  function writer.finish()
    if bits > 0 then
      chars[#(chars) + 1] = string.sub(ALPHABET, acc + 1, acc + 1)
    end

    return table.concat(chars)
  end

  return writer
end

local function Reader(body)
  local position, acc, left = 1, 0, 0
  local reader = {}

  function reader.get(count)
    local value, scale = 0, 1

    for _ = 1, count do
      if left == 0 then
        local digit = DIGIT[string.sub(body, position, position)]

        if not digit then
          error({ reason = "truncated" })
        end

        acc, left = digit, 6
        position = position + 1
      end

      local bit = acc % 2
      acc = math.floor(acc / 2)
      left = left - 1
      value = value + bit * scale
      scale = scale * 2
    end

    return value
  end

  function reader.var(group, limit)
    local value, scale, rounds = 0, 1, 0
    local base = math.floor(2 ^ group)

    repeat
      value = value + reader.get(group) * scale
      scale = scale * base
      rounds = rounds + 1

      if rounds > MAX_VAR_ROUNDS then
        error({ reason = "overlong" })
      end
    until reader.get(1) == 0

    if limit and value > limit then
      error({ reason = "out_of_range" })
    end

    return value
  end

  function reader.bytes(limit, group)
    local length = reader.var(group, limit)
    local out = {}

    for i = 1, length do
      out[i] = string.char(reader.get(8))
    end

    return table.concat(out)
  end

  function reader.index(count, limit)
    local width = Width(count)
    local value = reader.get(width)

    if value >= math.max(count, 1) then
      error({ reason = "bad_index" })
    end

    return value
  end

  return reader
end

local function StepKind(step)
  if step.kind == "travel" then
    return 0
  end

  if step.kind == "npc" then
    return 1
  end

  return step.on and 2 or 3
end

local function HasSpot(step)
  return type(step.map) == "string" and step.map ~= "" and step.x ~= nil and step.y ~= nil
end

local function CollectRouteTables(steps)
  local quests, questIndex, npcs, npcIndex, maps, mapIndex = {}, {}, {}, {}, {}, {}
  local extraMaps, extraCount = {}, 0

  local function AddQuest(id)
    id = tonumber(id)

    if id and id > MAX_ID then
      Report("ROUTECODE.ID_OUT_OF_RANGE", { value = id, limit = MAX_ID })
    elseif id and id > 0 and not questIndex[id] then
      questIndex[id] = true
      quests[#(quests) + 1] = id
    end
  end

  for _, step in ipairs(steps) do
    if step.kind == "npc" and step.npcId and step.npcId > MAX_ID then
      Report("ROUTECODE.ID_OUT_OF_RANGE", { value = step.npcId, limit = MAX_ID })
    elseif step.kind == "npc" and step.npcId and not npcIndex[step.npcId] then
      npcIndex[step.npcId] = true
      npcs[#(npcs) + 1] = step.npcId
    end

    if step.kind == "quest" then
      AddQuest(step.questId)
    end

    for _, ref in ipairs(step.active or {}) do
      AddQuest(ref.questId)
    end

    for _, action in ipairs(step.actions or {}) do
      if QUEST_ACTIONS[action.kind] then
        AddQuest(action.questId)
      end
    end

    if step.kind ~= "travel" and HasSpot(step) and not mapIndex[step.map] then
      if #(maps) < MAX_MAPS then
        maps[#(maps) + 1] = step.map
        mapIndex[step.map] = #(maps) - 1
      elseif not extraMaps[step.map] then
        extraMaps[step.map] = true
        extraCount = extraCount + 1
      end
    end
  end

  if extraCount > 0 then
    Report("ROUTECODE.MAPS_TRUNCATED", { maps = #(maps) + extraCount, limit = MAX_MAPS })
  end

  table.sort(quests)
  table.sort(npcs)

  for i, id in ipairs(quests) do
    questIndex[id] = i - 1
  end

  for i, id in ipairs(npcs) do
    npcIndex[id] = i - 1
  end

  return { quests = quests, questIndex = questIndex, npcs = npcs, npcIndex = npcIndex, maps = maps, mapIndex = mapIndex }
end

local function WriteRouteHeader(w, route, tables)
  w.var(tonumber(route.category) - 1, 3)
  w.var(Core.sanitizeDifficulty(route.difficulty) or 0, 3)
  w.bytes(Core.sanitizeSelectionName(route.name, ""), MAX_NAME_BYTES, 5)
  w.var(#(tables.maps), 3)

  for _, map in ipairs(tables.maps) do
    w.bytes(map, MAX_MAP_BYTES, 4)
  end

  w.var(#(tables.quests), 5)

  local previous = 0

  for _, id in ipairs(tables.quests) do
    w.var(id - previous, 7)
    previous = id
  end

  w.var(#(tables.npcs), 5)
  previous = 0

  for _, id in ipairs(tables.npcs) do
    w.var(id - previous, 7)
    previous = id
  end
end

local function WriteSpot(w, step, tables, widths, last)
  local spot = HasSpot(step) and tables.mapIndex[step.map] ~= nil
  local x = spot and math.floor(step.x * XY_MAX + 0.5) or 0
  local y = spot and math.floor(step.y * XY_MAX + 0.5) or 0
  local same = spot and last and last.map == step.map and last.x == x and last.y == y

  w.put(same and 1 or 0, 1)

  if same then
    return last
  end

  w.put(spot and 1 or 0, 1)

  if not spot then
    return last
  end

  w.put(tables.mapIndex[step.map], widths.map)
  w.put(x, XY_BITS)
  w.put(y, XY_BITS)

  return { map = step.map, x = x, y = y }
end

local function WriteActions(w, step, PutQuest)
  local actions = step.actions or {}

  if #(actions) > MAX_ACTIONS then
    Report("ROUTECODE.ACTIONS_TRUNCATED", { actions = #(actions), limit = MAX_ACTIONS })
  end

  w.var(math.min(#(actions), MAX_ACTIONS), 3)

  for i = 1, math.min(#(actions), MAX_ACTIONS) do
    local action = actions[i]

    w.put(ACTION_INDEX[action.kind], 3)

    if INDEXED_ACTIONS[action.kind] then
      w.var((tonumber(action.index) or 1) - 1, 2)
    elseif action.kind == "turnin" then
      w.var(tonumber(action.reward) or 0, 2)
    end

    if QUEST_ACTIONS[action.kind] then
      PutQuest(action.questId)
    end
  end
end

local function WriteStep(w, step, tables, widths, PutQuest, last)
  local kind = StepKind(step)
  local tier = Core.sanitizeDifficulty(step.difficulty)

  w.put(kind, 2)
  w.put(step.resting and 1 or 0, 1)
  w.put(tier and 1 or 0, 1)

  if tier then
    w.var(tier - 1, 3)
  end

  if kind ~= 0 then
    last = WriteSpot(w, step, tables, widths, last)
  end

  if kind == 0 then
    w.var(step.checkpoint, 5)
  elseif kind == 1 then
    local npc = step.npcId and tables.npcIndex[step.npcId]
    local active = step.active or {}

    w.put(npc and 1 or 0, 1)

    if npc then
      w.put(npc, widths.npc)
    end

    local refs = math.max(#(active), #(step.available or {}))

    if refs > MAX_REFS then
      Report("ROUTECODE.REFS_TRUNCATED", { refs = refs, limit = MAX_REFS })
    end

    w.var(math.min(#(active), MAX_REFS), 2)

    for i = 1, math.min(#(active), MAX_REFS) do
      PutQuest(active[i].questId)
    end

    w.var(math.min(#(step.available or {}), MAX_REFS), 2)
  else
    if kind == 2 then
      w.put(CHANGE_INDEX[step.on], 2)
    end

    PutQuest(step.questId)
  end

  WriteActions(w, step, PutQuest)

  return last
end

function Core.encodeRoute(route, stored)
  if type(route) ~= "table" or not Core.isRouteCategory(route.category) then
    return nil, Problem("ROUTECODE.CATEGORY_INVALID", { category = tostring(type(route) == "table" and route.category) })
  end

  local steps = stored and type(route.steps) == "table" and route.steps or Core.copyRouteSteps(route.steps)
  local tables = CollectRouteTables(steps)
  local w = Writer()
  local widths = { map = Width(#(tables.maps)), quest = Width(#(tables.quests)), npc = Width(#(tables.npcs)) }

  local function PutQuest(id)
    id = tonumber(id)
    local index = id and tables.questIndex[id]

    w.put(index and 1 or 0, 1)

    if index then
      w.put(index, widths.quest)
    end
  end

  WriteRouteHeader(w, route, tables)
  w.var(#(steps), 6)

  local last

  for _, step in ipairs(steps) do
    last = WriteStep(w, step, tables, widths, PutQuest, last)
  end

  local body = w.finish()

  return PREFIX .. body .. Checksum(body)
end

local function ReadRouteHeader(r, route)
  route.category = r.var(3, Core.routeCategoryCount() - 1) + 1
  local difficulty = r.var(3, 255)
  route.difficulty = difficulty ~= 0 and Core.sanitizeDifficulty(difficulty) or nil
  route.name = r.bytes(MAX_NAME_BYTES, 5)

  local maps = {}

  for i = 1, r.var(3, MAX_MAPS) do
    maps[i] = r.bytes(MAX_MAP_BYTES, 4)
  end

  local quests, npcs, previous = {}, {}, 0

  for i = 1, r.var(5, MAX_IDS) do
    previous = previous + r.var(7, MAX_ID)
    quests[i] = previous
  end

  previous = 0

  for i = 1, r.var(5, MAX_IDS) do
    previous = previous + r.var(7, MAX_ID)
    npcs[i] = previous
  end

  return { maps = maps, quests = quests, npcs = npcs }
end

local function ReadSpot(r, step, maps, last)
  if r.get(1) == 1 then
    if not last then
      error({ reason = "no_previous_spot" })
    end

    step.map, step.x, step.y = last.map, last.x, last.y

    return last
  end

  if r.get(1) == 0 then
    return last
  end

  step.map = maps[r.index(#(maps)) + 1]
  step.x = r.get(XY_BITS) / XY_MAX
  step.y = r.get(XY_BITS) / XY_MAX

  return { map = step.map, x = step.x, y = step.y }
end

local function ReadActions(r, step, GetQuest)
  for i = 1, r.var(3, MAX_ACTIONS) do
    local actionKind = ACTION_KINDS[r.get(3) + 1]

    if not actionKind then
      error({ reason = "bad_action" })
    end

    local action = { kind = actionKind }

    if INDEXED_ACTIONS[actionKind] then
      action.index = r.var(2, 255) + 1
    elseif actionKind == "turnin" then
      action.reward = r.var(2, 255)
    end

    if QUEST_ACTIONS[actionKind] then
      action.questId = GetQuest()
    end

    step.actions[i] = action
  end
end

local function ReadStep(r, tables, GetQuest, last)
  local kind = r.get(2)
  local step = { resting = r.get(1) == 1, actions = {} }

  if r.get(1) == 1 then
    step.difficulty = r.var(3, 255) + 1
  end

  if kind ~= 0 then
    last = ReadSpot(r, step, tables.maps, last)
  end

  if kind == 0 then
    step.kind = "travel"
    step.checkpoint = r.var(5, MAX_ID)
  elseif kind == 1 then
    step.kind = "npc"
    step.npcName = ""

    if r.get(1) == 1 then
      step.npcId = tables.npcs[r.index(#(tables.npcs)) + 1]
    end

    step.active = {}

    for i = 1, r.var(2, MAX_REFS) do
      step.active[i] = { questId = GetQuest() }
    end

    step.available = {}

    for i = 1, r.var(2, MAX_REFS) do
      step.available[i] = {}
    end
  else
    step.kind = "quest"

    if kind == 2 then
      step.on = CHANGES[r.get(2) + 1]
    end

    step.questId = GetQuest()
  end

  ReadActions(r, step, GetQuest)

  return step, last
end

local function DecodeBody(body)
  local r = Reader(body)
  local route = { steps = {} }
  local tables = ReadRouteHeader(r, route)

  local function GetQuest()
    if r.get(1) == 0 then
      return nil
    end

    return tables.quests[r.index(#(tables.quests)) + 1]
  end

  local last

  for s = 1, r.var(6, Core.MAX_ROUTE_STEPS) do
    route.steps[s], last = ReadStep(r, tables, GetQuest, last)
  end

  local read = #(route.steps)

  route.steps = Core.copyRouteSteps(route.steps)

  if #(route.steps) < read then
    Report("ROUTECODE.STEPS_DROPPED", { read = read, kept = #(route.steps) })
  end

  return route
end

function Core.decodeRoute(code)
  if type(code) ~= "string" then
    return nil, Problem("ROUTECODE.NOT_TEXT", { type = type(code) })
  end

  code = string.gsub(code, "%s", "")

  local length = #(code)

  if length == 0 then
    return nil, Problem("ROUTECODE.NOT_TEXT", { type = "empty" })
  end

  if string.sub(code, 1, #(PREFIX)) ~= PREFIX then
    if length < #(PREFIX) and string.sub(PREFIX, 1, length) == code then
      return nil, Problem("ROUTECODE.TRUNCATED", { length = length })
    end

    return nil, Problem("ROUTECODE.PREFIX", { prefix = string.sub(code, 1, #(PREFIX)), length = length })
  end

  if length < #(PREFIX) + 4 then
    return nil, Problem("ROUTECODE.TRUNCATED", { length = length })
  end

  local body = string.sub(code, #(PREFIX) + 1, -4)

  if Checksum(body) ~= string.sub(code, -3) then
    return nil, Problem("ROUTECODE.CHECKSUM", { length = length })
  end

  local ok, route = pcall(DecodeBody, body)

  if not ok then
    if type(route) == "table" and route.reason == "truncated" then
      return nil, Problem("ROUTECODE.TRUNCATED", { length = length })
    end

    if type(route) == "table" then
      return nil, Problem("ROUTECODE.CORRUPT", { reason = tostring(route.reason), length = length })
    end

    local problem = Problem("ROUTECODE.DECODE_BUG", { message = tostring(route), length = length })
    RT.api:Report(problem)

    return nil, problem
  end

  if type(route) ~= "table" then
    local problem = Problem("ROUTECODE.DECODE_BUG", { message = "result is " .. type(route), length = length })
    RT.api:Report(problem)

    return nil, problem
  end

  return route
end

local hashCache = setmetatable({}, { __mode = "k" })

function Core.routeHash(route)
  if type(route) ~= "table" then
    return nil
  end

  local cached = hashCache[route]

  if cached and cached.name == route.name and cached.category == route.category
      and cached.difficulty == route.difficulty and cached.steps == route.steps then
    return cached.hash
  end

  local hash = Core.codeHash(Core.encodeRoute(route, true))

  hashCache[route] = {
    hash = hash,
    name = route.name,
    category = route.category,
    difficulty = route.difficulty,
    steps = route.steps,
  }

  return hash
end

function Core.inheritRouteHash(source, copy)
  local cached = hashCache[source]

  if not cached or cached.name ~= source.name or cached.category ~= source.category
      or cached.difficulty ~= source.difficulty or cached.steps ~= source.steps then
    return false
  end

  if copy.name ~= source.name or copy.category ~= source.category
      or copy.difficulty ~= source.difficulty then
    return false
  end

  hashCache[copy] = {
    hash = cached.hash,
    name = copy.name,
    category = copy.category,
    difficulty = copy.difficulty,
    steps = copy.steps,
  }

  return true
end

function Core.isRouteShared(route)
  return type(route) == "table" and route.shared == true
end

function Core.setRouteShared(profile, id, shared)
  local route = Core.findRoute(profile, id)

  if not route then
    Report("ROUTECODE.SHARE_NO_ROUTE", { route = tostring(id) })

    return Core.copyAccountProfile(profile), false
  end

  if shared and not Core.routeHash(route) then
    local _, cause = Core.encodeRoute(route, true)
    Report("ROUTECODE.SHARE_NO_CODE", { title = tostring(route.name or "") }, cause)

    return Core.copyAccountProfile(profile), false
  end

  if shared then
    return Core.routeContainer.update(profile, id, { shared = true })
  end

  return Core.routeContainer.update(profile, id, { shared = Core.CLEARED, sharedHash = Core.CLEARED })
end

function Core.routeNeedsAnnounce(route)
  return Core.isRouteShared(route) and route.sharedHash ~= Core.routeHash(route)
end

function Core.findRouteByHash(profile, hash, hint)
  for _, route in ipairs(type(profile) == "table" and profile.savedRoutes or {}) do
    if (not hint or (route.category == hint.category and Core.routeStepCount(route) == hint.steps))
        and Core.routeHash(route) == hash then
      return route
    end
  end

  return nil
end
