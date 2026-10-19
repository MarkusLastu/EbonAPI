EbonBuilds.BuildForm = {}

local L = EbonBuilds.L
local W = EbonBuilds.Widgets

local classChangeCallbacks = {}

local function NotifyClassChange()
    for i = 1, #classChangeCallbacks do classChangeCallbacks[i]() end
end

function EbonBuilds.BuildForm.OnClassChanged(fn)
    classChangeCallbacks[#classChangeCallbacks + 1] = fn
end

local CLASS_ORDER = {
    "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST",
    "DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","DRUID",
}
local CLASS_TEXTURE = EbonBuilds.Const.CLASS_TEXTURE
local QUALITY_COLOR = EbonBuilds.Const.QUALITY_HEX
local UNKNOWN_ICON  = "Interface\\Icons\\INV_Misc_QuestionMark"
local EMPTY_SLOT    = "Interface\\Buttons\\UI-EmptySlot"
local BUILD_SLOTS   = EbonBuilds.Const.BUILD_LOCKED_SLOTS

local LABEL_WIDTH  = 56
local CLASS_SIZE   = 28
local CLASS_STEP   = 30
local SPEC_SIZE    = 36
local SPEC_STEP    = 40
local SLOT_SIZE    = 36
local SLOT_STEP    = 44
local SLOT_X       = 140
local TITLE_WIDTH  = 300
local TITLE_MAX    = 40
local DESC_LINES   = 14
local PAGE_PADDING = 10
local ROW_GAP      = 8

local viewFrame
local BuildViewFrame
local state = {
    mode     = "create",
    id       = nil,
    title    = "",
    class    = nil,
    spec     = 1,
    comments = "",
    locked = { nil, nil, nil, nil, nil },
    settings  = nil,
}
function EbonBuilds.BuildForm.GetEditingClass()
    return state.class
end
function EbonBuilds.BuildForm.GetEditingSettings()
    if not state.settings then
        state.settings = EbonBuilds.Build.DefaultSettings()
    end
    return state.settings
end

function EbonBuilds.BuildForm.GetEditingLockedEchoes()
    if not state.mode then return nil end
    return state.locked
end

function EbonBuilds.BuildForm.IsLocked(spellId)
    if not spellId then return false end
    for i = 1, BUILD_SLOTS do
        if state.locked[i] == spellId then return true end
    end
    return false
end

function EbonBuilds.BuildForm.IsBanned(spellId)
    if not spellId then return false end
    local banList = EbonBuilds.BuildForm.GetEditingSettings().echoBanList
    return (banList and banList[spellId]) and true or false
end

local classButtons = {}
local specButtons  = {}
local slotButtons  = {}
local titleBox, commentsBox

local _linkHookInstalled = false

local function InstallLinkHook()
    if _linkHookInstalled then return end
    _linkHookInstalled = true
    if not ChatEdit_InsertLink then return end
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if not link then return end
        local focus = GetCurrentKeyBoardFocus()
        if focus and commentsBox and focus == commentsBox.edit then
            commentsBox.edit:Insert(link)
        end
    end)
end

local function SpecEntry(i)
    local specs = state.class and EbonBuilds.SpecData and EbonBuilds.SpecData[state.class]
    return specs and specs[i]
end

local function RefreshClassSelection()
    for _, btn in pairs(classButtons) do btn:Refresh() end
end

local function RefreshSpecButtons()
    for i = 1, 3 do specButtons[i]:Refresh() end
end

local function Row(parent, key, labelWidth, spacing)
    local row = parent:Add("bar", { spacing = spacing })
    row:Add("text", { key = key, size = "medium", color = "heading", width = labelWidth - spacing })
    return row
end

local function BuildClassGrid(parent)
    local row = Row(parent, "FORM_CLASS", LABEL_WIDTH, CLASS_STEP - CLASS_SIZE)
    for _, token in ipairs(CLASS_ORDER) do
        local classToken = token
        local btn = W.Kit("icon", row, {
            size = CLASS_SIZE,
            icon = function() return CLASS_ICON_TCOORDS[classToken] and CLASS_TEXTURE or UNKNOWN_ICON end,
            checked = function() return state.class == classToken end,
            text = function() return EbonBuilds.ClassName(classToken) end,
            tip = function() end,
            onClick = function()
                if state.class == classToken then return end
                state.class = classToken
                if state.spec > 3 then state.spec = 1 end
                RefreshClassSelection()
                RefreshSpecButtons()
                NotifyClassChange()
            end,
        })
        W.ClassIcon(btn, function() return classToken end)
        classButtons[classToken] = btn
    end
end

local function BuildSpecGrid(parent)
    local row = Row(parent, "FORM_SPEC", LABEL_WIDTH, SPEC_STEP - SPEC_SIZE)
    for i = 1, 3 do
        local index = i
        local btn = W.Kit("icon", row, {
            size = SPEC_SIZE,
            icon = function()
                local entry = SpecEntry(index)
                return entry and entry.icon or UNKNOWN_ICON
            end,
            checked = function() return state.spec == index end,
            text = function()
                local entry = SpecEntry(index)
                return entry and entry.name or string.format(L.SPEC_N, index)
            end,
            tip = function() end,
            onClick = function()
                state.spec = index
                RefreshSpecButtons()
            end,
        })
        specButtons[i] = btn
    end
