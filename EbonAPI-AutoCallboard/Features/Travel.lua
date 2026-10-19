local Core = AutoCallboardCore
local RT = AutoCallboardRuntime
local L = AutoCallboardLocale
local Skin = AutoCallboardSkin
local state = RT.state

local BUTTON_NAME = "AutoCallboardTravelButton"

local button
local suggestion
local suggestionQuestKey
local requestedAt
local autoQuestKey
local MaybeAutoTravel
local lastTravelCheckpoints
local lastTravelUnlockedCount
local lastTravelLocation
local lastTravelAreaId

local LOCATION_ALIASES = {
  tirisfalglades = "tirisfal", elwynnforest = "elwynn", redridgemountains = "redridge",
  alteracmountains = "alterac", arathihighlands = "arathi", hillsbradfoothills = "hillsbrad",
  stranglethornvale = "stranglethorn", dustwallowmarsh = "dustwallow", azshara = "aszhara",
  stormwindcity = "stormwind", shattrathcity = "shattrath", silvermooncity = "silvermoon",
  darnassus = "darnassis", stockades = "stockade",
  tempestkeepnetherstorm = "tempestkeep",
  ogrimmar = "orgrimmar",
}

local function Trim(value)
  if type(value) ~= "string" then
    return ""
  end

  return (value:match("^%s*(.-)%s*$"))
end

local function NormalizeLocation(value)
  value = Trim(value):lower()
  value = value:gsub("[^%w]", "")

  value = value:gsub("^the", "")
  return LOCATION_ALIASES[value] or value
end

function Core.travelLocationFromText(text)
  text = Trim(text)

  if text == "" then
    return ""
  end

  local location

  for match in string.gmatch(text, "%f[%w][iI][nN]%s+([^%.]+)") do
    location = match
  end

  return Trim(location or "")
end

function Core.travelCheckpointLocation(name)
  name = Trim(name)

  if name == "" then
    return ""
  end

  local zone = name:match(",%s*([^,]+)%s*$")

  return Trim(zone or name)
end

function Core.travelCheckpointUsable(checkpoint)
  if type(checkpoint) ~= "table" then
    return false
  end

  if (tonumber(checkpoint.id) or 0) <= 0 then
    return false
  end

  if not checkpoint.unlocked then
    return false
  end

  if checkpoint.factionAllowed == false then
    return false
  end

  return true
end

local ClientBounds

local zonesByName, zonesByMap = {}, {}
local entrancesByName = {}
local subzonesByName = {}

for name, parent in pairs(Core.travelSubzones or {}) do
  subzonesByName[NormalizeLocation(name)] = NormalizeLocation(parent)
end

for name, entrances in pairs(Core.travelEntrances or {}) do
  entrancesByName[NormalizeLocation(name)] = entrances
end

for _, row in ipairs(Core.travelZones or {}) do
  local zone = { name = row[1], mapId = row[2], serverMapId = row[3],
    region = row[8], bounds = row[4] and { row[4], row[5], row[6], row[7], row[3] } or nil }
  zonesByName[NormalizeLocation(zone.name)] = zone
  zonesByMap[zone.mapId] = zone
end

local function WorldMapKey(zone, map)
  return tostring(map) .. ":" .. (zone.region or "")
end

local function WorldPoint(checkpoint, boundsByName)
  local zone = zonesByMap[tonumber(checkpoint.mapId)]
  if not zone then
    zone = zonesByName[NormalizeLocation(Core.travelCheckpointLocation(checkpoint.name))]
  end
  if not zone then
    return nil
  end
  local bounds = (boundsByName and boundsByName[NormalizeLocation(zone.name)]) or zone.bounds
  if not bounds or bounds[5] ~= tonumber(checkpoint.serverMapId) then
    return nil
  end
  local x, y = tonumber(checkpoint.x), tonumber(checkpoint.y)
  if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
    return nil
  end
  return { x = bounds[1] + (bounds[2] - bounds[1]) * x,
    y = bounds[3] + (bounds[4] - bounds[3]) * y, map = WorldMapKey(zone, bounds[5]) }
end

ClientBounds = function()
  local ebonBounds = EbonAPI.Ebonhold.WorldMapBounds()

  if not ebonBounds then
    return nil
  end

  local boundsByName = {}

  for name, bounds in pairs(ebonBounds) do
    if type(bounds) == "table" and type(bounds[1]) == "number" and type(bounds[2]) == "number"
        and type(bounds[3]) == "number" and type(bounds[4]) == "number" and type(bounds[5]) == "number"
        and bounds[1] > bounds[2] and bounds[3] > bounds[4] then
      boundsByName[NormalizeLocation(name)] = bounds
    end
  end

  return boundsByName
