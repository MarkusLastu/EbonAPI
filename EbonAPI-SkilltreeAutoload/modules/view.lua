local NS = SkillTreeAutoLoad

local View = {}
NS.View = View

local SAFETY_MIN_ZOOM = 0.1

local HOVER_DELAY = 0.3
local TRANSITION = 0.25
local FRAME_MARGIN = 24
local ARROW_SIZE = 28
local ARROW_INSET = 6

local ARROW_TEXTURES = {
    LEFT = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up",
    RIGHT = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
    TOP = "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up",
    BOTTOM = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
}

local COUNT_ANCHORS = {
    LEFT = { "LEFT", "RIGHT", 2, 0 },
    RIGHT = { "RIGHT", "LEFT", -2, 0 },
    TOP = { "TOP", "BOTTOM", 0, -2 },
    BOTTOM = { "BOTTOM", "TOP", 0, 2 },
}

local panel, driver
local covered, coveredSide = 0, "RIGHT"
local viewShift, draggingTree, driving = 0, false, false

local base
local padX, padY = 0, 0

local origin, target, pending, anim
local hovering, flaggedKey, flaggedCount = false, nil, nil
local arrows = {}
local faultArrows, faults, faultSets = {}, {}, {}
local RefreshFaults

local function Clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function TreeVisible()
    return _G.skillTreeScroll and _G.skillTreeCanvas and skillTreeScroll:IsVisible()
end

local function CaptureBase(view)
    if view:GetNumPoints() ~= 2 then return nil end

    local anchors = {}
    for i = 1, 2 do
        local point, relativeTo, relativePoint, x, y = view:GetPoint(i)
        anchors[point] = {
            relativeTo = relativeTo or view:GetParent(),
            relativePoint = relativePoint, x = x, y = y,
        }
    end

    local topLeft, bottomRight = anchors.TOPLEFT, anchors.BOTTOMRIGHT
    if not (topLeft and bottomRight and topLeft.relativeTo == bottomRight.relativeTo
        and topLeft.relativePoint == "TOPLEFT" and bottomRight.relativePoint == "BOTTOMRIGHT") then
        return nil
    end

    return {
        frame = topLeft.relativeTo,
        left = topLeft.x, top = topLeft.y, right = bottomRight.x, bottom = bottomRight.y,
    }
end

local function SetPadding(x, y)
    if not base or (x == padX and y == padY) then return end
    padX, padY = x, y
    skillTreeScroll:SetPoint("TOPLEFT", base.frame, "TOPLEFT", base.left + x, base.top - y)
end

local function ViewSize()
    if not base then return skillTreeScroll:GetWidth(), skillTreeScroll:GetHeight() end
    return base.frame:GetWidth() - base.left + base.right,
        base.frame:GetHeight() + base.top - base.bottom
end

local function ViewTop()
    if not base then return skillTreeScroll:GetTop() end
    local frameTop = base.frame:GetTop()
    return frameTop and (frameTop + base.top)
end

local function FreeRect()
    local width, height = ViewSize()
    local left, right = 0, width
    if coveredSide == "LEFT" then left = covered else right = width - covered end

    local top = 0
    local bar = skillTreeFrame.progressBar
    local viewTop = ViewTop()
    if bar and bar:IsShown() and bar:GetBottom() and viewTop then
        top = math.max(0, viewTop - bar:GetBottom())
    end

    return left, top, right, height
end

local function WantedShift()
    if covered == 0 then return 0 end
    return (coveredSide == "LEFT") and -covered / 2 or covered / 2
end

local function MoveHorizontally(delta)
    local view = _G.skillTreeScroll
    if not view or delta == 0 then return 0 end

    local current = view:GetHorizontalScroll()
    local wanted = Clamp(current + delta, 0, view:GetHorizontalScrollRange())

    driving = true
    view:SetHorizontalScroll(wanted)
    driving = false

    return wanted - current
end

local function SyncShift()
    viewShift = viewShift + MoveHorizontally(WantedShift() - viewShift)
end

local ICON_HIDE_ZOOM = 0.50
local iconButtons, iconsHidden = nil, false

