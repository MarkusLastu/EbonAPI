local Core = AutoCallboardCore
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local state = RT.state

local function CharacterName(key)
  local name = tostring(key or ""):match("([^/]+)$")

  if not name or name == "" then
    return tostring(key or "")
  end

  return name
end

function RT.GetAccountProfile()
  if type(state.accountProfile) ~= "table" or type(state.accountProfile.savedSelections) ~= "table" then
    state.accountProfile = Core.copyAccountProfile(state.accountProfile)
  end

  return state.accountProfile
end

function RT.SaveAccountProfile(nextProfile)
  state.accountProfile = nextProfile
  RT.TouchState()
end

function RT.EnsureCharacterState(key)
  key = key or RT.characterProfileKey

  if not key then
    return nil
  end

  if type(state.characterState) ~= "table" then
    state.characterState = {}
  end

  local entry = state.characterState[key]

  if type(entry) ~= "table" then
    entry = { desiredQuests = {}, activeSelectionId = nil, openGroupId = nil }
    state.characterState[key] = entry
  end

  if type(entry.desiredQuests) ~= "table" then
    entry.desiredQuests = {}
  end

  if type(entry.echoBar) ~= "table" then
    entry.echoBar = Core.copyEchoBar(nil)
  end

  return entry
end

function RT.SetDesiredQuests(map)
  local copy = Core.copyDesiredMap(map)
  local entry = RT.EnsureCharacterState()

  state.desiredQuests = copy

  if entry then
    entry.desiredQuests = copy
  end

  RT.TouchState()
end

function RT.ApplyCharacterState()
  local entry = RT.EnsureCharacterState()

  if not entry then
    return
  end

  state.desiredQuests = entry.desiredQuests
  RT.TouchState()
end

function RT.GetActiveSelectionId()
  local entry = RT.EnsureCharacterState()
  return entry and entry.activeSelectionId or nil
end

function RT.SetActiveSelectionId(id)
  local entry = RT.EnsureCharacterState()

  if entry and entry.activeSelectionId ~= id then
    entry.activeSelectionId = id
    RT.TouchState()
    RT.RefreshQuestWindow()
  end
end

function RT.GetOpenGroupId()
  local entry = RT.EnsureCharacterState()
  return entry and entry.openGroupId or nil
end

function RT.SetOpenGroupId(id)
  local entry = RT.EnsureCharacterState()

  if entry then
    entry.openGroupId = id
  end
end

local function MarkMigrated(key)
  if type(state.migratedCharacters) ~= "table" then
    state.migratedCharacters = {}
  end

  state.migratedCharacters[key] = true
end

local function FinishMigration(key, characterProfile, idMap, groupId)
  state.characterState[key] = Core.buildMigratedCharacterState(characterProfile, idMap, groupId)
  MarkMigrated(key)
  RT.ApplyCharacterState()
  RT.RefreshListsWindow()
  RT.RefreshQuestWindow()
end

local function ImportIntoList(key, characterProfile)
  local nextProfile, idMap = Core.importSelections(
      RT.GetAccountProfile(), characterProfile.savedSelections, nil)

  RT.SaveAccountProfile(nextProfile)
  state.accountListSeeded = true
  FinishMigration(key, characterProfile, idMap, nil)
  RT.api:Trace("migrationImportedList", key, Core.characterSelectionCount(characterProfile))
end

local function ImportIntoNewGroup(key, characterProfile)
  local nextProfile, group, _, cause = Core.createGroup(RT.GetAccountProfile(), CharacterName(key))

  if not group then
    RT.api:Report(RT.api:Problem("MIGRATION.GROUP_CREATE_FAILED", { character = CharacterName(key) }, cause))
    return false
  end

  local withSelections, idMap = Core.importSelections(
      nextProfile, characterProfile.savedSelections, group.id)

  RT.SaveAccountProfile(withSelections)
  FinishMigration(key, characterProfile, idMap, group.id)
  RT.api:Trace("migrationImportedGroup", key, group.name)

  return true
end

local function DiscardCharacterSelections(key, characterProfile)
  state.characterState[key] = { desiredQuests = {}, activeSelectionId = nil, openGroupId = nil }
  MarkMigrated(key)
  RT.ApplyCharacterState()
  RT.RefreshListsWindow()
  RT.RefreshQuestWindow()
  RT.api:Trace("migrationDiscarded", key, Core.characterSelectionCount(characterProfile))
end

