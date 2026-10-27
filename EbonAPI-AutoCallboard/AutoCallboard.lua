local ADDON_NAME = ...
local Core = AutoCallboardCore
local L = AutoCallboardLocale

local RT = AutoCallboardRuntime

RT.api = EbonAPI:NewAddon("AutoCallboard", 2, 1,{ icon = "Achievement_Quests_Completed_08" })

local frame = CreateFrame("Frame")
RT.eventFrame = frame
RT.api:Track("Scheduler", frame)
local characterProfileKey
local state = RT.state

RT.controlCollapsedWidth = 404
RT.controlCollapsedHeight = 44
RT.controlExpandedWidth = 620
RT.controlExpandedHeight = 580
RT.questPanelAnimationSeconds = 0.35
RT.statusPollInterval = 0.25
RT.summonVerifyPollInterval = 0.1
RT.pendingCooldownPollInterval = 0.1
RT.rollStatePollInterval = 0.05

RT.rollPendingPollInterval = 0

local UpdateSummonStatus = RT.UpdateSummonStatus
local QueueCallboardFollowup = RT.QueueCallboardFollowup
local MarkCallboardSummoned = RT.MarkCallboardSummoned

function RT.GetSummonSpellName()
  if not state then
    return ""
  end

  if GetSpellInfo and state.summonSpellID then
    local name = GetSpellInfo(state.summonSpellID)
    if type(name) == "string" and name ~= "" then
      return name
    end
  end

  return state.summonSpell or ""
end

function RT.GetSummonMacroText()
  local spellName = RT.GetSummonSpellName()

  if spellName ~= "" then
    return "/cast " .. spellName
  end

  return nil
end

function RT.FlushQuestStateBackup()
  EbonAPIAutoCallboardQuestDB = nil
end

local function ApplyState(nextState)
  RT.PersistState(nextState)

  RT.RefreshQuestWindow()

  RT.PositionMinimapButton()

  RT.RefreshOptions()
end

function RT.SaveQuestPanelExpanded(expanded)
  if not state or state.questPanelExpanded == expanded then
    return
  end

  state.questPanelExpanded = expanded and true or false
end

function RT.SaveControlFrameShown(shown)
  if not state or state.buttonShown == shown then
    return
  end

  state.buttonShown = shown and true or false
end

local function GetCharacterProfileKey()
  local playerName = UnitName and UnitName("player") or "Unknown"
  local realmName = GetRealmName and GetRealmName() or "UnknownRealm"

  if playerName == "" then
    playerName = "Unknown"
  end

  if realmName == "" then
    realmName = "UnknownRealm"
  end

  return realmName .. "/" .. playerName
end

local function SetUpCharacter()
  characterProfileKey = GetCharacterProfileKey()
  RT.characterProfileKey = characterProfileKey

  RT.RunAccountMigration(characterProfileKey)
  RT.ApplyCharacterState()
  RT.ResetWorldTourProgress()
end

local function CommitStateChange()
  RT.TouchState()
  RT.RefreshQuestWindow()
  RT.PositionMinimapButton()
  RT.RefreshOptions()
end

function RT.SetField(field, value)
  state[field] = value
  CommitStateChange()

  if field == "targetName" then
    RT.SetCallboardButtonText(value)
  elseif field == "summonSpellID" then
    RT.ApplySummonButtonAttributes()
  elseif field == "travelEnabled" then
    RT.OnTravelEnabledChanged()
  elseif field == "travelAuto" then
    RT.OnTravelAutoChanged()
  elseif field == "autoCurrentInstanceQuest" then
    RT.currentInstanceQuestSignature = nil

    RT.InvalidateInstanceTarget()
    RT.RefreshCurrentInstanceQuestTarget("setting")
  elseif field == "showSpeed" then
    RT.LayoutMainToolbar()
  end
end

function RT.SetRollSpeed(delay, timeout, label)
  state.rerollDelay = Core.clampRollDelay(delay)
  state.rerollTimeout = Core.clampRollTimeout(timeout)
  CommitStateChange()

  RT.api:Trace("roll_speed", delay, timeout)
end

local function HandleSlash(input)
  local parsed = Core.parseSlash(input)

  if parsed.kind == "version" then
    RT.ShowAddonHelp("about")
  elseif parsed.kind == "set" then
    RT.SetField(parsed.field, parsed.value)
  elseif parsed.kind == "debug" then
    if RT.HandleDebugAction then
      RT.HandleDebugAction(parsed.action, parsed.value)
    else
      RT.api:Report(RT.api:Problem("BOOT.DEBUG_MODULE_MISSING", { action = tostring(parsed.action) }))
    end
  else
    RT.api:Report(RT.api:Problem("BOOT.SLASH_INVALID", {
      kind = tostring(parsed.kind),
      input = string.sub(tostring(input or ""), 1, 60),
      usage = tostring(parsed.message),
    }))
  end
