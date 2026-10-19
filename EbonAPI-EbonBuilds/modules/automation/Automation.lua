EbonBuilds.Automation = {}

local FAMILY_MAP = EbonBuilds.Const.FAMILY_MAP

local function GetEvalDelay()
    return (EbonAPIEbonBuildsDB.globalSettings and EbonAPIEbonBuildsDB.globalSettings.evalDelay) or 2
end

local evalTimer         = nil
local pendingChoices    = nil
local locallyFrozenIndices = {}
local unconfirmedFreezes   = 0
local cachedPeak           = nil

local REFERENCE_OFFER_SIZE = 3

local QUALITY_BONUS = { [0] = 0, [1] = 0.5, [2] = 1.0, [3] = 1.5 }

local function Perks()
    return EbonAPI.Ebonhold.Perks()
end

local function HasPerkApi()
    local svc = Perks()
    return (svc and EbonAPI.Ebonhold.PerkDatabase()
            and svc.GetCurrentChoice and svc.SelectPerk) and true or false
end

local function ShouldAutomate()
    if not HasPerkApi() then return false end
    if EbonBuilds.Reroll and EbonBuilds.Reroll.IsHunting() then return false end
    local build = EbonBuilds.Build and EbonBuilds.Build.GetActive()
    return (build and build.automationEnabled) and true or false
end

local function OnEvalTimer()
    if EbonBuilds.Automation.Evaluate() then
        pendingChoices = nil
        return
    end
    if pendingChoices then EbonBuilds.DrawHook.ShowNative(pendingChoices) end
    pendingChoices = nil
end

local function StartEvalTimer()
    evalTimer = evalTimer or EbonBuilds.Timer.New("Automation delay")
    EbonBuilds.Timer.Arm(evalTimer, GetEvalDelay(), OnEvalTimer)
end

function EbonBuilds.Automation.GetPeak()
    if cachedPeak then return cachedPeak end
    local build = EbonBuilds.Build.GetActive()
    if not build then return 1 end
    local settings = build.settings or EbonBuilds.Build.DefaultSettings()
    local _, score = EbonBuilds.Scoring.ComputePeak(build.class, settings, build.echoWeights or {})
    cachedPeak = (score and score > 0) and score or 1
    return cachedPeak
end

function EbonBuilds.Automation.ResetPeakCache()
    cachedPeak = nil
end

local function StacksOwned(spellId)
    local owned = EbonBuilds.Protocol and EbonBuilds.Protocol.GetOwnedEchoes()
    if not owned then return nil end

    local total = 0
    local variants = EbonBuilds.Catalog.Variants(spellId)
    if variants then
        for i = 1, #variants do
            local held = owned[variants[i]]
            if held then total = total + (held.stacks or 1) end
        end
    else
        local held = owned[spellId]
        if held then total = total + (held.stacks or 1) end
    end
    return total
end

local function ScoreChoice(choice, settings, weights)
    local spellId = choice.spellId
    local name = GetSpellInfo(spellId)
    if not name then
        return nil, EbonBuilds.api:Problem("AUTOMATION.CHOICE_UNKNOWN", { spellId = spellId, detail = "no spell name" })
    end
    local data = EbonBuilds.Catalog.Entry(spellId)
    if not data then
        return nil, EbonBuilds.api:Problem("AUTOMATION.CHOICE_UNKNOWN", { spellId = spellId, detail = "not in the Echo catalog" })
    end
    local entry = {
        spellId   = spellId,
        name      = name,
        quality   = choice.quality,
        families  = data.families,
        classMask = data.classMask,
    }
    local weightKey = EbonBuilds.Catalog.WeightKey(spellId) or name
    local weight = EbonBuilds.Scoring.WeightOf(weights, weightKey)
    local stacks = StacksOwned(spellId)
    local isNovel
    if stacks ~= nil then
        isNovel = (stacks == 0)
    else
        local granted = Perks().GetGrantedPerks()
        isNovel = not granted or not granted[name]
    end
    local score
    if isNovel then
        score = EbonBuilds.Scoring.Score(entry, weight, settings)
    else
        score = EbonBuilds.Scoring.ScorePerQuality(entry, weight, settings, entry.quality)
    end
    local matrixScore
    if EbonBuilds.Matrix then
        matrixScore = EbonBuilds.Matrix.CombinedScore(
            spellId, EbonBuilds.Build.PlayerClassToken())
    end

    return {
        index       = 0,
        spellId     = spellId,
        name        = name,
        quality     = choice.quality,
        stacks      = stacks,
        score       = score,
        matrixScore = matrixScore,
        entry     = entry,
        data      = data,
        isFrozen  = choice.isFrozen,
        isCarried = choice.isCarried,
    }