end

function RT.WorldPointFor(mapName, x, y)
  x, y = tonumber(x), tonumber(y)

  if not x or not y then
    return nil
  end

  local zone = zonesByName[NormalizeLocation(mapName)]

  if not zone then
    return nil
  end

  return WorldPoint({ mapId = zone.mapId, serverMapId = zone.serverMapId, x = x, y = y }, ClientBounds())
end

function Core.travelZoneKey(location, areaId)
  local wanted = NormalizeLocation(location)

  if wanted == "" then
    wanted = NormalizeLocation((Core.travelAreaNames or {})[tonumber(areaId)])
  end

  if wanted == "" then
    return ""
  end

  return subzonesByName[wanted] or wanted
end

local MAP_REFRESH_INTERVAL = 1
local mapRefreshedAt

local function RefreshPlayerMap()
  if not SetMapToCurrentZone then
    return
  end

  if WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown() then
    return
  end

  local now = GetTime and GetTime() or 0

  if mapRefreshedAt and now - mapRefreshedAt < MAP_REFRESH_INTERVAL then
    return
  end

  mapRefreshedAt = now
  SetMapToCurrentZone()
end

function RT.InvalidatePlayerMap()
  mapRefreshedAt = nil
end

function RT.GetCurrentZoneKey()
  if not GetMapInfo then
    return ""
  end

  RefreshPlayerMap()

  return NormalizeLocation(GetMapInfo())
end

function RT.ReadPlayerMapPoint()
  if not GetPlayerMapPosition then
    return nil
  end

  RefreshPlayerMap()

  local x, y = GetPlayerMapPosition("player")
  x, y = tonumber(x), tonumber(y)

  if not x or not y or (x == 0 and y == 0) then
    return nil
  end

  return (GetMapInfo and GetMapInfo()) or "", x, y
end

function RT.IsPlayerInTravelZone(location, areaId)
  local wanted = Core.travelZoneKey(location, areaId)

  if wanted == "" then
    return false
  end

  local here = RT.GetCurrentZoneKey()

  if here == "" then
    return false
  end

  return here == wanted
end

function Core.chooseTravelCheckpoint(checkpoints, location, areaId)
  if type(checkpoints) ~= "table" then
    return nil
  end

  local wanted = NormalizeLocation(location)
  if wanted == "" then
    wanted = NormalizeLocation((Core.travelAreaNames or {})[tonumber(areaId)])
  end
  wanted = subzonesByName[wanted] or wanted

  if wanted == "" then
    return nil
  end

  local boundsByName = ClientBounds()

  local anchors = {}
  local targetZone = zonesByName[wanted]
  if targetZone then
    local bounds = (boundsByName and boundsByName[wanted]) or targetZone.bounds
    if bounds then
      anchors[1] = { x = (bounds[1] + bounds[2]) / 2, y = (bounds[3] + bounds[4]) / 2,
        map = WorldMapKey(targetZone, bounds[5]) }
    end
  else
    for _, checkpoint in ipairs(checkpoints) do
      if NormalizeLocation(checkpoint.name) == wanted then
        local point = WorldPoint(checkpoint, boundsByName)
        if point then
          table.insert(anchors, point)
        end
      end
    end
    if #anchors == 0 then
      for _, entrance in ipairs(entrancesByName[wanted] or {}) do
        local zone = zonesByName[NormalizeLocation(entrance[1])]
        if zone then
          local point = WorldPoint({ mapId = zone.mapId, serverMapId = zone.serverMapId,
            x = entrance[2], y = entrance[3] }, boundsByName)
          if point then
            table.insert(anchors, point)
          end
        end
      end
    end
  end

  local best, bestScore, bestRank

  for i = 1, #(checkpoints) do
    local checkpoint = checkpoints[i]

    if Core.travelCheckpointUsable(checkpoint) then
      local full = NormalizeLocation(checkpoint.name)
      local zone = NormalizeLocation(Core.travelCheckpointLocation(checkpoint.name))

      local exact = full == wanted or zone == wanted
      local sameZone = targetZone and tonumber(checkpoint.mapId) == targetZone.mapId
        and tonumber(checkpoint.serverMapId) == targetZone.serverMapId
      local rank = (exact or sameZone) and 0 or 1
      local point = WorldPoint(checkpoint, boundsByName)
      local score
      if point then
        for _, anchor in ipairs(anchors) do
          if point.map == anchor.map then
            local distance = (point.x - anchor.x)^2 + (point.y - anchor.y)^2
            if not score or distance < score then
              score = distance
            end
          end
        end
      end
      if not score and exact then
        score = math.huge
      end
      if score then
        if not best or rank < bestRank or (rank == bestRank and (score < bestScore
            or (score == bestScore and tonumber(checkpoint.id) < tonumber(best.id)))) then
          best = checkpoint
          bestScore = score
          bestRank = rank
        end
      end
    end
  end

  return best
