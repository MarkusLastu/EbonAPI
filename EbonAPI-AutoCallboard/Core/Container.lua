local Core = AutoCallboardCore or {}
AutoCallboardCore = Core
local L = AutoCallboardLocale

local type, tonumber, math, table, string = type, tonumber, math, table, string

Core.CLEARED = Core.CLEARED or {}

local function sameContainer(itemGroupId, groupId)
  return (tonumber(itemGroupId) or 0) == (tonumber(groupId) or 0)
end

Core.sameContainer = sameContainer

function Core.buildContainer(spec)
  local C = {}
  local ITEMS, GROUPS = spec.items, spec.groups
  local NEXT_ITEM, NEXT_GROUP = spec.nextItem, spec.nextGroup
  local GROUP_KEY = spec.groupKey or "groupId"

  local function list(profile)
    if type(profile) ~= "table" or type(profile[ITEMS]) ~= "table" then
      return nil
    end
    return profile[ITEMS]
  end

  local function groupList(profile)
    if not GROUPS or type(profile) ~= "table" or type(profile[GROUPS]) ~= "table" then
      return nil
    end
    return profile[GROUPS]
  end

  local function positiveCounter(value)
    return type(value) == "number" and value >= 1 and value == math.floor(value)
  end

  local function shaped(profile)
    return type(profile) == "table"
        and type(profile[ITEMS]) == "table"
        and (not GROUPS or type(profile[GROUPS]) == "table")
        and positiveCounter(profile[NEXT_ITEM])
        and (not NEXT_GROUP or positiveCounter(profile[NEXT_GROUP]))
  end

  local function copyArray(source)
    local target = {}

    for i = 1, #(source) do
      target[i] = source[i]
    end

    return target
  end

  local function copy(profile)
    if not shaped(profile) then
      if profile ~= nil and not (type(profile) == "table" and next(profile) == nil) then
        Core.repaired("CONTAINER.PROFILE_REPAIRED", { profile = ITEMS, value = type(profile) }, profile)
      end

      return spec.copyProfile(profile)
    end

    local nextProfile = {}

    for key, value in pairs(profile) do
      nextProfile[key] = value
    end

    nextProfile[ITEMS] = copyArray(profile[ITEMS])

    if GROUPS then
      nextProfile[GROUPS] = copyArray(profile[GROUPS])
    end

    return nextProfile
  end

  local function own(rows, index)
    local entry = {}

    for key, value in pairs(rows[index]) do
      entry[key] = value
    end

    rows[index] = entry

    return entry
  end

  local function itemName(number)
    return string.format(L[spec.itemNameKey], tostring(number))
  end

  local function groupName(number)
    return string.format(L[spec.groupNameKey], tostring(number))
  end

  local function indexOf(rows, id)
    if not rows or id == nil then
      return nil
    end

    for i = 1, #(rows) do
      if rows[i].id == id then
        return i
      end
    end

    return nil
  end

  local function renameIn(profile, key, finder, id, newName)
    local nextProfile = copy(profile)
    local index = finder(nextProfile, id)

    if not index then
      return nextProfile, false, "not_found", Core.problem("CONTAINER.NOT_FOUND", { number = id })
    end

    local entry = own(nextProfile[key], index)
    entry.name = Core.sanitizeSelectionName(newName, entry.name)

    return nextProfile, true
  end

  function C.itemsIn(profile, groupId)
    local entries = {}
    local rows = list(profile)

    if not rows then
      return entries
    end

    for i = 1, #(rows) do
      if sameContainer(rows[i][GROUP_KEY], groupId) then
        table.insert(entries, rows[i])
      end
    end

    return entries
  end

  function C.count(profile, groupId)
    local rows = list(profile)

    if not rows then
      return 0
    end

    local count = 0

    for i = 1, #(rows) do
      if sameContainer(rows[i][GROUP_KEY], groupId) then
        count = count + 1
      end
    end

    return count
  end

  function C.full(profile, groupId)
    return C.count(profile, groupId) >= spec.maxItems()
  end

  function C.peekNextName(profile)
    local number = type(profile) == "table" and tonumber(profile[NEXT_ITEM]) or 1
    return itemName(number or 1)
  end

  function C.findIndex(profile, id)
    return indexOf(list(profile), id)
  end

  function C.find(profile, id)
    local index = C.findIndex(profile, id)

    if not index then
      return nil
    end

    return profile[ITEMS][index]
  end

  function C.create(profile, name, groupId, payload)
    local nextProfile = copy(profile)

    if C.full(nextProfile, groupId) then
      return nextProfile, nil, "full", Core.problem("CONTAINER.FULL", { group = groupId or 0, max = spec.maxItems() })
    end

    local number = nextProfile[NEXT_ITEM]
    nextProfile[NEXT_ITEM] = number + 1

    local entry = {
      id = number,
      name = Core.sanitizeSelectionName(name, itemName(number)),
    }

    entry[GROUP_KEY] = tonumber(groupId)

    for key, value in pairs(payload or {}) do
      entry[key] = value
    end

    table.insert(nextProfile[ITEMS], entry)

    return nextProfile, entry, nil
  end

  function C.rename(profile, id, newName)
    return renameIn(profile, ITEMS, C.findIndex, id, newName)
  end

  function C.update(profile, id, fields)
    local nextProfile = copy(profile)
    local index = C.findIndex(nextProfile, id)

    if not index then
      return nextProfile, false, "not_found", Core.problem("CONTAINER.NOT_FOUND", { number = id })
    end

    local entry = own(nextProfile[ITEMS], index)

    for key, value in pairs(fields or {}) do
      if value == Core.CLEARED then
        entry[key] = nil
      else
        entry[key] = value
      end
    end

    return nextProfile, true
  end

  function C.delete(profile, id)
    local nextProfile = copy(profile)
    local index = C.findIndex(nextProfile, id)

    if not index then
      return nextProfile, false, "not_found", Core.problem("CONTAINER.NOT_FOUND", { number = id })
    end

    table.remove(nextProfile[ITEMS], index)

    return nextProfile, true
  end

  function C.setGroup(profile, id, groupId)
    local nextProfile = copy(profile)
    local index = C.findIndex(nextProfile, id)

    if not index then
      return nextProfile, false, "not_found", Core.problem("CONTAINER.NOT_FOUND", { number = id })
    end

    groupId = tonumber(groupId)

    if groupId and not C.hasGroup(nextProfile, groupId) then
      return nextProfile, false, "group_unknown", Core.problem("CONTAINER.GROUP_UNKNOWN", { group = groupId })
    end

    if sameContainer(nextProfile[ITEMS][index][GROUP_KEY], groupId) then
      return nextProfile, true
    end

    if C.full(nextProfile, groupId) then
      return nextProfile, false, "full", Core.problem("CONTAINER.FULL", { group = groupId or 0, max = spec.maxItems() })
    end

    own(nextProfile[ITEMS], index)[GROUP_KEY] = groupId

    return nextProfile, true
  end

  function C.moveTo(profile, id, groupId, beforeId)
    local nextProfile = copy(profile)
    local index = C.findIndex(nextProfile, id)

    if not index then
      return nextProfile, false, "not_found", Core.problem("CONTAINER.NOT_FOUND", { number = id })
    end

    if beforeId == id then
      return nextProfile, true
    end

    groupId = tonumber(groupId)

    if groupId ~= nil and groupId ~= 0 and not C.hasGroup(nextProfile, groupId) then
      return nextProfile, false, "group_unknown", Core.problem("CONTAINER.GROUP_UNKNOWN", { group = groupId })
    end

    local rows = nextProfile[ITEMS]
    local entry = own(rows, index)
    local movingIn = not sameContainer(entry[GROUP_KEY], groupId)

    if movingIn and C.full(nextProfile, groupId) then
      return nextProfile, false, "full", Core.problem("CONTAINER.FULL", { group = groupId or 0, max = spec.maxItems() })
    end

    table.remove(rows, index)
    entry[GROUP_KEY] = groupId

    local target, missing

    if beforeId ~= nil then
      target = C.findIndex(nextProfile, beforeId)

      if not target then
        missing = Core.problem("CONTAINER.MOVE_TARGET_MISSING", { before = beforeId })
      end
    end

    if not target then
      target = #(rows) + 1

      for i = #(rows), 1, -1 do
        if sameContainer(rows[i][GROUP_KEY], groupId) then
          target = i + 1
          break
        end
      end
    end

    table.insert(rows, target, entry)

    return nextProfile, true, nil, missing
  end

  function C.findGroupIndex(profile, id)
    return indexOf(groupList(profile), id)
  end

  function C.hasGroup(profile, id)
    if spec.hasGroup then
      return spec.hasGroup(id) and true or false
    end

    return C.findGroupIndex(profile, id) ~= nil
  end

  function C.findGroup(profile, id)
    local index = C.findGroupIndex(profile, id)

    if not index then
      return nil
    end

    return profile[GROUPS][index]
  end

  function C.groupCount(profile)
    local rows = groupList(profile)

    if not rows then
      return 0
    end

    return #(rows)
  end

  function C.groupsFull(profile)
    return C.groupCount(profile) >= spec.maxGroups()
  end

  function C.peekNextGroupName(profile)
    local number = type(profile) == "table" and tonumber(profile[NEXT_GROUP]) or 1
    return groupName(number or 1)
  end

  function C.createGroup(profile, name)
    local nextProfile = copy(profile)

    if C.groupsFull(nextProfile) then
      return nextProfile, nil, "full", Core.problem("CONTAINER.GROUPS_FULL", { max = spec.maxGroups() })
    end

    local number = nextProfile[NEXT_GROUP]
    nextProfile[NEXT_GROUP] = number + 1

    local entry = {
      id = number,
      name = Core.sanitizeSelectionName(name, groupName(number)),
    }

    table.insert(nextProfile[GROUPS], entry)

    return nextProfile, entry, nil
  end

  function C.moveGroupToIndex(profile, id, index)
    local nextProfile = copy(profile)
    local from = C.findGroupIndex(nextProfile, id)

    if not from then
      return nextProfile, false, "not_found", Core.problem("CONTAINER.NOT_FOUND", { number = id })
    end

    local rows = nextProfile[GROUPS]
    local count = #(rows)
    index = math.floor(tonumber(index) or from)

    if index < 1 then
      index = 1
    end

    if index > count then
      index = count
    end

    if index == from then
      return nextProfile, true
    end

    table.insert(rows, index, table.remove(rows, from))

    return nextProfile, true
  end

  function C.renameGroup(profile, id, newName)
    return renameIn(profile, GROUPS, C.findGroupIndex, id, newName)
  end

  function C.groupItemNames(profile, groupId, limit)
    local entries = C.itemsIn(profile, groupId)
    local names = {}

    limit = tonumber(limit) or 3

    for i = 1, #(entries) do
      if i > limit then
        break
      end

      table.insert(names, tostring(entries[i].name or ""))
    end

    return names, math.max(0, #(entries) - #(names))
  end

  function C.deleteGroup(profile, id)
    local nextProfile = copy(profile)
    local index = C.findGroupIndex(nextProfile, id)

    if not index then
      return nextProfile, false, "not_found", Core.problem("CONTAINER.NOT_FOUND", { number = id })
    end

    local groupId = nextProfile[GROUPS][index].id
    table.remove(nextProfile[GROUPS], index)

    local rows = nextProfile[ITEMS]

    for i = #(rows), 1, -1 do
      if sameContainer(rows[i][GROUP_KEY], groupId) then
        table.remove(rows, i)
      end
    end

    return nextProfile, true
  end

  return C
end
