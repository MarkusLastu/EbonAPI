local Lib = EbonAPI.Lib
local Core = AutoCallboardCore
local Skin = AutoCallboardSkin
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime

local Localized = RT.Localized
local RegisterSpecialFrame = RT.RegisterSpecialFrame
local GetQuestTypeName = RT.GetQuestTypeName
local FormatSeconds = RT.FormatSeconds
local CaptureCurrentObjectives = RT.CaptureCurrentObjectives
local GetObjectivesService = RT.GetObjectivesService
local objectivesDown = false
local CountDesiredQuests = RT.CountDesiredQuests
local IsCallboardActive = RT.IsCallboardActive
local GetSummonCooldownRemaining = RT.GetSummonCooldownRemaining
local state = RT.state

local function SyncCheckbox(checkbox, value)
  if not checkbox then
    return
  end

  value = value and true or false

  if (checkbox:GetChecked() and true or false) == value then
    return
  end

  checkbox:SetChecked(value)
end

RT.SyncCheckbox = SyncCheckbox

local KNOWN_ROWS = 8
local QUEST_ROW_GAP = 4
local QUEST_WINDOW_WIDTH = 620
local KNOWN_QUEST_ROW_WIDTH = 556

local MENU_ENTRIES_PER_LEVEL = 20

local questWindow
local knownQuestRows = {}

local function QuestRowStride()
  return knownQuestRows[1]:GetHeight() + QUEST_ROW_GAP
end

local questStatusText
local knownScrollFrame
local questSearchBox
local questSearchText = ""
local knownScrollOffset = 0
local updatingKnownScrollBar = false
local knownShowAllCheckbox
local knownShowAll = false

local QuestLabel
local ConfigureKnownQuestRow
local SetKnownScrollOffset
local UpdateQuestWindow
local ShowQuestWindow

function RT.RefreshQuestWindow()
  if questWindow and questWindow:IsShown() and UpdateQuestWindow then
    UpdateQuestWindow()
  end
end

function RT.IsQuestWindowShown()
  return questWindow ~= nil and questWindow:IsShown()
end

QuestLabel = function(quest)
  local title = Core.questTitle(quest)
  local questID = tonumber(quest and quest.questId)

  if title == "" then
    title = L.QUEST_UNKNOWN_TITLE
  end

  if questID and questID > 0 then
    return title .. " (" .. tostring(math.floor(questID)) .. ")"
  end

  return title
end

RT.questTypeFilterOptions = {
  { questType = 1, label = L.QUEST_TYPE_NAMES[1] },
  { questType = 2, label = L.QUEST_TYPE_NAMES[2] },
  { questType = 3, label = L.QUEST_TYPE_NAMES[3] },
  { questType = 4, label = L.QUEST_TYPE_NAMES[4] },
  { questType = 0, label = L.QUEST_TYPE_OTHER },
}
RT.knownQuestTypeButtons = RT.knownQuestTypeButtons or {}
RT.knownQuestTypeFilters = RT.knownQuestTypeFilters or {}

RT.questSortTitles = setmetatable({}, { __mode = "k" })

local function QuestSortTitle(quest)
  if not quest then
    return ""
  end

  local cached = RT.questSortTitles[quest]

  if not cached then
    cached = string.lower(Core.questTitle(quest))
    RT.questSortTitles[quest] = cached
  end

  return cached
end

local function CompareKnownQuests(left, right)
  local leftType = tonumber(left and left.questType) or 999
  local rightType = tonumber(right and right.questType) or 999

  if leftType ~= rightType then
    return leftType < rightType
  end

  local leftTitle = QuestSortTitle(left)
  local rightTitle = QuestSortTitle(right)
  if leftTitle ~= rightTitle then
    return leftTitle < rightTitle
  end

  return (tonumber(left and left.questId) or 0) < (tonumber(right and right.questId) or 0)
end

RT.questSearchHaystacks = setmetatable({}, { __mode = "k" })

Core.onKnownQuestTouched = function(quest)
  RT.questSearchHaystacks[quest] = nil
end

local function QuestMatchesSearch(quest, query)
  if not query or query == "" then
    return true
  end

  if not quest then
    return false
  end

  local haystack = RT.questSearchHaystacks[quest]

  if haystack then
    return string.find(haystack, query, 1, true) ~= nil
  end

  local questType = tonumber(quest.questType)
  local tooltipParts = {
    tostring(quest.title or ""),
    tostring(quest.objectiveText or ""),
    tostring(quest.questId or ""),
    tostring(quest.zoneOrSort or ""),
    tostring(quest.questType or ""),
    questType and GetQuestTypeName(questType) or "",
    tostring(quest.normalXp or ""),
    tostring(quest.hc1Xp or ""),
    tostring(quest.hc2Xp or ""),
    tostring(quest.hc3Xp or ""),
    tostring(quest.hc4Xp or ""),
    tostring(quest.normalSoulAshes or ""),
    tostring(quest.hc1SoulAshes or ""),
    tostring(quest.hc2SoulAshes or ""),
    tostring(quest.hc3SoulAshes or ""),
    tostring(quest.hc4SoulAshes or ""),
    tostring(quest.seen or ""),
    "xp",
    "soul ash",
    "seen",
  }

  haystack = table.concat(tooltipParts, " "):lower()
  RT.questSearchHaystacks[quest] = haystack

  return string.find(haystack, query, 1, true) ~= nil