end

function Core.travelCheckpointLabel(checkpoint)
  if type(checkpoint) ~= "table" then
    return ""
  end

  local name = Trim(checkpoint.name)

  if name == "" then
    return ""
  end

  local place = name:match("^([^,]+)")

  return Trim(place or name)
end

function Core.countUnlockedCheckpoints(checkpoints)
  local count = 0

  if type(checkpoints) ~= "table" then
    return count
  end

  for i = 1, #(checkpoints) do
    if Core.travelCheckpointUsable(checkpoints[i]) then
      count = count + 1
    end
  end

  return count
end

local function GetService()
  return EbonAPI.Ebonhold.Checkpoints()
end

local function GetCheckpoints()
  local service = GetService()

  if not service or not service.GetCheckpoints then
    return nil
  end

  local list = RT.api:Guard("travel.checkpoints", service.GetCheckpoints)

  if type(list) ~= "table" then
    return nil
  end

  return list
end

local serviceDown = false

local function ServiceReady()
  if GetService() then
    if serviceDown then
      serviceDown = false
      RT.api:Restore("TRAVEL.SERVICE_UNAVAILABLE")
    end

    return true
  end

  if not serviceDown then
    serviceDown = true
    RT.api:Degrade(RT.api:Problem("TRAVEL.SERVICE_UNAVAILABLE"))
  end

  return false
end

function RT.RequestTravelCheckpoints(source)
  local service = GetService()

  if not service or not service.RequestCheckpoints then
    return false
  end

  local now = GetTime and GetTime() or 0

  if requestedAt and (now - requestedAt) < 30 then
    return false
  end

  requestedAt = now

  local _, problem = RT.api:Guard("travel.request", service.RequestCheckpoints)

  return problem == nil
end

function RT.IsTravelEnabled()
  return state and state.travelEnabled and true or false
end

function RT.IsTravelAutoEnabled()
  if not RT.IsTravelEnabled() then
    return false
  end

  return state and state.travelAuto and true or false
end

local function ActiveQuestKey(objective)
  if type(objective) ~= "table" then
    return ""
  end

  return tostring(objective.questId or 0) .. ":" .. tostring(Core.questTitle(objective))
end

local function UpdateButton()
  if not button then
    return
  end

  if not suggestion then
    button:Hide()
    return
  end

  button:SetText(string.format(L.TRAVEL_BUTTON_FORMAT, Core.travelCheckpointLabel(suggestion)))
  button:Show()
end

local function CreateButton()
  if button or not RT.controlFrame then
    return button
  end

  button = Skin.Root(Skin.MakeButton(UIParent, {
    name = BUTTON_NAME,
    point = { "TOPLEFT", RT.controlFrame, "BOTTOMLEFT", 0, -4 },
    onClick = function()
      RT.TravelToSuggestion("button")
    end,
    tipTitle = "TRAVEL_BUTTON_LABEL",
    tipBody = "TRAVEL_BUTTON_TOOLTIP",
  }))

  button:Hide()

  return button
end

local function AutoTravelBlocked()
  if InCombatLockdown and InCombatLockdown() then
    return "combat"
  end

  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
    return "dead"
  end

  return nil
end

function MaybeAutoTravel(questKey)
  if not RT.IsTravelAutoEnabled() then
    autoQuestKey = questKey
    return false
  end

  if not suggestion or questKey == "" then
    return false
  end

  if autoQuestKey == nil then
    autoQuestKey = questKey
    return false
  end

  if questKey == autoQuestKey then
    return false
  end

  if not ServiceReady() then
    return false
  end

  if AutoTravelBlocked() then
    return false
  end

  if RT.IsPlayerInTravelZone(lastTravelLocation, lastTravelAreaId) then
    autoQuestKey = questKey
    return false
  end

  autoQuestKey = questKey

  return RT.TravelToSuggestion("auto")
end

function RT.ResetTravelAutoBaseline()
  local objective = RT.GetActiveObjective()

  autoQuestKey = ActiveQuestKey(objective)
end

function RT.GetTravelSuggestion()
  return suggestion
end

function RT.ClearTravelSuggestion()
  suggestion = nil
  suggestionQuestKey = nil
  lastTravelCheckpoints = nil
  lastTravelUnlockedCount = nil
  lastTravelLocation = nil
  lastTravelAreaId = nil
  UpdateButton()
