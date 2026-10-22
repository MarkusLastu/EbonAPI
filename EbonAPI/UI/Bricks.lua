EbonAPI = EbonAPI or {}
EbonAPI.Bricks = {}

local Bricks = EbonAPI.Bricks
local Catalog = EbonAPI.Catalog
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Parameters = EbonAPI.Parameters
local Lib = EbonAPI.Lib
local L = EbonAPI.L

local pairs, ipairs, tostring, tonumber, type, pcall, setmetatable = pairs, ipairs, tostring, tonumber, type,
  pcall, setmetatable
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local format, gsub, find = string.format, string.gsub, string.find
local remove = table.remove

local S = Skins.value
local paint = Palette.paint
local THEME = Palette.THEME
local WEAK = { __mode = "k" }
local AUTO_LIGHT = 0.179

local CONTRACT = {
  button = { "SetLabel", "SetSelected", "SetDisabledState", "TextWidth", "Fit" },
  tab = { "SetLabel", "SetSelected", "SetDisabledState", "TextWidth", "SetPadding", "Fit" },
  execute = { "SetLabel", "SetSelected", "SetDisabledState", "TextWidth", "Fit" },
  row = { "SetLabel", "SetSelected", "SetDisabledState", "TextWidth", "SetTextKey" },
  close = { "SetLabel", "SetSelected", "SetDisabledState", "TextWidth" },
  section = { "SetLabel" },
  toggle = { "SetLabel", "SetValue", "SetDisabledState", "TextWidth" },
  range = { "SetTitle", "SetRange", "SetValue", "SetDisabledState", "SetFormat" },
  select = { "SetTitle", "SetItems", "SetValue", "SetDisabledState" },
  color = { "SetLabel", "SetColor", "SetDisabledState", "TextWidth" },
  input = { "SetTitle", "SetLines", "SetValue", "SetDisabledState" },
  heading = { "SetLabel" },
  text = { "SetContent" },
  group = { "SetLabel", "SetInnerHeight" },
  scroll = {
    "SetMode", "SetView", "SetContentHeight", "SetContentWidth", "Offset", "SetOffset", "HorizontalOffset",
    "SetHorizontalOffset", "Wheel",
  },
  minimap = {},
  card = { "Dress", "Undress", "SetState", "SetBadge", "SetRound", "SetInset" },
  cardHeader = { "Dress", "Undress", "SetInset" },
}

local FIELDS = {
  button = { "label" },
  tab = { "label" },
  execute = { "label" },
  row = { "label" },
  close = { "label" },
  group = { "box" },
  scroll = { "child", "bar", "hbar" },
  minimap = { "icon" },
}

local ROLES = { small = "small", medium = "normal", large = "large" }
local GROUP_FRAMES = { LARGE = "large", SMALL = "small", FLAT = "flat" }

Bricks.CONTRACT = CONTRACT
Bricks.value = S
Bricks.paint = paint
Bricks.unpaint = Palette.unpaint

local framed = setmetatable({}, WEAK)
local shadows = setmetatable({}, WEAK)
local roots = setmetatable({}, WEAK)
local buttons = setmetatable({}, WEAK)
local decorated = setmetatable({}, WEAK)
local levelled = setmetatable({}, WEAK)
local registry = {}
local broken = {}

local function applyLevel(child)
  local rule = levelled[child]

  child:SetFrameLevel(max(0, rule.anchor:GetFrameLevel() + S(rule.key)))
end

function Bricks.level(child, anchor, key)
  levelled[child] = { anchor = anchor, key = key }
  applyLevel(child)
end

function Bricks.relevel()
  for child in pairs(levelled) do
    applyLevel(child)
  end
end

function Bricks.media(key)
  return S("media." .. key)
end

local function flags(outline)
  if outline == "NONE" or outline == "AUTO" then
    return ""
  end

  return outline
end

function Bricks.font(target, role, outline)
  local file = S("fonts." .. role .. ".file")

  if file == "game" then
    file = STANDARD_TEXT_FONT
  end

  target:SetFont(file, S("fonts." .. role .. ".size"), flags(outline or S("fonts." .. role .. ".outline")))

  if target.SetShadowOffset then
    local r, g, b = Palette.unpackColor(S("fonts.shadow.color"))

    target:SetShadowOffset(S("fonts.shadow.x"), S("fonts.shadow.y"))
    target:SetShadowColor(r, g, b, S("fonts.shadow.alpha"))
  end
end

function Bricks.text(parent, role, key)
  local text = parent:CreateFontString(nil, "OVERLAY")

  Bricks.font(text, role or "normal")
  paint(text, "SetTextColor", key or "text")

  return text
end

function Bricks.label(text, upperKey)
  if upperKey and S(upperKey) then
    return Lib.upper(text or "")
  end

  return text or ""
end

function Bricks.sound(key)
  local sound = S(key)

  if sound == "" then
    return
  end

  if find(sound, ".", 1, true) then
    if PlaySoundFile then
      PlaySoundFile(sound)
    end
  elseif PlaySound then
    PlaySound(sound)
  end
end

local flat = nil
local rounded = {}
local textured = {}

local function texturedFor(style)
  local size = style == "small" and "small" or "large"
  local backdrop = textured[size]

  if not backdrop then
    local prefix = "border." .. size .. "."
    local background, edge = S(prefix .. "background"), S(prefix .. "edge")
    local tile, inset = S(prefix .. "tile"), S(prefix .. "inset")

    backdrop = {
      bgFile = background ~= "" and background or nil,
      edgeFile = edge ~= "" and edge or nil,
      edgeSize = S(prefix .. "size"),
      tile = tile > 0,
      tileSize = tile > 0 and tile or nil,
      insets = { left = inset, right = inset, top = inset, bottom = inset },
    }
    textured[size] = backdrop
  end

  return backdrop
end

local function backdropFor(style)
  if style ~= "flat" and S("border.style") == "TEXTURE" then
    return texturedFor(style)
  end

  local corners = Parameters.value(nil, "corners")

  if style == "flat" or corners <= 0 then
    if not flat then
      local solid = Bricks.media("solid")

      flat = { bgFile = solid, edgeFile = solid, edgeSize = S("border.size") }
    end

    return flat
  end

  local edge = S("border.round.base") + corners

  if style == "small" then
    edge = min(edge, S("border.round.small"))
  end

  local backdrop = rounded[edge]

  if not backdrop then
    local inset = floor(edge * S("border.round.inset"))

    backdrop = {
      bgFile = Bricks.media("solid"), edgeFile = Bricks.media("rounded"), edgeSize = edge,
      insets = { left = inset, right = inset, top = inset, bottom = inset },
    }
    rounded[edge] = backdrop
  end

  return backdrop
end

function Bricks.frame(target, style, bgKey, borderKey)
  framed[target] = style or "large"
  target:SetBackdrop(backdropFor(framed[target]))
  paint(target, "SetBackdropColor", bgKey or "bg")
  paint(target, "SetBackdropBorderColor", borderKey or "border")

  return target
end

function Bricks.unframe(target)
  framed[target] = nil
  Palette.unpaint(target, "SetBackdropColor")
  Palette.unpaint(target, "SetBackdropBorderColor")
  target:SetBackdrop(nil)

  return target
end

local function insetOf(target)
  local insets = backdropFor(framed[target] or "flat").insets

  return insets and insets.left or 0
end

Bricks.insetOf = insetOf

local glows = {}

local function glowFor(size)
  local backdrop = glows[size]

  if not backdrop then
    backdrop = { edgeFile = Bricks.media("shadow"), edgeSize = size }
    glows[size] = backdrop
  end

  return backdrop
end

local function layoutShadow(holder)
  local target = shadows[holder]
  local amount = Parameters.value(nil, "shadow")

  if amount <= 0 then
    holder:Hide()
    return
  end

  local size = floor(S("window.shadow.base") + S("window.shadow.spread") * amount)
  local outside = size - insetOf(target)
  local x, y = S("window.shadow.x"), S("window.shadow.y")
  local color = THEME.shadow

  holder:ClearAllPoints()
  holder:SetPoint("TOPLEFT", target, "TOPLEFT", x - outside, y + outside)
  holder:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", x + outside, y - outside)
  Bricks.level(holder, target, "window.shadow.level")
  holder:SetBackdrop(glowFor(size))
  holder:SetBackdropBorderColor(color[1], color[2], color[3],
    S("window.shadow.alphaBase") + S("window.shadow.alphaSpread") * amount)
  holder:Show()
end

function Bricks.shadow(target)
  local holder = CreateFrame("Frame", nil, target)

  shadows[holder] = target
  layoutShadow(holder)
  target:HookScript("OnShow", function()
    layoutShadow(holder)
  end)

  return holder
end

local function fill(frame, texture, inset)
  texture:ClearAllPoints()
  texture:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
  texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
end