end

local function BuildTitleField(parent)
    titleBox = W.Field(parent, { key = "TITLE_LABEL", width = TITLE_WIDTH }, { maxLetters = TITLE_MAX })
end

local function RefreshSlot(i)
    local btn = slotButtons[i]
    local id = state.locked[i]
    btn:Refresh()
    if id then
        local data = EbonBuilds.Catalog.Entry(id)
        W.SetRing(btn._ring, data and data.quality or 0)
    else
        W.SetRing(btn._ring, nil)
    end
end

local function BuildLockedSlots(parent)
    local row = Row(parent, "LOCKED_ECHOES", SLOT_X, SLOT_STEP - SLOT_SIZE)
    for i = 1, BUILD_SLOTS do
        local index = i
        local function Spell() return state.locked[index] end
        local btn = W.Kit("icon", row, {
            size = SLOT_SIZE,
            icon = function()
                local spellId = Spell()
                return spellId and select(3, GetSpellInfo(spellId)) or EMPTY_SLOT
            end,
            onClick = function(_, button)
                if button == "RightButton" then
                    state.locked[index] = nil
                    RefreshSlot(index)
                    return
                end
                local settings = EbonBuilds.BuildForm.GetEditingSettings()
                local banList = settings and settings.echoBanList or {}
                local allList = EbonBuilds.Catalog.AllQualities()
                local filtered = {}
                for _, entry in ipairs(allList) do
                    if not banList[entry.spellId] then
                        filtered[#filtered + 1] = entry
                    end
                end
                EbonBuilds.EchoPicker.Show(function(spellId)
                    state.locked[index] = spellId
                    RefreshSlot(index)
                end, filtered)
            end,
        })
        W.SpellTip(btn, Spell, { describe = true })
        btn._ring = W.Ring(btn)
        slotButtons[i] = btn
    end
end

local function InsertLinkTooltip(lines)
    lines:Add(L.INSERT_LINK_BODY, "text", true)
    lines:Add(" ")
    lines:Add(L.INSERT_LINK_HINT1, "muted", true)
    lines:Add(L.INSERT_LINK_HINT2, "muted", true)
end

local function BuildDescriptionField(parent, width)
    local row = Row(parent, "DESCRIPTION_LABEL", LABEL_WIDTH * 3, 0)
    local push = W.Gap(row, 1, 1)
    local insertBtn = W.Kit("button", row, {
        key = "INSERT_LINK_BUTTON",
        tip = InsertLinkTooltip,
        onClick = function()
            EbonBuilds.EchoPicker.Show(function(spellId, quality, name)
                local color = QUALITY_COLOR[quality] or "ffffff"
                local link  = "|cff" .. color .. "|Hecho:" .. spellId .. "|h[" .. name .. "]|h|r"
                local edit = commentsBox.edit
                if edit:HasFocus() then
                    edit:Insert(link)
                else
                    edit:SetText((edit:GetText() or "") .. link)
                end
            end)
        end,
    })
    push.spec.width = math.max(1, width - LABEL_WIDTH * 3 - insertBtn:GetWidth())
    push:SetWidth(push.spec.width)
    row:Layout()

    commentsBox = W.Field(parent, { width = width, lines = DESC_LINES }, { placeholder = "FORM_DESCRIPTION_HINT" })
end

local function CollectFromInputs()
    state.title    = titleBox.edit:GetText() or ""
    state.comments = commentsBox.edit:GetText() or ""
end

local function OnSave()
    CollectFromInputs()
    if strtrim(state.title) == "" then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("FORM.TITLE_MISSING", {}))
        if titleBox then titleBox.edit:SetFocus() end
        return
    end
    local weights = EbonBuilds.Draft.weights
    if state.mode == "create" then
        local b = EbonBuilds.Build.Create({
            title = state.title, class = state.class, spec = state.spec,
            comments = state.comments, lockedEchoes = EbonBuilds.Build.CopyLocked(state.locked),
            settings = state.settings,
            echoWeights = weights,
        })
        state.mode = "edit"
        state.id   = b.id
        EbonBuilds.Build.SetActive(b.id)
    else
        EbonBuilds.Build.Save(state.id, {
            title = state.title, class = state.class, spec = state.spec,
            comments = state.comments, lockedEchoes = EbonBuilds.Build.CopyLocked(state.locked),
            settings = state.settings,
            echoWeights = weights,
        })
    end
    EbonBuilds.Draft.isEditing = false
    EbonBuilds.Draft.weights = nil
    EbonBuilds.Draft.wizardPrefill = nil
    if EbonBuilds.BuildList and EbonBuilds.BuildList.Refresh then
        EbonBuilds.BuildList.Refresh()
    end
    if EbonBuilds.BuildTabs and EbonBuilds.BuildTabs.OnBuildSaved then
        EbonBuilds.BuildTabs.OnBuildSaved()
    end
    local active = EbonBuilds.Build.GetActive()
    if active then
        EbonBuilds.ViewRouter.Show("buildOverview", { build = active })
    end
