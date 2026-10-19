local Core = AutoCallboardCore
local RT = AutoCallboardRuntime

RT.state = RT.state or Core.defaultState()

function RT.TouchState()
  RT.stateRevision = (RT.stateRevision or 0) + 1
end

local state = RT.state

function RT.PersistState(nextState)
  local adopted = Core.adoptState(nextState)

  for key in pairs(state) do
    state[key] = nil
  end

  for key, value in pairs(adopted) do
    state[key] = value
  end

  EbonAPIAutoCallboardDB = state

  RT.stateRevision = (RT.stateRevision or 0) + 1
end

local NormalizeCopper = RT.NormalizeCopper

local function GetGoldTrackerState()
  if not state then
    return nil
  end

  state.goldTracker = state.goldTracker or {
    totalSpent = 0,
    trackedQuestCount = 0,
    lastQuestSpent = 0,
  }

  return state.goldTracker
end

local function SyncGoldTracker()
  if not GetMoney or not state or RT.trackedGoldAt == nil then
    return 0
  end

  local currentMoney = NormalizeCopper(GetMoney())
  local delta = RT.trackedGoldAt - currentMoney
  local tracker = delta > 0 and GetGoldTrackerState() or nil

  if tracker then
    RT.trackedQuestSpend = (RT.trackedQuestSpend or 0) + delta
    RT.sessionGoldSpent = (RT.sessionGoldSpent or 0) + delta
    tracker.totalSpent = NormalizeCopper((tracker.totalSpent or 0) + delta)
  end

  RT.trackedGoldAt = currentMoney
  if delta > 0 then RT.RefreshGoldDisplay() end
  return math.max(delta, 0)
end

local function FinalizeTrackedQuestSpend()
  local tracker = GetGoldTrackerState()
  if not tracker then
    return 0
  end

  local spent = NormalizeCopper(RT.trackedQuestSpend or 0)

  tracker.trackedQuestCount = math.max(0, math.floor((tracker.trackedQuestCount or 0) + 1))
  tracker.lastQuestSpent = spent
  RT.trackedQuestSpend = 0
  RT.RefreshGoldDisplay()

  return spent
end

RT.GetGoldTrackerState = GetGoldTrackerState
RT.SyncGoldTracker = SyncGoldTracker
RT.FinalizeTrackedQuestSpend = FinalizeTrackedQuestSpend

function RT.RepairKnownQuestState()
  if not state then
    return
  end

  if type(state.knownQuests) ~= "table" then
    local found = state.knownQuests

    state.knownQuests = {}

    if found ~= nil then
      Core.repaired("QUESTS.REPAIRED", { field = "known", value = type(found), kept = 0 }, found)
    end

    RT.TouchState()
    return
  end

  state.knownQuests = Core.copyQuestList(state.knownQuests)
  RT.TouchState()
end