local function layoutDecor(frame)
  local decor = decorated[frame]

  if not decor then
    return
  end

  local inset = insetOf(frame)

  for _, texture in ipairs(decor.fills) do
    fill(frame, texture, inset)
  end

  if decor.gradient then
    local color = THEME[S("window.gradient.color")]

    decor.gradient:SetGradientAlpha(S("window.gradient.orientation"), color[1], color[2], color[3],
      S("window.gradient.from"), color[1], color[2], color[3], S("window.gradient.to"))
  end

  if decor.sheen then
    decor.sheen:ClearAllPoints()
    decor.sheen:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    decor.sheen:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
    decor.sheen:SetHeight(max(1, ((frame:GetHeight() or 0) - inset * 2) * S("window.glass.sheenHeight")))
  end

  if decor.edges then
    local top, bottom, left, right = decor.edges[1], decor.edges[2], decor.edges[3], decor.edges[4]
    local thickness = S("window.glass.edgeSize")

    for _, edge in ipairs(decor.edges) do
      edge:ClearAllPoints()
    end

    top:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
    top:SetHeight(thickness)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    bottom:SetHeight(thickness)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
    left:SetWidth(thickness)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    right:SetWidth(thickness)
  end
end

local function layer(frame, drawLayer, texture, blend)
  local region = frame:CreateTexture(nil, drawLayer)

  region:SetTexture(texture)

  if blend then
    region:SetBlendMode(blend)
  end

  return region
end

