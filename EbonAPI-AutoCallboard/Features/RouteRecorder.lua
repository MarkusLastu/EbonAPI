local Core = AutoCallboardCore
local RT = AutoCallboardRuntime

local stateDown = false

local function Refresh()
  RT.RefreshRouteWindow()
end

local REOPEN_GRACE = 1.5
local EXPECT_GRACE = 10
local ECHO_GRACE = 0.5
local QUEST_WINDOWS = { QUEST_DETAIL = true, QUEST_PROGRESS = true, QUEST_COMPLETE = true }
local WINDOW_ACTIONS = { accept = true, complete = true, turnin = true }

local gossipCache = { available = {}, active = {}, options = {} }
local currentStep
local stepClosedAt
local hookedServices = setmetatable({}, { __mode = "k" })
local questItem
local window
local questLog
local readingLog = false
local echoed = false
local echoUntil = 0
local expected = {}

local function CharacterState()
  return RT.EnsureCharacterState()
end

function RT.GetRouteDraft()
  local entry = CharacterState()

  if not entry then
    if not stateDown then
      stateDown = true
      RT.api:Degrade(RT.api:Problem("RECORDER.STATE_UNAVAILABLE", {}))
    end

    return {}
  end

  if stateDown then
    stateDown = false
    RT.api:Restore("RECORDER.STATE_UNAVAILABLE")
  end

  if type(entry.routeDraft) ~= "table" then
    entry.routeDraft = {}
  end

  return entry.routeDraft
end

function RT.ClearRouteDraft()
  local entry = CharacterState()

  if entry then
    entry.routeDraft = {}
  end

  currentStep = nil
  RT.TouchState()
  Refresh()
end

local function CharacterFlag(key)
  local entry = CharacterState()

  return entry and entry[key] and true or false
end

local function SetCharacterFlag(key, on)
  local entry = CharacterState()

  if not entry then
    return
  end

  entry[key] = on and true or false
  RT.TouchState()
end

RT.RefreshRoutePanel = Refresh

local function RemoveValue(list, value)
  for i = #(list), 1, -1 do
    if list[i] == value then
      table.remove(list, i)
    end
  end
end

local function PushStep(step)
  local draft = RT.GetRouteDraft()

  if #(draft) >= Core.MAX_ROUTE_STEPS then
    RT.api:Report(RT.api:Problem("RECORDER.DRAFT_FULL", { max = Core.MAX_ROUTE_STEPS }))
    RT.StopRouteRecording("full")
    return nil
  end

  table.insert(draft, step)
  RT.TouchState()
  Refresh()

  return step
end

local function Expect(on, action)
  if RT.IsRecordingRoute() and action and type(action.title) == "string" and action.title ~= "" then
    expected[action.title] = { on = on, at = GetTime(), step = currentStep, action = action }
  end
end

local function DropStaleExpectations(snapshot)
  local now = GetTime()
  local present = {}

  for _, quest in pairs(snapshot) do
    present[quest.title] = true
  end

  for title, wait in pairs(expected) do
    if now - wait.at > EXPECT_GRACE then
      expected[title] = nil

      if wait.on == "in" and wait.step and not present[title] then
        local removed = "action"

        if wait.step.kind == "quest" and #(wait.step.actions) <= 1 then
          removed = "step"
        end

        RT.api:Repaired("RECORDER.ACTION_UNCONFIRMED", { title = title, seconds = EXPECT_GRACE, removed = removed }, wait.action)
        RemoveValue(wait.step.actions, wait.action)

        if wait.step.kind == "quest" and #(wait.step.actions) == 0 then
          RemoveValue(RT.GetRouteDraft(), wait.step)
          currentStep = currentStep ~= wait.step and currentStep or nil
        end

        RT.TouchState()
        Refresh()
      end
    end
  end
end

function RT.IsRecordingRoute()
  return CharacterFlag("routeRecording")
end

function RT.StartRouteRecording(source)
  if RT.IsRecordingRoute() or RT.IsPlayingRoute() then
    RT.api:Report(RT.api:Problem("RECORDER.RECORD_BUSY", { state = RT.IsRecordingRoute() and "recording" or "playing" }))
    return false
  end

  SetCharacterFlag("routeRecording", true)
  currentStep = nil
  stepClosedAt = nil
  window = nil
  expected = {}
  RT.WatchRouteQuestLog(true)
  RT.api:Trace("route", "recording_started", source)
  Refresh()

  return true
