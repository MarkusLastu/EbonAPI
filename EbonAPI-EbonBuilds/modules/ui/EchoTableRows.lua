EbonBuilds.EchoTableRows = {}

local W = EbonBuilds.Widgets

local COL_WEIGHT = 80
local COL_SCORE  = 140
local ROW_HEIGHT = 36
local ROW_PAD    = 4
local ROW_INNER  = ROW_HEIGHT - ROW_PAD * 2
local ICON_SIZE  = 28
local ICON_LEAD  = 2
local NAME_LEAD  = 2
local NAME_ROOM  = COL_WEIGHT + COL_SCORE + 24
local SCORE_ROOM = COL_WEIGHT + 16
local BOX_W      = 58
local BOX_H      = 22
local EDIT_W     = 52
local EDIT_H     = 18
local EDIT_RIGHT = 8

local QUALITY_COLORS = EbonBuilds.Const.QUALITY_HEX

local function UpdateScores(row, entry)
    local weight = EbonBuilds.Weights.Get(entry.name) or 0
    local form = EbonBuilds.BuildForm
    local settings = form.GetEditingSettings()
    local parts = {}
    for q = 0, 4 do
        if entry.qualities[q] then
            local spellId = entry.spellIds and entry.spellIds[q]
            if spellId and form.IsLocked(spellId) then
                parts[#parts + 1] = string.format("|cff%s%s|r", QUALITY_COLORS[q], EbonBuilds.L.LOCKED)
            elseif spellId and form.IsBanned(spellId) then
                parts[#parts + 1] = string.format("|cff%s%s|r", QUALITY_COLORS[q], EbonBuilds.L.BANNED)
            else
                local score = EbonBuilds.Scoring.ScorePerQuality(entry, weight, settings, q)
                parts[#parts + 1] = string.format("|cff%s%d|r", QUALITY_COLORS[q], score)
            end
        end
    end
    row._scoreText = table.concat(parts, " - ")
    row.scoreLabel:Refresh()
end

local function IconSpell(self)
    return self.spellId
end

local function ApplyWeight(editBox, raw)
    local num = tonumber(raw)
    if not (num and math.floor(num) == num and num >= 0) then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("TABLE.WEIGHT_INVALID", { echo = editBox.echoName, value = tostring(raw) }))
    elseif EbonBuilds.Build.GetActive() == nil then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("TABLE.WEIGHT_NOT_SAVED", { echo = editBox.echoName, value = tostring(num) }))
    else
        EbonBuilds.Weights.Set(editBox.echoName, num)
    end
    editBox:SetText(tostring(EbonBuilds.Weights.Get(editBox.echoName)))
    local row = editBox._row
    UpdateScores(row, { name = editBox.echoName, qualities = row._qualities, families = row._families, spellIds = row._spellIds })
end

local function WireWeightBox(editBox)
    W.Digits(editBox)
    editBox:SetScript("OnEnterPressed", function(self)
        ApplyWeight(self, self:GetText())
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        ApplyWeight(self, self:GetText())
    end)
    editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
end

local function Centre(column, element)
    W.Lead(column, (ROW_INNER - element:GetHeight()) / 2)
    return element
end

local function CreateWeightBox(row)
    local column = W.Column(row, BOX_W)
    local holder = Centre(column, column:Add("bar", { width = BOX_W, height = BOX_H }))
    W.InputBackdrop(holder)

    local box = CreateFrame("EditBox", nil, holder)
    box:SetSize(EDIT_W, EDIT_H)
    box:SetPoint("CENTER", holder, "CENTER", 0, 0)
    box:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    box:SetTextColor(1, 1, 1, 1)
    box:SetJustifyH("CENTER")
    box:SetAutoFocus(false)
    box:SetMaxLetters(6)
    box._row = row
    WireWeightBox(box)
    return box
end

local function AddBackground(row, index)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetTexture(0, 0, 0, (index % 2 == 0) and 0.15 or 0.05)
end

function EbonBuilds.EchoTableRows.CreateRow(parent, index)
    local width = parent.spec.width
    local row = parent:Add("bar", { spacing = 4, padding = ROW_PAD, width = width, height = ROW_HEIGHT })
    AddBackground(row, index)

    W.Gap(row, ICON_LEAD, 1)
    local iconFrame = row:Add("icon", {
        size = ICON_SIZE,
        icon = function(self) return self.spellId and select(3, GetSpellInfo(self.spellId)) end,
    })
    W.SpellTip(iconFrame, IconSpell, { describe = true })
    W.Gap(row, NAME_LEAD, 1)

    local nameStart = ROW_PAD + ICON_LEAD + 4 + ICON_SIZE + 4 + NAME_LEAD + 4
    local nameWidth = width - NAME_ROOM - nameStart
    local nameColumn = W.Column(row, nameWidth)
    Centre(nameColumn, nameColumn:Add("text", { size = "medium", width = nameWidth, text = function() return row._nameText end }))

    W.Gap(row, 0, 1)
    local scoreColumn = W.Column(row, COL_SCORE)
    local scoreLabel = Centre(scoreColumn, scoreColumn:Add("text", { width = COL_SCORE, text = function() return row._scoreText end }))
    scoreLabel.text:SetJustifyH("RIGHT")

    local boxStart = width - EDIT_RIGHT - BOX_W
    local scoreEnd = width - SCORE_ROOM
    W.Gap(row, math.max(0, boxStart - scoreEnd - 8), 1)
    local weightBox = CreateWeightBox(row)

    row.iconFrame  = iconFrame
    row.scoreLabel = scoreLabel
    row.weightBox  = weightBox
    row:Hide()
    return row
end

function EbonBuilds.EchoTableRows.Populate(row, yOffset, entry)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 0, yOffset)
    row.iconFrame.spellId = entry.spellId
    row._nameText = entry.name
    row.weightBox.echoName = entry.name
    row.weightBox:SetText(tostring(EbonBuilds.Weights.Get(entry.name)))
    row._qualities = entry.qualities
    row._families  = entry.families
    row._spellIds  = entry.spellIds
    row:Show()
    row:Refresh()
    UpdateScores(row, entry)
end