local function decorate(frame)
  local decor = { fills = {} }
  local solid = Bricks.media("solid")
  local image = S("window.texture")

  if image ~= "" then
    decor.image = layer(frame, "BORDER", image)
    decor.image:SetAlpha(S("window.textureAlpha"))
    decor.fills[#decor.fills + 1] = decor.image
  end

  local orientation = S("window.gradient.orientation")

  if orientation ~= "NONE" then
    decor.gradient = layer(frame, "ARTWORK", solid)
    decor.fills[#decor.fills + 1] = decor.gradient
  end

  if S("window.glass.enabled") then
    local tr, tg, tb = Palette.unpackColor(S("window.glass.tint"))
    local keep = 1 - S("window.glass.darken")
    local milk = S("window.glass.milk")
    local edge = S("window.glass.edge")

    decor.tint = layer(frame, "BACKGROUND", solid, "MOD")
    decor.tint:SetVertexColor(tr * keep, tg * keep, tb * keep, 1)
    decor.milk = layer(frame, "BORDER", solid, "ADD")
    decor.milk:SetVertexColor(milk, milk, milk, 1)
    decor.grain = layer(frame, "ARTWORK", Bricks.media("grain"), "BLEND")
    decor.grain:SetVertexColor(1, 1, 1, S("window.glass.grain"))
    decor.fills[#decor.fills + 1] = decor.tint
    decor.fills[#decor.fills + 1] = decor.milk
    decor.fills[#decor.fills + 1] = decor.grain
    decor.sheen = layer(frame, "ARTWORK", solid, "ADD")
    decor.sheen:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, S("window.glass.sheen"))
    decor.edges = {}

    for index = 1, 4 do
      decor.edges[index] = layer(frame, "ARTWORK", solid, "ADD")
      decor.edges[index]:SetVertexColor(1, 1, 1, edge)
    end
  end

  decorated[frame] = decor
  layoutDecor(frame)

  return decor
end

function Bricks.decor(frame)
  return decorated[frame]
end

function Bricks.apply()
  Palette.derive(Parameters.value(nil, "background"), Parameters.value(nil, "accent"),
    Parameters.value(nil, "opacity"))

  for target, style in pairs(framed) do
    target:SetBackdrop(backdropFor(style))
  end

  Palette.repaint()

  if EbonAPI.AddonList then
    EbonAPI.AddonList.refresh()
  end

  for button in pairs(buttons) do
    button:Visual()
  end

  for holder in pairs(shadows) do
    layoutShadow(holder)
  end

  Bricks.relevel()

  for frame in pairs(decorated) do
    layoutDecor(frame)
  end

  local scale = Parameters.value(nil, "scale")

  for root in pairs(roots) do
    root:SetScale(scale)
  end
end

function Bricks.tip(owner, title, body)
  if not GameTooltip or (not title and not body) then
    return
  end

  local heading, text = THEME.heading, THEME.text

  GameTooltip:SetOwner(owner, S("widgets.tooltip.anchor"))

  if S("widgets.tooltip.skinned") and GameTooltip.SetBackdropColor then
    local bg, border = THEME.bg, THEME.border

    GameTooltip:SetBackdropColor(bg[1], bg[2], bg[3], 1)
    GameTooltip:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
  end

  if title and title ~= "" then
    GameTooltip:AddLine(title, heading[1], heading[2], heading[3])
  end

  if body then
    GameTooltip:AddLine(body, text[1], text[2], text[3], true)
  end

  GameTooltip:Show()
end

local function hideTip()
  if GameTooltip then
    GameTooltip:Hide()
  end
end

local function enterTip(self)
  Bricks.tip(self, self.tipTitle, self.tipBody)
end

Bricks.hideTip = hideTip
Bricks.enterTip = enterTip

function Bricks.register(slot, name, build)
  registry[slot] = registry[slot] or {}
  registry[slot][name] = build
end

function Bricks.registered(slot, name)
  return (Skins.brick(slot, name) or (registry[slot] and registry[slot][name])) ~= nil
end

local function breach(widget, slot)
  if type(widget) ~= "table" then
    return "the constructor returned " .. type(widget)
  end

  for _, method in ipairs(CONTRACT[slot]) do
    if type(widget[method]) ~= "function" then
      return 'the method "' .. method .. '" is missing'
    end
  end

  for _, field in ipairs(FIELDS[slot] or {}) do
    if widget[field] == nil then
      return 'the field "' .. field .. '" is missing'
    end
  end

  return nil
end

function Bricks.create(slot, parent)
  local key = Catalog.slotKey(slot)
  local name = S(key)
  local mark = slot .. "." .. name

  if not broken[mark] then
    local build = Skins.brick(slot, name) or (registry[slot] and registry[slot][name])

    if build then
      local ok, widget = pcall(build, parent, Bricks)
      local problem

      if ok then
        problem = breach(widget, slot)
      else
        problem = tostring(widget)
      end

      if not problem then
        return widget
      end

      broken[mark] = true
      Lib.report(format('EbonAPI: brick "%s" of slot "%s" failed, the default one applies: %s', name, slot, problem))
    else
      broken[mark] = true
      Lib.report(format('EbonAPI: brick "%s" of slot "%s" is not registered, the default one applies', name, slot))
    end
  end

  local fallback = Skins.default(key)

  return (Skins.defaultBrick(slot, fallback) or registry[slot][fallback])(parent, Bricks)
end

function Bricks.build(slot, name, parent)
  local build = registry[slot] and registry[slot][name]

  if not build then
    error('EbonAPI: Bricks.build: no built-in brick "' .. tostring(name) .. '" for slot "' .. tostring(slot) .. '"', 2)
  end

  return build(parent, Bricks)
end

function Bricks.pool(create)
  local pool = { free = {}, used = {} }

  function pool:acquire(parent)
    local widget = remove(self.free) or create(parent)

    widget:SetParent(parent)
    widget:ClearAllPoints()
    widget:SetAlpha(1)
    widget:Show()
    widget.tipTitle, widget.tipBody = nil, nil
    self.used[#self.used + 1] = widget

    return widget
  end

  function pool:releaseAll()
    for index = #self.used, 1, -1 do
      local widget = self.used[index]

      widget:Hide()
      widget:ClearAllPoints()
      self.used[index] = nil
      self.free[#self.free + 1] = widget
    end
  end

  function pool:count()
    return #self.used
  end

  return pool
end

function Bricks.slotPool(slot)
  return Bricks.pool(function(parent)
    return Bricks.create(slot, parent)
  end)
end

local function labelFont(button, textKey)
  local role = button.role or "button"
  local outline = S("fonts." .. role .. ".outline")

  if outline == "AUTO" then
    outline = Palette.lightness(THEME[textKey]) > AUTO_LIGHT and "OUTLINE" or ""
  else
    outline = flags(outline)
  end

  if button.outline ~= outline then
    button.outline = outline
    Bricks.font(button.label, role, outline)
  end
end

Bricks.labelFont = labelFont

local function fillVisual(button)
  local bg, border, text = "button", "buttonBorder", button.textKey or "buttonText"

  if button.selectedState then
    bg, border, text = "selected", "selected", "selectedText"
  elseif button.disabledState then
    border, text = "buttonDisabledBorder", "buttonDisabledText"
  elseif button.hovered then
    bg, border = "buttonHoverFill", "buttonHover"
  elseif button.toneBg then
    bg, border = button.toneBg, button.toneBorder or button.toneBg
  end

  paint(button, "SetBackdropColor", bg)
  paint(button, "SetBackdropBorderColor", border)
  paint(button.label, "SetTextColor", text)
  labelFont(button, text)

  if button.arrow then
    paint(button.arrow, "SetVertexColor", text)
  end
end

local function lineVisual(button)
  local text = button.textKey or "text"

  if button.selectedState then
    text = "heading"
  elseif button.disabledState then
    text = "muted"
  elseif button.hovered then
    text = "buttonHover"
  end

  paint(button.label, "SetTextColor", text)
  labelFont(button, text)

  if button.bar then
    Lib.setShown(button.bar, button.selectedState)
  end

  if button.arrow then
    paint(button.arrow, "SetVertexColor", text)
  end
end

local function listVisual(button)
  local fill, text = nil, button.textKey or "text"

  if button.selectedState then
    fill, text = "selected", "selectedText"
  elseif button.disabledState then
    text = "muted"
  elseif button.hovered then
    fill = "rowHover"
  end

  if fill then
    paint(button, "SetBackdropColor", fill)
  else
    Palette.unpaint(button, "SetBackdropColor")
    button:SetBackdropColor(0, 0, 0, 0)
  end

  button:SetBackdropBorderColor(0, 0, 0, 0)
  paint(button.label, "SetTextColor", text)
  labelFont(button, text)

  if button.arrow then
    paint(button.arrow, "SetVertexColor", text)
  end
end

local function flatVisual(button)
  local text = button.textKey or "text"

  if button.disabledState then
    text = "muted"
  elseif button.hovered then
    text = "buttonText"
  end

  if button.hover then
    Lib.setShown(button.hover, button.hovered and not button.disabledState)
  end

  paint(button.label, "SetTextColor", text)
  labelFont(button, text)
end

local function anchorLabel(button, bounded)
  local label, left, right = button.label, button.insetLeft, button.insetRight

  label:ClearAllPoints()

  if bounded then
    label:SetPoint("LEFT", button, "LEFT", left, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -right, 0)
    return
  end

  local justify = label:GetJustifyH()

  if justify == "LEFT" then
    label:SetPoint("LEFT", button, "LEFT", left, 0)
  elseif justify == "RIGHT" then
    label:SetPoint("RIGHT", button, "RIGHT", -right, 0)
  else
    label:SetPoint("CENTER", button, "CENTER", (left - right) / 2, 0)
  end
end

local function baseButton(parent, visual, template, name)
  local button = CreateFrame("Button", name, parent, template)
  local label = button:CreateFontString(nil, "OVERLAY")

  button:SetHeight(S("widgets.button.height"))
  label:SetJustifyH("CENTER")
  button.label = label
  button.lead = 0
  button.Visual = visual

  function button:SetPadding(padding)
    self.insetLeft, self.insetRight = self.lead + padding, padding
    anchorLabel(self, true)
  end

  -- Optional tone (palette names for fill and border) worn while the button is idle; no arguments clear it.
  -- Each brick's visual shows it in its own way.
  function button:SetTone(bg, border)
    self.toneBg, self.toneBorder = bg, border
    self:Visual()
  end

  function button:Fit(width)
    local natural = self:TextWidth()

    width = width or natural
    self:SetWidth(width)
    anchorLabel(self, width < natural)

    return width
  end

  button:SetPadding(S("widgets.button.padding"))

  button:SetScript("OnEnter", function(self)
    self.hovered = true
    self:Visual()
    enterTip(self)

    if self.onEnter then
      self:onEnter()
    end
  end)
  button:SetScript("OnLeave", function(self)
    self.hovered = false
    self:Visual()
    hideTip()

    if self.onLeave then
      self:onLeave()
    end
  end)
  button:SetScript(template and "PostClick" or "OnClick", function(self, mouse)
    if not self.disabledState and self.onClick then
      self.onClick(self, mouse)
    end
  end)

  function button:SetLabel(text)
    self.label:SetText(text or "")
  end

  function button:SetSelected(selected)
    self.selectedState = selected and true or false
    self:Visual()
  end

  function button:SetDisabledState(disabled)
    self.disabledState = disabled and true or false
    self:Visual()
  end

  function button:SetTextKey(key)
    self.textKey = key
    self:Visual()
  end

  function button:TextWidth()
    return ceil(self.label:GetStringWidth() or 0) + self.insetLeft + self.insetRight
  end

  buttons[button] = true

  return button
end

Bricks.baseButton = baseButton

local function fillButton(parent)
  local button = baseButton(parent, fillVisual)

  Bricks.frame(button, "small", "button", "buttonBorder")
  button:Visual()

  return button
end

-- The skin's own button brick for a secure button, when that brick takes the template and the name (it then
-- marks its widget secureOk). Without it the secure button wears the flat dressed look.
function Bricks.createSecure(slot, parent, template, name)
  local build = Skins.brick(slot, S(Catalog.slotKey(slot)))

  if not build then
    return nil
  end

  local ok, widget = pcall(build, parent, Bricks, template, name)

  if ok and type(widget) == "table" and widget.secureOk and not breach(widget, slot) then
    return widget
  end

  if ok and type(widget) == "table" and widget.Hide then
    widget:Hide()
  end

  return nil
end

function Bricks.dressedButton(parent, template, name)
  local native = template and Bricks.createSecure("button", parent, template, name)

  if native then
    native:Visual()

    return native
  end

  local button = baseButton(parent, fillVisual, template, name)

  Bricks.frame(button, "small", "button", "buttonBorder")
  button:Visual()

  return button
end

local function listButton(parent, role, padding, align)
  local button = baseButton(parent, listVisual)

  Bricks.frame(button, "small", "button", "buttonBorder")
  Palette.unpaint(button, "SetBackdropColor")
  Palette.unpaint(button, "SetBackdropBorderColor")
  button.role = role
  button.label:SetJustifyH(align)
  button:SetPadding(padding)
  button:Visual()

  return button
end

local function tabButton(parent, visual, bar)
  local button = baseButton(parent, visual)

  button.role = S("nav.tab.font")

  if visual == fillVisual then
    Bricks.frame(button, "small", "button", "buttonBorder")
  end

  if bar then
    local width = S("nav.tab.bar")

    button.lead = width
    button.bar = button:CreateTexture(nil, "ARTWORK")
    button.bar:SetTexture(Bricks.media("solid"))
    button.bar:SetWidth(width)
    button.bar:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    paint(button.bar, "SetVertexColor", "checked")
  end

  button.label:SetJustifyH(S("nav.tab.align"))
  button:SetPadding(S("nav.tab.padding"))
  button:Visual()

  return button
end

local function centered(button)
  button:SetPadding(0)
  anchorLabel(button, false)

  return button
end

Bricks.register("button", "default", fillButton)
Bricks.register("execute", "default", fillButton)
Bricks.register("row", "fill", function(parent)
  local button = fillButton(parent)

  button:SetPadding(S("widgets.menu.inset"))

  return button
end)

Bricks.register("row", "list", function(parent)
  return listButton(parent, "button", S("widgets.menu.inset"), "LEFT")
end)

Bricks.register("tab", "fill", function(parent)
  return tabButton(parent, fillVisual, false)
end)

Bricks.register("tab", "bar", function(parent)
  return tabButton(parent, lineVisual, true)
end)

Bricks.register("tab", "text", function(parent)
  return tabButton(parent, lineVisual, false)
end)

Bricks.register("tab", "list", function(parent)
  return listButton(parent, S("nav.tab.font"), S("nav.tab.padding"), S("nav.tab.align"))
end)

Bricks.register("close", "default", function(parent)
  return centered(fillButton(parent))
end)

Bricks.register("close", "flat", function(parent)
  local button = centered(baseButton(parent, flatVisual))
  local hover = button:CreateTexture(nil, "BACKGROUND")
  local r, g, b = Palette.unpackColor(S("header.close.hover"))

  hover:SetTexture(Bricks.media("solid"))
  hover:SetAllPoints(button)
  hover:SetVertexColor(r, g, b, 1)
  hover:Hide()
  button.hover = hover
  button:Visual()

  return button
end)

function Bricks.flatButton(parent)
  local button = centered(baseButton(parent, flatVisual))
  local hover = button:CreateTexture(nil, "BACKGROUND")

  hover:SetTexture(Bricks.media("solid"))
  hover:SetAllPoints(button)
  paint(hover, "SetVertexColor", "rowHover")
  hover:Hide()
  button.hover = hover
  button:Visual()

  return button
end

local TURNS = {
  RIGHT = { 0, 0, 0, 1, 1, 0, 1, 1 },
  DOWN = { 0, 1, 1, 1, 0, 0, 1, 0 },
  LEFT = { 1, 1, 1, 0, 0, 1, 0, 0 },
  UP = { 1, 0, 0, 0, 1, 1, 0, 1 },
}

function Bricks.turn(texture, direction)
  if direction == true then
    direction = "DOWN"
  elseif not direction then
    direction = "RIGHT"
  end

  local turn = TURNS[direction]

  texture:SetTexCoord(turn[1], turn[2], turn[3], turn[4], turn[5], turn[6], turn[7], turn[8])
end

Bricks.register("section", "default", function(parent)
  local section = CreateFrame("Frame", nil, parent)

  section:SetHeight(S("nav.section.height"))
  section.text = Bricks.text(section, S("nav.section.font"), S("nav.section.color"))
  section.text:SetPoint("LEFT", section, "LEFT", 0, 0)

  function section:SetLabel(text)
    self.text:SetText(Bricks.label(text, "nav.section.upper"))
  end

  return section
end)

local function toggleRow(parent, build)
  local row = CreateFrame("Button", nil, parent)
  local gap = S("widgets.toggle.gap")

  row:SetHeight(S("widgets.toggle.height"))

  local control, width = build(row)
  local label = Bricks.text(row, "normal")

  label:SetPoint("LEFT", control, "RIGHT", gap, 0)
  label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  label:SetJustifyH("LEFT")

  row.box, row.label = control, label

  row:SetScript("OnEnter", function(self)
    self.hovered = true
    self:Visual()
    enterTip(self)
  end)
  row:SetScript("OnLeave", function(self)
    self.hovered = false
    self:Visual()
    hideTip()
  end)
  row:SetScript("OnClick", function(self)
    if self.disabledState then
      return
    end

    self:SetValue(not self.value)

    if self.onToggle then
      self.onToggle(self.value)
    end
  end)

  function row:SetValue(value)
    self.value = value and true or false
    self:Visual()
  end

  function row:SetLabel(text)
    self.label:SetText(text or "")
  end

  function row:SetDisabledState(disabled)
    self.disabledState = disabled and true or false
    self:SetAlpha(self.disabledState and S("widgets.disabledAlpha") or 1)
    self:Visual()
  end

  function row:TextWidth()
    return ceil(self.label:GetStringWidth() or 0) + width + gap + S("widgets.toggle.margin")
  end

  return row
end

Bricks.toggleRow = toggleRow

Bricks.register("toggle", "box", function(parent)
  local row = toggleRow(parent, function(owner)
    local size = S("widgets.toggle.size")
    local inset = S("widgets.toggle.mark")
    local box = CreateFrame("Frame", nil, owner)
    local mark = box:CreateTexture(nil, "OVERLAY")

    local texture = S("widgets.toggle.markTexture")

    box:SetWidth(size)
    box:SetHeight(size)
    box:SetPoint("LEFT", owner, "LEFT", 0, 0)
    Bricks.frame(box, "flat", "checkbox", "checkboxBorder")

    if texture ~= "" then
      mark:SetTexture(texture)
      mark:SetDesaturated(true)
    else
      mark:SetTexture(Bricks.media("solid"))
    end

    mark:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
    mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
    paint(mark, "SetVertexColor", "checked")
    owner.mark = mark

    return box, size
  end)

  function row:Visual()
    paint(self.box, "SetBackdropBorderColor", self.hovered and not self.disabledState and "buttonHover" or "checkboxBorder")

    Lib.setShown(self.mark, self.value)
  end

  row:SetValue(false)

  return row
end)

Bricks.register("toggle", "switch", function(parent)
  local width, height = S("widgets.toggle.switch.width"), S("widgets.toggle.switch.height")
  local inset = S("widgets.toggle.mark")
  local row = toggleRow(parent, function(owner)
    local track = CreateFrame("Frame", nil, owner)
    local knob = track:CreateTexture(nil, "OVERLAY")

    track:SetWidth(width)
    track:SetHeight(height)
    track:SetPoint("LEFT", owner, "LEFT", 0, 0)
    Bricks.frame(track, "small", "checkbox", "checkboxBorder")
    knob:SetTexture(S("widgets.toggle.roundKnob") and Bricks.media("circle") or Bricks.media("solid"))
    knob:SetWidth(max(1, height - inset * 2))
    knob:SetHeight(max(1, height - inset * 2))
    owner.mark = knob

    return track, width
  end)

  row.switch = true

  function row:Visual()
    local border = self.value and "checked" or "checkboxBorder"

    if self.hovered and not self.disabledState then
      border = "buttonHover"
    end

    self.mark:ClearAllPoints()

    if self.value then
      self.mark:SetPoint("RIGHT", self.box, "RIGHT", -inset, 0)
      paint(self.mark, "SetVertexColor", "checkbox")
      paint(self.box, "SetBackdropColor", "checked")
    else
      self.mark:SetPoint("LEFT", self.box, "LEFT", inset, 0)
      paint(self.mark, "SetVertexColor", "thumb")
      paint(self.box, "SetBackdropColor", "checkbox")
    end

    paint(self.box, "SetBackdropBorderColor", border)
  end

  row:SetValue(false)

  return row
end)

local function trimNumber(value)
  local text = format("%.6f", value)

  text = gsub(text, "0+$", "")
  text = gsub(text, "%.$", "")

  return (gsub(text, "%.", L.NUMBER_DECIMAL))
end

local function readNumber(text)
  text = gsub(text or "", "[%%%s\194\160]", "")

  return tonumber((gsub(text, ",", ".")))
end

local function roundTo(value, low, step)
  if step and step > 0 then
    value = low + floor((value - low) / step + 0.5) * step
  end

  return tonumber(format("%.6f", value))
end

local function flatRange(slider)
  local solid = Bricks.media("solid")
  local track = slider:CreateTexture(nil, "BACKGROUND")

  track:SetTexture(solid)
  track:SetHeight(S("widgets.range.track"))
  track:SetPoint("LEFT", slider, "LEFT", 0, 0)
  track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  paint(track, "SetVertexColor", "borderDim")

  local filled = nil

  if S("widgets.range.fill") then
    filled = slider:CreateTexture(nil, "BORDER")
    filled:SetTexture(solid)
    filled:SetHeight(S("widgets.range.track"))
    filled:SetPoint("LEFT", slider, "LEFT", 0, 0)
    paint(filled, "SetVertexColor", S("widgets.range.fillColor"))
  end

  slider:SetThumbTexture(S("widgets.range.roundThumb") and Bricks.media("circle") or solid)

  local thumb = slider:GetThumbTexture()

  if thumb then
    paint(thumb, "SetVertexColor", "thumb")
  end

  return {
    track = track,
    fill = filled,
    hover = function(over)
      if thumb then
        paint(thumb, "SetVertexColor", over and "buttonHover" or "thumb")
      end
    end,
  }
end

local function rangeBox(parent, dress)
  local box = CreateFrame("Frame", nil, parent)

  box:SetHeight(S("widgets.range.height"))

  local title = Bricks.text(box, "small", "heading")

  title:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  title:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
  title:SetJustifyH("CENTER")

  local top = S("widgets.range.top")
  local slider = CreateFrame("Slider", nil, box)

  slider:SetOrientation("HORIZONTAL")
  slider:SetHeight(S("widgets.range.bar"))
  slider:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -top)
  slider:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -top)
  slider:EnableMouse(true)

  local art = dress(slider)
  local filled = art.fill
  local thumb = slider:GetThumbTexture()

  if thumb then
    thumb:SetWidth(S("widgets.range.thumb.width"))
    thumb:SetHeight(S("widgets.range.thumb.height"))
  end

  local low = Bricks.text(box, "small", "muted")
  local high = Bricks.text(box, "small", "muted")
  local labels = S("widgets.range.labels")

  low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -labels)
  high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -labels)

  local edit = CreateFrame("EditBox", nil, box)

  edit:SetWidth(S("widgets.range.edit.width"))
  edit:SetHeight(S("widgets.range.edit.height"))
  edit:SetPoint("TOP", slider, "BOTTOM", 0, -S("widgets.range.edit.y"))
  edit:SetAutoFocus(false)
  Bricks.font(edit, "small")
  edit:SetJustifyH("CENTER")
  Bricks.frame(edit, "flat", "bgSoft", "borderDim")
  paint(edit, "SetTextColor", "text")

  box.title, box.slider, box.edit, box.low, box.high, box.fill = title, slider, edit, low, high, filled
  box.track = art.track
  box.min, box.max, box.step = 0, 1, 0.01

  local function show(value)
    if box.formatter then
      local ok, text = pcall(box.formatter, value)

      if ok and text ~= nil then
        return tostring(text)
      end

      if not ok and not box.formatFailed then
        box.formatFailed = true
        Lib.report(format("EbonAPI: range formatter failed: %s", tostring(text)))
      end
    end

    if box.percent then
      return format(L.NUMBER_PERCENT, floor(value * 100 + 0.5))
    end

    return trimNumber(value)
  end

  local function showFill(value)
    if not filled then
      return
    end

    local span = box.max - box.min
    local share = span > 0 and (value - box.min) / span or 0
    local width = (box:GetWidth() or 0) * max(0, min(1, share))

    if width < 1 then
      filled:Hide()
    else
      filled:SetWidth(width)
      filled:Show()
    end
  end

  local function fit(value)
    return max(box.min, min(box.max, roundTo(value, box.min, box.step)))
  end

  local function refresh()
    local value = box.value or box.min

    box.syncing = true
    slider:SetValue(value)
    box.syncing = false
    edit:SetText(show(value))
    showFill(value)
  end

  local function commit(value)
    if box.disabledState then
      refresh()

      return
    end

    value = fit(value)
    edit:SetText(show(value))
    showFill(value)

    if value ~= box.value then
      box.value = value

      if box.onCommit then
        box.onCommit(value)
      end
    end
  end

  slider:SetScript("OnValueChanged", function(_, value)
    if box.syncing then
      return
    end

    edit:SetText(show(fit(value)))
    showFill(value)

    if not box.dragging then
      commit(value)
    end
  end)
  slider:SetScript("OnMouseDown", function()
    box.dragging = true
  end)
  slider:SetScript("OnMouseUp", function(self)
    box.dragging = false
    commit(self:GetValue())
  end)
  slider:SetScript("OnEnter", function()
    if art.hover then
      art.hover(true)
    end

    enterTip(box)
  end)
  slider:SetScript("OnLeave", function()
    if art.hover then
      art.hover(false)
    end

    hideTip()
  end)

  edit:SetScript("OnEnterPressed", function(self)
    local number = readNumber(self:GetText())

    if number then
      if box.percent then
        number = number / 100
      end

      box.syncing = true
      box.slider:SetValue(max(box.min, min(box.max, number)))
      box.syncing = false
      commit(number)
    else
      self:SetText(show(box.value or box.min))
    end

    self:ClearFocus()
  end)
  edit:SetScript("OnEscapePressed", function(self)
    self:SetText(show(box.value or box.min))
    self:ClearFocus()
  end)

  function box:SetTitle(text)
    self.title:SetText(text or "")
  end

  function box:SetRange(lowest, highest, step, percent)
    self.min, self.max, self.step, self.percent = lowest, highest, step, percent and true or false
    self.syncing = true
    self.slider:SetMinMaxValues(lowest, highest)
    self.slider:SetValueStep(step)
    self.syncing = false
    self.low:SetText(show(lowest))
    self.high:SetText(show(highest))

    if self.value ~= nil then
      self:SetValue(self.value)
    end
  end

  function box:SetFormat(formatter)
    self.formatter = formatter
    self.formatFailed = nil
    self.low:SetText(show(self.min))
    self.high:SetText(show(self.max))
    self.edit:SetText(show(self.value or self.min))
  end

  function box:SetValue(value)
    self.value = fit(tonumber(value) or self.min)
    refresh()
  end

  function box:SetDisabledState(disabled)
    self.disabledState = disabled and true or false
    self:SetAlpha(self.disabledState and S("widgets.disabledAlpha") or 1)
    self.slider:EnableMouse(not self.disabledState)
    self.edit:EnableMouse(not self.disabledState)
  end

  function box:Commit(value)
    commit(value)
  end

  return box
end

Bricks.rangeBox = rangeBox

Bricks.register("range", "default", function(parent)
  return rangeBox(parent, flatRange)
end)

local menu

local function ensureMenu()
  if menu then
    return menu
  end

  menu = CreateFrame("Frame", nil, UIParent)
  menu:SetFrameStrata(S("widgets.menu.strata"))
  menu:SetClampedToScreen(true)
  menu:EnableMouse(true)
  Bricks.frame(menu, "small", "bg", "border")
  menu.rows = {}
  menu.titles = {}
  menu.ranges = {}
  menu:Hide()

  return menu
end

local function menuTitle()
  local title = CreateFrame("Frame", nil, menu)
  local padding = S("widgets.menu.inset")

  title.text = Bricks.text(title, "small", "heading")
  title.text:SetPoint("LEFT", title, "LEFT", padding, 0)
  title.text:SetPoint("RIGHT", title, "RIGHT", -padding, 0)

  return title
end

local function hideAll(list)
  for _, widget in ipairs(list) do
    widget:Hide()
  end
end

function Bricks.closeMenu()
  if menu then
    menu:Hide()
  end
end

function Bricks.menuShown()
  return menu ~= nil and menu:IsShown()
end

function Bricks.menuRows()
  return menu and menu.rows or {}
end

function Bricks.menuTitles()
  return menu and menu.titles or {}
end

function Bricks.menuRanges()
  return menu and menu.ranges or {}
end

function Bricks.openMenu(anchor, items, current, onPick)
  ensureMenu()

  if menu:IsShown() and menu.anchor == anchor then
    menu:Hide()
    return
  end

  local height, gap, padding = S("widgets.menu.row"), S("widgets.menu.gap"), S("widgets.menu.padding")
  local rows, titles, ranges = 0, 0, 0
  local y = padding

  menu.anchor = anchor
  menu:SetScale((anchor:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1))
  menu:SetWidth(anchor:GetWidth())
  hideAll(menu.rows)
  hideAll(menu.titles)
  hideAll(menu.ranges)

  for _, item in ipairs(items) do
    local widget, size

    if item.title then
      titles = titles + 1
      widget = menu.titles[titles]

      if not widget then
        widget = menuTitle()
        menu.titles[titles] = widget
      end

      Bricks.font(widget.text, S("widgets.menu.title.font"))
      paint(widget.text, "SetTextColor", S("widgets.menu.title.color"))
      widget.text:SetJustifyH(S("widgets.menu.title.align"))
      widget.text:SetText(item.text)
      size = height
    elseif item.range then
      local range = item.range

      ranges = ranges + 1
      widget = menu.ranges[ranges]

      if not widget then
        widget = Bricks.create("range", menu)
        menu.ranges[ranges] = widget
      end

      widget.onCommit = nil
      widget:SetFormat(range.format)
      widget:SetRange(range.min, range.max, range.step, range.percent)
      widget:SetTitle(item.text)
      widget:SetValue(range.value)
      widget:SetDisabledState(item.disabled and true or false)
      widget.onCommit = item.onChange
      size = S("widgets.range.height")
    else
      rows = rows + 1
      widget = menu.rows[rows]

      if not widget then
        widget = Bricks.create("row", menu)
        menu.rows[rows] = widget
      end

      widget:SetLabel(item.text)
      widget:SetSelected(item.key == current)
      widget:SetDisabledState(item.disabled and true or false)
      widget.onClick = function()
        menu:Hide()
        onPick(item.key)
      end
      size = height
    end

    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", menu, "TOPLEFT", padding, -y)
    widget:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -padding, -y)
    widget:SetHeight(size)
    widget:Show()
    y = y + size + gap
  end

  menu:SetHeight(y + padding)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -S("widgets.menu.offset"))
  menu:Show()