end

function RT.CountActiveQuestTypeFilters()
  local count = 0
  local lastQuestType = nil

  for i = 1, #(RT.questTypeFilterOptions) do
    local questType = RT.questTypeFilterOptions[i].questType

    if Core.questTypeFilterEnabled(RT.knownQuestTypeFilters, questType) then
      count = count + 1
      lastQuestType = questType
    end
  end

  return count, lastQuestType
end

function RT.GetActiveQuestTypeFilterNames()
  local count = RT.CountActiveQuestTypeFilters()
  local names = {}

  if count == 0 then
    return names
  end

  for i = 1, #(RT.questTypeFilterOptions) do
    local option = RT.questTypeFilterOptions[i]
    if Core.questTypeFilterEnabled(RT.knownQuestTypeFilters, option.questType) then
      table.insert(names, option.label)
    end
  end

  return names
end

function RT.SyncKnownQuestTypeButtons()
  local buttons = RT.knownQuestTypeButtons
  local revision = RT.knownFilterRevision or 0

  if buttons._acbSyncedRevision == revision then
    return
  end

  buttons._acbSyncedRevision = revision

  for i = 1, #(buttons) do
    local checkbox = buttons[i]
    SyncCheckbox(checkbox, Core.questTypeFilterEnabled(RT.knownQuestTypeFilters, checkbox._acbQuestType))
  end
end

function RT.SetKnownQuestTypeFilter(questType)
  RT.knownQuestTypeFilters = RT.knownQuestTypeFilters or {}
  questType = tonumber(questType) or 0

  if Core.questTypeFilterEnabled(RT.knownQuestTypeFilters, questType) then
    RT.knownQuestTypeFilters[questType] = nil
    RT.knownQuestTypeFilters[tostring(questType)] = nil
  else
    RT.knownQuestTypeFilters[questType] = true
    RT.knownQuestTypeFilters[tostring(questType)] = nil
  end

  RT.knownFilterRevision = (RT.knownFilterRevision or 0) + 1
  RT.SyncKnownQuestTypeButtons()
  SetKnownScrollOffset(0, true)
end

function RT.SetKnownShowAll(value)
  value = value and true or false

  if knownShowAll == value then
    SyncCheckbox(knownShowAllCheckbox, value)
    return
  end

  knownShowAll = value
  RT.knownFilterRevision = (RT.knownFilterRevision or 0) + 1
  SyncCheckbox(knownShowAllCheckbox, value)
  SetKnownScrollOffset(0, true)
end

local function ActiveSelectionFilter()
  if knownShowAll then
    return nil
  end

  local selection = Core.findSelection(RT.GetAccountProfile(), RT.GetActiveSelectionId())

  if not selection then
    return nil
  end

  local name = type(selection.name) == "string" and selection.name or ""

  return type(selection.desiredQuests) == "table" and selection.desiredQuests or {},
      name ~= "" and name or L.SELECTION_DEFAULT_NAME
end

function RT.GetActiveSelectionFilterName()
  local _, name = ActiveSelectionFilter()
  return name
end

local function FilterKnownQuests()
  local filtered = {}

  local quests = state and state.knownQuests or {}
  local activeTypeCount = RT.CountActiveQuestTypeFilters()
  local useTypeFallback = activeTypeCount > 0 and Core.needsKnownTypeFallback(quests, RT.knownQuestTypeFilters)
  local listScope = ActiveSelectionFilter()
  local searchNeedle = string.lower(questSearchText or "")
  local filterMode

  if useTypeFallback then
    filterMode = "type-fallback"
  elseif activeTypeCount > 0 then
    filterMode = "type"
  elseif listScope then
    filterMode = "list"
  else
    filterMode = "all"
  end

  for i = 1, #(quests) do
    local quest = quests[i]
    local matchesFilter = useTypeFallback or Core.questMatchesTypeFilter(quest, RT.knownQuestTypeFilters)

    if matchesFilter and listScope then
      matchesFilter = Core.questInSelection(quest, listScope)
    end

    if matchesFilter and QuestMatchesSearch(quest, searchNeedle) then
      table.insert(filtered, quest)
    end
  end

  return filtered, filterMode
end

local function BuildKnownQuestEntries()
  local filtered, filterMode = FilterKnownQuests()
  table.sort(filtered, CompareKnownQuests)

  local entries = {}
  local lastTypeName = nil

  for i = 1, #(filtered) do
    local quest = filtered[i]
    local typeName = filterMode == "type-fallback" and L.QUEST_CATEGORY_DATA_MISSING or GetQuestTypeName(quest and quest.questType)

    if typeName ~= lastTypeName then
      table.insert(entries, {
        kind = "header",
        title = typeName,
      })
      lastTypeName = typeName
    end

    table.insert(entries, {
      kind = "quest",
      quest = quest,
    })
  end

  return entries, filtered, filterMode
end