local function CollectIcons()
    if iconButtons then return iconButtons end

    local defs = NS.Core.GetNodeDefs()
    if not defs then return nil end

    local list = {}
    for nodeId in pairs(defs) do
        local btn = _G["skillTreeNode" .. nodeId]
        if btn and btn.icon then list[#list + 1] = btn end
    end

    if #list == 0 then return nil end

    iconButtons = list
    return list
end

local function SetIconsShown(shown)
    if iconsHidden == not shown then return end

    local buttons = CollectIcons()
    if not buttons then return end

    iconsHidden = not shown
    for i = 1, #buttons do
        local btn = buttons[i]
        if shown then
            btn.icon:Show()
            if btn.rankText then btn.rankText:Show() end
        else
            btn.icon:Hide()
            if btn.rankText then btn.rankText:Hide() end
        end
    end
end

local function SetZoom(zoom)
    local canvas = skillTreeCanvas
    local current = canvas:GetScale()
    if math.abs(zoom - current) < 0.0001 then return end

    local width, height = canvas:GetWidth() * current, canvas:GetHeight() * current
    canvas:SetScale(zoom)
    canvas:SetSize(width / zoom, height / zoom)

    SetIconsShown(zoom >= ICON_HIDE_ZOOM)
    NS.Overlay.Rescale()
    RefreshFaults()
end

local function ViewCenter()
    local view, zoom = skillTreeScroll, skillTreeCanvas:GetScale()
    local left, top, right, bottom = FreeRect()
    return (view:GetHorizontalScroll() - padX + (left + right) / 2) / zoom,
        (view:GetVerticalScroll() - padY + (top + bottom) / 2) / zoom
end

local function ScrollTarget(cx, cy, zoom)
    local left, top, right, bottom = FreeRect()
    return cx * zoom - (left + right) / 2, cy * zoom - (top + bottom) / 2
end

local function PlaceView(cx, cy)
    local view = skillTreeScroll
    local scrollX, scrollY = ScrollTarget(cx, cy, skillTreeCanvas:GetScale())

    driving = true
    view:SetHorizontalScroll(Clamp(scrollX + padX, 0, math.max(0, view:GetHorizontalScrollRange())))
    view:SetVerticalScroll(Clamp(scrollY + padY, 0, math.max(0, view:GetVerticalScrollRange())))
    driving = false
end

local nodeRects = {}

local function NodeRect(nodeId)
    local rect = nodeRects[nodeId]
    if rect then return rect[1], rect[2], rect[3], rect[4] end

    local button = _G["skillTreeNode" .. nodeId]
    if not button then return nil end

    local _, _, _, x, y = button:GetPoint(1)
    if not x then return nil end

    rect = { x, -y, x + button:GetWidth(), -y + button:GetHeight() }
    nodeRects[nodeId] = rect
    return rect[1], rect[2], rect[3], rect[4]
end

local function Bounds(set)
    local minX, minY, maxX, maxY
    for nodeId in pairs(set) do
        local left, top, right, bottom = NodeRect(nodeId)
        if left then
            if not minX then
                minX, minY, maxX, maxY = left, top, right, bottom
            else
                minX, minY = math.min(minX, left), math.min(minY, top)
                maxX, maxY = math.max(maxX, right), math.max(maxY, bottom)
            end
        end
    end
    return minX, minY, maxX, maxY
end

local function FitZoom(minX, minY, maxX, maxY)
    local left, top, right, bottom = FreeRect()
    local width = right - left - 2 * FRAME_MARGIN
    local height = bottom - top - 2 * FRAME_MARGIN
    return math.min(width / math.max(maxX - minX, 1), height / math.max(maxY - minY, 1))
end

local function ComputeFraming(missing, affordable)
    local minX, minY, maxX, maxY = Bounds(missing)
    if not minX then
        return nil
    end

    local fit = FitZoom(minX, minY, maxX, maxY)
    if fit < SAFETY_MIN_ZOOM then
        local focusMinX, focusMinY, focusMaxX, focusMaxY
        if affordable and next(affordable) then
            focusMinX, focusMinY, focusMaxX, focusMaxY = Bounds(affordable)
        end
        if not focusMinX then
            focusMinX, focusMinY, focusMaxX, focusMaxY = Bounds(NS.Plan.LargestGroup(missing))
        end
        if focusMinX then
            minX, minY, maxX, maxY = focusMinX, focusMinY, focusMaxX, focusMaxY
            fit = FitZoom(minX, minY, maxX, maxY)
        end
    end

    local zoom = math.max(SAFETY_MIN_ZOOM, math.min(origin.zoom, fit))

    return zoom, (minX + maxX) / 2, (minY + maxY) / 2
end

local function HideArrows()
    for _, arrow in pairs(arrows) do arrow:Hide() end
end

local function GetArrow(store, side, fault)
    local arrow = store[side]
    if arrow then return arrow end

    arrow = CreateFrame("Frame", nil, skillTreeFrame)
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)

    arrow.icon = arrow:CreateTexture(nil, "ARTWORK")
    arrow.icon:SetAllPoints(arrow)
    arrow.icon:SetTexture(ARROW_TEXTURES[side])
    if fault then EbonAPI.Palette.paint(arrow.icon, "SetVertexColor", "danger") end

    local anchor = COUNT_ANCHORS[side]
    arrow.count = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow.count:SetPoint(anchor[1], arrow, anchor[2], anchor[3], anchor[4])

    store[side] = arrow
    return arrow
