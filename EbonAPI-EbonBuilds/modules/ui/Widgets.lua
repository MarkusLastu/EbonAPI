local _, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local CLASS_TEXTURE = ns.Const.CLASS_TEXTURE
local UNKNOWN_ICON  = "Interface\\Icons\\INV_Misc_QuestionMark"
local SOLID         = "Interface\\Buttons\\WHITE8X8"
local DIM_ALPHA     = 0.5
local HOVER_ALPHA   = 0.2
local HINT_X        = 6
local HINT_Y        = 4
local TIP_COLORS    = {
    title = { 1, 0.82, 0 },
    text  = { 1, 1, 1 },
    muted = { 0.6, 0.6, 0.6 },
    faint = { 0.5, 0.5, 0.5 },
    error = { 1, 0.3, 0.3 },
}

local floor = math.floor
local looks = {}

local function Unpack(color)
    return floor(color / 65536) / 255, floor(color / 256) % 256 / 255, color % 256 / 255
end

function Widgets.Color(name)
    return Unpack(ns.api:GetParameter(name))
end

function Widgets.OnLook(fn)
    looks[#looks + 1] = fn
    fn()
end

if ns.api then
    ns.api:On("PARAMETER_CHANGED", function()
        for i = 1, #looks do looks[i]() end
    end)
end

function Widgets.Kit(kind, parent, spec)
    local element = ns.api:Create(kind, parent, spec or {})
    if kind == "button" then element:RegisterForClicks("LeftButtonUp") end
    return element
end

function Widgets.Hover(texture, alpha)
    Widgets.OnLook(function()
        local r, g, b = Widgets.Color("accent")
        texture:SetTexture(SOLID)
        texture:SetVertexColor(r, g, b, alpha or HOVER_ALPHA)
    end)
    return texture
end

function Widgets.Ring(element)
    local ring = element:CreateTexture(nil, "BACKGROUND")
    ring:SetAllPoints(element)
    ring:SetTexture(SOLID)
    ring:Hide()
    return ring
end

function Widgets.SetRing(ring, quality)
    if quality == nil then
        ring:Hide()
        return
    end
    local c = ns.Const.QUALITY_RGB[quality] or ns.Const.QUALITY_RGB[0]
    ring:SetVertexColor(c[1], c[2], c[3], 1)
    ring:Show()
end

local function DigitsFilter(negative, decimal)
    return function(self, char)
        local valid = char >= "0" and char <= "9"
        if decimal and char == "." and not (self:GetText() or ""):find("%.") then valid = true end
        if negative and char == "-" and self:GetCursorPosition() == 0 then valid = true end
        if not valid then
            local pos  = self:GetCursorPosition()
            local text = self:GetText() or ""
            self:SetText(text:sub(1, pos - 1) .. text:sub(pos + 1))
            self:SetCursorPosition(pos - 1)
        end
    end
end

function Widgets.Digits(edit, negative, decimal)
    edit:HookScript("OnChar", DigitsFilter(negative, decimal))
end

local function Placeholder(field, key)
    local edit = field.edit
    local hint = ns.api:Create("status", field.field, { key = key, width = field:GetWidth() - HINT_X * 2 })
    hint:SetPoint("TOPLEFT", field.field, "TOPLEFT", HINT_X, -HINT_Y)
    local function Refresh()
        if edit:HasFocus() or (edit:GetText() or "") ~= "" then hint:Hide() else hint:Show() end
    end
    edit:HookScript("OnTextChanged", Refresh)
    edit:HookScript("OnEditFocusGained", Refresh)
    edit:HookScript("OnEditFocusLost", Refresh)
    hooksecurefunc(field, "SetValue", Refresh)
    Refresh()
end

function Widgets.Field(parent, spec, options)
    local field = Widgets.Kit("input", parent, spec)
    local edit = field.edit
    options = options or {}
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if options.maxLetters then edit:SetMaxLetters(options.maxLetters) end
    if options.digits then Widgets.Digits(edit, options.digits.negative, options.digits.decimal) end
    if options.onText then
        edit:HookScript("OnTextChanged", function(self) options.onText(self:GetText() or "") end)
    end
    if options.onBlur then
        edit:HookScript("OnEditFocusLost", function(self) options.onBlur(self:GetText() or "") end)
    end
    if options.placeholder then Placeholder(field, options.placeholder) end
    return field
end

local function TipLine(text, color, wrap)
    local c = TIP_COLORS[color or "text"]
    GameTooltip:AddLine(text, c[1], c[2], c[3], wrap)
end

function Widgets.Tip(element, fill, anchor)
    element:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_TOP")
        GameTooltip:ClearLines()
        if fill(TipLine, self) == false then
            GameTooltip:Hide()
            return
        end
        GameTooltip:Show()
    end)
    element:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function Widgets.SpellTip(element, spellOf, options)
    options = options or {}
    Widgets.Tip(element, function(add, self)
        local spellId, quality, stacks = spellOf(self)
        if not spellId then return false end
        local name = GetSpellInfo(spellId)
        if name and options.colored then
            add("|cff" .. (ns.Const.QUALITY_HEX[quality or 0] or "ffffff") .. name .. "|r")
        elseif name then
            add(name, "title")
        end
        if options.describe and utils and utils.GetSpellDescription then
            local desc = utils.GetSpellDescription(spellId, 500, stacks or 1)
            if desc and desc ~= "" then add(desc, "text", true) end
        end
    end, options.anchor or "ANCHOR_RIGHT")
end