function RT.GetKnownQuestEntries()
  local signature = tostring(RT.stateRevision or 0)
      .. "|" .. tostring(RT.knownFilterRevision or 0)
      .. "|" .. questSearchText

  if RT.knownEntriesSignature == signature then
    return RT.knownEntries,
        RT.knownEntriesFiltered,
        RT.knownEntriesFilterMode
  end

  local entries, filtered, filterMode = BuildKnownQuestEntries()

  RT.knownEntriesSignature = signature
  RT.knownEntries = entries
  RT.knownEntriesFiltered = filtered
  RT.knownEntriesFilterMode = filterMode

  return entries, filtered, filterMode
end

function RT.GetKnownListViewState()
  return questSearchText, knownScrollOffset, KNOWN_ROWS
end

function RT.GetKnownQuestDisplayReason(quests, filtered, entries, filterMode, selectedKnownCount, selectedMissingCount, activeTypeNames)
  if #(quests) == 0 then
    return "no_known_quests"
  end

  if #(entries) > 0 then
    if filterMode == "list" then
      return "showing_list"
    end

    if filterMode == "type-fallback" then
      return "category_metadata_missing_fallback"
    end

    if filterMode == "type" then
      return "showing_type_filter"
    end

    if selectedMissingCount > 0 and selectedKnownCount == 0 then
      return "selected_keys_missing_showing_all"
    end

    return "showing_all_known"
  end

  if questSearchText ~= "" then
    return "search_hides_all"
  end

  if #(activeTypeNames) > 0 and Core.needsKnownTypeFallback(quests, RT.knownQuestTypeFilters) then
    return "category_metadata_missing"
  end

  if #(activeTypeNames) > 0 then
    return "type_filter_hides_all"
  end

  if filterMode == "list" and #(filtered) == 0 then
    return "list_filter_hides_all"
  end

  return "unknown_empty_list"
end

RT.knownEmptyReasonKeys = {
  no_known_quests = "KNOWN_EMPTY_NO_QUESTS",
  search_hides_all = "KNOWN_EMPTY_SEARCH",
  category_metadata_missing = "KNOWN_EMPTY_CATEGORY_DATA",
  type_filter_hides_all = "KNOWN_EMPTY_TYPE_FILTER",
  list_filter_hides_all = "KNOWN_EMPTY_LIST_FILTER",
}

