EbonBuilds.Matrix = {}

local POINTS = { pick = 3, ban = -5 }

local MIN_BUILDS     = 3
local MIN_PEOPLE     = 1
local MIN_BAN_PEOPLE = 3

local Key = EbonBuilds.Catalog.Key

local version = 0

function EbonBuilds.Matrix.Touch() version = version + 1 end

function EbonBuilds.Matrix.Version() return version end

local function PlayerClass()
    return EbonBuilds.Build and EbonBuilds.Build.PlayerClassToken()
end

local checked = nil

local function Store()
    local m = EbonAPIEbonBuildsDB.echoMatrix
    if m and m == checked then return m end
    EbonAPIEbonBuildsDB.echoMatrix = m or {}
    m = EbonAPIEbonBuildsDB.echoMatrix

    m.peers = nil

    m.builds = m.builds or {}
    local own = m.builds.own
    if type(own) ~= "table" or type(own.slots) ~= "table" then
        if own ~= nil then
            EbonBuilds.api:Repaired("MATRIX.REPAIRED", { field = "own", lost = true }, own)
        end
        m.builds.own = { class = nil, slots = {} }
    end
    m.builds.shareOff = nil
    local imported = m.builds.imported
    if type(imported) ~= "table" or imported.counts then
        if imported ~= nil then
            EbonBuilds.api:Repaired("MATRIX.REPAIRED", { field = "imported", lost = true }, imported)
        end
        m.builds.imported = {}
    end

    m.forgets          = nil
    m.builds.counts    = nil
    m.builds.totals    = nil
    m.builds.community = nil
    m.builds.seen      = nil
    m.own              = nil
    m.community        = nil

    checked = m
    return m
end

local function NewPerson()
    return { total = 0, hit = {} }
end

local function AddBuild(person, ids)
    person.total = person.total + 1
    local seenHere = {}
    for i = 1, #ids do
        local id = ids[i] and Key(ids[i])
        if id and not seenHere[id] then
            seenHere[id] = true
            person.hit[id] = (person.hit[id] or 0) + 1
        end
    end
end

local function FoldPeople(persons)
    local rate, builds, people = {}, 0, 0
    for _, p in ipairs(persons) do
        if p.total > 0 then
            people = people + 1
            builds = builds + p.total
            for id, n in pairs(p.hit) do
                rate[id] = (rate[id] or 0) + n / p.total
            end
        end
    end
    if people > 0 then
        for id, v in pairs(rate) do rate[id] = v / people end
    end
    return { rate = rate, people = people, builds = builds }
end

local inclCache = {}

local function InvalidateInclusion()
    inclCache = {}
    version = version + 1
end

EbonBuilds.Matrix.InvalidateInclusion = InvalidateInclusion

local EMPTY_OWN = { sum = {}, people = 0, builds = 0 }

