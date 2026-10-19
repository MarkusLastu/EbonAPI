EbonBuilds.SettingsView = {}

local L = EbonBuilds.L
local W = EbonBuilds.Widgets

local FAMILIES = EbonBuilds.Const.FAMILIES

local WEIGHT_THRESHOLDS = {
    { key = "autoBanishPct",  label = "T_BANISH_PCT", flavor = "T_BANISH_PCT_HINT", min = 0, max = 100, step = 1 },
    { key = "autoRerollPct",  label = "T_REROLL_PCT", flavor = "T_REROLL_PCT_HINT", min = 0, max = 300, step = 1 },
    { key = "rerollGuardPct", label = "T_GUARD_PCT",  flavor = "T_GUARD_PCT_HINT",  min = 0, max = 100, step = 1 },
    { key = "autoFreezePct",  label = "T_FREEZE_PCT", flavor = "T_FREEZE_PCT_HINT", min = 0, max = 100, step = 1 },
}

local MATRIX_THRESHOLDS = {
    { key = "matrixBanishBelow",  label = "T_BANISH", absolute = true, flavor = "T_BANISH_HINT", min = -5, max = 0, step = 0.1 },
    { key = "matrixRerollBelow",  label = "T_REROLL", absolute = true, flavor = "T_REROLL_HINT", min = -5, max = 3, step = 0.1 },
    { key = "matrixRerollGuard",  label = "T_GUARD",  absolute = true, flavor = "T_GUARD_HINT",  min = -5, max = 3, step = 0.1 },
    { key = "matrixFreezeAbove",  label = "T_FREEZE", absolute = true, flavor = "T_FREEZE_HINT", min = -5, max = 3, step = 0.1 },
    { key = "matrixWeightFactor", label = "T_WEIGHT", absolute = true, flavor = "T_WEIGHT_HINT", min = 0,  max = 3, step = 0.1 },
}

local TOGGLE_COLUMNS = 4
local TOGGLE_WIDTH   = 110
local BAN_ICON       = 28
local BAN_HEIGHT     = 120
local SLIDER_W       = 400
local ABS_WIDTH      = 60
local TEXT_MARGIN    = 60

local viewFrame
local page
local weightsGroup, matrixGroup
local banGrid, banIcons = nil, {}
local absLabels = {}
local cachedPeak = 0

local function Settings()
    return EbonBuilds.BuildForm.GetEditingSettings()
end

local function IsMatrixMode()
    return Settings().scoreSource ~= "weights"
end

local function Whitelist()
    local settings = Settings()
    settings.banishFamilyWhitelist = settings.banishFamilyWhitelist or {}
    return settings.banishFamilyWhitelist
end

local function AllProtected()
    local whitelist = Whitelist()
    for _, fam in ipairs(FAMILIES) do
        if not whitelist[fam] then return false end
    end
    return true
end

local cachedPeakName

local function RecomputePeak()
    if IsMatrixMode() then
        cachedPeak, cachedPeakName = 0, nil
        return
    end
    local class = EbonBuilds.BuildForm.GetEditingClass()
    local name, score = EbonBuilds.Scoring.ComputePeak(class, Settings(), EbonBuilds.Build.GetActiveWeights())
    cachedPeak, cachedPeakName = score or 0, name
end

local function PeakText()
    if IsMatrixMode() then return L.SCALE_MATRIX end
    if cachedPeakName then return string.format(L.PEAK, cachedPeakName, cachedPeak) end
    return L.PEAK_EMPTY
end

local function PeakNote()
    return IsMatrixMode() and L.SCALE_MATRIX_NOTE or L.PEAK_NOTE
end

local function QuantiseThreshold(entry, value)
    if entry.absolute then return math.floor(value * 10 + 0.5) / 10 end
    return math.floor(value + 0.5)
end

local function FormatThreshold(entry, v)
    if entry.absolute then return string.format("%+.2f", v) end
    return v .. "%"
end

local function ThresholdValue(entry)
    local val = Settings()[entry.key]
    if val == nil then val = entry.absolute and entry.min or 0 end
    return val