end

local nextTickAt
local ACTIVE_INTERVAL = 0.066
local IDLE_INTERVAL = 0.25

local UpdateQuestPanelAnimation = RT.UpdateQuestPanelAnimation
local UpdateBrowserAnimations = RT.UpdateBrowserAnimations
local ProcessRolling = RT.ProcessRolling
local RefreshQuestWindowIfNeeded = RT.RefreshQuestWindowIfNeeded
local SyncCallboardActiveFromCooldown = RT.SyncCallboardActiveFromCooldown
local CheckPendingSummonAttempt = RT.CheckPendingSummonAttempt
local SyncPendingSummonCooldown = RT.SyncPendingSummonCooldown
local IsSummonStatusBusy = RT.IsSummonStatusBusy

local indoorTask = { fn = RT.RefreshCallboardButtonEnabled, every = 2 }

local TASKS = {
  { fn = RT.WatchDifficultyChange, every = 0.5 },
  indoorTask,
  { fn = function() return RT.WatchEternalSequence() end, every = 1 },
  { fn = function() return RT.WatchTravelSuggestion() end, every = 1 },
  { fn = function() return RT.ProcessRoutePlayback() end, every = 0.35 },
}

RT.api:Tick("objectives", 0.5, RT.WatchCurrentObjectives)
RT.api:Tick("overlays", 0.5, RT.SyncOverlayFrameLevels)
RT.api:Tick("speed", 0.2, RT.RefreshSpeedDisplay)
RT.api:Tick("routeShare", 1, function() RT.ProcessRouteShare() end)
RT.api:Tick("worldTour", 0.25, function() RT.CheckWorldTourProgress() end)

local function WakeIndoorCheck()
  indoorTask.nextAt = nil
end

local function Busy()
  return RT.rolling
      or RT.questPanelAnimation
      or RT.IsAnyBrowserAnimating()
      or RT.pendingSummonVerifyUntil
      or RT.pendingCooldownSyncUntil
end

local function Awake()
  return RT.IsQuestWindowShown()
      or (RT.listsWindow and RT.listsWindow:IsShown())
      or IsSummonStatusBusy()
end

local function Tick()
  local now = GetTime()

  if Busy() then
    nextTickAt = nil
  else
    if nextTickAt and now < nextTickAt then
      return
    end

    nextTickAt = now + (Awake() and ACTIVE_INTERVAL or IDLE_INTERVAL)
  end

  UpdateQuestPanelAnimation()
  UpdateBrowserAnimations()
  ProcessRolling()
  RefreshQuestWindowIfNeeded(now)
  SyncCallboardActiveFromCooldown("cooldown inference")
  CheckPendingSummonAttempt()
  SyncPendingSummonCooldown()

  for i = 1, #(TASKS) do
    local task = TASKS[i]

    if not task.nextAt or now >= task.nextAt then
      local wait = RT.api:Guard("Scheduler.task", task.fn, now)
      task.nextAt = now + (wait or task.every)
    end
  end

  if IsSummonStatusBusy() then
    if not RT.nextStatusUpdateAt or now >= RT.nextStatusUpdateAt then
      RT.nextStatusUpdateAt = now + RT.statusPollInterval
      UpdateSummonStatus()
    end
    RT.summonStatusWasBusy = true
  elseif RT.summonStatusWasBusy then
    SyncCallboardActiveFromCooldown("status settle")
    RT.nextStatusUpdateAt = nil
    UpdateSummonStatus()
    RT.summonStatusWasBusy = IsSummonStatusBusy()
  end

  if RT.buildsRefreshAt and now >= RT.buildsRefreshAt then
    RT.buildsRefreshAt = nil
    RT.RequestBuildsRefresh("post-connexion")
  end

  if RT.DebugTick then
    RT.DebugTick(now)
  end
end

frame:SetScript("OnUpdate", function()
  RT.api:Guard("Scheduler.tick", Tick)
end)

local EVENTS = {}

local function Dispatch(event, ...)
  if RT.DebugEvent then
    RT.DebugEvent(event, ...)
  end

  local handler = EVENTS[event]
  if handler then
    handler(...)
  end
end

RT.api:TrackFunction("Events", Dispatch)

local events = RT.NewEventRelay(Dispatch)
RT.events = events

local function CreateInterface()
  if InCombatLockdown() then
    RT.api:AfterCombat(CreateInterface)
    return
  end

  RT.CreateCallboardButton()
  RT.CreateMinimapButton()
  RT.ApplyEchoBar()
  RT.InitSettingsAccess()
  RT.RestoreRouteWindow()
