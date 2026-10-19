EbonBuilds.Session = {}

local MAX_PLAYER_LEVEL = 80
local MAX_SESSIONS  = 200

local FULL_LOG_SESSIONS = 25

local maxLevel     = 0

local function GetRunSoulAshes()
    local rd = EbonAPI.State.GetRun()
    if not rd then return 0, false end
    return rd.soulPoints or 0, true
end

local function TrackLevel(level)
    if not level or level <= maxLevel then return end
    maxLevel = level
    local session = EbonBuilds.Session.GetActiveSession()
    if session then session.maxLevel = maxLevel end
end

local function GetClassName()
    local _, class = UnitClass("player")
    return class
end

local function GetActiveBuildTitle()
    local build = EbonBuilds.Build.GetActive()
    return build and build.title or "No Build"
end

local function SummariseLogs(session)
    local logs = session.logs
    if not logs then return false end
    local sum = { decisions = #logs, actions = {} }
    for _, e in ipairs(logs) do
        local a = e.action or "?"
        sum.actions[a] = (sum.actions[a] or 0) + 1
        local c = e.charges
        if c then
            sum.ban, sum.reroll, sum.freeze = c.ban or 0, c.reroll or 0, c.freeze or 0
        end
    end
    session.logSummary = sum
    session.logs = nil
    return true
end

local function TrimOldLogs()
    local sessions = EbonAPIEbonBuildsDB.sessions or {}
    local trimmed = 0
    for i = FULL_LOG_SESSIONS + 1, #sessions do
        if SummariseLogs(sessions[i]) then trimmed = trimmed + 1 end
    end
    return trimmed
end

local function CreateSession()
    local sessions = EbonAPIEbonBuildsDB.sessions
    local id = tostring(time()) .. "-" .. tostring(#sessions + 1)

    local session = {
        id            = id,
        characterName = UnitName("player"),
        className     = GetClassName(),
        startTime     = time(),
        endTime       = nil,
        soulAshes     = 0,
        buildTitle    = GetActiveBuildTitle(),
        logs          = {},
    }

    table.insert(sessions, 1, session)
    local dropped = #sessions - MAX_SESSIONS
    for i = #sessions, MAX_SESSIONS + 1, -1 do
        table.remove(sessions, i)
    end
    if dropped > 0 then
        EbonBuilds.api:Trace("sessions_dropped", dropped, MAX_SESSIONS)
    end
    TrimOldLogs()
    EbonAPIEbonBuildsDB.currentSessionIndex = 1
    maxLevel = UnitLevel("player")
    session.maxLevel = maxLevel

    if EbonBuilds.Automation and EbonBuilds.Automation.ResetPeakCache then
        EbonBuilds.Automation.ResetPeakCache()
    end
    EbonBuilds.Events.Fire("EB_SESSION_CHANGED")
    return session
end

local function OnPlayerEnteringWorld()
    local level = UnitLevel("player")

    if not EbonAPIEbonBuildsDB.currentSessionIndex then
        CreateSession()
        return
    end

    if level == 1 and maxLevel > 1 then
        EbonBuilds.Session.EndCurrentSession()
        CreateSession()
        return
    end

    TrackLevel(level)
end

local function OnPlayerLevelUp(newLevel)
    if not EbonAPIEbonBuildsDB.currentSessionIndex then
        CreateSession()
        return
    end

    TrackLevel(newLevel)
end

local function OnUnitLevel(unit)
    if unit ~= "player" then return end

    local level = UnitLevel("player")

    if EbonAPIEbonBuildsDB.currentSessionIndex and level == 1 and maxLevel > 1 then
        EbonBuilds.Session.EndCurrentSession()
        CreateSession()
        return
    end

    TrackLevel(level)
end

function EbonBuilds.Session.EndCurrentSession()
    local idx = EbonAPIEbonBuildsDB.currentSessionIndex
    if not idx then return end

    local session = EbonAPIEbonBuildsDB.sessions[idx]
    if not session then
        EbonBuilds.api:Repaired("SESSION.REPAIRED", { field = "currentSessionIndex", before = idx }, idx)
        EbonAPIEbonBuildsDB.currentSessionIndex = nil
        return
    end

    local ashes, known = GetRunSoulAshes()
    session.endTime   = time()
    session.soulAshes = ashes
    session.maxLevel  = maxLevel
    if not known then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("SESSION.RUN_UNKNOWN", { session = session.id, what = "soul_ashes" }))
    end

    local build = EbonBuilds.Build.GetActive()
    if build and build.stats then
        local key = (maxLevel >= MAX_PLAYER_LEVEL) and "runsCompleted" or "runsReset"
        build.stats[key] = (build.stats[key] or 0) + 1
    elseif build then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("SESSION.RUN_NOT_COUNTED", { session = session.id, build = tostring(build.title) }))
    end
    EbonAPIEbonBuildsDB.currentSessionIndex = nil
    maxLevel = 0
    EbonBuilds.Events.Fire("EB_SESSION_CHANGED")
