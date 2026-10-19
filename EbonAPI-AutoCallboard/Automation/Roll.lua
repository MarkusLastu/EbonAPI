local Core = AutoCallboardCore
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local SecondsRemaining = RT.SecondsRemaining
local GetQuestTypeName = RT.GetQuestTypeName
local NormalizeCopper = RT.NormalizeCopper
local SyncGoldTracker = RT.SyncGoldTracker
local NormalizeQuestTitle = RT.NormalizeQuestTitle
local FindSelectedQuestInLog = RT.FindSelectedQuestInLog
local GetObjectivesService = RT.GetObjectivesService
local GetCurrentObjectives = RT.GetCurrentObjectives
local GetActiveObjective = RT.GetActiveObjective
local state = RT.state

local ROLL_EVAL_INTERVAL = 0.5
local QUEST_REFRESH_INTERVAL = 0.4
local SELECTED_QUEST_SCAN_FLOOR = 0.25
local ABANDON_GRACE = 5

local rolling = false
local rollPausedReason
local rollPauseMessage
local rollCount = 0
local nextRollAt
local pendingReroll = false
local pendingRerollUntil
local lastObjectiveSignature
local lastCapturedSignature
local selectedQuest
local excludedQuests = {}
local satisfiedInstances = {}
local lastAbandonAt
local nextSelectedQuestCheckAt
local lastSelectedQuestScanAt
local nextQuestRefreshAt

local SetRollPause
local ClearRollPause
local EvaluateCurrentObjectives
local ResumeRollingAfterCallboardActive
local StopRolling
local StartRolling

local function UpdateQuestWindow()
  RT.UpdateQuestWindow()
end

local function UpdateRollToggleButtons()
  RT.UpdateRollToggleButtons()
end

local signatureParts = {}
local signatureSource, signatureAt, signatureValue

local function ObjectiveSignature(objectives)
  if type(objectives) ~= "table" then
    return ""
  end

  local now = GetTime()
  if signatureSource == objectives and signatureAt == now then
    return signatureValue
  end

  local count = #(objectives)

  for i = 1, count do
    signatureParts[i] = Core.questKey(objectives[i]) or i
  end

  for i = #(signatureParts), count + 1, -1 do
    signatureParts[i] = nil
  end

  signatureSource = objectives
  signatureAt = now
  signatureValue = table.concat(signatureParts, "|")

  return signatureValue
end

local function CaptureCurrentObjectives()
  if not state then
    return {}
  end

  if not RT.CanReadObjectiveChoices() then
    lastCapturedSignature = nil
    return {}
  end

  local objectives = GetCurrentObjectives()
  local signature = ObjectiveSignature(objectives)

  if signature == lastCapturedSignature then
    return objectives
  end

  lastCapturedSignature = signature

  local known, changed = Core.captureKnownQuests(state.knownQuests, objectives, rollCount, true)
  state.knownQuests = known

  if changed then
    RT.TouchState()
  end

  return objectives
end

local function CountDesiredQuests()
  return Core.desiredQuestCount(state and state.desiredQuests)
end

function RT.CanRollWithoutWantedQuest()
  return RT.learningQuestList == true
end

local function SetQuestStatus(message)
  if RT.questStatusText then
    RT.questStatusText:SetText(message)
  end

end

function RT.ConfirmUntargetedRoll()
  SetQuestStatus(L.UNTARGETED_ROLL_CONFIRM_PROMPT)

  AutoCallboardSkin.Dialog({
    title = L.UNTARGETED_ROLL_CONFIRM_PROMPT,
    body = L.UNTARGETED_ROLL_CONFIRM_TEXT,
    acceptText = L.BUTTON_YES,
    cancelText = L.BUTTON_NO,
    onAccept = function()
      StartRolling(true)
      end,
    onCancel = function()
      SetQuestStatus(L.UNTARGETED_ROLL_CANCELED)
      end,
  })
end

function RT.ShowAutoCurrentInstanceWarning()
  AutoCallboardSkin.Dialog({
    title = L.AUTO_CURRENT_INSTANCE_LABEL,
    body = Core.autoCurrentInstanceWarningText(),
    acceptText = L.BUTTON_OKAY,
  })
end

local function RequireActiveCallboard(action)
  local access = RT.GetBoardAccessState(action)

  if access.ok then
    return true
  end

  local message = access.message or string.format(L.BOARD_ACCESS_FALLBACK, tostring(action))
  SetQuestStatus(message)

  return false
end

