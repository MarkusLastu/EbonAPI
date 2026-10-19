local Core = AutoCallboardCore or {}
AutoCallboardCore = Core
local L = AutoCallboardLocale

local type, tonumber, tostring, pairs = type, tonumber, tostring, pairs
local string, table, math = string, table, math

local trim = Core.trim
local mergeNested = Core.mergeNested

local function Api()
  local runtime = AutoCallboardRuntime

  return runtime and runtime.api or nil
end

function Core.makeProblem(name, facts)
  local api = Api()

  return api and api:Problem(name, facts) or nil
end

function Core.reportProblem(name, facts)
  local api = Api()

  if api then
    api:Report(api:Problem(name, facts))
  end
end

local repairedOnce = {}

local function Repaired(field, reason)
  local key = field .. "/" .. reason
  local api = Api()

  if repairedOnce[key] or not api then
    return
  end

  repairedOnce[key] = true
  api:Repaired("SELECTION.REPAIRED", { field = field, reason = reason, lost = 1 })
end

local difficultyReported = false

function Core.copyCharacterProfile(profile)
  local source = type(profile) == "table" and profile or {}
  local nextNumber = tonumber(source.nextSelectionNumber) or 1

  if nextNumber < 1 then
    nextNumber = 1
  end

  return {
    desiredQuests = Core.copyDesiredMap(source.desiredQuests),
    savedSelections = Core.copySelectionList(source.savedSelections),
    nextSelectionNumber = nextNumber,
    activeSelectionId = source.activeSelectionId,
  }
end

function Core.copyCharacterProfiles(profiles)
  local copy = {}

  if type(profiles) ~= "table" then
    return copy
  end

  for profileKey, profile in pairs(profiles) do
    if type(profileKey) == "string" and type(profile) == "table" then
      copy[profileKey] = Core.copyCharacterProfile(profile)
    end
  end

  return copy
end

Core.MIN_DIFFICULTY = 1
Core.MAX_DIFFICULTY = 6

function Core.maxDifficulty()
  local service = EbonAPI.Ebonhold.Hardmode()
  local tiers = service and service.HARDMODE_REWARDS
  local highest = 0

  if type(tiers) == "table" then
    for tier in pairs(tiers) do
      tier = tonumber(tier)

      if tier and tier > highest then
        highest = math.floor(tier)
      end
    end
  end

  if highest < Core.MAX_DIFFICULTY then
    return Core.MAX_DIFFICULTY
  end

  return highest
end

function Core.sanitizeDifficulty(value)
  local given = value

  value = tonumber(value)

  if value then
    value = math.floor(value)

    if value >= Core.MIN_DIFFICULTY and value <= Core.maxDifficulty() then
      return value
    end
  end

  if given ~= nil and not difficultyReported and Api() then
    difficultyReported = true
    Core.reportProblem("SELECTION.DIFFICULTY_INVALID", {
      value = tostring(given), min = Core.MIN_DIFFICULTY, max = Core.maxDifficulty(),
    })
  end

  return nil
end

function Core.difficultyLabel(tier)
  tier = Core.sanitizeDifficulty(tier)

  if not tier then
    return L.DIFFICULTY_NONE
  end

  return L.DIFFICULTY_LABELS[tier] or string.format(L.DIFFICULTY_NUMBERED, tostring(tier))
end

Core.MAX_SAVED_SELECTIONS = 50
Core.MAX_GROUPS = 10
Core.MAX_SELECTION_NAME_LENGTH = 40

function Core.copySelection(selection)
  if type(selection) ~= "table" then
    if selection ~= nil then
      Repaired("selection", "not_table")
    end

    return nil
  end

  return {
    id = selection.id,
    name = selection.name or L.SELECTION_DEFAULT_NAME,
    difficulty = Core.sanitizeDifficulty(selection.difficulty),
    groupId = tonumber(selection.groupId),
    desiredQuests = Core.copyDesiredMap(selection.desiredQuests),
  }
end

local function copyEach(list, copier)
  local copy = {}

  if type(list) == "table" then
    for i = 1, #(list) do
      local entry = copier(list[i])

      if entry then
        table.insert(copy, entry)
      end
    end
  end

  return copy
end

function Core.copySelectionList(list)
  return copyEach(list, Core.copySelection)
end

function Core.sanitizeSelectionName(name, fallback)
  local cleaned = trim(name)

  if cleaned == "" then
    cleaned = fallback or L.SELECTION_DEFAULT_NAME
  end

  return trim(Core.truncateLetters(cleaned, Core.MAX_SELECTION_NAME_LENGTH))
end

