local Core = AutoCallboardCore
local RT = AutoCallboardRuntime
local L = AutoCallboardLocale

local transitions = {
  { questId = 600602, checkpoint = "10044", title = "End of the Line: Kelthuzad", destination = "Obsidian Sanctum (OS)" },
  { questId = 600600, checkpoint = "10039", title = "The Fall of Sartharion", destination = "Eye of Eternity (EoE)" },
}
local completed = {}
local pending = {}

local function IsActive()
  return RT.GetActiveSelectionId() == Core.WORLD_TOUR_SELECTION_ID
end

local function IsComplete(questId)
  local _, entry = RT.FindQuestLogIndexByID(questId)

  if entry and (entry.isComplete == true or entry.isComplete == 1) then
    return true
  end

  return type(IsQuestFlaggedCompleted) == "function" and IsQuestFlaggedCompleted(questId) == true
end

function RT.ResetWorldTourProgress()
  completed = {}
  pending = {}

  if IsActive() then
    for _, transition in ipairs(transitions) do
      completed[transition.questId] = IsComplete(transition.questId)
    end
  end
end

function RT.CheckWorldTourProgress(turnedInQuestId)
  if not IsActive() then
    completed = {}
    pending = {}
    return
  end

  for _, transition in ipairs(transitions) do
    local questId = transition.questId

    if not completed[questId] and (turnedInQuestId == questId or IsComplete(questId)) then
      completed[questId] = true
      pending[#pending + 1] = { transition = transition, readyAt = GetTime() + 1, attempts = 0 }
    end
  end

  local request = pending[1]

  if not request then
    return
  end

  if (InCombatLockdown and InCombatLockdown())
      or (UnitAffectingCombat and UnitAffectingCombat("player")) then
    request.readyAt = GetTime() + 1
    return
  end

  if GetTime() < request.readyAt then
    return
  end

  local transition = request.transition
  local sent = EbonAPI.Ebonhold.SendToServer("REQUEST_USE_CHECKPOINT", transition.checkpoint)

  if sent then
    table.remove(pending, 1)
    DEFAULT_CHAT_FRAME:AddMessage(string.format(L.WORLD_TOUR_TELEPORT, transition.title, transition.destination))
  else
    request.attempts = request.attempts + 1
    request.readyAt = GetTime() + 1

    if request.attempts >= 3 then
      table.remove(pending, 1)
      DEFAULT_CHAT_FRAME:AddMessage(string.format(L.WORLD_TOUR_TELEPORT_FAILED, transition.destination))
    end
  end
end