SetRollPause = function(reason, message)
  if not rolling then
    if message then
      SetQuestStatus(message)
    end

    return
  end

  if rollPausedReason == reason and rollPauseMessage == message then
    return
  end

  rollPausedReason = reason
  rollPauseMessage = message
  pendingReroll = false
  nextRollAt = nil
  RT.nextRollStatePollAt = nil
  pendingRerollUntil = nil

  if message then
    SetQuestStatus(message)
  end

  RT.api:Trace("roll", "paused", reason)
end

ClearRollPause = function(reason)
  if reason and rollPausedReason ~= reason then
    return
  end

  if rollPausedReason then
    RT.api:Trace("roll", "resumed", rollPausedReason)
  end

  rollPausedReason = nil
  rollPauseMessage = nil
end

RT.SetManualBoardOpenRequired = function(source)
  RT.manualBoardOpenRequired = true
  RT.objectiveRequestPendingUntil = nil
  RT.nextObjectiveRequestAt = nil
  RT.ClearPendingInteract()
  RT.pendingInteractSource = nil
  SetRollPause("manual_board", L.PAUSED_CLICK_BOARD)
end

local function StartSelectedQuestPause(quest, index)
  if not rolling or not quest then
    return
  end

  if RT.LogRollNote then
    RT.LogRollNote("questSelected", quest.questId, Core.questTitle(quest))
  end

  local zoneOrSort, questType = Core.objectiveMetadata(quest)

  selectedQuest = {
    key = Core.questKey(quest),
    questId = tonumber(quest.questId or quest.id) or 0,
    title = Core.questTitle(quest),
    objectiveText = Core.objectiveText(quest),
    zoneOrSort = zoneOrSort,
    questType = questType,
    selectedAt = GetTime(),
    seenInLog = false,
    seenActiveObjective = false,
  }
  rollCount = 0
  nextSelectedQuestCheckAt = nil
  local selectedLabel = string.format(L.STATUS_PAUSED_SELECTED_QUEST, RT.QuestLabel(quest))
  if index then
    selectedLabel = selectedLabel .. string.format(L.STATUS_PAUSED_SELECTED_SLOT_SUFFIX, tostring(index))
  end
  SetRollPause("quest_selected", selectedLabel .. ".")
end

RT.ShouldHoldObjectiveChoices = function()
  return Core.shouldHoldObjectiveChoices(rolling, rollPausedReason, selectedQuest ~= nil)
end

local function ReleaseInstanceAnchor(signature, key, sticky)
  local entry = satisfiedInstances[signature]

  if entry and entry.key == key then
    entry.sticky = entry.sticky or sticky == true
    return false
  end

  satisfiedInstances[signature] = { key = key, sticky = sticky == true }

  return true
end

local function InstanceQuestStillBlocked(entry)
  if entry.sticky or excludedQuests[entry.key] then
    return true
  end

  local objectives = GetCurrentObjectives()

  for i = 1, #(objectives or {}) do
    if Core.questKey(objectives[i]) == entry.key then
      local questID = tonumber(objectives[i].questId) or 0

      return questID > 0 and type(IsQuestFlaggedCompleted) == "function"
          and IsQuestFlaggedCompleted(questID) == true
    end
  end

  return true
end

local function InstanceTargetForRoll(source)
  local target = RT.RefreshCurrentInstanceQuestTarget(source)
  local entry = target and satisfiedInstances[RT.instanceTargetSignature]

  if not entry then
    return target
  end

  if not InstanceQuestStillBlocked(entry) then
    satisfiedInstances[RT.instanceTargetSignature] = nil
    return target
  end

  local objectives = GetCurrentObjectives()

  for i = 1, #(objectives or {}) do
    if Core.questKey(objectives[i]) == entry.key then
      return target, entry.key
    end
  end

  return nil
end

local function ExclusionsWithCompletedQuests(objectives)
  if type(objectives) ~= "table" or type(IsQuestFlaggedCompleted) ~= "function" then
    return excludedQuests
  end

  local exclusions

  for i = 1, #(objectives) do
    local quest = objectives[i]
    local questID = tonumber(quest and quest.questId) or 0
    local key = Core.questKey(quest)

    if questID > 0 and key and IsQuestFlaggedCompleted(questID) then
      if not exclusions then
        exclusions = {}
        for excludedKey, value in pairs(excludedQuests) do
          exclusions[excludedKey] = value
        end
      end
      exclusions[key] = true
    end
  end

  return exclusions or excludedQuests
end

local function NoteSelectedQuestComplete()
  if not selectedQuest or selectedQuest.seenComplete then
    return
  end

  local questID = tonumber(selectedQuest.questId) or 0

  if questID > 0 and IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(questID) then
    selectedQuest.seenComplete = true
    return
  end

  local found, complete = FindSelectedQuestInLog()

  if found and complete then
    selectedQuest.seenComplete = true
  end
end

