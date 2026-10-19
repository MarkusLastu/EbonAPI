EbonAPI = EbonAPI or {}
EbonAPI.State = {}

local State = EbonAPI.State
local Lib = EbonAPI.Lib
local Bridge = EbonAPI.Bridge
local SS = EbonAPI.SS
local Handle = EbonAPI.Handle
local L = EbonAPI.L
local Problems = EbonAPI.Problems

local type, tonumber, pairs, next = type, tonumber, pairs, next
local match, gmatch, format, upper, sub = string.match, string.gmatch, string.format, string.upper, string.sub
local max = math.max

State.MAX_ASH = "18446744073709551615"

local MAX_ASH = State.MAX_ASH
local MAX_ASH_DIGITS = #MAX_ASH

local function readAsh(text)
  local digits = match(text, "^0*(%d+)$")

  if not digits then
    return nil
  end

  local length = #digits

  if length > MAX_ASH_DIGITS or (length == MAX_ASH_DIGITS and digits > MAX_ASH) then
    return nil
  end

  return tonumber(digits)
end

State.RUN_FIELDS = {
  "soulPoints",
  "soulPointsMax",
  "acceptedRezs",
  "acceptedRezsMax",
  "selfRezs",
  "selfRezsMax",
  "classRezs",
  "classRezsMax",
  "avoidedFatalAttacks",
  "avoidedFatalAttacksMax",
  "nbResetAvoided",
  "costNextReset",
  "usedRerolls",
  "totalRerolls",
  "remainingBanishes",
  "catchupMultiplierPct",
  "usedFreezes",
  "totalFreezes",
  "hasReachedMaxLevel",
}

State.RUN_FIELDS_REQUIRED = 14

local RUN_FIELDS = State.RUN_FIELDS

local run = nil
local intensity = nil
local ash = nil
local multiplier = 0
local builds = nil
local loadout = nil

local runFields = {}
local intensityFields = {}
local publishedRun = {}
local publishedIntensity = {}

local DERIVED = {
  { "countCanAcceptedRezs", "acceptedRezsMax", "acceptedRezs" },
  { "countCanSelfRezs", "selfRezsMax", "selfRezs" },
  { "countCanClassRezs", "classRezsMax", "classRezs" },
  { "countCanAvoidFatalAttacks", "avoidedFatalAttacksMax", "avoidedFatalAttacks" },
  { "remainingRerolls", "totalRerolls", "usedRerolls" },
  { "remainingFreezes", "totalFreezes", "usedFreezes" },
}

State.rejected = 0

local function reject(opcode, reason, field, body)
  State.rejected = State.rejected + 1

  Problems.reject("EbonAPI", "SERVER.BODY_REJECTED", {
    opcode = opcode, reason = reason, field = field,
    sample = type(body) == "string" and sub(body, 1, 60) or type(body),
  })
end

local function derive(data)
  for index = 1, #DERIVED do
    local entry = DERIVED[index]

    if data[entry[1]] == nil then
      data[entry[1]] = max(0, Lib.num(data[entry[2]]) - Lib.num(data[entry[3]]))
    end
  end
end

function State.parseRun(body)
  local fields, count = Lib.split(body, ";", runFields)

  if count < State.RUN_FIELDS_REQUIRED then
    reject(SS.PLAYER_RUN_DATA, "too_few_fields", "fields", body)
    return nil
  end

  if tonumber(fields[1]) == nil then
    reject(SS.PLAYER_RUN_DATA, "not_a_number", RUN_FIELDS[1], body)
    return nil
  end

  local data = {}

  for index = 1, #RUN_FIELDS do
    data[RUN_FIELDS[index]] = tonumber(fields[index]) or 0
  end

  if count < 15 then
    data.remainingBanishes = 1
  end

  data.hasReachedMaxLevel = data.hasReachedMaxLevel == 1
  data.fieldCount = count

  derive(data)

  return data
end

function State.parseIntensity(body)
  local fields, count = Lib.split(body, ";", intensityFields)

  if count < 2 then
    reject(SS.PLAYER_INTENSITY_POINTS, "too_few_fields", "fields", body)
    return nil
  end

  if tonumber(fields[1]) == nil then
    reject(SS.PLAYER_INTENSITY_POINTS, "not_a_number", "intensity", body)
    return nil
  end

  local data = {}

  data.intensity = tonumber(fields[1])
  data.areaName = fields[2]
  data.onCooldown = fields[3] == "1"

  return data
end

