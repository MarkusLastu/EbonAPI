EbonBuilds.BonusView = {}

local L = EbonBuilds.L
local W = EbonBuilds.Widgets

local QUALITY_NAME = EbonBuilds.Const.QUALITY_NAME
local QUALITY_HEX  = EbonBuilds.Const.QUALITY_HEX
local FAMILIES     = EbonBuilds.Const.FAMILIES

local MODE_ADD      = "+"
local MODE_MULTIPLY = "|cff19ff19x|r"
local FIELD_WIDTH   = 90
local MODE_WIDTH    = 22
local CELL_GAP      = 4
local CELL_HEIGHT   = 42
local COLUMNS       = 4
local HINT_MARGIN   = 60

local viewFrame
local page
local fields = {}

local function Settings()
    return EbonBuilds.BuildForm.GetEditingSettings()
end

local function ModeText(on)
    return on and MODE_MULTIPLY or MODE_ADD
end

local function Cell(parent, title, read, write, readMode, writeMode)
    local cell = W.Kit("bar", parent, {
        spacing = CELL_GAP, width = FIELD_WIDTH + CELL_GAP + MODE_WIDTH, height = CELL_HEIGHT,
    })

    local field
    local function Commit(text)
        local num = tonumber(text)
        if num then write(num) end
        field:Refresh()
    end
    field = W.Field(cell, {
        text = title, width = FIELD_WIDTH,
        get = function() return tostring(read() or 0) end,
        onChange = function(_, text) Commit(text) end,
    }, {
        maxLetters = 6,
        digits = { negative = true, decimal = true },
        onBlur = Commit,
    })
    field.edit:SetJustifyH("CENTER")
    field.edit:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    field._commit = Commit
    fields[#fields + 1] = field

    local column = W.Column(cell)
    local mode = W.Kit("button", column, {
        width = MODE_WIDTH,
        text = function() return ModeText(readMode()) end,
        onClick = function(self)
            writeMode(not readMode())
            self:Refresh()
        end,
    })
    local _, _, _, _, top = field.field:GetPoint(1)
    W.Lead(column, field.field:GetHeight() - (top or 0) - mode:GetHeight())

    return cell
end

local function Section(parent, key, hintKey, width)
    local section = parent:Add("group", { key = key })
    section:Add("status", { key = hintKey, width = width - HINT_MARGIN })
    return section
end

local function BuildQualityBonusSection(parent, width)
    local section = Section(parent, "BONUS_QUALITY", "BONUS_MODE_HINT", width)
    local grid = section:Add("grid", { columns = COLUMNS })
    for q = 0, 3 do
        local quality = q
        Cell(grid,
            function() return "|cff" .. QUALITY_HEX[quality] .. QUALITY_NAME[quality] .. "|r" end,
            function() return Settings().qualityBonus[quality] end,
            function(v) Settings().qualityBonus[quality] = v end,
            function() return Settings().qualityBonusMode[quality] end,
            function(v) Settings().qualityBonusMode[quality] = v end)
    end
end

local function BuildFamilyBonusSection(parent, width)
    local section = Section(parent, "BONUS_FAMILY", "BONUS_MODE_HINT", width)
    local grid = section:Add("grid", { columns = COLUMNS })
    for _, fam in ipairs(FAMILIES) do
        local family = fam
        Cell(grid,
            function() return L.FAMILY[family] or family end,
            function() return Settings().familyBonus[family] end,
            function(v) Settings().familyBonus[family] = v end,
            function() return Settings().familyBonusMode[family] end,
            function(v) Settings().familyBonusMode[family] = v end)
    end
end

local function BuildNoveltyBonusSection(parent, width)
    local section = Section(parent, "BONUS_NOVELTY", "BONUS_NOVELTY_HINT", width)
    Cell(section,
        function() return L.BONUS_VALUE end,
        function() return Settings().noveltyValue end,
        function(v) Settings().noveltyValue = v end,
        function() return Settings().noveltyMode end,
        function(v) Settings().noveltyMode = v end)
end

local function BuildViewFrame(container)
    local f = W.Page(container, { spacing = 0 })
    local width = EbonBuilds.BuildTabs.ContentWidth()

    page = f:Add("group", { key = "BONUS_HEADER", scroll = "VERTICAL", width = f.spec.width, height = f.spec.height })

    BuildQualityBonusSection(page, width)
    BuildFamilyBonusSection(page, width)
    BuildNoveltyBonusSection(page, width)

    return f
end

local function CommitFocusedBoxes()
    for _, field in ipairs(fields) do
        if field.edit:HasFocus() then field._commit(field.edit:GetText() or "") end
    end
end

function EbonBuilds.BonusView.Mount(container)
    viewFrame = viewFrame or BuildViewFrame(container)
    W.ShowPage(viewFrame)
    page:Refresh()
end

function EbonBuilds.BonusView.Unmount()
    if not viewFrame then return end
    CommitFocusedBoxes()
    viewFrame:Hide()
end
