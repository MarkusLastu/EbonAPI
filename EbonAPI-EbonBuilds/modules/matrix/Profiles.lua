local _, ns = ...

local Profiles = {}
ns.Profiles = Profiles

local api = ns.api
local Codec = EbonAPI.Profile
local Key = ns.Catalog.Key

local db = nil
local SAVED_SLOTS = ns.Const.SAVED_SLOTS

local function Players()
    return db.account.players
end

local function Index(class)
    if type(class) == "number" then return class end
    return Codec.ClassIndex(class)
end

local folds = {}

local EMPTY_FOLD = { sum = {}, people = 0, builds = 0, version = 0 }

local function Contribute(fold, name, player, sign)
    local total, hits = 0, nil
    for _, text in pairs(player.e) do
        if text ~= "" then
            local ids, _, n = Codec.DecodeBuild(text)
            if not ids and sign == 1 then
                api:Reject("PROFILE.REJECTED", { sender = name, reason = "undecodable_build", sample = tostring(text):sub(1, 60) })
            end
            if ids then
                total = total + 1
                hits = hits or {}
                local seen = {}
                for i = 1, n do
                    local id = Key(ids[i])
                    if not seen[id] then
                        seen[id] = true
                        hits[id] = (hits[id] or 0) + 1
                    end
                end
            end
        end
    end
    if total == 0 then return end

    fold.people = fold.people + sign
    fold.builds = fold.builds + sign * total
    local sum = fold.sum
    for id, n in pairs(hits) do
        local value = (sum[id] or 0) + sign * n / total
        if value < 1e-9 and value > -1e-9 then value = nil end
        sum[id] = value
    end
    fold.version = fold.version + 1
end

local function BuildFold(class)
    local fold = { sum = {}, people = 0, builds = 0, version = 0 }
    for name, player in pairs(Players()) do
        if player.c == class then Contribute(fold, name, player, 1) end
    end
    folds[class] = fold
    return fold
end

function Profiles.Fold(class)
    class = Index(class)
    if not class then return EMPTY_FOLD end
    return folds[class] or BuildFold(class)
end

local function Player(name, class)
    local players = Players()
    local player = players[name]
    if not player then
        player = { c = class, h = {}, e = {} }
        players[name] = player
    end
    return player
end

local function Reshape(name, player, class, change)
    local before = folds[player.c]
    if before then Contribute(before, name, player, -1) end
    change(player)
    player.c = class
    local after = folds[class]
    if after then Contribute(after, name, player, 1) end
    ns.Matrix.Touch()
    ns.Events.Fire("EB_PROFILES_CHANGED")
end

local function OnSlots(_, sender, class, slots)
    local player = Player(sender, class)
    local keep = {}
    for i = 1, #slots do keep[slots[i]] = true end

    local stale = false
    for slot in pairs(player.h) do
        if not keep[slot] then stale = true; break end
    end
    if not stale and player.c == class then return end

    Reshape(sender, player, class, function(p)
        for slot in pairs(p.h) do
            if not keep[slot] then
                p.h[slot] = nil
                p.e[slot] = nil
                if p.k then p.k[slot] = nil end
                if p.u then p.u[slot] = nil end
                if p.l then p.l[slot] = nil end
            end
        end
    end)
end

local function OnBuild(_, sender, class, slot, hash, text, locked)
    if slot > SAVED_SLOTS then
        api:Reject("PROFILE.REJECTED", { sender = sender, reason = "slot_limit", sample = "slot " .. tostring(slot) })
        return
    end
    local player = Player(sender, class)
    if player.h[slot] == hash and player.c == class then return end

    Reshape(sender, player, class, function(p)
        if p.h[slot] ~= hash and p.u then p.u[slot] = nil end
        p.h[slot] = hash
        p.e[slot] = text
        if locked then
            p.l = p.l or {}
            p.l[slot] = locked
        elseif p.l then
            p.l[slot] = nil
        end
    end)
end

local function OnBans(_, sender, class, hash, text)
    local player = Player(sender, class)
    if player.xh == hash and player.c == class then return end

    Reshape(sender, player, class, function(p)
        p.xh = hash
        p.x = text
    end)

    if ns.Matrix and ns.Matrix.InvalidateBanVotes then
        ns.Matrix.InvalidateBanVotes()
    end