local function IsSelectedQuestDone()
  if not selectedQuest then
    return false
  end

  NoteSelectedQuestComplete()

  local questID = tonumber(selectedQuest.questId) or 0
  local activeObjective = GetActiveObjective()
  local activeQuestID = tonumber(activeObjective and activeObjective.questId) or 0

  if activeObjective then
    if (questID > 0 and activeQuestID == questID) or (selectedQuest.title ~= "" and NormalizeQuestTitle(Core.questTitle(activeObjective)) == NormalizeQuestTitle(selectedQuest.title)) then
      selectedQuest.seenActiveObjective = true
      return false
    end

    if selectedQuest.seenActiveObjective then
      return true
    end
  elseif selectedQuest.seenActiveObjective then
    return true
  end

  if questID > 0 and IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(questID) then
    return true
  end

  local found, complete = FindSelectedQuestInLog()
  if found then
    selectedQuest.seenInLog = true
    return complete
  end

  if selectedQuest.seenInLog then
    return true
  end

  return false
end

local function KeyForAbandonedTitle(title)
  local normalized = NormalizeQuestTitle(title or "")
  if normalized == "" then
    return nil
  end

  if selectedQuest and NormalizeQuestTitle(selectedQuest.title) == normalized then
    return selectedQuest.key
  end

  local objectives = GetCurrentObjectives()
  if type(objectives) == "table" then
    for i = 1, #(objectives) do
      if NormalizeQuestTitle(Core.questTitle(objectives[i])) == normalized then
        return Core.questKey(objectives[i])
      end
    end
  end

  return nil
end

local function ExcludeQuestFromRoll(key, source)
  if type(key) ~= "string" or key == "" then
    return false
  end

  excludedQuests[key] = true

  return true
end

function RT.NoteQuestAbandoned(title)
  if ExcludeQuestFromRoll(KeyForAbandonedTitle(title), "abandon") then
    return
  end

  if selectedQuest and NormalizeQuestTitle(title or "") ~= ""
      and NormalizeQuestTitle(selectedQuest.title) ~= NormalizeQuestTitle(title) then
    if GetNumQuestLogEntries and GetQuestLogTitle then
      for index = 1, GetNumQuestLogEntries() do
        local logTitle = GetQuestLogTitle(index)
        if NormalizeQuestTitle(logTitle) == NormalizeQuestTitle(title) then
          return
        end
      end
    end
  end

  lastAbandonAt = GetTime()
end

local function CollectionKeyForQuest(questID, title)
  local desired = state.desiredQuests
  if type(desired) ~= "table" then
    return nil
  end

  local byID = Core.questKey({ questId = questID })
  if byID and desired[byID] then
    return byID
  end

  local byTitle = Core.questKey({ title = title })
  if byTitle and desired[byTitle] then
    return byTitle
  end

  return nil
end

function RT.NoteQuestAccepted(questID, title)
  if not next(excludedQuests) then
    return false
  end

  local key = CollectionKeyForQuest(questID, title)
  if not key or excludedQuests[key] then
    return false
  end

  RT.ClearAbandonedQuestExclusions()

  return true
end

local function SelectedQuestWasAbandoned()
  if not selectedQuest then
    return false
  end

  if selectedQuest.abandoned or (selectedQuest.key and excludedQuests[selectedQuest.key]) then
    return true
  end

  if selectedQuest.seenComplete then
    return false
  end

  if lastAbandonAt and GetTime() - lastAbandonAt <= ABANDON_GRACE then
    ExcludeQuestFromRoll(selectedQuest.key, "abandon grace")
    return true
  end

  return false
end

local function ResumeAfterSelectedQuest(source)
  local title = selectedQuest and selectedQuest.title or L.SELECTED_QUEST_FALLBACK
  local abandoned = SelectedQuestWasAbandoned()
  local instanceSignature = selectedQuest and selectedQuest.instanceSignature

  if not abandoned and selectedQuest and selectedQuest.key then
    local target = RT.RefreshCurrentInstanceQuestTarget("resume")

    if target and Core.questMatchesInstanceTarget(selectedQuest, target) then
      instanceSignature = RT.instanceTargetSignature
    end
  end

  if not abandoned and instanceSignature and selectedQuest.key then
    ReleaseInstanceAnchor(instanceSignature, selectedQuest.key, true)
  end

  if RT.LogRollNote then
    RT.LogRollNote(abandoned and "questAbandoned" or "questGone",
      selectedQuest and selectedQuest.questId, title)
  end

  selectedQuest = nil
  nextSelectedQuestCheckAt = nil
  rollCount = 0
  ClearRollPause("quest_selected")
  nextRollAt = GetTime() + 0.2

  if abandoned then
    SetQuestStatus(string.format(L.QUEST_ABANDONED_RESUMING, title))
    return
  end

  SetQuestStatus(string.format(L.QUEST_DONE_RESUMING, title))