end

EVENTS.ADDON_LOADED = function(arg1)
  if arg1 ~= ADDON_NAME then
    return
  end

  events:Unlisten("ADDON_LOADED")
  EVENTS.ADDON_LOADED = nil

  local api = RT.api
  local chosenLanguage = type(EbonAPIAutoCallboardDB) == "table" and EbonAPIAutoCallboardDB.language or nil

  api:Guard("Boot.state", function()
    ApplyState(Core.restoreQuestState(EbonAPIAutoCallboardDB, EbonAPIAutoCallboardQuestDB))
  end)

  api:Guard("Boot.language", function()
    if type(chosenLanguage) == "string" and chosenLanguage ~= ""
        and not EbonAPI:IsLanguageChosen() and RT.IsLanguageAvailable(chosenLanguage) then
      RT.SetLanguage(chosenLanguage)
    end
  end)

  api:Guard("Boot.repair", function()
    RT.RepairKnownQuestState()
    RT.PersistState(Core.migrateLegacyPresets(state, AutoCallboardPresetsDB))
  end)
  api:Guard("Boot.character", SetUpCharacter)
  api:Guard("Boot.hooks", function()
    RT.InstallAbandonQuestHook()
    RT.InstallRouteRecorderHooks()
  end)
  api:Guard("Boot.routes", function()
    RT.ResumeRouteRecording()
    RT.ResumeRoutePlayback()
  end)
  api:Guard("Boot.appearance", RT.InitAppearance)
  api:On("READY", CreateInterface)
  api:On("READY", EVENTS.ZONE_CHANGED_NEW_AREA)
  api:Guard("Boot.bindings", RT.RefreshBindingNames)
  api:Guard("Boot.version", RT.InitVersionWatch)
  api:Guard("Boot.share", RT.InitRouteShare)
  api:Guard("Boot.builds", RT.InitBuilds)
  api:Guard("Boot.languageInit", RT.InitLanguage)
  RT.ListenOptionalEvents()

  RT.buildsRefreshAt = GetTime() + RT.buildsRefreshDelay

  SLASH_AUTOCALLBOARD1 = "/acb"
  SlashCmdList.AUTOCALLBOARD = HandleSlash
end

EVENTS.PLAYER_REGEN_DISABLED = function()
  RT.RefreshEchoBar()
end

EVENTS.PLAYER_REGEN_ENABLED = function()
  RT.RefreshEchoBar()
  RT.CheckWorldTourProgress()
end

EVENTS.PLAYER_LOGOUT = function()
  RT.FlushQuestStateBackup()
end

local function RouteDialogue(source)
  RT.RecordNpcStep(source)
  RT.OnRouteDialogueOpened(source)
end

EVENTS.GOSSIP_SHOW = function()
  local npcName = GossipFrameNpcNameText and GossipFrameNpcNameText:GetText()
  local npcBoard = RT.GetNpcBoardInfo()

  if RT.IsObjectiveBoardName(npcName) or npcBoard then
    RT.MarkObjectiveBoardOpened("GOSSIP_SHOW:" .. tostring(npcName)
        .. ":" .. tostring(npcBoard and npcBoard.objectId or "no-id"))
    return
  end

  RouteDialogue("GOSSIP_SHOW")
end

EVENTS.QUEST_GREETING = function()
  RouteDialogue("QUEST_GREETING")
end

EVENTS.QUEST_PROGRESS = function()
  RouteDialogue("QUEST_PROGRESS")
end

EVENTS.QUEST_COMPLETE = function()
  RouteDialogue("QUEST_COMPLETE")
end

EVENTS.GOSSIP_CLOSED = function()
  RT.MarkObjectiveBoardClosed("GOSSIP_CLOSED")
  RT.EndRouteNpcStep()
end

EVENTS.QUEST_DETAIL = function()
  RouteDialogue("QUEST_DETAIL")

  local acceptUntil = RT.GetPendingAcceptUntil()

  if not (state and state.autoAccept and acceptUntil and GetTime() <= acceptUntil) then
    return
  end

  if RT.IsQuestOfferFromPlayer() then
    RT.api:Trace("auto_accept_skipped", "QUEST_DETAIL", "player_offer")
    return
  end

  RT.ClearPendingAcceptUntil()
  RT.AcceptCurrentQuestOffer("QUEST_DETAIL")
end

EVENTS.QUEST_ACCEPT_CONFIRM = function(_, title)
  RT.routeConfirmTitle = title
  RT.OnRouteDialogueOpened("QUEST_ACCEPT_CONFIRM", title)
end

local function CheckEternalQuest(source, force)
  RT.CheckEternalQuestStillActive(source, force)
