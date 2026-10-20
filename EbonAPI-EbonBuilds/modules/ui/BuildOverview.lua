EbonBuilds.BuildOverview = {}

local L = EbonBuilds.L
local W = EbonBuilds.Widgets

local CLASS_TEXTURE  = EbonBuilds.Const.CLASS_TEXTURE
local QUALITY_LABELS = EbonBuilds.Const.QUALITY_NAME
local QUALITY_HEX    = EbonBuilds.Const.QUALITY_HEX
local CLASS_MASK     = EbonBuilds.Const.CLASS_BITS
local BUILD_SLOTS    = EbonBuilds.Const.BUILD_LOCKED_SLOTS
local UNKNOWN_ICON   = "Interface\\Icons\\INV_Misc_QuestionMark"
local EMPTY_SLOT     = "Interface\\Buttons\\UI-EmptySlot"

local CLASS_ICON_SIZE = 32
local LOCKED_SIZE     = 36
local LOCKED_STEP     = 42
local CONTENT_INSET   = 6
local BOX_BOTTOM      = 10
local PAD             = 10
local TITLE_DROP      = 6
local DESC_BOTTOM     = 32
local DELETE_BOTTOM   = 4
local STATS_COLUMN    = 260
local MISSING_TOP     = 14
local MISSING_BOTTOM  = 8
local MISSING_LEFT    = 10
local MISSING_RIGHT   = 4
local MISSING_ICON    = 24
local MISSING_NAME    = 160
local MISSING_SOURCE  = 200
local MISSING_SCORE   = 54

local viewFrame
local tabs
local contentArea
local state = { build = nil }

local PREFIXES = { "tome of ", "codex of ", "scroll of ", "manual of ", "grimoire of ", "libram of ", "tablet of " }
local QUALITY_SUFFIXES = { " %- common", " %- uncommon", " %- rare", " %- epic", " %- legendary" }

