EbonBuilds.BuildDetail = {}

local L = EbonBuilds.L
local W = EbonBuilds.Widgets
local Codec = EbonAPI.Profile

local WIDTH      = 360
local HEIGHT     = EbonBuilds.MainWindow.HEIGHT
local PADDING    = 8
local INNER      = WIDTH - PADDING * 2
local BESIDE     = 2
local COLUMNS    = 5
local CELL_W     = 62
local CELL_H     = 66
local ICON_SIZE  = 36
local BADGE      = 17
local BOOK_SIZE  = 11
local CORNER     = 2
local HALO       = ICON_SIZE * 1.7
local HALO_TURN  = 8
local HALO_ALPHA = 0.6
local DISCS      = { { 0, BADGE - 1 }, { -BADGE, 0 }, { BADGE, 0 } }
local GRID_TOP   = 10
local SLOT       = 42
local SLOT_GAP   = 8
local SLOTS_TOP  = SLOT / 2
local HEAD_ICON  = 24
local HEAD_GAP   = 6
local HEAD_TEXT  = 220
local FAMILY_W   = INNER - HEAD_ICON - HEAD_GAP
local FAMILY_GAP = 4
local NAME_H     = 22
local NOTICE_H   = 18
local WISH_H     = 24
local WISH_W     = 220
local WISH_ROOM  = WISH_H + PADDING
local CARD_ICON  = 28
local CARD_ECHO  = 22
local CARD_TEXT  = CARD_ICON + 32
local SMALL_ICON = 22
local SMALL_ECHO = 20
local SMALL_GAP  = 2
local SPEC_ICON  = 14
local ACTIVE     = 0.25
local NAME_MAX   = 32
local ACK_WINDOW = 30
local UPLOAD     = "REQUEST_PERK_LOADOUT_UPLOAD"
local NO_FAMILY  = "No family"
local ASSETS     = "Interface\\AddOns\\ProjectEbonhold\\assets\\"
local STAR       = "Interface\\Cooldown\\star4"
local NO_ICON    = "Interface\\Icons\\INV_Misc_QuestionMark"
local EMPTY_SLOT = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
local BOOK       = "Interface\\Icons\\INV_Misc_Book_09"
local GREY       = { 0.5, 0.5, 0.5 }
local GOLD       = { 1, 0.82, 0 }
local GOLD_HEX   = "ffd100"
local SOLID      = "Interface\\Buttons\\WHITE8X8"

local BUILD_SLOTS  = EbonBuilds.Const.BUILD_LOCKED_SLOTS
local CLASS_COLORS = EbonBuilds.Const.CLASS_RGB
local QUALITY_HEX  = EbonBuilds.Const.QUALITY_HEX
local FAMILY_MAP   = EbonBuilds.Const.FAMILY_MAP
local FAMILIES     = EbonBuilds.Const.FAMILIES

local STAR_RGB = {
    [0] = { 1.0, 1.0, 1.0 },
    [1] = { 0.1, 1.0, 0.1 },
    [2] = { 0.0, 0.4, 1.0 },
    [3] = { 0.8, 0.4, 1.0 },
    [4] = { 1.0, 0.5, 0.0 },
}

local frame, page, others, holder, slotRow
local permSlots, gridCells = {}, {}
local echoes, counts, chosen = {}, {}, {}
local current, pendingEntry, pendingName, pendingAt
local listening = false

local function Quality(spellId)
    local data = EbonBuilds.Catalog.Entry(spellId)
    return data and data.quality or 0
end

local function Art(quality)
    return math.min(quality, 3)
end

local function Hex(quality)
    return QUALITY_HEX[quality] or QUALITY_HEX[0]
end

local function LockedSet(entry)
    local set = {}
    for _, id in ipairs(entry.locked and Codec.DecodeLocked(entry.locked) or {}) do set[id] = true end
    return set
end

local function IsOwnClass(entry)
    return entry ~= nil and entry.class == EbonBuilds.Build.PlayerClassToken()
end

local function ByRarity(a, b)
    if a.quality ~= b.quality then return a.quality > b.quality end
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
end

local function Families(spellId, into)
    local data = EbonBuilds.Catalog.Entry(spellId)
    for _, family in ipairs(data and data.families or {}) do
        local key = FAMILY_MAP[family] or family
        if key ~= NO_FAMILY then into[key] = true end
    end
end