end

function RT.StopRouteRecording(source)
  if not RT.IsRecordingRoute() then
    return false
  end

  RT.WatchRouteQuestLog()
  SetCharacterFlag("routeRecording", false)
  currentStep = nil
  stepClosedAt = nil
  RT.api:Trace("route", "recording_stopped", source)
  Refresh()

  return true
end

function RT.ResumeRouteRecording()
  if not RT.IsRecordingRoute() then
    return false
  end

  currentStep = nil
  stepClosedAt = nil

  return true
end

local function GossipStride(values, count)
  if count <= 0 then
    return 0
  end

  if count <= 5 then
    return count
  end

  local candidates = { 3, 4, 5 }

  for i = 1, #(candidates) do
    local stride = candidates[i]

    if count % stride == 0 and type(values[stride + 1]) == "string" then
      return stride
    end
  end

  return count
end

RT.RouteGossipStride = GossipStride

local function packReturns(...)
  return select("#", ...), { ... }
end

local GOSSIP_OPTION_STRIDE = 2

local function ReadGossipQuests(reader, fixedStride)
  local entries = {}

  if type(reader) ~= "function" then
    return entries
  end

  local ok, count, values = pcall(function() return packReturns(reader()) end)

  if not ok or type(count) ~= "number" or count <= 0 then
    return entries
  end

  local stride = fixedStride or GossipStride(values, count)

  if stride <= 0 then
    return entries
  end

  for i = 1, count, stride do
    local title = values[i]

    if type(title) == "string" and title ~= "" then
      table.insert(entries, { title = title, complete = stride >= 4 and values[i + 3] and true or false })
    end
  end

  return entries
end

local function QuestIdByTitle(title)
  if type(title) ~= "string" or title == "" or not GetNumQuestLogEntries then
    return nil
  end

  for i = 1, GetNumQuestLogEntries() do
    local entry = RT.GetQuestLogEntryInfo(i)

    if entry and not entry.isHeader and entry.title == title and tonumber(entry.questID) then
      return tonumber(entry.questID)
    end
  end

  return nil
end

RT.RouteQuestIdByTitle = QuestIdByTitle

local function ReadGreetingList(countFn, titleFn)
  local entries = {}

  if type(countFn) ~= "function" or type(titleFn) ~= "function" then
    return entries
  end

  local ok, count = pcall(countFn)

  if not ok or type(count) ~= "number" then
    return entries
  end

  for i = 1, count do
    local titleOk, title = pcall(titleFn, i)

    if titleOk and type(title) == "string" and title ~= "" then
      table.insert(entries, { title = title })
    end
  end

  return entries
end

local function CaptureNpc()
  local guid = UnitGUID and UnitGUID("npc") or nil
  local name = UnitName and UnitName("npc") or nil

  return RT.ExtractBoardObjectIdFromGuid(guid), (type(name) == "string" and name or "")
end

local function CaptureSpot(step)
  step.resting = RT.IsDifficultyChangeAllowedHere()
  step.zone = (GetRealZoneText and GetRealZoneText()) or ""

  local map, x, y = RT.ReadPlayerMapPoint()

  step.map = map
  step.x = x
  step.y = y

  return step
end

local function ResolveActive(entries)
  for i = 1, #(entries) do
    entries[i].questId = QuestIdByTitle(entries[i].title)
  end

  return entries
end

local function IsCurrentStep(kind, key, value)
  if not currentStep or currentStep.kind ~= kind or currentStep[key] ~= value then
    return false
  end

  return not stepClosedAt or (GetTime() - stepClosedAt) < REOPEN_GRACE
end

function RT.EndRouteNpcStep()
  questItem = nil

  if currentStep then
    stepClosedAt = GetTime and GetTime() or 0
  end
end

function RT.RouteWindowTitle(source)
  if QUEST_WINDOWS[source] and not CaptureNpc() then
    return RT.GetQuestOfferTitle()
  end

  return nil
end