end

local function CheckSelectedQuestProgress(source)
  if not rolling or rollPausedReason ~= "quest_selected" or not selectedQuest then
    return
  end

  local now = GetTime()
  if nextSelectedQuestCheckAt and now < nextSelectedQuestCheckAt then
    return
  end

  nextSelectedQuestCheckAt = now + 1
  lastSelectedQuestScanAt = now

  if IsSelectedQuestDone() then
    ResumeAfterSelectedQuest(source)
  end
end

local function ToggleDesiredQuest(key)
  if type(key) ~= "string" or key == "" then
    return
  end

  local desired = state.desiredQuests
  if desired[key] then
    desired[key] = nil
  else
    desired[key] = true
    excludedQuests[key] = nil
  end

  local entry = RT.EnsureCharacterState()
  if entry and entry.desiredQuests ~= desired then
    entry.desiredQuests = desired
  end

  RT.TouchState()

  if not rolling then
    EvaluateCurrentObjectives()
  end

  RT.RefreshQuestWindow()
end

function RT.CloseObjectiveBoardAfterSelection(source)
  if GossipFrame then
    if GossipFrame.SetAlpha then
      GossipFrame:SetAlpha(1)
    end

    if GossipFrame.EnableMouse then
      GossipFrame:EnableMouse(true)
    end

    if GossipFrame.ClearAllPoints and GossipFrame.SetPoint then
      GossipFrame:ClearAllPoints()
      GossipFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    end
  end

  if GossipFrameCloseButton and GossipFrameCloseButton.Click then
    pcall(GossipFrameCloseButton.Click, GossipFrameCloseButton)
  elseif CloseGossip then
    pcall(CloseGossip)
  elseif GossipFrame and HideUIPanel then
    HideUIPanel(GossipFrame)
  end

  local objectivesUI = EbonAPI.Ebonhold.ObjectivesUI()

  if objectivesUI and objectivesUI.HideObjectives then
    objectivesUI.HideObjectives()
  elseif _G.ObjectivesMainFrame and _G.ObjectivesMainFrame.Hide then
    _G.ObjectivesMainFrame:Hide()
  end

end

local function SelectObjectiveIndex(index)
  if not index then
    return false
  end

  if not RequireActiveCallboard(L.ACTION_SELECT_QUEST) then
    return false
  end

  local objective = GetCurrentObjectives()[index]
  local active = GetActiveObjective()

  if active then
    local activeID = tonumber(active.questId) or 0
    local wantedID = tonumber(objective and objective.questId) or 0

    if activeID ~= wantedID then
      StartSelectedQuestPause(active)
      return false, "active", active
    end
  end

  local boardWasOpen = RT.IsBoardSessionOpen()
  local selected

  local sent, sendProblem = EbonAPI.Ebonhold.SendToServer("REQUEST_SELECT_OBJECTIVE", tostring(index - 1))
  if sent then
    selected = true
  else
    selected = RT.ClickNamedFrame(state.objectivePrefix .. tostring(index) .. "." .. state.objectiveButtonField, string.format(L.OBJECTIVE_LABEL, index))
    if not selected then
      return false, "failed", nil, RT.api:Problem("ROLL.SELECT_FAILED", {
        slot = index,
        questId = objective and objective.questId,
        title = Core.questTitle(objective),
        reason = "no_button",
      }, sendProblem)
    end
  end

  if selected then
    SetQuestStatus(string.format(L.OBJECTIVE_SELECTED_SLOT, index))
    StartSelectedQuestPause(objective, index)

    if boardWasOpen then
      RT.CloseObjectiveBoardAfterSelection("selected slot " .. tostring(index))
    end
  end

  return selected
end

StopRolling = function(message)
  if rolling and RT.LogRollNote then
    RT.LogRollNote("stop", nil, message)
  end

  rolling = false
  RT.rolling = false
  rollPausedReason = nil
  rollPauseMessage = nil
  RT.ClearPendingAcceptUntil()

  if RT.listsWindow and RT.listsWindow:IsShown() then
    RT.RefreshListsWindow()
  end
  RT.manualBoardOpenRequired = false
  RT.objectiveBoardReadyUntil = nil
  RT.objectiveBoardAccessOpen = false
  RT.objectiveRequestPendingUntil = nil
  RT.nextObjectiveRequestAt = nil
  RT.objectiveRequestAttempts = 0
  pendingReroll = false
  nextRollAt = nil
  pendingRerollUntil = nil
  RT.trackedGoldAt = nil
  RT.trackedQuestSpend = 0
  selectedQuest = nil
  RT.learningQuestList = false
  nextSelectedQuestCheckAt = nil
  RT.blockedMatchKey = nil

  if message then
    SetQuestStatus(message)
  end

  UpdateRollToggleButtons()

  if UpdateQuestWindow then
    UpdateQuestWindow()
  end
