local Core = AutoCallboardCore
local RT = AutoCallboardRuntime
local state = RT.state

RT.instanceTargetDirty = true

local MAP_FILE_NAME_MAX_ATTEMPTS = 20
local MAP_RETRY_INTERVAL = 0.5

function RT.InvalidateInstanceTarget()
  RT.instanceTargetDirty = true
  RT.instanceTargetMapAttempts = 0
  RT.instanceTargetRetryAt = nil
end

local function CurrentInstanceVisit()
  local ok, inInstance, instanceType = pcall(IsInInstance)

  if not ok then
    return nil
  end

  if not inInstance then
    return "none"
  end

  local infoOk, instanceName, infoInstanceType = pcall(GetInstanceInfo)

  if not infoOk or type(instanceName) ~= "string" or instanceName == "" then
    return nil
  end

  if not instanceType or instanceType == "" then
    instanceType = infoInstanceType
  end

  local questType = Core.currentInstanceQuestType(instanceType)

  if questType == 0 then
    return nil
  end

  return questType .. ":" .. instanceName
end

function RT.NoteInstanceVisit()
  local visit = CurrentInstanceVisit()

  if not visit or visit == RT.instanceVisit then
    return
  end

  RT.api:Trace("instance", RT.instanceVisit, visit)
  RT.instanceVisit = visit
  RT.ClearVisitExclusions()
end

local function GetCurrentMapFileName(instanceType)
  local mapIsBrowsed = WorldMapFrame
      and RT.FrameIsVisibleOrShown(WorldMapFrame)

  if mapIsBrowsed then
    RT.instanceTargetMapPending = true
    return nil
  end

  pcall(SetMapToCurrentZone)

  local _, mapFileName = pcall(GetMapInfo)
  if type(mapFileName) ~= "string" or mapFileName == "" then
    local attempts = (RT.instanceTargetMapAttempts or 0) + 1

    RT.instanceTargetMapAttempts = attempts
    RT.instanceTargetMapPending = attempts < MAP_FILE_NAME_MAX_ATTEMPTS

    if attempts == MAP_FILE_NAME_MAX_ATTEMPTS then
      return nil, RT.api:Problem("INSTANCE.MAP_UNAVAILABLE", { attempts = attempts, instanceType = instanceType })
    end

    return nil
  end

  return mapFileName
end

function RT.ComputeCurrentInstanceQuestTarget()
  RT.instanceTargetMapPending = false

  if not state or not state.autoCurrentInstanceQuest then
    return nil, "disabled"
  end

  if not IsInInstance then
    return nil, "missing_is_in_instance"
  end

  local ok, inInstance, instanceType = pcall(IsInInstance)
  if not ok then
    return nil, "is_in_instance_failed"
  end

  if not inInstance then
    return nil, "not_in_instance"
  end

  local names = {}
  local function addName(value)
    if type(value) == "string" and value ~= "" then
      table.insert(names, value)
    end
  end

  if GetInstanceInfo then
    local infoOk, instanceName, infoInstanceType = pcall(GetInstanceInfo)
    if infoOk then
      addName(instanceName)
      if (not instanceType or instanceType == "") and type(infoInstanceType) == "string" then
        instanceType = infoInstanceType
      end
    end
  end

  if GetRealZoneText then
    local zoneOk, zoneName = pcall(GetRealZoneText)
    if zoneOk then
      addName(zoneName)
    end
  end

  if GetZoneText then
    local zoneOk, zoneName = pcall(GetZoneText)
    if zoneOk then
      addName(zoneName)
    end
  end

  if GetMinimapZoneText then
    local zoneOk, zoneName = pcall(GetMinimapZoneText)
    if zoneOk then
      addName(zoneName)
    end
  end

  local mapFileName, mapProblem = GetCurrentMapFileName(instanceType)

  addName(mapFileName)

  if mapProblem then
    RT.api:Report(mapProblem)
  end

  local target = Core.buildCurrentInstanceTarget({
      instanceType = instanceType,
      name = names[1],
      names = names,
    })

  if not target then
    if #names == 0 then
      return nil, "map_unavailable"
    end

    return nil, "unsupported_instance_type:" .. tostring(instanceType)
  end

  return target
end

function RT.GetCurrentInstanceQuestTarget()
  if not RT.instanceTargetDirty then
    return RT.instanceTargetCache, RT.instanceTargetReason
  end

  local now = GetTime()

  if RT.instanceTargetRetryAt and now < RT.instanceTargetRetryAt then
    return RT.instanceTargetCache, RT.instanceTargetReason
  end

  local target, reason = RT.ComputeCurrentInstanceQuestTarget()

  if not target and RT.requestedInstanceTarget then
    target, reason = RT.requestedInstanceTarget, nil
  end

  if target then
    RT.instanceTargetSignature = tostring(target.questType) .. ":" .. tostring(target.name)
  else
    RT.instanceTargetSignature = "none:" .. tostring(reason)
  end

  RT.instanceTargetDirty = RT.instanceTargetMapPending == true

  if RT.instanceTargetDirty then
    RT.instanceTargetRetryAt = now + MAP_RETRY_INTERVAL
  else
    RT.instanceTargetRetryAt = nil
  end

  RT.instanceTargetCache = target
  RT.instanceTargetReason = reason

  return target, reason
end

function RT.SetRequestedInstance(areaId, questType, name)
  areaId = math.floor(tonumber(areaId) or 0)
  questType = Core.sanitizeQuestType(questType)

  if areaId <= 0 or (questType ~= 2 and questType ~= 3) then
    RT.requestedInstanceTarget = nil
  else
    local label = Core.trim(name)

    RT.requestedInstanceTarget = {
      builtTarget = true,
      areaId = areaId,
      questType = questType,
      name = label ~= "" and label or tostring(areaId),
      aliases = {},
    }
  end

  RT.InvalidateInstanceTarget()

  return RT.requestedInstanceTarget ~= nil
end

function RT.RefreshCurrentInstanceQuestTarget(source)
  local target, reason = RT.GetCurrentInstanceQuestTarget()

  local signature = RT.instanceTargetSignature

  if RT.currentInstanceQuestSignature ~= signature then
    RT.currentInstanceQuestSignature = signature
    if target then
      RT.api:Trace("instance", source, target.name)
    elseif state and state.autoCurrentInstanceQuest
        and (reason == "map_unavailable" or reason == "is_in_instance_failed" or reason == "missing_is_in_instance") then
      RT.api:Trace("instance", source, reason)
    end
  end

  return target
end
