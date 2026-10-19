local _, ns = ...

local Stars = {}
ns.Stars = Stars

local TEXTURE = "Interface\\Common\\FavoritesIcon"
local LEFT, RIGHT, TOP, BOTTOM = 0.15625, 0.71875, 0.125, 0.6875
local COUNT = 3

function Stars.Width(size, gap)
    return COUNT * size + (COUNT - 1) * gap
end

function Stars.Create(parent, size, gap, layer)
    local row = {}
    for i = 1, COUNT do
        local t = parent:CreateTexture(nil, layer or "OVERLAY")
        t:SetTexture(TEXTURE)
        t:SetTexCoord(LEFT, RIGHT, TOP, BOTTOM)
        t:SetWidth(size)
        t:SetHeight(size)
        t:Hide()
        row[i] = t
    end
    row[1]:SetPoint("RIGHT", row[2], "LEFT", -gap, 0)
    row[3]:SetPoint("LEFT", row[2], "RIGHT", gap, 0)
    return row
end

function Stars.Place(row, point, relative, relativePoint, x, y)
    local middle = row[2]
    middle:ClearAllPoints()
    middle:SetPoint(point, relative, relativePoint, x, y)
end

function Stars.Set(row, count)
    if row.count == count then return end
    row.count = count
    for i = 1, COUNT do
        local t = row[i]
        if count then
            local lit = i <= count
            t:SetDesaturated(not lit)
            if lit then
                t:SetVertexColor(1, 1, 1, 1)
            else
                t:SetVertexColor(0.4, 0.4, 0.4, 0.85)
            end
            t:Show()
        else
            t:Hide()
        end
    end
end