local function OwnFor(class)
    if not class then return EMPTY_OWN end
    local cached = inclCache[class]
    if cached then return cached end

    local b = Store().builds
    local persons = {}

    if b.own.class == class then
        local me = NewPerson()
        for _, build in pairs(b.own.slots) do
            if build.ids then AddBuild(me, build.ids) end
        end
        persons[#persons + 1] = me
    end

    local imported = NewPerson()
    for _, rec in pairs(b.imported) do
        if rec.class == class and rec.ids then AddBuild(imported, rec.ids) end
    end
    persons[#persons + 1] = imported

    local folded = FoldPeople(persons)
    local sum = {}
    for id, rate in pairs(folded.rate) do sum[id] = rate * folded.people end
    cached = { sum = sum, people = folded.people, builds = folded.builds }
    inclCache[class] = cached
    return cached
end

local function InclusionFor(class)
    local own = OwnFor(class)
    local others = EbonBuilds.Profiles.Fold(class)
    return own, others, own.people + others.people, own.builds + others.builds
end

function EbonBuilds.Matrix.InclusionRate(spellId, class)
    local own, others, people, builds = InclusionFor(class)
    if people < MIN_PEOPLE or builds < MIN_BUILDS then return nil end
    local key = Key(spellId)
    return ((own.sum[key] or 0) + (others.sum[key] or 0)) / people, people, builds
end

local banCache = {}

function EbonBuilds.Matrix.InvalidateBanVotes()
    banCache = {}
    version = version + 1
end

local function BanVotesFor(class)
    if not class then return { rate = {}, people = 0, builds = 0 } end
    local cached = banCache[class]
    if cached then return cached end

    local byAuthor = {}
    local function vote(author, ids)
        if #ids == 0 then return end
        local p = byAuthor[author]
        if not p then p = NewPerson(); byAuthor[author] = p end
        AddBuild(p, ids)
    end
    local function consider(author, buildClass, list)
        if buildClass ~= class or not list or not next(list) then return end
        local ids = {}
        for spellId in pairs(list) do
            local id = tonumber(spellId)
            if id then ids[#ids + 1] = id end
        end
        vote(author, ids)
    end

    EbonBuilds.Profiles.EachBanList(class, vote)
    local me = UnitName("player") or "self"
    for _, lb in pairs(EbonAPIEbonBuildsDB.builds or {}) do
        consider(me, lb.class, lb.settings and lb.settings.echoBanList)
    end

    local persons = {}
    for _, p in pairs(byAuthor) do persons[#persons + 1] = p end
    cached = FoldPeople(persons)
    banCache[class] = cached
    return cached
end

function EbonBuilds.Matrix.BanVoteRate(spellId, class)
    local c = BanVotesFor(class)
    if c.people < MIN_BAN_PEOPLE then return nil end
    return c.rate[Key(spellId)] or 0, c.people, c.builds
end

function EbonBuilds.Matrix.SetOwnBuilds(class, slots)
    if not class or type(slots) ~= "table" then
        EbonBuilds.api:Reject("MATRIX.REJECTED", { reason = "bad_argument", sample = tostring(class) .. " / " .. type(slots) })
        return 0
    end
    local b = Store().builds
    b.own = { class = class, slots = slots }
    InvalidateInclusion()
    local n = 0
    for _ in pairs(slots) do n = n + 1 end
    return n
end

function EbonBuilds.Matrix.EachBuild(class, fn)
    if not class then return end
    local b = Store().builds
    if b.own.class == class then
        for _, build in pairs(b.own.slots) do
            if build.ids then fn("#own", build.ids) end
        end
    end
    for _, rec in pairs(b.imported) do
        if rec.class == class and rec.ids then fn("#imported", rec.ids) end
    end
    EbonBuilds.Profiles.EachBuild(class, fn)
end

function EbonBuilds.Matrix.OwnBuildSlots()
    return Store().builds.own.slots, Store().builds.own.class
end

local function CompositionKey(class, ids)
    local sorted = {}
    for i = 1, #ids do sorted[i] = ids[i] end
    table.sort(sorted)
    return tostring(class) .. ":" .. table.concat(sorted, ",")
end

function EbonBuilds.Matrix.AddImportedComposition(class, ids)
    if not class or type(ids) ~= "table" or #ids == 0 then
        local size = type(ids) == "table" and (#ids .. " echoes") or type(ids)
        EbonBuilds.api:Reject("MATRIX.REJECTED", { reason = "invalid_composition", sample = tostring(class) .. " / " .. size })
        return false
    end
    local b = Store().builds
    local key = CompositionKey(class, ids)
    if b.imported[key] then return false end
    b.imported[key] = { class = class, ids = ids }
    InvalidateInclusion()
    return true
end

function EbonBuilds.Matrix.CombinedScore(spellId, class)
    local incl = EbonBuilds.Matrix.InclusionRate(spellId, class)
    local ban  = EbonBuilds.Matrix.BanVoteRate(spellId, class)
    if not incl and not ban then return nil end
    return (incl or 0) * POINTS.pick + (ban or 0) * POINTS.ban
end

function EbonBuilds.Matrix.Init()
    Store()
    InvalidateInclusion()
    EbonBuilds.Matrix.InvalidateBanVotes()

    EbonBuilds.Events.On("EB_BUILDS_CHANGED", EbonBuilds.Matrix.InvalidateBanVotes, "Matrix bans")

    EbonBuilds.api:On("SERVER_BUILDS", function(_, builds)
        if not builds or not builds.slots then
            EbonBuilds.api:Reject("MATRIX.REJECTED", { reason = "no_slots", sample = type(builds) })
            return
        end
        local class = PlayerClass()
        if not class then
            EbonBuilds.api:Reject("MATRIX.REJECTED", { reason = "no_class", sample = "class unknown" })
            return
        end
        local slots = {}
        for slot, build in pairs(builds.slots) do
            local echoes = EbonAPI.State.BuildEchoes(build) or {}
            local ids = {}
            for i = 1, #echoes do ids[i] = echoes[i].spellId end
            if #ids > 0 then
                slots[slot] = { name = build.name, ids = ids }
            else
                EbonBuilds.api:Reject("MATRIX.REJECTED", { reason = "empty_slot", sample = "slot " .. tostring(slot) })
            end
        end
        EbonBuilds.Matrix.SetOwnBuilds(class, slots)
    end)
end
