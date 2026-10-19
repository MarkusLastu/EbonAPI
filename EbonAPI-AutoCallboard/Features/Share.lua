local Core = AutoCallboardCore
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local SyncGoldTracker = RT.SyncGoldTracker
local FinalizeTrackedQuestSpend = RT.FinalizeTrackedQuestSpend
local state = RT.state

local function NormalizeQuestTitle(title)
  title = Core.stripColorCodes(tostring(title or ""):lower())
  title = title:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

  return title
end

function RT.GetQuestLogEntryInfo(index)
  if not GetQuestLogTitle then
    return nil
  end

  local title, _, _, _, isHeader, isCollapsed, isComplete, _, questID = GetQuestLogTitle(index)
  if not title then
    return nil
  end

  questID = tonumber(questID)
  if questID and questID <= 0 then
    questID = nil
  end

  return {
    title = title,
    isHeader = isHeader,
    isCollapsed = isCollapsed,
    isComplete = isComplete,
    questID = questID,
  }
end

local function GetQuestIdFromLogIndex(index)
  local entry = RT.GetQuestLogEntryInfo(index)
  if entry and tonumber(entry.questID) and tonumber(entry.questID) > 0 then
    return tonumber(entry.questID)
  end

  if GetQuestLogQuestID then
    local questID = GetQuestLogQuestID(index)
    if tonumber(questID) and tonumber(questID) > 0 then
      return tonumber(questID)
    end
  end

  if GetQuestLink then
    local link = GetQuestLink(index)
    local questID = link and link:match("quest:(%d+)")
    if questID then
      return tonumber(questID)
    end
  end

  return nil
end

local function FindSelectedQuestInLog()
  if not RT.GetSelectedQuest() or not GetNumQuestLogEntries or not GetQuestLogTitle then
    return false, false
  end

  local selectedID = tonumber(RT.GetSelectedQuest().questId) or 0
  local selectedTitle = NormalizeQuestTitle(RT.GetSelectedQuest().title)
  local entries = GetNumQuestLogEntries()

  for i = 1, entries do
    local entry = RT.GetQuestLogEntryInfo(i)

    if entry and not entry.isHeader then
      local questID = tonumber(entry.questID) or GetQuestIdFromLogIndex(i)
      local idMatches = selectedID > 0 and questID == selectedID
      local titleMatches = selectedTitle ~= "" and NormalizeQuestTitle(entry.title) == selectedTitle

      if idMatches or titleMatches then
        return true, entry.isComplete == true or entry.isComplete == 1
      end
    end
  end

  return false, false
end

function RT.FindQuestLogIndexByID(questID, preferredIndex)
  questID = tonumber(questID) or 0
  if questID <= 0 or not GetNumQuestLogEntries then
    return nil
  end

  if preferredIndex then
    local preferredEntry = RT.GetQuestLogEntryInfo(preferredIndex)
    if preferredEntry and not preferredEntry.isHeader and tonumber(preferredEntry.questID) == questID then
      return preferredIndex, preferredEntry
    end
  end

  for i = 1, GetNumQuestLogEntries() do
    local entry = RT.GetQuestLogEntryInfo(i)
    if entry and not entry.isHeader and tonumber(entry.questID) == questID then
      return i, entry
    end
  end

  return nil
end

function RT.QuestLogTitles()
  local titles = {}

  if not GetNumQuestLogEntries then
    return titles
  end

  for i = 1, GetNumQuestLogEntries() do
    local entry = RT.GetQuestLogEntryInfo(i)
    local questID = entry and not entry.isHeader and tonumber(entry.questID)

    if questID and questID > 0 and titles[questID] == nil then
      titles[questID] = entry.title or false
    end
  end

  return titles
end

function RT.QuestShareLabel(quest)
  if not quest then
    return L.QUEST_FALLBACK_LABEL
  end

  local questID = tonumber(quest.questID) or tonumber(quest.questId) or 0
  local title = tostring(quest.title or "")
  if title ~= "" and questID > 0 then
    return tostring(questID) .. " " .. title
  end

  if questID > 0 then
    return tostring(questID)
  end

  if title ~= "" then
    return title
  end

  return L.QUEST_FALLBACK_LABEL
end

function RT.ShareQuestLogIndex(index, quest, source)
  if not index then
    return nil, RT.api:Problem("SHARE.QUEST_NOT_IN_LOG", { quest = RT.QuestShareLabel(quest) })
  end

  if not SelectQuestLogEntry then
    return nil, RT.api:Problem("SHARE.UNAVAILABLE", { api = "SelectQuestLogEntry" })
  end

  if not QuestLogPushQuest then
    return nil, RT.api:Problem("SHARE.UNAVAILABLE", { api = "QuestLogPushQuest" })
  end

  local previousIndex = GetQuestLogSelection and GetQuestLogSelection() or nil
  SelectQuestLogEntry(index)

  if GetQuestLogPushable and not GetQuestLogPushable() then
    if previousIndex then
      SelectQuestLogEntry(previousIndex)
    end

    return nil, RT.api:Problem("SHARE.NOT_SHAREABLE", { quest = RT.QuestShareLabel(quest) })
  end

  QuestLogPushQuest()

  if previousIndex then
    SelectQuestLogEntry(previousIndex)
  end

  return true
