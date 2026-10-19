EbonBuilds.PublicBuildsView = {}

local L = EbonBuilds.L
local Codec = EbonAPI.Profile

local PAGE_SIZE    = 8
local MARGIN       = 10
local GAP          = 4
local LIST_ROOM    = 40
local CLASS_TOKENS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local ALL_CLASSES  = "ALL"
local FILTER_WIDTH = 150
local NAV_WIDTH    = 80
local RELOAD_WIDTH = 70
local BUILD_SLOTS  = EbonBuilds.Const.BUILD_LOCKED_SLOTS

local viewFrame
local cards = {}
local list
local pageLabel, prevBtn, nextBtn
local noBuildsLabel
local classFilter, refreshBtn, reloadTimer
local filterClass
local state = { builds = {}, page = 1, totalPages = 1 }

local RefreshView, UpdateReloadButton

local function FullyLocked(locked, token)
    if not locked then return false end
    local set, count = Codec.DecodeLocked(locked)
    if set == nil and count == nil then
        if locked ~= "" then
            EbonBuilds.api:Reject("PUBLIC.REJECTED", { reason = "locked", class = token, sample = string.sub(tostring(locked), 1, 60) })
        end
        return false
    end
    return count == BUILD_SLOTS
end

local function Collect()
    local out, shown = {}, {}
    EbonBuilds.Profiles.Each(function(_, player)
        local token = Codec.ClassToken(player.c)
        if token and (not filterClass or token == filterClass) then
            for slot, text in pairs(player.e) do
                local hash = player.h[slot]
                local key = token .. text
                local locked = player.l and player.l[slot]
                if text ~= "" and hash and not shown[key] and FullyLocked(locked, token) then
                    shown[key] = true
                    out[#out + 1] = {
                        class  = token,
                        hash   = hash,
                        echoes = text,
                        locked = locked,
                        count  = #text / 3,
                    }
                end
            end
        end
    end)
    table.sort(out, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.hash < b.hash
    end)
    return out
end

