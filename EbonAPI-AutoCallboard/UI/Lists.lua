local Core = AutoCallboardCore
local Skin = AutoCallboardSkin
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local state = RT.state

local function Report(code, facts)
  RT.api:Report(RT.api:Problem(code, facts))
end

local function ReportRefused(code, field, found, action, item, id)
  Report(code, {
    action = action,
    [field] = item and item.name or tostring(id),
    reason = found and "refused" or "not_found",
  })
end

local function ReportSelection(action, entry, id)
  ReportRefused("LIST.SELECTION_CHANGE_REFUSED", "list", Core.findSelection(RT.GetAccountProfile(), id), action, entry, id)
end

local function ReportGroup(action, group, id)
  ReportRefused("LIST.GROUP_CHANGE_REFUSED", "group", Core.findGroup(RT.GetAccountProfile(), id), action, group, id)
end

local function ReportContainerFull()
  Report("LIST.CONTAINER_FULL", { limit = Core.MAX_SAVED_SELECTIONS })
end

local function ReportGroupsFull()
  Report("LIST.GROUPS_FULL", { limit = Core.MAX_GROUPS })
end

RT.noneSelectionEntry = { id = nil, name = "", desiredQuests = {} }

local BuildSelectionContextMenu

local function AccountProfile()
  return RT.GetAccountProfile()
end

local function RequestRename(title, name, rename, id, onRefused)
  Skin.Dialog({
    title = title,
    body = "",
    editBox = { default = name, maxLetters = Core.MAX_SELECTION_NAME_LENGTH },
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function(text)
      local nextProfile, ok = rename(AccountProfile(), id, text)
      if not ok then
        onRefused()
        return
      end

      RT.SaveAccountProfile(nextProfile)
      RT.RefreshListsWindow()
    end,
  })
end

function RT.LoadSelectionPreset(entry)
  if not entry then
    return
  end

  RT.SetDesiredQuests(entry.desiredQuests)
  RT.SetActiveSelectionId(entry.id)

  RT.ApplyListDifficulty(entry.difficulty, "chargement liste " .. tostring(entry.name))

  if not RT.IsRolling() then
    RT.EvaluateCurrentObjectives()
  end

  RT.RefreshQuestWindow()
end

function RT.IsSelectionActive(entry)
  return entry ~= nil and entry.id ~= nil and RT.GetActiveSelectionId() == entry.id
end

function RT.IsSelectionDifficultyLocked(entry)
  if not entry or entry.difficulty == nil then
    return false
  end

  if RT.IsSelectionActive(entry) then
    return false
  end

  if RT.GetCurrentDifficulty() == entry.difficulty then
    return false
  end

  return not RT.CanApplyDifficulty()
end

function RT.RequestLoadSelection(entry)
  if not entry then
    return
  end

  if RT.IsRolling() then
    Report("LIST.CANNOT_SWITCH_ROLLING")
    return
  end

  if RT.IsSelectionActive(entry) then
    RT.LoadSelectionPreset(RT.noneSelectionEntry)
    RT.RefreshListsWindow()
    return
  end

  if RT.IsSelectionDifficultyLocked(entry) then
    Report("LIST.DIFFICULTY_LOCKED", { list = entry.name, difficulty = Core.difficultyLabel(entry.difficulty) })
    return
  end

  RT.LoadSelectionPreset(entry)
  RT.RefreshListsWindow()
end

function RT.RequestRenameSelection(entry)
  if not entry then
    return
  end

  RequestRename(string.format(L.LISTS_RENAME_DIALOG_TITLE, entry.name), entry.name, Core.renameSelection, entry.id, function()
    ReportSelection("rename", entry, entry.id)
  end)
end