end

local function Field(t, slot)
    return t and t[slot]
end

function Profiles.Merge(name, class, builds)
    if name == UnitName("player") then return false end
    local players = Players()
    if not players[name] and next(builds) == nil then return false end
    local player = Player(name, class)
    local changed = player.c ~= class
    local hashes = {}
    local kept = {}
    for slot, b in pairs(builds) do
        if slot > SAVED_SLOTS then
            api:Reject("PROFILE.REJECTED", { sender = name, reason = "slot_limit", sample = "slot " .. tostring(slot) })
        else
            kept[slot] = b
        end
    end
    for slot, b in pairs(kept) do
        local signed = class .. ":" .. slot .. ":" .. b.echoes
        if b.locked then signed = signed .. ":" .. b.locked end
        local hash = Codec.Signature(signed)
        hashes[slot] = hash
        if player.h[slot] ~= hash or Field(player.k, slot) ~= b.category or Field(player.u, slot) ~= b.usage
            or Field(player.l, slot) ~= b.locked then
            changed = true
        end
    end
    if not changed then
        for slot in pairs(player.h) do
            if not kept[slot] then
                changed = true
                break
            end
        end
    end
    if not changed then return false end

    Reshape(name, player, class, function(p)
        for slot in pairs(p.h) do
            if not kept[slot] then p.h[slot], p.e[slot] = nil, nil end
        end
        p.k, p.u, p.l = nil, nil, nil
        for slot, b in pairs(kept) do
            p.h[slot], p.e[slot] = hashes[slot], b.echoes
            if b.locked then
                p.l = p.l or {}
                p.l[slot] = b.locked
            end
            if b.category then
                p.k = p.k or {}
                p.k[slot] = b.category
            end
            if b.usage then
                p.u = p.u or {}
                p.u[slot] = b.usage
            end
        end
    end)
    return true
end

function Profiles.Each(fn)
    for name, player in pairs(Players()) do fn(name, player) end
end

function Profiles.EachBuild(class, fn)
    class = Index(class)
    if not class then return end
    for name, player in pairs(Players()) do
        if player.c == class then
            for _, text in pairs(player.e) do
                if text ~= "" then fn(name, text) end
            end
        end
    end
end

function Profiles.EachBanList(class, fn)
    class = Index(class)
    if not class then return end
    for name, player in pairs(Players()) do
        if player.c == class and player.x and player.x ~= "" then
            local lists = Codec.DecodeBans(player.x)
            if lists then
                for i = 1, #lists do fn(name, lists[i]) end
            else
                api:Reject("PROFILE.REJECTED", { sender = name, reason = "undecodable_bans", sample = player.x:sub(1, 60) })
            end
        end
    end
end

function Profiles.Count(class)
    class = Index(class)
    local n = 0
    for _, player in pairs(Players()) do
        if class == nil or player.c == class then n = n + 1 end
    end
    return n
end

function Profiles.Wipe()
    db.account.players = {}
    folds = {}
    if ns.Matrix and ns.Matrix.InvalidateBanVotes then
        ns.Matrix.InvalidateBanVotes()
    end
end

function Profiles.SendBans()
    local class = ns.Build.PlayerClassToken()
    if not class then return false end

    local lists = {}
    for _, build in pairs(EbonAPIEbonBuildsDB.builds or {}) do
        local list = build.class == class and build.settings and build.settings.echoBanList
        if list and next(list) then
            local ids = {}
            for spellId in pairs(list) do
                local id = tonumber(spellId)
                if id then ids[#ids + 1] = id end
            end
            if #ids > 0 then lists[#lists + 1] = ids end
        end
    end

    local ok = api:SetProfileBans(lists)
    if not ok then
        api:Report(api:Problem("PROFILE.SEND_FAILED", { class = class }))
    end
    return ok
end

function Profiles.Init()
    db = api:DB({ account = { players = {} } })
    for _, player in pairs(Players()) do player.t = nil end

    api:On("PROFILE_SLOTS", OnSlots)
    api:On("PROFILE_BUILD", OnBuild)
    api:On("PROFILE_BANS", OnBans)

    ns.Events.On("EB_BUILDS_CHANGED", Profiles.SendBans, "Profiles bans")
    Profiles.SendBans()
end
