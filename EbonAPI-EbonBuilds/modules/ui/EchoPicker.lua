EbonBuilds.EchoPicker = {}

local W = EbonBuilds.Widgets

local QUALITY_COLOR = EbonBuilds.Const.QUALITY_HEX

local ROW_HEIGHT    = 24
local WINDOW_WIDTH  = 400
local WINDOW_HEIGHT = 500
local PADDING       = 12
local GAP           = 6
local SEARCH_WIDTH  = WINDOW_WIDTH - PADDING * 2

local frame, searchBox, scroll, scrollChild
local allEntries   = {}
local filtered     = {}
local rowPool      = {}
local onPick
local searchText   = ""

local function BuildEntries()
    local best = EbonBuilds.Catalog.BestByName()
    local list = {}
    for name, entry in pairs(best) do
        list[#list + 1] = {
            spellId = entry.spellId,
            name    = name,
            quality = entry.quality,
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function ApplySearch()
    filtered = {}
    if searchText == "" then
        for i = 1, #allEntries do filtered[i] = allEntries[i] end
        return
    end
    for i = 1, #allEntries do
        local e = allEntries[i]
        local lname = e.lname
        if not lname then
            lname = e.name:lower()
            e.lname = lname
        end
        if lname:find(searchText, 1, true) then
            filtered[#filtered + 1] = e
        end
    end
end

local function RowText(self)
    local entry = self._entry
    if not entry then return "" end
    return "|cff" .. (QUALITY_COLOR[entry.quality] or "ffffff") .. entry.name .. "|r"
end

local function RowIcon(self)
    return self._entry and select(3, GetSpellInfo(self._entry.spellId)) or nil
end

local function RowPick(self, mouse)
    if mouse ~= "LeftButton" or not self._entry then return end
    local entry = self._entry
    if onPick then onPick(entry.spellId, entry.quality, entry.name) end
    frame:Close()
end

local function CreateRow()
    return W.Kit("slot", scrollChild, {
        width = scrollChild.spec.width, height = ROW_HEIGHT, icon = RowIcon, text = RowText, onClick = RowPick,
    })
end

local function PopulateRow(row, index, entry)
    row._entry = entry
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:Refresh()
    row:Show()
end

local function VisibleRowCount()
    local h = W.ScrollView(scroll)
    if h <= 1 then h = 420 end
    return math.ceil(h / ROW_HEIGHT) + 2
end

local rendering = false

local function Draw()
    W.ScrollHeight(scroll, #filtered * ROW_HEIGHT)

    local offset  = math.floor(W.ScrollOffset(scroll) / ROW_HEIGHT)
    local visible = VisibleRowCount()

    for poolIdx = 1, visible do
        local listIdx = offset + poolIdx
        local entry   = filtered[listIdx]
        if entry then
            if not rowPool[poolIdx] then
                rowPool[poolIdx] = CreateRow()
            end
            PopulateRow(rowPool[poolIdx], listIdx, entry)
        elseif rowPool[poolIdx] then
            rowPool[poolIdx]:Hide()
        end
    end
    for i = visible + 1, #rowPool do rowPool[i]:Hide() end
end

local function Render()
    if rendering then return end
    rendering = true
    Draw()
    rendering = false
end

local function BuildFrame()
    local f = EbonBuilds.api:Window("picker", {
        key = "PICK_ECHO", width = WINDOW_WIDTH, height = WINDOW_HEIGHT, layout = "VERTICAL", spacing = GAP,
        padding = PADDING,
    })
    f:SetFrameStrata("FULLSCREEN_DIALOG")

    searchBox = W.Field(f, { width = SEARCH_WIDTH }, {
        maxLetters = 60,
        onText = function(text)
            searchText = text:lower()
            ApplySearch()
            W.ScrollTo(scroll, 0)
            Render()
        end,
    })

    scroll = W.Scroll(f, { onScroll = Render })
    scrollChild = scroll._content
    W.ScrollSize(scroll, SEARCH_WIDTH, WINDOW_HEIGHT - f.head:GetHeight() - PADDING - searchBox:GetHeight() - GAP)

    return f
end

function EbonBuilds.EchoPicker.Show(callback, dataSource)
    if not frame then
        frame = BuildFrame()
    end
    if type(dataSource) == "table" then
        allEntries = dataSource
    elseif dataSource then
        allEntries = EbonBuilds.Catalog.AllQualities()
    else
        allEntries = BuildEntries()
    end
    onPick = callback
    searchText = ""
    searchBox:SetValue("")
    ApplySearch()
    frame:Show()
    W.ScrollTo(scroll, 0)
    Render()
    searchBox.edit:SetFocus()
end