function RT.ReadLiveGossipQuests()
  local available = ReadGossipQuests(GetGossipAvailableQuests)
  local active = ResolveActive(ReadGossipQuests(GetGossipActiveQuests))
  local options = ReadGossipQuests(GetGossipOptions, GOSSIP_OPTION_STRIDE)

  if #(available) == 0 and #(active) == 0 then
    available = ReadGreetingList(GetNumAvailableQuests, GetAvailableTitle)
    active = ResolveActive(ReadGreetingList(GetNumActiveQuests, GetActiveTitle))
  end

  if #(active) == 0 and (RT.FrameIsVisibleOrShown(QuestFrameProgressPanel)
      or RT.FrameIsVisibleOrShown(QuestFrameRewardPanel)) then
    active = ResolveActive({ { title = RT.GetQuestOfferTitle() } })
  end

  return available, active, options
end

function RT.RecordNpcStep(source)
  if not RT.IsRecordingRoute() then
    return nil
  end

  local npcId, npcName = CaptureNpc()

  if QUEST_WINDOWS[source] then
    window = { npcId = npcId, item = questItem }

    if not npcId then
      return nil
    end
  end

  if IsCurrentStep("npc", "npcId", npcId) then
    return currentStep
  end

  gossipCache.available, gossipCache.active, gossipCache.options = RT.ReadLiveGossipQuests()

  local step = PushStep(CaptureSpot({
    kind = "npc",
    npcId = npcId,
    npcName = npcName,
    available = gossipCache.available,
    active = gossipCache.active,
    actions = {},
  }))

  if step then
    currentStep = step
    stepClosedAt = nil
  end

  return step
end

local function AppendAction(action)
  if not RT.IsRecordingRoute() or type(action) ~= "table" then
    return nil
  end

  local giver = window or { npcId = CaptureNpc() }

  if action.kind == "confirm" or (WINDOW_ACTIONS[action.kind] and not giver.npcId) then
    if not IsCurrentStep("quest", "title", action.title) then
      currentStep = PushStep(CaptureSpot({ kind = "quest", title = action.title,
        item = action.kind ~= "confirm" and giver.item or nil, actions = {} }))
      stepClosedAt = nil
    end
  elseif not currentStep or currentStep.kind ~= "npc" then
    currentStep = RT.RecordNpcStep("implicit")
  end

  if not currentStep then
    return nil
  end

  local copy = Core.copyRouteAction(action)

  if not copy then
    RT.api:Reject("RECORDER.ACTION_REJECTED", { kind = action.kind, title = action.title })
    return nil
  end

  table.insert(currentStep.actions, copy)
  RT.TouchState()
  Refresh()

  return copy
end

function RT.RecordRouteTravel(checkpointId)
  if not RT.IsRecordingRoute() then
    return nil
  end

  checkpointId = tonumber(checkpointId)

  if not checkpointId or checkpointId <= 0 then
    return nil
  end

  currentStep = nil
  stepClosedAt = nil

  return PushStep(CaptureSpot({
    kind = "travel",
    checkpoint = checkpointId,
    checkpointName = Core.routeCheckpointName(checkpointId),
  }))
end

local function ScanQuestLog()
  local count, quests = GetNumQuestLogEntries()
  local snapshot, seen, collapsed = {}, 0, {}

  for index = 1, (tonumber(count) or 0) + (tonumber(quests) or 0) do
    local entry = RT.GetQuestLogEntryInfo(index)

    if entry and entry.isHeader then
      collapsed[entry.title] = entry.isCollapsed and true or nil
    elseif entry and entry.questID and not snapshot[entry.questID] then
      snapshot[entry.questID] = { title = entry.title, complete = entry.isComplete == 1 }
      seen = seen + 1
    end
  end

  return snapshot, seen >= (tonumber(quests) or seen), collapsed, seen, tonumber(quests) or seen
end

local function ReadQuestLog()
  local snapshot, complete, collapsed, seen, total = ScanQuestLog()

  if not complete and next(collapsed) then
    readingLog, echoed = true, false
    ExpandQuestHeader(0)
    local rescanned
    snapshot, complete, rescanned, seen, total = ScanQuestLog()

    for index = GetNumQuestLogEntries(), 1, -1 do
      local entry = RT.GetQuestLogEntryInfo(index)

      if entry and entry.isHeader and collapsed[entry.title] then
        CollapseQuestHeader(index)
      end
    end

    readingLog = false
    echoUntil = echoed and 0 or GetTime() + ECHO_GRACE
  end

  return complete and snapshot or nil, seen, total