end

Bricks.register("select", "default", function(parent)
  local box = CreateFrame("Frame", nil, parent)
  local top = S("widgets.select.top")
  local padding = S("widgets.select.padding")
  local size = S("widgets.select.arrow.size")

  box:SetHeight(S("widgets.select.height"))

  local title = Bricks.text(box, "small", "heading")

  title:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  title:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
  title:SetJustifyH("LEFT")

  local button = Bricks.create("button", box)

  button:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -top)
  button:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -top)
  button.label:ClearAllPoints()
  button.label:SetPoint("LEFT", button, "LEFT", padding, 0)
  button.label:SetPoint("RIGHT", button, "RIGHT", -S("widgets.select.arrow.right"), 0)

  local arrow = button:CreateTexture(nil, "OVERLAY")

  arrow:SetTexture(Bricks.media("arrow"))
  arrow:SetWidth(size)
  arrow:SetHeight(size)
  arrow:SetPoint("RIGHT", button, "RIGHT", -S("widgets.select.arrow.x"), -S("widgets.select.arrow.y"))
  paint(arrow, "SetVertexColor", "buttonText")
  button.arrow = arrow

  if button.Visual then
    button:Visual()
  end

  box.title, box.button, box.items = title, button, {}

  button.onClick = function()
    Bricks.openMenu(button, box.items, box.value, function(key)
      box:SetValue(key)

      if box.onPick then
        box.onPick(key)
      end
    end)
  end
  button:HookScript("OnEnter", function()
    enterTip(box)
  end)

  function box:SetTitle(text)
    self.title:SetText(text or "")
  end

  function box:SetItems(items)
    self.items = items or {}
    self:SetValue(self.value)
  end

  function box:SetValue(key)
    self.value = key

    local text = key ~= nil and tostring(key) or ""

    for _, item in ipairs(self.items) do
      if item.key == key then
        text = item.text
        break
      end
    end

    self.button:SetLabel(text)
  end

  function box:SetDisabledState(disabled)
    self.disabledState = disabled and true or false
    self.button:SetDisabledState(self.disabledState)
  end

  return box
