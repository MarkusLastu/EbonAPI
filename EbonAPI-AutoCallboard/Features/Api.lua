local Core = AutoCallboardCore
local RT = AutoCallboardRuntime

local API = AutoCallboardAPI or {}
AutoCallboardAPI = API

API.version = 1

local function InstanceQuestType(questType)
  questType = Core.sanitizeQuestType(questType)

  if questType == 2 or questType == 3 then
    return questType
  end

  return nil
end

function API.GetInstanceQuest(areaId, questType)
  local givenArea, givenType = areaId, questType

  areaId = math.floor(tonumber(areaId) or 0)
  questType = InstanceQuestType(questType)

  if areaId <= 0 or not questType then
    RT.api:Reject("API.BAD_ARGUMENT", { areaId = tostring(givenArea), questType = tostring(givenType) })

    return nil
  end

  local known = RT.state and RT.state.knownQuests
  if type(known) ~= "table" then
    return nil
  end

  local best, bestSeen

  for i = 1, #(known) do
    local quest = known[i]
    local zoneOrSort, knownType = Core.objectiveMetadata(quest)
    local seen = tonumber(quest.seen) or 0

    if zoneOrSort == areaId and knownType == questType and (not best or seen > bestSeen) then
      best, bestSeen = quest, seen
    end
  end

  if not best then
    return nil
  end

  return tonumber(best.questId) or 0, Core.questTitle(best)
end

function API.SetRequestedInstance(areaId, questType, name)
  return RT.SetRequestedInstance(areaId, questType, name)
end

function API.ClearRequestedInstance()
  RT.SetRequestedInstance(nil)
end

function API.GetRequestedInstance()
  local target = RT.requestedInstanceTarget

  if not target then
    return nil
  end

  return target.areaId, target.questType, target.name
end
