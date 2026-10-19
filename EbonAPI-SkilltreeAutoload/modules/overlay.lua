local NS = SkillTreeAutoLoad

local Overlay = {}
NS.Overlay = Overlay

local MARK_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local MARK_INSET = 8
local MARK_LEVEL = 5

local MARK_MIN_SIZE = 12

local BASE_MIN = 28 + 2 * MARK_INSET

Overlay.MARK_LEVEL = MARK_LEVEL

local container, faultContainer
local marks = {}
local faultMarks, faultShown = {}, {}
local markList = {}

local TINT = {
    { 1, 0.82, 0, 0.85 },
    { 0.3, 1, 0.3, 1 },
    { 1, 0.65, 0.1, 1 },
}

local shownTint = {}
local lastFloor

local function CurrentZoom()
    local canvas = _G.skillTreeCanvas
    return canvas and canvas:GetScale() or 1
end

local function NewContainer()
    local canvas = _G.skillTreeCanvas
    if not canvas then return nil end

    local frame = CreateFrame("Frame", nil, canvas)
    frame:SetAllPoints(canvas)
    frame:SetFrameLevel(canvas:GetFrameLevel() + 1 + MARK_LEVEL)
    frame:Hide()

    return frame
end

local function GetContainer()
    container = container or NewContainer()
    return container
end

local function NewMark(parent, nodeId)
    local button = _G["skillTreeNode" .. nodeId]
    if not button then return nil end

    local _, _, _, x, y = button:GetPoint(1)
    if not x then return nil end

    local width, height = button:GetWidth(), button:GetHeight()
    local base = width + 2 * MARK_INSET

    local mark = parent:CreateTexture(nil, "OVERLAY")
    mark:SetTexture(MARK_TEXTURE)
    mark:SetBlendMode("ADD")
    mark:SetPoint("CENTER", parent, "TOPLEFT", x + width / 2, y - height / 2)
    mark:SetSize(base, base)
    mark:Hide()
    mark.base = base
    markList[#markList + 1] = mark

    if lastFloor and lastFloor > base then mark:SetSize(lastFloor, lastFloor) end
    return mark
end

local function GetMark(nodeId)
    local mark = marks[nodeId]
    if mark then return mark end

    local parent = GetContainer()
    if not parent then return nil end

    mark = NewMark(parent, nodeId)
    marks[nodeId] = mark
    return mark
end

local function ApplySizes(zoom)
    local floorSize = MARK_MIN_SIZE / zoom

    if floorSize <= BASE_MIN and (lastFloor or 0) <= BASE_MIN then return end
    if floorSize == lastFloor then return end
    lastFloor = floorSize

    for i = 1, #markList do
        local mark = markList[i]
        local size = mark.base
        if floorSize > size then size = floorSize end
        mark:SetSize(size, size)
    end
end

function Overlay.Hide()
    if container then container:Hide() end
end

function Overlay.Rescale()
    ApplySizes(CurrentZoom())
end

function Overlay.SetAlpha(alpha)
    local parent = GetContainer()
    if parent then parent:SetAlpha(alpha) end
end

function Overlay.Show(missing, affordable)
    local parent = GetContainer()
    if not parent then return 0 end

    ApplySizes(CurrentZoom())

    for nodeId in pairs(shownTint) do
        if not (missing and missing[nodeId]) then
            local mark = marks[nodeId]
            if mark then mark:Hide() end
            shownTint[nodeId] = nil
        end
    end

    local skipped = 0

    if missing then
        for nodeId in pairs(missing) do
            local tint
            if not affordable then
                tint = 1
            elseif affordable[nodeId] then
                tint = 2
            else
                tint = 3
            end

            local mark = GetMark(nodeId)
            if not mark then
                skipped = skipped + 1
            elseif shownTint[nodeId] ~= tint then
                local color = TINT[tint]
                mark:SetVertexColor(color[1], color[2], color[3])
                mark:SetAlpha(color[4])
                mark:Show()
                shownTint[nodeId] = tint
            end
        end
    end

    parent:Show()
    return skipped
end

function Overlay.Fault(set)
    for nodeId in pairs(faultShown) do
        if not (set and set[nodeId]) then
            faultMarks[nodeId]:Hide()
            faultShown[nodeId] = nil
        end
    end

    if not set then
        if faultContainer then faultContainer:Hide() end
        return
    end

    faultContainer = faultContainer or NewContainer()
    if not faultContainer then return end

    for nodeId in pairs(set) do
        if not faultShown[nodeId] then
            local mark = faultMarks[nodeId]
            if not mark then
                mark = NewMark(faultContainer, nodeId)
                if mark then
                    EbonAPI.Palette.paint(mark, "SetVertexColor", "danger")
                    faultMarks[nodeId] = mark
                end
            end
            if mark then
                mark:Show()
                faultShown[nodeId] = true
            end
        end
    end

    faultContainer:Show()
end
