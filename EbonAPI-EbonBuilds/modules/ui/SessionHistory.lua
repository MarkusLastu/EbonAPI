EbonBuilds.SessionHistory = {}

local L = EbonBuilds.L
local W = EbonBuilds.Widgets

local QUALITY_HEX = EbonBuilds.Const.QUALITY_HEX
local ACTION_COLORS = {
    Banish         = { 1.0, 0.27, 0.27 },
    Reroll         = { 0.27, 0.67, 1.0 },
    Freeze         = { 0.27, 0.80, 1.0 },
    Select         = { 0.27, 1.0, 0.27 },
    ["Select (Locked)"] = { 1.0, 0.53, 0.0 },
}

local BORDER_ACTIVE   = { 0.27, 1.0, 0.27 }
local BORDER_SELECTED = { 1.0, 0.84, 0.0 }
local BORDER_IDLE     = { 0.4, 0.4, 0.4 }

local CARD_W       = 170
local CARD_H       = 48
local CARD_GAP     = 6
local CARD_STEP    = CARD_W + CARD_GAP
local CARD_PAD     = 4
local CARD_LEFT    = 4
local CARD_TOP     = 2
local CARD_WHEEL   = 30
local DELETE_H     = 14
local ARROW_W      = 16
local EDGE         = 2
local HINT_W       = 300
local BUTTON_GAP   = 6
local HEADER_TOP   = 6
local STRIP_TOP    = 24
local LOG_TOP      = 8
local LOG_INSET    = 4
local LOG_BOTTOM   = 6
local NOTICE_INSET = 6

local page
local sessionItems   = {}
local sortedSessions = {}
local logRows      = {}
local selectedSessionId = nil

local cardScroll, cardChild
local logScroll, logChild, logNotice
local noticeText
local durationTimer
local refreshTimer
local deferTimer

local function FormatDuration(startTime, endTime)
    local t = (endTime or time()) - startTime
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = math.floor(t % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local FormatScore = W.FormatScore

local function FormatTimestamp(ts)
    return date("%H:%M:%S", ts)
end

local function ChoiceName(ch)
    return ch.name or (ch.id and GetSpellInfo(ch.id)) or "?"
end

local function ChoiceQuality(ch)
    if ch.quality then return ch.quality end
    local data = ch.id and EbonBuilds.Catalog.Entry(ch.id)
    return (data and data.quality) or 0
end

local activeSessionCard = nil

local function TickDuration()
    local card = activeSessionCard
    if not (card and card._isActive and card:IsVisible()) then
        activeSessionCard = nil
        return
    end
    card._duration:Refresh()
    EbonBuilds.Timer.Arm(durationTimer, 1, TickDuration)
end

local function PaintCard(item)
    local c = BORDER_IDLE
    if item._id == selectedSessionId then
        c = BORDER_SELECTED
    elseif item._isActive then
        c = BORDER_ACTIVE
    end
    item:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end

local function SelectSession(id)
    selectedSessionId = id
    for _, item in ipairs(sessionItems) do PaintCard(item) end
    EbonBuilds.SessionHistory.RefreshLogView()
end

local function DeleteSession(item)
    local id = item._id
    if not id then return end
    EbonBuilds.api:Dialog({
        text = L.DELETE_SESSION_CONFIRM, acceptKey = "YES", cancelKey = "NO",
        onAccept = function()
            local ok, problem = EbonBuilds.Session.DeleteSession(id)
            if not ok then
                EbonBuilds.api:Report(problem)
                return
            end
            selectedSessionId = nil
            EbonBuilds.SessionHistory.RefreshSessionList()
            EbonBuilds.SessionHistory.RefreshLogView()
        end,
    })
end

local function BuildCard(parent)
    local inner = CARD_W - CARD_PAD * 2
    local item = parent:Add("bar", {
        layout = "VERTICAL", spacing = 0, padding = CARD_PAD, width = CARD_W, height = CARD_H,
    })
    W.InputBackdrop(item)
    item:EnableMouse(true)
    item:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self._id then SelectSession(self._id) end
    end)

    item:Add("status", { width = inner, text = function() return item._levelText end })
    item:Add("status", { width = inner, text = function() return item._soulText end })

    local bottom = item:Add("bar", { spacing = 0 })
    item._duration = bottom:Add("status", {
        width = inner,
        text = function()
            return item._startTime and FormatDuration(item._startTime, item._endTime) or ""
        end,
    })
    local delete = W.Kit("button", bottom, {
        text = "X", height = DELETE_H,
        hidden = function() return item._isActive end,
        onClick = function() DeleteSession(item) end,
    })
    item._duration.spec.width = inner - delete:GetWidth()
    bottom:Refresh()

    item:Hide()
    return item