function Core.copyGroup(group)
  if type(group) ~= "table" then
    return nil
  end

  local id = tonumber(group.id)
  if not id then
    Repaired("group", "no_id")

    return nil
  end

  return {
    id = math.floor(id),
    name = Core.sanitizeSelectionName(group.name, L.GROUP_DEFAULT_NAME),
  }
end

function Core.copyGroupList(list)
  local copy = {}

  if type(list) == "table" then
    for i = 1, #(list) do
      local entry = Core.copyGroup(list[i])

      if entry and #(copy) < Core.MAX_GROUPS then
        table.insert(copy, entry)
      elseif entry then
        Repaired("group", "limit")
      end
    end
  end

  return copy
end

local function positiveNumber(value)
  local number = tonumber(value) or 1

  if number < 1 then
    number = 1
  end

  return math.floor(number)
end

local ROUTE_ACTION_KINDS = {
  gossip = true, available = true, active = true,
  accept = true, confirm = true, complete = true, turnin = true,
}

local ROUTE_QUEST_CHANGES = { ["in"] = true, done = true, out = true }

Core.MAX_ROUTE_STEPS = 400

local function copyRouteLabel(value)
  return trim(Core.truncateLetters(trim(value), Core.MAX_SELECTION_NAME_LENGTH * 4))
end

local function copyUnitCoord(value)
  local number = tonumber(value)

  if not number or number < 0 or number > 1 then
    return nil
  end

  return number
end

local function copyPositiveId(value)
  local number = tonumber(value)

  if not number or number <= 0 then
    return nil
  end

  return math.floor(number)
end

function Core.copyRouteAction(action)
  if type(action) ~= "table" or not ROUTE_ACTION_KINDS[action.kind] then
    if action ~= nil then
      Repaired("route action", "bad_kind")
    end

    return nil
  end

  return {
    kind = action.kind,
    index = copyPositiveId(action.index),
    text = copyRouteLabel(action.text),
    title = copyRouteLabel(action.title),
    questId = copyPositiveId(action.questId),
    reward = tonumber(action.reward) and math.floor(tonumber(action.reward)) or nil,
  }
end

function Core.copyRouteQuestRef(entry)
  if type(entry) ~= "table" then
    return nil
  end

  return {
    title = copyRouteLabel(entry.title),
    questId = copyPositiveId(entry.questId),
    complete = entry.complete and true or false,
  }
end

local function copyRouteQuestRefs(list)
  return copyEach(list, Core.copyRouteQuestRef)
end

function Core.copyRouteStep(step)
  if type(step) ~= "table" then
    return nil
  end

  local copy = {
    kind = step.kind,
    resting = step.resting and true or false,
    zone = copyRouteLabel(step.zone),
    map = copyRouteLabel(step.map),
    x = copyUnitCoord(step.x),
    y = copyUnitCoord(step.y),
    difficulty = Core.sanitizeDifficulty(step.difficulty),
  }

  if step.kind == "travel" then
    copy.checkpoint = copyPositiveId(step.checkpoint)
    copy.checkpointName = copyRouteLabel(step.checkpointName)

    if not copy.checkpoint then
      Repaired("route step", "no_checkpoint")

      return nil
    end

    return copy
  end

  if step.kind == "npc" then
    copy.npcId = copyPositiveId(step.npcId)
    copy.npcName = copyRouteLabel(step.npcName)
    copy.available = copyRouteQuestRefs(step.available)
    copy.active = copyRouteQuestRefs(step.active)
  elseif step.kind == "quest" then
    copy.questId = copyPositiveId(step.questId)
    copy.title = copyRouteLabel(step.title)
    copy.item = copyRouteLabel(step.item)
    copy.on = ROUTE_QUEST_CHANGES[step.on] and step.on or nil
  else
    Repaired("route step", "bad_kind")

    return nil
  end

  copy.actions = {}

  if type(step.actions) == "table" then
    for i = 1, #(step.actions) do
      local action = Core.copyRouteAction(step.actions[i])

      if action then
        table.insert(copy.actions, action)
      end
    end
  end

  return copy
end

