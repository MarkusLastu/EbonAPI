local Core = AutoCallboardCore or {}
AutoCallboardCore = Core
local L = AutoCallboardLocale
local Lib = EbonAPI.Lib

local type, tonumber, tostring, pairs, ipairs = type, tonumber, tostring, pairs, ipairs
local string, table, math = string, table, math

function Core.problem(name, facts, cause)
  local RT = AutoCallboardRuntime

  if not Core.reportReady or not RT or not RT.api then
    return nil
  end

  return RT.api:Problem(name, facts, cause)
end

function Core.report(problem)
  local RT = AutoCallboardRuntime

  if problem and Core.reportReady and RT and RT.api then
    return RT.api:Report(problem)
  end
end

function Core.repaired(name, facts, old)
  local RT = AutoCallboardRuntime

  if not Core.reportReady or not RT or not RT.api then
    return nil
  end

  return RT.api:Repaired(name, facts, old)
end

local DEFAULTS = {
  targetName = "Callboard",
  summonSpell = "Summon Callboard",
  summonSpellID = 600647,
  summonDuration = 30,
  summonCooldown = 45,
  rerollFrame = "ObjectivesMainFrame.rerollBtn",
  objectivePrefix = "ObjectiveFrame",
  objectiveButtonField = "selectBtn",
  autoAccept = true,
  autoCurrentInstanceQuest = false,
  travelEnabled = true,
  travelAuto = false,
  remoteRoll = false,
  showSpeed = false,
  maxRerolls = 50,
  rerollDelay = 0.1,
  rerollTimeout = 1.5,
  knownQuests = {},
  desiredQuests = {},
  characterProfiles = {},
  accountProfile = {},
  routeLibrary = {},
  characterState = {},
  migratedCharacters = {},
  accountListSeeded = false,
  presetsMigrated = false,
  arrowPointUnscaled = true,
  questPanelExpanded = false,
  debug = {
    enabled = false,
    mouseWatch = false,
    sniffer = false,
    maxLog = 120,
  },
  goldTracker = {
    totalSpent = 0,
    trackedQuestCount = 0,
    lastQuestSpent = 0,
  },
  buttonShown = true,
  button = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
  },
  minimap = {
    shown = true,
    angle = 225,
  },
}

local function trim(value)
  if type(value) ~= "string" then
    return ""
  end

  return Lib.trim(value)
end

local function truncateLetters(value, limit)
  if type(value) ~= "string" then
    return ""
  end

  local length = string.len(value)
  local index, letters = 1, 0

  while index <= length do
    if letters >= limit then
      return string.sub(value, 1, index - 1)
    end

    index = index + 1

    while index <= length do
      local byte = string.byte(value, index)

      if byte < 128 or byte > 191 then
        break
      end

      index = index + 1
    end

    letters = letters + 1
  end

  return value
end

Core.truncateLetters = truncateLetters

local function objectiveTextParts(value)
  local text = trim(value)
  local cleanText, zoneOrSort, questType = string.match(text, "^(.-),%s*(%d+)%s*,%s*(%d+)%s*%.?%s*$")

  if cleanText then
    return trim(cleanText), tonumber(zoneOrSort) or 0, tonumber(questType) or 0
  end

  return text, 0, 0
end

local VALID_QUEST_TYPES = { [1] = true, [2] = true, [3] = true, [4] = true }

function Core.sanitizeQuestType(value)
  value = tonumber(value) or 0
  if VALID_QUEST_TYPES[value] then
    return value
  end

  return 0
end

local function containsAny(value, needles)
  for i = 1, #(needles) do
    if string.find(value, needles[i], 1, true) then
      return true
    end
  end

  return false
end

local function stripColorCodes(value)
  if type(value) ~= "string" then
    return ""
  end

  return Lib.stripColor(value)
end

local function normalizeMatchText(value)
  value = stripColorCodes(string.lower(trim(value)))
  value = value:gsub("[^%w]+", " ")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

  return value
end

local function compactMatchText(value)
  return (normalizeMatchText(value):gsub(" ", ""))
end

local function hasEnabledValue(map)
  if type(map) ~= "table" then
    return false
  end

  for _, enabled in pairs(map) do
    if enabled == true then
      return true
    end
  end

  return false
end

Core.trim = trim
Core.stripColorCodes = stripColorCodes
Core.normalizeMatchText = normalizeMatchText
Core.compactMatchText = compactMatchText