function State.parseBank(body)
  if type(body) ~= "string" then
    reject(SS.COMMITTED_SOUL_POINTS, "not_a_string", "body", body)
    return nil
  end

  local spendable, committed = match(body, "^(%d+),(%d+)")

  if not spendable then
    reject(SS.COMMITTED_SOUL_POINTS, "bad_format", "spendable,committed", body)
    return nil
  end

  spendable, committed = readAsh(spendable), readAsh(committed)

  if not (spendable and committed) then
    reject(SS.COMMITTED_SOUL_POINTS, "out_of_range", "spendable,committed", body)
    return nil
  end

  return spendable, committed
end

local function setAsh(spendable, committed, source)
  if spendable == nil then
    return nil, false
  end

  local changed = ash == nil or ash.spendable ~= spendable or ash.committed ~= committed

  ash = ash or {}
  ash.spendable = spendable
  ash.committed = committed
  ash.source = source
  ash.at = (GetTime and GetTime()) or 0

  return ash, changed
end

function State.parseBuildList(body)
  if type(body) ~= "string" then
    reject(SS.BUILD_LIST, "not_a_string", "body", body)
    return nil
  end

  local parsed = { slots = {}, prices = {} }
  local first = true

  for chunk in gmatch(body, "[^;]+") do
    if first then
      local active, maxSlots, unlocked, prices = match(chunk, "^(%d+)|(%d+)|(%d+)|(.*)$")

      if not active then
        reject(SS.BUILD_LIST, "bad_format", "header", body)
        return nil
      end

      parsed.active = tonumber(active)
      parsed.maxSlots = tonumber(maxSlots)
      parsed.unlocked = tonumber(unlocked)

      for price in gmatch(prices, "[^%.]+") do
        parsed.prices[#parsed.prices + 1] = tonumber(price) or 0
      end

      first = false
    else
      local slot, name, echoes = match(chunk, "^(%d+)|([^|]*)|[^|]*|[^|]*|(.*)$")

      if not slot then
        slot, name = match(chunk, "^(%d+)|([^|]*)|")
        echoes = ""
      end

      if slot then
        parsed.slots[tonumber(slot)] = { slot = tonumber(slot), name = name, echoes = echoes }
      end
    end
  end

  if first then
    reject(SS.BUILD_LIST, "empty", "header", body)
    return nil
  end

  return parsed
end

function State.BuildEchoes(build)
  if type(build) ~= "table" then
    return nil
  end

  local list = build.list

  if list then
    return list
  end

  list = {}

  for entry in gmatch(build.echoes or "", "[^,]+") do
    local id, stacks, locked = match(entry, "^(%d+)%.(%d+)%.(%d+)$")

    if id then
      list[#list + 1] = { spellId = tonumber(id), stacks = tonumber(stacks), locked = locked == "1" }
    end
  end

  build.list = list

  return list
end

function State.sortedBuilds()
  local sorted = {}

  if not builds or type(builds.slots) ~= "table" then
    return sorted
  end

  for slot, build in pairs(builds.slots) do
    if type(build) == "table" and tonumber(slot) then
      sorted[#sorted + 1] = build
    end
  end

  table.sort(sorted, function(a, b)
    return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0)
  end)

  return sorted
end

function State.activeBuild()
  local slot = builds and tonumber(builds.active)

  if not slot or not builds or type(builds.slots) ~= "table" then
    return nil, slot
  end

  return builds.slots[slot], slot
end

function State.parseLoadouts(body)
  if type(body) ~= "string" then
    reject(SS.SEND_LOADOUTS, "not_a_string", "body", body)
    return nil
  end

  local globalPart, loadoutsPart = match(body, "^([^_]+)_?(.*)$")

  if not globalPart then
    reject(SS.SEND_LOADOUTS, "bad_format", "global", body)
    return nil
  end

  local result = { nodes = {}, count = 0 }
  local selectedId = tonumber(match(globalPart, "^(%d+),"))

  local spendable, committed = match(globalPart, "^%d+,(%d+),(%d+),?%d*$")

  if spendable then
    spendable, committed = readAsh(spendable), readAsh(committed)

    if spendable and committed then
      result.spendable = spendable
      result.committed = committed
    else
      reject(SS.SEND_LOADOUTS, "out_of_range", "spendable,committed", body)
    end
  end

  if not loadoutsPart or loadoutsPart == "" then
    return result
  end

  local exact, fallback

  for loadoutString in gmatch(loadoutsPart, "([^;]+)") do
    local parts = {}

    for part in gmatch(loadoutString, "([^,]+)") do
      parts[#parts + 1] = part
    end

    if #parts >= 3 then
      local id = tonumber(parts[1])

      if id then
        result.count = result.count + 1

        if selectedId and id == selectedId then
          exact = exact or parts
        elseif id == 0 and not fallback then
          fallback = parts
        end
      end
    end
  end

  local chosen = exact or fallback

  if not chosen then
    return result
  end

  local name = chosen[2]

  if type(name) ~= "string" or name == "" or match(name, "|") then
    reject(SS.SEND_LOADOUTS, "bad_name", "name", body)
    return result
  end

  result.id = tonumber(chosen[1])
  result.name = name

  for index = 4, #chosen do
    local nodeId, rank = match(chosen[index], "^(%d+):(%d+)$")

    nodeId = tonumber(nodeId)
    rank = tonumber(rank)

    if nodeId and rank and rank > 0 then
      result.nodes[nodeId] = rank
    end
  end

  return result
end

local function fromPublished(source)
  for key in pairs(publishedRun) do
    publishedRun[key] = nil
  end

  for key, value in pairs(source) do
    publishedRun[key] = value
  end

  derive(publishedRun)

  return publishedRun
end

function State.GetRun()
  if run then
    return run
  end

  local published = EbonAPI.Ebonhold.PublishedRunData()

  if published then
    return fromPublished(published)
  end

  local service = EbonAPI.Ebonhold.PlayerRun()

  if service and type(service.GetCurrentData) == "function" then
    local data = Lib.safeGet(service.GetCurrentData)

    if type(data) == "table" and next(data) ~= nil then
      return fromPublished(data)
    end
  end

  return nil
end

function State.GetIntensity()
  if intensity then
    return intensity
  end

  local published = EbonAPI.Ebonhold.PublishedIntensity()

  if published then
    publishedIntensity.intensity = Lib.num(published.intensity)
    publishedIntensity.areaName = published.areaNameReaper
    publishedIntensity.onCooldown = Lib.bool(published.onCooldown)

    return publishedIntensity
  end

  return nil
end

function State.GetAsh()
  return ash
end

function State.GetMultiplier()
  return multiplier
end

function State.GetBuilds()
  return builds
end

function State.GetLoadout()
  return loadout
end

function State.RunAshes()
  local data = State.GetRun()

  if not data then
    return nil
  end

  return Lib.int(data.soulPoints), Lib.int(data.soulPointsMax)
end

function State.snapshot(name)
  if name == "run" then return Lib.copyDeep(State.GetRun()) end
  if name == "intensity" then return Lib.copyDeep(State.GetIntensity()) end
  if name == "ash" then return Lib.copyDeep(ash) end
  if name == "builds" then return Lib.copyDeep(builds) end
  if name == "loadout" then return Lib.copyDeep(loadout) end

  return nil
end

function State.HasServer()
  return EbonAPI.Ebonhold.IsPresent() or Bridge.seen
end

local function onRunData(body)
  local data = State.parseRun(body)

  if not data then
    return
  end

  run = data
  EbonAPI:Emit("SERVER_RUN_DATA", Lib.copyDeep(data))
end

local function onIntensity(body)
  local data = State.parseIntensity(body)

  if not data then
    return
  end

  intensity = data
  EbonAPI:Emit("SERVER_INTENSITY", Lib.copyDeep(data))
end

local function onBank(body)
  if body == "" then
    return
  end

  local spendable, committed = State.parseBank(body)

  if not spendable then
    return
  end

  local held, changed = setAsh(spendable, committed, SS.COMMITTED_SOUL_POINTS)

  if changed then
    EbonAPI:Emit("SERVER_ASH", Lib.copyDeep(held))
  end
end

local function onMultiplier(body)
  if body == "" then
    return
  end

  local value = tonumber(body)

  if not value then
    reject(SS.SOUL_POINTS_MULTIPLIER, "not_a_number", "multiplier", body)
    return
  end

  multiplier = value
  EbonAPI:Emit("SERVER_MULTIPLIER", multiplier)
end

local function onBuildList(body)
  local parsed = State.parseBuildList(body)

  if not parsed then
    return
  end

  builds = parsed
  EbonAPI:Emit("SERVER_BUILDS", builds)
end

local function onBuildActive(body)
  local slot = tonumber(match(tostring(body), "^(%d+)"))

  if not slot or not builds then
    return
  end

  if not builds.slots[slot] then
    reject(SS.BUILD_ACTIVE, "unknown_slot", "slot", body)
    return
  end

  builds = Lib.copyDeep(builds)
  builds.active = slot
  EbonAPI:Emit("SERVER_BUILD_ACTIVE", slot, builds)
end

local function onLoadouts(body)
  local parsed = State.parseLoadouts(body)

  if not parsed then
    return
  end

  loadout = parsed

  if parsed.spendable then
    local held, changed = setAsh(parsed.spendable, parsed.committed, SS.SEND_LOADOUTS)

    if changed then
      EbonAPI:Emit("SERVER_ASH", Lib.copyDeep(held))
    end
  end

  EbonAPI:Emit("SERVER_LOADOUT", loadout)
end

Problems.declare("EbonAPI", "EBONAPI", {
  ["SERVER.BUILD_REFUSED"] = { class = "refus", key = "reason" },
  ["SERVER.TREE_REFUSED"] = { class = "echec" },
  ["SERVER.PICK_REFUSED"] = { class = "echec" },
  ["SERVER.FREEZE_REFUSED"] = { class = "echec" },
  ["SERVER.RESET_REFUSED"] = { class = "refus", key = "code" },
  ["SERVER.PRESTIGE_REFUSED"] = { class = "refus", key = "reason" },
  ["SERVER.BODY_REJECTED"] = { class = "rejet" },
})

local BUILD_REASONS = {
  disabled = "DISABLED", slot = "SLOT", empty = "EMPTY", level = "LEVEL", combat = "COMBAT", dead = "DEAD",
  rolls = "ROLLS", locked = "LOCKED", max = "MAX", money = "MONEY", designed = "DESIGNED", invalid = "INVALID",
  full = "FULL", norecover = "NORECOVER", occupied = "OCCUPIED", overbudget = "OVERBUDGET",
  recoverable = "RECOVERABLE",
}

local BUILD_VARIANT = { empty = "save", level = "save", full = "recover", overbudget = "recover" }

local PRESTIGE_REASONS = { gate = "GATE", combat = "COMBAT", dead = "DEAD" }

local function why(prefix, suffix, reason)
  local text = suffix and L[prefix .. suffix]

  return text or format(L.PROBLEM_SERVER_REASON_UNKNOWN, reason)
end

local function refuse(code, facts)
  local problem = Problems.new("EbonAPI", code, facts)

  Problems.report(problem)

  return problem
end

local function result(kind, problem)
  EbonAPI:Emit("SERVER_RESULT", kind, problem == nil, problem)
end

local function onBuildAck(body)
  local status, op, reason = match(tostring(body), "^([^,]+),([^,]+),(.*)$")

  if status == "OK" then
    result("build")
  elseif status == "FAIL" then
    local suffix = BUILD_REASONS[reason]

    if suffix and BUILD_VARIANT[reason] == op then
      suffix = suffix .. "_" .. upper(op)
    end

    result("build", refuse("SERVER.BUILD_REFUSED", {
      op = op, reason = reason, why = why("PROBLEM_SERVER_BUILD_REFUSED_", suffix, reason),
    }))
  else
    reject(SS.BUILD_ACK, "bad_status", "status", body)
  end
end

local function flagResult(body, name, opcode, code)
  local flag = match(tostring(body), "^([01])$")

  if flag == "1" then
    result(name)
  elseif flag == "0" then
    result(name, refuse(code))
  else
    reject(opcode, "bad_flag", "flag", body)
  end
end

local function onTreeResult(body)
  flagResult(body, "tree", SS.SKILL_TREE_UPDATE_SPELL_CAST_RESULT, "SERVER.TREE_REFUSED")
end

local function onPickResult(body)
  local count = match(tostring(body), "^(%d+)$")

  if not count then
    reject(SS.PLAYER_PERK_SELECTION_RESULT, "not_a_number", "count", body)
  elseif tonumber(count) > 0 then
    result("pick")
  else
    result("pick", refuse("SERVER.PICK_REFUSED"))
  end
end

local function onFreezeResult(body)
  flagResult(body, "freeze", SS.FREEZE_PERK_RESULT, "SERVER.FREEZE_REFUSED")
end

local function onResetResult(body)
  local code, cost = match(tostring(body), "^(%d+),(%d+)$")

  if not code then
    reject(SS.INSTANCE_RESET_RESULT, "bad_format", "code,cost", body)
    return
  end

  code = tonumber(code)

  if code == 0 then
    result("reset")
    return
  end

  result("reset", refuse("SERVER.RESET_REFUSED", {
    code = code, cost = tonumber(cost),
    why = why("PROBLEM_SERVER_RESET_REFUSED_", code >= 1 and code <= 6 and code or nil, code),
  }))
end

local function onPrestigeResult(body)
  local status, reason = match(tostring(body), "^(%a+),(.*)$")

  if status == "OK" then
    result("prestige")
  elseif status == "FAIL" then
    result("prestige", refuse("SERVER.PRESTIGE_REFUSED", {
      reason = reason, why = why("PROBLEM_SERVER_PRESTIGE_REFUSED_", PRESTIGE_REASONS[reason], reason),
    }))
  else
    reject(SS.PRESTIGE_RESULT, "bad_status", "status", body)
  end
end

local wired = false

function State.enable()
  if wired then
    return false
  end

  wired = true

  Bridge.on(SS.PLAYER_RUN_DATA, onRunData)
  Bridge.on(SS.PLAYER_INTENSITY_POINTS, onIntensity)
  Bridge.on(SS.COMMITTED_SOUL_POINTS, onBank)
  Bridge.on(SS.SOUL_POINTS_MULTIPLIER, onMultiplier)
  Bridge.on(SS.BUILD_LIST, onBuildList)
  Bridge.on(SS.BUILD_ACTIVE, onBuildActive)
  Bridge.on(SS.SEND_LOADOUTS, onLoadouts)
  Bridge.on(SS.BUILD_ACK, onBuildAck)
  Bridge.on(SS.SKILL_TREE_UPDATE_SPELL_CAST_RESULT, onTreeResult)
  Bridge.on(SS.PLAYER_PERK_SELECTION_RESULT, onPickResult)
  Bridge.on(SS.FREEZE_PERK_RESULT, onFreezeResult)
  Bridge.on(SS.INSTANCE_RESET_RESULT, onResetResult)
  Bridge.on(SS.PRESTIGE_RESULT, onPrestigeResult)

  return true
end

function State.disable()
  if not wired then
    return false
  end

  wired = false

  Bridge.off(SS.PLAYER_RUN_DATA, onRunData)
  Bridge.off(SS.PLAYER_INTENSITY_POINTS, onIntensity)
  Bridge.off(SS.COMMITTED_SOUL_POINTS, onBank)
  Bridge.off(SS.SOUL_POINTS_MULTIPLIER, onMultiplier)
  Bridge.off(SS.BUILD_LIST, onBuildList)
  Bridge.off(SS.BUILD_ACTIVE, onBuildActive)
  Bridge.off(SS.SEND_LOADOUTS, onLoadouts)
  Bridge.off(SS.BUILD_ACK, onBuildAck)
  Bridge.off(SS.SKILL_TREE_UPDATE_SPELL_CAST_RESULT, onTreeResult)
  Bridge.off(SS.PLAYER_PERK_SELECTION_RESULT, onPickResult)
  Bridge.off(SS.FREEZE_PERK_RESULT, onFreezeResult)
  Bridge.off(SS.INSTANCE_RESET_RESULT, onResetResult)
  Bridge.off(SS.PRESTIGE_RESULT, onPrestigeResult)

  return true
end

function State.reset()
  run, intensity, ash, builds, loadout = nil, nil, nil, nil, nil
  multiplier = 0

  EbonAPI:ClearSticky("SERVER_RUN_DATA")
  EbonAPI:ClearSticky("SERVER_INTENSITY")
  EbonAPI:ClearSticky("SERVER_ASH")
  EbonAPI:ClearSticky("SERVER_MULTIPLIER")
  EbonAPI:ClearSticky("SERVER_BUILDS")
  EbonAPI:ClearSticky("SERVER_BUILD_ACTIVE")
  EbonAPI:ClearSticky("SERVER_LOADOUT")
end

EbonAPI:DeclareSticky("SERVER_RUN_DATA")
EbonAPI:DeclareSticky("SERVER_INTENSITY")
EbonAPI:DeclareSticky("SERVER_ASH")
EbonAPI:DeclareSticky("SERVER_MULTIPLIER")
EbonAPI:DeclareSticky("SERVER_BUILDS")
EbonAPI:DeclareSticky("SERVER_BUILD_ACTIVE")
EbonAPI:DeclareSticky("SERVER_LOADOUT")

function Handle:State()
  return State
end