end

EVENTS.QUEST_TURNED_IN = function(arg1)
  local questID = tonumber(arg1) or 0
  local selected = RT.GetSelectedQuest()

  RT.CheckWorldTourProgress(questID)
  CheckEternalQuest("QUEST_TURNED_IN", true)

  if selected and questID > 0 and tonumber(selected.questId) == questID then
    RT.ResumeAfterSelectedQuest("QUEST_TURNED_IN")
  else
    RT.ResetSelectedQuestCheck()
    RT.CheckSelectedQuestProgress("QUEST_TURNED_IN")
  end
end

EVENTS.QUEST_REMOVED = function()
  CheckEternalQuest("QUEST_REMOVED", true)
end

EVENTS.QUEST_ACCEPTED = function(arg1, arg2)
  RT.ClearPendingAcceptUntil()
  RT.TrackAcceptedQuest(arg1, arg2)
  RT.ResetSelectedQuestCheck()
  RT.CheckSelectedQuestProgress("QUEST_ACCEPTED")
end

EVENTS.QUEST_LOG_UPDATE = function()
  RT.CheckWorldTourProgress()
  RT.WatchRouteQuestLog()
  RT.RefreshLastAcceptedQuest()
  RT.ResetSelectedQuestCheck()
  RT.CheckSelectedQuestProgress("QUEST_LOG_UPDATE")
  CheckEternalQuest("QUEST_LOG_UPDATE")
end

EVENTS.QUEST_FINISHED = function()
  RT.EndRouteNpcStep()
  RT.ResetSelectedQuestCheck()
  RT.CheckSelectedQuestProgress("QUEST_FINISHED")
  CheckEternalQuest("QUEST_FINISHED")
end

EVENTS.UNIT_SPELLCAST_SUCCEEDED = function(arg1, arg2, arg3, arg4, arg5)
  if arg1 ~= "player" then
    return
  end

  local spellID = tonumber(arg5) or tonumber(arg4) or tonumber(arg3)
  local summonName = RT.GetSummonSpellName()

  if (summonName ~= "" and arg2 == summonName)
      or (state.summonSpellID and spellID == state.summonSpellID) then
    MarkCallboardSummoned("spellcast event")
    QueueCallboardFollowup("spellcast event")
  end
end

EVENTS.SPELL_UPDATE_COOLDOWN = function()
  if RT.StartCallboardTimersFromCooldown("SPELL_UPDATE_COOLDOWN") then
    UpdateSummonStatus()
  end
end

EVENTS.ZONE_CHANGED_NEW_AREA = function()
  RT.InvalidateInstanceTarget()
  RT.NoteInstanceVisit()
  RT.InvalidatePlayerMap()
  WakeIndoorCheck()
  RT.HookRouteCheckpointService()
  RT.LayoutRouteArrow()
end

EVENTS.PLAYER_ENTERING_WORLD = EVENTS.ZONE_CHANGED_NEW_AREA

EVENTS.ZONE_CHANGED = function()
  RT.InvalidatePlayerMap()
  WakeIndoorCheck()
end

EVENTS.ZONE_CHANGED_INDOORS = EVENTS.ZONE_CHANGED

frame:SetScript("OnEvent", function(_, event, ...)
  if RT.DebugEvent and not events:IsListening(event) then
    RT.DebugEvent(event, ...)
  end
end)

events:Listen("ADDON_LOADED")
events:Listen("PLAYER_LOGOUT")
events:Listen("QUEST_DETAIL")
events:Listen("QUEST_PROGRESS")
events:Listen("QUEST_COMPLETE")
events:Listen("QUEST_ACCEPT_CONFIRM")
events:Listen("QUEST_ACCEPTED")
events:Listen("QUEST_LOG_UPDATE")
events:Listen("QUEST_FINISHED")
events:Listen("GOSSIP_SHOW")
events:Listen("GOSSIP_CLOSED")
events:Listen("ZONE_CHANGED_NEW_AREA")
events:Listen("PLAYER_ENTERING_WORLD")
events:Listen("ZONE_CHANGED")

local OPTIONAL_EVENTS = {
  "QUEST_GREETING",
  "ZONE_CHANGED_INDOORS",
  "QUEST_TURNED_IN",
  "QUEST_REMOVED",
  "UNIT_SPELLCAST_SUCCEEDED",
  "SPELL_UPDATE_COOLDOWN",
}

function RT.ListenOptionalEvents()
  for i = 1, #OPTIONAL_EVENTS do
    local event = OPTIONAL_EVENTS[i]

    if not events:Listen(event) then
      RT.api:Degrade(RT.api:Problem("EVENTS.LISTEN_FAILED", { event = event }))
    end
  end
end
