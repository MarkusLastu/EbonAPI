EbonBuilds.BuildWizard = {}

local L = EbonBuilds.L
local W = EbonBuilds.Widgets

local QUALITY_COLOR = EbonBuilds.Const.QUALITY_HEX
local QUALITY_LABELS = EbonBuilds.Const.QUALITY_NAME
local EMPTY_SLOT = "Interface\\Buttons\\UI-EmptySlot"
local BUILD_SLOTS = EbonBuilds.Const.BUILD_LOCKED_SLOTS
local FAMILY_KEYS = { "Tank", "Survivability", "Healer", "Caster", "Melee", "Ranged" }
local WEIGHT_OPTIONS = {
    { key = "WEIGHT_WANT", value = 50 },
    { key = "WEIGHT_GOOD", value = 40 },
    { key = "WEIGHT_OK",   value = 30 },
    { key = "WEIGHT_MEH",  value = 20 },
}
local FAMILY_CYCLE_KEYS = { [0] = "WIZARD_FAMILY_NONE", [10] = "WIZARD_FAMILY_SECONDARY", [20] = "WIZARD_FAMILY_PRIMARY" }
local familyCycleValues = { 0, 10, 20 }
local qualityValues = { 0, 5, 10, 15, 20, 25, 30, 35, 40 }

local SLOT_SIZE     = 48
local SLOT_SPACING  = 10
local ROW_LABEL_W   = 130
local CYCLE_W       = 100
local ECHO_ICON     = 22
local ECHO_NAME_W   = 140
local NAV_W         = 80
local DESC_LINES    = 12
local MODE_BUTTON_W = 200
local MODE_BUTTON_H = 40
local CYCLE_ROW_W   = 360
local STEP_W        = 200
local TOP_GAP       = 10
local CONTENT_TOP   = 40
local FOOTER        = 50
local FOOTER_BOTTOM = 20

local viewFrame, contentArea
local stepLabel, backBtn, nextBtn
local RenderCurrentStep

local state = {}
local panes = {}

local function ResetState()
    state.step = 0
    state.locked = { nil, nil, nil, nil, nil }
    state.noveltyValue = 30
    state.qualityBonus = { [0] = 0, [1] = 10, [2] = 20, [3] = 30, [4] = 40 }
    state.familyPriorities = {}
    state.echoes = {}
    state.wizardTitle = ""
    state.wizardDescription = ""
end

ResetState()

local function Width()
    return EbonBuilds.MainWindow.VIEW_WIDTH
end

local function BuildFilteredEchoList()
    local best = EbonBuilds.Catalog.BestByName()
    local lockedSet = {}
    for i = 1, BUILD_SLOTS do
        if state.locked[i] then
            local n = GetSpellInfo(state.locked[i])
            if n then lockedSet[n] = true end
        end
    end
    local list = {}
    for name, entry in pairs(best) do
        if not state.echoes[name] and not lockedSet[name] then
            list[#list + 1] = {
                spellId = entry.spellId,
                name    = name,
                quality = entry.quality,
            }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function HasAdaptivePower()
    for i = 1, BUILD_SLOTS do
        local id = state.locked[i]
        if id then
            local name = GetSpellInfo(id)
            if name and name:lower():find("adaptive power") then
                return true
            end
        end
    end
    return false
end

local function TotalSteps()
    return HasAdaptivePower() and 6 or 5
end

local function DisplayedStep()
    if not HasAdaptivePower() and state.step >= 2 then
        return state.step - 1
    end
    return state.step
end

local function Cycle(values, current, step)
    for i, v in ipairs(values) do
        if v == current then
            local nextIdx = i + step
            if nextIdx > #values then nextIdx = 1 end
            if nextIdx < 1 then nextIdx = #values end
            return values[nextIdx]
        end
    end
    return 0
end

local function Line(parent, spec, kind)
    spec.width = spec.width or Width() - 40
    local text = W.Centered(parent, Width(), spec.width):Add(kind or "text", spec)
    text.text:SetJustifyH("CENTER")
    return text
end

local function Pane(step)
    local pane = panes[step]
    if not pane then
        pane = W.Page(contentArea, { spacing = 0 })
        pane._elements = {}
        panes[step] = pane
    end
    return pane