end

function EbonBuilds.Session.LogAction(scored, action, targetIndex)
    local level = UnitLevel("player")
    if EbonAPIEbonBuildsDB.currentSessionIndex and level == 1 and maxLevel > 1 then
        EbonBuilds.Session.EndCurrentSession()
        CreateSession()
    end

    local idx = EbonAPIEbonBuildsDB.currentSessionIndex
    if not idx then
        CreateSession()
        idx = EbonAPIEbonBuildsDB.currentSessionIndex
        if not idx then
            EbonBuilds.api:Report(EbonBuilds.api:Problem("SESSION.LOG_LOST", { reason = "no_session" }))
            return
        end
    end

    local session = EbonAPIEbonBuildsDB.sessions[idx]
    if not session then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("SESSION.LOG_LOST", { reason = "session_missing", index = idx }))
        return
    end
    session.logs = session.logs or {}

    local choices = {}
    for _, s in ipairs(scored) do
        choices[#choices + 1] = {
            id    = s.spellId,
            score = s.score,
        }
    end

    local rd = EbonAPI.State.GetRun()
    if not rd then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("SESSION.RUN_UNKNOWN", { session = session.id, what = "charges" }))
    end

    local charges = {
        ban    = (rd and rd.remainingBanishes) or 0,
        reroll = (rd and ((rd.totalRerolls or 0) - (rd.usedRerolls or 0))) or 0,
        freeze = (rd and ((rd.totalFreezes or 0) - (rd.usedFreezes or 0))) or 0,
    }

    local entry = {
        timestamp   = time(),
        action      = action,
        choices     = choices,
        targetIndex = targetIndex,
        charges     = charges,
    }

    session.logs[#session.logs + 1] = entry
    EbonBuilds.Events.Fire("EB_SESSION_CHANGED")
end

function EbonBuilds.Session.GetSessions()
    return EbonAPIEbonBuildsDB.sessions or {}
end

function EbonBuilds.Session.GetActiveSession()
    local idx = EbonAPIEbonBuildsDB.currentSessionIndex
    if not idx then return nil end
    return EbonAPIEbonBuildsDB.sessions[idx]
end

function EbonBuilds.Session.DeleteSession(id)
    if EbonAPIEbonBuildsDB.currentSessionIndex then
        local active = EbonAPIEbonBuildsDB.sessions[EbonAPIEbonBuildsDB.currentSessionIndex]
        if active and active.id == id then
            return nil, EbonBuilds.api:Problem("SESSION.DELETE_ACTIVE", { session = id })
        end
    end

    local sessions = EbonAPIEbonBuildsDB.sessions
    for i, s in ipairs(sessions) do
        if s.id == id then
            if EbonAPIEbonBuildsDB.currentSessionIndex and i < EbonAPIEbonBuildsDB.currentSessionIndex then
                EbonAPIEbonBuildsDB.currentSessionIndex = EbonAPIEbonBuildsDB.currentSessionIndex - 1
            end
            table.remove(sessions, i)
            EbonBuilds.Events.Fire("EB_SESSION_CHANGED")
            return true
        end
    end
    return nil, EbonBuilds.api:Problem("SESSION.NOT_FOUND", { session = id })
end

function EbonBuilds.Session.ClearAllSessions()
    EbonAPIEbonBuildsDB.sessions = {}
    EbonAPIEbonBuildsDB.currentSessionIndex = nil
    maxLevel = 0
    CreateSession()
end

function EbonBuilds.Session.Init()
    EbonAPIEbonBuildsDB.sessions = EbonAPIEbonBuildsDB.sessions or {}

    local trimmed = TrimOldLogs()
    if trimmed > 0 then
        EbonBuilds.api:Trace("logs_condensed", trimmed, FULL_LOG_SESSIONS)
    end

    local active = EbonBuilds.Session.GetActiveSession()
    maxLevel = (active and active.maxLevel) or 0

    local Events = EbonBuilds.Events
    Events.On("UNIT_LEVEL",            OnUnitLevel,           "Session level")
    Events.On("PLAYER_ENTERING_WORLD", OnPlayerEnteringWorld, "Session zoning")
    EbonBuilds.api:On("READY", OnPlayerEnteringWorld)
    Events.On("PLAYER_LEVEL_UP",       OnPlayerLevelUp,       "Session level up")
end