function RT.RequestOverwriteSelection(entry)
  if not entry then
    return
  end

  Skin.Dialog({
    title = entry.name,
    body = string.format(L.LISTS_OVERWRITE_CONFIRM_TEXT, entry.name),
    acceptText = L.BUTTON_OKAY,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function()
      local nextProfile, ok = Core.updateSelectionContent(AccountProfile(), entry.id, state.desiredQuests)
      if not ok then
        ReportSelection("overwrite", entry, entry.id)
        return
      end

      RT.SaveAccountProfile(nextProfile)
      RT.SetActiveSelectionId(entry.id)
      RT.RefreshListsWindow()
      end,
  })
end

function RT.RequestDeleteSelection(entry)
  if not entry then
    return
  end

  Skin.Dialog({
    title = entry.name,
    body = string.format(L.LISTS_DELETE_CONFIRM_TEXT, entry.name),
    acceptText = L.BUTTON_DELETE,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function()
      local nextProfile, ok = Core.deleteSelection(AccountProfile(), entry.id)
      if not ok then
        ReportSelection("delete", entry, entry.id)
        return
      end

      RT.SaveAccountProfile(nextProfile)

      if RT.GetActiveSelectionId() == entry.id then
        RT.SetActiveSelectionId(nil)
      end

      RT.RefreshListsWindow()
      end,
  })
end

local function AskForNewSelection(groupId, titleKey, getDesired, activate)
  local profile = AccountProfile()

  if Core.selectionsFull(profile, groupId) then
    ReportContainerFull()
    return
  end

  Skin.Dialog({
    title = L[titleKey],
    body = "",
    editBox = { default = Core.peekNextSelectionName(profile), maxLetters = Core.MAX_SELECTION_NAME_LENGTH },
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function(text)
      local nextProfile, entry, err = Core.createSelection(AccountProfile(), getDesired(), text, groupId)

      if err == "full" then
        ReportContainerFull()
        return
      end

      RT.SaveAccountProfile(nextProfile)

      if entry and activate then
        RT.SetActiveSelectionId(entry.id)
      end

      RT.RefreshListsWindow()
      RT.RefreshQuestWindow()
      end,
  })
end

function RT.RequestCreateSelection(groupId)
  AskForNewSelection(groupId, "LISTS_NEW_DIALOG_TITLE", function()
    return state.desiredQuests
    end, true)
end

function RT.RequestCreateSelectionWithQuest(key, groupId)
  if type(key) ~= "string" or key == "" then
    return
  end

  AskForNewSelection(groupId, "QUEST_MENU_NEW_TITLE", function()
    return { [key] = true }
    end, false)
end

function RT.RequestSetQuestInSelection(entry, key, wanted)
  if not entry or entry.id == nil or type(key) ~= "string" or key == "" then
    return false
  end

  local nextProfile, ok = Core.setQuestInSelection(AccountProfile(), entry.id, key, wanted)

  if not ok then
    ReportSelection("set_quest", entry, entry.id)
    return false
  end

  RT.SaveAccountProfile(nextProfile)

  wanted = wanted and true or false

  if RT.GetActiveSelectionId() == entry.id
      and (state.desiredQuests[key] == true) ~= wanted then
    RT.ToggleDesiredQuest(key)
  end

  RT.RefreshListsWindow()
  RT.RefreshQuestWindow()

  return true
end

function RT.RequestCreateGroup()
  local profile = AccountProfile()

  if Core.groupsFull(profile) then
    ReportGroupsFull()
    return
  end

  Skin.Dialog({
    title = L.LISTS_NEW_GROUP_TITLE,
    body = "",
    editBox = { default = Core.peekNextGroupName(profile), maxLetters = Core.MAX_SELECTION_NAME_LENGTH },
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function(text)
      local nextProfile, group, err = Core.createGroup(AccountProfile(), text)

      if err == "full" then
        ReportGroupsFull()
        return
      end

      RT.SaveAccountProfile(nextProfile)

      if group then
        RT.SetOpenGroup(group.id, true)
      end

      RT.RefreshListsWindow()
      end,
  })
end