end

local function Track(pane, element)
    pane._elements[#pane._elements + 1] = element
    return element
end

local function ShowPane(step)
    local pane = panes[step]
    W.ShowPage(pane)
    for _, element in ipairs(pane._elements) do element:Refresh() end
end

local function Button(pane, spec)
    return W.Kit("button", W.Centered(pane, Width(), spec.width), spec)
end

local function BuildStep0()
    local pane = Pane(0)
    W.Gap(pane, 1, 20)
    Line(pane, { key = "WIZARD_S0_TITLE", size = "medium" })
    W.Gap(pane, 1, 6)
    Line(pane, { key = "WIZARD_S0_DESC" }, "status")
    W.Gap(pane, 1, 12)
    Button(pane, {
        key = "WIZARD_MODE", width = MODE_BUTTON_W, height = MODE_BUTTON_H,
        onClick = function()
            state.step = 1
            RenderCurrentStep()
        end,
    })
    W.Gap(pane, 1, 2)
    Line(pane, { key = "WIZARD_MODE_DESC" }, "status")
    W.Gap(pane, 1, 18)
    Button(pane, {
        key = "PRO_MODE", width = MODE_BUTTON_W, height = MODE_BUTTON_H,
        onClick = function()
            EbonBuilds.ViewRouter.Show("buildTabs", { mode = "create" })
        end,
    })
    W.Gap(pane, 1, 2)
    Line(pane, { key = "PRO_MODE_DESC" }, "status")
end

local function RefreshLockedSlot(btn)
    local spellId = state.locked[btn._index]
    btn:Refresh()
    if spellId then
        local data = EbonBuilds.Catalog.Entry(spellId)
        W.SetRing(btn._ring, data and data.quality or 0)
    else
        W.SetRing(btn._ring, nil)
    end
end

local function LockedSlot(pane, index)
    local slots = pane._slots
    if slots[index] then return slots[index] end
    local btn = W.Kit("icon", pane._slotRow, {
        size = SLOT_SIZE,
        icon = function(self)
            local spellId = state.locked[self._index]
            return spellId and select(3, GetSpellInfo(spellId)) or EMPTY_SLOT
        end,
        onClick = function(self, button)
            local idx = self._index
            if button == "RightButton" then
                state.locked[idx] = nil
                RefreshLockedSlot(self)
                return
            end
            EbonBuilds.EchoPicker.Show(function(spellId)
                state.locked[idx] = spellId
                RefreshLockedSlot(self)
            end, BuildFilteredEchoList())
        end,
    })
    btn._index = index
    W.SpellTip(btn, function(self) return state.locked[self._index] end, { describe = true })
    btn._ring = W.Ring(btn)
    slots[index] = btn
    return btn
end

local function BuildStep1()
    local pane = Pane(1)
    pane._slots = {}
    W.Gap(pane, 1, 20)
    Track(pane, Line(pane, {
        size = "medium",
        text = function() return string.format(L.WIZARD_S1_TITLE, BUILD_SLOTS) end,
    }))
    W.Gap(pane, 1, 50)
    local slots = BUILD_SLOTS
    local centered = W.Centered(pane, Width(), slots * SLOT_SIZE + (slots - 1) * SLOT_SPACING)
    pane._slotRow = centered:Add("bar", { spacing = SLOT_SPACING })
end

local function RenderStep1()
    local pane = panes[1]
    local slots = BUILD_SLOTS
    for i = 1, math.max(slots, #pane._slots) do
        local btn = LockedSlot(pane, i)
        if i <= slots then
            btn:Show()
            RefreshLockedSlot(btn)
        else
            btn:Hide()
        end
    end
    pane._slotRow:Layout()
end

local function BuildStep2()
    local pane = Pane(2)
    W.Gap(pane, 1, 30)
    Track(pane, Line(pane, { key = "WIZARD_S2_TITLE", size = "medium" }))
    W.Gap(pane, 1, 6)
    Track(pane, Line(pane, { key = "WIZARD_S2_DESC" }, "status"))
    W.Gap(pane, 1, 24)
    Track(pane, W.Kit("range", W.Centered(pane, Width(), 300), {
        width = 300, min = 0, max = 100, step = 1,
        get = function() return state.noveltyValue or 30 end,
        onChange = function(_, v) state.noveltyValue = math.floor(v) end,
    }))
    W.Gap(pane, 1, 8)
    Track(pane, Line(pane, { key = "WIZARD_S2_HINT" }, "status"))
end

local function CycleRow(pane, labelText, valueText, onStep)
    local row = W.Centered(pane, Width(), CYCLE_ROW_W):Add("bar", { spacing = 8 })
    local label = Track(pane, row:Add("text", { size = "medium", width = ROW_LABEL_W, text = labelText }))
    label.text:SetJustifyH("RIGHT")
    local value
    Track(pane, W.Kit("button", row, {
        text = "<",
        onClick = function() onStep(-1); value:Refresh() end,
    }))
    value = Track(pane, W.Kit("button", row, {
        width = CYCLE_W, text = valueText,
        onClick = function(self) onStep(1); self:Refresh() end,
    }))
    Track(pane, W.Kit("button", row, {
        text = ">",
        onClick = function() onStep(1); value:Refresh() end,
    }))
    W.Gap(pane, 1, 4)
end

local function BuildStep3()
    local pane = Pane(3)
    W.Gap(pane, 1, 20)
    Track(pane, Line(pane, { key = "WIZARD_S3_TITLE", size = "medium" }))
    W.Gap(pane, 1, 6)
    Track(pane, Line(pane, { key = "WIZARD_DEFAULTS_HINT" }, "status"))
    W.Gap(pane, 1, 12)
    for _, fam in ipairs(FAMILY_KEYS) do
        local family = fam
        CycleRow(pane,
            function() return L.FAMILY_LONG[family] end,
            function() return L[FAMILY_CYCLE_KEYS[state.familyPriorities[family] or 0]] end,
            function(step)
                state.familyPriorities[family] = Cycle(familyCycleValues, state.familyPriorities[family] or 0, step)
            end)
    end
end

local function BuildStep4()
    local pane = Pane(4)
    W.Gap(pane, 1, 20)
    Track(pane, Line(pane, { key = "WIZARD_S4_TITLE", size = "medium" }))
    W.Gap(pane, 1, 6)
    Track(pane, Line(pane, { key = "WIZARD_DEFAULTS_HINT" }, "status"))
    W.Gap(pane, 1, 12)
    for _, q in ipairs({ 0, 1, 2, 3, 4 }) do
        local quality = q
        CycleRow(pane,
            function() return "|cff" .. (QUALITY_COLOR[quality] or "ffffff") .. QUALITY_LABELS[quality] .. "|r" end,
            function() return "+" .. tostring(state.qualityBonus[quality]) end,
            function(step)
                state.qualityBonus[quality] = Cycle(qualityValues, state.qualityBonus[quality], step)
            end)
    end
end

local function RenderStep4()
    for q = 0, 4 do
        if state.qualityBonus[q] == nil then state.qualityBonus[q] = q * 10 end
    end
end

local RenderStep5

local function EchoRow(pane, index)
    local rows = pane._rows
    if rows[index] then return rows[index] end

    local row = pane._list:Add("bar", {})
    row:Add("icon", {
        size = ECHO_ICON,
        icon = function() return row._entry and select(3, GetSpellInfo(row._entry.spellId)) or nil end,
    })
    row:Add("text", {
        width = ECHO_NAME_W,
        text = function()
            local entry = row._entry
            if not entry then return "" end
            return "|cff" .. (QUALITY_COLOR[entry.quality] or "ffffff") .. entry.name .. "|r"
        end,
    })
    row._weights = {}
    for j, opt in ipairs(WEIGHT_OPTIONS) do
        local option = opt
        row._weights[j] = W.Kit("button", row, {
            key = option.key,
            onClick = function()
                state.echoes[row._entry.name].weight = option.value
                for k, btn in ipairs(row._weights) do
                    btn:SetSelected(WEIGHT_OPTIONS[k].value == option.value)
                end
            end,
        })
    end
    W.Kit("button", row, {
        key = "REMOVE",
        onClick = function()
            state.echoes[row._entry.name] = nil
            RenderStep5()
        end,
    })
    rows[index] = row
    return row
end

local function BuildStep5()
    local pane = Pane(5)
    pane._rows = {}
    W.Gap(pane, 1, 20)
    Track(pane, Line(pane, { key = "WIZARD_S5_TITLE", size = "medium" }))
    W.Gap(pane, 1, 6)
    Track(pane, Line(pane, { key = "WIZARD_S5_DESC" }, "status"))
    W.Gap(pane, 1, 8)
    Track(pane, Button(pane, {
        key = "ADD_ECHO_BUTTON", width = 120,
        onClick = function()
            EbonBuilds.EchoPicker.Show(function(spellId, quality, name)
                state.echoes[name] = { spellId = spellId, quality = quality, name = name, weight = 40 }
                RenderStep5()
            end, BuildFilteredEchoList())
        end,
    }))
    W.Gap(pane, 1, 8)

    local rest = W.Rest(pane)
    local holder = pane:Add("bar", { spacing = 0 })
    W.Gap(holder, 10, 1)
    local list = holder:Add("group", { scroll = "VERTICAL", width = Width() - 30, height = rest })
    pane._list = list

    pane._empty = list:Add("status", { key = "WIZARD_S5_EMPTY", width = Width() - 80 })
end

RenderStep5 = function()
    local pane = panes[5]
    local sorted = {}
    for _, entry in pairs(state.echoes) do
        sorted[#sorted + 1] = entry
    end
    table.sort(sorted, function(a, b) return a.name < b.name end)

    if #sorted == 0 then pane._empty:Show() else pane._empty:Hide() end

    for i, entry in ipairs(sorted) do
        local row = EchoRow(pane, i)
        row._entry = entry
        row:Show()
        row:Refresh()
        for k, btn in ipairs(row._weights) do
            btn:SetSelected(WEIGHT_OPTIONS[k].value == entry.weight)
        end
    end
    for i = #sorted + 1, #pane._rows do pane._rows[i]:Hide() end
    pane._list:Layout()
end

local function Indented(pane)
    local row = pane:Add("bar", { spacing = 0 })
    W.Gap(row, 40, 1)
    return row
end

local function BuildStep6()
    local pane = Pane(6)
    W.Gap(pane, 1, 20)
    Track(pane, Line(pane, { key = "WIZARD_S6_TITLE", size = "medium" }))
    W.Gap(pane, 1, 6)
    Track(pane, Line(pane, { key = "WIZARD_S6_DESC" }, "status"))
    W.Gap(pane, 1, 16)

    local fieldWidth = Width() - 80
    local titleBox = W.Field(Indented(pane), {
        key = "TITLE_LABEL", width = fieldWidth,
        get = function() return state.wizardTitle or "" end,
    }, {
        maxLetters = 40,
        onText = function(text) state.wizardTitle = text end,
    })
    Track(pane, titleBox)
    W.Gap(pane, 1, 8)

    Track(pane, W.Field(Indented(pane), {
        key = "DESCRIPTION_LABEL", width = fieldWidth, lines = DESC_LINES,
        get = function() return state.wizardDescription or "" end,
    }, {
        onText = function(text) state.wizardDescription = text end,
        placeholder = "WIZARD_S6_HINT",
    }))
end

local function CreateBuildFromWizard()
    EbonBuilds.Draft.weights = EbonBuilds.Draft.weights or {}

    for name, entry in pairs(state.echoes) do
        EbonBuilds.Draft.weights[name] = entry.weight
    end

    local settings = EbonBuilds.Build.DefaultSettings()

    for q = 0, 4 do
        settings.qualityBonus[q] = state.qualityBonus[q] or (q * 10)
    end

    for _, family in ipairs(FAMILY_KEYS) do
        local val = state.familyPriorities[family] or 0
        if val > 0 then
            settings.familyBonus[family] = val
        end
    end

    if HasAdaptivePower() then
        settings.noveltyValue = state.noveltyValue or 30
    else
        settings.noveltyValue = 0
    end

    local locked = EbonBuilds.Build.CopyLocked(state.locked)

    local playerClass = EbonBuilds.Build.PlayerClassToken()

    EbonBuilds.Draft.wizardPrefill = {
        title        = state.wizardTitle ~= "" and state.wizardTitle or L.NEW_BUILD_TITLE,
        class        = playerClass,
        spec         = EbonBuilds.Build.PlayerTopTalentTab(),
        comments     = state.wizardDescription or "",
        lockedEchoes = locked,
        settings     = settings,
    }
    EbonBuilds.Draft.isEditing = true

    EbonBuilds.ViewRouter.Show("buildTabs", { mode = "create", fromWizard = true })
end

local function GoNext()
    if state.step >= 6 then
        CreateBuildFromWizard()
        return
    end

    if state.step == 1 and not HasAdaptivePower() then
        state.step = 3
    else
        state.step = state.step + 1
    end

    RenderCurrentStep()
end

local function GoBack()
    if state.step <= 1 then
        state.step = 0
        RenderCurrentStep()
        return
    end

    if state.step == 3 and not HasAdaptivePower() then
        state.step = 1
    else
        state.step = state.step - 1
    end

    RenderCurrentStep()
end

RenderCurrentStep = function()
    local step = state.step
    stepLabel:Refresh()
    backBtn:Refresh()
    nextBtn:Refresh()
    if step == 0 then
        backBtn:Hide()
        nextBtn:Hide()
    else
        backBtn:Show()
        nextBtn:Show()
    end
    backBtn.kitHost:Layout()
    if step == 1 then
        RenderStep1()
    elseif step == 4 then
        RenderStep4()
    end
    ShowPane(step)
    if step == 5 then
        RenderStep5()
    end
end

local view = {}

local BuildViewFrame

function view.Show(container, context)
    viewFrame = viewFrame or BuildViewFrame(container)
    ResetState()
    W.ShowPage(viewFrame)
    RenderCurrentStep()
end

function view.Hide()
    if viewFrame then viewFrame:Hide() end
end

BuildViewFrame = function(container)
    local f = W.Page(container, { spacing = 0 })
    local width = Width()

    W.Gap(f, 1, TOP_GAP)
    local top = f:Add("bar", { spacing = 0 })
    W.Gap(top, 10, 1)
    top:Add("text", { key = "WIZARD_HEADER", size = "medium", width = width / 2 - STEP_W / 2 - 10 })
    stepLabel = top:Add("text", {
        size = "medium", width = STEP_W,
        text = function()
            if (state.step or 0) <= 0 then return "" end
            return string.format(L.WIZARD_STEP, DisplayedStep(), TotalSteps())
        end,
    })
    stepLabel.text:SetJustifyH("CENTER")
    local lead = W.Gap(f, 1, 1)

    contentArea = f:Add("bar", { layout = "VERTICAL", spacing = 0, width = width, height = 1 })

    local drop = W.Gap(f, 1, 1)
    local bottom = f:Add("bar", { spacing = 10 })
    W.Gap(bottom, 0, 1)
    backBtn = W.Kit("button", bottom, {
        key = "BACK", width = NAV_W,
        disabled = function() return (state.step or 0) <= 0 end,
        onClick = GoBack,
    })
    nextBtn = W.Kit("button", bottom, {
        minWidth = NAV_W,
        text = function() return (state.step or 0) >= 6 and L.CREATE_BUILD or L.NEXT end,
        onClick = GoNext,
    })

    lead.spec.height = math.max(1, CONTENT_TOP - TOP_GAP - top:GetHeight())
    lead:SetHeight(lead.spec.height)
    drop.spec.height = math.max(1, FOOTER - FOOTER_BOTTOM - backBtn:GetHeight())
    drop:SetHeight(drop.spec.height)
    contentArea.spec.height = f.spec.height - CONTENT_TOP - FOOTER
    contentArea:SetHeight(contentArea.spec.height)
    f:Layout()

    BuildStep0()
    BuildStep1()
    BuildStep2()
    BuildStep3()
    BuildStep4()
    BuildStep5()
    BuildStep6()
    return f
end

function EbonBuilds.BuildWizard.Init()
    EbonBuilds.ViewRouter.Register("buildWizard", view)
end
