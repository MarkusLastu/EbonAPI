EbonAPI = EbonAPI or {}
EbonAPI.Catalog = {}

local Catalog = EbonAPI.Catalog
local Lib = EbonAPI.Lib

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local format, concat, sub, len = string.format, table.concat, string.sub, string.len
local floor = math.floor

local COLOR_MAX = 0xFFFFFF

local STRATA = {
  BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
  FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true,
}
local OUTLINE = { NONE = true, OUTLINE = true, THICKOUTLINE = true, MONOCHROME = true }
local AUTO_OUTLINE = { AUTO = true, NONE = true, OUTLINE = true, THICKOUTLINE = true, MONOCHROME = true }
local SIDE = { LEFT = true, RIGHT = true }
local ALIGN = { LEFT = true, CENTER = true, RIGHT = true }
local GRADIENT = { NONE = true, VERTICAL = true, HORIZONTAL = true }
local LINES = { BOTH = true, AFTER = true, NONE = true }
local ANCHOR = {
  ANCHOR_RIGHT = true, ANCHOR_LEFT = true, ANCHOR_TOPRIGHT = true, ANCHOR_TOPLEFT = true,
  ANCHOR_BOTTOMRIGHT = true, ANCHOR_BOTTOMLEFT = true, ANCHOR_CURSOR = true,
}

local PALETTE = {
  "bg", "bgSoft", "card", "border", "borderDim", "button", "buttonBorder", "buttonHover",
  "buttonDisabledBorder", "buttonText", "buttonDisabledText", "checkbox", "checkboxBorder", "checked",
  "thumb", "selected", "selectedText", "text", "muted", "title", "heading", "menu", "shadow",
  "focus", "buttonHoverFill", "rowHover", "headerBg", "navBg", "pageBg", "footerBg", "success", "danger", "caution",
}

local ROLES = { small = true, normal = true, large = true, button = true }
local PALETTE_SET = {}

for _, name in ipairs(PALETTE) do
  PALETTE_SET[name] = true
end

local LIST = {}

