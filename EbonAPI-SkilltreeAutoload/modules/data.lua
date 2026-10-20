local NS = SkillTreeAutoLoad
local L = NS.L

local Data = {}
NS.Data = Data

local SCHEMA_VERSION = 1

local function IsTable(value)
    return type(value) == "table"
end

local function Migrate(db)
    for _, save in pairs(db.saves) do
        if IsTable(save) then
            save.nodeChoices = nil
            save.updatedAt = nil
        end
    end
    db.version = SCHEMA_VERSION
end

local function EnsureShape(db)
    if not IsTable(db.settings) then db.settings = {} end
    if not IsTable(db.groups) then db.groups = {} end
    if not IsTable(db.saves) then db.saves = {} end
    if not IsTable(db.imported) then db.imported = {} end
    if type(db.nextId) ~= "number" then db.nextId = 1 end
    return db
end

local MAX_RANK = 32

local function RepairRanks(nodeRanks, saveName)
    for nodeId, rank in pairs(nodeRanks) do
        local after
        if type(nodeId) ~= "number" or type(rank) ~= "number"
            or rank ~= math.floor(rank) or rank <= 0 then
            after = 0
            nodeRanks[nodeId] = nil
        elseif rank > MAX_RANK then
            after = MAX_RANK
            nodeRanks[nodeId] = MAX_RANK
        end
        if after then
            NS.api:Repaired("SAVE.RANKS_REPAIRED",
                { save = saveName, node = tostring(nodeId), before = tostring(rank), after = after }, rank)
        end
    end
end

local function Sanitize(db)
    for id, group in pairs(db.groups) do
        if not IsTable(group) or type(group.name) ~= "string" then
            db.groups[id] = nil
        elseif type(group.order) ~= "number" then
            group.order = 0
        end
    end

    for id, save in pairs(db.saves) do
        if not IsTable(save) or type(save.name) ~= "string" then
            db.saves[id] = nil
        else
            if not IsTable(save.nodeRanks) then save.nodeRanks = {} end
            RepairRanks(save.nodeRanks, save.name)
            if save.progressive ~= true then save.progressive = nil end
        end
    end

    if db.version ~= SCHEMA_VERSION then Migrate(db) end
end

local EMPTY = {}
local index

local function Touch()
    index = nil
end

local function NewId(db)
    local id = "id" .. db.nextId
    db.nextId = db.nextId + 1
    Touch()
    return id
end

local function SortedGroupIds(db)
    local ids = {}
    for id in pairs(db.groups) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local orderA, orderB = db.groups[a].order or 0, db.groups[b].order or 0
        if orderA == orderB then return a < b end
        return orderA < orderB
    end)
    return ids
end

local function BuildIndex(db)
    local groups = SortedGroupIds(db)
    local byGroup, ungrouped = {}, {}
    for i = 1, #groups do byGroup[groups[i]] = {} end

    for id, save in pairs(db.saves) do
        local bucket = (save.groupId == nil) and ungrouped or byGroup[save.groupId]
        if bucket then bucket[#bucket + 1] = id end
    end

    local saves = db.saves
    local function byName(a, b)
        local nameA, nameB = saves[a].name or "", saves[b].name or ""
        if nameA == nameB then return a < b end
        return nameA < nameB
    end
    for _, ids in pairs(byGroup) do table.sort(ids, byName) end
    table.sort(ungrouped, byName)

    index = { groups = groups, byGroup = byGroup, ungrouped = ungrouped }
    return index
end

local function Index(db)
    return index or BuildIndex(db)
end

local function CreateGroupIn(db, name)
    local id = NewId(db)

    local maxOrder = 0
    for _, group in pairs(db.groups) do
        if (group.order or 0) > maxOrder then maxOrder = group.order end
    end

    db.groups[id] = { name = name, order = maxOrder + 1 }
    return id
end

local function CopyRanks(source)
    local copy = {}
    for nodeId, rank in pairs(source) do
        if type(rank) == "number" and rank > 0 then copy[nodeId] = rank end
    end
    return copy
end

local function SameRanks(a, b)
    for nodeId, rank in pairs(a) do
        if b[nodeId] ~= rank then return false end
    end
    for nodeId in pairs(b) do
        if a[nodeId] == nil then return false end
    end
    return true
end

local function FindGroupByName(db, name)
    for id, group in pairs(db.groups) do
        if group.name == name then return id end
    end
end

local function FindSaveInGroup(db, groupId, name)
    for id, save in pairs(db.saves) do
        if save.groupId == groupId and save.name == name then return id end
    end
end

local function UniqueSaveName(db, groupId, baseName, charName)
    local candidate = baseName .. " (" .. charName .. ")"
    local n = 1
    while FindSaveInGroup(db, groupId, candidate) do
        n = n + 1
        candidate = baseName .. " (" .. charName .. ") " .. n
    end
    return candidate
end

local function LegacyGroupIds(legacy)
    local groups = IsTable(legacy.groups) and legacy.groups or {}
    local ids = {}
    for id, group in pairs(groups) do
        if IsTable(group) and type(group.name) == "string" then ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b)
        local orderA = tonumber(groups[a].order) or 0
        local orderB = tonumber(groups[b].order) or 0
        if orderA == orderB then return a < b end
        return orderA < orderB
    end)
    return ids