end

local function ResolveQuestTitle(title, questId)
  for _, step in ipairs(RT.GetRouteDraft()) do
    if step.kind == "quest" and not step.on and step.title == title and not step.questId then
      step.questId = questId
    end

    for _, action in ipairs(step.actions or {}) do
      if action.kind == "available" and action.title == title and not action.questId then
        action.questId = questId
      end
    end
  end
end

local function RecordQuestChange(change)
  local wait = expected[change.title]

  if wait and wait.on == change.on then
    expected[change.title] = nil
    wait.action.questId = change.questId

    if change.on == "in" then
      ResolveQuestTitle(change.title, change.questId)
    end

    RT.TouchState()
    Refresh()
    return
  end

  change.actions = {}
  PushStep(CaptureSpot(change))
end

function RT.WatchRouteQuestLog(reset)
  if readingLog then
    echoed = true
    return
  end

  local recording = RT.IsRecordingRoute()

  if reset or not (recording or RT.IsPlayingRoute()) then
    questLog = nil
  end

  if not (recording or RT.IsPlayingRoute()) or (not reset and GetTime() < echoUntil) then
    return
  end

  local before = questLog
  local snapshot, seen, total = ReadQuestLog()

  if not snapshot then
    RT.api:Reject("RECORDER.QUESTLOG_UNREADABLE", { seen = seen, total = total })
    return
  end

  questLog = snapshot

  if not before then
    return
  end

  for _, change in ipairs(Core.questLogChanges(before, snapshot)) do
    if recording then
      RecordQuestChange(change)
    else
      RT.PlayRouteQuestChange(change)
    end
  end

  if recording then
    DropStaleExpectations(snapshot)
  end
end

local function CachedTitle(list, index)
  local entry = list and list[tonumber(index) or 0]

  if type(entry) ~= "table" then
    return "", nil
  end

  return tostring(entry.title or ""), tonumber(entry.questId)
end

local function InstallHook(name, handler)
  if type(_G[name]) ~= "function" then
    RT.api:Degrade(RT.api:Problem("RECORDER.HOOK_MISSING", { missing = name }))
    return false
  end

  hooksecurefunc(name, handler)

  return true
end

function RT.HookRouteCheckpointService()
  local service = EbonAPI.Ebonhold.Checkpoints()

  if not service or type(service.UseCheckpoint) ~= "function" then
    RT.api:Degrade(RT.api:Problem("RECORDER.CHECKPOINTS_UNAVAILABLE", {}))
    return false
  end

  if hookedServices[service] then
    return true
  end

  RT.api:Restore("RECORDER.CHECKPOINTS_UNAVAILABLE")

  local original = service.UseCheckpoint

  local function after(checkpointId, result, ...)
    if result == false then
      RT.api:Report(RT.api:Problem("RECORDER.CHECKPOINT_NOT_USED", { checkpoint = checkpointId }))
    else
      RT.RecordRouteTravel(checkpointId)
    end

    return result, ...
  end

  service.UseCheckpoint = function(checkpointId, ...)
    return after(checkpointId, original(checkpointId, ...))
  end

  hookedServices[service] = true

  return true
end

