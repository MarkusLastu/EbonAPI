local NS = SkillTreeAutoLoad

local Bridge = {}
NS.Bridge = Bridge

local LOADOUT_FIRST_TRY = 2
local LOADOUT_RETRY = 5
local LOADOUT_MAX_TRIES = 12
local LISTED_NODES = 8

local loadoutId, loadoutName
local serverSpendable, serverCommitted
local serverNodes
local installed = false
local due, left
local started
local announced = 0
local treeRefusal
local showHooked = false
local open = {}

local function Lapse(code, facts, cause)
    local api = NS.api
    api:Degrade(api:Problem(code, facts or {}, cause))
    open[code] = true
end

local function Close(code)
    if open[code] then
        open[code] = nil
        NS.api:Restore(code)
    end
end

local function Fail(code, facts, cause)
    local api = NS.api
    api:Report(api:Problem(code, facts or {}, cause))
end

local function ReadNodes(nodes)
    local defs = NS.Core.GetNodeDefs()
    local out, dropped, list = {}, 0, {}

    for nodeId, rank in pairs(nodes) do
        if defs and not defs[nodeId] then
            dropped = dropped + 1
            if dropped <= LISTED_NODES then list[dropped] = nodeId end
        else
            out[nodeId] = rank
        end
    end

    if dropped > 0 then
        table.sort(list)
        local text = table.concat(list, ", ")
        if dropped > LISTED_NODES then text = text .. " (+" .. (dropped - LISTED_NODES) .. ")" end
        NS.api:Reject("SERVER.UNKNOWN_NODES", { nodes = dropped, list = text })
    end
    return out
end

function Bridge.Waited()
    return started and math.floor(GetTime() - started) or 0
end

local function OnLoadout(_, loadout)
    announced = loadout.count or 0
    Close("LOADOUT.NO_ANSWER")

    if loadout.id and loadout.name then
        Close("LOADOUT.NOT_FOUND")
        loadoutId, loadoutName = loadout.id, loadout.name
        serverNodes = ReadNodes(loadout.nodes)
    else
        loadoutId, loadoutName = nil, nil
        serverNodes = {}
        if announced > 0 then Lapse("LOADOUT.NOT_FOUND", { announced = announced }) end
    end

    NS.api:Untick("loadout")
end

local function OnAsh(_, ash)
    serverSpendable, serverCommitted = ash.spendable, ash.committed
    NS.api:Restore("BALANCE.NOT_RECEIVED")
end

local function RestorePayload(body)
    local nodes = body:sub(4)

    local present = {}
    for nodeId in nodes:gmatch("(%d+):%d+") do
        present[tonumber(nodeId)] = true
    end

    local additions = {}
    for nodeId, rank in pairs(serverNodes or {}) do
        if not present[nodeId] then
            additions[#additions + 1] = nodeId .. ":" .. rank
        end
    end

    if #additions > 0 then
        local extra = table.concat(additions, ",")
        nodes = (nodes == "") and extra or (nodes .. "," .. extra)
    end

    return loadoutId .. "|" .. loadoutName .. "|" .. nodes, #additions
end

local StartLoadoutRequest

local function WatchTreeOpening()
    if showHooked then return end
    local frame = EbonAPI.Ebonhold.SkillTreeFrame()
    if not (frame and frame.HookScript) then return end
    showHooked = true
    frame:HookScript("OnShow", function() StartLoadoutRequest() end)
end

local function TickLoadoutRequest()
    if serverNodes then
        NS.api:Untick("loadout")
        return
    end

    due = due - 1
    if due > 0 then return end

    if left <= 0 then
        NS.api:Untick("loadout")
        Lapse("LOADOUT.NO_ANSWER", { tries = LOADOUT_MAX_TRIES, seconds = Bridge.Waited() })
        WatchTreeOpening()
        return
    end

    left = left - 1
    due = LOADOUT_RETRY
    local sent, problem = EbonAPI.Ebonhold.RequestLoadout()
    if not sent then Fail("LOADOUT.REQUEST_FAILED", {}, problem) end
end

function StartLoadoutRequest()
    if serverNodes or not EbonAPI.Ebonhold.CanRequestLoadout() then return end

    due, left = LOADOUT_FIRST_TRY, LOADOUT_MAX_TRIES
    NS.api:Tick("loadout", 1, TickLoadoutRequest)
end

function Bridge.HasLoadoutIdentity()
    return loadoutId ~= nil and loadoutName ~= nil and loadoutName ~= ""
        and serverNodes ~= nil
end

function Bridge.GetServerNodes()
    return serverNodes
end

function Bridge.GetServerBalance()
    return serverSpendable, serverCommitted
end

local function UnidentifiedReason()
    if serverNodes then
        return "none of the " .. announced .. " loadouts announced by the server is the selected one"
    end
    if not EbonAPI.Ebonhold.CanRequestLoadout() then
        return "ProjectEbonhold cannot be asked for the active loadout"
    end
    if open["LOADOUT.NO_ANSWER"] then
        return "the server never announced the active loadout"
    end
    return "the server has not announced the active loadout yet"
end

local function CompletePayload(original, id, body, opcode)
    if id == opcode and type(body) == "string" and body:sub(1, 3) == "0||" then
        if Bridge.HasLoadoutIdentity() then
            body = (RestorePayload(body))
        else
            Fail("LOADOUT.UNIDENTIFIED", { detail = UnidentifiedReason() })
        end
    end
    return original(id, body)
end

local function OnApplyResult(original, spellId, success)
    original(spellId, success)
    if success then
        treeRefusal = nil
        EbonAPI.Ebonhold.RequestLoadout()
        return
    end

    local refusal = treeRefusal
    treeRefusal = nil
    Fail("APPLY.REFUSED", { cause = refusal and NS.api:ProblemText(refusal) or "the server gave no reason" }, refusal)
end

local function OnServerResult(_, kind, ok, problem)
    if kind == "tree" then treeRefusal = (not ok) and problem or nil end
end

function Bridge.Init()
    if installed then return end

    local Ebonhold = EbonAPI.Ebonhold
    local opcode = Ebonhold.OpcodeCS("REQUEST_LOADOUT_UPDATE")
    started = GetTime()

    local hooked, why
    if opcode == nil then
        why = "opcode REQUEST_LOADOUT_UPDATE unknown"
    else
        hooked, why = Ebonhold.Hook(nil, "sendToServer", function(original, id, body)
            return CompletePayload(original, id, body, opcode)
        end)
    end

    if not hooked then
        Lapse("BRIDGE.HOOK_FAILED", {}, why)
        return
    end

    if Ebonhold.CanRequestLoadout() then
        local applied, applyWhy = Ebonhold.Hook("SkillTree", "OnApplyChangesResult", OnApplyResult)
        if not applied then
            Lapse("BRIDGE.HOOK_FAILED", {}, applyWhy)
        else
            NS.api:On("SERVER_RESULT", OnServerResult)
        end
    end

    NS.api:On("SERVER_LOADOUT", OnLoadout)
    NS.api:On("SERVER_ASH", OnAsh)

    StartLoadoutRequest()

    installed = true
end