end

local function HandleMatch(match)
  pendingReroll = false
  nextRollAt = nil
  pendingRerollUntil = nil

  local title = Core.questTitle(match.quest)
  local matchKey = tostring(match.index) .. ":" .. tostring(match.key)
  local matchLabel = match.label or L.MATCH_LABEL_WANTED

  if not RT.IsCallboardReadyForQuestActions() then
    SetRollPause("no_callboard", string.format(L.QUEST_FOUND_WAITING_CALLBOARD, matchLabel, title))
    nextRollAt = GetTime() + ROLL_EVAL_INTERVAL

    if RT.LogRoll then
      RT.LogRoll("blocked", match.index, GetCurrentObjectives())
    end

    if RT.blockedMatchKey ~= matchKey then
      RT.blockedMatchKey = matchKey
      RT.api:Trace("quest", "no_callboard", match.key)
    end
  else
    local selected, blocker, active, selectProblem = SelectObjectiveIndex(match.index)

    if selected then
      if match.source == "currentInstance" and state and state.autoAccept then
        RT.ArmQuestAccept()
      end

      if match.source == "currentInstance" and selectedQuest then
        selectedQuest.instanceSignature = RT.instanceTargetSignature
      end

      RT.blockedMatchKey = nil
      RT.api:Trace("quest", "selected", match.key)
      SetQuestStatus(string.format(L.QUEST_FOUND_SELECTED, matchLabel, title, match.index))

      if RT.LogRoll then
        RT.LogRoll("select", match.index, GetCurrentObjectives())
      end
    elseif blocker == "active" then
      RT.blockedMatchKey = matchKey

      if not rolling then
        SetQuestStatus(string.format(L.QUEST_FOUND_OTHER_OBJECTIVE_ACTIVE, matchLabel, title, RT.QuestLabel(active)))
      end
    else
      local shouldLogBlockedMatch = RT.blockedMatchKey ~= matchKey
      RT.blockedMatchKey = matchKey
      nextRollAt = GetTime() + ROLL_EVAL_INTERVAL

      local failedText = selectProblem and RT.api:ProblemText(selectProblem)
          or string.format(L.QUEST_FOUND_SELECT_FAILED, matchLabel, title, match.index)

      if shouldLogBlockedMatch then
        if selectProblem then
          RT.api:Report(selectProblem)
        end
        SetQuestStatus(failedText)
      elseif RT.questStatusText then
        RT.questStatusText:SetText(failedText)
      end

      SetRollPause("no_callboard", string.format(L.QUEST_FOUND_WAITING_SELECTABLE, matchLabel, title))

      if RT.LogRoll then
        RT.LogRoll("selectFailed", match.index, GetCurrentObjectives())
      end
    end
  end

  if UpdateQuestWindow then
    UpdateQuestWindow()
  end
end

EvaluateCurrentObjectives = function()
  if not RT.HasCurrentObjectiveData() then
    return false
  end

  local objectives = GetCurrentObjectives()
  local currentInstanceTarget, completedInstanceQuestKey = InstanceTargetForRoll("evaluate")
  local exclusions = ExclusionsWithCompletedQuests(objectives)

  if completedInstanceQuestKey then
    if exclusions == excludedQuests then
      exclusions = {}
      for key, value in pairs(excludedQuests) do
        exclusions[key] = value
      end
    end
    exclusions[completedInstanceQuestKey] = true
  end

  local match, releasedInstanceQuestKey =
      Core.findRollObjective(objectives, state.desiredQuests, currentInstanceTarget, exclusions)

  if releasedInstanceQuestKey and currentInstanceTarget then
    ReleaseInstanceAnchor(RT.instanceTargetSignature, releasedInstanceQuestKey, false)
  end

  if match then
    HandleMatch(match)
    return true
  end

  return false
end

ResumeRollingAfterCallboardActive = function(source)
  if not rolling then
    return
  end

  if not RT.IsCallboardDataAvailable() then
    SetRollPause("no_callboard", L.PAUSED_WAITING_CALLBOARD_UI)
    return
  end

  if rollPausedReason == "quest_selected" then
    return
  end

  if rollPausedReason == "no_callboard" or rollPausedReason == "no_wanted" then
    ClearRollPause()
  end

  pendingReroll = false
  pendingRerollUntil = nil
  nextRollAt = GetTime() + 0.2
  lastObjectiveSignature = ObjectiveSignature(CaptureCurrentObjectives())
  SetQuestStatus(L.CALLBOARD_ACTIVE_RESUMING)

  EvaluateCurrentObjectives()