local function add(key, kind, fields)
  local entry = fields or {}

  entry.key, entry.kind = key, kind
  LIST[#LIST + 1] = entry
end

local function number(key, low, high)
  add(key, "number", { min = low, max = high })
end

local function whole(key, low, high)
  add(key, "number", { min = low, max = high, whole = true })
end

local function choice(key, values)
  add(key, "choice", { values = values })
end

local function brick(key, slot)
  add(key, "brick", { slot = slot })
end

add("background", "color", { player = true })
add("accent", "color", { player = true })
add("scale", "number", { player = true, min = 0.2, max = 1.4, step = 0.05, isPercent = true })
add("opacity", "number", { player = true, min = 0.25, max = 1, step = 0.01, isPercent = true })
add("shadow", "number", { player = true, min = 0, max = 1, step = 0.05, isPercent = true })
add("corners", "number", { player = true, min = 0, max = 16, whole = true, step = 1 })
add("tabs", "choice", { player = true, values = SIDE })
add("locked", "boolean", { player = true })

for _, name in ipairs(PALETTE) do
  add("palette." .. name, "rgba", { palette = name })
end

number("contrast.minimum", 1, 21)
add("contrast.enforce", "boolean")
number("contrast.light", 0, 1)
number("contrast.dark", 0, 1)
number("contrast.step", 0.01, 1)
whole("contrast.attempts", 1, 200)
number("contrast.mutedStep", 0.01, 1)

for _, role in ipairs({ "small", "normal", "large", "button" }) do
  add("fonts." .. role .. ".file", "font")
  whole("fonts." .. role .. ".size", 6, 40)
  choice("fonts." .. role .. ".outline", role == "button" and AUTO_OUTLINE or OUTLINE)
end

number("fonts.shadow.x", -4, 4)
number("fonts.shadow.y", -4, 4)
add("fonts.shadow.color", "color")
number("fonts.shadow.alpha", 0, 1)

add("media.solid", "texture")
add("media.rounded", "texture")
add("media.arrow", "texture")
add("media.shadow", "texture")
add("media.grain", "texture")
add("media.circle", "texture")
add("media.chevron", "texture")
add("media.sidebar", "texture")
add("media.error", "texture")
add("media.warning", "texture")
add("media.icon", "texture")
add("media.addonIcon", "texture")
add("media.pointer", "texture")

whole("border.size", 1, 8)
whole("border.round.base", 0, 32)
whole("border.round.small", 2, 64)
number("border.round.inset", 0, 0.5)
choice("border.style", { ROUND = true, TEXTURE = true })

for _, size in ipairs({ "large", "small" }) do
  add("border." .. size .. ".background", "texture")
  add("border." .. size .. ".edge", "texture")
  whole("border." .. size .. ".size", 1, 64)
  whole("border." .. size .. ".inset", 0, 32)
  whole("border." .. size .. ".tile", 0, 256)
end

whole("window.padding", 0, 60)
whole("window.spacing", 0, 60)
add("window.card.border", "key")
choice("window.strata", STRATA)
add("window.texture", "texture")
number("window.textureAlpha", 0, 1)
choice("window.gradient.orientation", GRADIENT)
add("window.gradient.color", "key")
number("window.gradient.from", 0, 1)
number("window.gradient.to", 0, 1)
number("window.shadow.base", 0, 64)
number("window.shadow.spread", 0, 64)
number("window.shadow.alphaBase", 0, 1)
number("window.shadow.alphaSpread", 0, 1)
number("window.shadow.x", -32, 32)
number("window.shadow.y", -32, 32)
whole("window.shadow.level", -8, 0)
add("window.glass.enabled", "boolean")
add("window.glass.tint", "color")
number("window.glass.darken", 0, 1)
number("window.glass.milk", 0, 1)
number("window.glass.grain", 0, 1)
number("window.glass.sheen", 0, 1)
number("window.glass.sheenHeight", 0, 1)
number("window.glass.edge", 0, 1)
whole("window.glass.edgeSize", 1, 8)
number("window.fade", 0, 2)
add("window.sound.open", "sound")
add("window.sound.close", "sound")

add("windows.detach.header", "boolean")
add("windows.detach.nav", "boolean")
add("windows.detach.page", "boolean")
add("windows.detach.pages", "boolean")
add("windows.detach.list", "list")
whole("windows.gap", 0, 60)
whole("windows.snap", 0, 60)
whole("windows.cascade", 0, 120)

add("header.show", "boolean")
whole("header.height", 16, 160)
choice("header.controls", SIDE)
add("header.title.show", "boolean")
number("header.title.x", -60, 200)
number("header.title.y", -60, 160)
choice("header.title.align", { SIDE = true, CENTER = true })
add("header.title.color", "key")
add("header.title.font", "role")
add("header.banner.texture", "texture")
whole("header.banner.width", 16, 1024)
whole("header.banner.height", 8, 256)
number("header.banner.y", -100, 100)
add("header.version.show", "boolean")
number("header.version.gap", 0, 60)
number("header.version.y", -20, 20)
add("header.search.show", "boolean")
whole("header.search.width", 40, 600)
whole("header.search.height", 12, 60)
number("header.search.gap", 0, 60)
number("header.search.inset", 0, 30)
number("header.search.insetY", 0, 20)
choice("header.search.position", { CONTROLS = true, CENTER = true, OPPOSITE = true })
add("header.close.show", "boolean")
whole("header.close.size", 10, 60)
number("header.close.y", -60, 160)
brick("header.close.brick", "close")
whole("header.close.width", 10, 120)
add("header.close.glyph", "text")
add("header.close.hover", "color")
add("header.close.ink", "color")
number("header.inset", -60, 60)
whole("header.spacing", 0, 40)
add("header.history.show", "boolean")
add("header.history.back", "text")
add("header.history.forward", "text")
whole("header.history.width", 10, 80)
add("header.minimize.show", "boolean")
whole("header.minimize.width", 10, 120)
add("header.minimize.glyph", "text")
add("header.minimize.color", "color")
add("header.minimize.ink", "color")
add("header.zoom.glyph", "text")
add("header.zoom.color", "color")
add("header.zoom.ink", "color")
add("header.sidebar.show", "boolean")
whole("header.sidebar.size", 6, 40)
whole("header.sidebar.width", 10, 120)
add("header.rule.show", "boolean")
whole("header.rule.size", 1, 8)

add("footer.show", "boolean")
whole("footer.height", 8, 80)
add("footer.version", "boolean")
add("footer.rule", "boolean")
whole("footer.ruleSize", 1, 8)
number("footer.inset", -60, 60)
number("footer.refresh", 0.1, 60)
add("footer.badge.show", "boolean")
add("footer.badge.color", "key")
add("footer.badge.text", "key")
number("footer.badge.padding", 0, 40)
add("footer.items", "boolean")
whole("footer.gap", 0, 60)
whole("footer.icon", 6, 40)

whole("panel.button.width", 40, 600)
whole("panel.button.height", 16, 60)
number("panel.margin", 0, 60)
number("panel.gap", 0, 60)
number("gamemenu.gap", 0, 20)

whole("nav.width", 60, 500)
whole("nav.inset", 0, 40)
whole("nav.padding", 0, 60)
whole("nav.divider.size", 0, 8)
add("nav.divider.color", "key")
choice("nav.frame", { NONE = true, LARGE = true, SMALL = true })
add("nav.rail.show", "boolean")
whole("nav.rail.width", 16, 120)
whole("nav.rail.gap", 0, 40)
whole("nav.rail.icon", 8, 80)
whole("nav.rail.spacing", 0, 40)
whole("nav.rail.indicator", 0, 8)
add("nav.rail.color", "key")
number("nav.rail.crop", 0, 0.45)
add("nav.rail.indicatorColor", "key")
add("nav.rail.desaturate", "boolean")
number("nav.rail.dim", 0, 1)
add("nav.rail.filter", "boolean")
add("nav.tree.collapsible", "boolean")
add("nav.tree.expanded", "boolean")
add("nav.tree.guides", "boolean")
whole("nav.tree.chevron", 4, 40)
add("nav.tree.chevronColor", "key")
add("nav.tree.guideColor", "key")
whole("nav.tree.guideWidth", 1, 8)
whole("nav.tree.margin", 0, 20)
brick("nav.section.brick", "section")
add("nav.section.show", "boolean")
number("nav.section.x", -20, 60)
whole("nav.section.height", 8, 60)
whole("nav.section.before", 0, 60)
whole("nav.section.after", 0, 60)
add("nav.section.upper", "boolean")
add("nav.section.color", "key")
add("nav.section.font", "role")
brick("nav.tab.brick", "tab")
whole("nav.tab.height", 12, 80)
whole("nav.tab.gap", 0, 40)
whole("nav.tab.indent", 0, 80)
choice("nav.tab.align", ALIGN)
whole("nav.tab.bar", 1, 16)
add("nav.tab.font", "role")
number("nav.tab.padding", 0, 60)
number("nav.tab.glow.selected", 0, 1)
number("nav.tab.glow.hover", 0, 1)

whole("page.width", 200, 1600)
whole("page.height", 150, 1200)
whole("page.gutter", 0, 60)
whole("page.top", 0, 200)
add("page.title.show", "boolean")
number("page.title.y", -40, 40)
add("page.description.show", "boolean")
number("page.description.gap", 0, 40)
whole("page.unit", 60, 600)
whole("page.gap.x", 0, 80)
whole("page.gap.y", 0, 80)
choice("page.addons", { LIST = true, CARDS = true })
whole("page.inset.x", 0, 120)
whole("page.inset.y", 0, 120)
choice("page.layout", { FLOW = true, LIST = true })
choice("page.descriptions", { TOOLTIP = true, INLINE = true, BOTH = true })
number("page.description.below", 0, 40)
add("page.title.color", "key")
add("page.title.font", "role")
add("page.description.color", "key")
add("page.description.font", "role")
add("page.strip.show", "boolean")
whole("page.strip.height", 10, 80)
number("page.strip.padding", 0, 60)
whole("page.strip.border", 0, 8)
add("page.strip.color", "key")
add("page.strip.tab", "key")
add("page.strip.accent", "key")
add("page.strip.text", "key")
whole("page.strip.tabs", 1, 12)
add("page.strip.idle", "key")
add("page.strip.idleText", "key")
add("page.strip.separator", "key")
whole("page.strip.close", 0, 40)
add("page.strip.font", "role")
whole("page.strip.separatorWidth", 1, 8)
whole("page.close.size", 10, 60)
whole("page.close.width", 10, 120)
number("page.close.gap", 0, 60)
add("page.close.glyph", "text")
choice("page.frame", { NONE = true, LARGE = true, SMALL = true })
add("page.crumbs.show", "boolean")
whole("page.crumbs.height", 8, 60)
add("page.crumbs.separator", "text")
add("page.crumbs.color", "key")
add("page.crumbs.font", "role")

number("widgets.disabledAlpha", 0, 1)
choice("widgets.tooltip.anchor", ANCHOR)
add("widgets.tooltip.skinned", "boolean")

brick("widgets.button.brick", "button")
whole("widgets.button.height", 10, 80)
number("widgets.button.padding", 0, 40)

brick("widgets.execute.brick", "execute")
whole("widgets.execute.height", 10, 80)

brick("widgets.toggle.brick", "toggle")
whole("widgets.toggle.height", 10, 80)
whole("widgets.toggle.size", 6, 60)
number("widgets.toggle.mark", -16, 20)
add("widgets.toggle.markTexture", "texture")
add("widgets.toggle.roundKnob", "boolean")
number("widgets.toggle.gap", 0, 40)
number("widgets.toggle.margin", 0, 40)
whole("widgets.toggle.switch.width", 10, 120)
whole("widgets.toggle.switch.height", 6, 60)

brick("widgets.range.brick", "range")
whole("widgets.range.height", 20, 160)
number("widgets.range.top", 0, 60)
whole("widgets.range.bar", 4, 60)
whole("widgets.range.track", 1, 30)
whole("widgets.range.thumb.width", 2, 60)
whole("widgets.range.thumb.height", 2, 60)
number("widgets.range.labels", 0, 30)
whole("widgets.range.edit.width", 20, 200)
whole("widgets.range.edit.height", 10, 60)
number("widgets.range.edit.y", 0, 30)
add("widgets.range.fill", "boolean")
add("widgets.range.fillColor", "key")
add("widgets.range.roundThumb", "boolean")

brick("widgets.select.brick", "select")
whole("widgets.select.height", 20, 160)
number("widgets.select.top", 0, 60)
number("widgets.select.padding", 0, 40)
whole("widgets.select.arrow.size", 4, 40)
number("widgets.select.arrow.right", 0, 60)
number("widgets.select.arrow.x", 0, 40)
number("widgets.select.arrow.y", -20, 20)

whole("widgets.menu.row", 10, 60)
whole("widgets.menu.gap", 0, 20)
whole("widgets.menu.padding", 0, 30)
number("widgets.menu.inset", 0, 40)
number("widgets.menu.offset", -20, 40)
choice("widgets.menu.strata", STRATA)
brick("widgets.menu.brick", "row")
add("widgets.menu.title.font", "role")
add("widgets.menu.title.color", "key")
choice("widgets.menu.title.align", ALIGN)

brick("widgets.color.brick", "color")
whole("widgets.color.height", 10, 80)
whole("widgets.color.size", 6, 60)
number("widgets.color.gap", 0, 40)
number("widgets.color.margin", 0, 40)

brick("widgets.input.brick", "input")
whole("widgets.input.height", 20, 160)
number("widgets.input.top", 0, 60)
whole("widgets.input.field", 10, 80)
number("widgets.input.padding", 0, 40)
number("widgets.input.paddingY", 0, 20)
whole("widgets.input.line", 8, 40)
whole("widgets.input.lines", 2, 30)
whole("widgets.input.linePad", 0, 40)
whole("widgets.input.bottom", 0, 40)
whole("widgets.input.gap", 0, 20)

brick("widgets.heading.brick", "heading")
whole("widgets.heading.height", 10, 80)
number("widgets.heading.gap", 0, 60)
choice("widgets.heading.lines", LINES)
whole("widgets.heading.size", 1, 8)
add("widgets.heading.upper", "boolean")
add("widgets.heading.color", "key")

brick("widgets.text.brick", "text")
whole("widgets.text.extra", 0, 40)

brick("widgets.group.brick", "group")
whole("widgets.group.padding", 0, 60)
whole("widgets.group.title", 0, 80)
number("widgets.group.titleX", -20, 60)
add("widgets.group.upper", "boolean")
add("widgets.group.color", "key")
add("widgets.group.font", "role")
choice("widgets.group.frame", { LARGE = true, SMALL = true, FLAT = true })

brick("widgets.scroll.brick", "scroll")
whole("widgets.scroll.width", 1, 40)
whole("widgets.scroll.thumb", 4, 200)
whole("widgets.scroll.step", 1, 400)
number("widgets.scroll.trackAlpha", 0, 1)

whole("kit.padding", 0, 40)
whole("kit.spacing", 0, 40)
whole("kit.inset", 0, 20)
whole("kit.gap", 0, 20)
whole("kit.columns", 1, 20)
whole("kit.wrap", 40, 2000)
add("kit.text.font", "role")
add("kit.bar.color", "key")
add("kit.bar.border", "key")
whole("kit.header", 12, 60)
whole("kit.control", 8, 60)
whole("kit.icon.size", 12, 96)
whole("kit.icon.inset", 0, 12)
number("kit.icon.trim", 0, 0.2)
add("kit.icon.color", "key")
add("kit.icon.border", "key")
add("kit.icon.hover", "key")
add("kit.icon.checked", "key")
whole("kit.badge.size", 6, 40)
whole("kit.badge.level", 1, 10)
add("kit.badge.color", "key")
add("kit.badge.text", "key")
whole("kit.band.height", 12, 60)
number("kit.band.alpha", 0, 1)
add("kit.band.text", "key")
whole("kit.progress.height", 4, 60)
add("kit.progress.color", "key")
add("kit.progress.background", "key")
add("kit.progress.border", "key")
whole("kit.row", 10, 60)
whole("kit.rows.action", 8, 60)
add("kit.rows.fill", "key")
number("kit.rows.fillAlpha", 0, 1)
add("kit.rows.mark", "key")
number("kit.rows.markAlpha", 0, 1)
add("kit.rows.suffix", "key")
whole("kit.slot", 10, 80)
whole("kit.indent", 0, 60)
whole("kit.list", 40, 800)
whole("kit.scroll.width", 40, 2000)
whole("kit.scroll.height", 40, 2000)
whole("kit.table.row", 10, 60)
whole("kit.table.sort", 4, 24)
whole("kit.table.column", 10, 200)
add("kit.table.selected", "key")
add("kit.table.hover", "key")
whole("kit.toast.width", 100, 600)
number("kit.toast.duration", 1, 30)
whole("kit.toast.top", 0, 600)
whole("kit.toast.icon", 12, 64)
number("kit.toast.fade", 0, 5)
whole("kit.problem.alert.width", 100, 600)
whole("kit.problem.alert.max", 1, 10)
number("kit.problem.discreet.duration", 1, 30)
number("kit.problem.discreet.quiet", 0, 3600)
whole("kit.drag", 0, 60)
whole("kit.ghost.width", 20, 600)
add("kit.ghost.color", "key")
add("kit.ghost.border", "key")
whole("kit.handle", 6, 40)
add("kit.dot.color", "key")
add("kit.dot.hover", "key")
whole("kit.pointer", 16, 160)
number("kit.aim.every", 0.01, 1)
number("kit.timer.every", 0.01, 1)
add("kit.timer.font", "role")
add("kit.chart.color", "key")
whole("kit.chart.height", 20, 400)
add("kit.chart.background", "key")
add("kit.chart.border", "key")
whole("kit.dialog.width", 160, 800)
whole("kit.dialog.copy", 20, 400)
whole("kit.dialog.button", 20, 200)
whole("kit.dialog.choices", 1, 20)
number("kit.dialog.offset", -600, 600)
add("kit.dialog.field.color", "key")
add("kit.dialog.field.border", "key")
add("kit.dialog.title.font", "role")
add("kit.dialog.title.color", "key")
choice("kit.dialog.title.align", ALIGN)
brick("kit.minimap.brick", "minimap")
whole("kit.minimap.size", 16, 48)
whole("kit.minimap.inset", 0, 16)
whole("kit.minimap.ring", 0, 12)
number("kit.minimap.offset", -40, 60)
number("kit.minimap.corner", 0, 40)
number("kit.minimap.angle", 0, 360)
number("kit.minimap.group.angle", 0, 360)
whole("kit.minimap.group.columns", 1, 12)
whole("kit.model.width", 40, 800)
whole("kit.model.height", 40, 800)
number("kit.model.turn", 0, 1)
number("kit.model.zoom.step", 0, 2)
number("kit.model.zoom.min", -10, 0)
number("kit.model.zoom.max", 0, 10)
number("kit.combatAlpha", 0, 1)
number("kit.animation", 0, 2)
number("kit.rescale.delay", 0, 1)

add("chat.prefix", "color")
add("chat.text", "color")
add("chat.error", "color")
add("chat.warn", "color")
add("chat.success", "color")
add("chat.highlight", "color")
add("chat.muted", "color")
add("chat.gold", "color")
add("chat.silver", "color")
add("chat.copper", "color")

local BY_KEY = {}
local SECTIONS = {}
local SLOTS = {}
local SLOT_NAMES = {}
local PLAYER = {}

for _, entry in ipairs(LIST) do
  BY_KEY[entry.key] = entry

  local key = entry.key

  for index = 1, len(key) do
    if sub(key, index, index) == "." then
      SECTIONS[sub(key, 1, index - 1)] = true
    end
  end

  if entry.kind == "brick" then
    SLOTS[entry.slot] = key
    SLOT_NAMES[#SLOT_NAMES + 1] = entry.slot
  end

  if entry.player then
    PLAYER[#PLAYER + 1] = entry
  end
end

table.sort(SLOT_NAMES)

Catalog.LIST = LIST
Catalog.PALETTE = PALETTE
Catalog.PLAYER = PLAYER

function Catalog.entry(key)
  return BY_KEY[key]
end

function Catalog.isSection(path)
  return SECTIONS[path] == true
end

function Catalog.slotKey(slot)
  return SLOTS[slot]
end

function Catalog.slotNames()
  return SLOT_NAMES
end

local function isColor(value)
  return type(value) == "number" and value == floor(value) and value >= 0 and value <= COLOR_MAX
end

local function isAlpha(value)
  return type(value) == "number" and value >= 0 and value <= 1
end

function Catalog.problem(entry, value)
  local name, kind = entry.key, entry.kind

  if kind == "color" then
    if not isColor(value) then
      return format('parameter "%s" expects a color 0xRRGGBB (0 to %d), got %s', name, COLOR_MAX, tostring(value))
    end
  elseif kind == "rgba" then
    local ok = isColor(value)
      or (type(value) == "table" and isColor(value[1]) and isAlpha(value[2]) and value[3] == nil)

    if not ok then
      return format('parameter "%s" expects a color 0xRRGGBB or { 0xRRGGBB, alpha from 0 to 1 }, got %s',
        name, tostring(value))
    end
  elseif kind == "number" then
    if type(value) ~= "number" or value ~= value or value < entry.min or value > entry.max
        or (entry.whole and value ~= floor(value)) then
      return format('parameter "%s" expects a %s from %s to %s, got %s', name,
        entry.whole and "whole number" or "number", tostring(entry.min), tostring(entry.max), tostring(value))
    end
  elseif kind == "choice" then
    if not entry.values[value] then
      return format('parameter "%s" expects one of %s, got %s', name,
        concat(Lib.sortedKeys(entry.values), ", "), tostring(value))
    end
  elseif kind == "boolean" then
    if type(value) ~= "boolean" then
      return format('parameter "%s" expects a boolean, got %s', name, type(value))
    end
  elseif kind == "font" then
    if type(value) ~= "string" or value == "" then
      return format('parameter "%s" expects a font file or "game", got %s', name, tostring(value))
    end
  elseif kind == "texture" or kind == "sound" then
    if type(value) ~= "string" then
      return format('parameter "%s" expects a %s path, or "" for none, got %s', name, kind, type(value))
    end
  elseif kind == "list" then
    if type(value) ~= "table" then
      return format('parameter "%s" expects a list of texts, got %s', name, type(value))
    end

    local count = 0

    for index, item in pairs(value) do
      if type(index) ~= "number" or type(item) ~= "string" then
        return format('parameter "%s" expects a list of texts, got %s at %s', name, type(item), tostring(index))
      end

      count = count + 1
    end

    if count ~= #value then
      return format('parameter "%s" expects a list of texts numbered 1, 2, 3 without gaps', name)
    end
  elseif kind == "brick" then
    if type(value) ~= "string" or value == "" then
      return format('parameter "%s" expects a brick name, got %s', name, tostring(value))
    end
  elseif kind == "key" then
    if not PALETTE_SET[value] then
      return format('parameter "%s" expects a palette color name (%s), got %s', name, concat(PALETTE, ", "),
        tostring(value))
    end
  elseif kind == "role" then
    if not ROLES[value] then
      return format('parameter "%s" expects one of %s, got %s', name, concat(Lib.sortedKeys(ROLES), ", "),
        tostring(value))
    end
  elseif kind == "text" then
    if type(value) ~= "string" then
      return format('parameter "%s" expects a text, got %s', name, type(value))
    end
  else
    return format('parameter "%s" has an unknown kind "%s"', name, tostring(kind))
  end

  return nil
end