end

local function PopulateCard(item, s, index)
    local isActive = (s.endTime == nil)
    local level = s.maxLevel or UnitLevel("player")
    item._id        = s.id
    item._isActive  = isActive
    item._startTime = s.startTime
    item._endTime   = s.endTime
    item._levelText = (isActive and L.CARD_ACTIVE or L.CARD_LEVEL):format(level)
    item._soulText  = L.CARD_ASHES:format(isActive and "..." or tostring(s.soulAshes))
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", cardChild, "TOPLEFT", CARD_LEFT + (index - 1) * CARD_STEP, -CARD_TOP)
    PaintCard(item)
    item:Show()
    item:Refresh()
end

local function DrawCards()
    local viewW = W.ScrollView(cardScroll, true) or 0
    if viewW <= 1 then viewW = 520 end
    local first   = math.floor(W.ScrollOffset(cardScroll, true) / CARD_STEP) + 1
    local visible = math.ceil(viewW / CARD_STEP) + 1

    local activeCard = nil
    for poolIdx = 1, visible do
        local index = first + poolIdx - 1
        local s = sortedSessions[index]
        local item = sessionItems[poolIdx]
        if s then
            if not item then
                item = BuildCard(cardChild)
                sessionItems[poolIdx] = item
            end
            PopulateCard(item, s, index)
            if item._isActive then activeCard = item end
        elseif item then
            item:Hide()
        end
    end
    for i = visible + 1, #sessionItems do sessionItems[i]:Hide() end

    activeSessionCard = activeCard
    if durationTimer then
        if activeCard then
            EbonBuilds.Timer.Arm(durationTimer, 1, TickDuration)
        else
            EbonBuilds.Timer.Cancel(durationTimer)
        end
    end
end

local drawingCards = false

local function RenderCards()
    if drawingCards or not cardChild then return end
    drawingCards = true
    DrawCards()
    drawingCards = false
end

