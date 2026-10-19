local Core = AutoCallboardCore or {}
AutoCallboardCore = Core
local L = AutoCallboardLocale

local type, tonumber, tostring, table, string = type, tonumber, tostring, table, string

Core.MAX_SAVED_ROUTES = 50
Core.ROUTE_WINDOW_SIGNATURE = "quest#window"

Core.ROUTE_CATEGORY_KEYS = {
  "leveling", "dailies", "reputations", "professions", "chains", "class", "events", "achievements",
}

function Core.routeCategoryCount()
  return #(Core.ROUTE_CATEGORY_KEYS)
end

function Core.isRouteCategory(value)
  value = tonumber(value)

  return value ~= nil and value == math.floor(value) and value >= 1 and value <= Core.routeCategoryCount()
end

function Core.routeCategoryName(category)
  local names = L.ROUTE_CATEGORY_NAMES

  return names and names[tonumber(category)] or tostring(category)
end

local Routes = Core.buildContainer({
  items = "savedRoutes",
  groupKey = "category",
  nextItem = "nextRouteNumber",
  itemNameKey = "ROUTE_NUMBERED_NAME",
  hasGroup = function(id) return Core.isRouteCategory(id) end,
  copyProfile = function(profile) return Core.copyAccountProfile(profile) end,
  maxItems = function() return Core.MAX_SAVED_ROUTES end,
  maxGroups = function() return Core.routeCategoryCount() end,
})

Core.routeContainer = Routes

Core.routesInCategory = Routes.itemsIn
Core.routeCount = Routes.count
Core.routesFull = Routes.full
Core.peekNextRouteName = Routes.peekNextName
Core.findRoute = Routes.find
Core.renameRoute = Routes.rename
Core.deleteRoute = Routes.delete
Core.setRouteCategory = Routes.setGroup
Core.moveRouteTo = Routes.moveTo

function Core.createRoute(profile, steps, name, category, fields)
  if not Core.isRouteCategory(category) then
    return Core.copyAccountProfile(profile), nil,
      Core.makeProblem("ROUTE.CATEGORY_INVALID", { category = tostring(category) })
  end

  local payload = { steps = Core.copyRouteSteps(steps) }

  for key, value in pairs(fields or {}) do
    payload[key] = value
  end

  return Routes.create(profile, name, tonumber(category), payload)
end

local function RouteMissing(profile, id)
  return Core.copyAccountProfile(profile), nil, Core.makeProblem("ROUTE.NOT_FOUND", { route = tostring(id) })
end

local function StepMissing(profile, id, index)
  return Core.copyAccountProfile(profile), nil,
    Core.makeProblem("ROUTE.STEP_NOT_FOUND", { route = tostring(id), step = tostring(index) })
end

local questFactions

function Core.questFaction(questId)
  questId = tonumber(questId)

  if not questId then
    return nil
  end

  if not questFactions then
    questFactions = {}

    for faction, data in pairs(Core.QUEST_FACTION_DATA or {}) do
      local id = 0

      for gap in string.gmatch(data, "[^,]+") do
        id = id + (tonumber(gap, 36) or 0)
        questFactions[id] = faction
      end
    end
  end

  return questFactions[questId]
end

local function StepQuestIds(step, visit)
  visit(step.questId)

  for _, ref in ipairs(step.active or {}) do
    visit(ref.questId)
  end

  for _, action in ipairs(step.actions or {}) do
    visit(action.questId)
  end
end

local factionCache = setmetatable({}, { __mode = "k" })

local function ReadRouteFaction(steps)
  local found

  for i = 1, #(steps) do
    StepQuestIds(steps[i], function(questId)
      found = found or Core.questFaction(questId)
    end)

    if found then
      return found
    end
  end

  return nil
end

function Core.routeFaction(route)
  if type(route) ~= "table" or type(route.steps) ~= "table" then
    return nil
  end

  local cached = factionCache[route]

  if cached and cached.steps == route.steps then
    return cached.faction
  end

  local faction = ReadRouteFaction(route.steps)

  factionCache[route] = { steps = route.steps, faction = faction }

  return faction
end

function Core.inheritRouteFaction(source, copy)
  local cached = factionCache[source]

  if not cached or cached.steps ~= source.steps then
    return false
  end

  factionCache[copy] = { steps = copy.steps, faction = cached.faction }

  return true
end

Core.FACTION_ICONS = {
  Horde = [[Interface\PVPFrame\PVP-Currency-Horde]],
  Alliance = [[Interface\PVPFrame\PVP-Currency-Alliance]],
}

function Core.factionLabel(faction)
  local names = L.ROUTE_FACTION_NAMES

  return names and names[faction] or tostring(faction or "")
end

function Core.factionIcon(faction, size)
  local texture = Core.FACTION_ICONS[faction]

  if not texture then
    return ""
  end

  size = tonumber(size) or 14

  return "|T" .. texture .. ":" .. size .. ":" .. size .. "|t "
end