local function appendUniqueNormalized(values, seen, value)
  value = normalizeMatchText(value)

  if value == "" or seen[value] then
    return
  end

  seen[value] = true
  table.insert(values, value)
end

Core.appendUniqueNormalized = appendUniqueNormalized

local PROFESSION_HINTS = {
  "bulk order:",
  "crafting materials:",
  "saronite",
  "cobalt bar",
  "titansteel bar",
  "dragon's eye",
  "autumn's glow",
  "monarch topaz",
  "twilight opal",
  "forest emerald",
  "scarlet ruby",
  "sky sapphire",
  "borean leather",
  "heavy borean leather",
  "jormungar scale",
  "frostweave cloth",
  "moonshroud",
  "spellweave",
  "ebonweave",
  "eternal fire",
  "eternal earth",
  "eternal water",
  "eternal air",
  "eternal shadow",
  "eternal life",
  "crystallized fire",
  "crystallized earth",
  "crystallized water",
  "crystallized air",
  "crystallized shadow",
  "crystallized life",
  "pygmy oil",
  "dragonfin filet",
  "snapper extreme",
  "worm meat",
  "rhino meat",
  "shoveltusk flank",
  "chunk o' mammoth",
  "chilled meat",
  "northern spices",
  "glacial salmon",
  "constrictor grass",
}

local RAID_HINTS = {
  "malygos",
  "kelthuzad",
  "kel'thuzad",
  "sartharion",
  "naxxramas",
  "obsidian sanctum",
  "eye of eternity",
  "construct quarter",
}

local DUNGEON_HINTS = {
  "keristrasza",
  "ingvar",
  "king ymiron",
  "prophet tharon'ja",
  "tharon'ja",
  "utgarde pinnacle",
  "drak'tharon keep",
  "the nexus.",
  "the nexus ",
}

local OPEN_WORLD_TITLE_PREFIXES = {
  "a growing menace:",
  "clear the roads",
  "no mercy:",
  "pacify ",
  "sweep and clear:",
  "storm peaks trophy",
}

local ROLL_DELAY_MIN = 0
local ROLL_DELAY_MAX = 5
local ROLL_TIMEOUT_MIN = 0.25
local ROLL_TIMEOUT_MAX = 10

local ROLL_SPEED_PRESETS = {
  turbo = { delay = 0, timeout = 1, label = "turbo" },
  fast = { delay = 0.05, timeout = 1.25, label = "fast" },
  normal = { delay = 0.1, timeout = 1.5, label = "normal" },
  safe = { delay = 0.35, timeout = 2.5, label = "safe" },
}

local ROLL_SPEED_PRESET_ORDER = { "turbo", "fast", "normal", "safe" }

local function clampNumber(value, minimum, maximum)
  value = tonumber(value)

  if not value then
    return nil
  end

  if value < minimum then
    return minimum
  end

  if value > maximum then
    return maximum
  end

  return value
end

function Core.clampRollDelay(value)
  return clampNumber(value, ROLL_DELAY_MIN, ROLL_DELAY_MAX) or DEFAULTS.rerollDelay
end

function Core.clampRollTimeout(value)
  return clampNumber(value, ROLL_TIMEOUT_MIN, ROLL_TIMEOUT_MAX) or DEFAULTS.rerollTimeout
end

function Core.rollSpeedPresetList()
  local list = {}

  for i = 1, #(ROLL_SPEED_PRESET_ORDER) do
    local key = ROLL_SPEED_PRESET_ORDER[i]
    local preset = ROLL_SPEED_PRESETS[key]

    if preset then
      list[#(list) + 1] = {
        index = #(list) + 1,
        key = key,
        delay = preset.delay,
        timeout = preset.timeout,
        label = preset.label,
      }
    end
  end

  return list
end

function Core.nearestRollSpeedPreset(delay)
  local list = Core.rollSpeedPresetList()
  local target = tonumber(delay)
  local best, bestDiff

  for i = 1, #(list) do
    local diff = math.abs((target or 0) - list[i].delay)

    if not bestDiff or diff < bestDiff then
      best = list[i]
      bestDiff = diff
    end
  end

  return best or list[1]
end

local function copyDefaults()
  return Lib.copyDeep(DEFAULTS)
end

function Core.defaultState()
  return copyDefaults()
end

function Core.autoCurrentInstanceWarningText()
  return L.AUTO_CURRENT_INSTANCE_WARNING
end

