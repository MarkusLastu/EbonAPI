EbonBuilds.Filters = {}

local L = EbonBuilds.L

local FAMILY_MAP = EbonBuilds.Const.FAMILY_MAP
local FAMILIES = EbonBuilds.Const.FAMILIES

local state = {
    text     = "",
    quality  = nil,
    families = {},
    showAllClasses = false,
}
local changeCallbacks = {}
local searchEditBox = nil

local function Notify()
    for i = 1, #changeCallbacks do
        changeCallbacks[i]()
    end
end

function EbonBuilds.Filters.OnChange(fn)
    changeCallbacks[#changeCallbacks + 1] = fn
end

local function FamiliesActive()
    for _ in pairs(state.families) do return true end
    return false
end

local function MatchesFamilies(entry)
    if not next(state.families) then return true end
    local has = {}
    local hasAnyFamily = false
    for _, fam in ipairs(entry.families or {}) do
        local key = FAMILY_MAP[fam] or fam
        has[key] = true
        if key ~= "No family" then hasAnyFamily = true end
    end
    for required in pairs(state.families) do
        if required == "No family" then
            if hasAnyFamily then return false end
        else
            if not has[required] then return false end
        end
    end
    return true
end

local function PassesFilters(entry, famActive)
    if state.text ~= "" then
        if not (entry.lname or entry.name:lower()):find(state.text, 1, true) then return false end
    end
    if state.quality ~= nil then
        if not (entry.qualities and entry.qualities[state.quality]) then return false end
    end
    if famActive then
        if not MatchesFamilies(entry) then return false end
    end
    return true
end

function EbonBuilds.Filters.Apply(echoList)
    local out = {}
    local famActive = FamiliesActive()
    for i = 1, #echoList do
        local entry = echoList[i]
        if PassesFilters(entry, famActive) then
            out[#out + 1] = entry
        end
    end
    return out
end

local SEARCH_WIDTH  = 140
local QUALITY_WIDTH = 110
local FAMILY_WIDTH  = 150
local GAP           = 6
local ALL_QUALITIES = -1

local function QualityItems()
    local items = { { value = ALL_QUALITIES, text = L.ALL } }
    for q = 0, 4 do
        items[#items + 1] = { value = q, text = EbonBuilds.Const.QUALITY_NAME[q] }
    end
    return items
end

local function CreateSearchBox(bar)
    local field = EbonBuilds.Widgets.Field(bar, { width = SEARCH_WIDTH }, {
        maxLetters = 60,
        onText = function(text)
            state.text = text:lower()
            Notify()
        end,
    })
    searchEditBox = field.edit
    return field
end

function EbonBuilds.Filters.FocusSearch()
    if searchEditBox then searchEditBox:SetFocus() end
end

function EbonBuilds.Filters.ShowAllClasses()
    return state.showAllClasses
end

local function CreateQualityDropdown(bar)
    local select = EbonBuilds.Widgets.Kit("select", bar, {
        width = QUALITY_WIDTH,
        values = QualityItems,
        get = function() return state.quality or ALL_QUALITIES end,
        onChange = function(_, value)
            if value == ALL_QUALITIES then state.quality = nil else state.quality = value end
            Notify()
        end,
    })
    return select
end

local function CreateFamilyDropdown(bar, height)
    local holder = bar:Add("bar", { layout = "NONE", width = FAMILY_WIDTH, height = height })
    local dropdown = CreateFrame("Frame", "EbonBuildsFiltersFamilyDD", holder, "UIDropDownMenuTemplate")
    dropdown:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(dropdown, 130)

    local function UpdateFamilyLabel()
        local count = 0
        for _ in pairs(state.families) do count = count + 1 end
        if count == 0 then
            UIDropDownMenu_SetText(dropdown, L.ALL_FAMILIES)
        else
            UIDropDownMenu_SetText(dropdown, string.format(L.FAMILIES_N, count))
        end
    end

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, family in ipairs(FAMILIES) do
            local info = UIDropDownMenu_CreateInfo()
            info.text             = L.FAMILY[family] or family
            info.isNotRadio       = true
            info.keepShownOnClick = true
            info.checked          = state.families[family] and true or false
            info.func             = function(_, _, _, checked)
                if checked then
                    state.families[family] = true
                else
                    state.families[family] = nil
                end
                UpdateFamilyLabel()
                Notify()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UpdateFamilyLabel()
    return dropdown
end

function EbonBuilds.Filters.Init(parent)
    local W = EbonBuilds.Widgets
    local bar = parent:Add("bar", { spacing = GAP })

    CreateSearchBox(bar)
    local qualityDropdown = CreateQualityDropdown(bar)
    CreateFamilyDropdown(bar, qualityDropdown:GetHeight())

    local column = W.Column(bar)
    local allClasses = W.Kit("toggle", column, {
        key = "SHOW_ALL_CLASSES",
        get = function() return state.showAllClasses end,
        onChange = function(_, value)
            state.showAllClasses = value and true or false
            Notify()
        end,
    })
    W.Lead(column, qualityDropdown:GetHeight() - allClasses:GetHeight() - 4)

    return bar
end