end

function RT.ShareAcceptedQuest(source)
  if not RT.lastAcceptedQuest then
    return nil, RT.api:Report(RT.api:Problem("SHARE.NO_ACCEPTED_QUEST"))
  end

  local lastAcceptedQuest = RT.lastAcceptedQuest
  local index, entry = RT.FindQuestLogIndexByID(lastAcceptedQuest.questID, lastAcceptedQuest.questLogIndex)
  if entry and entry.title and entry.title ~= "" then
    lastAcceptedQuest.title = entry.title
  end

  local shared, problem = RT.ShareQuestLogIndex(index, {
      questID = lastAcceptedQuest.questID,
      title = lastAcceptedQuest.title,
    }, source)

  if not shared then
    return nil, RT.api:Report(problem)
  end

  RT.SetQuestStatus(string.format(L.SHARE_ACCEPTED_QUEST, RT.QuestShareLabel(lastAcceptedQuest)))
  RT.api:Notify(string.format(L.SHARE_REQUESTED, RT.QuestShareLabel(lastAcceptedQuest)))

  return true
end

function RT.TrackAcceptedQuest(arg1, arg2)
  SyncGoldTracker()
  local first = tonumber(arg1)
  local second = tonumber(arg2)
  local questLogIndex = second and first or nil
  local questID = second
  local entry

  if questLogIndex then
    entry = RT.GetQuestLogEntryInfo(questLogIndex)
  elseif first then
    local possibleEntry = RT.GetQuestLogEntryInfo(first)
    if possibleEntry and tonumber(possibleEntry.questID) and tonumber(possibleEntry.questID) ~= first then
      questLogIndex = first
      questID = tonumber(possibleEntry.questID)
      entry = possibleEntry
    else
      questID = first
    end
  end

  if (not questID or questID <= 0) and entry and tonumber(entry.questID) then
    questID = tonumber(entry.questID)
  end

  if not questID or questID <= 0 then
    RT.api:Reject("SHARE.ACCEPTED_QUEST_ID_UNKNOWN", { first = tostring(arg1), second = tostring(arg2) })
    RT.lastAcceptedQuest = nil
    RT.UpdateShareButtonState()
    return
  end

  if RT.LogRollNote then
    RT.LogRollNote("questAccepted", questID, nil)
  end

  RT.lastAcceptedQuest = {
    questID = questID,
    questLogIndex = questLogIndex,
    title = entry and entry.title or "",
    acceptedAt = GetTime(),
  }

  RT.NoteQuestAccepted(questID, RT.lastAcceptedQuest.title)

  if Core.shouldPauseForAcceptedQuest(RT.IsRolling(), questID,
      RT.GetCurrentObjectives(), RT.GetActiveObjective(), state and state.knownQuests) then
    local selectedID = tonumber(RT.GetSelectedQuest() and RT.GetSelectedQuest().questId) or 0
    if selectedID ~= questID then
      RT.StartSelectedQuestPause({
          questId = questID,
          title = RT.lastAcceptedQuest.title,
        })
    end
  end

  local spent = FinalizeTrackedQuestSpend()
  RT.trackedGoldAt = nil
  RT.api:Trace("quest.accepted", questID, spent)
  RT.UpdateShareButtonState()

  RT.HandleEternalQuest()
end

function RT.RefreshLastAcceptedQuest()
  local accepted = RT.lastAcceptedQuest
  if not accepted or accepted.title ~= "" then
    return
  end

  local index, entry = RT.FindQuestLogIndexByID(accepted.questID, accepted.questLogIndex)
  if not entry then
    return
  end

  accepted.questLogIndex = index
  accepted.title = entry.title or ""
  RT.NoteQuestAccepted(accepted.questID, accepted.title)
end

function RT.GetQuestOfferTitle()
  if GetTitleText then
    local ok, value = pcall(GetTitleText)
    if ok and type(value) == "string" and value ~= "" then
      return value
    end
  end

  if QuestTitleText and QuestTitleText.GetText then
    return QuestTitleText:GetText() or ""
  end

  return ""
end

function RT.IsQuestOfferFromPlayer()
  return (UnitIsPlayer("questnpc") or UnitIsUnit("questnpc", "player")) and true or false
end

function RT.IsQuestOfferFromNpc()
  local guid = UnitGUID("questnpc") or UnitGUID("npc")

  return RT.ExtractBoardObjectIdFromGuid(guid) ~= nil
end

function RT.AcceptCurrentQuestOffer(source)
  if AcceptQuest then
    AcceptQuest()
  elseif QuestFrameAcceptButton then
    QuestFrameAcceptButton:Click()
  else
    local problem = RT.api:Report(RT.api:Problem("SHARE.ACCEPT_UNAVAILABLE"))
    return false, problem
  end

  return true
end

RT.NormalizeQuestTitle = NormalizeQuestTitle
RT.FindSelectedQuestInLog = FindSelectedQuestInLog