local function ClassItems()
    local items = { { value = ALL_CLASSES, text = L.ALL_CLASSES } }
    for _, token in ipairs(CLASS_TOKENS) do
        items[#items + 1] = { value = token, text = EbonBuilds.ClassName(token) }
    end
    return items
end

local function RefreshPaginationControls()
    prevBtn:Refresh()
    nextBtn:Refresh()
    pageLabel:Refresh()
end

local function Render()
    local all = state.builds or {}
    local first = (state.page - 1) * PAGE_SIZE + 1
    local last = math.min(first + PAGE_SIZE - 1, #all)
    local shown = math.max(0, last - first + 1)

    for i = 1, shown do
        local card = cards[i]
        if not card then
            card = EbonBuilds.BuildDetail.Card(list._content, list.spec.width - LIST_ROOM)
            cards[i] = card
        end
        EbonBuilds.BuildDetail.FillCard(card, all[first + i - 1])
        card:Show()
    end
    for i = shown + 1, #cards do cards[i]:Hide() end
    list._content:Layout()

    if #all == 0 then noBuildsLabel:Show() else noBuildsLabel:Hide() end
    list._content:Layout()
    RefreshPaginationControls()
end

local function Turn(page)
    state.page = page
    Render()
    EbonBuilds.Widgets.ScrollTo(list, 0)
end

RefreshView = function()
    state.builds     = Collect()
    state.totalPages = math.max(1, math.ceil(#state.builds / PAGE_SIZE))
    Turn(1)
end

UpdateReloadButton = function()
    if not (viewFrame and viewFrame:IsVisible()) then return end
    refreshBtn:Refresh()
    if EbonBuilds.Sync.GetCooldownRemaining() > 0 then
        EbonBuilds.Timer.Arm(reloadTimer, 1, UpdateReloadButton)
    end
end

local function BuildViewFrame(container)
    local W = EbonBuilds.Widgets
    local width = EbonBuilds.MainWindow.VIEW_WIDTH - MARGIN * 2
    local f = W.Page(container, { padding = MARGIN, spacing = GAP })

    f:Add("text", { key = "PLAYER_BUILDS", size = "medium", width = width })
    f:Add("status", { key = "PLAYER_BUILDS_SUB", width = width })

    local filters = f:Add("bar", { spacing = GAP })
    filterClass = EbonBuilds.Build.PlayerClassToken()
    classFilter = W.Kit("select", filters, {
        width = FILTER_WIDTH,
        values = ClassItems,
        get = function() return filterClass or ALL_CLASSES end,
        onChange = function(_, value)
            filterClass = value ~= ALL_CLASSES and value or nil
            RefreshView()
        end,
    })
    local reload = W.Column(filters)
    refreshBtn = W.Kit("button", reload, {
        width = RELOAD_WIDTH,
        text = function()
            local remaining = EbonBuilds.Sync.GetCooldownRemaining()
            if remaining > 0 then return string.format(L.WAIT_SECONDS, remaining) end
            return L.RELOAD
        end,
        disabled = function() return EbonBuilds.Sync.GetCooldownRemaining() > 0 end,
        onClick = function()
            EbonBuilds.Sync.RequestSync()
            UpdateReloadButton()
        end,
    })
    W.Lead(reload, classFilter:GetHeight() - refreshBtn:GetHeight())
    reloadTimer = EbonBuilds.Timer.New("Player builds cooldown")

    list = W.Scroll(f, { layout = "VERTICAL", width = width })
    noBuildsLabel = list._content:Add("status", { key = "PLAYER_BUILDS_NONE", size = "medium", width = width - LIST_ROOM })
    noBuildsLabel.text:SetJustifyH("CENTER")
    noBuildsLabel:Hide()

    local bottom = f:Add("bar", { spacing = GAP })
    prevBtn = W.Kit("button", bottom, {
        key = "PREVIOUS", width = NAV_WIDTH,
        disabled = function() return state.page <= 1 end,
        onClick = function()
            if state.page > 1 then Turn(state.page - 1) end
        end,
    })
    pageLabel = bottom:Add("text", {
        size = "medium", width = width - NAV_WIDTH * 2 - GAP * 2,
        text = function() return string.format(L.PAGE, state.page, state.totalPages) end,
    })
    pageLabel.text:SetJustifyH("CENTER")
    nextBtn = W.Kit("button", bottom, {
        key = "NEXT", width = NAV_WIDTH,
        disabled = function() return state.page >= state.totalPages end,
        onClick = function()
            if state.page < state.totalPages then Turn(state.page + 1) end
        end,
    })

    W.ScrollSize(list, width, W.Rest(f, list))
    return f
end

function EbonBuilds.PublicBuildsView.Mount(container)
    viewFrame = viewFrame or BuildViewFrame(container)
    EbonBuilds.Widgets.ShowPage(viewFrame)
    RefreshView()
    UpdateReloadButton()
end

function EbonBuilds.PublicBuildsView.Unmount()
    EbonBuilds.BuildDetail.Hide()
    if viewFrame then viewFrame:Hide() end
    if reloadTimer then EbonBuilds.Timer.Cancel(reloadTimer) end
end

local COALESCE_DELAY = 0.5
local coalesceTimer

local function RefreshNow()
    if not (viewFrame and viewFrame:IsVisible()) then return end
    RefreshView()
end

function EbonBuilds.PublicBuildsView.RefreshIfMounted()
    if not (viewFrame and viewFrame:IsVisible()) then return end
    coalesceTimer = coalesceTimer or EbonBuilds.Timer.New("Player builds refresh")
    EbonBuilds.Timer.Arm(coalesceTimer, COALESCE_DELAY, RefreshNow)
end

EbonBuilds.Events.On("EB_PROFILES_CHANGED", EbonBuilds.PublicBuildsView.RefreshIfMounted, "Player builds refresh")