function RT.RequestRenameGroup(group)
  if not group then
    return
  end

  RequestRename(string.format(L.LISTS_RENAME_GROUP_TITLE, group.name), group.name, Core.renameGroup, group.id, function()
    ReportGroup("rename", group, group.id)
  end)
end

function RT.RequestDeleteGroup(group)
  if not group then
    return
  end

  local profile = AccountProfile()
  local count = Core.selectionCount(profile, group.id)
  local body

  if count == 0 then
    body = string.format(L.LISTS_DELETE_GROUP_EMPTY_BODY, group.name)
  else
    body = string.format(L.LISTS_DELETE_GROUP_BODY, group.name, RT.DescribeGroupContents(profile, group.id))
  end

  Skin.Dialog({
    title = L.LISTS_DELETE_GROUP_TITLE,
    body = body,
    acceptText = L.BUTTON_DELETE,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function()
      local activeId = RT.GetActiveSelectionId()
      local activeSelection = Core.findSelection(AccountProfile(), activeId)
      local nextProfile, ok = Core.deleteGroup(AccountProfile(), group.id)

      if not ok then
        ReportGroup("delete", group, group.id)
        return
      end

      RT.SaveAccountProfile(nextProfile)

      if activeSelection and Core.sameContainer(activeSelection.groupId, group.id) then
        RT.SetActiveSelectionId(nil)
      end

      if RT.GetOpenGroupId() == group.id then
        RT.SetOpenGroup(nil, true)
      end

      RT.RefreshListsWindow()
      end,
  })
end

function RT.RequestMoveSelection(entry, groupId)
  if not entry then
    return
  end

  local nextProfile, ok, err = Core.setSelectionGroup(AccountProfile(), entry.id, groupId)

  if err == "full" then
    ReportContainerFull()
    return
  end

  if not ok then
    ReportSelection("move", entry, entry.id)
    return
  end

  RT.SaveAccountProfile(nextProfile)
  RT.RefreshListsWindow()
end

local function BuildDifficultySubmenu(menu, entry)
  menu:Reset()
  menu:AddItem(entry.name, { header = true })
  menu:AddItem("< " .. L.LISTS_MENU_DIFFICULTY, {
    keepOpen = true,
    onClick = function()
      BuildSelectionContextMenu(menu, entry)
      end,
  })

  RT.AddDifficultySlider(menu, entry.difficulty, function(tier)
    RT.RequestSetSelectionDifficulty(entry, tier)
    end)

  menu:Layout()
end

local function BuildMoveSubmenu(menu, entry)
  local profile = AccountProfile()

  menu:Reset()
  menu:AddItem(entry.name, { header = true })
  menu:AddItem("< " .. L.LISTS_MENU_MOVE_TO, {
    keepOpen = true,
    onClick = function()
      BuildSelectionContextMenu(menu, entry)
      end,
  })

  menu:AddItem(L.LISTS_MOVE_TO_LIST, {
    checked = entry.groupId == nil,
    onClick = function()
      RT.RequestMoveSelection(entry, nil)
      end,
  })

  for i = 1, #(profile.groups) do
    local group = profile.groups[i]
    menu:AddItem(group.name, {
      checked = entry.groupId == group.id,
      onClick = function()
        RT.RequestMoveSelection(entry, group.id)
        end,
    })
  end

  menu:Layout()
end

BuildSelectionContextMenu = function(menu, entry)
  menu:Reset()
  menu:AddItem(entry.name, { header = true })

  if Core.groupCount(AccountProfile()) > 0 then
    menu:AddItem(L.LISTS_MENU_MOVE_TO, {
      arrow = true,
      keepOpen = true,
      onClick = function() BuildMoveSubmenu(menu, entry) end,
    })
  end

  menu:AddItem(L.LISTS_MENU_DIFFICULTY, {
    arrow = true,
    keepOpen = true,
    onClick = function() BuildDifficultySubmenu(menu, entry) end,
  })
  menu:AddItem(L.LISTS_MENU_UPDATE, {
    onClick = function() RT.RequestOverwriteSelection(entry) end,
  })
  menu:AddItem(L.LISTS_MENU_RENAME, {
    onClick = function() RT.RequestRenameSelection(entry) end,
  })
  menu:AddItem(L.LISTS_MENU_DELETE, {
    onClick = function() RT.RequestDeleteSelection(entry) end,
  })

  menu:Layout()