function Core.routeTitle(route)
  if type(route) ~= "table" then
    return ""
  end

  return Core.factionIcon(Core.routeFaction(route)) .. tostring(route.name)
    .. Core.routeDifficultySuffix(route.difficulty)
    .. (Core.isRouteShared(route) and L.ROUTE_SHARED_SUFFIX or "")
end

function Core.canPlayRoute(route, playerFaction)
  local faction = Core.routeFaction(route)

  return faction == nil or faction == playerFaction, faction
end

function Core.setRouteSteps(profile, id, steps)
  return Routes.update(profile, id, { steps = Core.copyRouteSteps(steps) })
end

function Core.appendRouteSteps(profile, id, steps)
  local route = Routes.find(profile, id)

  if not route then
    return RouteMissing(profile, id)
  end

  local merged = Core.copyRouteSteps(route.steps)
  local added = Core.copyRouteSteps(steps)
  local existing = #(merged)

  local function count(list)
    return type(list) == "table" and #(list) or 0
  end

  if existing + #(added) > Core.MAX_ROUTE_STEPS
    and count(route.steps) <= Core.MAX_ROUTE_STEPS and count(steps) <= Core.MAX_ROUTE_STEPS then
    Core.reportProblem("ROUTE.STEPS_TRUNCATED", { given = existing + #(added), limit = Core.MAX_ROUTE_STEPS })
  end

  for _, step in ipairs(added) do
    if #(merged) >= Core.MAX_ROUTE_STEPS then
      break
    end

    table.insert(merged, step)
  end

  return Routes.update(profile, id, { steps = merged })
end

function Core.deleteRouteStep(profile, id, index)
  local route = Routes.find(profile, id)
  local given = index
  index = tonumber(index)

  if not route then
    return RouteMissing(profile, id)
  end

  if not index or not route.steps[index] then
    return StepMissing(profile, id, given)
  end

  local steps = Core.copyRouteSteps(route.steps)
  table.remove(steps, index)

  return Routes.update(profile, id, { steps = steps })
end

function Core.deleteRouteAction(profile, id, stepIndex, actionIndex)
  local route = Routes.find(profile, id)
  local givenStep, givenAction = stepIndex, actionIndex
  stepIndex, actionIndex = tonumber(stepIndex), tonumber(actionIndex)

  if not route then
    return RouteMissing(profile, id)
  end

  local steps = Core.copyRouteSteps(route.steps)
  local step = stepIndex and steps[stepIndex]

  if not step then
    return StepMissing(profile, id, givenStep)
  end

  if not actionIndex or not step.actions or not step.actions[actionIndex] then
    return Core.copyAccountProfile(profile), nil, Core.makeProblem("ROUTE.ACTION_NOT_FOUND", {
      route = tostring(id), step = tostring(givenStep), action = tostring(givenAction),
    })
  end

  table.remove(step.actions, actionIndex)

  return Routes.update(profile, id, { steps = steps })
end

function Core.routeStepCount(route)
  if type(route) ~= "table" or type(route.steps) ~= "table" then
    return 0
  end

  return #(route.steps)
end

local unknownCheckpoints = {}

function Core.routeCheckpointName(checkpointId, fallback)
  checkpointId = tonumber(checkpointId)

  local service = EbonAPI.Ebonhold.Checkpoints()

  if checkpointId and service and service.GetCheckpoints then
    local ok, list = pcall(service.GetCheckpoints)

    if ok and type(list) == "table" then
      for i = 1, #(list) do
        if tonumber(list[i].id) == checkpointId then
          return tostring(list[i].name)
        end
      end

      if not unknownCheckpoints[checkpointId] then
        unknownCheckpoints[checkpointId] = true
        Core.reportProblem("ROUTE.CHECKPOINT_UNKNOWN", { checkpoint = checkpointId })
      end
    end
  end

  if type(fallback) == "string" and fallback ~= "" then
    return fallback
  end

  return string.format(L.ROUTE_UNKNOWN_CHECKPOINT, tostring(checkpointId or "?"))
end

function Core.routeQuestLabel(questId, title, titles)
  questId = tonumber(questId)

  if questId then
    local live

    if titles then
      live = titles[questId]
    else
      live = Core.routeQuestTitleLookup(questId)
    end

    if type(live) == "string" and live ~= "" then
      return live
    end
  end

  if type(title) == "string" and title ~= "" then
    return title
  end

  return string.format(L.ROUTE_UNKNOWN_QUEST, tostring(questId or "?"))
end

local function AcceptLine(action, titles)
  return string.format(L.ROUTE_LINE_ACCEPT, Core.routeQuestLabel(action.questId, action.title, titles))
end

local ACTION_LINES = {
  gossip = function(action)
    return string.format(L.ROUTE_LINE_GOSSIP, action.text ~= "" and action.text
      or tostring(action.index or "?"))
  end,
  available = function(action, titles)
    return string.format(L.ROUTE_LINE_QUEST_AVAILABLE, Core.routeQuestLabel(action.questId, action.title, titles))
  end,
  active = function(action, titles)
    return string.format(L.ROUTE_LINE_QUEST_ACTIVE, Core.routeQuestLabel(action.questId, action.title, titles))
  end,
  accept = AcceptLine,
  confirm = AcceptLine,
  complete = function()
    return L.ROUTE_LINE_COMPLETE
  end,
  turnin = function(action, titles)
    local label = Core.routeQuestLabel(action.questId, action.title, titles)

    if action.reward and action.reward > 0 then
      return string.format(L.ROUTE_LINE_TURNIN_REWARD, label, tostring(action.reward))
    end

    return string.format(L.ROUTE_LINE_TURNIN, label)
  end,
}

function Core.routeActionHasLine(action)
  return type(action) == "table" and ACTION_LINES[action.kind] ~= nil
end

function Core.routeActionLine(action, titles)
  if not Core.routeActionHasLine(action) then
    return ""
  end

  return ACTION_LINES[action.kind](action, titles)
end

function Core.routeStepLine(step, titles)
  if type(step) ~= "table" then
    return ""
  end

  local text

  if step.kind == "travel" then
    text = string.format(L.ROUTE_LINE_TRAVEL, Core.routeCheckpointName(step.checkpoint, step.checkpointName))
  elseif step.kind == "quest" then
    local change = ({ ["in"] = L.ROUTE_LINE_QUEST_GAINED, done = L.ROUTE_LINE_QUEST_DONE,
      out = L.ROUTE_LINE_QUEST_REWARDED })[step.on]

    if change then
      text = string.format(change, Core.routeQuestLabel(step.questId, step.title, titles))
    elseif type(step.item) == "string" and step.item ~= "" then
      text = string.format(L.ROUTE_LINE_USE_ITEM, step.item)
    else
      text = L.ROUTE_LINE_QUEST_WINDOW
    end
  else
    local name = step.npcName

    if type(name) ~= "string" or name == "" then
      name = L.ROUTE_UNKNOWN_NPC
    end

    text = string.format(L.ROUTE_LINE_NPC, name)
  end

  return text .. Core.routeDifficultySuffix(step.difficulty)
end

function Core.routeDifficultySuffix(value)
  local tier = Core.sanitizeDifficulty(value)

  if not tier then
    return ""
  end

  return string.format(L.ROUTE_LINE_DIFFICULTY_SUFFIX, Core.difficultyLabel(tier))
end

local QUEST_CHANGE_ORDER = { out = 1, ["in"] = 2, done = 3 }

function Core.questLogChanges(before, after)
  local changes = {}

  for questId, quest in pairs(before) do
    if not after[questId] then
      table.insert(changes, { kind = "quest", on = "out", questId = questId, title = quest.title })
    end
  end

  for questId, quest in pairs(after) do
    local previous = before[questId]

    if not previous then
      table.insert(changes, { kind = "quest", on = "in", questId = questId, title = quest.title })
    end

    if quest.complete and not (previous and previous.complete) then
      table.insert(changes, { kind = "quest", on = "done", questId = questId, title = quest.title })
    end
  end

  table.sort(changes, function(a, b)
    if a.on ~= b.on then
      return QUEST_CHANGE_ORDER[a.on] < QUEST_CHANGE_ORDER[b.on]
    end

    return a.questId < b.questId
  end)

  return changes
end

function Core.routeSignature(step)
  if type(step) ~= "table" then
    return ""
  end

  if step.kind == "quest" then
    if step.on then
      return tonumber(step.questId) and (step.on .. ":" .. step.questId) or ""
    end

    if type(step.title) == "string" and step.title ~= "" then
      return "quest:" .. step.title
    end

    return tonumber(step.questId) and Core.ROUTE_WINDOW_SIGNATURE or ""
  end

  if step.kind ~= "npc" then
    return ""
  end

  local parts = { "npc:" .. tostring(step.npcId or 0) }
  local turnins = {}

  local active, available = step.active or {}, step.available or {}

  for i = 1, #(active) do
    table.insert(turnins, tostring(active[i].questId or 0))
  end

  table.sort(turnins)

  table.insert(parts, "in:" .. table.concat(turnins, ","))
  table.insert(parts, "av:" .. tostring(#(available)))

  return table.concat(parts, "|")
end

function Core.setRouteDifficulty(profile, id, tier)
  return Routes.update(profile, id, { difficulty = Core.sanitizeDifficulty(tier) or Core.CLEARED })
end

function Core.setRouteStepDifficulty(profile, id, stepIndex, tier)
  local route = Routes.find(profile, id)
  local given = stepIndex
  stepIndex = tonumber(stepIndex)

  if not route then
    return RouteMissing(profile, id)
  end

  if not stepIndex or not route.steps[stepIndex] then
    return StepMissing(profile, id, given)
  end

  if not route.steps[stepIndex].resting then
    return Core.copyAccountProfile(profile), nil,
      Core.makeProblem("ROUTE.NOT_RESTING", { route = tostring(id), step = tostring(given) })
  end

  local steps = Core.copyRouteSteps(route.steps)
  steps[stepIndex].difficulty = Core.sanitizeDifficulty(tier)

  return Routes.update(profile, id, { steps = steps })
end