end)

function Bricks.pickColor(r, g, b, a, hasAlpha, onChange)
  local picker = ColorPickerFrame

  if not picker then
    return false
  end

  picker:Hide()
  picker.func, picker.opacityFunc, picker.cancelFunc = nil, nil, nil
  picker.hasOpacity = hasAlpha and true or false
  picker.opacity = 1 - (a or 1)
  picker.previousValues = { r, g, b, a }
  picker:SetColorRGB(r, g, b)

  local function changed()
    local nr, ng, nb = picker:GetColorRGB()
    local na = 1

    if hasAlpha and OpacitySliderFrame then
      na = 1 - (OpacitySliderFrame:GetValue() or 0)
    end

    onChange(nr, ng, nb, na)
  end

  picker.func = changed
  picker.opacityFunc = changed
  picker.cancelFunc = function()
    onChange(r, g, b, a or 1)
  end

  picker:Show()

  return true
end

Bricks.register("color", "default", function(parent)
  local row = CreateFrame("Button", nil, parent)
  local size = S("widgets.color.size")
  local gap = S("widgets.color.gap")

  row:SetHeight(S("widgets.color.height"))

  local chip = CreateFrame("Frame", nil, row)

  chip:SetWidth(size)
  chip:SetHeight(size)
  chip:SetPoint("LEFT", row, "LEFT", 0, 0)
  chip:SetBackdrop(backdropFor("flat"))
  paint(chip, "SetBackdropBorderColor", "checkboxBorder")

  local label = Bricks.text(row, "normal")

  label:SetPoint("LEFT", chip, "RIGHT", gap, 0)
  label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  label:SetJustifyH("LEFT")

  row.chip, row.label = chip, label

  row:SetScript("OnEnter", function(self)
    paint(self.chip, "SetBackdropBorderColor", "buttonHover")
    enterTip(self)
  end)
  row:SetScript("OnLeave", function(self)
    paint(self.chip, "SetBackdropBorderColor", "checkboxBorder")
    hideTip()
  end)
  row:SetScript("OnClick", function(self)
    if self.disabledState then
      return
    end

    local color = self.color
    local pick = self.onPick

    Bricks.pickColor(color[1], color[2], color[3], color[4], self.hasAlpha, function(nr, ng, nb, na)
      if self.onPick == pick then
        self:SetColor(nr, ng, nb, na)
      end

      if pick then
        pick(nr, ng, nb, na)
      end
    end)
  end)

  function row:SetColor(r, g, b, a)
    self.color = { tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 1 }
    self.chip:SetBackdropColor(self.color[1], self.color[2], self.color[3], self.color[4])
  end

  function row:SetLabel(text)
    self.label:SetText(text or "")
  end

  function row:SetDisabledState(disabled)
    self.disabledState = disabled and true or false
    self:SetAlpha(self.disabledState and S("widgets.disabledAlpha") or 1)
  end

  function row:TextWidth()
    return (self.label:GetStringWidth() or 0) + size + gap + S("widgets.color.margin")
  end

  row:SetColor(0, 0, 0, 1)

  return row
end)

