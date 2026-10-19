local Core = AutoCallboardCore
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local SecondsRemaining = RT.SecondsRemaining
local FormatSeconds = RT.FormatSeconds
local ResolveFramePath = RT.ResolveFramePath
local state = RT.state

local BOARD_TARGET_PRIMARY_NAMES = { "Objectives Board", "Objective Board" }
local BOARD_OBJECT_IDS = { [600600] = true }
local ACCEPT_WINDOW = 12
local INTERACT_DELAY = 1.25

local callboardActiveUntil
local fallbackCooldownUntil
local pendingInteractAt
local pendingAcceptUntil
local UpdateSummonStatus
local TargetCallboard
local QueueCallboardFollowup

local SyncCallboardActiveFromCooldown
local GetFallbackCooldownRemaining

local function IsCallboardActive()
  if SecondsRemaining(callboardActiveUntil) > 0 then
    return true
  end

  if SecondsRemaining(RT.objectiveBoardReadyUntil) > 0 then
    return true
  end

  if RT.GetNpcBoardInfo() then
    return true
  end

  if RT.IsCallboardUiPresent() then
    return true
  end

  return false
end

local function GetCallboardCooldownRemaining()
  if not state then
    return 0, false
  end

  if GetSpellCooldown and state.summonSpellID then
    local start, duration = GetSpellCooldown(state.summonSpellID)

    if start then
      if start > 0 and duration and duration > 1.5 then
        return math.max(0, start + duration - GetTime()), true
      end

      return 0, true
    end
  end

  local spellName = RT.GetSummonSpellName()

  if GetSpellCooldown and spellName ~= "" then
    local start, duration = GetSpellCooldown(spellName)

    if start then
      if start > 0 and duration and duration > 1.5 then
        return math.max(0, start + duration - GetTime()), true
      end

      return 0, true
    end
  end

  return 0, false
end

GetFallbackCooldownRemaining = function()
  return SecondsRemaining(fallbackCooldownUntil)
end

local function GetSummonCooldownRemaining()
  local cooldownRemaining, observed = GetCallboardCooldownRemaining()

  if observed then
    if cooldownRemaining <= 0 then
      fallbackCooldownUntil = nil
      callboardActiveUntil = nil
    end

    return cooldownRemaining
  end

  return GetFallbackCooldownRemaining()
end

SyncCallboardActiveFromCooldown = function(source)
  if source == "cooldown inference" then
    if SecondsRemaining(callboardActiveUntil) <= 0
        and SecondsRemaining(fallbackCooldownUntil) <= 0
        and not RT.pendingSummonVerifyUntil
        and not RT.pendingCooldownSyncUntil then
      RT.nextCooldownInferenceAt = nil
      return false
    end

    local now = GetTime()

    if RT.nextCooldownInferenceAt and now < RT.nextCooldownInferenceAt then
      return SecondsRemaining(callboardActiveUntil) > 0
    end

    RT.nextCooldownInferenceAt = now + 0.5
  end

  if RT.StartCallboardTimersFromCooldown(source) then
    return SecondsRemaining(callboardActiveUntil) > 0
  end

  return false
end

function RT.StartCallboardTimersFromCooldown(source)
  if not state then
    return false
  end

  local cooldownRemaining, observed = GetCallboardCooldownRemaining()
  local inactiveCooldownTail = math.max(0, (state.summonCooldown or 45) - (state.summonDuration or 30))

  if cooldownRemaining <= 0 then
    if observed then
      fallbackCooldownUntil = nil
      callboardActiveUntil = nil
    end

    return false
  end

  local now = GetTime()
  local activeRemaining = 0
  fallbackCooldownUntil = now + cooldownRemaining

  if cooldownRemaining > inactiveCooldownTail then
    activeRemaining = math.min(state.summonDuration or 30, cooldownRemaining - inactiveCooldownTail)
    callboardActiveUntil = now + activeRemaining
  else
    callboardActiveUntil = nil
  end

  if source ~= "cooldown inference" and activeRemaining > 0 and RT.IsCallboardDataAvailable() then
    RT.ResumeRollingAfterCallboardActive(source)
  end

  return true