local function DescribeGroupContents(profile, groupId)
  local names, extra = Core.groupSelectionNames(profile, groupId, 3)

  if #(names) == 0 then
    return L.LISTS_GROUP_EMPTY_CONTENTS
  end

  local joined = table.concat(names, ", ")

  if extra > 0 then
    return string.format(L.LISTS_GROUP_MORE_CONTENTS, joined, extra)
  end

  return joined
end

RT.DescribeGroupContents = DescribeGroupContents

local PromptGroupsFull

local function PromptReplaceGroup(key, characterProfile, groupId)
  local profile = RT.GetAccountProfile()
  local group = Core.findGroup(profile, groupId)

  if not group then
    PromptGroupsFull(key, characterProfile)
    return
  end

  AutoCallboardSkin.Dialog({
    title = L.MIGRATION_REPLACE_TITLE,
    body = string.format(L.MIGRATION_REPLACE_BODY, group.name, DescribeGroupContents(profile, groupId)),
    acceptText = L.BUTTON_DELETE,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function()
      local nextProfile, removed, _, cause = Core.deleteGroup(RT.GetAccountProfile(), groupId)

      if not removed then
        RT.api:Report(RT.api:Problem("MIGRATION.GROUP_DELETE_FAILED", { group = groupId }, cause))
        return
      end

      RT.SaveAccountProfile(nextProfile)

      if not ImportIntoNewGroup(key, characterProfile) then
        ImportIntoList(key, characterProfile)
      end
      end,
    onCancel = function()
      PromptGroupsFull(key, characterProfile)
      end,
  })
end

local function PromptPickGroup(key, characterProfile)
  local profile = RT.GetAccountProfile()
  local choices = {}

  for i = 1, #(profile.groups) do
    local group = profile.groups[i]
    table.insert(choices, {
      text = string.format(L.MIGRATION_GROUP_CHOICE, group.name, Core.selectionCount(profile, group.id)),
      value = group.id,
    })
  end

  AutoCallboardSkin.Dialog({
    title = L.MIGRATION_PICK_TITLE,
    body = string.format(L.MIGRATION_PICK_BODY, CharacterName(key)),
    choices = choices,
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function(groupId)
      if groupId then
        PromptReplaceGroup(key, characterProfile, groupId)
      else
        PromptGroupsFull(key, characterProfile)
      end
      end,
    onCancel = function()
      PromptGroupsFull(key, characterProfile)
      end,
  })
end

PromptGroupsFull = function(key, characterProfile)
  AutoCallboardSkin.Dialog({
    title = L.MIGRATION_FULL_TITLE,
    body = string.format(L.MIGRATION_FULL_BODY,
        CharacterName(key),
        Core.characterSelectionCount(characterProfile),
        Core.MAX_GROUPS),
    acceptText = L.MIGRATION_KEEP_BUTTON,
    cancelText = L.MIGRATION_DISCARD_BUTTON,
    onAccept = function()
      PromptPickGroup(key, characterProfile)
      end,
    onCancel = function()
      DiscardCharacterSelections(key, characterProfile)
      end,
  })
end

function RT.RunAccountMigration(key)
  if not key then
    return
  end

  if type(state.migratedCharacters) ~= "table" then
    state.migratedCharacters = {}
  end

  if type(state.characterState) ~= "table" then
    state.characterState = {}
  end

  if type(state.characterProfiles) ~= "table" then
    state.characterProfiles = {}
  end

  local alreadyMigrated = {}

  for migratedKey in pairs(state.migratedCharacters) do
    alreadyMigrated[migratedKey] = true
  end

  for migratedKey in pairs(alreadyMigrated) do
    if state.characterProfiles[migratedKey] ~= nil then
      state.characterProfiles[migratedKey] = nil
      RT.api:Trace("migrationPurged", migratedKey)
    end
  end

  if alreadyMigrated[key] then
    return
  end

  local characterProfile = state.characterProfiles[key]

  if type(characterProfile) ~= "table" then
    if characterProfile ~= nil then
      RT.api:Report(RT.api:Problem("MIGRATION.PROFILE_INVALID",
          { character = CharacterName(key), value = type(characterProfile) }))
    end

    return
  end

  if Core.characterSelectionCount(characterProfile) == 0 then
    FinishMigration(key, characterProfile, nil, nil)
    return
  end

  if not state.accountListSeeded then
    ImportIntoList(key, characterProfile)
    return
  end

  if Core.groupsFull(RT.GetAccountProfile()) then
    PromptGroupsFull(key, characterProfile)
    return
  end

  if not ImportIntoNewGroup(key, characterProfile) then
    ImportIntoList(key, characterProfile)
  end
end