local function flatInput(field)
  Bricks.frame(field, "small", "bgSoft", "borderDim")

  return function(focused)
    paint(field, "SetBackdropBorderColor", focused and "focus" or "borderDim")
  end
end

local function inputBox(parent, dress)
  local box = CreateFrame("Frame", nil, parent)
  local top = S("widgets.input.top")
  local padding, paddingY = S("widgets.input.padding"), S("widgets.input.paddingY")

  box:SetHeight(S("widgets.input.height"))

  local title = Bricks.text(box, "small", "heading")

  title:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  title:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
  title:SetJustifyH("LEFT")

  local field = CreateFrame("Frame", nil, box)

  field:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -top)
  field:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -top)
  field:SetHeight(S("widgets.input.field"))

  local focus = dress(field)
  local edit = CreateFrame("EditBox", nil, field)

  edit:SetAllPoints(field)
  edit:SetAutoFocus(false)
  Bricks.font(edit, "small")
  edit:SetTextInsets(padding, padding, paddingY, paddingY)
  paint(edit, "SetTextColor", "text")

  box.title, box.field, box.edit = title, field, edit

  local function commit()
    local text = edit:GetText() or ""

    if text ~= box.value then
      box.value = text

      if box.onCommit and not box.disabledState then
        box.onCommit(text)
      end
    end
  end

  edit:SetScript("OnEnterPressed", function(self)
    if box.multiline then
      self:Insert("\n")
      return
    end

    commit()
    self:ClearFocus()
  end)
  edit:SetScript("OnEscapePressed", function(self)
    self:SetText(box.value or "")
    self:ClearFocus()
  end)
  edit:SetScript("OnEditFocusGained", function()
    if focus then
      focus(true)
    end
  end)
  edit:SetScript("OnEditFocusLost", function()
    if focus then
      focus(false)
    end

    commit()
  end)
  edit:SetScript("OnEnter", function()
    enterTip(box)
  end)
  edit:SetScript("OnLeave", hideTip)

  box.area = Bricks.editArea(field, edit, function()
    return box:GetWidth()
  end)

  function box:SetTitle(text)
    self.title:SetText(text or "")
  end

  function box:SetValue(text)
    self.value = text ~= nil and tostring(text) or ""
    self.edit:SetText(self.value)
    self.area:Fit()
  end

  function box:SetLines(lines)
    local line = S("widgets.input.line")

    self.multiline = lines ~= nil and lines > 1
    self.edit:SetMultiLine(self.multiline)

    if self.multiline then
      local height = lines * line + S("widgets.input.linePad")

      self.field:SetHeight(height)
      self:SetHeight(height + top + S("widgets.input.bottom"))
    else
      self.field:SetHeight(S("widgets.input.field"))
      self:SetHeight(S("widgets.input.height"))
    end

    self.area:SetMultiLine(self.multiline)
  end

  function box:SetDisabledState(disabled)
    self.disabledState = disabled and true or false
    self:SetAlpha(self.disabledState and S("widgets.disabledAlpha") or 1)
    self.edit:EnableMouse(not self.disabledState)
  end

  return box
end

Bricks.inputBox = inputBox

Bricks.register("input", "default", function(parent)
  return inputBox(parent, flatInput)
end)

Bricks.register("text", "default", function(parent)
  local box = CreateFrame("Frame", nil, parent)
  local text = Bricks.text(box, "small")

  text:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("TOP")
  box.text = text

  function box:SetContent(content, width, size, key)
    local role = ROLES[size] or "small"

    if self.role ~= role then
      self.role = role
      Bricks.font(self.text, role)
    end

    paint(self.text, "SetTextColor", key or "text")

    self.text:SetWidth(width)
    self.text:SetText(content or "")
    self:SetWidth(width)

    local height = floor(max(self.text:GetStringHeight() or 0, self.text:GetHeight() or 0) + S("widgets.text.extra"))

    self:SetHeight(height)

    return height
  end

  return box
end)

local function rule(parent)
  local line = parent:CreateTexture(nil, "ARTWORK")

  line:SetTexture(Bricks.media("solid"))
  line:SetHeight(S("widgets.heading.size"))
  paint(line, "SetVertexColor", "borderDim")

  return line
end

Bricks.register("heading", "default", function(parent)
  local box = CreateFrame("Frame", nil, parent)
  local lines = S("widgets.heading.lines")
  local gap = S("widgets.heading.gap")

  box:SetHeight(S("widgets.heading.height"))

  local text = Bricks.text(box, "normal", S("widgets.heading.color"))

  if lines == "BOTH" then
    local left, right = rule(box), rule(box)

    text:SetPoint("CENTER", box, "CENTER", 0, 0)
    left:SetPoint("LEFT", box, "LEFT", 0, 0)
    left:SetPoint("RIGHT", text, "LEFT", -gap, 0)
    right:SetPoint("LEFT", text, "RIGHT", gap, 0)
    right:SetPoint("RIGHT", box, "RIGHT", 0, 0)
  else
    text:SetPoint("LEFT", box, "LEFT", 0, 0)

    if lines == "AFTER" then
      local right = rule(box)

      right:SetPoint("LEFT", text, "RIGHT", gap, 0)
      right:SetPoint("RIGHT", box, "RIGHT", 0, 0)
    end
  end

  box.text = text

  function box:SetLabel(label)
    self.text:SetText(Bricks.label(label, "widgets.heading.upper"))
  end

  return box
end)

local function group(parent, style)
  local frame = CreateFrame("Frame", nil, parent)
  local offset = S("widgets.group.title")
  local title = Bricks.text(frame, S("widgets.group.font"), S("widgets.group.color"))

  title:SetPoint("TOPLEFT", frame, "TOPLEFT", S("widgets.group.titleX"), 0)
  title:SetJustifyH("LEFT")

  local box = CreateFrame("Frame", nil, frame)

  box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -offset)
  box:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -offset)

  if style == "card" then
    Bricks.frame(box, GROUP_FRAMES[S("widgets.group.frame")], "card", "borderDim")
  elseif style == "line" then
    local line = rule(box)

    line:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
  end

  frame.title, frame.box = title, box

  function frame:SetLabel(text)
    self.title:SetText(Bricks.label(text, "widgets.group.upper"))
  end

  function frame:SetInnerHeight(height)
    self.box:SetHeight(height)
    self:SetHeight(height + offset)
  end

  return frame
end

Bricks.register("group", "card", function(parent)
  return group(parent, "card")
end)

