EbonBuilds.SavedBuildsView = {}

local L = EbonBuilds.L
local Codec = EbonAPI.Profile

local MARGIN   = 10
local COLUMNS  = 2
local CARD_GAP = 12
local ACTIVE   = "|cff19ff19>|r "

local viewFrame
local cards = {}

local function OrderedSlots()
    local slots = EbonAPI.State.GetBuilds()
    local out = {}
    if not slots or not slots.slots then return out, nil end
    for slot in pairs(slots.slots) do out[#out + 1] = slot end
    table.sort(out)
    return out, slots
end

local function Entry(slot, build, active)
    return {
        slot   = slot,
        class  = EbonBuilds.Build.PlayerClassToken(),
        title  = (slot == active and ACTIVE or "") .. slot .. ". " .. (build.name or "?"),
        echoes = (Codec.EncodeEchoes(build.echoes)),
        locked = EbonBuilds.Sync.LockedText(build),
        count  = #EbonAPI.State.BuildEchoes(build),
    }
end

local function Refresh()
    if not viewFrame then return end
    local ordered, server = OrderedSlots()
    local grid = viewFrame._grid
    local width = math.floor((EbonBuilds.MainWindow.VIEW_WIDTH - MARGIN * 2 - CARD_GAP) / COLUMNS)
    local entries = {}
    for i = 1, #ordered do
        local slot = ordered[i]
        local card = cards[i]
        if not card then
            card = EbonBuilds.BuildDetail.Card(grid, width)
            cards[i] = card
        end
        entries[slot] = Entry(slot, server.slots[slot], server.active)
        EbonBuilds.BuildDetail.FillCard(card, entries[slot])
        card:Show()
    end
    for i = #ordered + 1, #cards do cards[i]:Hide() end
    grid:Layout()
    viewFrame._subtitle:Refresh()
    if #ordered == 0 then viewFrame._empty:Show() else viewFrame._empty:Hide() end
    viewFrame:Layout()

    local open = EbonBuilds.BuildDetail.Current()
    if open and open.slot then
        if entries[open.slot] then
            EbonBuilds.BuildDetail.Show(entries[open.slot])
        else
            EbonBuilds.BuildDetail.Hide()
        end
    end
end

EbonBuilds.SavedBuildsView.Refresh = Refresh

local function SubtitleText()
    local ordered, server = OrderedSlots()
    if #ordered == 0 then return "" end
    return string.format(L.SAVED_SUBTITLE, #ordered, server.active or 0, server.unlocked or 0, server.maxSlots or 0)
end

local function Build(container)
    local W = EbonBuilds.Widgets
    local width = EbonBuilds.MainWindow.VIEW_WIDTH - MARGIN * 2
    viewFrame = W.Page(container, { padding = MARGIN })
    viewFrame:Add("text", { key = "SAVED_BUILDS", size = "medium", width = width })
    viewFrame._subtitle = viewFrame:Add("status", { width = width, text = SubtitleText })
    viewFrame._grid = viewFrame:Add("grid", { columns = COLUMNS })
    viewFrame._empty = viewFrame:Add("status", { key = "SAVED_NONE", size = "medium", width = width })
    viewFrame._empty.text:SetJustifyH("CENTER")
end

local view = {}

function view.Show(container)
    if not viewFrame then Build(container) end
    Refresh()
    EbonBuilds.Widgets.ShowPage(viewFrame)
end

function view.Hide()
    EbonBuilds.BuildDetail.Hide()
    if viewFrame then viewFrame:Hide() end
end

function EbonBuilds.SavedBuildsView.Init()
    EbonBuilds.ViewRouter.Register("savedBuilds", view)

    EbonBuilds.api:On("SERVER_BUILDS", function()
        if viewFrame and viewFrame:IsVisible() then Refresh() end
    end)
end