end

function RT.RefreshTravelSuggestion(source, skipAuto)
  if not RT.IsTravelEnabled() then
    RT.ClearTravelSuggestion()
    return nil
  end

  local objective = RT.GetActiveObjective()

  if not objective then
    if autoQuestKey ~= nil then
      autoQuestKey = ""
    end
    RT.ClearTravelSuggestion()
    return nil
  end

  local questKey = ActiveQuestKey(objective)
  if autoQuestKey == nil then
    autoQuestKey = questKey
  end

  local checkpoints = GetCheckpoints()
  local unlocked = Core.countUnlockedCheckpoints(checkpoints)

  if unlocked <= 0 then
    RT.RequestTravelCheckpoints("refresh")
    RT.ClearTravelSuggestion()
    return nil
  end

  local location = Core.travelLocationFromText(Core.objectiveText(objective))
  local areaId = Core.objectiveMetadata(objective)

  if source == "watch" and suggestionQuestKey == questKey and lastTravelCheckpoints == checkpoints
      and lastTravelUnlockedCount == unlocked and lastTravelLocation == location and lastTravelAreaId == areaId then
    if not skipAuto then
      MaybeAutoTravel(questKey)
    end
    return suggestion
  end

  lastTravelCheckpoints = checkpoints
  lastTravelUnlockedCount = unlocked
  lastTravelLocation = location
  lastTravelAreaId = areaId

  local chosen = Core.chooseTravelCheckpoint(checkpoints, location, areaId)

  if (chosen and chosen.id) ~= (suggestion and suggestion.id) or suggestionQuestKey ~= questKey then
    RT.api:Trace("travel.suggestion", Core.questTitle(objective), chosen and chosen.name or "none")
  end

  suggestion = chosen
  suggestionQuestKey = questKey
  CreateButton()
  UpdateButton()
  if not skipAuto then
    MaybeAutoTravel(questKey)
  end

  return suggestion
end

function RT.TravelToSuggestion(source)
  if not ServiceReady() then
    return false
  end

  local previousId = suggestion and suggestion.id
  local previousQuestKey = suggestionQuestKey
  local target = RT.RefreshTravelSuggestion("send", true)

  if not target then
    local objective = RT.GetActiveObjective()
    local quest = objective and Core.questTitle(objective) or ""
    if quest == "" then
      quest = L.QUEST_FALLBACK_LABEL
    end

    RT.api:Report(RT.api:Problem("TRAVEL.NO_DESTINATION", { quest = quest }))
    return false
  end

  if target.id ~= previousId or suggestionQuestKey ~= previousQuestKey then
    RT.api:Report(RT.api:Problem("TRAVEL.SUGGESTION_CHANGED", { checkpoint = Core.travelCheckpointLabel(target) }))
    return false
  end

  local blocked = AutoTravelBlocked()

  if blocked == "combat" then
    RT.api:Report(RT.api:Problem("TRAVEL.IN_COMBAT"))
    return false
  end

  if blocked then
    RT.api:Report(RT.api:Problem("TRAVEL.PLAYER_DEAD"))
    return false
  end

  if not Core.travelCheckpointUsable(target) then
    RT.api:Report(RT.api:Problem("TRAVEL.CHECKPOINT_LOCKED", { checkpoint = Core.travelCheckpointLabel(target) }))
    return false
  end

  RT.api:Trace("travel.use", target.id, source)

  autoQuestKey = suggestionQuestKey

  if not EbonAPI.Ebonhold.UseCheckpoint(tonumber(target.id)) then
    return false
  end

  return true
end

function RT.OnTravelEnabledChanged()
  if RT.IsTravelEnabled() then
    RT.RequestTravelCheckpoints("enabled")
  end

  RT.ResetTravelAutoBaseline()
  RT.RefreshTravelSuggestion("toggle")
end

function RT.OnTravelAutoChanged()
  RT.ResetTravelAutoBaseline()
end

function RT.SetTravelEnabled(enabled)
  RT.SetField("travelEnabled", enabled and true or false)
end

function RT.SetTravelAutoEnabled(enabled)
  RT.SetField("travelAuto", enabled and true or false)
end

function RT.WatchTravelSuggestion()
  if not state then
    return 5
  end

  if not RT.IsTravelEnabled() then
    if suggestion then
      RT.ClearTravelSuggestion()
    end

    return 5
  end

  if not ServiceReady() then
    RT.ClearTravelSuggestion()
    return 5
  end

  RT.RefreshTravelSuggestion("watch")

  return 1
end