Bricks.register("group", "plain", function(parent)
  return group(parent, "plain")
end)

Bricks.register("group", "line", function(parent)
  return group(parent, "line")
end)

local SCROLL_VERTICAL = { VERTICAL = true, BOTH = true }
local SCROLL_HORIZONTAL = { HORIZONTAL = true, BOTH = true }

Bricks.SCROLL_VERTICAL = SCROLL_VERTICAL
Bricks.SCROLL_HORIZONTAL = SCROLL_HORIZONTAL

-- Lays out a card: the icon on the left, the title and the line under it beside the icon, up to inset
-- pixels from the right edge, the two lines centered in the height of the card.
function Bricks.placeCard(row, inset)
  local size = S("board.row.icon")
  local top = max(2, floor((row:GetHeight() - 25) / 2))

  row.icon:SetWidth(size)
  row.icon:SetHeight(size)
  row.icon:ClearAllPoints()
  row.icon:SetPoint("LEFT", row, "LEFT", 9, 0)
  row.title:ClearAllPoints()
  row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 19 + size, -top)
  row.title:SetPoint("RIGHT", row, "RIGHT", -inset, 0)
  row.sub:ClearAllPoints()
  row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
  row.sub:SetPoint("RIGHT", row, "RIGHT", -inset, 0)
end

local CARD_BADGES = {
  take = { "heading", "!" },
  daily = { "focus", "!" },
  active = { "selected", "?" },
  dailyActive = { "selected", "?" },
  ready = { "success", "" },
}

local function fillOf(row, sub)
  local texture = row:CreateTexture(nil, "BACKGROUND")

  texture:SetDrawLayer("BACKGROUND", sub)
  texture:SetTexture(Bricks.media("solid"))
  texture:SetAllPoints(row)

  return texture
end