end

local function AbsText(entry)
    if cachedPeak > 0 then
        return "= " .. math.floor(cachedPeak * ThresholdValue(entry) / 100)
    end
    return ""
end

local function RefreshAbsLabels()
    for _, label in ipairs(absLabels) do label:Refresh() end
end

local function BanIcon(index)
    local btn = banIcons[index]
    if btn then return btn end
    btn = banGrid:Add("icon", {
        size = BAN_ICON,
        icon = function(self) return self._spellId and select(3, GetSpellInfo(self._spellId)) or nil end,
        onClick = function(self)
            local id = self._spellId
            if id then Settings().echoBanList[id] = nil end
            EbonBuilds.SettingsView.RefreshBanList()
        end,
    })
    W.SpellTip(btn, function(self) return self._spellId, self._quality end, { colored = true, describe = true })
    btn._ring = W.Ring(btn)
    banIcons[index] = btn
    return btn
end

function EbonBuilds.SettingsView.RefreshBanList()
    if not banGrid then return end
    local banList = Settings().echoBanList or {}
    local banned = {}
    for spellId in pairs(banList) do banned[#banned + 1] = spellId end
    table.sort(banned)

    local perkDb = EbonAPI.Ebonhold.PerkDatabase() or {}
    for i, spellId in ipairs(banned) do
        local data = perkDb[spellId]
        local btn = BanIcon(i)
        btn._spellId = spellId
        btn._quality = data and data.quality or 0
        W.SetRing(btn._ring, btn._quality)
        btn:Show()
        btn:Refresh()
    end
    for i = #banned + 1, #banIcons do banIcons[i]:Hide() end
    banGrid._empty = #banned == 0
    banGrid:Layout()
    page:Refresh()
end

local function AddEchoToBan(name, spellId)
    local settings = Settings()
    settings.echoBanList = settings.echoBanList or {}
    settings.echoBanList[spellId] = name
    EbonBuilds.SettingsView.RefreshBanList()
end

local function OpenBanPicker()
    local allList = EbonBuilds.Catalog.AllQualities()
    local banList = Settings().echoBanList or {}
    local filtered = {}
    for _, entry in ipairs(allList) do
        if not banList[entry.spellId] and not EbonBuilds.BuildForm.IsLocked(entry.spellId) then
            filtered[#filtered + 1] = entry
        end
    end
    EbonBuilds.EchoPicker.Show(function(spellId, _, name)
        AddEchoToBan(name, spellId)
    end, filtered)
end

local function BuildBanishWhitelistSection(parent, width)
    local section = parent:Add("group", { key = "BANISH_PROTECTION" })
    section:Add("status", { key = "BANISH_PROTECTION_HINT", width = width - TEXT_MARGIN })

    local grid = section:Add("grid", { columns = TOGGLE_COLUMNS })
    for _, fam in ipairs(FAMILIES) do
        local family = fam
        grid:Add("toggle", {
            width = TOGGLE_WIDTH,
            text = function() return L.FAMILY[family] or family end,
            get = function() return Whitelist()[family] or false end,
            onChange = function(_, value)
                Whitelist()[family] = value and true or nil
                section:Refresh()
            end,
        })
    end

    section:Add("text", { key = "ALL_PROTECTED", width = width - TEXT_MARGIN, hidden = function() return not AllProtected() end })
    section:Add("status", { key = "BAN_NOTE", width = width - TEXT_MARGIN })
end

local function BuildEchoBanSection(parent, width)
    local section = parent:Add("group", { key = "ECHO_BAN" })
    section:Add("status", { key = "ECHO_BAN_HINT", width = width - TEXT_MARGIN })
    section:Add("button", { key = "ADD_ECHO", onClick = OpenBanPicker })

    local list = section:Add("group", { scroll = "VERTICAL", width = width - TEXT_MARGIN, height = BAN_HEIGHT })
    banGrid = list:Add("grid", { columns = math.floor((width - TEXT_MARGIN * 2) / (BAN_ICON + 4)) })
    list:Add("status", { key = "NO_BANNED", hidden = function() return not banGrid._empty end })

    local modeRow = section:Add("bar", {})
    modeRow:Add("status", { key = "ALL_BANNED_LABEL", width = 300 })
    modeRow:Add("button", {
        text = function()
            return (Settings().echoBanAllMode or "highestScore") == "random" and L.RANDOM or L.HIGHEST_SCORE
        end,
        onClick = function(self)
            local s = Settings()
            s.echoBanAllMode = (s.echoBanAllMode or "highestScore") == "highestScore" and "random" or "highestScore"
            self:Refresh()
        end,
    })
end

local ApplyScoreSource

local function BuildScoreSourceSection(parent, width)
    local section = parent:Add("group", { key = "SCORE_SOURCE" })
    section:Add("button", {
        width = 150,
        text = function() return IsMatrixMode() and L.COMMUNITY_MATRIX or L.MANUAL_WEIGHTS end,
        onClick = function()
            local settings = Settings()
            settings.scoreSource = (settings.scoreSource == "weights") and "matrix" or "weights"
            ApplyScoreSource()
        end,
    })
    section:Add("status", {
        width = width - TEXT_MARGIN,
        text = function() return IsMatrixMode() and L.MATRIX_BLURB or L.WEIGHTS_BLURB end,
    })
    section:Add("text", { size = "medium", width = width - TEXT_MARGIN, text = PeakText })
    section:Add("status", { width = width - TEXT_MARGIN, text = PeakNote })
end

local function ThresholdSlider(parent, entry, width)
    local block = parent:Add("bar", { layout = "VERTICAL" })
    block:Add("status", { key = entry.flavor, width = width - TEXT_MARGIN * 2 })

    local row = block:Add("bar", {})
    row:Add("range", {
        key = entry.label, width = SLIDER_W,
        min = entry.min, max = entry.max, step = entry.step,
        format = function(v) return FormatThreshold(entry, QuantiseThreshold(entry, v)) end,
        get = function() return ThresholdValue(entry) end,
        onChange = function(_, value)
            Settings()[entry.key] = QuantiseThreshold(entry, value)
            RefreshAbsLabels()
        end,
    })
    if not entry.absolute then
        absLabels[#absLabels + 1] = row:Add("status", {
            width = ABS_WIDTH,
            text = function() return AbsText(entry) end,
        })
    end
end

local function BuildThresholdsSection(parent, width)
    local section = parent:Add("group", { key = "THRESHOLDS" })

    weightsGroup = section:Add("bar", { layout = "VERTICAL", hidden = IsMatrixMode })
    for _, entry in ipairs(WEIGHT_THRESHOLDS) do ThresholdSlider(weightsGroup, entry, width) end

    matrixGroup = section:Add("bar", { layout = "VERTICAL", hidden = function() return not IsMatrixMode() end })
    for _, entry in ipairs(MATRIX_THRESHOLDS) do ThresholdSlider(matrixGroup, entry, width) end
end

ApplyScoreSource = function()
    RecomputePeak()
    page:Refresh()
end

local function BuildViewFrame(container)
    local f = W.Page(container, { spacing = 0 })
    local width = EbonBuilds.BuildTabs.ContentWidth()

    page = f:Add("group", { key = "AUTOMATION_HEADER", scroll = "VERTICAL", width = f.spec.width, height = f.spec.height })

    BuildBanishWhitelistSection(page, width)
    BuildEchoBanSection(page, width)
    BuildScoreSourceSection(page, width)
    BuildThresholdsSection(page, width)

    return f
end

function EbonBuilds.SettingsView.Mount(container)
    viewFrame = viewFrame or BuildViewFrame(container)
    W.ShowPage(viewFrame)
    RecomputePeak()
    EbonBuilds.SettingsView.RefreshBanList()
end

function EbonBuilds.SettingsView.Unmount()
    if not viewFrame then return end
    viewFrame:Hide()
end