function RT.FormatKnownQuestHeader(quests, filtered, entries, filterMode, activeTypeNames, selectedKnownCount, selectedMissingCount)
  local parts = {}
  local listName = RT.GetActiveSelectionFilterName()

  if listName then
    table.insert(parts, listName)
  end

  if #(activeTypeNames) > 0 then
    table.insert(parts, filterMode == "type-fallback" and L.QUEST_CATEGORY_DATA_MISSING or table.concat(activeTypeNames, ", "))
  end

  local showing = #(parts) > 0 and table.concat(parts, " + ") or L.KNOWN_SHOWING_ALL

  local header = string.format(L.KNOWN_HEADER, #(quests), #(filtered), showing)

  if selectedMissingCount > 0 then
    header = header .. string.format(L.KNOWN_HEADER_MISSING, selectedMissingCount)
  elseif selectedKnownCount > 0 then
    header = header .. string.format(L.KNOWN_HEADER_SELECTED_KNOWN, selectedKnownCount)
  end

  if #(entries) == 0 then
    local reasonKey = RT.knownEmptyReasonKeys[RT.GetKnownQuestDisplayReason(
        quests, filtered, entries, filterMode, selectedKnownCount, selectedMissingCount, activeTypeNames)]

    if reasonKey then
      header = header .. "  |  " .. L[reasonKey]
    else
      RT.api:Report(RT.api:Problem("QUESTWINDOW.EMPTY_UNEXPLAINED", { filterMode = tostring(filterMode), known = #(quests) }))
    end
  end

  return header
end

local function AddRewardLine(label, xp, soulAshes)
  local parts = {}

  if xp and xp > 0 then
    table.insert(parts, string.format(L.REWARD_XP, xp))
  end

  if soulAshes and soulAshes > 0 then
    table.insert(parts, string.format(L.REWARD_SOUL_ASH, soulAshes))
  end

  if #(parts) > 0 then
    GameTooltip:AddDoubleLine(label, table.concat(parts, "  "), 0.85, 0.85, 0.85, 1, 1, 1)
  end
end

local function PositionTooltipNearCursor(owner)
  if not GetCursorPosition or not UIParent or not UIParent.GetEffectiveScale then
    GameTooltip:SetPoint("BOTTOMLEFT", owner or UIParent, "TOPRIGHT", 12, 12)
    return
  end

  local scale = UIParent:GetEffectiveScale() or 1
  local cursorX, cursorY = GetCursorPosition()
  local uiWidth = UIParent:GetWidth() or 0
  local uiHeight = UIParent:GetHeight() or 0
  local tooltipWidth = GameTooltip:GetWidth() or 260
  local tooltipHeight = GameTooltip:GetHeight() or 120
  local x = (cursorX / scale) + 18
  local y = (cursorY / scale) + 18

  if uiWidth > 0 and x + tooltipWidth > uiWidth - 8 then
    x = math.max(8, uiWidth - tooltipWidth - 8)
  end

  if uiHeight > 0 and y + tooltipHeight > uiHeight - 8 then
    y = math.max(8, uiHeight - tooltipHeight - 8)
  end

  GameTooltip:ClearAllPoints()
  GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function AnchorTooltipNearCursor(owner)
  Skin.OpenTip(owner or UIParent, "ANCHOR_NONE")
  PositionTooltipNearCursor(owner)
end

local function ShowQuestTooltip(owner, quest, sourceLabel)
  if not quest then
    return
  end

  AnchorTooltipNearCursor(owner)
  GameTooltip:AddLine(Core.questTitle(quest) ~= "" and Core.questTitle(quest) or L.QUEST_UNKNOWN_TITLE, 1, 0.82, 0)

  if sourceLabel then
    GameTooltip:AddLine(sourceLabel, 0.65, 0.8, 1)
  end

  if tonumber(quest.questId) and tonumber(quest.questId) > 0 then
    GameTooltip:AddDoubleLine(L.QUEST_TOOLTIP_ID, tostring(math.floor(tonumber(quest.questId))), 0.8, 0.8, 0.8, 1, 1, 1)
  end

  local questType = tonumber(quest.questType)
  if questType and questType > 0 then
    GameTooltip:AddDoubleLine(L.QUEST_TOOLTIP_TYPE, GetQuestTypeName(questType), 0.8, 0.8, 0.8, 1, 1, 1)
  end

  if tonumber(quest.zoneOrSort) and tonumber(quest.zoneOrSort) > 0 then
    GameTooltip:AddDoubleLine(L.QUEST_TOOLTIP_ZONE_SORT, tostring(math.floor(tonumber(quest.zoneOrSort))), 0.8, 0.8, 0.8, 1, 1, 1)
  end

  if quest.objectiveText and quest.objectiveText ~= "" then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(quest.objectiveText, 1, 1, 1, true)
  end

  local RL = L.REWARD_DIFFICULTY_LABELS
  AddRewardLine(RL[1], tonumber(quest.normalXp) or 0, tonumber(quest.normalSoulAshes) or 0)
  AddRewardLine(RL[2], tonumber(quest.hc1Xp) or 0, tonumber(quest.hc1SoulAshes) or 0)
  AddRewardLine(RL[3], tonumber(quest.hc2Xp) or 0, tonumber(quest.hc2SoulAshes) or 0)
  AddRewardLine(RL[4], tonumber(quest.hc3Xp) or 0, tonumber(quest.hc3SoulAshes) or 0)
  AddRewardLine(RL[5], tonumber(quest.hc4Xp) or 0, tonumber(quest.hc4SoulAshes) or 0)

  if quest.seen then
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.QUEST_TOOLTIP_SEEN, tostring(quest.seen), 0.8, 0.8, 0.8, 1, 1, 1)
  end

  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L.QUEST_TOOLTIP_RIGHT_CLICK, 0.8, 0.8, 0.8)

  GameTooltip:Show()
  PositionTooltipNearCursor(owner)
end

local function GetKnownMaxScrollOffset()
  local entries = RT.GetKnownQuestEntries()

  return math.max(0, #(entries) - KNOWN_ROWS)
end

SetKnownScrollOffset = function(value, force)
  local maxOffset = GetKnownMaxScrollOffset()
  local nextOffset = math.max(0, math.min(maxOffset, math.floor((tonumber(value) or 0) + 0.5)))

  if nextOffset == knownScrollOffset and not force then
    if knownScrollFrame and knownScrollFrame._acbScrollBar and knownScrollFrame._acbScrollBar.SetValue then
      updatingKnownScrollBar = true
      knownScrollFrame._acbScrollBar:SetValue(nextOffset)
      updatingKnownScrollBar = false
    end
    return
  end

  knownScrollOffset = nextOffset

  if UpdateQuestWindow then
    UpdateQuestWindow()
  end
end

UpdateQuestWindow = function()
  if not questWindow then
    return
  end

  if not questWindow:IsShown() then
    if RT.controlFrame and RT.controlFrame.startButton then
      RT.UpdateRollToggleButtonState(RT.controlFrame.startButton, true)
    end

    return
  end

  if not RT.ShouldHoldObjectiveChoices() then
    CaptureCurrentObjectives()
  end
  local service = GetObjectivesService()
  if service and objectivesDown then
    objectivesDown = false
    RT.api:Restore("QUESTWINDOW.OBJECTIVES_UNAVAILABLE")
  elseif not service and not objectivesDown then
    objectivesDown = true
    RT.api:Degrade(RT.api:Problem("QUESTWINDOW.OBJECTIVES_UNAVAILABLE"))
  end
  local desiredCount = CountDesiredQuests()

  local knownEntries, knownFiltered, knownFilterMode = RT.GetKnownQuestEntries()
  local displayCount = #(knownEntries)
  local maxOffset = math.max(0, displayCount - KNOWN_ROWS)

  if knownScrollOffset > maxOffset then
    knownScrollOffset = maxOffset
  elseif knownScrollOffset < 0 then
    knownScrollOffset = 0
  end

  if knownScrollFrame and knownScrollFrame._acbScrollBar then
    local scrollBar = knownScrollFrame._acbScrollBar

    updatingKnownScrollBar = true
    if scrollBar.SetMinMaxValues then
      scrollBar:SetMinMaxValues(0, maxOffset)
    end
    if scrollBar.SetValueStep then
      scrollBar:SetValueStep(1)
    end
    if scrollBar.SetValue then
      scrollBar:SetValue(knownScrollOffset)
    end
    updatingKnownScrollBar = false

    Lib.setShown(scrollBar, maxOffset > 0)
  elseif knownScrollFrame and FauxScrollFrame_Update and FauxScrollFrame_GetOffset then
    knownScrollFrame.offset = knownScrollOffset
    FauxScrollFrame_Update(knownScrollFrame, displayCount, KNOWN_ROWS, QuestRowStride())
    knownScrollOffset = FauxScrollFrame_GetOffset(knownScrollFrame)
  end

  local offset = knownScrollOffset
  for i = 1, KNOWN_ROWS do
    local row = knownQuestRows[i]
    local entry = knownEntries[offset + i]

    if row then
      ConfigureKnownQuestRow(row, entry)
    end
  end

  if RT.knownPageText then
    local pageText = RT.knownPageText

    local selectedKnownCount, selectedMissingCount =
        Core.countDesiredKnownQuests(state and state.knownQuests, state and state.desiredQuests)

    if pageText._acbHeaderEntries ~= knownEntries
        or pageText._acbHeaderKnown ~= selectedKnownCount
        or pageText._acbHeaderMissing ~= selectedMissingCount then
      pageText._acbHeaderEntries = knownEntries
      pageText._acbHeaderKnown = selectedKnownCount
      pageText._acbHeaderMissing = selectedMissingCount

      pageText:SetText(RT.FormatKnownQuestHeader(
          state and state.knownQuests or {},
          knownFiltered,
          knownEntries,
          knownFilterMode,
          RT.GetActiveQuestTypeFilterNames(),
          selectedKnownCount,
          selectedMissingCount))
    end
  end

  RT.SyncKnownQuestTypeButtons()
  SyncCheckbox(knownShowAllCheckbox, knownShowAll)

  RT.RefreshGoldDisplay()

  RT.UpdateRollToggleButtonState(RT.startRollButton, service ~= nil)
  RT.UpdateRollToggleButtonState(RT.controlFrame and RT.controlFrame.startButton or nil, true)

  if questStatusText then
    local summonSummary = ""
    local cooldownRemaining = GetSummonCooldownRemaining()
    if IsCallboardActive() then
      summonSummary = string.format(L.STATUS_SUFFIX_ACTIVE, FormatSeconds(RT.GetCallboardActiveRemaining()))
    elseif cooldownRemaining > 0 then
      summonSummary = string.format(L.STATUS_SUFFIX_COOLDOWN, FormatSeconds(cooldownRemaining))
    end

    summonSummary = summonSummary .. RT.FormatDifficultyStatus()

    if not service then
      questStatusText:SetText(L.STATUS_OBJECTIVES_UNAVAILABLE)
    elseif RT.IsRolling() and RT.GetRollPauseReason() == "quest_selected" and RT.GetSelectedQuest() then
      questStatusText:SetText(string.format(L.STATUS_PAUSED_SELECTED, tostring(RT.GetSelectedQuest().title or "quest"), summonSummary))
    elseif RT.IsRolling() and RT.GetRollPauseReason() then
      questStatusText:SetText(tostring(RT.GetRollPauseMessage() or string.format(L.STATUS_PAUSED_GENERIC, RT.GetRollPauseReason())) .. summonSummary)
    elseif RT.IsRolling() and RT.learningQuestList then
      questStatusText:SetText(string.format(L.STATUS_LEARNING, RT.GetRollCount(), state.maxRerolls, summonSummary))
    elseif RT.IsRolling() then
      questStatusText:SetText(string.format(L.STATUS_ROLLING, RT.GetRollCount(), state.maxRerolls, desiredCount, summonSummary))
    else
      questStatusText:SetText(string.format(L.STATUS_SELECTED, desiredCount, summonSummary))
    end
  end
end

local questContextMenu
local BuildQuestCollectionMenu

local function QuestContextKey(quest)
  if type(quest) ~= "table" then
    return nil
  end

  if type(quest.key) == "string" and quest.key ~= "" then
    return quest.key
  end

  return Core.questKey(quest)
end

local function EnsureQuestContextMenu()
  if not questContextMenu then
    questContextMenu = Skin.Menu("AutoCallboardQuestContextMenu")
    RT.questContextMenu = questContextMenu
  end

  return questContextMenu
end

local function AddCollectionItems(menu, quest, key, groupId)
  local entries = Core.selectionsInContainer(RT.GetAccountProfile(), groupId)
  local shown = 0

  for i = 1, #(entries) do
    if shown >= MENU_ENTRIES_PER_LEVEL then
      menu:AddItem(string.format(L.QUEST_MENU_MORE, #(entries) - shown), { disabled = true })
      break
    end

    local entry = entries[i]
    local inside = Core.selectionHasQuest(entry, key)
    shown = shown + 1

    menu:AddItem(entry.name, {
      checked = inside,
      keepOpen = true,
      onClick = function()
        RT.RequestSetQuestInSelection(entry, key, not inside)
        BuildQuestCollectionMenu(menu, quest, groupId)
        end,
    })
  end

  return #(entries)
end

BuildQuestCollectionMenu = function(menu, quest, groupId)
  local key = QuestContextKey(quest)
  local profile = RT.GetAccountProfile()
  local group = nil

  if groupId then
    group = Core.findGroup(profile, groupId)
  end

  menu:Reset()
  menu:AddItem(QuestLabel(quest), { header = true })

  if group then
    menu:AddItem("< " .. group.name, {
      keepOpen = true,
      onClick = function()
        BuildQuestCollectionMenu(menu, quest, nil)
        end,
    })
  end

  local count = AddCollectionItems(menu, quest, key, groupId)

  if not group then
    local groups = profile.groups

    for i = 1, #(groups) do
      local entry = groups[i]
      count = count + Core.selectionCount(profile, entry.id)

      menu:AddItem(entry.name, {
        arrow = true,
        keepOpen = true,
        onClick = function()
          BuildQuestCollectionMenu(menu, quest, entry.id)
          end,
      })
    end
  end

  if count == 0 then
    menu:AddItem(L.QUEST_MENU_NO_COLLECTION, { disabled = true })
  end

  menu:AddItem(L.QUEST_MENU_NEW, {
    onClick = function()
      RT.RequestCreateSelectionWithQuest(key, groupId)
      end,
  })

  menu:Layout()
end

local function ShowQuestContextMenu(row, quest)
  if not QuestContextKey(quest) then
    return
  end

  local menu = EnsureQuestContextMenu()
  BuildQuestCollectionMenu(menu, quest, nil)
  menu:OpenAt(row, "TOPLEFT", "BOTTOMLEFT", 8, -2)
end

local function OpenRowMenu(row, mouseButton)
  if mouseButton == "RightButton" then
    ShowQuestContextMenu(row, row.quest)
  end
end

local function AnchorRowTitle(row, header)
  row.title:ClearAllPoints()
  row.title:SetPoint("LEFT", row, "LEFT", 6, 0)

  if header then
    row.title:SetPoint("RIGHT", row, "RIGHT", -6, 0)
  else
    row.title:SetPoint("RIGHT", row.checkbox, "LEFT", -8, 0)
  end
end

local function MakeQuestRow(parent, width)
  local row = Skin.Row(parent, nil, "RightButtonUp")
  row:SetWidth(width)
  row:HookScript("OnEnter", function(self)
    ShowQuestTooltip(self, self.quest, L.TOOLTIP_SOURCE_KNOWN_QUEST)
    end)
  row:HookScript("OnLeave", function()
    GameTooltip:Hide()
    end)
  row:HookScript("OnMouseUp", OpenRowMenu)

  row:EnableMouseWheel(true)
  row:SetScript("OnMouseWheel", function(_, delta)
    SetKnownScrollOffset(knownScrollOffset - delta)
    end)

  row.checkbox = Skin.Checkbox(row, {
    onClick = function()
      if row.key then
        RT.ToggleDesiredQuest(row.key)
      end
    end,
  })
  row.checkbox:SetPoint("RIGHT", row, "RIGHT", -6, 0)
  AnchorRowTitle(row)
  row.checkbox:HookScript("OnMouseUp", function(_, mouseButton)
    OpenRowMenu(row, mouseButton)
    end)
  row.checkbox:HookScript("OnEnter", function(self)
    ShowQuestTooltip(self, row.quest, L.TOOLTIP_SOURCE_KNOWN_QUEST)
    end)
  row.checkbox:HookScript("OnLeave", function()
    GameTooltip:Hide()
    end)
  row.checkbox:EnableMouseWheel(true)
  row.checkbox:SetScript("OnMouseWheel", function(_, delta)
    SetKnownScrollOffset(knownScrollOffset - delta)
    end)

  return row
end

local EMPTY_ROW = {}

local function ClearKnownQuestRow(row)
  if row._acbRowEntry == EMPTY_ROW then
    return
  end

  row._acbRowEntry = EMPTY_ROW
  row._acbRowWanted = nil
  row.quest = nil
  row.key = nil
  row:Hide()
end

ConfigureKnownQuestRow = function(row, entry)
  if not row then
    return
  end

  if not entry then
    ClearKnownQuestRow(row)
    return
  end

  if entry.kind == "header" then
    if row._acbRowEntry == entry then
      return
    end

    row._acbRowEntry = entry
    row._acbRowWanted = nil
    row.quest = nil
    row.key = nil
    AnchorRowTitle(row, true)
    row.title:SetText("[" .. tostring(entry.title or L.QUEST_TYPE_OTHER) .. "]")
    row:SetTextKey("heading")
    if row.checkbox then
      row.checkbox:SetChecked(false)
      row.checkbox:Hide()
    end
    row:Show()
    return
  end

  local quest = entry.quest
  if not quest then
    ClearKnownQuestRow(row)
    return
  end

  local wanted = quest.key ~= nil and state.desiredQuests ~= nil and state.desiredQuests[quest.key] == true

  if row._acbRowEntry == entry and row._acbRowWanted == wanted then
    return
  end

  row._acbRowEntry = entry
  row._acbRowWanted = wanted
  row.quest = quest
  row.key = quest.key
  AnchorRowTitle(row)
  row.title:SetText(QuestLabel(quest))
  row:SetTextKey(nil)
  if row.checkbox then
    SyncCheckbox(row.checkbox, wanted)
    row.checkbox:Show()
  end
  row:Show()
end

local function CreateQuestSearch(questWindow)
  local searchLabel = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  searchLabel:SetPoint("TOPLEFT", questWindow, "TOPLEFT", 24, -52)
  Localized(searchLabel, "SEARCH_LABEL")
  Skin.MutedText(searchLabel)

  questSearchBox = CreateFrame("EditBox", "AutoCallboardQuestSearchBox", questWindow)
  questSearchBox:SetFontObject(GameFontHighlightSmall)
  questSearchBox:SetWidth(250)
  questSearchBox:SetHeight(20)
  questSearchBox:SetTextInsets(6, 6, 0, 0)
  questSearchBox:SetAutoFocus(false)
  questSearchBox:SetPoint("LEFT", searchLabel, "RIGHT", 12, 0)
  Skin.Field(questSearchBox)
  questSearchBox:SetScript("OnTextChanged", function(self)
    questSearchText = self:GetText() or ""
    SetKnownScrollOffset(0, true)
    end)
  questSearchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    end)
  questSearchBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    end)

  local clearSearchButton = Skin.MakeButton(questWindow, {
    textKey = "BUTTON_CLEAR",
    points = { { "LEFT", questSearchBox, "RIGHT", 10, 0 } },
    onClick = function()
      questSearchBox:SetText("")
      questSearchBox:ClearFocus()
      end,
  })

  knownShowAllCheckbox = Skin.Checkbox(questWindow, {
    onClick = function(self)
      RT.SetKnownShowAll(self:GetChecked() and true or false)
    end,
  })
  knownShowAllCheckbox:SetPoint("LEFT", clearSearchButton, "RIGHT", 16, 0)

  local showAllLabel = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  showAllLabel:SetPoint("LEFT", knownShowAllCheckbox, "RIGHT", 6, 0)
  Localized(showAllLabel, "KNOWN_SHOW_ALL_LABEL")
  Skin.MutedText(showAllLabel)

  Skin.HoverTip(knownShowAllCheckbox, "KNOWN_SHOW_ALL_LABEL", "KNOWN_SHOW_ALL_TOOLTIP")
  RT.knownShowAllCheckbox = knownShowAllCheckbox
  SyncCheckbox(knownShowAllCheckbox, knownShowAll)
end

local function CreateQuestFilters(questWindow)
  local categoryLabel = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  categoryLabel:SetPoint("TOPLEFT", questWindow, "TOPLEFT", 24, -84)
  Localized(categoryLabel, "SHOW_LABEL")
  Skin.MutedText(categoryLabel)

  local previousCategoryLabel = categoryLabel
  RT.knownQuestTypeButtons = {}
  for i = 1, #(RT.questTypeFilterOptions) do
    local option = RT.questTypeFilterOptions[i]
    local checkbox = Skin.Checkbox(questWindow, {
      onClick = function(self)
        RT.SetKnownQuestTypeFilter(self._acbQuestType)
      end,
    })
    if i == 1 then
      checkbox:SetPoint("LEFT", categoryLabel, "RIGHT", 14, 0)
    else
      checkbox:SetPoint("LEFT", previousCategoryLabel, "RIGHT", 18, 0)
    end
    checkbox._acbQuestType = option.questType

    local checkboxLabel = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkboxLabel:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
    checkboxLabel:SetText(option.label)
    Skin.MutedText(checkboxLabel)

    checkbox._acbLabel = checkboxLabel
    table.insert(RT.knownQuestTypeButtons, checkbox)
    previousCategoryLabel = checkboxLabel
  end
  RT.SyncKnownQuestTypeButtons()
end

local function CreateKnownQuestList(questWindow)
  RT.knownPageText = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  RT.knownPageText:SetPoint("TOPLEFT", questWindow, "TOPLEFT", 24, -116)
  RT.knownPageText:SetWidth(QUEST_WINDOW_WIDTH - 62)
  RT.knownPageText:SetJustifyH("LEFT")
  RT.knownPageText:SetText(L.QUEST_WINDOW_KNOWN_PAGE_DEFAULT)
  Skin.HeadingText(RT.knownPageText)

  knownScrollFrame = CreateFrame("ScrollFrame", "AutoCallboardKnownQuestScrollFrame", questWindow, "FauxScrollFrameTemplate")
  knownScrollFrame:SetPoint("TOPLEFT", RT.knownPageText, "BOTTOMLEFT", -4, -8)
  knownScrollFrame:SetPoint("BOTTOMRIGHT", questWindow, "BOTTOMRIGHT", -34, 120)
  knownScrollFrame:EnableMouseWheel(true)
  local knownScrollBar = Skin.ScrollBar(knownScrollFrame)
  if knownScrollBar then
    knownScrollBar:SetScript("OnValueChanged", function(_, value)
      if updatingKnownScrollBar then
        return
      end

      SetKnownScrollOffset(value)
      end)

    if knownScrollBar.acbUpButton then
      knownScrollBar.acbUpButton:SetScript("OnClick", function()
        SetKnownScrollOffset(knownScrollOffset - 1)
        end)
    end

    if knownScrollBar.acbDownButton then
      knownScrollBar.acbDownButton:SetScript("OnClick", function()
        SetKnownScrollOffset(knownScrollOffset + 1)
        end)
    end
  end
  knownScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    SetKnownScrollOffset(offset)
    end)
  knownScrollFrame:SetScript("OnMouseWheel", function(_, delta)
    SetKnownScrollOffset(knownScrollOffset - delta)
    end)

  for i = 1, KNOWN_ROWS do
    knownQuestRows[i] = MakeQuestRow(questWindow, KNOWN_QUEST_ROW_WIDTH)
    knownQuestRows[i]:SetPoint("TOPLEFT", RT.knownPageText, "BOTTOMLEFT", 0, -10 - ((i - 1) * QuestRowStride()))
  end

  RT.knownQuestRows = knownQuestRows
end

local function CreateQuestToolbar(questWindow)
  local toolbar = Skin.ButtonRow(questWindow, { point = { "BOTTOM", questWindow, "BOTTOM", 0, 54 } })

  RT.startRollButton = Skin.MakeButton(toolbar, {
    secure = true,
    text = L.BUTTON_START,
  })
  RT.ConfigureStartButton(RT.startRollButton)
  RT.UpdateRollToggleButtonState(RT.startRollButton, RT.IsQuestRollStartAvailable())

  RT.shareQuestButton = Skin.MakeButton(toolbar, {
    textKey = "BUTTON_SHARE",
    onClick = function()
      RT.ShareAcceptedQuest("quest window button")
      end,
    tipKey = "SHARE_BUTTON_TOOLTIP",
  })
  RT.UpdateShareButtonState()

  Skin.MakeButton(toolbar, {
    textKey = "BUTTON_EXPORT",
    onClick = function() RT.ShowQuestDataWindow("export") end,
  })

  Skin.MakeButton(toolbar, {
    textKey = "BUTTON_IMPORT",
    onClick = function() RT.ShowQuestDataWindow("import") end,
  })

  RT.questGoldText = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  RT.questGoldText:SetPoint("BOTTOMLEFT", questWindow, "BOTTOMLEFT", 24, 32)
  RT.questGoldText:SetWidth(540)
  RT.questGoldText:SetJustifyH("LEFT")
  Skin.MutedText(RT.questGoldText)

  questStatusText = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  RT.questStatusText = questStatusText
  questStatusText:SetPoint("BOTTOMLEFT", questWindow, "BOTTOMLEFT", 24, 16)
  questStatusText:SetWidth(540)
  questStatusText:SetJustifyH("LEFT")
  Skin.MutedText(questStatusText)
end

function RT.CreateQuestWindow()
  questWindow = Skin.Box(RT.controlFrame and RT.controlFrame.content or UIParent, {
    name = "AutoCallboardQuestWindow",
    width = QUEST_WINDOW_WIDTH,
    height = 526,
  })
  RT.questWindow = questWindow
  RegisterSpecialFrame("AutoCallboardQuestWindow")
  questWindow:SetPoint("TOPLEFT", RT.controlFrame and RT.controlFrame.content or UIParent, "TOPLEFT", 0, RT.controlFrame and -52 or 0)
  if RT.controlFrame and questWindow.SetFrameLevel then
    questWindow:SetFrameLevel(RT.controlFrame:GetFrameLevel() + 1)
  end
  RT.SyncOverlayFrameLevels()
  questWindow:EnableMouse(true)
  questWindow:SetClampedToScreen(true)
  questWindow:HookScript("OnHide", function()
    if questSearchBox and questSearchBox.ClearFocus then
      questSearchBox:ClearFocus()
    end

    if RT.controlFrame and not RT.questPanelChanging and not RT.questWindowCreating then
      RT.SetQuestPanelExpanded(false)
    end
    end)

  local title = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", questWindow, "TOP", 0, -18)
  Localized(title, "QUEST_WINDOW_TITLE")
  Skin.HeadingText(title)

  CreateQuestSearch(questWindow)
  CreateQuestFilters(questWindow)
  CreateKnownQuestList(questWindow)
  CreateQuestToolbar(questWindow)

  RT.questWindowCreating = true
  RT.LayoutMainToolbar()
  questWindow:Hide()
  RT.questWindowCreating = nil
end

ShowQuestWindow = function()
  if not questWindow then
    RT.CreateQuestWindow()
  end

  RT.SetQuestPanelExpanded(true)
end

RT.QuestLabel = QuestLabel
RT.UpdateQuestWindow = UpdateQuestWindow
RT.ShowQuestWindow = ShowQuestWindow