end

local function EnsureContextMenu()
  if not RT.listsContextMenu then
    RT.listsContextMenu = Skin.Menu("AutoCallboardListsContextMenu")
  end

  return RT.listsContextMenu
end

function RT.ShowSelectionContextMenu(row, entry)
  if not entry or entry.id == nil then
    return
  end

  local menu = EnsureContextMenu()
  BuildSelectionContextMenu(menu, entry)
  menu:OpenAt(row, "TOPLEFT", "TOPRIGHT", 4, 2)
end

function RT.ShowGroupContextMenu(anchor, group)
  if not group then
    return
  end

  local menu = EnsureContextMenu()
  menu:Reset()
  menu:AddItem(group.name, { header = true })
  menu:AddItem(L.LISTS_MENU_RENAME, {
    onClick = function() RT.RequestRenameGroup(group) end,
  })
  menu:AddItem(L.LISTS_MENU_DELETE, {
    onClick = function() RT.RequestDeleteGroup(group) end,
  })
  menu:Layout()
  menu:OpenAt(anchor, "TOPLEFT", "BOTTOMLEFT", 0, -2)
end

local function RowTooltip(row, entry)
  EbonAPI.Bricks.tip(row, entry.name or "")

  if entry.id == nil then
    GameTooltip:AddLine(L.LISTS_ROW_CLEAR_ENTRY, 1, 1, 1)
  else
    GameTooltip:AddLine(string.format(L.LISTS_ROW_QUEST_COUNT, Core.desiredQuestCount(entry.desiredQuests)), 1, 1, 1)

    if entry.difficulty then
      GameTooltip:AddLine(string.format(L.LISTS_ROW_TARGET_DIFFICULTY, Core.difficultyLabel(entry.difficulty)), 0.85, 0.78, 1)
    end
  end

  if RT.IsRolling() then
    GameTooltip:AddLine(L.LISTS_ROW_STOP_TO_SWITCH, 1, 0.4, 0.4)
  elseif RT.IsSelectionActive(entry) then
    GameTooltip:AddLine(L.LISTS_ROW_LEFT_CLICK_UNLOAD, 0.8, 0.8, 0.8)
  elseif RT.IsSelectionDifficultyLocked(entry) then
    GameTooltip:AddLine(L.LISTS_ROW_NEED_RESTED, 1, 0.4, 0.4)
  elseif entry.id == nil then
    GameTooltip:AddLine(L.LISTS_ROW_LEFT_CLICK_CLEAR, 0.8, 0.8, 0.8)
  else
    GameTooltip:AddLine(L.LISTS_ROW_LEFT_CLICK_LOAD, 0.8, 0.8, 0.8)
  end

  GameTooltip:Show()
end