end

local function LegacySaveIds(legacy)
    local saves = IsTable(legacy.saves) and legacy.saves or {}
    local ids = {}
    for id, save in pairs(saves) do
        if IsTable(save) and type(save.name) == "string" then ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b)
        local nameA, nameB = saves[a].name, saves[b].name
        if nameA == nameB then return a < b end
        return nameA < nameB
    end)
    return ids
end

local function CharacterKey()
    local name = UnitName("player")
    if not name or name == "" or name == UNKNOWNOBJECT then return nil end
    return name .. "-" .. (GetRealmName() or ""), name
end

local function MigrateCharacterDB(db)
    local legacy = EbonAPISkillTreeAutoLoadDB
    if not IsTable(legacy) then return end

    local key, charName = CharacterKey()
    if not key or db.imported[key] then return end

    local groupIds = {}
    for _, oldId in ipairs(LegacyGroupIds(legacy)) do
        local name = legacy.groups[oldId].name
        groupIds[oldId] = FindGroupByName(db, name) or CreateGroupIn(db, name)
    end

    local imported, merged = 0, 0
    for _, oldId in ipairs(LegacySaveIds(legacy)) do
        local save = legacy.saves[oldId]
        local ranks = CopyRanks(IsTable(save.nodeRanks) and save.nodeRanks or {})
        local groupId = save.groupId and groupIds[save.groupId] or nil
        local twinId = FindSaveInGroup(db, groupId, save.name)

        if twinId and SameRanks(db.saves[twinId].nodeRanks, ranks) then
            merged = merged + 1
        else
            local name = save.name
            if twinId then name = UniqueSaveName(db, groupId, save.name, charName) end
            db.saves[NewId(db)] = {
                name = name,
                groupId = groupId,
                nodeRanks = ranks,
            }
            imported = imported + 1
        end
    end

    if not db.settings.adoptedFromCharacter then
        if IsTable(legacy.settings) and legacy.settings.panelSide == "LEFT" then
            db.settings.panelSide = "LEFT"
        end
        db.settings.adoptedFromCharacter = true
    end

    db.imported[key] = true

    if imported > 0 or merged > 0 then
        NS.api:Notify(string.format(L.MSG_MIGRATED, charName, imported, merged))
    end
end

function Data.Init()
    if not IsTable(EbonAPISkillTreeAutoLoadAccountDB) then EbonAPISkillTreeAutoLoadAccountDB = {} end
    local db = EnsureShape(EbonAPISkillTreeAutoLoadAccountDB)

    Sanitize(db)
    MigrateCharacterDB(db)

    if db.settings.panelSide ~= "LEFT" then db.settings.panelSide = "RIGHT" end

    Touch()
    return db
end

local function DB()
    if not IsTable(EbonAPISkillTreeAutoLoadAccountDB) then return Data.Init() end
    return EnsureShape(EbonAPISkillTreeAutoLoadAccountDB)
end

function Data.CreateGroup(name)
    return CreateGroupIn(DB(), name)
end

function Data.RenameGroup(groupId, newName)
    local group = DB().groups[groupId]
    if not group then return false end
    group.name = newName
    Touch()
    return true
end