function RT.InstallRouteRecorderHooks()
  if RT.routeRecorderHooked then
    return
  end

  RT.routeRecorderHooked = true

  InstallHook("SelectGossipOption", function(index)
    local text = CachedTitle(gossipCache.options, index)
    AppendAction({ kind = "gossip", index = index, text = text })
  end)

  InstallHook("SelectGossipAvailableQuest", function(index)
    local title = CachedTitle(gossipCache.available, index)
    AppendAction({ kind = "available", index = index, title = title })
  end)

  InstallHook("SelectGossipActiveQuest", function(index)
    local title, questId = CachedTitle(gossipCache.active, index)
    AppendAction({ kind = "active", index = index, title = title, questId = questId })
  end)

  InstallHook("SelectAvailableQuest", function(index)
    local title = CachedTitle(gossipCache.available, index)
    AppendAction({ kind = "available", index = index, title = title })
  end)

  InstallHook("SelectActiveQuest", function(index)
    local title, questId = CachedTitle(gossipCache.active, index)
    AppendAction({ kind = "active", index = index, title = title, questId = questId })
  end)

  InstallHook("AcceptQuest", function()
    Expect("in", AppendAction({ kind = "accept", title = RT.GetQuestOfferTitle() }))
  end)

  InstallHook("ConfirmAcceptQuest", function()
    Expect("in", AppendAction({ kind = "confirm", title = RT.routeConfirmTitle }))
  end)

  InstallHook("CompleteQuest", function()
    AppendAction({ kind = "complete", title = RT.GetQuestOfferTitle() })
  end)

  InstallHook("GetQuestReward", function(choice)
    local title = RT.GetQuestOfferTitle()
    Expect("out", AppendAction({ kind = "turnin", reward = tonumber(choice), title = title, questId = QuestIdByTitle(title) }))
  end)

  InstallHook("UseContainerItem", function(bag, slot)
    if not RT.IsRecordingRoute() or not GetContainerItemQuestInfo then
      return
    end

    local _, questId, active = GetContainerItemQuestInfo(bag, slot)

    if questId and not active then
      questItem = GetContainerItemLink(bag, slot)
    end
  end)

  hooksecurefunc(RT, "NoteQuestAbandoned", function(title)
    Expect("out", { title = title })
  end)

  RT.HookRouteCheckpointService()
end

function RT.SaveRouteDraftAs(name, category)
  local draft = RT.GetRouteDraft()

  if #(draft) == 0 then
    RT.api:Report(RT.api:Problem("RECORDER.DRAFT_EMPTY", { what = "save" }))
    return nil
  end

  local nextProfile, entry, err = Core.createRoute(RT.GetAccountProfile(), draft, name, category)

  if err == "full" then
    RT.api:Report(RT.api:Problem("RECORDER.ROUTES_FULL", { max = Core.MAX_SAVED_ROUTES, category = category }))
    return nil
  end

  if not entry then
    RT.api:Report(RT.api:Problem("RECORDER.ROUTE_NOT_SAVED", { name = name, category = category, reason = err }))
    return nil
  end

  RT.SaveAccountProfile(nextProfile)
  RT.ClearRouteDraft()

  if entry then
    RT.SetActiveRouteId(entry.id)
  end

  return entry
end

function RT.CanEditRoutes()
  return not RT.IsPlayingRoute()
end

local function ApplyDraftToRoute(what, update, id)
  if not RT.CanEditRoutes() then
    RT.api:Report(RT.api:Problem("RECORDER.EDIT_LOCKED", { what = what }))
    return false
  end

  local draft = RT.GetRouteDraft()

  if #(draft) == 0 then
    RT.api:Report(RT.api:Problem("RECORDER.DRAFT_EMPTY", { what = what }))
    return false
  end

  local nextProfile, ok = update(RT.GetAccountProfile(), id, draft)

  if not ok then
    RT.api:Report(RT.api:Problem("RECORDER.ROUTE_NOT_UPDATED", { route = id, reason = "unknown_route" }))
    return false
  end

  RT.SaveAccountProfile(nextProfile)
  RT.ClearRouteDraft()

  return true
end

function RT.OverwriteRouteFromDraft(id)
  return ApplyDraftToRoute("overwrite", Core.setRouteSteps, id)
end

function RT.AppendRouteFromDraft(id)
  return ApplyDraftToRoute("append", Core.appendRouteSteps, id)
end

function RT.GetActiveRouteId()
  local entry = CharacterState()

  return entry and tonumber(entry.activeRouteId) or nil
end

function RT.SetActiveRouteId(id)
  local entry = CharacterState()

  if not entry then
    if not stateDown then
      stateDown = true
      RT.api:Degrade(RT.api:Problem("RECORDER.STATE_UNAVAILABLE", {}))
    end

    return
  end

  if stateDown then
    stateDown = false
    RT.api:Restore("RECORDER.STATE_UNAVAILABLE")
  end

  entry.activeRouteId = tonumber(id)
  RT.TouchState()
  Refresh()
end

function RT.GetActiveRoute()
  local id = RT.GetActiveRouteId()

  if not id then
    return nil
  end

  return Core.findRoute(RT.GetAccountProfile(), id)