function Core.copyRouteSteps(steps)
  local copy = {}

  if type(steps) == "table" then
    for i = 1, #(steps) do
      if #(copy) >= Core.MAX_ROUTE_STEPS then
        Core.reportProblem("ROUTE.STEPS_TRUNCATED", { given = #(steps), limit = Core.MAX_ROUTE_STEPS })

        break
      end

      local step = Core.copyRouteStep(steps[i])

      if step then
        table.insert(copy, step)
      end
    end
  end

  return copy
end

local minted = setmetatable({}, { __mode = "k" })

function Core.copyRoute(route)
  if type(route) ~= "table" or not Core.isRouteCategory(route.category) then
    if type(route) == "table" then
      Repaired("route", "bad_category")
    end

    return nil
  end

  local copy = {
    id = route.id,
    name = route.name or L.ROUTE_DEFAULT_NAME,
    category = tonumber(route.category),
    difficulty = Core.sanitizeDifficulty(route.difficulty),
    shared = (route.shared == true or Core.sanitizeRouteHash(route.sharedHash) ~= nil) or nil,
    sharedHash = Core.sanitizeRouteHash(route.sharedHash),
    steps = Core.copyRouteSteps(route.steps),
  }

  minted[copy] = true

  if minted[route] and #(copy.steps) == #(route.steps) then
    Core.inheritRouteHash(route, copy)
    Core.inheritRouteFaction(route, copy)
  end

  return copy
end

function Core.copyRouteList(list)
  return copyEach(list, Core.copyRoute)
end

function Core.copyAccountProfile(profile)
  local source = type(profile) == "table" and profile or {}

  return {
    savedSelections = Core.copySelectionList(source.savedSelections),
    groups = Core.copyGroupList(source.groups),
    nextSelectionNumber = positiveNumber(source.nextSelectionNumber),
    nextGroupNumber = positiveNumber(source.nextGroupNumber),
    savedRoutes = Core.copyRouteList(source.savedRoutes),
    nextRouteNumber = positiveNumber(source.nextRouteNumber),
  }
end

local ECHO_BAR_SLOTS = 3
local ECHO_BAR_DEFAULTS = {
  enabled = false,
  locked = false,
  orientation = "H",
  point = "CENTER",
  relativePoint = "CENTER",
  x = 0,
  y = -200,
}
local ECHO_BAR_SPEC = {
  enabled = "boolean",
  locked = "boolean",
  orientation = "nonEmptyString",
  point = "nonEmptyString",
  relativePoint = "nonEmptyString",
  x = "number",
  y = "number",
}

Core.ECHO_BAR_SLOTS = ECHO_BAR_SLOTS

function Core.copyEchoBar(source)
  local bar = { slots = {} }

  for key, value in pairs(ECHO_BAR_DEFAULTS) do
    bar[key] = value
  end

  if type(source) ~= "table" then
    return bar
  end

  mergeNested(source, bar, ECHO_BAR_SPEC)

  if bar.orientation ~= "V" then
    bar.orientation = "H"
  end

  if type(source.slots) == "table" then
    local seen = {}

    for i = 1, ECHO_BAR_SLOTS do
      local slot = tonumber(source.slots[i])

      if slot and slot >= 1 and not seen[slot] then
        seen[slot] = true
        bar.slots[i] = math.floor(slot)
      end
    end
  end

  return bar
end

function Core.copyCharacterState(entry)
  local source = type(entry) == "table" and entry or {}

  return {
    desiredQuests = Core.copyDesiredMap(source.desiredQuests),
    activeSelectionId = tonumber(source.activeSelectionId),
    openGroupId = tonumber(source.openGroupId),
    openRouteCategory = tonumber(source.openRouteCategory),
    openLibraryCategory = tonumber(source.openLibraryCategory),
    echoBar = Core.copyEchoBar(source.echoBar),
    toolbar = Core.copyToolbar(source.toolbar),
    routeDraft = Core.copyRouteSteps(source.routeDraft),
    activeRouteId = tonumber(source.activeRouteId),
    routeWindowOpen = source.routeWindowOpen and true or false,
    routeCompact = source.routeCompact and true or false,
    routeLoop = source.routeLoop and true or false,
    routeRecording = source.routeRecording and true or false,
    routePlaying = source.routePlaying and true or false,
    routeCursor = tonumber(source.routeCursor),
    routeStart = tonumber(source.routeStart),
  }
end

function Core.copyCharacterStateMap(states)
  local copy = {}

  if type(states) == "table" then
    for key, entry in pairs(states) do
      if type(key) == "string" and type(entry) == "table" then
        copy[key] = Core.copyCharacterState(entry)
      end
    end
  end

  return copy
end

local Selections = Core.buildContainer({
  items = "savedSelections",
  groups = "groups",
  nextItem = "nextSelectionNumber",
  nextGroup = "nextGroupNumber",
  itemNameKey = "SELECTION_NUMBERED_NAME",
  groupNameKey = "GROUP_NUMBERED_NAME",
  copyProfile = function(profile) return Core.copyAccountProfile(profile) end,
  maxItems = function() return Core.MAX_SAVED_SELECTIONS end,
  maxGroups = function() return Core.MAX_GROUPS end,
})

Core.selectionsInContainer = Selections.itemsIn
Core.selectionCount = Selections.count
Core.selectionsFull = Selections.full
Core.peekNextSelectionName = Selections.peekNextName
Core.findSelection = Selections.find
Core.renameSelection = Selections.rename
Core.deleteSelection = Selections.delete
Core.setSelectionGroup = Selections.setGroup
Core.moveSelectionTo = Selections.moveTo
Core.findGroupIndex = Selections.findGroupIndex
Core.findGroup = Selections.findGroup
Core.groupCount = Selections.groupCount
Core.groupsFull = Selections.groupsFull
Core.peekNextGroupName = Selections.peekNextGroupName
Core.createGroup = Selections.createGroup
Core.moveGroupToIndex = Selections.moveGroupToIndex
Core.renameGroup = Selections.renameGroup
Core.groupSelectionNames = Selections.groupItemNames
Core.deleteGroup = Selections.deleteGroup

function Core.createSelection(profile, desiredQuests, name, groupId)
  return Selections.create(profile, name, groupId, { desiredQuests = Core.copyDesiredMap(desiredQuests) })
end

function Core.setSelectionDifficulty(profile, id, tier)
  return Selections.update(profile, id, { difficulty = Core.sanitizeDifficulty(tier) or Core.CLEARED })
end

function Core.updateSelectionContent(profile, id, desiredQuests)
  return Selections.update(profile, id, { desiredQuests = Core.copyDesiredMap(desiredQuests) })
end

function Core.selectionHasQuest(selection, key)
  if type(selection) ~= "table" or type(key) ~= "string" or key == "" then
    return false
  end

  return type(selection.desiredQuests) == "table" and selection.desiredQuests[key] == true
end

function Core.setQuestInSelection(profile, id, key, wanted)
  if type(key) ~= "string" or key == "" then
    return profile, nil, Core.makeProblem("SELECTION.QUEST_KEY_INVALID", { key = tostring(key) })
  end

  local selection = Core.findSelection(profile, id)

  if not selection then
    return profile, nil, Core.makeProblem("SELECTION.NOT_FOUND", { selection = tostring(id) })
  end

  local desired = Core.copyDesiredMap(selection.desiredQuests)

  if wanted then
    desired[key] = true
  else
    desired[key] = nil
  end

  return Selections.update(profile, id, { desiredQuests = desired })
end

function Core.characterSelectionCount(characterProfile)
  if type(characterProfile) ~= "table" or type(characterProfile.savedSelections) ~= "table" then
    return 0
  end

  return #(characterProfile.savedSelections)
end

function Core.importSelections(profile, selections, groupId)
  local nextProfile = Core.copyAccountProfile(profile)
  local incoming = Core.copySelectionList(selections)
  local idMap = {}

  groupId = tonumber(groupId)

  for i = 1, #(incoming) do
    local entry = incoming[i]
    local previousId = entry.id
    local number = nextProfile.nextSelectionNumber

    nextProfile.nextSelectionNumber = number + 1
    entry.id = number
    entry.groupId = groupId

    if previousId ~= nil then
      idMap[previousId] = number
    end

    table.insert(nextProfile.savedSelections, entry)
  end

  return nextProfile, idMap
end

function Core.buildMigratedCharacterState(characterProfile, idMap, groupId)
  local source = type(characterProfile) == "table" and characterProfile or {}
  local activeId = source.activeSelectionId

  if activeId ~= nil and type(idMap) == "table" then
    activeId = idMap[activeId]
  else
    activeId = nil
  end

  return {
    desiredQuests = Core.copyDesiredMap(source.desiredQuests),
    activeSelectionId = tonumber(activeId),
    openGroupId = tonumber(groupId),
  }
end

function Core.migrateLegacyPresets(state, legacyDB)
  if type(state) ~= "table" then
    state = Core.defaultState()
  end

  if type(legacyDB) ~= "table" or type(legacyDB.characters) ~= "table" then
    return state
  end

  local nextState = Core.mergeState(state)
  nextState.presetsMigrated = true

  for characterKey, legacyProfile in pairs(legacyDB.characters) do
    if type(characterKey) == "string" and type(legacyProfile) == "table" then
      local profile = Core.copyCharacterProfile(nextState.characterProfiles[characterKey])
      local legacySelections = Core.copySelectionList(legacyProfile.selections)

      if #(legacySelections) > 0 and #(profile.savedSelections) == 0 then
        profile.savedSelections = legacySelections
        profile.nextSelectionNumber = tonumber(legacyProfile.nextNumber) or (#(legacySelections) + 1)
        profile.activeSelectionId = legacyProfile.activeSelectionId
      end

      nextState.characterProfiles[characterKey] = profile
    end
  end

  return nextState
end