function Widgets.Tabs(parent, entries, onSelect)
    local tabs = Widgets.Kit("tabs", parent, {
        onSelect = function(_, id) onSelect(id) end,
    })
    for i = 1, #entries do
        tabs:AddTab(entries[i][1], { key = entries[i][2] })
    end
    return tabs
end

function Widgets.ClassIcon(element, classOf)
    hooksecurefunc(element, "Refresh", function(self)
        Widgets.SetClassIcon(self.icon, classOf(self))
    end)
    Widgets.SetClassIcon(element.icon, classOf(element))
    return element
end

function Widgets.SetClassIcon(tex, classToken)
    local coords = classToken and CLASS_ICON_TCOORDS[classToken]
    if coords then
        tex:SetTexture(CLASS_TEXTURE)
        tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        tex:SetTexture(UNKNOWN_ICON)
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

function Widgets.ClassHex(classToken)
    local c = ns.Const.CLASS_RGB[classToken] or { 0.5, 0.5, 0.5 }
    return string.format("%02x%02x%02x", floor(c[1] * 255), floor(c[2] * 255), floor(c[3] * 255))
end

local FLAT = { bgFile = SOLID, edgeFile = SOLID, edgeSize = 1 }

function Widgets.InputBackdrop(frame)
    frame:SetBackdrop(FLAT)
    Widgets.OnLook(function()
        local r, g, b = Widgets.Color("background")
        local ar, ag, ab = Widgets.Color("accent")
        frame:SetBackdropColor(r, g, b, ns.api:GetParameter("opacity"))
        frame:SetBackdropBorderColor(ar, ag, ab, DIM_ALPHA)
    end)
end

function Widgets.Scroll(parent, spec)
    spec = spec or {}
    local across = spec.scroll == "HORIZONTAL"
    local scroll = Widgets.Kit("group", parent, {
        key = spec.key, scroll = spec.scroll or "VERTICAL", width = spec.width or 1, height = spec.height,
    })
    local content = { layout = spec.layout or "NONE", width = 1, spacing = spec.spacing, columns = spec.columns }
    if not spec.layout then content.height = 1 end
    scroll._content = scroll:Add("bar", content)
    if spec.onScroll then
        local bar = across and scroll.kitScroll.hbar or scroll.kitScroll.bar
        bar:HookScript("OnValueChanged", function() spec.onScroll(scroll) end)
    end
    return scroll
end

function Widgets.ScrollSize(scroll, width, height)
    if not width or not height or width <= 0 or height <= 0 then return end
    if scroll.spec.width ~= width or scroll.spec.height ~= height then
        scroll.spec.width, scroll.spec.height = width, height
        scroll:SetWidth(width)
        scroll:Layout()
    end
    local content, view = scroll._content, scroll.kitScroll.child:GetWidth()
    if content.spec.width ~= view then
        content.spec.width = view
        content:SetWidth(view)
        scroll:Layout()
    end
end

function Widgets.ScrollHeight(scroll, height)
    local content = scroll._content
    height = math.max(1, height)
    if content.spec.height == height then return end
    content.spec.height = height
    content:SetHeight(height)
    scroll:Layout()
end

function Widgets.ScrollWidth(scroll, width)
    local content = scroll._content
    width = math.max(1, width)
    if content.spec.width == width then return end
    content.spec.width = width
    content:SetWidth(width)
    scroll:Layout()
end

function Widgets.ScrollOffset(scroll, across)
    local kit = scroll.kitScroll
    if across then return kit:HorizontalOffset() end
    return kit:Offset()
end

function Widgets.ScrollTo(scroll, value, across)
    local kit = scroll.kitScroll
    if across then kit:SetHorizontalOffset(value or 0) else kit:SetOffset(value or 0) end
end

function Widgets.ScrollView(scroll, across)
    local kit = scroll.kitScroll
    if across then return kit.viewWidth end
    return kit:GetHeight()
end

function Widgets.Page(container, spec)
    spec = spec or {}
    spec.layout = spec.layout or "VERTICAL"
    local inset = (container.spec.padding or 0) * 2
    spec.width  = spec.width or (container.spec.width - inset)
    spec.height = spec.height or (container.spec.height - inset)
    local page = container:Add("bar", spec)
    page:Hide()
    container:Layout()
    return page
end

function Widgets.ShowPage(page)
    local host = page.kitHost
    for _, child in ipairs(host.children) do
        if child ~= page then child:Hide() end
    end
    page:Show()
    host:Layout()
end

function Widgets.Rest(container, skip)
    local spacing, used = container.spec.spacing or 0, 0
    for _, child in ipairs(container.children) do
        if child ~= skip and child:IsShown() then used = used + child:GetHeight() + spacing end
    end
    return container.spec.height - (container.spec.padding or 0) * 2 - used
end

function Widgets.Gap(parent, width, height)
    return parent:Add("bar", { width = width, height = height })
end

function Widgets.Column(parent, width)
    local column = parent:Add("bar", { layout = "VERTICAL", spacing = 0, width = width })
    column._lead = Widgets.Gap(column, 1, 1)
    return column
end

function Widgets.Lead(column, height)
    local lead = column._lead
    lead.spec.height = math.max(1, height)
    lead:SetHeight(lead.spec.height)
    column:Layout()
end

function Widgets.Centered(parent, total, width)
    local row = parent:Add("bar", { spacing = 0 })
    Widgets.Gap(row, math.floor((total - width) / 2), 1)
    return row
end

function Widgets.FormatScore(v)
    v = v or 0
    if v > -10 and v < 10 then return string.format("%.2f", v) end
    return string.format("%.0f", v)
end