end

local function PlaceArrows(missing, store, fault)
    if not (missing and TreeVisible()) then return end

    local view, zoom = skillTreeScroll, skillTreeCanvas:GetScale()
    local scrollX, scrollY = view:GetHorizontalScroll(), view:GetVerticalScroll()
    local left, top, right, bottom = FreeRect()

    local counts, sums = {}, {}
    for nodeId in pairs(missing) do
        local nodeLeft, nodeTop, nodeRight, nodeBottom = NodeRect(nodeId)
        if nodeLeft then
            local x = (nodeLeft + nodeRight) / 2 * zoom - scrollX + padX
            local y = (nodeTop + nodeBottom) / 2 * zoom - scrollY + padY
            local dx = (x < left) and (left - x) or ((x > right) and (x - right) or 0)
            local dy = (y < top) and (top - y) or ((y > bottom) and (y - bottom) or 0)

            if dx > 0 or dy > 0 then
                local side, along
                if dx >= dy then
                    side, along = (x < left) and "LEFT" or "RIGHT", y
                else
                    side, along = (y < top) and "TOP" or "BOTTOM", x
                end
                counts[side] = (counts[side] or 0) + 1
                sums[side] = (sums[side] or 0) + along
            end
        end
    end

    local level = skillTreeCanvas:GetFrameLevel() + 2 + NS.Overlay.MARK_LEVEL + (fault and 1 or 0)
    local edge = ARROW_INSET + ARROW_SIZE / 2

    for side, count in pairs(counts) do
        local along = sums[side] / count
        local x, y
        if side == "LEFT" or side == "RIGHT" then
            x = (side == "LEFT") and (left + edge) or (right - edge)
            y = Clamp(along, top + edge, bottom - edge)
        else
            x = Clamp(along, left + edge, right - edge)
            y = (side == "TOP") and (top + edge) or (bottom - edge)
        end

        local arrow = GetArrow(store, side, fault)
        arrow:ClearAllPoints()
        if base then
            arrow:SetPoint("CENTER", base.frame, "TOPLEFT", base.left + x, base.top - y)
        else
            arrow:SetPoint("CENTER", view, "TOPLEFT", x, -y)
        end
        arrow:SetFrameLevel(level)
        arrow.count:SetText(count)
        arrow:Show()
    end
end

local function ShowArrows(missing)
    HideArrows()
    PlaceArrows(missing, arrows, false)
end

function RefreshFaults()
    local any = next(faults) ~= nil
    NS.Overlay.Fault(any and faults or nil)
    for _, arrow in pairs(faultArrows) do arrow:Hide() end
    if any then PlaceArrows(faults, faultArrows, true) end
end

local function ReadRankNode(set, facts)
    local node = facts and facts.node
    local id = tonumber(node)
    if not id and node then
        local defs = NS.Core.GetNodeDefs()
        for nodeId, def in pairs(defs or {}) do
            if def.name == node and (not id or nodeId < id) then id = nodeId end
        end
    end
    if id then set[id] = true end
end

local function ReadWantedNodes(set, facts)
    for id in tostring(facts and facts.wanted or ""):gmatch("(%d+):%d+") do set[tonumber(id)] = true end
end

local FAULT_READERS = {
    ["STAL.IMPORT.NODES_NOT_APPLIED"] = ReadWantedNodes,
    ["STAL.IMPORT.RANK_TOO_HIGH"] = ReadRankNode,
}