local MERGE_NONEMPTY_STRING = { "targetName", "rerollFrame", "objectivePrefix", "objectiveButtonField" }
local MERGE_STRING = { "summonSpell" }
local MERGE_BOOLEAN = {
  "autoAccept", "autoCurrentInstanceQuest", "travelEnabled", "travelAuto", "remoteRoll", "showSpeed",
  "presetsMigrated", "questPanelExpanded", "buttonShown",
  "accountListSeeded",
}
local MERGE_NUMBER_MIN1 = { "summonDuration", "summonCooldown", "maxRerolls" }
local MERGE_COLLECTION = {
  knownQuests = "copyQuestList",
  desiredQuests = "copyDesiredMap",
  characterProfiles = "copyCharacterProfiles",
  accountProfile = "copyAccountProfile",
  routeLibrary = "copyRouteLibrary",
  characterState = "copyCharacterStateMap",
  migratedCharacters = "copyDesiredMap",
}
local GOLD_TRACKER_KEYS = { "totalSpent", "trackedQuestCount", "lastQuestSpent" }

local function mergeNested(saved, state, spec)
  for key, kind in pairs(spec) do
    if kind == "nonEmptyString" then
      if trim(saved[key]) ~= "" then state[key] = trim(saved[key]) end
    elseif kind == "number" then
      if type(saved[key]) == "number" then state[key] = saved[key] end
    elseif kind == "boolean" then
      if type(saved[key]) == "boolean" then state[key] = saved[key] end
    end
  end
end

Core.mergeNested = mergeNested

function Core.mergeState(saved, adopt)
  local state = copyDefaults()

  if type(saved) ~= "table" then
    if saved ~= nil then
      Core.repaired("STATE.REPAIRED", { field = "settings", setting = "settings", value = type(saved) }, saved)
    end

    return state
  end

  for _, key in ipairs(MERGE_NONEMPTY_STRING) do
    if trim(saved[key]) ~= "" then state[key] = trim(saved[key]) end
  end

  for _, key in ipairs(MERGE_STRING) do
    if type(saved[key]) == "string" then state[key] = trim(saved[key]) end
  end

  for _, key in ipairs(MERGE_BOOLEAN) do
    if type(saved[key]) == "boolean" then state[key] = saved[key] end
  end

  for _, key in ipairs(MERGE_NUMBER_MIN1) do
    if type(saved[key]) == "number" and saved[key] >= 1 then state[key] = saved[key] end
  end

  if type(saved.summonSpellID) == "number" then
    state.summonSpellID = saved.summonSpellID
  end

  if type(saved.rerollDelay) == "number" then
    state.rerollDelay = Core.clampRollDelay(saved.rerollDelay)
  end

  if type(saved.rerollTimeout) == "number" then
    state.rerollTimeout = Core.clampRollTimeout(saved.rerollTimeout)
  end

  for key, copier in pairs(MERGE_COLLECTION) do
    if type(saved[key]) == "table" then
      state[key] = adopt and saved[key] or Core[copier](saved[key])
    end
  end

  if type(saved.debug) == "table" then
    mergeNested(saved.debug, state.debug, {
      enabled = "boolean", mouseWatch = "boolean", sniffer = "boolean",
    })

    if type(saved.debug.maxLog) == "number" and saved.debug.maxLog >= 20 then
      state.debug.maxLog = saved.debug.maxLog
    end
  end

  if type(saved.goldTracker) == "table" then
    for _, key in ipairs(GOLD_TRACKER_KEYS) do
      local value = saved.goldTracker[key]
      if type(value) == "number" and value >= 0 then
        state.goldTracker[key] = math.floor(value)
      end
    end
  end

  if type(saved.button) == "table" then
    mergeNested(saved.button, state.button, {
      point = "nonEmptyString", relativePoint = "nonEmptyString", x = "number", y = "number",
    })
  end

  state.appearance = Core.copyAppearance(saved.appearance)
  state.windowPositions = {}
  if type(saved.windowPositions) == "table" then
    for name, point in pairs(saved.windowPositions) do
      if type(name) == "string" and name:match("^AutoCallboard") then
        if type(point) == "table" then
          local copy = {}
          mergeNested(point, copy, {point = "nonEmptyString", relativePoint = "nonEmptyString", x = "number", y = "number"})
          state.windowPositions[name] = copy
        else
          Core.repaired("STATE.REPAIRED", { field = "windowPositions", setting = name, value = type(point) }, point)
        end
      end
    end
  elseif saved.windowPositions ~= nil then
    Core.repaired("STATE.REPAIRED", { field = "windowPositions", setting = "windowPositions", value = type(saved.windowPositions) }, saved.windowPositions)
  end

  local arrowPoint = state.windowPositions.AutoCallboardRouteArrow
  if arrowPoint and saved.arrowPointUnscaled ~= true then
    local factor = state.appearance.arrowScale
    if arrowPoint.x then arrowPoint.x = arrowPoint.x * factor end
    if arrowPoint.y then arrowPoint.y = arrowPoint.y * factor end
  end

  if type(saved.minimap) == "table" then
    mergeNested(saved.minimap, state.minimap, { shown = "boolean", angle = "number" })
  end

  if type(state.accountProfile) ~= "table" or type(state.accountProfile.savedSelections) ~= "table"
      or type(state.accountProfile.groups) ~= "table" then
    state.accountProfile = Core.copyAccountProfile(state.accountProfile)
  end

  return state