end

function RT.QueueSummonCooldownSync()
  RT.pendingCooldownSyncUntil = GetTime() + 3
  RT.nextPendingCooldownCheckAt = nil
end

function RT.SyncPendingSummonCooldown()
  if not RT.pendingCooldownSyncUntil then
    RT.nextPendingCooldownCheckAt = nil
    return
  end

  local now = GetTime()
  if RT.nextPendingCooldownCheckAt and now < RT.nextPendingCooldownCheckAt then
    return
  end

  RT.nextPendingCooldownCheckAt = now + RT.pendingCooldownPollInterval

  if RT.StartCallboardTimersFromCooldown("pending cooldown sync") then
    RT.pendingCooldownSyncUntil = nil
    RT.nextPendingCooldownCheckAt = nil
    UpdateSummonStatus()
    return
  end

  if now > RT.pendingCooldownSyncUntil then
    RT.pendingCooldownSyncUntil = nil
    RT.nextPendingCooldownCheckAt = nil
  end
end

function RT.IsSummonBlockedIndoors()
  if not IsIndoors then
    return false
  end

  if not IsIndoors() then
    return false
  end

  if IsInInstance and IsInInstance() then
    return false
  end

  return true
end

local function IsSummonSpellUsable()
  if RT.IsSummonBlockedIndoors() then
    return false
  end

  local spellName = RT.GetSummonSpellName()

  if not IsUsableSpell or spellName == "" then
    return true
  end

  local usable = IsUsableSpell(spellName)

  if usable and usable ~= 0 then
    return true
  end

  return false
end

local function MarkCallboardSummoned(source)
  RT.pendingSummonVerifyUntil = nil
  RT.pendingSummonSource = nil
  RT.QueueSummonCooldownSync()

  if RT.StartCallboardTimersFromCooldown(source) then
    return
  end

  local now = GetTime()
  callboardActiveUntil = now + state.summonDuration
  fallbackCooldownUntil = now + state.summonCooldown

  if RT.IsCallboardDataAvailable() then
    RT.ResumeRollingAfterCallboardActive(source)
  end
end

function RT.BeginSummonAttempt(source)
  RT.pendingSummonSource = source
  RT.pendingSummonVerifyUntil = GetTime() + 2.5
  RT.nextSummonVerifyCheckAt = nil
end

function RT.CheckPendingSummonAttempt()
  if not RT.pendingSummonVerifyUntil then
    RT.nextSummonVerifyCheckAt = nil
    return
  end

  local now = GetTime()
  if RT.nextSummonVerifyCheckAt and now < RT.nextSummonVerifyCheckAt then
    return
  end

  RT.nextSummonVerifyCheckAt = now + RT.summonVerifyPollInterval
  local source = tostring(RT.pendingSummonSource)

  if RT.IsCallboardUiPresent() then
    MarkCallboardSummoned(source .. " ui verified")
    QueueCallboardFollowup(source .. " ui verified")
    return
  end

  if GetSummonCooldownRemaining() > 0 or SecondsRemaining(callboardActiveUntil) > 0 then
    MarkCallboardSummoned(source .. " cooldown verified")
    QueueCallboardFollowup(source .. " cooldown verified")
    return
  end

  if now <= RT.pendingSummonVerifyUntil then
    return
  end

  RT.pendingSummonVerifyUntil = nil
  RT.pendingSummonSource = nil
  RT.nextSummonVerifyCheckAt = nil
  RT.api:Report(RT.api:Problem("SUMMON.NOT_VERIFIED", {
    source = source,
    indoors = RT.IsSummonBlockedIndoors(),
    usable = RT.IsSummonSpellUsable(),
    cooldown = math.floor(GetSummonCooldownRemaining()),
  }))

  if RT.IsRolling() then
    RT.SetRollPause("no_callboard", L.PAUSED_WAITING_CALLBOARD_OPEN)
  end

  UpdateSummonStatus()
