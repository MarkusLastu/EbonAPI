EbonBuilds.Sync = {}

local api = EbonBuilds.api
local Codec = EbonAPI.Profile
local Hash = EbonAPI.Hash
local State = EbonAPI.State

local FORMAT = "2"
local PREFIX = "p_"
local NONE = "-"
local USAGE_LENGTH = 9
local SLOT_MAX = 20
local SAVED_SLOTS = EbonBuilds.Const.SAVED_SLOTS
local CLASS_MAX = 10
local REQ_COOLDOWN = 30
local HEX = "0123456789abcdef"

local lastRequestTime = 0
local ownKey = nil
local seen = nil

local function Now()
    return GetTime()
end

local function Hex(value)
    local out = {}
    for i = 8, 1, -1 do
        local digit = value % 16
        out[i] = HEX:sub(digit + 1, digit + 1)
        value = (value - digit) / 16
    end
    return table.concat(out)
end

function EbonBuilds.Sync.KeyFor(name)
    local hi, lo = Hash.fnv64(name)
    return PREFIX .. Hex(hi) .. Hex(lo)
end

local function OwnKey()
    if not ownKey then
        local name = UnitName("player")
        if name and name ~= "" and name ~= UNKNOWNOBJECT then ownKey = EbonBuilds.Sync.KeyFor(name) end
    end
    return ownKey
end

local function LockedText(build)
    local ids = {}
    for _, echo in ipairs(State.BuildEchoes(build) or {}) do
        if echo.locked then ids[#ids + 1] = echo.spellId end
    end
    return (Codec.EncodeLocked(ids))
end
EbonBuilds.Sync.LockedText = LockedText

local function OwnText()
    local name = UnitName("player")
    local class = Codec.PlayerClass()
    local builds = State.GetBuilds()
    if not name or not class or not builds or type(builds.slots) ~= "table" then return nil end
    local limit = math.min(tonumber(builds.maxSlots) or SAVED_SLOTS, SAVED_SLOTS)
    local parts = {}
    for _, build in ipairs(State.sortedBuilds()) do
        local slot = tonumber(build.slot)
        local echoes = Codec.EncodeEchoes(build.echoes)
        if slot and slot >= 1 and slot <= limit and echoes ~= "" then
            parts[#parts + 1] = slot .. "," .. NONE .. ",," .. LockedText(build) .. "," .. echoes
        end
    end
    return FORMAT .. "|" .. name .. "|" .. class .. "|" .. table.concat(parts, ";")
end

local function Publish()
    local key = OwnKey()
    if not key then return false end
    local text = OwnText()
    if not text then return false end
    local held, state = api:GetShared(key)
    if held == text then return false end
    local stamp = time()
    state = tonumber(state)
    if state and stamp <= state then stamp = state + 1 end
    return api:Guard("sync.publish", api.Share, api, key, stamp, text)
end

local function Parse(text)
    local format, name, class, body = text:match("^(%d+)|([^|]+)|(%d+)|(.*)$")
    class = tonumber(class)
    if format ~= FORMAT then return nil, "format" end
    if not class or class < 1 or class > CLASS_MAX then return nil, "format" end
    local builds = {}
    for chunk in body:gmatch("[^;]+") do
        local slot, category, usage, locked, echoes = chunk:match("^(%d+),([%a%-]),(%d*),([%w%-_]*),([%w%-_]*)$")
        slot = tonumber(slot)
        if not slot or slot < 1 or slot > SLOT_MAX then return nil, "slot", slot end
        if #usage ~= 0 and #usage ~= USAGE_LENGTH then return nil, "usage", slot end
        if #locked % 2 ~= 0 or not Codec.DecodeLocked(locked) then return nil, "locked", slot end
        if not Codec.DecodeBuild(echoes) then return nil, "echoes", slot end
        if slot <= SAVED_SLOTS then
            builds[slot] = {
                echoes   = echoes,
                category = category ~= NONE and category or nil,
                usage    = usage ~= "" and usage or nil,
                locked   = locked,
            }
        end
    end
    return name, class, builds
end

local function Adopt(key)
    if key == OwnKey() or key:sub(1, #PREFIX) ~= PREFIX then return false end
    local text, state = api:GetShared(key)
    if not text or seen[key] == state then return false end
    seen[key] = state
    local name, class, builds = Parse(text)
    if not name then
        api:Reject("SYNC.PROFILE_REJECTED", { reason = class, slot = builds or 0, sample = text:sub(1, 60) })
        return false
    end
    if EbonBuilds.Sync.KeyFor(name) ~= key then
        api:Reject("SYNC.PROFILE_REJECTED", { reason = "key", slot = 0, sample = text:sub(1, 60) })
        return false
    end
    return EbonBuilds.Profiles.Merge(name, class, builds)
end

local function OnReceived(_, addon, key)
    if addon ~= EbonBuilds.NAME then return end
    Adopt(key)
end

local function Retire()
    if type(EbonAPIEbonBuildsDB.published) == "table" then
        for id in pairs(EbonAPIEbonBuildsDB.published) do api:Unshare(id) end
    end
    EbonAPIEbonBuildsDB.published = nil
    EbonAPIEbonBuildsDB.remoteBuilds = nil
    EbonAPIEbonBuildsDB.syncVersion = nil
    EbonAPIEbonBuildsDB.syncPeers = nil
    EbonAPIEbonBuildsDB.lastSyncDate = nil
end

function EbonBuilds.Sync.GetCooldownRemaining()
    local elapsed = Now() - lastRequestTime
    if elapsed >= REQ_COOLDOWN then return 0 end
    return math.ceil(REQ_COOLDOWN - elapsed)
end

function EbonBuilds.Sync.RequestSync()
    local remaining = EbonBuilds.Sync.GetCooldownRemaining()
    if remaining > 0 then return false end

    Publish()

    if not api:SyncShares() then
        api:Report(api:Problem("SYNC.REQUEST_NOT_SENT", {}))
        return false
    end

    lastRequestTime = Now()
    api:Notify(EbonBuilds.L.SYNC_REQUESTING)
    return true
end

function EbonBuilds.Sync.Init()
    Retire()

    seen = api:DB({ account = { seen = {} } }).account.seen

    api:On("SHARE_RECEIVED", OnReceived)
    api:On("SERVER_BUILDS", Publish)

    for _, key in ipairs(api:SharedNames()) do Adopt(key) end

    Publish()
end