end

local function NormFamily(f) return FAMILY_MAP[f] end

local function IsProtected(data, whitelist)
    if not whitelist or next(whitelist) == nil then return false end
    local families = data.families
    if not families or #families == 0 then
        return whitelist["No family"] or false
    end
    for _, fam in ipairs(families) do
        local key = NormFamily(fam) or fam
        if whitelist[key] then return true end
    end
    return false
end

local function ScoreLockedEcho(lockedId, settings, weights)
    local name = GetSpellInfo(lockedId)
    if not name then return 0 end
    local data = EbonBuilds.Catalog.Entry(lockedId)
    if not data then return 0 end
    local entry = {
        spellId   = lockedId,
        name      = name,
        quality   = data.quality or 0,
        families  = data.families,
        classMask = data.classMask,
    }
    local weightKey = EbonBuilds.Catalog.WeightKey(lockedId) or name
    local w = EbonBuilds.Scoring.WeightOf(weights, weightKey)
    return EbonBuilds.Scoring.Score(entry, w, settings)
end

local function UpdateStat(build, key, amount)
    if build and build.stats then
        build.stats[key] = (build.stats[key] or 0) + (amount or 1)
    end
end

local function RecordQualityPick(build, quality)
    if not (build and build.stats and build.stats.qualityPicks) then return end
    if type(quality) ~= "number" or quality < 0 or quality > 3 then return end
    local qp = build.stats.qualityPicks
    qp[quality] = (qp[quality] or 0) + 1
end

local function LogAndToast(scored, action, targetIndex)
    EbonBuilds.Toast.ShowAutomationResult(scored, action, targetIndex)
    EbonBuilds.Session.LogAction(scored, action, targetIndex)
end

local function ByIndex(a, b)
    return a.index < b.index
end

local function ByScoreAscending(a, b)
    return a.score < b.score
end

local function ByScoreDescending(a, b)
    return a.score > b.score
end