local function RebuildFaults()
    for id in pairs(faults) do faults[id] = nil end
    for _, set in pairs(faultSets) do
        for id in pairs(set) do faults[id] = true end
    end
    RefreshFaults()
end

local function OnProblem(_, addon, problem)
    local read = addon == "SkillTreeAutoLoad" and FAULT_READERS[problem.code]
    if not read then return end

    local set = faultSets[problem.code] or {}
    faultSets[problem.code] = set
    for id in pairs(set) do set[id] = nil end
    read(set, problem.facts)
    RebuildFaults()
end

local function OnProblemClosed(_, addon, code)
    local set = addon == "SkillTreeAutoLoad" and faultSets[code]
    if not (set and next(set)) then return end

    for id in pairs(set) do set[id] = nil end
    RebuildFaults()
end

function View.ClearFaults()
    local had = next(faults) ~= nil
    for _, set in pairs(faultSets) do
        for id in pairs(set) do set[id] = nil end
    end
    if had then RebuildFaults() end
end

local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP_RATIO = 0.10, 2.50, 1.12
local ZOOM_LABEL_HOLD = 1

local ladder, ladderLabels, ladderCount
local wheelNotches = 0
local nativeWheel, wheelBroken
local zoomLabelUntil

local floor, log, GetCursorPosition = math.floor, math.log, GetCursorPosition

local function LabelLadder()
    for i = 1, ladderCount do
        ladderLabels[i] = string.format(NS.L.LABEL_ZOOM, floor(ladder[i] * 100 + 0.5))
    end
end

local function BuildLadder()
    if ladder then return end

    local steps = math.ceil(log(ZOOM_MAX / ZOOM_MIN) / log(ZOOM_STEP_RATIO))
    local ratio = (ZOOM_MAX / ZOOM_MIN) ^ (1 / steps)

    ladder, ladderLabels, ladderCount = {}, {}, steps + 1
    for i = 1, ladderCount do
        ladder[i] = ZOOM_MIN * ratio ^ (i - 1)
    end

    ladder[1], ladder[ladderCount] = ZOOM_MIN, ZOOM_MAX

    LabelLadder()
end

function View.Localize()
    if ladder then LabelLadder() end
end

local function NearestIndex(zoom)
    local lo, hi = 1, ladderCount
    while lo < hi do
        local mid = floor((lo + hi) * 0.5)
        if ladder[mid] < zoom then lo = mid + 1 else hi = mid end
    end

    if lo > 1 and (zoom - ladder[lo - 1]) < (ladder[lo] - zoom) then return lo - 1 end
    return lo
end

local function AnchorScroll(scroll, offset, ratio)
    return (scroll + offset) * ratio - offset
end

local function CursorOffsets(view)
    local left, top = view:GetLeft(), view:GetTop()
    if not (left and top) then return nil end

    local scale = view:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale - left, top - y / scale
end

local function AbandonPreview()
    if not origin then return end

    origin, target, pending, anim = nil, nil, nil, nil
    HideArrows()
    NS.Overlay.Rescale()
    SetPadding(0, 0)
end

local function ShowZoomLabel(index)
    local fs = skillTreeFrame.zoomText
    if not fs then
        fs = skillTreeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("TOP", skillTreeFrame, "TOP", 0, -10)
        skillTreeFrame.zoomText = fs
    end

    local label = ladderLabels[index]
    if fs.stalLabel ~= label then
        fs.stalLabel = label
        fs:SetText(label)
    end

    zoomLabelUntil = GetTime() + ZOOM_LABEL_HOLD
end

local function ApplyWheel(notches)
    if not TreeVisible() then return end

    BuildLadder()

    AbandonPreview()

    local view = skillTreeScroll
    local from = skillTreeCanvas:GetScale()

    local index = NearestIndex(from) + notches
    if index < 1 then
        index = 1
    elseif index > ladderCount then
        index = ladderCount
    end

    local to = ladder[index]
    if to == from then return end

    local offsetX, offsetY = CursorOffsets(view)
    if not offsetX then return end

    local ratio = to / from
    local h = AnchorScroll(view:GetHorizontalScroll(), offsetX, ratio)
    local v = AnchorScroll(view:GetVerticalScroll(), offsetY, ratio)

    SetZoom(to)

    driving = true
    view:SetHorizontalScroll(Clamp(h, 0, math.max(0, view:GetHorizontalScrollRange())))
    view:SetVerticalScroll(Clamp(v, 0, math.max(0, view:GetVerticalScrollRange())))
    driving = false

    ShowZoomLabel(index)
