local _, ns = ...

local Rating = {}
ns.Rating = Rating

local BASE = { [0] = 1.0, [1] = 1.25, [2] = 1.5, [3] = 1.75, [4] = 2.0 }
local PRIOR = 3
local TOP = 3
local BAN_ZERO = 0.5
local BAN_MINUS = 0.2
local RUN_HALF = 5
local PARTNERS = 3
local PARTNER_BUILDS = 3
local PARTNER_GAIN = 0.15

local Key = ns.Catalog.Key
local Decode = EbonAPI.Profile.DecodeBuild
local floor = math.floor

local corpora = {}
local stamp = nil
local known = {}
local mark, pass = {}, 0

local function KeysOf(source, name)
    local ids, n = source, #source
    if type(source) == "string" then
        local _
        ids, _, n = Decode(source)
        if not ids then
            ns.api:Reject("PROFILE.REJECTED", { sender = name, reason = "undecodable_build", sample = source:sub(1, 60) })
            return {}
        end
    end
    pass = pass + 1
    local keys = {}
    for i = 1, n do
        local k = Key(ids[i])
        if mark[k] ~= pass then
            mark[k] = pass
            keys[#keys + 1] = k
        end
    end
    return keys
end

local function Corpus(class)
    local version = ns.Matrix.Version()
    if version ~= stamp then
        stamp = version
        corpora = {}
    end
    local corpus = corpora[class]
    if corpus then return corpus end

    local before, now = known[class] or {}, {}
    local people, byName = {}, {}
    ns.Matrix.EachBuild(class, function(name, source)
        local keys = now[source] or before[source] or KeysOf(source, name)
        now[source] = keys
        if #keys == 0 then return end
        local person = byName[name]
        if not person then
            person = {}
            byName[name] = person
            people[#people + 1] = person
        end
        person[#person + 1] = keys
    end)
    known[class] = now

    corpus = { people = people, partners = {} }
    corpora[class] = corpus
    return corpus
end

local function Weight(common, size)
    if size <= 0 then return 1 end
    local s = common / size
    local c = size / (size + RUN_HALF)
    return (1 - c) + c * s * s
end

local function Presence(corpus, run, size)
    local num, total = {}, 0
    local keepNum, keepCut, total1
    if size > 0 then keepNum, keepCut, total1 = {}, {}, 0 end

    local people = corpus.people
    for p = 1, #people do
        local person = people[p]
        local share = 1 / #person
        for b = 1, #person do
            local keys = person[b]
            local common = 0
            if size > 0 then
                for i = 1, #keys do
                    if run[keys[i]] then common = common + 1 end
                end
            end
            local w = Weight(common, size) * share
            total = total + w
            local w1, w0 = 0, 0
            if size > 0 then
                w1 = Weight(common, size - 1) * share
                if common > 0 then w0 = Weight(common - 1, size - 1) * share end
                total1 = total1 + w1
            end
            for i = 1, #keys do
                local k = keys[i]
                num[k] = (num[k] or 0) + w
                if size > 0 and run[k] then
                    keepNum[k] = (keepNum[k] or 0) + w0
                    keepCut[k] = (keepCut[k] or 0) + (w1 - w0)
                end
            end
        end
    end

    local out = {}
    if total > 0 then
        for k, v in pairs(num) do out[k] = v / total end
    end
    if size > 0 then
        for k in pairs(run) do
            local den = total1 - (keepCut[k] or 0)
            out[k] = den > 0 and (keepNum[k] or 0) / den or 0
        end
    end
    return out
end

local function ClassPresence(corpus)
    local p = corpus.presence
    if not p then
        p = Presence(corpus, nil, 0)
        corpus.presence = p
    end
    return p
end

local noRunReported

local function RunPresence(corpus)
    local owned = ns.Protocol.GetOwnedEchoes()
    if not owned then
        if not noRunReported then
            noRunReported = true
            ns.api:Report(ns.api:Problem("RATING.NO_RUN_DATA"))
        end
        return ClassPresence(corpus)
    end
    noRunReported = nil
    if corpus.owned == owned then return corpus.run end

    local run, size = {}, 0
    for spellId in pairs(owned) do
        local k = Key(spellId)
        if not run[k] then
            run[k] = true
            size = size + 1
        end
    end
    local p = size > 0 and Presence(corpus, run, size) or ClassPresence(corpus)
    corpus.owned, corpus.run = owned, p
    return p
end

local function Playable(data, class)
    local mask = data.classMask or 0
    if mask == 0 then return true end
    local bitVal = ns.Const.CLASS_BITS[class]
    return not bitVal or bit.band(mask, bitVal) ~= 0
end

function Rating.Value(spellId, withRun)
    local class = ns.Build.PlayerClassToken()
    local data = class and spellId and ns.Catalog.Entry(spellId)
    if not data or not Playable(data, class) then return nil end

    local ban = ns.Matrix.BanVoteRate(spellId, class) or 0
    if ban >= BAN_ZERO then return 0 end

    local note = BASE[data.quality or 0] or BASE[0]
    local corpus = Corpus(class)
    local people = #corpus.people
    if people > 0 then
        local presence = withRun and RunPresence(corpus) or ClassPresence(corpus)
        note = (PRIOR * note + people * TOP * (presence[Key(spellId)] or 0)) / (PRIOR + people)
    end
    if ban >= BAN_MINUS then note = note - 1 end
    if note < 1 then note = 1 end
    return note
end

function Rating.Stars(spellId, withRun)
    local note = Rating.Value(spellId, withRun)
    if not note then return nil end
    local stars = floor(note + 0.5)
    if stars > TOP then stars = TOP end
    return stars
end

local function ByGain(a, b)
    if a.gain ~= b.gain then return a.gain > b.gain end
    return a.k < b.k
end

function Rating.Partners(spellId)
    local class = ns.Build.PlayerClassToken()
    if not class or not spellId then return nil end
    local corpus = Corpus(class)
    local key = Key(spellId)
    local cached = corpus.partners[key]
    if cached ~= nil then return cached or nil end

    local together, count, weight, builds = {}, {}, 0, 0
    local people = corpus.people
    for p = 1, #people do
        local person = people[p]
        local share = 1 / #person
        for b = 1, #person do
            local keys = person[b]
            local has = false
            for i = 1, #keys do
                if keys[i] == key then
                    has = true
                    break
                end
            end
            if has then
                builds = builds + 1
                weight = weight + share
                for i = 1, #keys do
                    local k = keys[i]
                    together[k] = (together[k] or 0) + share
                    count[k] = (count[k] or 0) + 1
                end
            end
        end
    end

    local out = false
    if builds >= PARTNER_BUILDS then
        local presence = ClassPresence(corpus)
        local picks = {}
        for k, w in pairs(together) do
            if k ~= key and count[k] >= PARTNER_BUILDS then
                local gain = w / weight - (presence[k] or 0)
                if gain >= PARTNER_GAIN then picks[#picks + 1] = { k = k, gain = gain } end
            end
        end
        if #picks > 0 then
            table.sort(picks, ByGain)
            out = {}
            for i = 1, math.min(PARTNERS, #picks) do
                out[i] = ns.Catalog.KeySpell(picks[i].k, class)
            end
        end
    end
    corpus.partners[key] = out
    return out or nil
end