end

UpdateSummonStatus = function()
  local summonStatusText = RT.summonStatusText
  if not summonStatusText or not state then
    return
  end

  local activeRemaining = SecondsRemaining(callboardActiveUntil)
  local cooldownRemaining = GetSummonCooldownRemaining()

  if activeRemaining > 0 then
    summonStatusText:SetText(string.format(L.SUMMON_STATUS_ACTIVE, FormatSeconds(activeRemaining), FormatSeconds(cooldownRemaining)))
  elseif cooldownRemaining > 0 then
    summonStatusText:SetText(string.format(L.SUMMON_STATUS_COOLDOWN, FormatSeconds(cooldownRemaining)))
  else
    summonStatusText:SetText(L.SUMMON_STATUS_READY)
  end
end

RT.UpdateSummonStatus = UpdateSummonStatus

local function GetObjectivesService()
  return EbonAPI.Ebonhold.Objectives()
end

local EMPTY_OBJECTIVES = {}

local function GetCurrentObjectives()
  local now = GetTime()

  if RT.objectivesCacheAt == now then
    return RT.objectivesCache
  end

  local objectives = EMPTY_OBJECTIVES
  local service = GetObjectivesService()

  if service and service.GetCurrentObjectives then
    local result = service.GetCurrentObjectives()
    if type(result) == "table" then
      objectives = result
    elseif result ~= nil then
      RT.api:Reject("CALLBOARD.OBJECTIVES_BAD_DATA", { type = type(result), source = "GetCurrentObjectives" })
    end
  end

  RT.objectivesCacheAt = now
  RT.objectivesCache = objectives

  return objectives
end

local function GetActiveObjective()
  local service = GetObjectivesService()

  if service and service.GetActiveObjective then
    local objective = service.GetActiveObjective()
    if type(objective) == "table" then
      return objective
    end

    if objective ~= nil then
      RT.api:Reject("CALLBOARD.OBJECTIVES_BAD_DATA", { type = type(objective), source = "GetActiveObjective" })
    end
  end

  return nil
end

function RT.FrameIsVisibleOrShown(target)
  if not target then
    return false
  end

  if target.IsVisible and target:IsVisible() then
    return true
  end

  if not target.IsVisible and target.IsShown and target:IsShown() then
    return true
  end

  return false
end

function RT.GetObjectiveFrameNames()
  local prefix = state and state.objectivePrefix or ""

  if RT.objectiveFrameNamesPrefix ~= prefix then
    RT.objectiveFrameNamesPrefix = prefix
    RT.objectiveFrameNames = { prefix .. "1", prefix .. "2", prefix .. "3" }
  end

  return RT.objectiveFrameNames
end

function RT.IsCallboardUiPresent()
  if not state then
    return false
  end

  if RT.FrameIsVisibleOrShown(_G.ObjectivesMainFrame) then
    return true
  end

  local names = RT.GetObjectiveFrameNames()

  for i = 1, 3 do
    if RT.FrameIsVisibleOrShown(_G[names[i]]) then
      return true
    end
  end

  return RT.FrameIsVisibleOrShown(ResolveFramePath(state.rerollFrame))
end

function RT.HasCurrentObjectiveData()
  return Core.isObjectiveChoiceList(GetCurrentObjectives())
end

function RT.IsCallboardDataAvailable()
  if RT.IsCallboardUiPresent() then
    return true
  end

  if RT.GetNpcBoardInfo()
      and RT.HasCurrentObjectiveData() then
    return true
  end

  return RT.objectiveBoardAccessOpen
      and SecondsRemaining(RT.objectiveBoardReadyUntil) > 0
      and RT.HasCurrentObjectiveData()