end

function RT.IsPlayingRoute()
  return CharacterFlag("routePlaying")
end

function RT.SetRoutePlaying(playing)
  SetCharacterFlag("routePlaying", playing)
end

function RT.ResumeRoutePlayback()
  if not RT.IsPlayingRoute() then
    return false
  end

  local route = RT.GetActiveRoute()

  if not route then
    RT.SetRoutePlaying(false)
    RT.api:Report(RT.api:Problem("RECORDER.ACTIVE_ROUTE_MISSING", { route = RT.GetActiveRouteId() }))
    return false
  end

  RT.ResetRoutePlayback()
  RT.SetRouteCursor(RT.StoredRouteCursor())
  RT.PointRouteArrowAtNextStep(route, RT.RouteCursor())

  return true
end

function RT.StoredRouteCursor()
  local entry = CharacterState()

  return entry and tonumber(entry.routeCursor) or 0, entry and tonumber(entry.routeStart) or 1
end

function RT.StoreRouteCursor(index, start)
  local entry = CharacterState()

  if not entry then
    return
  end

  entry.routeCursor = tonumber(index) or 0
  entry.routeStart = tonumber(start) or 1
  RT.TouchState()
end

function RT.StartRoutePlayback(source, routeId, from)
  if RT.IsRecordingRoute() then
    RT.api:Report(RT.api:Problem("RECORDER.PLAY_BUSY", { state = "recording" }))
    return false
  end

  if tonumber(routeId) and tonumber(routeId) ~= RT.GetActiveRouteId() then
    if not Core.findRoute(RT.GetAccountProfile(), tonumber(routeId)) then
      RT.api:Report(RT.api:Problem("RECORDER.ACTIVE_ROUTE_MISSING", { route = routeId }))
      return false
    end

    RT.SetActiveRouteId(routeId)
  end

  local route = RT.GetActiveRoute()

  if not route then
    RT.api:Report(RT.api:Problem("RECORDER.NO_ROUTE_LOADED", {}))
    return false
  end

  local playable, faction = Core.canPlayRoute(route, RT.PlayerFaction())

  if not playable then
    RT.api:Report(RT.api:Problem("RECORDER.WRONG_FACTION", { route = route.name, faction = Core.factionLabel(faction) }))
    return false
  end

  RT.SetRoutePlaying(true)
  RT.WatchRouteQuestLog(true)
  RT.BeginRoutePlaybackRun(route, from)
  Refresh()

  return true
end

function RT.StopRoutePlayback(source)
  if not RT.IsPlayingRoute() then
    return false
  end

  RT.SetRoutePlaying(false)
  RT.ResetRoutePlayback()
  RT.ClearRouteArrowTarget()
  RT.api:Trace("route", "playback_stopped", source)
  Refresh()

  return true
end

function RT.ToggleRoutePlayback()
  if RT.IsPlayingRoute() then
    return RT.StopRoutePlayback("toggle")
  end

  return RT.StartRoutePlayback("toggle")
end

Core.routeQuestTitleLookup = function(questId)
  local index, entry = RT.FindQuestLogIndexByID(questId)

  if index and entry then
    return entry.title
  end

  return nil
end

function RT.LastRecordedRouteLine()
  local draft = RT.GetRouteDraft()
  local step = draft[#(draft)]

  if not step then
    return ""
  end

  if step.actions then
    local action = step.actions[#(step.actions)]

    if action then
      local text = Core.routeActionLine(action)

      if text ~= "" then
        return text
      end
    end
  end

  return Core.routeStepLine(step)
end

function RT.IsRouteWindowOpen()
  return CharacterFlag("routeWindowOpen")
end

function RT.SetRouteWindowOpen(open)
  SetCharacterFlag("routeWindowOpen", open)
end

function RT.IsRouteWindowCompact()
  return CharacterFlag("routeCompact")
end

function RT.SetRouteWindowCompact(compact)
  SetCharacterFlag("routeCompact", compact)
  Refresh()
end

function RT.IsRouteLooping()
  return CharacterFlag("routeLoop")
end

function RT.SetRouteLooping(loop)
  SetCharacterFlag("routeLoop", loop)
  Refresh()
end