function EbonBuilds.SessionHistory.RefreshSessionList()
    if not cardChild then return end

    local sessions = EbonBuilds.Session.GetSessions()
    local activeSession = EbonBuilds.Session.GetActiveSession()

    for i = #sortedSessions, 1, -1 do sortedSessions[i] = nil end
    for i = 1, #sessions do sortedSessions[i] = sessions[i] end
    table.sort(sortedSessions, function(a, b)
        if a == b then return false end
        if a == activeSession then return true end
        if b == activeSession then return false end
        return (a.startTime or 0) > (b.startTime or 0)
    end)

    if not selectedSessionId and activeSession then
        selectedSessionId = activeSession.id
    end

    W.ScrollWidth(cardScroll, CARD_LEFT + #sortedSessions * CARD_STEP)
    RenderCards()
end

local function SummaryText(session)
    local sum = session.logSummary
    if not sum then return nil end
    local order = { "Select", "Freeze", "Banish", "Reroll", "Select (Locked)" }
    local parts = {}
    for _, action in ipairs(order) do
        local n = sum.actions and sum.actions[action]
        if n then parts[#parts + 1] = string.format("%s %d", L.ACTION[action] or action, n) end
    end
    for action, n in pairs(sum.actions or {}) do
        local known = false
        for _, a in ipairs(order) do if a == action then known = true end end
        if not known then parts[#parts + 1] = string.format("%s %d", L.ACTION[action] or action, n) end
    end
    local out = {
        L.LOG_NO_DETAIL,
        string.format(L.LOG_DECISIONS, sum.decisions or 0,
            table.concat(parts, ", ")),
        string.format(L.LOG_CHARGES_END,
            sum.ban or 0, sum.reroll or 0, sum.freeze or 0),
    }
    return table.concat(out, "\n")
end

local TIME_W    = 46
local ACTION_W  = 52
local ECHO_W    = 94
local ECHO_H    = 14
local SCORE_W   = 32
local CHARGES_W = 66
local MAX_ECHO_COLS = 4
local ROW_H     = 18

local CELL_EDGE = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function CellTip(lines, cell)
    if cell._echoScore then
        lines:Add(string.format(L.SCORE, FormatScore(cell._echoScore)), "muted")
    end
end

local function BuildLogCell(row)
    local cell = row:Add("bar", {
        spacing = 2, width = ECHO_W, height = ECHO_H,
        text = function(self) return self._echoName end,
        tip = CellTip,
    })
    cell:SetBackdrop(CELL_EDGE)
    cell:SetBackdropBorderColor(0, 0, 0, 0)
    W.Gap(cell, 2, 1)
    cell:Add("text", { width = ECHO_W - SCORE_W - 10, text = function() return cell._nameText end })
    local score = cell:Add("text", { width = SCORE_W, text = function() return cell._scoreText end })
    score.text:SetJustifyH("RIGHT")
    return cell
end

local function BuildLogRow(parent)
    local row = parent:Add("bar", { spacing = 3, height = ROW_H })
    row:Add("text", { width = TIME_W, text = function() return row._timeText end })
    row:Add("text", { width = ACTION_W, text = function() return row._actionText end })
    row._cells = {}
    for i = 1, MAX_ECHO_COLS do row._cells[i] = BuildLogCell(row) end
    row:Add("text", { width = CHARGES_W, text = function() return row._chargesText end })
    row:Hide()
    return row
end

local logEntries = {}

local function VisibleLogRows()
    local h = logScroll and W.ScrollView(logScroll) or 0
    if h <= 1 then h = 200 end
    return math.ceil(h / ROW_H) + 2
end

local function PopulateLogRow(row, listIdx, entry)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", logChild, "TOPLEFT", 0, -(listIdx - 1) * ROW_H)

    row._timeText = ("|cff888888%s|r"):format(FormatTimestamp(entry.timestamp))

    local ac = ACTION_COLORS[entry.action] or { 1, 1, 1 }
    local acHex = string.format("%02x%02x%02x",
        math.floor(ac[1] * 255), math.floor(ac[2] * 255), math.floor(ac[3] * 255))
    row._actionText = ("|cff%s%s|r"):format(acHex, L.ACTION[entry.action] or entry.action)

    local choices = entry.choices or {}
    for j = 1, MAX_ECHO_COLS do
        local ch   = choices[j]
        local cell = row._cells[j]
        if ch then
            local hex = QUALITY_HEX[ChoiceQuality(ch)] or "ffffff"
            local name = ChoiceName(ch)
            cell._nameText  = ("|cff%s%s|r"):format(hex, name)
            cell._scoreText = ("|cff%s(%s)|r"):format(hex, FormatScore(ch.score))
            cell._echoName  = name
            cell._echoScore = ch.score
            if j == entry.targetIndex then
                cell:SetBackdropBorderColor(ac[1], ac[2], ac[3], 1)
            else
                cell:SetBackdropBorderColor(0, 0, 0, 0)
            end
        else
            cell._nameText, cell._scoreText = "", ""
            cell._echoName, cell._echoScore = nil, nil
            cell:SetBackdropBorderColor(0, 0, 0, 0)
        end
        cell:EnableMouse(ch ~= nil)
    end

    local ch = entry.charges or {}
    row._chargesText = ("|cff888888B:%d R:%d F:%d|r"):format(ch.ban or 0, ch.reroll or 0, ch.freeze or 0)

    row:Show()
    row:Refresh()
end

local function DrawLogRows()
    local offset  = math.floor(W.ScrollOffset(logScroll) / ROW_H)
    local visible = VisibleLogRows()

    for poolIdx = 1, visible do
        local listIdx = offset + poolIdx
        local entry   = logEntries[listIdx]
        if entry then
            if not logRows[poolIdx] then logRows[poolIdx] = BuildLogRow(logChild) end
            PopulateLogRow(logRows[poolIdx], listIdx, entry)
        elseif logRows[poolIdx] then
            logRows[poolIdx]:Hide()
        end
    end
    for i = visible + 1, #logRows do logRows[i]:Hide() end
end

local drawingRows = false

local function RenderLogRows()
    if drawingRows or not logChild then return end
    drawingRows = true
    DrawLogRows()
    drawingRows = false
end

EbonBuilds.SessionHistory._RenderLogRows = RenderLogRows

local function ClearLogRows()
    for _, row in ipairs(logRows) do row:Hide() end
    if logNotice then logNotice:Hide() end
end

function EbonBuilds.SessionHistory.RefreshLogView()
    ClearLogRows()
    logEntries = {}

    if not logScroll or not logChild then return end

    local prevSessionId = logChild._sessionId
    local sessionSwitched = (selectedSessionId ~= prevSessionId)

    local function ShowNothing()
        W.ScrollHeight(logScroll, 1)
        logChild._sessionId = nil
    end

    if not selectedSessionId then return ShowNothing() end

    local sessions = EbonBuilds.Session.GetSessions()
    local session
    for _, s in ipairs(sessions) do
        if s.id == selectedSessionId then session = s; break end
    end
    if not session then return ShowNothing() end

    logChild._sessionId = selectedSessionId

    local savedScroll = W.ScrollOffset(logScroll)
    if sessionSwitched then
        savedScroll = 0
        W.ScrollTo(logScroll, 0)
    end

    logEntries = session.logs or {}

    noticeText = (#logEntries == 0) and SummaryText(session) or nil
    local totalH = #logEntries * ROW_H + 4
    if noticeText then
        logNotice:Show()
        logNotice:Refresh()
        totalH = math.max(totalH, logNotice:GetHeight() + NOTICE_INSET * 2 + 4)
    end
    W.ScrollHeight(logScroll, totalH)
    if not sessionSwitched then W.ScrollTo(logScroll, savedScroll) end

    RenderLogRows()
end

local exportDialog

local EXPORT_WIDTH   = 800
local EXPORT_HEIGHT  = 550
local EXPORT_PADDING = 12
local EXPORT_LINES   = 34

local function BuildExportDialog()
    local f = EbonBuilds.api:Window("sessionExport", {
        key = "EXPORT_SESSION_TITLE", width = EXPORT_WIDTH, height = EXPORT_HEIGHT,
        layout = "VERTICAL", padding = EXPORT_PADDING,
    })
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f._field = W.Field(f, { width = EXPORT_WIDTH - EXPORT_PADDING * 2, lines = EXPORT_LINES })
    return f
end

function EbonBuilds.SessionHistory.ExportSession()
    if not exportDialog then
        exportDialog = BuildExportDialog()
    end

    local session
    if selectedSessionId then
        for _, s in ipairs(EbonBuilds.Session.GetSessions()) do
            if s.id == selectedSessionId then session = s; break end
        end
    end

    if not session then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("HISTORY.NO_SESSION_SELECTED", {}))
        return
    else
        local lines = {}
        lines[#lines + 1] = string.format(L.EXPORT_SESSION_HEADER,
            session.maxLevel or UnitLevel("player"),
            FormatDuration(session.startTime, session.endTime),
            session.soulAshes or 0)
        lines[#lines + 1] = ""

        local logs = session.logs or {}
        if #logs == 0 and session.logSummary then
            local sum = session.logSummary
            lines[#lines + 1] = string.format(
                L.EXPORT_NO_DETAIL, sum.decisions or 0)
            for action, n in pairs(sum.actions or {}) do
                lines[#lines + 1] = string.format("  %-16s %d", L.ACTION[action] or action, n)
            end
            lines[#lines + 1] = string.format(L.EXPORT_CHARGES_END,
                sum.ban or 0, sum.reroll or 0, sum.freeze or 0)
        end
        for _, entry in ipairs(logs) do
            local parts = {}
            parts[#parts + 1] = FormatTimestamp(entry.timestamp)
            parts[#parts + 1] = string.format("%-16s", L.ACTION[entry.action] or entry.action)

            for j, ch in ipairs(entry.choices) do
                local text = string.format("%s (%s)", ChoiceName(ch), FormatScore(ch.score))
                if j == entry.targetIndex then
                    text = ">>" .. text .. "<<"
                end
                parts[#parts + 1] = string.format("%-34s", text)
            end

            local ch = entry.charges or {}
            parts[#parts + 1] = string.format("B:%d  R:%d  F:%d",
                ch.ban or 0, ch.reroll or 0, ch.freeze or 0)

            lines[#lines + 1] = table.concat(parts, "")
        end

        exportDialog._field:SetValue(table.concat(lines, "\n"))
    end

    exportDialog:Show()
end

local function ScrollCards(delta)
    W.ScrollTo(cardScroll, W.ScrollOffset(cardScroll, true) + delta * CARD_WHEEL, true)
end

local function ClearSessions()
    EbonBuilds.Session.ClearAllSessions()
    selectedSessionId = nil
    EbonBuilds.SessionHistory.RefreshSessionList()
    EbonBuilds.SessionHistory.RefreshLogView()
end

local function RefreshAll()
    EbonBuilds.SessionHistory.RefreshSessionList()
    EbonBuilds.SessionHistory.RefreshLogView()
end

local function BuildHeader(width)
    local Kit = W.Kit
    local head = page:Add("bar", { spacing = 0 })
    W.Gap(head, EDGE * 2, 1)
    Kit("text", head, { key = "LOGBOOK_HINT", width = HINT_W })
    local push = W.Gap(head, 1, 1)
    local exportBtn = Kit("button", head, {
        key = "EXPORT", minWidth = 60,
        onClick = function() EbonBuilds.SessionHistory.ExportSession() end,
    })
    W.Gap(head, BUTTON_GAP, 1)
    local clearBtn = Kit("button", head, {
        key = "CLEAR_ALL", minWidth = 100,
        onClick = function()
            EbonBuilds.api:Dialog({
                text = L.CLEAR_SESSIONS_CONFIRM, acceptKey = "YES", cancelKey = "NO",
                onAccept = ClearSessions,
            })
        end,
    })
    push.spec.width = math.max(1, width - EDGE * 4 - HINT_W - BUTTON_GAP - exportBtn:GetWidth() - clearBtn:GetWidth())
    push:SetWidth(push.spec.width)
    head:Layout()
    return head
end

local function BuildStrip(width)
    local Kit = W.Kit
    local strip = page:Add("bar", { spacing = EDGE })
    W.Gap(strip, 0, 1)
    Kit("button", strip, { text = "<", width = ARROW_W, height = CARD_H, onClick = function() ScrollCards(-1) end })
    cardScroll = W.Scroll(strip, { scroll = "HORIZONTAL", width = width - ARROW_W * 2 - EDGE * 4, onScroll = RenderCards })
    cardChild = cardScroll._content
    W.ScrollHeight(cardScroll, CARD_H + CARD_TOP * 2)
    Kit("button", strip, { text = ">", width = ARROW_W, height = CARD_H, onClick = function() ScrollCards(1) end })
end

local function BuildLog(width)
    local row = page:Add("bar", { spacing = 0 })
    W.Gap(row, LOG_INSET, 1)
    logScroll = W.Scroll(row, { key = "LOGBOOK_HEADER", onScroll = RenderLogRows })
    logChild = logScroll._content
    W.ScrollSize(logScroll, width - LOG_INSET * 2, W.Rest(page, row) - LOG_BOTTOM)
    logNotice = logChild:Add("text", {
        width = logChild.spec.width - NOTICE_INSET * 2,
        text = function() return noticeText end,
    })
    logNotice:SetPoint("TOPLEFT", logChild, "TOPLEFT", NOTICE_INSET, -NOTICE_INSET)
    logNotice:Hide()
end

local function BuildUI(host)
    page = host
    local width = page.spec.width

    W.Gap(page, 1, HEADER_TOP)
    local head = BuildHeader(width)
    W.Gap(page, 1, math.max(1, STRIP_TOP - HEADER_TOP - head:GetHeight()))
    BuildStrip(width)
    W.Gap(page, 1, LOG_TOP)
    BuildLog(width)

    durationTimer = EbonBuilds.Timer.New("Logbook duration")
    refreshTimer  = EbonBuilds.Timer.New("Logbook refresh")
    deferTimer    = EbonBuilds.Timer.New("Logbook first draw")
end

function EbonBuilds.SessionHistory.Show(container)
    local firstBuild = not page
    if firstBuild then BuildUI(container) end

    if firstBuild then
        EbonBuilds.Timer.Arm(deferTimer, 0, RefreshAll)
    else
        RefreshAll()
    end
end

function EbonBuilds.SessionHistory.Hide()
    if exportDialog then exportDialog:Hide() end
    activeSessionCard = nil
    if durationTimer then EbonBuilds.Timer.Cancel(durationTimer) end
    if deferTimer    then EbonBuilds.Timer.Cancel(deferTimer)    end
    if refreshTimer  then EbonBuilds.Timer.Cancel(refreshTimer)  end
end

local function OnSessionChanged()
    if refreshTimer and page and page:IsVisible() then
        EbonBuilds.Timer.Arm(refreshTimer, 0.2, RefreshAll)
    end
end

function EbonBuilds.SessionHistory.Init()
    EbonBuilds.Events.On("EB_SESSION_CHANGED", OnSessionChanged, "Logbook")
end
