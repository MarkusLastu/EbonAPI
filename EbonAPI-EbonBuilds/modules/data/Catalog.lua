local _, ns = ...

local Catalog = {}
ns.Catalog = Catalog

local QUALITY_SUFFIXES = {
    " %- Common$", " %- Uncommon$", " %- Rare$", " %- Epic$", " %- Legendary$"
}

local function StripQualitySuffix(name)
    for _, pattern in ipairs(QUALITY_SUFFIXES) do
        local stripped = name:match("^(.+)" .. pattern)
        if stripped then return stripped end
    end
    return name
end

local cache = {}

local function Database()
    return EbonAPI.Ebonhold.PerkDatabase()
end

function Catalog.Entry(spellId)
    local db = Database()
    if not db or not spellId then return nil end
    return db[spellId]
end

local function BuildKeys()
    local db = Database()
    if not db then return nil end
    local keys, members = {}, {}
    for spellId, data in pairs(db) do
        local group = data.groupId
        local key = (group and group > 0) and group or spellId
        keys[spellId] = key
        local list = members[key]
        if not list then
            list = {}
            members[key] = list
        end
        list[#list + 1] = spellId
    end
    if next(keys) then
        cache.keys, cache.members = keys, members
    end
    return keys
end

function Catalog.Key(spellId)
    local keys = cache.keys or BuildKeys()
    return keys and keys[spellId] or spellId
end

function Catalog.KeySpell(key, classToken)
    if not cache.members then BuildKeys() end
    local list = cache.members and cache.members[key]
    if not list then return key end
    local bitVal = classToken and ns.Const.CLASS_BITS[classToken]
    local db = Database()
    for i = 1, #list do
        local mask = db and db[list[i]] and db[list[i]].classMask or 0
        if not bitVal or mask == 0 or bit.band(mask, bitVal) ~= 0 then return list[i] end
    end
    return list[1]
end

function Catalog.BestByName()
    if cache.best then return cache.best end
    local best = {}
    local db = Database()
    if not db then return best end
    for spellId, data in pairs(db) do
        local raw = data.comment
        if raw and raw ~= "" then
            local name = StripQualitySuffix(raw)
            local existing = best[name]
            local mask = data.classMask or 0
            if not existing then
                existing = { spellId = spellId, quality = data.quality, qualities = {}, families = data.families or {}, classMask = mask, spellIds = {} }
                best[name] = existing
            else
                existing.classMask = bit.bor(existing.classMask or 0, mask)
                if data.quality > existing.quality then
                    existing.spellId  = spellId
                    existing.quality  = data.quality
                    existing.families = data.families or {}
                end
            end
            existing.qualities[data.quality] = true
            existing.spellIds[data.quality] = spellId
        end
    end
    if next(best) then cache.best = best end
    return best
end

function Catalog.WeightKey(spellId)
    if not spellId then return nil end
    local map = cache.weightKey
    if not map then
        map = {}
        for name, entry in pairs(Catalog.BestByName()) do
            for _, id in pairs(entry.spellIds or {}) do
                map[id] = name
            end
        end
        if next(map) then cache.weightKey = map end
    end
    return map[spellId]
end

function Catalog.Variants(spellId)
    if not spellId then return nil end
    local name = Catalog.WeightKey(spellId)
    if not name then return nil end
    local variants = cache.variants
    if not variants then
        variants = {}
        cache.variants = variants
    end
    local out = variants[name]
    if out then return out end
    local entry = Catalog.BestByName()[name]
    if not entry or not entry.spellIds then return nil end
    out = {}
    for _, id in pairs(entry.spellIds) do out[#out + 1] = id end
    variants[name] = out
    return out
end

function Catalog.SortedList()
    if cache.sorted then return cache.sorted end
    local list = {}
    for name, entry in pairs(Catalog.BestByName()) do
        list[#list + 1] = {
            spellId = entry.spellId, name = name, lname = name:lower(),
            quality = entry.quality, qualities = entry.qualities,
            families = entry.families, classMask = entry.classMask or 0,
            spellIds = entry.spellIds,
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    if #list > 0 then cache.sorted = list end
    return list
end

function Catalog.AllQualities()
    if cache.allQualities then return cache.allQualities end
    local list = {}
    local db = Database()
    if not db then return list end
    for spellId, data in pairs(db) do
        local raw = data.comment
        if raw and raw ~= "" then
            local name = StripQualitySuffix(raw)
            list[#list + 1] = {
                spellId = spellId,
                name = name,
                lname = name:lower(),
                quality = data.quality,
                classMask = data.classMask or 0,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.quality < b.quality
    end)
    if #list > 0 then cache.allQualities = list end
    return list
end