local function NormalizeEchoName(name)
    if not name then return nil end
    local n = strlower(name)
    for _, prefix in ipairs(PREFIXES) do
        if n:sub(1, #prefix) == prefix then
            n = n:sub(#prefix + 1)
            break
        end
    end
    for _, suffix in ipairs(QUALITY_SUFFIXES) do
        if n:sub(-#suffix) == suffix then
            n = n:sub(1, -(#suffix + 1))
            break
        end
    end
    return n
end

local function ComputeMissingEchoes(build)
    if not build or not build.class then return nil end

    local classMask = CLASS_MASK[build.class] or 0
    local playerLevel = UnitLevel("player")

    local ownedLower = {}
    local ownedGroups = {}
    local spellbookIds = {}
    -- The tabs are read whatever their name: the client translates it ("Echoes" is not the same text in every
    -- language), and a tome is told apart by its spell id below, not by the tab that holds it.
    local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    for tabIdx = 1, numTabs do
        local _, _, offset, numSpells = GetSpellTabInfo(tabIdx)
        for slot = offset + 1, offset + numSpells do
            local link = GetSpellLink(slot, "spell")
            local tomeSpellId = link and tonumber(link:match("spell:(%d+)"))
            if tomeSpellId then
                spellbookIds[tomeSpellId] = true
            end
        end
    end

    local perkDb = EbonAPI.Ebonhold.PerkDatabase()
    if perkDb == nil then
        EbonBuilds.api:Degrade(EbonBuilds.api:Problem("OVERVIEW.PERK_DATABASE_MISSING", {}))
        perkDb = {}
    else
        EbonBuilds.api:Restore("OVERVIEW.PERK_DATABASE_MISSING")
    end
    for spellId, data in pairs(perkDb) do
        local isOwned = spellbookIds[data.requiredSpell] or spellbookIds[spellId + 100000]
        if isOwned then
            local name = GetSpellInfo(spellId)
            local norm = NormalizeEchoName(name)
            if norm then ownedLower[norm] = true end
            if data.groupId then ownedGroups[data.groupId] = true end
        end
    end

    local perks = EbonAPI.Ebonhold.Perks()
    if perks and perks.GetGrantedPerks then
        local granted = perks.GetGrantedPerks()
        for name in pairs(granted or {}) do
            local norm = NormalizeEchoName(name)
            if norm then ownedLower[norm] = true end
        end
    end

    local lockedLower = {}
    if build.lockedEchoes then
        for i = 1, BUILD_SLOTS do
            local spellId = build.lockedEchoes[i]
            if spellId then
                local name = GetSpellInfo(spellId)
                if name then lockedLower[NormalizeEchoName(name)] = true end
            end
        end
    end

    local byName = {}
    for spellId, data in pairs(perkDb) do
        local spellName = GetSpellInfo(spellId)
        if spellName then
            local key = NormalizeEchoName(spellName)
            local isOwned = ownedLower[key] or (data.groupId and ownedGroups[data.groupId])
            if not isOwned then
                if classMask == 0 or bit.band(data.classMask or 0, classMask) ~= 0 then
                    if not data.minLevel or playerLevel >= data.minLevel then
                        local existing = byName[key]
                        if not existing or (data.quality or 0) > (existing.quality or 0) then
                            byName[key] = { spellId = spellId, data = data, displayName = spellName }
                        end
                    end
                end
            end
        end
    end

    local settings = build.settings or EbonBuilds.Build.DefaultSettings()
    local banList = settings.echoBanList or {}
    local weights = build.echoWeights or {}
    local missing = {}
    local dropSources = EbonAPI.Ebonhold.PerkDropSources()
    local dropByGroup = EbonAPI.Ebonhold.PerkDropSourceByGroup()
    for key, entry in pairs(byName) do
        local source = dropSources and dropSources[entry.spellId]
        if not source and entry.data.groupId and dropByGroup then
            source = dropByGroup[entry.data.groupId]
        end
        local needsTome = entry.data.requiredSpell and entry.data.requiredSpell > 0
        if not banList[entry.spellId] and needsTome then
            local scoringEntry = {
                spellId = entry.spellId,
                name = entry.displayName,
                quality = entry.data.quality or 0,
                families = entry.data.families,
                classMask = entry.data.classMask,
            }
            local weightKey = EbonBuilds.Catalog.WeightKey(entry.spellId)
                              or entry.displayName
            local weight = weights[weightKey] or 0
            local score = EbonBuilds.Scoring.Score(scoringEntry, weight, settings)
            if source == nil then
                EbonBuilds.api:Report(EbonBuilds.api:Problem("OVERVIEW.DROP_SOURCE_UNKNOWN", { echo = entry.displayName }))
            end
            missing[#missing + 1] = {
                spellId = entry.spellId,
                name = entry.displayName,
                quality = entry.data.quality or 0,
                dropSource = source or L.UNKNOWN,
                isLocked = lockedLower[key] or false,
                score = score,
            }
        end
    end

    table.sort(missing, function(a, b)
        if a.isLocked ~= b.isLocked then
            return a.isLocked
        end
        if a.score ~= b.score then
            return a.score > b.score
        end
        if a.quality ~= b.quality then
            return a.quality > b.quality
        end
        return a.name < b.name
    end)
    return missing
end

local function DeleteBuild()
    local build = state.build
    if not build or not build.id then return end
    EbonBuilds.Build.Delete(build.id)
    if EbonBuilds.BuildList and EbonBuilds.BuildList.Refresh then
        EbonBuilds.BuildList.Refresh()
    end
    local builds = EbonBuilds.Build.List()
    if #builds > 0 then
        EbonBuilds.Build.SetActive(builds[1].id)
        EbonBuilds.ViewRouter.Show("buildOverview", { build = builds[1] })
    else
        EbonBuilds.ViewRouter.Show("welcome")
    end
end

local function ConfirmDelete()
    local build = state.build
    if not build then return end
    EbonBuilds.api:Dialog({
        text      = string.format(L.DELETE_BUILD_CONFIRM, build.title or L.UNTITLED),
        acceptKey = "DELETE",
        cancelKey = "CANCEL",
        onAccept  = DeleteBuild,
    })
end

local function LockedSpell(i)
    local build = state.build
    return build and build.lockedEchoes and build.lockedEchoes[i]
end

local function FitDescription(page)
    local width = page._descScroll._content:GetWidth()
    local smf, measure = page._descSmf, page._descMeasure
    smf:SetWidth(width)
    measure:SetWidth(width)
    local textHeight = measure:GetStringHeight() or 0
    smf:SetHeight(math.max(textHeight + 4, 14))
    W.ScrollHeight(page._descScroll, textHeight + 6)
end

local function DescriptionText(child)
    local smf = CreateFrame("ScrollingMessageFrame", nil, child)
    smf:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -2)
    smf:SetFontObject("GameFontNormalSmall")
    smf:SetJustifyH("LEFT")
    smf:SetFading(false)
    smf:SetInsertMode("TOP")
    smf:SetMaxLines(500)
    smf:SetHyperlinksEnabled(true)
    smf:EnableMouse(true)
    smf:EnableMouseWheel(false)
    smf:SetScript("OnHyperlinkEnter", function(self, link)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        if not pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
            GameTooltip:Hide()
            return
        end
        GameTooltip:Show()
    end)
    smf:SetScript("OnHyperlinkLeave", function()
        GameTooltip:Hide()
    end)
    return smf
end

local function BuildOverviewTab(area)
    local Kit = W.Kit
    local page = W.Page(area, { spacing = 0, padding = PAD })
    local width = page.spec.width - PAD * 2

    local head = page:Add("bar", { spacing = 8 })
    local classIcon = Kit("icon", head, {
        size = CLASS_ICON_SIZE,
        icon = function()
            local build = state.build
            return build and CLASS_ICON_TCOORDS[build.class] and CLASS_TEXTURE or UNKNOWN_ICON
        end,
    })
    W.ClassIcon(classIcon, function() return state.build and state.build.class end)

    local titleColumn = W.Column(head)
    W.Lead(titleColumn, TITLE_DROP)
    local nameLabel = Kit("text", titleColumn, {
        size = "medium", width = width - CLASS_ICON_SIZE - 8,
        text = function()
            local build = state.build
            if not build then return "" end
            return "|cff" .. W.ClassHex(build.class) .. (build.title or L.UNTITLED) .. "|r"
        end,
    })

    W.Gap(page, 1, 2)
    local metaLabel = Kit("status", page, {
        width = width,
        text = function()
            local build = state.build
            if not build then return "" end
            local specs = EbonBuilds.SpecData and EbonBuilds.SpecData[build.class]
            local specName = specs and specs[build.spec or 1] and specs[build.spec or 1].name or ""
            return string.format(L.BUILD_META, build.author or L.UNKNOWN, specName, build.lastModified or "")
        end,
    })

    W.Gap(page, 1, 42)
    Kit("text", page, { key = "LOCKED_ECHOES", size = "medium", color = "heading", width = width })
    W.Gap(page, 1, 6)

    local slots = page:Add("bar", { spacing = LOCKED_STEP - LOCKED_SIZE })
    local lockedButtons = {}
    for i = 1, BUILD_SLOTS do
        local slot = i
        local btn = Kit("icon", slots, {
            size = LOCKED_SIZE,
            icon = function()
                local spellId = LockedSpell(slot)
                return spellId and select(3, GetSpellInfo(spellId)) or EMPTY_SLOT
            end,
        })
        W.SpellTip(btn, function() return LockedSpell(slot) end)
        btn._ring = W.Ring(btn)
        lockedButtons[i] = btn
    end
    page._lockedButtons = lockedButtons

    W.Gap(page, 1, 22)
    local actions = page:Add("bar", { spacing = 8 })
    Kit("button", actions, {
        minWidth = 140,
        text = function()
            local build = state.build
            return build and build.automationEnabled and L.AUTOMATION_ON or L.AUTOMATION_OFF
        end,
        onClick = function()
            local build = state.build
            if not build then return end
            build.automationEnabled = not build.automationEnabled
            actions:Refresh()
        end,
    })
    Kit("button", actions, {
        key = "EDIT_BUILD", minWidth = 120,
        onClick = function()
            if state.build then
                EbonBuilds.ViewRouter.Show("buildTabs", { mode = "edit", build = state.build })
            end
        end,
    })

    W.Gap(page, 1, 14)
    local descScroll = W.Scroll(page, { key = "DESCRIPTION_LABEL" })
    local drop = W.Gap(page, 1, 1)
    local deleteBtn = Kit("button", page, { key = "DELETE", minWidth = 64, onClick = ConfirmDelete })
    drop.spec.height = math.max(1, DESC_BOTTOM - DELETE_BOTTOM - deleteBtn:GetHeight())
    drop:SetHeight(drop.spec.height)
    W.ScrollSize(descScroll, width, W.Rest(page, descScroll) + PAD - DELETE_BOTTOM)

    local descChild = descScroll._content
    page._descSmf     = DescriptionText(descChild)
    page._descMeasure = descChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    page._descMeasure:Hide()
    page._descScroll  = descScroll

    page._elements = { classIcon, nameLabel, metaLabel, actions }
    for i = 1, #lockedButtons do page._elements[#page._elements + 1] = lockedButtons[i] end

    return page
end

local STAT_ROWS = {
    { key = "echoesSeen",    label = "STAT_ECHOES_SEEN" },
    { key = "runsCompleted", label = "STAT_RUNS_COMPLETED" },
    { key = "runsReset",     label = "STAT_RUNS_RESET" },
    { key = "picks",         label = "STAT_PICKS" },
    { key = "rerollsUsed",   label = "STAT_REROLLS" },
    { key = "banishesUsed",  label = "STAT_BANISHES" },
    { key = "freezesUsed",   label = "STAT_FREEZES" },
}

local function Stats()
    return state.build and state.build.stats or {}
end

local function StatColumn(page, key, width, headerWidth, first)
    local column = page:Add("bar", { layout = "VERTICAL", spacing = 0, width = width })
    local header = column:Add("text", { key = key, size = "medium", color = "heading", width = headerWidth })
    W.Gap(column, 1, math.max(1, first - header:GetHeight()))
    return column
end

local function StatRow(column, step, label, value)
    local row = column:Add("bar", { spacing = 4, height = step })
    W.Gap(row, 0, 1)
    row:Add("text", label)
    local val = row:Add("text", value)
    val.text:SetJustifyH("RIGHT")
    return val
end

local function BuildStatsTab(area)
    local page = W.Page(area, { layout = "HORIZONTAL", spacing = 0, padding = PAD })
    local values = {}

    local left = StatColumn(page, "STATS_TITLE", STATS_COLUMN, 240, 30)
    for _, row in ipairs(STAT_ROWS) do
        local labelKey, statKey = row.label, row.key
        values[#values + 1] = StatRow(left, 22, {
            size = "medium", width = 160,
            text = function() return L[labelKey] .. ":" end,
        }, {
            width = 60,
            text = function() return tostring(Stats()[statKey] or 0) end,
        })
    end

    local right = StatColumn(page, "STATS_QUALITY", nil, 200, 26)
    for q = 0, 3 do
        local quality = q
        values[#values + 1] = StatRow(right, 18, {
            width = 90,
            text = function() return QUALITY_LABELS[quality] .. ":" end,
        }, {
            width = 80,
            text = function()
                local st = Stats()
                local count = (st.qualityPicks or {})[quality] or 0
                local total = st.picks or 0
                local pct = total > 0 and math.floor(count / total * 100) or 0
                return string.format("%d (%d%%)", count, pct)
            end,
        })
    end

    return page, values
end

local function BuildMissingTab(area)
    local page = W.Page(area, { spacing = 0 })
    W.Gap(page, 1, MISSING_TOP)
    local row = page:Add("bar", { spacing = 0 })
    W.Gap(row, MISSING_LEFT, 1)
    local scroll = W.Scroll(row, { layout = "VERTICAL", spacing = 2 })
    W.ScrollSize(scroll, page.spec.width - MISSING_LEFT - MISSING_RIGHT, page.spec.height - MISSING_TOP - MISSING_BOTTOM)
    scroll._loading = scroll._content:Add("status", { key = "REQUESTING_DATA", width = scroll._content.spec.width - 8 })
    return page, scroll
end

local overviewPage
local statsValues
local missingScroll
local missingRows = {}

local function RefreshOverview()
    local build = state.build
    if not build then return end

    for _, element in ipairs(overviewPage._elements) do element:Refresh() end

    for i = 1, BUILD_SLOTS do
        local btn = overviewPage._lockedButtons[i]
        local spellId = LockedSpell(i)
        local data = spellId and EbonBuilds.Catalog.Entry(spellId)
        W.SetRing(btn._ring, spellId and (data and data.quality or 0) or nil)
    end

    local desc = build.comments or ""
    overviewPage._descSmf:Clear()
    overviewPage._descSmf:AddMessage(desc, 0.8, 0.8, 0.8, 1.0)
    overviewPage._descMeasure:SetText(desc)
    FitDescription(overviewPage)
end

local function RefreshStats()
    if not statsValues then return end
    for _, element in ipairs(statsValues) do element:Refresh() end
end

local function CreateMissingRow(content)
    local row = content:Add("bar", { spacing = 2, padding = 2 })
    row:EnableMouse(true)
    W.SpellTip(row, function(self) return self._spellId end, { describe = true, anchor = "ANCHOR_LEFT" })
    local icon = row:Add("icon", {
        size = MISSING_ICON,
        icon = function() return row._spellId and select(3, GetSpellInfo(row._spellId)) end,
    })
    W.SpellTip(icon, function() return row._spellId end, { describe = true, anchor = "ANCHOR_LEFT" })
    row:Add("text", { width = MISSING_NAME, text = function() return row._name end })
    W.Gap(row, 0, 1)
    row:Add("status", { width = MISSING_SOURCE, text = function() return row._source end })
    row._push = W.Gap(row, 0, 1)
    local score = row:Add("text", { width = MISSING_SCORE, text = function() return row._score end })
    score.text:SetJustifyH("RIGHT")
    local push = content.spec.width - MISSING_RIGHT * 2 - row:GetWidth()
    row._push.spec.width = math.max(0, push)
    row._push:SetWidth(row._push.spec.width)
    row:Layout()
    return row
end

local function RefreshMissing()
    local build = state.build
    if not build or not missingScroll then return end
    local content = missingScroll._content
    for _, row in ipairs(missingRows) do row:Hide() end
    local missing = ComputeMissingEchoes(build)
    if missing == nil then
        missingScroll._loading:Show()
        content:Layout()
        return
    end
    missingScroll._loading:Hide()
    for rowIdx, entry in ipairs(missing) do
        local row = missingRows[rowIdx]
        if not row then
            row = CreateMissingRow(content)
            missingRows[rowIdx] = row
        end
        row._spellId = entry.spellId
        row._name    = "|cff" .. (QUALITY_HEX[entry.quality] or QUALITY_HEX[0]) .. entry.name .. "|r"
        row._source  = (entry.dropSource or ""):gsub("^Can be found on ", "")
        row._score   = string.format("%.0f", entry.score)
        row:Show()
        row:Refresh()
    end
    content:Layout()
end

local panes = {}

local function ShowPane(id)
    local pane = panes[id]
    if not pane then return end
    W.ShowPage(pane)
    if id ~= "logbook" and EbonBuilds.SessionHistory and EbonBuilds.SessionHistory.Hide then
        EbonBuilds.SessionHistory.Hide()
    end
    if id == "overview" then
        RefreshOverview()
    elseif id == "stats" then
        RefreshStats()
    elseif id == "missing" then
        RefreshMissing()
    elseif id == "logbook" then
        EbonBuilds.SessionHistory.Show(pane)
    end
end

local function BuildViewFrame(container)
    local f = W.Page(container, { spacing = 0 })

    tabs = W.Tabs(f, {
        { "overview", "TAB_OVERVIEW" },
        { "stats",    "TAB_STATS" },
        { "missing",  "TAB_MISSING" },
        { "logbook",  "TAB_LOGBOOK" },
    }, ShowPane)

    contentArea = f:Add("bar", {
        frame = "SMALL", layout = "VERTICAL", spacing = 0, padding = CONTENT_INSET,
        width = f.spec.width, height = f.spec.height - tabs:GetHeight() - BOX_BOTTOM,
    })

    overviewPage = BuildOverviewTab(contentArea)
    panes.overview = overviewPage
    panes.stats, statsValues = BuildStatsTab(contentArea)
    panes.missing, missingScroll = BuildMissingTab(contentArea)
    panes.logbook = W.Page(contentArea, { spacing = 0 })

    return f
end

local view = {}

function view.Show(container, context)
    viewFrame = viewFrame or BuildViewFrame(container)
    state.build = (context or {}).build
    W.ShowPage(viewFrame)
    tabs:Select("overview")
end

function view.Hide()
    if EbonBuilds.SessionHistory and EbonBuilds.SessionHistory.Hide then
        EbonBuilds.SessionHistory.Hide()
    end
    if viewFrame then viewFrame:Hide() end
end

function EbonBuilds.BuildOverview.Init()
    EbonBuilds.ViewRouter.Register("buildOverview", view)
end