end

function RT.RollDelay()
  return Core.clampRollDelay(state and state.rerollDelay)
end

function RT.RollTimeout()
  return Core.clampRollTimeout(state and state.rerollTimeout)
end

local function RequestObjectiveReroll()
  local service = GetObjectivesService()

  local facts = { rollCount = rollCount, maxRerolls = state.maxRerolls }

  if service and service.RequestRerollObjectives then
    if service.CanAffordReroll and not service.CanAffordReroll() then
      facts.gold = RT.FormatMoney(GetMoney and GetMoney() or 0)
      facts.cost = service.GetRerollCost and RT.FormatMoney(service.GetRerollCost()) or "?"
      return false, RT.api:Problem("ROLL.REROLL_UNAFFORDABLE", facts)
    end

    local ok, err = pcall(service.RequestRerollObjectives)
    if not ok then
      facts.reason = tostring(err)
      facts.detail = string.sub(tostring(err), 1, 60)
      return false, RT.api:Problem("ROLL.REROLL_FAILED", facts)
    end

    RT.api:Trace("reroll", "requested", rollCount)
    return true
  end

  if RT.ClickNamedFrame(state.rerollFrame, "Reroll") then
    return true
  end

  facts.frame = state.rerollFrame
  return false, RT.api:Problem("ROLL.REROLL_CONTROL_MISSING", facts)
end

local function ConfirmRerollPopupIfVisible()
  if StaticPopup_Visible and not StaticPopup_Visible("EBONHOLD_CONFIRM_REROLL") then
    return false
  end

  for i = 1, 4 do
    local popup = _G["StaticPopup" .. tostring(i)]
    if popup and popup:IsShown() and popup.which == "EBONHOLD_CONFIRM_REROLL" then
      local confirmButton = _G["StaticPopup" .. tostring(i) .. "Button1"]
      if confirmButton and confirmButton.Click then
        pcall(confirmButton.Click, confirmButton)
        return true
      end
    end
  end

  return false
end

local function BypassRerollConfirm()
  local ok, problem = RequestObjectiveReroll()
  if not ok then
    return false, problem
  end

  ConfirmRerollPopupIfVisible()
  return true
end