end

local function RestoreNativeWheel(err)
    if wheelBroken then return end
    wheelBroken = true

    if nativeWheel and _G.skillTreeScroll then
        skillTreeScroll:SetScript("OnMouseWheel", nativeWheel)
    end
    NS.api:Degrade(NS.api:Problem("VIEW.ZOOM_DISABLED", { detail = tostring(err) }))
end

local function OnTreeWheel(_, delta)
    wheelNotches = wheelNotches + delta
    if driver then driver:Show() end
end

local function ClearZoomLabel()
    zoomLabelUntil = nil

    local fs = skillTreeFrame and skillTreeFrame.zoomText
    if fs and fs.stalLabel then
        fs.stalLabel = nil
        fs:SetText("")
    end
end

local function Smooth(t)
    return t * t * (3 - 2 * t)
end

local function ShowMarks()
    if not (target and target.missing) then return end

    local skipped = NS.Overlay.Show(target.missing, target.affordable)
    ShowArrows(target.missing)

    skipped = skipped or 0
    if skipped > 0 then
        if flaggedKey ~= target.key or flaggedCount ~= skipped then
            flaggedKey, flaggedCount = target.key, skipped
            local save = NS.Data.GetSave(target.key)
            NS.api:Degrade(NS.api:Problem("SAVE.NODES_NOT_IN_TREE",
                { save = save and save.name or tostring(target.key), nodes = skipped }))
        end
    elseif flaggedKey == target.key then
        flaggedKey, flaggedCount = nil, nil
        NS.api:Restore("SAVE.NODES_NOT_IN_TREE")
    end
end

local function StartAnimation(zoom, cx, cy, restore)
    local fromZoom = skillTreeCanvas:GetScale()
    local fromX, fromY = ViewCenter()

    local zoomedOut = zoom < fromZoom
    if zoomedOut then SetZoom(zoom) end

    local panZoom = zoomedOut and zoom or fromZoom
    local startX, startY = ScrollTarget(fromX, fromY, panZoom)
    local endX, endY = ScrollTarget(cx, cy, panZoom)
    SetPadding(math.max(0, -startX, -endX), math.max(0, -startY, -endY))

    anim = {
        startedAt = GetTime(), restore = restore, zoomedOut = zoomedOut,
        fromX = fromX, fromY = fromY, toZoom = zoom, toX = cx, toY = cy,
    }

    HideArrows()
    NS.Overlay.Hide()
    driver:Show()
end

local function StartRestore()
    local left, top, right, bottom = FreeRect()
    StartAnimation(origin.zoom,
        (origin.scrollX + (left + right) / 2) / origin.zoom,
        (origin.scrollY + (top + bottom) / 2) / origin.zoom, true)
end

local function FinishRestore()
    local canvas = skillTreeCanvas
    canvas:SetScale(origin.zoom)
    canvas:SetSize(origin.width, origin.height)
    SetIconsShown(origin.zoom >= ICON_HIDE_ZOOM)
    NS.Overlay.Rescale()
    SetPadding(0, 0)

    local view = skillTreeScroll
    driving = true
    view:SetHorizontalScroll(origin.scrollX)
    view:SetVerticalScroll(origin.scrollY)
    driving = false

    origin, target = nil, nil
    RefreshFaults()
end

local function FrameTarget()
    if not origin then
        local view, canvas = skillTreeScroll, skillTreeCanvas
        origin = {
            zoom = canvas:GetScale(),
            width = canvas:GetWidth(),
            height = canvas:GetHeight(),
            scrollX = view:GetHorizontalScroll(),
            scrollY = view:GetVerticalScroll(),
        }
    end

    local zoom, cx, cy = ComputeFraming(target.missing, target.affordable)
    if not zoom then
        ShowMarks()
        return
    end

    local fromX, fromY = ViewCenter()
    local current = skillTreeCanvas:GetScale()
    if math.abs(zoom - current) < 0.001
        and math.abs(cx - fromX) * zoom < 1 and math.abs(cy - fromY) * zoom < 1 then
        anim = nil
        ShowMarks()
        return
    end

    StartAnimation(zoom, cx, cy, false)