function Data.DeleteGroup(groupId)
    local db = DB()
    if not db.groups[groupId] then return false end

    db.groups[groupId] = nil
    for _, save in pairs(db.saves) do
        if save.groupId == groupId then save.groupId = nil end
    end
    Touch()
    return true
end

function Data.GetGroup(groupId)
    return DB().groups[groupId]
end

function Data.GetSortedGroupIds()
    return Index(DB()).groups
end

function Data.CreateSave(name, groupId, nodeRanks)
    local db = DB()
    local id = NewId(db)
    db.saves[id] = {
        name = name or L.DEFAULT_SAVE_NAME,
        groupId = groupId,
        nodeRanks = nodeRanks or {},
    }
    return id
end

function Data.UpdateSaveContent(saveId, nodeRanks)
    local save = DB().saves[saveId]
    if not save then return false end
    save.nodeRanks = nodeRanks or {}
    return true
end

function Data.RenameSave(saveId, newName)
    local save = DB().saves[saveId]
    if not save then return false end
    save.name = newName
    Touch()
    return true
end

function Data.SetSaveProgressive(saveId, enabled)
    local save = DB().saves[saveId]
    if not save then return false end
    save.progressive = enabled and true or nil
    return true
end

function Data.MoveSaveToGroup(saveId, groupId)
    local save = DB().saves[saveId]
    if not save then return false end
    save.groupId = groupId
    Touch()
    return true
end

function Data.DeleteSave(saveId)
    local db = DB()
    if not db.saves[saveId] then return false end
    db.saves[saveId] = nil
    Touch()
    return true
end

function Data.GetSave(saveId)
    return DB().saves[saveId]
end

function Data.GetSortedSaveIdsInGroup(groupId)
    local idx = Index(DB())
    if groupId == nil then return idx.ungrouped end
    return idx.byGroup[groupId] or EMPTY
end

function Data.SetPanelSide(side)
    DB().settings.panelSide = (side == "LEFT") and "LEFT" or "RIGHT"
end

function Data.GetPanelSide()
    return DB().settings.panelSide
end

function Data.SetCompact(enabled)
    DB().settings.compact = enabled and true or nil
end

function Data.IsCompact()
    return DB().settings.compact == true
end

function Data.SetPanelCollapsed(collapsed)
    DB().settings.collapsed = collapsed and true or nil
end

function Data.IsPanelCollapsed()
    return DB().settings.collapsed == true
end

function Data.SetPreviewCamera(enabled)
    DB().settings.noPreviewCamera = (not enabled) and true or nil
end

function Data.IsPreviewCamera()
    return DB().settings.noPreviewCamera ~= true
end


local VIEWS = { list = true, grid = true, gauge = true }
local DETAILS = { inline = true, dock = true }
local SORTS = { name = true, pct = true, cost = true }
local MIN_WIDTH, MAX_WIDTH = 200, 280

function Data.SetView(view)
    if view ~= nil and not VIEWS[view] then return false end
    DB().settings.view = view
    return true
end

function Data.GetView()
    local view = DB().settings.view
    return VIEWS[view] and view or nil
end

function Data.SetDetail(detail)
    if detail ~= nil and not DETAILS[detail] then return false end
    DB().settings.detail = detail
    return true
end

function Data.GetDetail()
    local detail = DB().settings.detail
    return DETAILS[detail] and detail or nil
end

function Data.SetSort(sort)
    if not SORTS[sort] then return false end
    DB().settings.sort = (sort ~= "name") and sort or nil
    return true
end

function Data.GetSort()
    local sort = DB().settings.sort
    return SORTS[sort] and sort or "name"
end

function Data.SetGrouped(grouped)
    if type(grouped) ~= "boolean" then return false end
    DB().settings.ungrouped = (not grouped) and true or nil
    return true
end

function Data.IsGrouped()
    return DB().settings.ungrouped ~= true
end

function Data.SetPanelWidth(width)
    if width ~= nil and (type(width) ~= "number" or width ~= width or width < MIN_WIDTH or width > MAX_WIDTH) then
        return false
    end
    DB().settings.panelWidth = width
    return true
end

function Data.GetPanelWidth()
    local width = DB().settings.panelWidth
    if type(width) == "number" and width >= MIN_WIDTH and width <= MAX_WIDTH then return width end
    return nil
end