end

function Core.adoptState(saved)
  return Core.mergeState(saved, true)
end

function Core.questTitle(quest)
  if type(quest) ~= "table" then
    return ""
  end

  return trim(quest.title)
end

function Core.objectiveText(quest)
  if type(quest) ~= "table" then
    return ""
  end

  local cleanText = objectiveTextParts(quest.objectiveText)
  return cleanText
end

local inferTypeCache = {}
local inferTypeCacheCount = 0
local INFER_TYPE_CACHE_MAX = 512

function Core.inferQuestType(quest)
  if type(quest) ~= "table" then
    return 0
  end

  local title = string.lower(Core.questTitle(quest))
  local objective = string.lower(Core.objectiveText(quest))
  local cacheKey = title .. "\1" .. objective
  local cached = inferTypeCache[cacheKey]

  if cached then
    return cached
  end

  local combined = trim(title .. " " .. objective)
  local questType = 0

  if containsAny(combined, PROFESSION_HINTS) then
    questType = 4
  elseif containsAny(combined, RAID_HINTS) then
    questType = 3
  elseif containsAny(combined, DUNGEON_HINTS) then
    questType = 2
  elseif containsAny(title, OPEN_WORLD_TITLE_PREFIXES)
      or string.find(objective, "^kill%s+%d+")
      or string.find(objective, "^collect%s+%d+%s+rare") then
    questType = 1
  end

  if inferTypeCacheCount >= INFER_TYPE_CACHE_MAX then
    inferTypeCache = {}
    inferTypeCacheCount = 0
  end

  inferTypeCache[cacheKey] = questType
  inferTypeCacheCount = inferTypeCacheCount + 1

  return questType
end

function Core.questKey(quest)
  if type(quest) ~= "table" then
    return nil
  end

  local questID = tonumber(quest.questId or quest.id)
  if questID and questID > 0 then
    return "id:" .. tostring(math.floor(questID))
  end

  local title = Core.questTitle(quest)
  if title == "" then
    return nil
  end

  return "title:" .. title:lower()
end

local QUEST_REWARD_FIELDS = {
  "normalSoulAshes",
  "hc1SoulAshes",
  "hc2SoulAshes",
  "hc3SoulAshes",
  "hc4SoulAshes",
  "normalXp",
  "hc1Xp",
  "hc2Xp",
  "hc3Xp",
  "hc4Xp",
}

Core.questRewardFields = QUEST_REWARD_FIELDS

local indexedList, indexedMap, indexedCount

local function questIndexKey(quest)
  if type(quest) ~= "table" then
    return nil
  end

  if type(quest.key) == "string" and quest.key ~= "" then
    return quest.key
  end

  return Core.questKey(quest)
end

local function knownQuestIndex(quests)
  if type(quests) ~= "table" then
    return nil
  end

  local count = #(quests)

  if indexedList == quests and indexedCount == count then
    return indexedMap
  end

  local map = {}

  for i = 1, count do
    local key = questIndexKey(quests[i])

    if key then
      map[key] = quests[i]
    end
  end

  indexedList = quests
  indexedMap = map
  indexedCount = count

  return map
end

local function noteIndexedQuest(quests, key, quest)
  if indexedList ~= quests then
    return
  end

  indexedMap[key] = quest
  indexedCount = #(quests)
end

local function copyRewardFields(target, source)
  local changed = false

  for i = 1, #(QUEST_REWARD_FIELDS) do
    local field = QUEST_REWARD_FIELDS[i]
    local value = tonumber(source[field]) or 0

    if target[field] ~= value then
      target[field] = value
      changed = true
    end
  end

  return target, changed
end