local browser = RT.BuildBrowser({
  names = {
    listPanel = "AutoCallboardListPanel",
    groupPanel = "AutoCallboardGroupPanel",
    band = "AutoCallboardGroupBand",
    row = "AutoCallboardListRow",
  },
  hasList = true,
  listReservedRows = 1,
  emptyKey = "LISTS_WINDOW_EMPTY",
  maxGroups = function() return Core.MAX_GROUPS end,
  groups = function() return AccountProfile().groups end,
  getOpen = function() return RT.GetOpenGroupId() end,
  setOpen = function(value) RT.SetOpenGroupId(value) end,
  listTitle = function() return L.LISTS_WINDOW_TITLE end,
  listEntries = function()
    RT.noneSelectionEntry.name = L.LISTS_NONE_ENTRY

    local stored = Core.selectionsInContainer(AccountProfile(), nil)
    local entries = { RT.noneSelectionEntry }

    for i = 1, #(stored) do
      entries[#(entries) + 1] = stored[i]
    end

    return entries, #(stored)
  end,
  groupEntries = function(groupId) return Core.selectionsInContainer(AccountProfile(), groupId) end,
  count = function(groupId) return Core.selectionCount(AccountProfile(), groupId) end,
  rowText = function(entry)
    if entry.difficulty then
      return entry.name .. " " .. EbonAPI.Palette.code("heading") .. "[" .. Core.difficultyLabel(entry.difficulty) .. "]|r"
    end

    return entry.name
  end,
  rowState = function(entry)
    return RT.IsSelectionActive(entry), RT.IsRolling() or RT.IsSelectionDifficultyLocked(entry)
  end,
  rowTooltip = RowTooltip,
  onRowClick = function(row, entry, mouseButton)
    if mouseButton == "RightButton" then
      if entry.id ~= nil then
        RT.ShowSelectionContextMenu(row, entry)
      end
    else
      RT.RequestLoadSelection(entry)
    end
  end,
  canDrag = function(entry) return entry.id ~= nil end,
  entryGroup = function(entry) return entry.groupId end,
  dropRefused = function(groupId) return Core.selectionsFull(AccountProfile(), groupId) end,
  moveEntry = function(id, groupId, beforeId)
    local nextProfile, ok, err = Core.moveSelectionTo(AccountProfile(), id, groupId, beforeId)

    if ok then
      RT.SaveAccountProfile(nextProfile)
    elseif err == "full" then
      ReportContainerFull()
    else
      ReportSelection("move", nil, id)
    end

    return ok
  end,
  moveGroup = function(id, index)
    local nextProfile, moved = Core.moveGroupToIndex(AccountProfile(), id, index)

    if moved then
      RT.SaveAccountProfile(nextProfile)
    else
      ReportGroup("move", nil, id)
    end

    return moved
  end,
  groupMenu = function(anchor, group) RT.ShowGroupContextMenu(anchor, group) end,
  bandLines = function(groupId)
    return {
      { string.format(L.LISTS_ROW_QUEST_COUNT_GROUP, Core.selectionCount(AccountProfile(), groupId)), 1, 1, 1 },
      { L.LISTS_OPEN_GROUP_TOOLTIP, 0.8, 0.8, 0.8 },
    }
  end,
  onAdd = function(groupId) RT.RequestCreateSelection(groupId) end,
  addTip = { "LISTS_ADD_SELECTION_TITLE", "LISTS_ADD_SELECTION_TOOLTIP" },
  newGroup = {
    onClick = function() RT.RequestCreateGroup() end,
    tipTitle = "LISTS_NEW_GROUP_TITLE_SHORT",
    tipBody = "LISTS_NEW_GROUP_TOOLTIP",
    enabled = function() return not Core.groupsFull(AccountProfile()) end,
  },
  onAnimating = function(flag) RT.listsAnimating = flag end,
  createWindow = function(width, height, buttons)
    local window = Skin.Window("AutoCallboardListsWindow", {
      width = width,
      height = height,
      titleKey = "BUTTON_LISTS",
      strata = "HIGH",
      buttons = buttons,
      point = { "TOPRIGHT", RT.controlFrame, "TOPLEFT", -8, 0 },
    })
    RT.listsWindow = window

    return window
  end,
})

RT.CreateListsWindow = browser.Create
RT.RefreshListsWindow = browser.Refresh
RT.ToggleListsWindow = browser.Toggle
RT.SetOpenGroup = browser.SetOpen
RT.IsListsAnimating = browser.IsAnimating
RT.IsDraggingSelection = browser.IsDragging
