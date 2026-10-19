EbonBuilds.Protocol = {}

local OP = {
    GRANTED_PERKS = EbonAPI.SS.PLAYER_PERK_GRANTED,
}

EbonBuilds.Protocol.OP = OP

local ownedBody = nil
local ownedEchoes = nil

local function ParseGrantedPerks(body)
    local owned = {}
    local first = true
    for chunk in body:gmatch("[^;]+") do
        if first then
            first = false
        else
            local id, stacks, level, quality, locked =
                chunk:match("^(%d+),(%d+),(%d+),(%d+),(%d+)$")
            if id then
                owned[tonumber(id)] = {
                    stacks  = tonumber(stacks),
                    level   = tonumber(level),
                    quality = tonumber(quality),
                    locked  = locked == "1",
                }
            end
        end
    end
    return owned
end

function EbonBuilds.Protocol.GetOwnedEchoes()
    if ownedBody then
        ownedEchoes = ParseGrantedPerks(ownedBody)
        ownedBody = nil
    end
    return ownedEchoes
end

local function OnGrantedPerks(body)
    ownedBody = body
    local maxPermanent = tonumber(body:match("^(%d+)"))
    if maxPermanent and maxPermanent > 0 and EbonBuilds.Build then
        EbonBuilds.Build.LOCKED_SLOTS = maxPermanent
    end
end

function EbonBuilds.Protocol.Init()
    EbonBuilds.api:OnServer(OP.GRANTED_PERKS, OnGrantedPerks)
end