local function TrySelect(scored, settings, build)
    local banList = settings.echoBanList or {}
    local nonBanned, all = {}, {}
    for _, s in ipairs(scored) do
        all[#all + 1] = s
        if not banList[s.spellId] then
            nonBanned[#nonBanned + 1] = s
        end
    end
    local candidates = #nonBanned > 0 and nonBanned or all
    if #candidates == 0 then return false, nil end

    table.sort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        local as, bs = a.isSecured or false, b.isSecured or false
        if as ~= bs then return not as end
        return a.index < b.index
    end)

    local pick
    if #nonBanned == 0 and settings.echoBanAllMode == "random" then
        pick = candidates[math.random(1, #candidates)]
    else
        pick = candidates[1]
    end

    if not EbonAPI.Ebonhold.SelectPerk(pick.spellId) then return false, nil end
    UpdateStat(build, "picks")
    RecordQualityPick(build, pick.quality)
    return true, pick
end

local function AnnotateScored(scored, banList, whitelist, lockedList)
    for _, s in ipairs(scored) do
        s.isBanned    = banList[s.spellId] and true or false
        s.isProtected = IsProtected(s.data, whitelist)
        s.isSecured   = (s.isFrozen or s.isCarried
                         or locallyFrozenIndices[s.index]) and true or false
        s.isLocked    = false
        for i = 1, EbonBuilds.Build.LOCKED_SLOTS do
            local lockedId = lockedList[i]
            if lockedId and lockedId == s.spellId then
                s.isLocked = true
                break
            end
        end
    end
end

local function ScoreOffer(build, choices)
    local settings = build.settings or EbonBuilds.Build.DefaultSettings()
    local weights = build.echoWeights or {}

    local scored, unknown = {}, {}
    for i, choice in ipairs(choices) do
        local s, problem = ScoreChoice(choice, settings, weights)
        if s then
            s.index = i
            scored[#scored + 1] = s
        else
            unknown[#unknown + 1] = problem
        end
    end
    if #scored == 0 then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("AUTOMATION.OFFER_UNKNOWN", { offered = #choices }))
        return nil
    end
    for i = 1, #unknown do
        EbonBuilds.api:Report(unknown[i])
    end
    UpdateStat(build, "echoesSeen", #scored)

    local matrixMode = settings.scoreSource ~= "weights"
    if matrixMode then
        matrixMode = false
        for i = 1, #scored do
            if scored[i].matrixScore then matrixMode = true; break end
        end
    end

    local peak = EbonBuilds.Automation.GetPeak()

    if matrixMode then
        local factor = settings.matrixWeightFactor or 1
        for i = 1, #scored do
            local s = scored[i]
            local share = s.score / peak
            if share > 1 then share = 1 elseif share < -1 then share = -1 end
            s.score = (s.matrixScore or 0) + (QUALITY_BONUS[s.quality] or 0) + share * factor
        end
    end

    AnnotateScored(scored, settings.echoBanList or {}, settings.banishFamilyWhitelist or {},
        build.lockedEchoes or {})

    return {
        build      = build,
        settings   = settings,
        weights    = weights,
        scored     = scored,
        matrixMode = matrixMode,
        peak       = peak,
        runData    = EbonAPI.State.GetRun(),
    }
end

local function TakeLocked(round)
    for _, s in ipairs(round.scored) do
        if s.isLocked then
            if not EbonAPI.Ebonhold.SelectPerk(s.spellId) then return false end
            UpdateStat(round.build, "picks")
            RecordQualityPick(round.build, s.quality)
            LogAndToast(round.scored, "Select (Locked)", s.index)
            return true
        end
    end
    return false
end

local function Banish(round, s)
    if not Perks().BanishPerk(s.index - 1) then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("AUTOMATION.BANISH_REFUSED",
            { echo = s.name, left = round.runData and round.runData.remainingBanishes or 0 }))
        return false
    end
    UpdateStat(round.build, "banishesUsed")
    table.sort(round.scored, ByIndex)
    LogAndToast(round.scored, "Banish", s.index)
    return true
end

local function TryBanish(round)
    local runData = round.runData
    if not runData or (runData.remainingBanishes or 0) <= 0 then return false end

    local scored, settings = round.scored, round.settings
    local banList = settings.echoBanList or {}
    table.sort(scored, ByScoreAscending)

    for _, s in ipairs(scored) do
        if not s.isSecured and not s.isProtected and banList[s.spellId] and Banish(round, s) then
            return true
        end
    end

    local threshold
    if round.matrixMode then
        threshold = settings.matrixBanishBelow or -1
    else
        threshold = math.floor(round.peak * settings.autoBanishPct / 100)
    end
    for _, s in ipairs(scored) do
        if not s.isSecured and not s.isProtected and s.score < threshold and Banish(round, s) then
            return true
        end
    end

    table.sort(scored, ByIndex)
    return false
end

local function TryReroll(round)
    local runData = round.runData
    if not runData or (runData.totalRerolls or 0) - (runData.usedRerolls or 0) <= 0 then return false end

    local scored, settings = round.scored, round.settings
    local guardThreshold
    if round.matrixMode then
        guardThreshold = settings.matrixRerollGuard or 1.5
    else
        guardThreshold = math.floor(round.peak * (settings.rerollGuardPct or 90) / 100)
    end
    for _, s in ipairs(scored) do
        if s.score >= guardThreshold then return false end
    end

    local trigger
    if round.matrixMode then
        local best = scored[1] and scored[1].score or 0
        for _, s in ipairs(scored) do
            if s.score > best then best = s.score end
        end
        trigger = best < (settings.matrixRerollBelow or 0.5)
    else
        local sum = 0
        for _, s in ipairs(scored) do sum = sum + s.score end
        trigger = sum * REFERENCE_OFFER_SIZE / #scored < round.peak * settings.autoRerollPct / 100
    end
    if not trigger then return false end
    if not Perks().RequestReroll() then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("AUTOMATION.REROLL_REFUSED",
            { left = (runData.totalRerolls or 0) - (runData.usedRerolls or 0) }))
        return false
    end

    UpdateStat(round.build, "rerollsUsed")
    LogAndToast(scored, "Reroll", 0)
    return true
end

local function TryFreeze(round)
    local runData = round.runData
    if not runData or (runData.totalFreezes or 0) - (runData.usedFreezes or 0) - unconfirmedFreezes <= 0 then return false end

    local scored, settings, build = round.scored, round.settings, round.build
    local threshold
    if round.matrixMode then
        threshold = settings.matrixFreezeAbove or 1.5
    else
        threshold = math.floor(round.peak * settings.autoFreezePct / 100)
    end

    local above = {}
    for _, s in ipairs(scored) do
        if not s.isSecured and s.score > threshold then
            above[#above + 1] = s
        end
    end

    local lockedAbove = 0
    local lockedList = build.lockedEchoes or {}
    for i = 1, EbonBuilds.Build.LOCKED_SLOTS do
        local lockedId = lockedList[i]
        if lockedId and ScoreLockedEcho(lockedId, settings, round.weights) > threshold then
            lockedAbove = lockedAbove + 1
        end
    end

    if (#above + lockedAbove) < 2 or #above < 2 then return false end

    table.sort(above, ByScoreDescending)
    local lowest = above[#above]
    if not Perks().FreezePerk(lowest.index - 1) then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("AUTOMATION.FREEZE_REFUSED",
            { echo = lowest.name, left = (runData.totalFreezes or 0) - (runData.usedFreezes or 0) }))
        return false
    end

    UpdateStat(build, "freezesUsed")
    locallyFrozenIndices[lowest.index] = true
    unconfirmedFreezes = unconfirmedFreezes + 1
    LogAndToast(scored, "Freeze", lowest.index)
    StartEvalTimer()
    return true
end

local function Select(round)
    locallyFrozenIndices = {}
    local ok, pick = TrySelect(round.scored, round.settings, round.build)
    if ok and pick then
        LogAndToast(round.scored, "Select", pick.index)
    end
    return ok
end

local evalInProgress = false

local function Decide()
    local build = EbonBuilds.Build.GetActive()
    if not build or not build.automationEnabled then return false end
    if EbonBuilds.Reroll and EbonBuilds.Reroll.IsHunting() then return false end

    local choices = Perks().GetCurrentChoice()
    if not choices or #choices == 0 then return false end

    local round = ScoreOffer(build, choices)
    if not round then return false end

    return TakeLocked(round) or TryBanish(round) or TryReroll(round) or TryFreeze(round) or Select(round)
end

function EbonBuilds.Automation.Evaluate()
    if evalInProgress then return false end
    if not HasPerkApi() then return false end
    evalInProgress = true

    local result = EbonBuilds.api:Guard("Automation.Decide", Decide)
    evalInProgress = false
    return result or false
end

function EbonBuilds.Automation.Init()
    if EbonBuilds.Build and EbonBuilds.Build.OnActiveChanged then
        EbonBuilds.Build.OnActiveChanged(EbonBuilds.Automation.ResetPeakCache)
    end

    EbonBuilds.api:On("SERVER_RUN_DATA", function() unconfirmedFreezes = 0 end)

    local function Wire()
        if not EbonBuilds.DrawHook.Install() then return false end

        EbonBuilds.DrawHook.Take(function(choices)
            locallyFrozenIndices = {}

            if not ShouldAutomate() then return false end

            pendingChoices = choices
            StartEvalTimer()
            return true
        end)

        EbonBuilds.DrawHook.After("UpdateSinglePerk", function()
            if ShouldAutomate() then StartEvalTimer() end
        end)
        return true
    end

    if Wire() then return end

    EbonBuilds.api:Degrade(EbonBuilds.api:Problem("AUTOMATION.PERK_UI_MISSING"))
    local function Retry()
        if not Wire() then return end
        EbonBuilds.Events.Off("PLAYER_ENTERING_WORLD", Retry)
        EbonBuilds.api:Restore("AUTOMATION.PERK_UI_MISSING")
    end
    EbonBuilds.Events.On("PLAYER_ENTERING_WORLD", Retry, "Automation.Retry")
end