end

local function OnUpdate()
    local now = GetTime()

    if wheelNotches ~= 0 then
        local notches = wheelNotches
        wheelNotches = 0

        local ok, err = pcall(ApplyWheel, notches)
        if not ok then RestoreNativeWheel(err) end
    end

    if zoomLabelUntil and now >= zoomLabelUntil then ClearZoomLabel() end

    if pending and now >= pending.due then
        if hovering and TreeVisible() then
            target = pending
            FrameTarget()
        end
        pending = nil
    end

    if anim then
        local progress = math.min(1, (now - anim.startedAt) / TRANSITION)
        local eased = Smooth(progress)

        if progress >= 1 and not anim.zoomedOut and not anim.restore then
            SetZoom(anim.toZoom)
            local endX, endY = ScrollTarget(anim.toX, anim.toY, anim.toZoom)
            SetPadding(math.max(0, -endX), math.max(0, -endY))
        end

        PlaceView(anim.fromX + (anim.toX - anim.fromX) * eased,
            anim.fromY + (anim.toY - anim.fromY) * eased)

        if progress >= 1 then
            local restore = anim.restore
            anim = nil
            if restore then
                FinishRestore()
            elseif hovering and target then
                ShowMarks()
            end
        end
    end

    if origin and not hovering and not (anim and anim.restore)
        and not (panel and panel:IsMouseOver()) then
        StartRestore()
    end

    if not (pending or anim or origin or zoomLabelUntil) then driver:Hide() end
end

function View.Init()
    local view = _G.skillTreeScroll
    if not view then return end

    base = CaptureBase(view)

    driver = CreateFrame("Frame")
    driver:Hide()
    driver:SetScript("OnUpdate", OnUpdate)

    nativeWheel = view:GetScript("OnMouseWheel")
    view:SetScript("OnMouseWheel", OnTreeWheel)

    view:HookScript("OnMouseDown", function() draggingTree = true end)
    view:HookScript("OnMouseUp", function() draggingTree = false end)

    NS.api:On("PROBLEM", OnProblem)
    NS.api:On("PROBLEM_CLOSED", OnProblemClosed)
    view:HookScript("OnShow", RefreshFaults)
    if _G.skillTreeFrame then _G.skillTreeFrame:HookScript("OnHide", View.ClearFaults) end
    hooksecurefunc(view, "SetVerticalScroll", RefreshFaults)

    hooksecurefunc(view, "SetHorizontalScroll", function()
        RefreshFaults()
        if driving or draggingTree then return end

        AbandonPreview()

        viewShift = 0
        SyncShift()
    end)
end

function View.Attach(frame)
    panel = frame
end

function View.GetViewInsets()
    if not base then return nil end
    return base.frame, base.left, base.top, base.right, base.bottom
end

function View.SetCovered(side, width)
    if side ~= coveredSide or width ~= covered then
        if origin then
            anim, pending = nil, nil
            HideArrows()
            FinishRestore()
        end
        coveredSide, covered = side, width
    end
    SyncShift()
end

function View.Preview(key, missing, affordable)
    hovering = true
    HideArrows()

    if not (driver and TreeVisible() and missing and next(missing)) then
        pending = nil
        NS.Overlay.Hide()
        return
    end

    local entry = { key = key, missing = missing, affordable = affordable }

    if not NS.Data.IsPreviewCamera() then
        target, pending = entry, nil
        ShowMarks()
        return
    end

    if origin and target and target.key == key then
        target, pending = entry, nil
        FrameTarget()
    else
        NS.Overlay.Hide()
        entry.due = (pending and pending.key == key) and pending.due or (GetTime() + HOVER_DELAY)
        pending = entry
    end

    driver:Show()
end

function View.Release()
    hovering = false
    HideArrows()
end

function View.Cancel()
    draggingTree, hovering, pending, anim = false, false, nil, nil
    wheelNotches = 0
    ClearZoomLabel()
    HideArrows()

    if origin and _G.skillTreeScroll and _G.skillTreeCanvas then FinishRestore() end
    origin, target = nil, nil

    if driver then driver:Hide() end
end