local function ProcessRolling()
  if not rolling then
    return
  end

  local now = GetTime()
  if RT.nextRollStatePollAt and now < RT.nextRollStatePollAt then
    return
  end

  RT.nextRollStatePollAt = now + RT.rollStatePollInterval

  if rollPausedReason == "quest_selected" then
    CheckSelectedQuestProgress("poll")
    return
  end

  local activeObjective = GetActiveObjective()
  if activeObjective then
    StartSelectedQuestPause(activeObjective)
    return
  end

  if nextRollAt and now < nextRollAt then
    return
  end

  if pendingReroll then
    nextRollAt = now + RT.rollPendingPollInterval
  else
    nextRollAt = now + ROLL_EVAL_INTERVAL
  end

  local currentInstanceTarget = RT.RefreshCurrentInstanceQuestTarget("roll")
  if CountDesiredQuests() == 0 and not currentInstanceTarget and not RT.CanRollWithoutWantedQuest() then
    if state and state.autoCurrentInstanceQuest then
      SetRollPause("no_wanted", L.PAUSED_ENTER_INSTANCE_OR_PICK)
    else
      SetRollPause("no_wanted", L.PAUSED_PICK_QUEST)
    end
    return
  end

  if RT.objectiveRequestPendingUntil and GetTime() >= RT.objectiveRequestPendingUntil and not RT.HasCurrentObjectiveData() then
    RT.objectiveRequestPendingUntil = nil
  end

  if not RT.HasCurrentObjectiveData() then
    RT.RequestObjectiveBoardData("roll data refresh")
  end

  if rollPausedReason == "no_wanted" then
    ClearRollPause()
  end

  SyncGoldTracker()
  local objectives = GetCurrentObjectives()
  local signature = ObjectiveSignature(objectives)

  if pendingReroll then

    if signature == lastObjectiveSignature and now < pendingRerollUntil then
      return
    end

    pendingReroll = false
    lastObjectiveSignature = signature

    if EvaluateCurrentObjectives() then
      return
    end

    nextRollAt = now + RT.RollDelay()
    UpdateQuestWindow()
    return
  end

  if EvaluateCurrentObjectives() then
    return
  end

  local boardSessionOpen = RT.IsBoardSessionOpen()

  if not boardSessionOpen and not RT.IsRemoteRollEnabled() then
    if not rollPausedReason then
      SetRollPause("no_callboard", L.PAUSED_WAITING_CALLBOARD_UI)
    end

    nextRollAt = now + ROLL_EVAL_INTERVAL
    return
  end

  if not boardSessionOpen and not RT.HasCurrentObjectiveData() then
    if not rollPausedReason then
      SetRollPause("no_callboard", L.BOARD_ACCESS_DATA_MISSING)
    end

    nextRollAt = now + ROLL_EVAL_INTERVAL
    return
  end

  if rollCount >= state.maxRerolls then
    local text
    if RT.learningQuestList then
      text = string.format(L.ROLL_STOPPED_LEARNED, rollCount, #(state.knownQuests or {}))
    else
      text = string.format(L.ROLL_STOPPED_NOT_FOUND, rollCount)
    end
    StopRolling(text)
    RT.api:Notify(text)
    return
  end

  lastObjectiveSignature = signature

  local rerolled, rerollProblem = BypassRerollConfirm()
  if rerolled then
    rollCount = rollCount + 1
    pendingReroll = true
    pendingRerollUntil = now + RT.RollTimeout()
    nextRollAt = now + RT.rollPendingPollInterval
    SetQuestStatus(string.format(L.REROLL_REQUESTED, rollCount, state.maxRerolls))

    if RT.LogRoll then
      RT.LogRoll("reroll", rollCount, objectives)
    end
  else
    RT.api:Report(rerollProblem)
    StopRolling(RT.api:ProblemText(rerollProblem))
  end
end

local function RefreshQuestWindowIfNeeded(now)
  if not RT.IsQuestWindowShown() then
    return
  end

  now = now or GetTime()
  if nextQuestRefreshAt and now < nextQuestRefreshAt then
    return
  end

  nextQuestRefreshAt = now + QUEST_REFRESH_INTERVAL

  if not RT.CanReadObjectiveChoices() then
    return
  end

  local signature = ObjectiveSignature(GetCurrentObjectives())
  if signature ~= lastCapturedSignature then
    if not RT.ShouldHoldObjectiveChoices() then
      CaptureCurrentObjectives()
    end

    if rolling and not RT.ShouldHoldObjectiveChoices() and EvaluateCurrentObjectives() then
      return
    end

    UpdateQuestWindow()
  end
end

local function WatchCurrentObjectives()
  if not state or not GetObjectivesService() then
    return
  end

  if RT.ShouldHoldObjectiveChoices() then
    return
  end

  local beforeSignature = lastCapturedSignature
  local beforeCount = #(state.knownQuests or {})
  CaptureCurrentObjectives()
  local afterCount = #(state.knownQuests or {})

  if RT.IsQuestWindowShown()
      and (lastCapturedSignature ~= beforeSignature or afterCount ~= beforeCount) then
    UpdateQuestWindow()
  end
end

StartRolling = function(confirmedUntargeted)
  local desiredCount = CountDesiredQuests()
  local currentInstanceTarget = InstanceTargetForRoll("start")
  local autoCurrentInstanceEnabled = state and state.autoCurrentInstanceQuest

  if Core.needsUntargetedRollConfirm(state and state.desiredQuests)
      and not currentInstanceTarget
      and not autoCurrentInstanceEnabled
      and not confirmedUntargeted then
    RT.ConfirmUntargetedRoll()
    return
  end

  rollCount = 0
  RT.trackedQuestSpend = 0
  RT.trackedGoldAt = GetMoney and NormalizeCopper(GetMoney()) or nil
  selectedQuest = nil
  rollPausedReason = nil
  rollPauseMessage = nil
  local activeBoardSession = RT.IsCallboardUiPresent()
      or (RT.objectiveBoardAccessOpen
      and SecondsRemaining(RT.objectiveBoardReadyUntil) > 0)
  RT.manualBoardOpenRequired = false
  if not activeBoardSession then
    RT.objectiveBoardReadyUntil = nil
    RT.objectiveBoardAccessOpen = false
  end
  RT.objectiveRequestPendingUntil = nil
  RT.nextObjectiveRequestAt = nil
  RT.objectiveRequestAttempts = 0
  RT.ClearPendingInteract()
  RT.pendingInteractSource = nil
  nextSelectedQuestCheckAt = nil
  RT.nextRollStatePollAt = nil
  pendingReroll = false
  RT.blockedMatchKey = nil
  RT.learningQuestList = desiredCount == 0 and not autoCurrentInstanceEnabled and not currentInstanceTarget
  rolling = true
  RT.rolling = true

  if RT.listsWindow and RT.listsWindow:IsShown() then
    RT.RefreshListsWindow()
  end

  nextRollAt = GetTime()
  lastObjectiveSignature = ObjectiveSignature(CaptureCurrentObjectives())

  local activeObjective = GetActiveObjective()
  if activeObjective then
    StartSelectedQuestPause(activeObjective)
    return
  end

  if not RT.HasCurrentObjectiveData() then
    RT.RequestObjectiveBoardData("start data refresh")
  end

  if autoCurrentInstanceEnabled and not currentInstanceTarget and desiredCount == 0 then
    SetRollPause("no_wanted", L.PAUSED_ENTER_INSTANCE_OR_PICK)
  elseif RT.learningQuestList then
    SetQuestStatus(L.ROLLING_TO_LEARN)
  elseif not EvaluateCurrentObjectives() then
    if currentInstanceTarget then
      SetQuestStatus(string.format(L.ROLLING_CURRENT_INSTANCE, GetQuestTypeName(currentInstanceTarget.questType), tostring(currentInstanceTarget.name)))
    else
      SetQuestStatus(string.format(L.ROLLING_WANTED_QUESTS, desiredCount))
    end
  end

  UpdateRollToggleButtons()
end

function RT.InstallAbandonQuestHook()
  if RT.abandonQuestHooked or type(hooksecurefunc) ~= "function" then
    return
  end

  local function capture()
    if not GetAbandonQuestName then
      return
    end

    local ok, name = pcall(GetAbandonQuestName)
    if ok and type(name) == "string" and name ~= "" then
      RT.abandonQuestCandidate = name
    end
  end

  local setHooked = true
  if type(SetAbandonQuest) == "function" then
    setHooked = pcall(hooksecurefunc, "SetAbandonQuest", capture)
  end

  if type(AbandonQuest) ~= "function" then
    return
  end

  local hooked = pcall(hooksecurefunc, "AbandonQuest", function()
    RT.api:Guard("abandon.hook", function()
      capture()
      RT.NoteQuestAbandoned(RT.abandonQuestCandidate)
      RT.abandonQuestCandidate = nil
    end)
  end)

  RT.abandonQuestHooked = hooked

  if not hooked or not setHooked then
    RT.api:Degrade(RT.api:Problem("ROLL.ABANDON_HOOK_FAILED", { ["function"] = hooked and "SetAbandonQuest" or "AbandonQuest" }))
  else
    RT.api:Restore("ROLL.ABANDON_HOOK_FAILED")
  end
end

function RT.IsQuestExcludedFromRoll(key)
  return excludedQuests[key] == true
end

function RT.ClearExcludedQuests()
  excludedQuests = {}
  satisfiedInstances = {}
  lastAbandonAt = nil
end

function RT.ClearVisitExclusions()
  if selectedQuest and selectedQuest.key and excludedQuests[selectedQuest.key] then
    selectedQuest.abandoned = true
  end

  excludedQuests = {}
  satisfiedInstances = {}
end

function RT.ClearAbandonedQuestExclusions()
  excludedQuests = {}
  lastAbandonAt = nil
end

function RT.IsRolling()
  return rolling
end

function RT.GetRollPauseReason()
  return rollPausedReason
end

function RT.GetRollPauseMessage()
  return rollPauseMessage
end

function RT.GetRollCount()
  return rollCount
end

function RT.SetNextRollAt(value)
  nextRollAt = value
end

function RT.GetSelectedQuest()
  return selectedQuest
end

function RT.ResetSelectedQuestCheck()
  local soonest = (lastSelectedQuestScanAt or 0) + SELECTED_QUEST_SCAN_FLOOR

  if GetTime() >= soonest then
    nextSelectedQuestCheckAt = nil
  else
    nextSelectedQuestCheckAt = soonest
  end
end

RT.ObjectiveSignature = ObjectiveSignature
RT.CaptureCurrentObjectives = CaptureCurrentObjectives
RT.CountDesiredQuests = CountDesiredQuests
RT.SetQuestStatus = SetQuestStatus
RT.SetRollPause = SetRollPause
RT.ClearRollPause = ClearRollPause
RT.StartSelectedQuestPause = StartSelectedQuestPause
RT.EvaluateCurrentObjectives = EvaluateCurrentObjectives
RT.ResumeRollingAfterCallboardActive = ResumeRollingAfterCallboardActive
RT.ToggleDesiredQuest = ToggleDesiredQuest
RT.StopRolling = StopRolling
RT.RequestObjectiveReroll = RequestObjectiveReroll
RT.SelectObjectiveIndex = SelectObjectiveIndex
RT.StartRolling = StartRolling
RT.ProcessRolling = ProcessRolling
RT.RefreshQuestWindowIfNeeded = RefreshQuestWindowIfNeeded
RT.WatchCurrentObjectives = WatchCurrentObjectives
RT.CheckSelectedQuestProgress = CheckSelectedQuestProgress
RT.ResumeAfterSelectedQuest = ResumeAfterSelectedQuest