local function buildQuestEntry(source, key, title, zoneOrSort, questType, seen, lastSeenRoll)
  local entry = copyRewardFields({
    key = key,
    questId = tonumber(source.questId) or 0,
    title = title,
    objectiveText = Core.objectiveText(source),
    zoneOrSort = zoneOrSort,
    questType = questType,
    seen = seen,
    lastSeenRoll = lastSeenRoll,
  }, source)

  return entry
end

function Core.copyQuest(quest)
  if type(quest) ~= "table" then
    return nil
  end

  local zoneOrSort, questType = Core.objectiveMetadata(quest)

  return buildQuestEntry(
    quest,
    quest.key,
    trim(quest.title),
    zoneOrSort,
    questType,
    tonumber(quest.seen) or 1,
    tonumber(quest.lastSeenRoll) or 0)
end

function Core.copyQuestList(quests)
  local copy = {}

  if type(quests) ~= "table" then
    return copy
  end

  local count = 0

  for i = 1, #(quests) do
    local entry = Core.copyQuest(quests[i])
    if entry then
      count = count + 1
      copy[count] = entry
    end
  end

  if count < #(quests) then
    Core.repaired("QUESTS.REPAIRED", { field = "known", value = #(quests), kept = count }, quests)
  end

  return copy
end

function Core.copyDesiredMap(desired)
  local copy = {}

  if type(desired) ~= "table" then
    return copy
  end

  local found, dropped = 0, false

  for key, value in pairs(desired) do
    found = found + 1

    if type(key) == "string" and value == true then
      copy[key] = true
    elseif value ~= false then
      dropped = true
    end
  end

  if dropped then
    local kept = 0

    for _ in pairs(copy) do
      kept = kept + 1
    end

    Core.repaired("QUESTS.REPAIRED", { field = "desired", value = found, kept = kept }, desired)
  end

  return copy
end

function Core.desiredQuestCount(desired)
  local count = 0

  if type(desired) == "table" then
    for _, value in pairs(desired) do
      if value == true then
        count = count + 1
      end
    end
  end

  return count
end

function Core.questMatchesTypeFilter(quest, enabledQuestTypes)
  if not Core.hasEnabledQuestTypeFilter(enabledQuestTypes) then
    return true
  end

  local questType = tonumber(quest and quest.questType) or 0

  return Core.questTypeFilterEnabled(enabledQuestTypes, questType)
end

function Core.questTypeFilterEnabled(enabledQuestTypes, questType)
  if type(enabledQuestTypes) ~= "table" then
    return false
  end

  questType = tonumber(questType) or 0

  return enabledQuestTypes[questType] == true or enabledQuestTypes[tostring(questType)] == true
end

function Core.hasEnabledQuestTypeFilter(enabledQuestTypes)
  return hasEnabledValue(enabledQuestTypes)
end

function Core.hasAllPrimaryQuestTypeFilters(enabledQuestTypes)
  if type(enabledQuestTypes) ~= "table" then
    return false
  end

  return Core.questTypeFilterEnabled(enabledQuestTypes, 1)
      and Core.questTypeFilterEnabled(enabledQuestTypes, 2)
      and Core.questTypeFilterEnabled(enabledQuestTypes, 3)
      and Core.questTypeFilterEnabled(enabledQuestTypes, 4)
end

function Core.needsKnownTypeFallback(quests, enabledQuestTypes)
  if type(quests) ~= "table" or not Core.hasAllPrimaryQuestTypeFilters(enabledQuestTypes) then
    return false
  end

  if #(quests) == 0 then
    return false
  end

  local hasKnownType = false

  for i = 1, #(quests) do
    if Core.questMatchesTypeFilter(quests[i], enabledQuestTypes) then
      return false
    end

    if (tonumber(quests[i] and quests[i].questType) or 0) > 0 then
      hasKnownType = true
    end
  end

  return not hasKnownType
end

function Core.hasDesiredQuests(desired)
  return hasEnabledValue(desired)
end

function Core.countDesiredKnownQuests(quests, desired)
  local knownCount = 0
  local missingCount = 0
  local missingKeys = {}

  if type(desired) ~= "table" then
    return knownCount, missingCount, missingKeys
  end

  local present = knownQuestIndex(quests)

  for key, enabled in pairs(desired) do
    if enabled == true then
      if present and present[key] then
        knownCount = knownCount + 1
      else
        missingCount = missingCount + 1

        if #(missingKeys) < 3 then
          table.insert(missingKeys, tostring(key))
        end
      end
    end
  end

  return knownCount, missingCount, missingKeys
end

function Core.needsUntargetedRollConfirm(desired)
  return not Core.hasDesiredQuests(desired)
end

function Core.questTypeCounts(quests)
  local counts = {}

  if type(quests) ~= "table" then
    return counts
  end

  for i = 1, #(quests) do
    local questType = tonumber(quests[i] and quests[i].questType) or 0
    counts[questType] = (counts[questType] or 0) + 1
  end

  return counts
end

function Core.questInSelection(quest, selectedKeys)
  if type(selectedKeys) ~= "table" then
    return true
  end

  local key = type(quest) == "table" and type(quest.key) == "string" and quest.key or Core.questKey(quest)
  return key ~= nil and selectedKeys[key] == true
end

function Core.objectiveMetadata(objective)
  local _, parsedZone, parsedType = objectiveTextParts(objective and objective.objectiveText)
  parsedZone = tonumber(parsedZone) or 0
  parsedType = Core.sanitizeQuestType(parsedType)

  local storedZone = tonumber(objective and objective.zoneOrSort) or 0
  local storedType = Core.sanitizeQuestType(objective and objective.questType)

  local zoneOrSort = parsedZone > 0 and parsedZone or storedZone
  local questType = parsedType > 0 and parsedType or storedType

  if questType == 0 then
    questType = Core.inferQuestType(objective)
  end

  return zoneOrSort, questType
end

function Core.describeObjectiveMetadata(objective)
  local cleanText, parsedZone, parsedType = objectiveTextParts(objective and objective.objectiveText)
  local rawType = tonumber(objective and objective.questType) or 0
  local sanitizedRawType = Core.sanitizeQuestType(rawType)
  local finalZone, finalType = Core.objectiveMetadata(objective)

  return {
    rawText = trim(objective and objective.objectiveText),
    cleanText = cleanText,
    rawZone = tonumber(objective and objective.zoneOrSort) or 0,
    rawType = rawType,
    rawTypeRejected = rawType ~= 0 and sanitizedRawType == 0,
    hasSuffix = (tonumber(parsedZone) or 0) > 0 or Core.sanitizeQuestType(parsedType) > 0,
    suffixZone = tonumber(parsedZone) or 0,
    suffixType = Core.sanitizeQuestType(parsedType),
    finalZone = finalZone,
    finalType = finalType,
  }
end

local function byTitle(a, b)
  return (a.title or "") < (b.title or "")
end

Core.byTitle = byTitle

function Core.captureKnownQuests(existing, objectives, rollCount, adopt)
  local known = (adopt and type(existing) == "table") and existing or Core.copyQuestList(existing)

  if not Core.isObjectiveChoiceList(objectives) then
    return known, false
  end

  local indexByKey = knownQuestIndex(known)
  local inserted = false
  local changed = false

  for i = 1, #(objectives) do
    local objective = objectives[i]
    local key = Core.questKey(objective)
    local title = Core.questTitle(objective)

    if key and title ~= "" then
      local zoneOrSort, questType = Core.objectiveMetadata(objective)
      local entry = indexByKey[key]

      if entry then
        local objectiveText = Core.objectiveText(objective)
        local nextZone = zoneOrSort > 0 and zoneOrSort or entry.zoneOrSort or 0
        local nextType = questType > 0 and questType or entry.questType or 0
        local _, rewardsChanged = copyRewardFields(entry, objective)

        if entry.objectiveText ~= objectiveText
            or entry.zoneOrSort ~= nextZone
            or entry.questType ~= nextType
            or rewardsChanged then
          entry.objectiveText = objectiveText
          entry.zoneOrSort = nextZone
          entry.questType = nextType
          changed = true
        end

        entry.seen = (entry.seen or 0) + 1
        entry.lastSeenRoll = rollCount or entry.lastSeenRoll or 0

        Core.onKnownQuestTouched(entry)
      else
        local created = buildQuestEntry(
          objective, key, title, zoneOrSort, questType, 1, rollCount or 0)

        table.insert(known, created)
        indexByKey[key] = created
        noteIndexedQuest(known, key, created)
        inserted = true
        changed = true
      end
    end
  end

  if inserted then
    table.sort(known, byTitle)
  end

  return known, changed
end

function Core.isObjectiveChoiceList(objectives)
  if type(objectives) ~= "table" or #(objectives) < 3 then
    return false
  end

  for i = 1, 3 do
    if Core.questKey(objectives[i]) == nil or Core.questTitle(objectives[i]) == "" then
      return false
    end
  end

  return true
end

AutoCallboardCore = Core