end

function RT.CanReadObjectiveChoices()
  if RT.IsCallboardDataAvailable() then
    return true
  end

  return RT.IsRemoteRollEnabled() and RT.HasCurrentObjectiveData()
end

function RT.IsBoardSessionOpen()
  local npcBoard = RT.GetNpcBoardInfo()
  local uiOpen = RT.IsCallboardUiPresent()
  local sessionOpen = RT.objectiveBoardAccessOpen
      and SecondsRemaining(RT.objectiveBoardReadyUntil) > 0

  if not (uiOpen or sessionOpen or npcBoard) then
    return false, nil, npcBoard
  end

  return true, uiOpen and "objectives_ui" or npcBoard and "npc_token" or "objectives_gossip", npcBoard
end

function RT.IsCallboardReadyForQuestActions()
  if not GetObjectivesService() then
    return false
  end

  if not RT.IsBoardSessionOpen() and not RT.IsRemoteRollEnabled() then
    return false
  end

  return RT.HasCurrentObjectiveData()
end

function RT.IsRemoteRollEnabled()
  if not state or not state.remoteRoll then
    return false
  end

  if not GetObjectivesService() then
    return false
  end

  return true
end

function RT.GetBoardAccessState(action)
  local service = GetObjectivesService()
  local boardOpen, source, npcBoard = RT.IsBoardSessionOpen()
  local dataReady = RT.HasCurrentObjectiveData()
  local activeRemaining = SecondsRemaining(callboardActiveUntil)

  if not service then
    RT.api:Report(RT.api:Problem("CALLBOARD.SERVICE_MISSING"))

    return {
      ok = false,
      reason = "objectives_service_missing",
      message = L.BOARD_ACCESS_SERVICE_MISSING,
    }
  end

  if boardOpen then
    if dataReady then
      return {
        ok = true,
        boardOpen = true,
        source = source,
        reason = "ready",
        message = L.BOARD_ACCESS_READY,
        boardName = npcBoard and npcBoard.name or nil,
        boardObjectId = npcBoard and npcBoard.objectId or nil,
      }
    end

    RT.api:Report(RT.api:Problem("CALLBOARD.OBJECTIVE_DATA_MISSING", { boardOpen = true }))

    return {
      ok = false,
      boardOpen = true,
      needsData = true,
      source = source,
      reason = "objective_data_missing",
      message = L.BOARD_ACCESS_DATA_MISSING,
      boardName = npcBoard and npcBoard.name or nil,
      boardObjectId = npcBoard and npcBoard.objectId or nil,
    }
  end

  if RT.IsRemoteRollEnabled() then
    if dataReady then
      return {
        ok = true,
        remote = true,
        source = "remote",
        reason = "remote",
        message = L.BOARD_ACCESS_REMOTE,
      }
    end

    RT.api:Report(RT.api:Problem("CALLBOARD.OBJECTIVE_DATA_MISSING", { boardOpen = false }))

    return {
      ok = false,
      remote = true,
      needsData = true,
      reason = "objective_data_missing",
      message = L.BOARD_ACCESS_DATA_MISSING,
    }
  end

  if activeRemaining > 0 then
    RT.api:Report(RT.api:Problem("CALLBOARD.WINDOW_NOT_OPEN"))

    return {
      ok = false,
      callboardActive = true,
      reason = "board_window_not_open",
      message = L.BOARD_ACCESS_ACTIVE_NOT_OPEN,
    }
  end

  RT.api:Report(RT.api:Problem("CALLBOARD.NOT_OPEN"))

  return {
    ok = false,
    reason = "board_not_open",
    message = L.BOARD_ACCESS_NOT_OPEN,
    action = action,
  }
end

