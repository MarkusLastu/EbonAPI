EbonBuilds.EchoTable = {}

local ROW_HEIGHT   = 36
local COL_ICON     = 40
local NAME_WIDTH   = 120
local WEIGHT_WIDTH = 60
local WEIGHT_INSET = 28

local CLASS_BITS = EbonBuilds.Const.CLASS_BITS

local function ApplyClassFilter(list)
    if EbonBuilds.Filters and EbonBuilds.Filters.ShowAllClasses and EbonBuilds.Filters.ShowAllClasses() then
        return list
    end
    local token
    if EbonBuilds.BuildForm and EbonBuilds.BuildForm.GetEditingClass then
        token = EbonBuilds.BuildForm.GetEditingClass()
    end
    if not token then
        local build = EbonBuilds.Build.GetActive()
        token = build and build.class
    end
    local bitVal = token and CLASS_BITS[token]
    if not bitVal then return list end
    local out = {}
    for i = 1, #list do
        local e = list[i]
        if not e.classMask or e.classMask == 0 or bit.band(e.classMask, bitVal) ~= 0 then
            out[#out + 1] = e
        end
    end
    return out
end

local echoList     = {}
local filteredList = {}
local rowPool      = {}
local W = EbonBuilds.Widgets
local scroll, scrollChild

local function CreateHeaders(parent, width)
    local heads = parent:Add("bar", { spacing = 0 })
    W.Gap(heads, COL_ICON + 4, 1)
    heads:Add("text", { key = "COL_NAME", width = NAME_WIDTH })
    W.Gap(heads, width - COL_ICON - 4 - NAME_WIDTH - WEIGHT_WIDTH - WEIGHT_INSET, 1)
    heads:Add("text", { key = "COL_WEIGHT", width = WEIGHT_WIDTH }).text:SetJustifyH("RIGHT")
end

local function GetVisibleCount()
    return math.ceil(W.ScrollView(scroll) / ROW_HEIGHT) + 1
end

local function UpdateScrollRange()
    W.ScrollHeight(scroll, #filteredList * ROW_HEIGHT)
end

local function DrawRows()
    local first = math.floor(W.ScrollOffset(scroll) / ROW_HEIGHT)
    local visibleCount = GetVisibleCount()
    for poolIdx = 1, visibleCount do
        if not rowPool[poolIdx] then
            rowPool[poolIdx] = EbonBuilds.EchoTableRows.CreateRow(scrollChild, poolIdx)
        end
        local listIdx = first + poolIdx
        local entry   = filteredList[listIdx]
        if entry then
            EbonBuilds.EchoTableRows.Populate(rowPool[poolIdx], -(listIdx - 1) * ROW_HEIGHT, entry)
        else
            rowPool[poolIdx]:Hide()
        end
    end
    for i = visibleCount + 1, #rowPool do rowPool[i]:Hide() end
end

local drawing = false

local function RefreshRows()
    if drawing then return end
    drawing = true
    DrawRows()
    drawing = false
end

local function CreateScroll(parent, width)
    scroll = W.Scroll(parent, { onScroll = RefreshRows })
    scrollChild = scroll._content
    W.ScrollSize(scroll, width, W.Rest(parent, scroll))
end

function EbonBuilds.EchoTable.Init(parent)
    echoList     = EbonBuilds.Catalog.SortedList()
    filteredList = ApplyClassFilter(echoList)

    local width = parent.spec.width - (parent.spec.padding or 0) * 2
    CreateHeaders(parent, width)
    CreateScroll(parent, width)
    local function Redraw()
        UpdateScrollRange()
        RefreshRows()
    end
    scroll:HookScript("OnShow", Redraw)

    if EbonBuilds.Filters and EbonBuilds.Filters.OnChange then
        EbonBuilds.Filters.OnChange(function()
            filteredList = EbonBuilds.Filters.Apply(ApplyClassFilter(echoList))
            UpdateScrollRange()
            W.ScrollTo(scroll, 0)
            RefreshRows()
        end)
    end

    local function Rebuild()
        filteredList = EbonBuilds.Filters.Apply(ApplyClassFilter(echoList))
        UpdateScrollRange()
        RefreshRows()
    end

    if EbonBuilds.Build and EbonBuilds.Build.OnActiveChanged then
        EbonBuilds.Build.OnActiveChanged(Rebuild)
    end
    if EbonBuilds.BuildForm and EbonBuilds.BuildForm.OnClassChanged then
        EbonBuilds.BuildForm.OnClassChanged(Rebuild)
    end

    Redraw()
end
