local Core = AutoCallboardCore
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local state = RT.state

RT.difficultyPollInterval = 0.5
RT.difficultyIdlePollInterval = 2

function RT.GetHardmodeService()
  return EbonAPI.Ebonhold.Hardmode()
end

function RT.GetCurrentDifficulty()
  local service = RT.GetHardmodeService()

  if service and service.GetCurrentDifficulty then
    local tier = RT.api:Guard("Difficulty.read", service.GetCurrentDifficulty)
    local sanitized = Core.sanitizeDifficulty(tier)
    if sanitized then
      return sanitized
    end
  end

  if EbonAPI.Ebonhold.IsPresent() then
    return Core.sanitizeDifficulty(EbonAPI.Ebonhold.CurrentHardmodeTier())
  end

  return nil
end

function RT.IsDifficultyChangeAllowedHere()
  local level = UnitLevel and tonumber(UnitLevel("player")) or 0
  if level <= 10 then
    return true
  end

  return (IsResting and IsResting()) and true or false
end

function RT.CanApplyDifficulty()
  if UnitAffectingCombat and UnitAffectingCombat("player") then
    return false
  end

  return RT.IsDifficultyChangeAllowedHere()
end

function RT.GetActiveSelectionDifficulty()
  if not state then
    return nil
  end

  local selection = Core.findSelection(RT.GetAccountProfile(), RT.GetActiveSelectionId())
  if not selection then
    return nil
  end

  return Core.sanitizeDifficulty(selection.difficulty)
end

function RT.ApplyListDifficulty(tier, source)
  tier = Core.sanitizeDifficulty(tier)

  if not tier then
    return
  end

  if RT.GetCurrentDifficulty() == tier then
    return
  end

  local service = RT.GetHardmodeService()
  if not service or not service.SetDifficulty then
    local problem = RT.api:Problem("DIFFICULTY.SERVICE_MISSING", { tier = Core.difficultyLabel(tier), source = tostring(source) })
    RT.api:Report(problem)
    return nil, problem
  end

  if service.SetDifficulty(tier) == false then
    local problem = RT.api:Problem("DIFFICULTY.SET_REFUSED", { tier = Core.difficultyLabel(tier), source = tostring(source) })
    RT.api:Report(problem)
    return nil, problem
  end
end

function RT.WatchDifficultyChange()
  local listsWindow = RT.listsWindow
  local listsShown = listsWindow and listsWindow:IsShown()
  local watched = listsShown or RT.IsQuestWindowShown()
  local delay = watched and RT.difficultyPollInterval or RT.difficultyIdlePollInterval

  local current = RT.GetCurrentDifficulty()
  local difficultyChanged = current ~= RT.lastSeenDifficulty

  local canApplyChanged = false
  if listsShown then
    local canApply = RT.CanApplyDifficulty()
    if canApply ~= RT.lastCanApplyDifficulty then
      canApplyChanged = true
      RT.lastCanApplyDifficulty = canApply
    end
  end

  if not difficultyChanged and not canApplyChanged then
    return delay
  end

  if difficultyChanged then
    local previous = RT.lastSeenDifficulty
    RT.lastSeenDifficulty = current

    if previous ~= nil and current ~= nil then
      RT.api:Trace("difficulty_changed", previous, current)
    end

    RT.RefreshQuestWindow()
  end

  if listsShown then
    RT.RefreshListsWindow()
  end

  return delay
end

function RT.FormatDifficultyStatus()
  local current = RT.GetCurrentDifficulty()

  if not current then
    return ""
  end

  local text = string.format(L.DIFFICULTY_STATUS_SUFFIX, Core.difficultyLabel(current))
  local wanted = RT.GetActiveSelectionDifficulty()

  if wanted and wanted ~= current then
    text = text .. string.format(L.DIFFICULTY_STATUS_WANTED_SUFFIX, Core.difficultyLabel(wanted))
  end

  return text
end

function RT.RequestSetSelectionDifficulty(entry, tier)
  if not entry or entry.id == nil then
    return
  end

  local nextProfile, ok = Core.setSelectionDifficulty(RT.GetAccountProfile(), entry.id, tier)
  if not ok then
    RT.api:Report(RT.api:Problem("DIFFICULTY.SELECTION_REFUSED", {
      entryId = tostring(entry.id),
      tier = tier ~= nil and Core.difficultyLabel(tier) or "none",
    }))
    return
  end

  RT.SaveAccountProfile(nextProfile)
  RT.RefreshListsWindow()

  RT.RefreshQuestWindow()
end

function RT.DifficultySliderValue(tier)
  tier = Core.sanitizeDifficulty(tier)

  if not tier then
    return Core.MIN_DIFFICULTY - 1
  end

  return tier
end

function RT.AddDifficultySlider(menu, tier, onCommit)
  local floor = Core.MIN_DIFFICULTY - 1

  menu:AddSlider({
    width = 150,
    min = floor,
    max = Core.maxDifficulty(),
    step = 1,
    value = RT.DifficultySliderValue(tier),
    title = L.LISTS_MENU_DIFFICULTY,
    format = function(value)
      return Core.difficultyLabel(value)
    end,
    onCommit = function(value)
      value = math.floor(value + 0.5)

      if value <= floor then
        onCommit(nil)
        return
      end

      onCommit(value)
      end,
  })
end