function RT.RequestObjectiveBoardData(source)
  local now = GetTime()

  if RT.HasCurrentObjectiveData() then
    RT.objectiveRequestPendingUntil = nil
    RT.objectiveRequestAttempts = 0
    RT.noAnswerReported = nil
    return true
  end

  if RT.objectiveRequestPendingUntil and now < RT.objectiveRequestPendingUntil then
    return true
  end

  if RT.nextObjectiveRequestAt and now < RT.nextObjectiveRequestAt then
    return true
  end

  if RT.objectiveRequestAttempts and RT.objectiveRequestAttempts >= 2 then
    if not RT.noAnswerReported then
      RT.noAnswerReported = true
      RT.api:Report(RT.api:Problem("CALLBOARD.OBJECTIVES_NO_ANSWER", { attempts = RT.objectiveRequestAttempts }))
    end

    return false
  end

  local service = GetObjectivesService()
  if not service or not service.RequestObjectives then
    if not RT.objectiveServiceMissingReported then
      RT.objectiveServiceMissingReported = true
      RT.api:Degrade(RT.api:Problem("CALLBOARD.SERVICE_MISSING"))
    end

    return false
  end

  if RT.objectiveServiceMissingReported then
    RT.objectiveServiceMissingReported = nil
    RT.api:Restore("CALLBOARD.SERVICE_MISSING")
  end

  RT.objectiveRequestAttempts = (RT.objectiveRequestAttempts or 0) + 1
  RT.objectiveRequestPendingUntil = now + 2.5
  RT.nextObjectiveRequestAt = now + 3
  service.RequestObjectives()
  RT.api:Trace("objectives_requested", source, RT.objectiveRequestAttempts)

  return true
end

function RT.CleanBoardText(value)
  value = Core.stripColorCodes(value)
  value = value:gsub("^%s+", ""):gsub("%s+$", "")

  return value
end

function RT.IsObjectiveBoardName(value)
  value = RT.CleanBoardText(value)

  for i = 1, #(BOARD_TARGET_PRIMARY_NAMES) do
    if value == BOARD_TARGET_PRIMARY_NAMES[i] then
      return true, value
    end
  end

  return false, value
end

function RT.ExtractBoardObjectIdFromGuid(guid)
  if type(guid) ~= "string" then
    return nil
  end

  local hex = guid:gsub("^0x", "")
  if string.len(hex) < 10 then
    return nil
  end

  local prefix = string.sub(hex, 1, 4)
  if prefix ~= "F110" and prefix ~= "F130" then
    return nil
  end

  return tonumber(string.sub(hex, 5, 10), 16)
end

function RT.IsKnownBoardObjectId(objectId)
  return objectId and BOARD_OBJECT_IDS[tonumber(objectId)] == true
end

function RT.IsBoardNpcName(value)
  local isObjectiveName, cleanName = RT.IsObjectiveBoardName(value)
  if isObjectiveName then
    return true, cleanName
  end

  if state and cleanName == state.targetName then
    return true, cleanName
  end

  return false, cleanName
end

function RT.IsGossipFrameOpen()
  return GossipFrame and GossipFrame.IsShown and GossipFrame:IsShown()
end

function RT.GetNpcBoardInfo()
  if not RT.IsGossipFrameOpen() then
    return nil
  end

  local name = UnitName and RT.CleanBoardText(UnitName("npc")) or ""
  local guid = UnitGUID and UnitGUID("npc") or nil
  local objectId = RT.ExtractBoardObjectIdFromGuid(guid)
  local nameMatches, cleanName = RT.IsBoardNpcName(name)
  local idMatches = RT.IsKnownBoardObjectId(objectId)

  if not nameMatches and not idMatches then
    return nil
  end

  return {
    name = cleanName,
    guid = guid,
    objectId = objectId,
    nameMatches = nameMatches,
    idMatches = idMatches,
  }
end