function EbonBuilds.BuildDetail.Split(entry)
    local ids, stacks, n = Codec.DecodeBuild(entry.echoes)
    local lockedSet = LockedSet(entry)
    local items, locked, grid, byName = {}, {}, {}, {}
    for i = 1, n or 0 do
        items[i] = { id = ids[i], stacks = stacks[i], quality = Quality(ids[i]), name = GetSpellInfo(ids[i]) or "" }
    end
    table.sort(items, ByRarity)
    for _, item in ipairs(items) do
        local key = item.name ~= "" and item.name or item.id
        local echo = byName[key]
        if not echo then
            echo = { id = item.id, quality = item.quality, name = item.name, held = {}, families = {} }
            byName[key] = echo
            grid[#grid + 1] = echo
        end
        Families(item.id, echo.families)
        local held = echo.held
        local last = held[#held]
        if last and last.quality == item.quality then
            last.stacks = last.stacks + item.stacks
        else
            held[#held + 1] = { quality = item.quality, stacks = item.stacks }
        end
        if lockedSet[item.id] then
            locked[#locked + 1] = item
            echo.locked = true
        end
    end
    for _, echo in ipairs(grid) do
        if not next(echo.families) then echo.families[NO_FAMILY] = true end
    end
    return locked, grid
end

local function Tally(grid)
    local tally = {}
    for _, echo in ipairs(grid) do
        for family in pairs(echo.families) do tally[family] = (tally[family] or 0) + 1 end
    end
    return tally
end

local function Picked(echo)
    if not next(chosen) then return true end
    for family in pairs(echo.families) do
        if chosen[family] then return true end
    end
    return false
end

local function EchoOf(self)
    local spellId = self._spellId
    if not spellId then return nil end
    return spellId, Quality(spellId), self._stacks
end

local function EchoStars(self)
    if self._spellId and IsOwnClass(current) and EbonBuilds.OnJournalEnter then
        self.spellId = self._spellId
        EbonBuilds.OnJournalEnter(self)
    end
end

local function EchoTip(element)
    W.SpellTip(element, EchoOf, { colored = true, describe = true })
    element:HookScript("OnEnter", EchoStars)
end

local function Spin(slot, texture, seconds, degrees)
    local group = texture:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    local rotation = group:CreateAnimation("Rotation")
    rotation:SetDuration(seconds)
    rotation:SetDegrees(degrees)
    rotation:SetOrigin("CENTER", 0, 0)
    slot._spins[#slot._spins + 1] = group
end

local function Mark(cell, layer, sublevel, path, size, point, anchor, x, y)
    local texture = cell:CreateTexture(nil, layer, nil, sublevel)
    texture:SetTexture(path)
    texture:SetWidth(size)
    texture:SetHeight(size)
    texture:SetPoint(point, anchor, point, x, y)
    return texture
end

local function ShowIf(region, on)
    if on then region:Show() else region:Hide() end
end

local function CreateCell(parent)
    local cell = parent:Add("bar", { layout = "VERTICAL", spacing = 2, width = CELL_W, height = CELL_H })
    cell:EnableMouse(true)
    cell._spins, cell._discs, cell._counts = {}, {}, {}

    local base = cell:CreateTexture(nil, "BORDER")
    base:SetWidth(ICON_SIZE + 2)
    base:SetHeight(ICON_SIZE + 2)
    base:SetPoint("TOP", cell, "TOP", 0, -2)
    cell._base = base

    local tex = cell:CreateTexture(nil, "ARTWORK")
    tex:SetWidth(ICON_SIZE - 4)
    tex:SetHeight(ICON_SIZE - 4)
    tex:SetPoint("CENTER", base, "CENTER", 0, 0)
    cell._tex = tex

    local ring = cell:CreateTexture(nil, "OVERLAY")
    ring:SetWidth(110 * ICON_SIZE / 32)
    ring:SetHeight(110 * ICON_SIZE / 32)
    ring:SetPoint("CENTER", base, "CENTER", 0, 1)
    cell._ring = ring

    cell._halo = Mark(cell, "BACKGROUND", 0, STAR, HALO, "CENTER", base, 0, 0)
    cell._halo:SetBlendMode("ADD")
    Spin(cell, cell._halo, HALO_TURN, 360)

    for i, at in ipairs(DISCS) do
        local disc = Mark(cell, "OVERLAY", 5, ASSETS .. "background_count", BADGE, "CENTER", base, at[1], at[2])
        local count = cell:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("CENTER", disc, "CENTER", 0, 0)
        cell._discs[i], cell._counts[i] = disc, count
    end

    cell._book = Mark(cell, "OVERLAY", 6, BOOK, BOOK_SIZE, "BOTTOMRIGHT", tex, CORNER, -CORNER)
    cell._book:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell._lock = Mark(cell, "OVERLAY", 7, ASSETS .. "lock", BADGE, "TOPRIGHT", tex, CORNER, CORNER)

    W.Gap(cell, CELL_W, ICON_SIZE + 4)
    local name = cell:Add("text", { width = CELL_W - 2, text = function() return cell._nameText end })
    name.text:SetJustifyH("CENTER")
    name.text:SetHeight(NAME_H)

    EchoTip(cell)
    return cell
end

local function Fill(cell, item)
    local q, held = item.quality, item.held
    local rgb = item.locked and GOLD or STAR_RGB[q] or STAR_RGB[0]
    local data = EbonBuilds.Catalog.Entry(item.id)
    cell._spellId, cell._stacks = item.id, held[1].stacks
    cell._base:SetTexture(ASSETS .. "perk_quality_" .. Art(q))
    cell._ring:SetTexture(ASSETS .. "perk_border_quality_" .. Art(q))
    SetPortraitToTexture(cell._tex, select(3, GetSpellInfo(item.id)) or NO_ICON)
    local counted = #held > 1 or held[1].stacks > 1
    for i, disc in ipairs(cell._discs) do
        local rarity = counted and held[i]
        ShowIf(disc, rarity)
        cell._counts[i]:SetText(rarity and "|cff" .. Hex(rarity.quality) .. rarity.stacks .. "|r" or "")
    end
    ShowIf(cell._lock, item.locked)
    ShowIf(cell._book, data and data.requiredSpell and data.requiredSpell ~= 0)
    cell._halo:SetVertexColor(rgb[1], rgb[2], rgb[3], HALO_ALPHA)
    cell._nameText = "|cff" .. (item.locked and GOLD_HEX or Hex(q)) .. item.name .. "|r"
end

local function Layer(slot, layer, sublevel, path, scale, blend)
    local texture = slot:CreateTexture(nil, layer, nil, sublevel)
    texture:SetPoint("CENTER", slot, "CENTER", 0, 0)
    texture:SetWidth(SLOT * scale)
    texture:SetHeight(SLOT * scale)
    if path then texture:SetTexture(path) end
    if blend then texture:SetBlendMode(blend) end
    return texture
end

local function CreatePermSlot(parent)
    local slot = parent:Add("bar", { width = SLOT, height = SLOT })
    slot:EnableMouse(true)
    slot._spins = {}

    local bg = Layer(slot, "BACKGROUND", 0, ASSETS .. "perm_background_texture", 1.6)
    bg:SetPoint("CENTER", slot, "CENTER", 0, -1)

    slot._swirl = Layer(slot, "BACKGROUND", 1, STAR, 2.0, "ADD")
    Spin(slot, slot._swirl, 4, 360)

    local swirl2 = Layer(slot, "BACKGROUND", 2, STAR, 1.75, "ADD")
    swirl2:SetVertexColor(1, 1, 1, 0.4)
    Spin(slot, swirl2, 5, -360)

    local turning = Layer(slot, "OVERLAY", 1, ASSETS .. "rotating_perm_texture", 1.9, "ADD")
    Spin(slot, turning, 6, -360)

    slot._iconBase = Layer(slot, "BORDER", 0, nil, 1.2)
    slot._icon = Layer(slot, "ARTWORK", 0, nil, 0.8)

    slot._border = Layer(slot, "OVERLAY", 7, nil, 110 / 32)
    slot._border:SetPoint("CENTER", slot, "CENTER", 0, 2)

    EchoTip(slot)
    return slot
end

local function FillPerm(slot, item)
    local q = item and Quality(item.id) or 0
    local rgb = STAR_RGB[q] or STAR_RGB[0]
    slot._iconBase:SetTexture(ASSETS .. "perk_quality_" .. Art(q))
    slot._border:SetTexture(ASSETS .. "perk_border_quality_" .. Art(q))
    if item then
        slot._spellId, slot._stacks = item.id, item.stacks
        slot._swirl:SetVertexColor(rgb[1], rgb[2], rgb[3], 0.55)
        SetPortraitToTexture(slot._icon, select(3, GetSpellInfo(item.id)) or NO_ICON)
        slot._icon:Show()
    else
        slot._spellId, slot._stacks = nil, nil
        slot._swirl:SetVertexColor(1, 1, 1, 0.35)
        slot._icon:Hide()
    end
end

local function PermSlot(i)
    local slot = permSlots[i]
    if not slot then
        slot = CreatePermSlot(slotRow)
        permSlots[i] = slot
        if frame:IsShown() then
            for _, group in ipairs(slot._spins) do group:Play() end
        end
    end
    return slot
end

local function Turn(owner, on)
    for _, group in ipairs(owner._spins) do
        if on then group:Play() else group:Stop() end
    end
end

local function SetSpinning(on)
    for _, slot in ipairs(permSlots) do Turn(slot, on) end
    for _, cell in ipairs(gridCells) do Turn(cell, on) end
end

local function GridCell(i)
    local cell = gridCells[i]
    if not cell then
        cell = CreateCell(holder)
        gridCells[i] = cell
        if frame:IsShown() then Turn(cell, true) end
    end
    return cell
end

local function DefaultName(entry)
    return string.format(L.WISHLIST_DEFAULT_NAME, EbonBuilds.ClassName(entry.class), entry.count)
end

local function Clean(name)
    name = tostring(name or ""):gsub("[|;:,]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return name:sub(1, NAME_MAX)
end

local function OnAck(body)
    local status, op = tostring(body):match("^([^,]+),([^,]+)")
    if op ~= "upload" or not pendingName then return end
    local elapsed = GetTime() - pendingAt
    if elapsed > ACK_WINDOW then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("DETAIL.WISHLIST_ACK_LATE", { wishlist = pendingName, elapsed = math.floor(elapsed) }))
    elseif status == "OK" then
        EbonBuilds.api:Notify(string.format(L.WISHLIST_CREATED, pendingName))
    else
        EbonBuilds.api:Report(EbonBuilds.api:Problem("DETAIL.WISHLIST_ACK_REFUSED", { wishlist = pendingName, status = status }))
    end
    pendingName = nil
end

local function Send(name)
    local entry = pendingEntry
    pendingEntry = nil
    if not IsOwnClass(entry) then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("DETAIL.WISHLIST_OTHER_CLASS", { class = EbonBuilds.ClassName(entry.class) }))
        return
    end
    name = Clean(name)
    if name == "" then name = Clean(DefaultName(entry)) end
    local ids, stacks, n = Codec.DecodeBuild(entry.echoes)
    if not ids or n == 0 then
        EbonBuilds.api:Report(EbonBuilds.api:Problem("DETAIL.WISHLIST_BUILD_UNREADABLE", { wishlist = name, echoes = n or 0 }))
        return
    end
    local locked = LockedSet(entry)
    local parts = {}
    for i = 1, n do
        parts[i] = ids[i] .. "." .. stacks[i] .. "." .. (locked[ids[i]] and 1 or 0)
    end
    if not listening then
        EbonBuilds.api:OnServer(EbonAPI.SS.BUILD_ACK, OnAck)
        listening = true
    end
    local sent = EbonAPI.Ebonhold.SendToServer(UPLOAD, "0|" .. name .. "|" .. table.concat(parts, ","))
    if sent then pendingName, pendingAt = name, GetTime() end
end

local function AskName()
    EbonBuilds.api:Dialog({
        text       = L.WISHLIST_NAME_PROMPT,
        input      = pendingEntry and DefaultName(pendingEntry) or "",
        maxLetters = NAME_MAX,
        cancelKey  = "CANCEL",
        onAccept   = function(name) Send(name) end,
        onCancel   = function() pendingEntry = nil end,
    })
end

local function WishTip(add)
    if IsOwnClass(current) then return false end
    add(L.WISHLIST_OTHER_CLASS, "text", true)
end

local function WishClick()
    if not IsOwnClass(current) then return end
    pendingEntry = current
    AskName()
end

local function Title(entry)
    if not entry then return "" end
    return "|cff" .. W.ClassHex(entry.class) .. (entry.title or EbonBuilds.ClassName(entry.class)) .. "|r"
end

local function Count(entry)
    return entry and string.format(L.RECEIVED_ECHOES, entry.count) or ""
end

local function FitOthers()
    W.ScrollSize(others, INNER, W.Rest(page, others))
end

local function ShowGrid()
    local shown = 0
    for _, echo in ipairs(echoes) do
        if Picked(echo) then
            shown = shown + 1
            local cell = GridCell(shown)
            if not cell:IsShown() then
                cell:Show()
                Turn(cell, true)
            end
            Fill(cell, echo)
        end
    end
    for i = shown + 1, #gridCells do gridCells[i]:Hide() end
    holder:Refresh()
    W.ScrollTo(others, 0)
end

local function FamilyToggle(bar, family)
    bar:Add("toggle", {
        text = function() return string.format(L.FAMILY_COUNT, L.FAMILY[family] or family, counts[family] or 0) end,
        get = function() return chosen[family] == true end,
        hidden = function() return not counts[family] and not chosen[family] end,
        onChange = function(toggle, on)
            chosen[family] = on or nil
            if not counts[family] then
                toggle:Refresh()
                FitOthers()
            end
            ShowGrid()
        end,
    })
end

local function BuildFrame(main)
    local f = EbonBuilds.api:Window("buildDetail", {
        text = function() return Title(current) end,
        width = WIDTH, height = HEIGHT, layout = "VERTICAL", spacing = 0, padding = PADDING,
        point = main and { "TOPLEFT", main, "TOPRIGHT", BESIDE, 0 } or nil,
    })
    f:HookScript("OnShow", function() SetSpinning(true) end)
    f:HookScript("OnHide", function()
        current, chosen = nil, {}
        SetSpinning(false)
    end)
    if main then main:HookScript("OnHide", EbonBuilds.BuildDetail.Hide) end

    local height = HEIGHT - f.head:GetHeight() - PADDING
    page = f:Add("bar", { layout = "VERTICAL", spacing = 0, width = INNER, height = height })

    local head = page:Add("bar", { spacing = HEAD_GAP })
    W.ClassIcon(head:Add("icon", { size = HEAD_ICON }), function() return current and current.class end)
    local summary = head:Add("bar", { layout = "VERTICAL", spacing = 0 })
    summary:Add("status", { width = HEAD_TEXT, text = function() return Count(current) end })
    local families = summary:Add("bar", { layout = "FLOW", wrap = FAMILY_W, spacing = FAMILY_GAP })
    for _, family in ipairs(FAMILIES) do FamilyToggle(families, family) end

    W.Gap(page, 1, SLOTS_TOP)
    slotRow = page:Add("bar", { spacing = SLOT_GAP, height = SLOT + SLOT_GAP })
    W.Gap(slotRow, (INNER - BUILD_SLOTS * (SLOT + SLOT_GAP) + SLOT_GAP) / 2 - SLOT_GAP, 1)

    local unknownRow = page:Add("bar", {
        height = NOTICE_H,
        hidden = function() return current == nil or current.locked ~= nil end,
    })
    local unknown = unknownRow:Add("status", { key = "DETAIL_LOCKED_UNKNOWN", width = INNER })
    unknown.text:SetJustifyH("CENTER")

    others = W.Scroll(page, { width = INNER, layout = "VERTICAL", spacing = 0 })
    W.Gap(others._content, 1, GRID_TOP)
    holder = others._content:Add("bar", { layout = "GRID", columns = COLUMNS, spacing = 0 })

    local wish = page:Add("bar", {
        layout = "VERTICAL", height = WISH_ROOM,
        hidden = function() return current ~= nil and current.slot ~= nil end,
    })
    local wishBtn = W.Kit("button", W.Centered(wish, INNER, WISH_W), {
        key = "ADD_TO_WISHLIST", width = WISH_W, height = WISH_H,
        disabled = function() return not IsOwnClass(current) end,
        onClick = WishClick,
    })
    W.Tip(wishBtn, WishTip)

    hooksecurefunc(f, "Refresh", FitOthers)
    return f
end

local function Render()
    local locked, grid = EbonBuilds.BuildDetail.Split(current)
    for i = 1, BUILD_SLOTS do FillPerm(PermSlot(i), locked[i]) end
    echoes, counts = grid, Tally(grid)
    frame:Refresh()
    ShowGrid()
end

function EbonBuilds.BuildDetail.Show(entry)
    if not entry then return end
    if not frame then frame = BuildFrame(EbonBuilds.MainWindow._frame) end
    current = entry
    frame:Show()
    Render()
end

function EbonBuilds.BuildDetail.Hide()
    current = nil
    if frame then frame:Hide() end
end

function EbonBuilds.BuildDetail.Current()
    return current
end

local function OpenCard(self, mouse)
    if mouse ~= "LeftButton" then return end
    local card = self._card or self
    card._open(card._entry)
end

local function CardEcho(self)
    return self._spellId and select(3, GetSpellInfo(self._spellId)) or EMPTY_SLOT
end

local function CardEntry(self)
    return self._card and self._card._entry
end

local function CardSpec(self)
    local entry = CardEntry(self)
    return entry and entry.spec
end

local function NoEcho(self)
    return self._spellId == nil
end

local function TitleOnly()
end

local function Cover(card, alpha)
    local texture = W.Hover(card:CreateTexture(nil, "ARTWORK"), alpha)
    texture:SetAllPoints(card)
    texture:Hide()
    return texture
end

function EbonBuilds.BuildDetail.Card(parent, width, style)
    style = style or {}
    local small = style.small
    local card = parent:Add("bar", { frame = "SMALL", width = width, layout = small and "VERTICAL" or "HORIZONTAL" })
    card._open = style.onOpen or EbonBuilds.BuildDetail.Show
    card:EnableMouse(true)
    card:SetScript("OnMouseUp", OpenCard)

    local tint = card:CreateTexture(nil, "BACKGROUND")
    tint:SetTexture(SOLID)
    tint:SetPoint("TOPLEFT",     card, "TOPLEFT",     4, -4)
    tint:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -4, 4)
    card._tint = tint

    local stripe = card:CreateTexture(nil, "ARTWORK")
    stripe:SetTexture(SOLID)
    stripe:SetPoint("TOPLEFT",    card, "TOPLEFT",    4, -4)
    stripe:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 4,  4)
    card._stripe = stripe
    card._small = small

    card._active = Cover(card, ACTIVE)
    local hover = Cover(card)
    card:SetScript("OnEnter", function() hover:Show() end)
    card:SetScript("OnLeave", function() hover:Hide() end)

    local head = small and card:Add("bar", {}) or card
    local classIcon = head:Add("icon", {
        size = small and SMALL_ICON or CARD_ICON, onClick = OpenCard, tip = TitleOnly,
        text = function(self) local entry = CardEntry(self) return entry and EbonBuilds.ClassName(entry.class) end,
    })
    classIcon._card = card
    W.ClassIcon(classIcon, function(self) local entry = CardEntry(self) return entry and entry.class end)

    local names = head:Add("bar", { layout = "VERTICAL" })
    card._title = names:Add("text", {
        size = "medium", width = width - CARD_TEXT,
        text = function(self) return Title(CardEntry(self)) end,
    })
    card._title._card = card
    if not small then
        card._meta = names:Add("status", {
            width = width - CARD_TEXT,
            text = function(self) return Count(CardEntry(self)) end,
        })
        card._meta._card = card
    end

    local row = (small and card or names):Add("bar", { spacing = small and SMALL_GAP or nil })
    if small then
        local specIcon = row:Add("icon", {
            size = SPEC_ICON, onClick = OpenCard, tip = TitleOnly,
            icon = function(self) local spec = CardSpec(self) return spec and spec.icon end,
            text = function(self) local spec = CardSpec(self) return spec and spec.name end,
            hidden = function(self) return CardSpec(self) == nil end,
        })
        specIcon._card = card
    end
    card._echoBtns = {}
    for i = 1, BUILD_SLOTS do
        local icon = row:Add("icon", {
            size = small and SMALL_ECHO or CARD_ECHO, icon = CardEcho, onClick = OpenCard,
            hidden = small and NoEcho or nil,
        })
        icon._card = card
        W.SpellTip(icon, EchoOf, { describe = true })
        card._echoBtns[i] = icon
    end
    return card
end

function EbonBuilds.BuildDetail.FillCard(card, entry)
    local cc = CLASS_COLORS[entry.class] or GREY
    card._entry = entry
    local active = entry.active
    card._stripe:SetVertexColor(cc[1], cc[2], cc[3], active and 1 or (card._small and 0.6 or 0.8))
    card._stripe:SetWidth(active and 6 or 4)
    card._tint:SetVertexColor(cc[1], cc[2], cc[3], active and 0.12 or 0.06)
    if active then card._active:Show() else card._active:Hide() end
    local ids = entry.lockedIds
    if not ids then
        ids = {}
        for i, item in ipairs((EbonBuilds.BuildDetail.Split(entry))) do ids[i] = item.id end
    end
    for i, icon in ipairs(card._echoBtns) do
        icon._spellId = ids[i]
    end
    card:Refresh()
end