local function edgesOf(frame, layer, key)
  local size = S("border.size")
  local lines = {}

  for index = 1, 4 do
    lines[index] = frame:CreateTexture(nil, layer)
    lines[index]:SetTexture(Bricks.media("solid"))
    paint(lines[index], "SetVertexColor", key)
  end

  lines[1]:SetHeight(size)
  lines[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  lines[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  lines[2]:SetHeight(size)
  lines[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  lines[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  lines[3]:SetWidth(size)
  lines[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  lines[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  lines[4]:SetWidth(size)
  lines[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  lines[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  return lines
end

local function shown(regions, state)
  for _, region in ipairs(regions) do
    Lib.setShown(region, state)
  end
end

-- A card in the colors of the palette, drawn on the row it is given (a Button that carries
-- icon, title and sub): a flat background, the hover and the selection over it, an outline when selected,
-- a disk behind a round icon and a round state badge.
Bricks.register("card", "default", function(row)
  local look = { inset = 12 }
  local bg, hover, pick = fillOf(row, -8), fillOf(row, -7), fillOf(row, -6)
  local ring = row:CreateTexture(nil, "BACKGROUND")
  local disk = row:CreateTexture(nil, "OVERLAY")
  local check = row:CreateTexture(nil, "OVERLAY")
  local glyph = Bricks.text(row, "small", "bg")
  local badge = S("kit.badge.size")

  paint(bg, "SetVertexColor", "card")
  paint(hover, "SetVertexColor", "rowHover")
  paint(pick, "SetVertexColor", "selected")
  pick:SetAlpha(0.35)
  look.edges = edgesOf(row, "BORDER", "focus")
  ring:SetDrawLayer("BACKGROUND", 1)
  ring:SetTexture(Bricks.media("circle"))
  paint(ring, "SetVertexColor", "borderDim")
  disk:SetTexture(Bricks.media("circle"))
  disk:SetWidth(badge)
  disk:SetHeight(badge)
  disk:SetPoint("CENTER", row.icon, "BOTTOMLEFT", 2, 3)
  check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:SetAllPoints(disk)
  paint(check, "SetVertexColor", "bg")
  glyph:SetPoint("CENTER", disk, "CENTER", 0, 0)

  function look:SetState(hovered, selected)
    self.hovered, self.selected = hovered, selected

    Lib.setShown(hover, hovered and not selected)

    Lib.setShown(pick, selected)

    shown(self.edges, selected)
    paint(row.title, "SetTextColor", selected and "heading" or "text")
  end

  function look:SetBadge(kind)
    local spec = CARD_BADGES[kind]

    self.badgeKind = kind

    if not spec then
      disk:Hide()
      glyph:Hide()
      check:Hide()
      return
    end

    paint(disk, "SetVertexColor", spec[1])
    disk:Show()
    glyph:SetText(spec[2])
    glyph:Show()

    Lib.setShown(check, kind == "ready")
  end

  function look:SetRound(round)
    self.round = round

    Lib.setShown(ring, round)
  end

  function look:SetInset(inset)
    self.inset = inset
    Bricks.placeCard(row, inset)
  end

  function look:Dress()
    local size = S("board.row.icon") + 4

    Bricks.placeCard(row, self.inset)
    ring:ClearAllPoints()
    ring:SetWidth(size)
    ring:SetHeight(size)
    ring:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
    Bricks.font(row.title, S("board.row.font"))
    Bricks.font(row.sub, S("board.note.font"))
    paint(row.sub, "SetTextColor", "muted")
    bg:Show()
    self:SetRound(self.round ~= false)
    self:SetBadge(self.badgeKind)
    self:SetState(self.hovered, self.selected)
  end

  function look:Undress()
    shown({ bg, hover, pick, ring, disk, check, glyph }, false)
    shown(self.edges, false)
    Palette.unpaint(row.title, "SetTextColor")
    Palette.unpaint(row.sub, "SetTextColor")
  end

  look:Dress()

  return look
end)

-- A group header of a list of cards in the colors of the palette, drawn on the frame it is given (a Frame that
-- carries text): its text and a line that runs to inset pixels from the right edge.
Bricks.register("cardHeader", "default", function(header)
  local look = { inset = 4 }
  local line = header:CreateTexture(nil, "ARTWORK")

  line:SetTexture(Bricks.media("solid"))
  line:SetHeight(S("border.size"))
  paint(line, "SetVertexColor", S("board.header.line"))

  function look:SetInset(inset)
    self.inset = inset
    line:ClearAllPoints()
    line:SetPoint("LEFT", header.text, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", header, "RIGHT", -inset, 0)
  end

  function look:Dress()
    Bricks.font(header.text, S("board.header.font"))
    paint(header.text, "SetTextColor", S("board.header.color"))
    line:Show()
    self:SetInset(self.inset)
  end

  function look:Undress()
    line:Hide()
    Palette.unpaint(header.text, "SetTextColor")
  end

  look:Dress()

  return look
end)

-- Dresses the minimap button it is given, whose icon texture already exists: a ring and a disk in
-- the colors of the skin.
Bricks.register("minimap", "flat", function(button)
  local size, inset, ringWidth, edge = S("kit.minimap.size"), S("kit.minimap.inset"), S("kit.minimap.ring"), S("kit.icon.trim")
  local ring = button:CreateTexture(nil, "BACKGROUND")
  local disk = button:CreateTexture(nil, "BORDER")

  button:SetWidth(size)
  button:SetHeight(size)
  ring:SetTexture(Bricks.media("circle"))
  ring:SetAllPoints(button)
  paint(ring, "SetVertexColor", "border")
  disk:SetTexture(Bricks.media("circle"))
  disk:SetPoint("TOPLEFT", button, "TOPLEFT", ringWidth, -ringWidth)
  disk:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -ringWidth, ringWidth)
  paint(disk, "SetVertexColor", "bg")
  button.icon:ClearAllPoints()
  button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
  button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
  button.icon:SetTexCoord(edge, 1 - edge, edge, 1 - edge)

  return button
end)

-- A view over its child with a bar per scrolled direction, right and bottom. The wheel follows the
-- mode, and Shift + wheel goes across in BOTH; a view that cannot move further, or that the blocked
-- function freezes (secure content in combat), hands the wheel to the scroll around it, in the same
-- direction.
Bricks.register("scroll", "default", function(parent)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  local child = CreateFrame("Frame", nil, scroll)
  local thickness = S("widgets.scroll.width")
  local step = S("widgets.scroll.step")

  child:SetWidth(1)
  child:SetHeight(1)
  scroll:SetScrollChild(child)

  local function makeBar(orientation, move, current)
    local bar = CreateFrame("Slider", nil, scroll)
    local track = bar:CreateTexture(nil, "BACKGROUND")

    bar:SetOrientation(orientation)
    track:SetTexture(Bricks.media("solid"))
    track:SetAllPoints(bar)
    track:SetAlpha(S("widgets.scroll.trackAlpha"))
    paint(track, "SetVertexColor", "bgSoft")
    bar:SetThumbTexture(Bricks.media("solid"))

    local thumb = bar:GetThumbTexture()

    if thumb then
      if orientation == "VERTICAL" then
        thumb:SetWidth(thickness)
        thumb:SetHeight(S("widgets.scroll.thumb"))
      else
        thumb:SetWidth(S("widgets.scroll.thumb"))
        thumb:SetHeight(thickness)
      end

      paint(thumb, "SetVertexColor", "thumb")
    end

    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetValue(0)
    bar:Hide()
    bar:SetScript("OnValueChanged", function(self, value)
      if scroll.restoring then
        return
      end

      if scroll:Blocked() then
        scroll.restoring = true
        self:SetValue(current())
        scroll.restoring = false
        return
      end

      move(value)
    end)

    return bar
  end

  scroll.child = child
  scroll.bar = makeBar("VERTICAL", function(value)
    scroll:SetVerticalScroll(value)
  end, function()
    return scroll:GetVerticalScroll()
  end)
  scroll.hbar = makeBar("HORIZONTAL", function(value)
    scroll:SetHorizontalScroll(value)
  end, function()
    return scroll:GetHorizontalScroll()
  end)
  scroll.mode = "VERTICAL"
  scroll.viewWidth, scroll.viewHeight = 0, 0

  local function range(bar, size)
    bar:SetMinMaxValues(0, size)

    if size <= 0 then
      bar:SetValue(0)
      bar:Hide()
    else
      if bar:GetValue() > size then
        bar:SetValue(size)
      end

      bar:Show()
    end
  end

  local function place(self)
    local corner = (SCROLL_VERTICAL[self.mode] and SCROLL_HORIZONTAL[self.mode]) and thickness or 0

    self.bar:ClearAllPoints()
    self.bar:SetWidth(thickness)
    self.bar:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
    self.bar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, corner)
    self.hbar:ClearAllPoints()
    self.hbar:SetHeight(thickness)
    self.hbar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
    self.hbar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -corner, 0)
  end

  function scroll:Blocked()
    return self.blocked ~= nil and self.blocked() and true or false
  end

  function scroll:SetMode(mode)
    if not SCROLL_VERTICAL[mode] and not SCROLL_HORIZONTAL[mode] then
      error("EbonAPI: the scroll brick expects VERTICAL, HORIZONTAL or BOTH, got " .. tostring(mode), 2)
    end

    self.mode = mode
    place(self)

    if not SCROLL_VERTICAL[mode] then
      range(self.bar, 0)
    end

    if not SCROLL_HORIZONTAL[mode] then
      range(self.hbar, 0)
    end

    return self
  end

  function scroll:SetView(viewWidth, viewHeight)
    self.viewWidth, self.viewHeight = viewWidth, viewHeight

    if not SCROLL_HORIZONTAL[self.mode] then
      self.child:SetWidth(viewWidth)
    end

    if self.contentHeight then
      self:SetContentHeight(self.contentHeight)
    end

    if self.contentWidth then
      self:SetContentWidth(self.contentWidth)
    end
  end

  function scroll:SetContentHeight(height)
    self.contentHeight = height
    self.child:SetHeight(max(1, height))
    range(self.bar, SCROLL_VERTICAL[self.mode] and max(0, height - self.viewHeight) or 0)
  end

  function scroll:SetContentWidth(width)
    self.contentWidth = width

    if SCROLL_HORIZONTAL[self.mode] then
      self.child:SetWidth(max(1, width))
      range(self.hbar, max(0, width - self.viewWidth))
    end
  end

  function scroll:Offset()
    return self.bar:GetValue()
  end

  function scroll:SetOffset(value)
    local lowest, highest = self.bar:GetMinMaxValues()

    self.bar:SetValue(max(lowest, min(highest, value or 0)))

    if not self:Blocked() then
      self:SetVerticalScroll(self.bar:GetValue())
    end
  end

  function scroll:HorizontalOffset()
    return self.hbar:GetValue()
  end

  function scroll:SetHorizontalOffset(value)
    local lowest, highest = self.hbar:GetMinMaxValues()

    self.hbar:SetValue(max(lowest, min(highest, value or 0)))

    if not self:Blocked() then
      self:SetHorizontalScroll(self.hbar:GetValue())
    end
  end

  function scroll:Wheel(delta, horizontal)
    if horizontal == nil then
      horizontal = self.mode == "HORIZONTAL"
        or (self.mode == "BOTH" and IsShiftKeyDown ~= nil and IsShiftKeyDown() and true or false)
    end

    local bar

    if horizontal then
      bar = SCROLL_HORIZONTAL[self.mode] and self.hbar
    else
      bar = SCROLL_VERTICAL[self.mode] and self.bar
    end

    local frozen = bar and self:Blocked() or false

    if bar and not frozen then
      local lowest, highest = bar:GetMinMaxValues()
      local before = bar:GetValue()
      local after = max(lowest, min(highest, before - delta * step))

      if after ~= before then
        bar:SetValue(after)
        return true
      end
    end

    local at = self:GetParent()

    while at do
      if type(at.Wheel) == "function" and at.bar ~= nil and at.hbar ~= nil then
        return at:Wheel(delta, horizontal)
      end

      at = at.GetParent and at:GetParent() or nil
    end

    return frozen
  end

  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    self:Wheel(delta)
  end)
  place(scroll)

  return scroll
end)

-- A multi-line field scrolls: its EditBox moves into a scroll brick inside the framed field, takes
-- the height of its text, and the view follows the cursor. A one-line field stays as it was.
function Bricks.editArea(field, edit, widthOf)
  local area = { multiline = false }
  local scroll = Bricks.create("scroll", field)
  local measure = field:CreateFontString(nil, "OVERLAY")
  local cursorTop, cursorHeight = nil, 0

  Bricks.font(measure, "small")
  measure:Hide()
  scroll:SetAllPoints(field)
  scroll:SetMode("VERTICAL")
  scroll:Hide()
  area.scroll = scroll

  function area:Follow()
    if not self.multiline or not cursorTop then
      return
    end

    local offset, view = scroll:Offset(), scroll.viewHeight

    if cursorTop < offset then
      scroll:SetOffset(cursorTop)
    elseif cursorTop + cursorHeight > offset + view then
      scroll:SetOffset(cursorTop + cursorHeight - view)
    end
  end

  function area:Fit()
    if not self.multiline then
      return
    end

    local padding, paddingY = S("widgets.input.padding"), S("widgets.input.paddingY")
    local viewWidth = max(1, ((widthOf and widthOf()) or field:GetWidth() or 0) - S("widgets.scroll.width")
      - S("widgets.input.gap"))
    local viewHeight = max(1, field:GetHeight() or 0)
    local text = edit:GetText() or ""

    measure:SetWidth(max(1, viewWidth - padding * 2))
    measure:SetText(text)

    local height = (measure:GetStringHeight() or 0) + paddingY * 2

    if find(text, "\n$") then
      height = height + S("widgets.input.line")
    end

    height = max(viewHeight, ceil(height))
    scroll:SetView(viewWidth, viewHeight)
    edit:SetWidth(viewWidth)
    edit:SetHeight(height)
    scroll:SetContentHeight(height)
    self:Follow()
  end

  function area:SetMultiLine(multiline)
    self.multiline = multiline and true or false
    edit:ClearAllPoints()

    if self.multiline then
      edit:SetParent(scroll.child)
      edit:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, 0)
      scroll:Show()
      scroll:SetOffset(0)
      self:Fit()
    else
      edit:SetParent(field)
      edit:SetAllPoints(field)
      scroll:Hide()
    end
  end

  edit:HookScript("OnTextChanged", function()
    area:Fit()
  end)
  edit:HookScript("OnCursorChanged", function(_, _, y, _, height)
    cursorTop, cursorHeight = -(y or 0), height or 0
    area:Follow()
  end)
  field:HookScript("OnSizeChanged", function()
    area:Fit()
  end)

  return area
end

function Bricks.Container(name)
  local frame = CreateFrame("Frame", name, UIParent)

  frame:SetFrameStrata(S("window.strata"))
  frame:SetClampedToScreen(true)
  frame:SetToplevel(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    self:Raise()

    if not Parameters.value(nil, "locked") then
      self:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    if self.onMoved and not Parameters.value(nil, "locked") then
      self.onMoved(self)
    end
  end)

  Bricks.frame(frame, "large", "bg", "border")
  frame.decor = decorate(frame)
  frame.shadow = Bricks.shadow(frame)
  roots[frame] = true
  frame:SetScale(Parameters.value(nil, "scale"))
  frame:HookScript("OnUpdate", function(self)
    local level = self:GetFrameLevel()

    if level ~= self.shownLevel then
      self.shownLevel = level
      Bricks.relevel()
    end
  end)
  frame:HookScript("OnShow", function(self)
    self:Raise()

    local fade = S("window.fade")

    if fade > 0 and UIFrameFadeIn then
      UIFrameFadeIn(self, fade, 0, 1)
    end
  end)

  function frame:Resize(width, height)
    self:SetWidth(width)

    if height then
      self:SetHeight(height)
    end

    layoutDecor(self)
  end

  frame:Hide()

  return frame
end