function RT.MarkObjectiveBoardOpened(source)
  RT.objectiveBoardReadyUntil = GetTime() + (state and state.summonDuration or 30)
  RT.objectiveBoardAccessOpen = true
  RT.manualBoardOpenRequired = false
  RT.RequestObjectiveBoardData(source)
  RT.api:Trace("board_opened", source)

  if RT.IsRolling() and (RT.GetRollPauseReason() == "manual_board" or RT.GetRollPauseReason() == "no_callboard") then
    RT.ClearRollPause()
    RT.SetNextRollAt(GetTime() + 0.2)
  end
end

function RT.MarkObjectiveBoardClosed(source)
  if not RT.objectiveBoardAccessOpen then
    return
  end

  RT.objectiveBoardAccessOpen = false
  RT.objectiveBoardReadyUntil = nil
  RT.api:Trace("board_closed", source)

  if RT.IsRolling() and RT.GetRollPauseReason() ~= "quest_selected" and not IsCallboardActive() then
    RT.SetManualBoardOpenRequired(source)
  end
end

TargetCallboard = function()
  local name = state and state.targetName

  if not name or name == "" then
    return nil, RT.api:Problem("CALLBOARD.TARGET_NOT_SET")
  end

  local targetByName = rawget(_G, "TargetByName")
  if targetByName then
    targetByName(name, true)
  end

  if UnitExists("target") and UnitName("target") == name then
    return true, name
  end

  return nil, RT.api:Problem("CALLBOARD.TARGET_NOT_FOUND", { targetName = name })
end

local function TryInteract()
  local source = RT.pendingInteractSource
  pendingInteractAt = nil
  RT.pendingInteractSource = nil

  local targeted, targetName = TargetCallboard()
  if not targeted then
    RT.api:Report(targetName)
    RT.SetManualBoardOpenRequired(source)
    return
  end

  pendingAcceptUntil = GetTime() + ACCEPT_WINDOW

  if InteractUnit then
    InteractUnit("target")
  else
    RT.api:Notify(string.format(L.TARGETED_QUEST_PROMPT, targetName))
  end
end

QueueCallboardFollowup = function(source)
  pendingAcceptUntil = GetTime() + ACCEPT_WINDOW
  RT.api:Trace("summon_followup", source)

  if TargetCallboard() then
    TryInteract()
    return
  end

  pendingInteractAt = GetTime() + INTERACT_DELAY
  RT.pendingInteractSource = source
end

function RT.GetCallboardActiveRemaining()
  return SecondsRemaining(callboardActiveUntil)
end

function RT.IsSummonStatusBusy()
  return SecondsRemaining(callboardActiveUntil) > 0
      or SecondsRemaining(fallbackCooldownUntil) > 0
      or RT.pendingSummonVerifyUntil ~= nil
      or RT.pendingCooldownSyncUntil ~= nil
end

function RT.GetPendingAcceptUntil()
  return pendingAcceptUntil
end

function RT.ClearPendingAcceptUntil()
  pendingAcceptUntil = nil
end

function RT.RunPendingInteract(now)
  if pendingInteractAt and now >= pendingInteractAt then
    TryInteract()
  end
end

RT.IsCallboardActive = IsCallboardActive
RT.GetSummonCooldownRemaining = GetSummonCooldownRemaining
RT.GetFallbackCooldownRemaining = GetFallbackCooldownRemaining
RT.IsSummonSpellUsable = IsSummonSpellUsable
RT.GetObjectivesService = GetObjectivesService
RT.GetCurrentObjectives = GetCurrentObjectives
RT.GetActiveObjective = GetActiveObjective
RT.SyncCallboardActiveFromCooldown = SyncCallboardActiveFromCooldown
RT.TargetCallboard = TargetCallboard
RT.QueueCallboardFollowup = QueueCallboardFollowup
RT.MarkCallboardSummoned = MarkCallboardSummoned

function RT.ClearPendingInteract()
  pendingInteractAt = nil
  pendingAcceptUntil = nil
end

function RT.ArmQuestAccept()
  pendingAcceptUntil = GetTime() + ACCEPT_WINDOW
end