end

local LoadFromBuild, ApplyStateToInputs

local function OnCancel()
    EbonBuilds.Draft.isEditing = false
    EbonBuilds.Draft.weights = nil
    EbonBuilds.Draft.wizardPrefill = nil

    if state.mode == "edit" and state.id then
        local build = EbonBuilds.Build.Get(state.id)
        if build then
            LoadFromBuild(build)
            ApplyStateToInputs()
        end
    end

    local active = EbonBuilds.Build.GetActive()
    if active then
        EbonBuilds.ViewRouter.Show("buildOverview", { build = active })
    else
        EbonBuilds.ViewRouter.Show("welcome")
    end
end

EbonBuilds.BuildForm.Save   = OnSave
EbonBuilds.BuildForm.Cancel = OnCancel

ApplyStateToInputs = function()
    titleBox:SetValue(state.title or "")
    commentsBox:SetValue(state.comments or "")
    RefreshClassSelection()
    RefreshSpecButtons()
    for i = 1, BUILD_SLOTS do RefreshSlot(i) end
end

local function CloneSettings(src)
    local dst = EbonBuilds.Build.DefaultSettings()
    if not src then return dst end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            for k2, v2 in pairs(v) do dst[k][k2] = v2 end
        else
            dst[k] = v
        end
    end
    return dst
end

LoadFromBuild = function(build)
    state.mode     = "edit"
    state.id       = build.id
    state.title    = build.title    or ""
    state.class    = build.class
    state.spec     = build.spec     or 1
    state.comments = build.comments or ""
    state.settings = CloneSettings(build.settings)
    for i = 1, BUILD_SLOTS do state.locked[i] = build.lockedEchoes and build.lockedEchoes[i] or nil end
    EbonBuilds.Draft.isEditing = true
    EbonBuilds.Draft.weights = {}
    if build.echoWeights then
        for name, weight in pairs(build.echoWeights) do
            EbonBuilds.Draft.weights[name] = weight
        end
    end
end

local function LoadDefaults()
    state.mode     = "create"
    state.id       = nil
    state.title    = ""
    state.class    = EbonBuilds.Build.PlayerClassToken()
    state.spec     = EbonBuilds.Build.PlayerTopTalentTab()
    state.comments = ""
    state.settings = EbonBuilds.Build.DefaultSettings()
    for i = 1, BUILD_SLOTS do state.locked[i] = nil end
    EbonBuilds.Draft.isEditing = true
    EbonBuilds.Draft.weights = {}
    EbonBuilds.Draft.wizardPrefill = nil
end

local function LoadFromWizardPrefill()
    local pre = EbonBuilds.Draft.wizardPrefill
    state.mode     = "create"
    state.id       = nil
    state.title    = pre.title or ""
    state.class    = pre.class or EbonBuilds.Build.PlayerClassToken()
    state.spec     = pre.spec or EbonBuilds.Build.PlayerTopTalentTab()
    state.comments = pre.comments or ""
    state.settings = pre.settings or EbonBuilds.Build.DefaultSettings()
    for i = 1, BUILD_SLOTS do state.locked[i] = (pre.lockedEchoes and pre.lockedEchoes[i]) or nil end
    EbonBuilds.Draft.isEditing = true
    EbonBuilds.Draft.weights = EbonBuilds.Draft.weights or {}
end

local function TargetMatchesState(context)
    if context.mode == "edit" and context.build then
        return state.mode == "edit" and state.id == context.build.id
    end
    return false
end

function EbonBuilds.BuildForm.Mount(container, context)
    viewFrame = viewFrame or BuildViewFrame(container)
    W.ShowPage(viewFrame)

    context = context or {}
    local keepState = TargetMatchesState(context)
    if not keepState then
        if context.mode == "create" and context.fromWizard and EbonBuilds.Draft.wizardPrefill then
            LoadFromWizardPrefill()
        elseif context.mode == "edit" and context.build then
            LoadFromBuild(context.build)
        else
            LoadDefaults()
        end
    end

    ApplyStateToInputs()
    NotifyClassChange()
end

function EbonBuilds.BuildForm.Unmount()
    if viewFrame and titleBox and commentsBox then
        state.title    = titleBox.edit:GetText() or state.title
        state.comments = commentsBox.edit:GetText() or state.comments
    end
    if viewFrame then viewFrame:Hide() end
end

BuildViewFrame = function(container)
    local f = W.Page(container, { padding = PAGE_PADDING, spacing = ROW_GAP })
    local width = f.spec.width - PAGE_PADDING * 2
    f:Add("text", { key = "FORM_HEADER", size = "medium", width = width })
    BuildClassGrid(f)
    BuildSpecGrid(f)
    BuildTitleField(f)
    BuildLockedSlots(f)
    BuildDescriptionField(f, width)
    return f
end

function EbonBuilds.BuildForm.Init()
    InstallLinkHook()
end
