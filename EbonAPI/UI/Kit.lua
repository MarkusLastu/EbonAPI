EbonAPI = EbonAPI or {}
EbonAPI.Kit = {}

local Kit = EbonAPI.Kit
local Lib = EbonAPI.Lib
local Bus = EbonAPI.Bus
local DB = EbonAPI.DB
local Format = EbonAPI.Format
local Locale = EbonAPI.Locale
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Bricks = EbonAPI.Bricks
local Windows = EbonAPI.Windows
local Parameters = EbonAPI.Parameters
local Handle = EbonAPI.Handle
local Problems = EbonAPI.Problems
local L = EbonAPI.L

local type, pairs, ipairs, pcall, tostring, tonumber, setmetatable, error =
  type, pairs, ipairs, pcall, tostring, tonumber, setmetatable, error
local floor, ceil, max, min, sin, cos, atan2, deg, rad =
  math.floor, math.ceil, math.max, math.min, math.sin, math.cos, math.atan2, math.deg, math.rad
local format, find, gsub, lower, concat, sort, sub =
  string.format, string.find, string.gsub, string.lower, table.concat, table.sort, string.sub

local S = Skins.value
local paint = Palette.paint
local THEME = Palette.THEME
local WEAK = { __mode = "k" }
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }

local KINDS = {}
local elements = setmetatable({}, WEAK)
local released = setmetatable({}, WEAK)
local proxies = {}
local pending = {}
local targets = {}
local toasts = {}
local store = nil
local dragging = nil
local ghost = nil
local cursorAnchor = nil
local dialog = nil
local counter = 0
local arrivals = 0
local bindOwner = CreateFrame("Frame")
local relayout

Problems.declare("EbonAPI", "EBONAPI", {
  ["KIT.CALLBACK_FAILED"] = { class = "bug", key = "callback" },
})

function Kit.fail(code, err, owner, facts)
  err = tostring(err)
  EbonAPI.Log.trace("error", owner, err)

  local addon = (owner == "EbonAPI" or EbonAPI._addons[owner]) and owner or "EbonAPI"
  local problem = Problems.make(addon, code, facts, err)

  problem.where = Problems.where(err)
  problem.key = problem.where or problem.key
  problem.stack = debugstack and debugstack(2, 8, 0) or nil
  Problems.report(problem)
  EbonAPI.Catch.forward(err)
end

local function report(err, owner, element, name)
  if name then
    Kit.fail("EBONAPI.KIT.CALLBACK_FAILED", err, owner, { element = element, callback = name, addon = owner })
  else
    Lib.report(err, owner)
  end
end

local function trim(texture)
  local edge = S("kit.icon.trim")

  texture:SetTexCoord(edge, 1 - edge, edge, 1 - edge)
end

Kit.trim = trim

local function callback(element, name, ...)
  local fn = element.spec and element.spec[name]

  if type(fn) == "function" then
    local ok, err = pcall(fn, element, ...)

    if not ok then
      report(err, element.owner, element.kind, name)
    end
  end
end

local function evaluate(element, value)
  if type(value) == "function" then
    local ok, result = pcall(value, element)

    if not ok then
      report(result, element.owner, element.kind, "value")
      return nil
    end

    return result
  end

  return value
end

local function ask(element, fn, ...)
  local ok, result = pcall(fn, ...)

  if not ok then
    report(result, element.owner, element.kind, "callback")
    return nil
  end

  return result
end

local function reads(element, name)
  local value = element.spec[name]

  return type(value) == "function" or (value ~= nil and not element.kitDone)
end

local function source(element, name)
  if reads(element, name) then
    return evaluate(element, element.spec[name])
  end

  return nil
end

local function localized(owner, key)
  local texts = Locale.get(owner)

  return texts and texts[key] or key
end

local function textOf(element)
  local spec = element.spec

  if not spec then
    return element.label and element.label:GetText() or nil
  end

  if spec.key then
    return localized(element.owner, spec.key)
  end

  local text = evaluate(element, spec.text)

  return text ~= nil and tostring(text) or nil
end

Kit.textOf = textOf

local function saved(owner)
  if not DB.isAttached() then
    return nil
  end

  if not store then
    store = DB.store("EbonAPI", { account = { kit = {} } })
  end

  local kit = store.account.kit

  if type(kit) ~= "table" then
    kit = {}
    store.account.kit = kit
  end

  if type(kit[owner]) ~= "table" then
    kit[owner] = {}
  end

  return kit[owner]
end

Kit.evaluate = evaluate
Kit.localized = localized
Kit.saved = saved

local function inCombat()
  return InCombatLockdown ~= nil and InCombatLockdown() and true or false
end

local function afterCombat(fn)
  if inCombat() then
    pending[#pending + 1] = fn
    return false
  end

  fn()

  return true
end

Kit.afterCombat = afterCombat

function Kit.pending()
  return #pending
end

local Lines = {}
Lines.__index = Lines

local function lineColor(method, key, default)
  local color = THEME[key or default]

  if not color then
    error(format("EbonAPI: lines:%s expects a palette color, got %s (known: %s)", method, tostring(key),
      concat(Palette.KEYS, ", ")), 3)
  end

  return color
end

function Lines:Add(text, key, wrap)
  local color = lineColor("Add", key, "text")

  self.tooltip:AddLine(tostring(text), color[1], color[2], color[3], wrap and true or false)
end

function Lines:Pair(left, right, leftKey, rightKey)
  local a = lineColor("Pair", leftKey, "text")
  local b = lineColor("Pair", rightKey, "muted")

  self.tooltip:AddDoubleLine(tostring(left), tostring(right), a[1], a[2], a[3], b[1], b[2], b[3])
end

function Kit.lines(tooltip)
  return setmetatable({ tooltip = tooltip }, Lines)
end

local lines = Kit.lines(GameTooltip)

local function showTip(element)
  local spec = element.spec

  if not GameTooltip or not spec then
    return
  end

  local link = evaluate(element, spec.link)

  if type(link) == "string" and link ~= "" then
    GameTooltip:SetOwner(element, S("widgets.tooltip.anchor"))
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
    return
  end

  if spec.tip == nil and spec.tipKey == nil then
    return
  end

  local body = spec.tip

  if spec.tipKey then
    local texts = Locale.get(element.owner)

    body = texts and texts[spec.tipKey]

    if body == nil and not element.kitTipMissing then
      element.kitTipMissing = true
      report(format('EbonAPI: %s: tipKey "%s" is not in the texts of the addon', element.owner, spec.tipKey))
    end
  end

  Bricks.tip(element, textOf(element) or "", type(body) == "string" and body or nil)

  if type(spec.tip) == "function" then
    local ok, err = pcall(spec.tip, lines, element)

    if not ok then
      report(err, element.owner, element.kind, "tip")
    end

    GameTooltip:Show()
  end
end

Kit.showTip = showTip

local function click(element, mouse, anchor)
  local spec = element.spec

  if not spec or element.disabledState then
    return
  end

  local link = evaluate(element, spec.link)

  if type(link) == "string" and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
    ChatEdit_InsertLink(link)
    return
  end

  if mouse == "RightButton" and spec.menu then
    Kit.openMenu(element.owner, evaluate(element, spec.menu), anchor or element)
    return
  end

  callback(element, "onClick", mouse)
end

Kit.click = click

local function setBadge(element, text, color)
  if text == nil or text == false or text == "" then
    if element.kitBadge then
      element.kitBadge:Hide()
    end

    return
  end

  local badge = element.kitBadge

  if not badge then
    local size = S("kit.badge.size")

    badge = CreateFrame("Frame", nil, element)
    badge:SetWidth(size)
    badge:SetHeight(size)
    badge:SetPoint("CENTER", element, "TOPRIGHT", -floor(size / 4), -floor(size / 4))
    Bricks.level(badge, element, "kit.badge.level")
    badge.disk = badge:CreateTexture(nil, "ARTWORK")
    badge.disk:SetTexture(Bricks.media("circle"))
    badge.disk:SetAllPoints(badge)
    paint(badge.disk, "SetVertexColor", color or S("kit.badge.color"))
    badge.color = color
    badge.text = Bricks.text(badge, "small", S("kit.badge.text"))
    badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    element.kitBadge = badge
  elseif badge.color ~= color then
    badge.color = color
    paint(badge.disk, "SetVertexColor", color or S("kit.badge.color"))
  end

  badge.text:SetText(text == true and "" or tostring(text))
  badge:Show()
end

local common = {}

function common:Refresh()
  local spec = self.spec

  if self.kitRefresh then
    self:kitRefresh()
  end

  if spec.hidden ~= nil and not self.kitTabPage then
    local hidden = evaluate(self, spec.hidden)
    local element = self
    local function apply()
      if hidden then
        element:Hide()
      elseif not element.kitWindow then
        element:Show()
      end
    end

    if self.secure then
      afterCombat(apply)
    else
      apply()
    end
  end

  if spec.disabled ~= nil then
    self:SetDisabledState(evaluate(self, spec.disabled) and true or false)
  end

  if spec.badge ~= nil then
    setBadge(self, evaluate(self, spec.badge))
  end

  if self.kitHost and not self.kitHost.kitBusy then
    relayout(self.kitHost, true)
  end

  return self
end

function common:SetBadge(text, color)
  setBadge(self, text, color)

  return self
end

function common:Owner()
  return self.owner
end

local function adopt(element, owner, kind, spec)
  element.owner, element.kind, element.spec = owner, kind, spec

  for name, fn in pairs(common) do
    if element[name] == nil then
      element[name] = fn
    end
  end

  if not element.kitOwnTip and (spec.tip ~= nil or spec.tipKey ~= nil or spec.link ~= nil) then
    element:HookScript("OnEnter", showTip)
    element:HookScript("OnLeave", Bricks.hideTip)
  end

  if spec.width then
    element:SetWidth(spec.width)
  end

  if spec.height then
    element:SetHeight(spec.height)
  end

  if spec.point and not element.kitWindow then
    local point = spec.point

    element:ClearAllPoints()
    element:SetPoint(point[1], point[2] or element:GetParent(), point[3] or point[1], point[4] or 0, point[5] or 0)
  end

  elements[element] = true

  return element
end

Kit.adopt = adopt

function Kit.windowOf(frame)
  local at = frame

  while at do
    if at.kitWindow then
      return at
    end

    at = at.GetParent and at:GetParent() or nil
  end

  return nil
end

local function gridColumns(host, columns, spacing)
  local widths, offsets, index, left = {}, {}, 0, 0

  for _, child in ipairs(host.children) do
    if child:IsShown() then
      local at = index % columns

      widths[at] = max(widths[at] or 0, child:GetWidth() or 0)
      index = index + 1
    end
  end

  for at = 0, columns - 1 do
    offsets[at] = left
    left = left + (widths[at] or 0) + spacing
  end

  return offsets, widths
end

function relayout(host, upward)
  if host.kitSecure and inCombat() then
    if not host.kitQueued then
      host.kitQueued = true
      afterCombat(function()
        host.kitQueued = false
        relayout(host, upward)
      end)
    end

    return
  end

  local spec = host.spec
  local direction = host.kitDirection or "VERTICAL"
  local spacing = spec.spacing or S("kit.spacing")
  local columns = spec.columns or S("kit.columns")
  local body = host.body or host
  local wrap = spec.wrap or (spec.width and spec.width - (host.kitPad or 0) * 2) or S("kit.wrap")
  local x, y, rowHeight, width, height, column = 0, 0, 0, 0, 0, 0
  local offsets, widths

  if direction == "GRID" then
    offsets, widths = gridColumns(host, columns, spacing)
  end

  if direction ~= "NONE" then
    for _, child in ipairs(host.children) do
      if child:IsShown() then
        local w, h = child:GetWidth() or 0, child:GetHeight() or 0

        child:ClearAllPoints()

        if direction == "HORIZONTAL" then
          child:SetPoint("TOPLEFT", body, "TOPLEFT", x, 0)
          x = x + w + spacing
          width, height = x - spacing, max(height, h)
        elseif direction == "FLOW" then
          if x > 0 and x + w > wrap then
            x, y, rowHeight = 0, y + rowHeight + spacing, 0
          end

          child:SetPoint("TOPLEFT", body, "TOPLEFT", x, -y)
          x = x + w + spacing
          rowHeight = max(rowHeight, h)
          width, height = max(width, x - spacing), max(height, y + rowHeight)
        elseif direction == "GRID" then
          child:SetPoint("TOPLEFT", body, "TOPLEFT", offsets[column], -y)
          width = max(width, offsets[column] + widths[column])
          rowHeight = max(rowHeight, h)
          height = max(height, y + rowHeight)
          column = column + 1

          if column >= columns then
            column, y, rowHeight = 0, y + rowHeight + spacing, 0
          end
        else
          child:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
          y = y + h + spacing
          width, height = max(width, w), y - spacing
        end
      end
    end
  end

  host.kitContentWidth, host.kitContentHeight = width, height

  if host.kitResize then
    host:kitResize(width, height)
  end

  if upward and host.kitHost then
    relayout(host.kitHost, true)
  end
end

Kit.relayout = relayout

local function refreshChildren(host)
  host.kitBusy = true

  for _, child in ipairs(host.children) do
    child:Refresh()
  end

  host.kitBusy = false
  relayout(host, false)
end

local LAYOUTS = { VERTICAL = true, HORIZONTAL = true, GRID = true, FLOW = true, NONE = true }

local function holdsSecure(host)
  for _, list in ipairs({ host.children or {}, host.headButtons or {}, host.pages or {} }) do
    for _, member in pairs(list) do
      if member.secure or member.kitSecure then
        return true
      end
    end
  end

  return false
end

local function refreshSecure(host)
  local at = host

  while at do
    if at.children or at.kitWindow or at.pages then
      at.kitSecure = holdsSecure(at)
    end

    at = at.GetParent and at:GetParent() or nil
  end
end

local function release(element)
  elements[element] = nil

  if element:GetName() then
    released[element] = true
  end

  if element.spec and element.spec.shortcut then
    Kit.unbindTarget(element)
  end

  if element.kitRelease then
    element:kitRelease()
  end

  for _, child in ipairs(element.children or {}) do
    release(child)
  end

  for _, page in pairs(element.pages or {}) do
    release(page)
  end
end

local container = {}

function container:Add(kind, spec)
  local element = Kit.create(self.owner, kind, self, spec)

  return element
end

function container:Clear()
  for _, child in ipairs(self.children) do
    local function remove()
      child:Hide()
      child:ClearAllPoints()
    end

    if child.secure or child.kitSecure then
      afterCombat(remove)
    else
      remove()
    end

    release(child)
    child.kitHost = nil
  end

  self.children = {}
  refreshSecure(self)
  relayout(self, true)

  return self
end

function container:Children()
  return self.children
end

function container:SetOrientation(direction)
  if not LAYOUTS[direction] then
    error(format("EbonAPI: %s: SetOrientation expects VERTICAL, HORIZONTAL, GRID, FLOW or NONE, got %s", self.owner,
      tostring(direction)), 2)
  end

  self.kitDirection = direction
  relayout(self, true)

  return self
end

function container:Layout()
  relayout(self, true)

  return self
end

local function makeContainer(frame, spec, direction, pad)
  frame.children = {}
  frame.kitDirection = spec.layout or direction or "VERTICAL"
  frame.kitPad = pad

  for name, fn in pairs(container) do
    frame[name] = fn
  end

  return frame
end

local SCROLLS = { NONE = true, VERTICAL = true, HORIZONTAL = true, BOTH = true }
local SCROLLING = { group = true, panel = true, window = true }
local CONTAINERS = { bar = true, grid = true, group = true, panel = true, window = true }
local CLICKABLE = { button = true, secure = true, icon = true, slot = true, handle = true }
local MENUS = { list = true, tree = true, table = true }
local NAMED = { secure = true, icon = true }
local FRAMES = { flat = true, small = true, large = true }
local ACTIONS = { "macro", "spell", "item" }
local ATTRIBUTE = { macro = "macrotext", spell = "spell", item = "item" }

local function frameName(kind, owner, id)
  return format("EbonAPIKit%s%d_%s_%s", kind, #owner, owner, id)
end

local function elementName(owner, spec)
  return spec.name or (spec.shortcut and frameName("S", owner, spec.shortcut)) or nil
end

local function checkScroll(owner, kind, spec, level)
  local mode = spec.scroll

  if mode == nil then
    return
  end

  if not SCROLLING[kind] then
    error(format('EbonAPI: %s: element "%s" does not scroll, it does not accept scroll', owner, kind), level + 1)
  end

  if not SCROLLS[mode] then
    error(format("EbonAPI: %s: scroll expects NONE, VERTICAL, HORIZONTAL or BOTH, got %s", owner, tostring(mode)),
      level + 1)
  end
end

local function checkNumber(owner, spec, name, level)
  local value = spec[name]

  if value ~= nil and type(value) ~= "number" then
    error(format("EbonAPI: %s: %s expects a number, got %s", owner, name, tostring(value)), level + 1)
  end
end

local function checkShape(owner, kind, spec, level)
  level = level + 1

  if kind == "range" then
    for _, name in ipairs({ "min", "max", "step" }) do
      checkNumber(owner, spec, name, level)
    end

    if spec.step ~= nil and spec.step <= 0 then
      error(format("EbonAPI: %s: step expects a number above 0, got %s", owner, tostring(spec.step)), level)
    end

    if (spec.min or 0) >= (spec.max or 1) then
      error(format("EbonAPI: %s: range expects min lower than max, got min %s and max %s", owner,
        tostring(spec.min or 0), tostring(spec.max or 1)), level)
    end
  end

  if not CONTAINERS[kind] then
    return
  end

  for _, name in ipairs({ "spacing", "wrap", "padding", "columns" }) do
    checkNumber(owner, spec, name, level)
  end

  local columns = spec.columns

  if columns ~= nil and (columns < 1 or columns ~= floor(columns)) then
    error(format("EbonAPI: %s: columns expects a whole number of at least 1, got %s", owner, tostring(columns)), level)
  end

  if spec.layout ~= nil and not LAYOUTS[spec.layout] then
    error(format("EbonAPI: %s: layout expects VERTICAL, HORIZONTAL, GRID, FLOW or NONE, got %s", owner,
      tostring(spec.layout)), level)
  end

  if (kind == "bar" or kind == "grid") and spec.frame ~= nil
    and not (type(spec.frame) == "string" and FRAMES[lower(spec.frame)]) then
    error(format("EbonAPI: %s: frame expects flat, small or large, got %s", owner, tostring(spec.frame)), level)
  end
end

local function checkTexts(owner, spec, level)
  for _, name in ipairs({ "tip", "link" }) do
    local value = spec[name]

    if value ~= nil and type(value) ~= "string" and type(value) ~= "function" then
      error(format("EbonAPI: %s: %s expects a string or a function, got %s", owner, name, tostring(value)), level + 1)
    end
  end

  if spec.tipKey ~= nil and type(spec.tipKey) ~= "string" then
    error(format("EbonAPI: %s: tipKey expects a string, got %s", owner, tostring(spec.tipKey)), level + 1)
  end

  if spec.color ~= nil and not THEME[spec.color] then
    error(format("EbonAPI: %s: color expects a palette color, got %s (known: %s)", owner, tostring(spec.color),
      concat(Palette.KEYS, ", ")), level + 1)
  end
end

local function checkCallbacks(owner, spec, level)
  for name, value in pairs(spec) do
    if type(name) == "string" and (find(name, "^on%u") or name == "preClick") and type(value) ~= "function" then
      error(format("EbonAPI: %s: %s expects a function, got %s", owner, name, tostring(value)), level + 1)
    end
  end
end

local function checkHandled(owner, kind, spec, level)
  for _, name in ipairs({ "onClick", "menu", "shortcut" }) do
    if spec[name] ~= nil and not CLICKABLE[kind] and not (name == "menu" and MENUS[kind]) then
      error(format('EbonAPI: %s: element "%s" does not handle %s', owner, kind, name), level + 1)
    end
  end

  local shortcut = spec.shortcut

  if shortcut ~= nil and shortcut ~= false and (type(shortcut) ~= "string" or not find(shortcut, "^[%w_]+$")) then
    error(format("EbonAPI: %s: shortcut expects an id of letters, digits or _, got %s", owner, tostring(shortcut)),
      level + 1)
  end

  if kind == "window" and spec.disabled ~= nil then
    error(format('EbonAPI: %s: element "window" cannot be disabled', owner), level + 1)
  end
end

local function checkName(owner, spec, level)
  local name = spec.name

  if name ~= nil and (type(name) ~= "string" or not find(name, "^[%w_]+$")) then
    error(format("EbonAPI: %s: name expects a frame name of letters, digits or _, got %s", owner, tostring(name)),
      level + 1)
  end

  name = elementName(owner, spec)

  if name and _G[name] ~= nil and not released[_G[name]] then
    error(format('EbonAPI: %s: the frame name "%s" is already used', owner, name), level + 1)
  end
end

local function checkAction(owner, action, level)
  if type(action) ~= "table" then
    error(format("EbonAPI: %s: SetAction expects a table with macro, spell or item, got %s", owner, type(action)),
      level + 1)
  end

  for _, name in ipairs(ACTIONS) do
    if action[name] ~= nil and type(action[name]) ~= "string" then
      error(format("EbonAPI: %s: %s expects a string, got %s", owner, name, tostring(action[name])), level + 1)
    end
  end
end

local HOVERS = { "onEnter", "onLeave" }

local function rowProblem(owner, item)
  local actions = item.actions

  if actions ~= nil then
    if type(actions) ~= "table" or #actions > 3 then
      return format("EbonAPI: %s: list item actions expects a list of 0 to 3 buttons, got %s", owner,
        type(actions) == "table" and (#actions .. " buttons") or type(actions))
    end

    for _, action in ipairs(actions) do
      if type(action) ~= "table" then
        return format("EbonAPI: %s: list item actions expects tables, got %s", owner, type(action))
      end

      if action.onClick ~= nil and type(action.onClick) ~= "function" then
        return format("EbonAPI: %s: list item action onClick expects a function, got %s", owner, type(action.onClick))
      end
    end
  end

  if item.fill ~= nil and (type(item.fill) ~= "number" or item.fill < 0 or item.fill > 1) then
    return format("EbonAPI: %s: list item fill expects a number from 0 to 1, got %s", owner, tostring(item.fill))
  end

  if item.marked ~= nil and type(item.marked) ~= "boolean" then
    return format("EbonAPI: %s: list item marked expects true or false, got %s", owner, type(item.marked))
  end

  if item.suffix ~= nil and type(item.suffix) ~= "string" and type(item.suffix) ~= "number" then
    return format("EbonAPI: %s: list item suffix expects a text, got %s", owner, type(item.suffix))
  end

  for _, name in ipairs(HOVERS) do
    if item[name] ~= nil and type(item[name]) ~= "function" then
      return format("EbonAPI: %s: list item %s expects a function, got %s", owner, name, type(item[name]))
    end
  end

  local tint = item.suffixColor

  if tint ~= nil then
    local text = type(tint) == "string" and THEME[tint]
    local number = type(tint) == "table" and type(tint[1]) == "number" and type(tint[2]) == "number" and type(tint[3]) == "number"

    if not text and not (number and tint[1] >= 0 and tint[1] <= 1 and tint[2] >= 0 and tint[2] <= 1 and tint[3] >= 0 and tint[3] <= 1) then
      return format("EbonAPI: %s: list item suffixColor expects a palette color or { r, g, b } from 0 to 1, got %s", owner,
        type(tint) == "table" and "a table" or tostring(tint))
    end
  end

  return nil
end

local function colorProblem(owner, items)
  for _, item in ipairs(items) do
    if item.color ~= nil and not THEME[item.color] then
      return format('EbonAPI: %s: list item color "%s" is not a palette color (known: %s)', owner, tostring(item.color),
        concat(Palette.KEYS, ", "))
    end

    local problem = rowProblem(owner, item)

    if problem then
      return problem
    end

    if type(item.children) == "table" then
      problem = colorProblem(owner, item.children)

      if problem then
        return problem
      end
    end
  end

  return nil
end

local function checkItems(owner, items, level)
  local problem = colorProblem(owner, items)

  if problem then
    error(problem, level + 1)
  end
end

local function checkTarget(owner, spec, level)
  if type(spec.target) ~= "string" or spec.target == "" then
    error(format("EbonAPI: %s: shortcut expects a target, the shortcut name of the element it binds, got %s", owner,
      tostring(spec.target)), level + 1)
  end
end

local SIDES = { LEFT = true, RIGHT = true }
local MARGINS = { "left", "top", "right", "bottom" }

local function isFrame(value)
  return type(value) == "table" and type(value.IsShown) == "function"
end

local function checkAttach(owner, at, level)
  level = level + 1

  if type(at) ~= "table" then
    error(format("EbonAPI: %s: attach expects a table, got %s", owner, type(at)), level)
  end

  if not isFrame(at.frame) then
    error(format("EbonAPI: %s: attach.frame expects a frame, got %s", owner, type(at.frame)), level)
  end

  if at.anchor ~= nil and not isFrame(at.anchor) then
    error(format("EbonAPI: %s: attach.anchor expects a frame, got %s", owner, type(at.anchor)), level)
  end

  if at.side ~= nil and not SIDES[at.side] then
    error(format("EbonAPI: %s: attach.side expects LEFT or RIGHT, got %s", owner, tostring(at.side)), level)
  end

  if at.inside ~= nil and type(at.inside) ~= "boolean" then
    error(format("EbonAPI: %s: attach.inside expects a boolean, got %s", owner, tostring(at.inside)), level)
  end

  if at.gap ~= nil and type(at.gap) ~= "number" then
    error(format("EbonAPI: %s: attach.gap expects a number, got %s", owner, tostring(at.gap)), level)
  end

  if at.insets == nil then
    return
  end

  if type(at.insets) ~= "table" then
    error(format("EbonAPI: %s: attach.insets expects a table, got %s", owner, type(at.insets)), level)
  end

  for _, name in ipairs(MARGINS) do
    local value = at.insets[name]

    if value ~= nil and type(value) ~= "number" then
      error(format("EbonAPI: %s: attach.insets.%s expects a number, got %s", owner, name, tostring(value)), level)
    end
  end
end

local function validate(owner, kind, spec, level)
  level = level + 1

  if kind == "window" and spec.attach ~= nil then
    checkAttach(owner, spec.attach, level)
  end

  if (kind == "list" or kind == "tree") and type(spec.items) == "table" then
    checkItems(owner, spec.items, level)
  end

  if kind == "shortcut" then
    checkTarget(owner, spec, level)
  end

  checkScroll(owner, kind, spec, level)
  checkShape(owner, kind, spec, level)
  checkTexts(owner, spec, level)
  checkCallbacks(owner, spec, level)
  checkHandled(owner, kind, spec, level)

  if NAMED[kind] then
    checkName(owner, spec, level)
  end

  if kind == "secure" then
    checkAction(owner, spec, level)
  end
end

-- The scroll parameter of a container: NONE keeps its body as it is; VERTICAL, HORIZONTAL or BOTH
-- put the body in a scroll brick, frozen while secure content is in combat. The caller anchors the
-- returned frame where the body would go.
local function scrollArea(host, parent, spec)
  local mode = spec.scroll or "NONE"

  host.kitScrollMode = mode

  if mode == "NONE" then
    host.kitArea = host.body
    return host.body
  end

  local scroll = Bricks.create("scroll", parent)

  scroll:SetMode(mode)
  scroll.blocked = function()
    return host.kitSecure and inCombat()
  end
  host.body:SetParent(scroll.child)
  host.body:ClearAllPoints()
  host.body:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, 0)
  host.kitScroll, host.kitArea = scroll, scroll

  return scroll
end

local function scrolls(host)
  local mode = host.kitScrollMode

  return Bricks.SCROLL_VERTICAL[mode] == true, Bricks.SCROLL_HORIZONTAL[mode] == true
end

-- Room the bar takes, in each scrolled direction, beside the content.
local function barRoom()
  return S("widgets.scroll.width") + S("kit.gap")
end

-- The view gets the visible size, the child the content: the bars take their room inside the view.
local function fitScroll(host, viewWidth, viewHeight, width, height)
  local scroll = host.kitScroll

  if not scroll then
    return
  end

  local vertical, horizontal = scrolls(host)
  local room = barRoom()

  scroll:SetWidth(max(1, viewWidth))
  scroll:SetHeight(max(1, viewHeight))
  scroll:SetView(max(1, viewWidth - (vertical and room or 0)), max(1, viewHeight - (horizontal and room or 0)))
  scroll:SetContentWidth(width)
  scroll:SetContentHeight(height)
end

function Kit.create(owner, kind, parent, spec, level)
  local build = KINDS[kind]

  level = level or 3

  if not build then
    error(format('EbonAPI: %s: unknown element "%s" (known: %s)', owner, tostring(kind), concat(Kit.kinds(), ", ")),
      level)
  end

  if spec == nil then
    spec = {}
  elseif type(spec) ~= "table" then
    error(format('EbonAPI: %s: element "%s" expects a table, got %s', owner, kind, type(spec)), level)
  end

  validate(owner, kind, spec, level)

  local host = parent and parent.children and parent or nil
  local frame = host and (host.body or host) or parent or UIParent
  local element = build(owner, frame, spec)

  if spec.disabled ~= nil and not element.SetDisabledState then
    element:Hide()
    error(format('EbonAPI: %s: element "%s" cannot be disabled', owner, kind), level)
  end

  adopt(element, owner, kind, spec)
  element.kitTop = host == nil

  if element.secure then
    local at = frame

    while at do
      if at.children or at.kitWindow or at.pages then
        at.kitSecure = true
      end

      at = at.GetParent and at:GetParent() or nil
    end
  end

  if spec.shortcut then
    Kit.bindTarget(element)
  end

  element:Refresh()

  if host then
    element.kitHost = host
    host.children[#host.children + 1] = element
    relayout(host, true)
  end

  return element
end

function Kit.kinds()
  local list = {}

  for name in pairs(KINDS) do
    list[#list + 1] = name
  end

  sort(list)

  return list
end

function Kit.setAction(button, action)
  return afterCombat(function()
    for _, name in ipairs(ACTIONS) do
      local text = action[name]

      if text ~= nil and text ~= "" then
        button:SetAttribute("type1", name)
        button:SetAttribute(ATTRIBUTE[name], text)
        return
      end
    end

    button:SetAttribute("type1", nil)
  end)
end

local function secureCheck(owner)
  if inCombat() then
    error(format("EbonAPI: %s: a secure element cannot be created during combat", owner), 5)
  end
end

local function secureDisabled(button)
  local show = button.SetDisabledState

  function button:SetDisabledState(disabled)
    self.kitDisabled = disabled and true or false

    if self.kitDisabledQueued then
      return
    end

    self.kitDisabledQueued = inCombat()

    afterCombat(function()
      self.kitDisabledQueued = false
      show(self, self.kitDisabled)

      if self.kitDisabled then
        self:Disable()
      else
        self:Enable()
      end
    end)
  end
end

local function rangeStep(low, high, step)
  return step or ((high - low) >= 10 and 1 or 0.01)
end

local function autoWidth(button)
  if button.secure and inCombat() then
    afterCombat(function()
      autoWidth(button)
    end)
    return
  end

  button:Fit(button.spec.width or max(button.spec.minWidth or 0, button:TextWidth()))
end

KINDS.button = function(owner, parent, spec)
  local button = Bricks.create("button", parent)

  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button.onClick = function(self, mouse)
    click(self, mouse)
  end

  function button:kitRefresh()
    self:SetLabel(textOf(self) or "")
    autoWidth(self)
  end

  return button
end

KINDS.secure = function(owner, parent, spec)
  secureCheck(owner)

  local button = Bricks.dressedButton(parent, "SecureActionButtonTemplate", elementName(owner, spec))

  button.secure = true
  secureDisabled(button)
  button:RegisterForClicks("AnyUp")
  button.onClick = function(self, mouse)
    click(self, mouse)
  end

  if spec.preClick then
    button:SetScript("PreClick", function(self, mouse)
      callback(self, "preClick", mouse)
    end)
  end

  Kit.setAction(button, spec)

  function button:SetAction(action)
    checkAction(owner, action, 2)
    Kit.setAction(self, action)

    return self
  end

  function button:kitRefresh()
    self:SetLabel(textOf(self) or "")
    autoWidth(self)
  end

  return button
end

KINDS.toggle = function(owner, parent, spec)
  local toggle = Bricks.create("toggle", parent)

  toggle.onToggle = function(value)
    callback(toggle, "onChange", value)
  end

  function toggle:kitRefresh()
    local value = evaluate(self, self.spec.get)

    self:SetLabel(textOf(self) or "")

    if value ~= nil then
      self:SetValue(value)
    elseif not self.kitDone then
      self:SetValue(self.spec.value)
    end

    self.kitDone = true

    if not self.spec.width then
      self:SetWidth(self:TextWidth())
    end
  end

  return toggle
end

KINDS.range = function(owner, parent, spec)
  local range = Bricks.create("range", parent)

  range.onCommit = function(value)
    callback(range, "onChange", value)
  end

  function range:kitRefresh()
    local fields = self.spec
    local low, high = fields.min or 0, fields.max or 1
    local value = evaluate(self, fields.get)

    self:SetWidth(fields.width or S("page.unit"))
    self:SetFormat(fields.format)
    self:SetRange(low, high, rangeStep(low, high, fields.step), fields.percent)
    self:SetTitle(textOf(self) or "")

    if value ~= nil then
      self:SetValue(value)
    elseif not self.kitDone then
      self:SetValue(fields.value or low)
    end

    self.kitDone = true
  end

  return range
end

local function itemOf(owner, item)
  if type(item) ~= "table" then
    return { key = item, text = tostring(item) }
  end

  local key = item.value ~= nil and item.value or item.key
  local text = item.textKey and localized(owner, item.textKey) or item.text

  return { key = key, text = tostring(text ~= nil and text or key) }
end

local function itemsOf(owner, values)
  if type(values) ~= "table" then
    return {}
  end

  local list = {}

  if values[1] ~= nil then
    for index, item in ipairs(values) do
      list[index] = itemOf(owner, item)
    end

    return list
  end

  for key, text in pairs(values) do
    list[#list + 1] = itemOf(owner, { key = key, text = text })
  end

  sort(list, function(a, b)
    local left, right = lower(a.text), lower(b.text)

    if left ~= right then
      return left < right
    end

    return tostring(a.key) < tostring(b.key)
  end)

  return list
end

KINDS.select = function(owner, parent, spec)
  local box = Bricks.create("select", parent)

  box.onPick = function(key)
    callback(box, "onChange", key)
  end

  function box:kitRefresh()
    local value = evaluate(self, self.spec.get)

    self:SetWidth(self.spec.width or S("page.unit"))
    self:SetTitle(textOf(self) or "")
    self:SetItems(itemsOf(owner, evaluate(self, self.spec.values)))

    if value ~= nil then
      self:SetValue(value)
    elseif not self.kitDone then
      self:SetValue(self.spec.value)
    else
      self:SetValue(self.value)
    end

    self.kitDone = true
  end

  return box
end

KINDS.color = function(owner, parent, spec)
  local row = Bricks.create("color", parent)

  row.onPick = function(r, g, b, a)
    callback(row, "onChange", r, g, b, a)
  end

  function row:kitRefresh()
    local value = evaluate(self, self.spec.get)

    if value == nil and not self.kitDone then
      value = self.spec.value
    end

    self.hasAlpha = self.spec.alpha and true or false
    self:SetLabel(textOf(self) or "")

    if type(value) == "table" then
      self:SetColor(value[1], value[2], value[3], value[4])
    end

    self.kitDone = true

    if not self.spec.width then
      self:SetWidth(self:TextWidth())
    end
  end

  return row
end

KINDS.input = function(owner, parent, spec)
  local box = Bricks.create("input", parent)

  box.onCommit = function(text)
    callback(box, "onChange", text)
  end

  function box:kitRefresh()
    local value = evaluate(self, self.spec.get)
    local lines = self.spec.lines or 1

    self:SetWidth(self.spec.width or S("page.unit"))

    if self.kitLines ~= lines then
      self.kitLines = lines
      self:SetLines(self.spec.lines)
    end

    self:SetTitle(textOf(self) or "")

    if value ~= nil then
      self:SetValue(value)
    elseif not self.kitDone then
      self:SetValue(self.spec.value or "")
    end

    self.kitDone = true
  end

  return box
end

KINDS.heading = function(owner, parent, spec)
  local box = Bricks.create("heading", parent)

  function box:kitRefresh()
    self:SetWidth(self.spec.width or S("page.unit") * 2)
    self:SetLabel(textOf(self) or "")
  end

  return box
end

local function textKind(parent, spec, color)
  local box = Bricks.create("text", parent)

  function box:kitRefresh()
    self:SetContent(textOf(self) or "", self.spec.width or S("page.unit") * 2, self.spec.size or S("kit.text.font"),
      self.spec.color or color)

    if self.spec.height then
      self:SetHeight(self.spec.height)
    end
  end

  return box
end

KINDS.text = function(owner, parent, spec)
  return textKind(parent, spec, nil)
end

KINDS.status = function(owner, parent, spec)
  return textKind(parent, spec, "muted")
end

local problemViews = setmetatable({}, WEAK)

local function bandText(field, text, suffix, room)
  field:SetText(text .. suffix)

  local guard = 0

  while room > 0 and (field:GetStringWidth() or 0) > room and #text > 1 and guard < 40 do
    text = sub(text, 1, Lib.cutUtf8(text, 1, floor(#text * 0.85))) .. "..."
    field:SetText(text .. suffix)
    guard = guard + 1
  end
end

KINDS.band = function(owner, parent, spec)
  local band = CreateFrame("Frame", nil, parent)
  local pad = S("kit.padding")

  band:SetHeight(S("kit.band.height"))
  band.shade = band:CreateTexture(nil, "BACKGROUND")
  band.shade:SetTexture(Bricks.media("solid"))
  band.shade:SetAllPoints(band)
  paint(band.shade, "SetVertexColor", "danger")
  band.shade:SetAlpha(S("kit.band.alpha"))
  band.text = Bricks.text(band, "small", S("kit.band.text"))
  band.text:SetPoint("LEFT", band, "LEFT", pad, 0)
  band.text:SetPoint("RIGHT", band, "RIGHT", -pad, 0)
  band.text:SetJustifyH("LEFT")
  band:EnableMouse(true)
  band.on = false
  band:Hide()
  band:SetScript("OnMouseUp", function(self)
    local latest = self.latest

    if latest then
      Problems.open(self.addonName, Problems.keyOf(latest))
    end
  end)
  band:SetScript("OnSizeChanged", function(self)
    if self.on then
      self:Refresh()
    end
  end)

  function band:kitRefresh()
    self.addonName = self.spec.addon or self.owner

    local summary = Problems.summary(self.addonName)
    local window = self.window
    local latest = summary.severe and summary.latest or nil
    local show = latest ~= nil and not (window and window.kitShaded)

    self.latest = show and latest or nil

    if show then
      local more = summary.grave - 1

      bandText(self.text, Problems.text(latest), more > 0 and format(" (+%d)", more) or "",
        (self:GetWidth() or 0) - S("kit.padding") * 2)
    end

    if show ~= self.on then
      self.on = show

      if show then
        self:Show()
      else
        self:Hide()
      end

      if self.onToggle then
        self.onToggle(show)
      end
    end
  end

  problemViews[band] = "band"

  return band
end

local function headBadge(frame)
  local head = frame.head
  local summary = Problems.summary(frame.owner, "badge")
  local count = summary.count
  local badge = head.kitBadge

  if count == 0 and not badge then
    return
  end

  setBadge(head, count > 0 and count or nil, summary.severe and "danger" or "caution")
  badge = head.kitBadge
  badge.count = count

  if not badge.wired then
    badge.wired = true
    badge:ClearAllPoints()

    if frame.titleCentered or S("header.controls") ~= "LEFT" then
      badge:SetPoint("LEFT", frame.title, "RIGHT", S("kit.gap"), 0)
    else
      badge:SetPoint("RIGHT", frame.title, "LEFT", -S("kit.gap"), 0)
    end

    badge:EnableMouse(true)
    badge:SetScript("OnMouseUp", function()
      Problems.open(frame.owner)
    end)
    badge:SetScript("OnEnter", function(self)
      Bricks.tip(self, self.count == 1 and L.BADGE_PROBLEM_ONE or format(L.BADGE_PROBLEMS, self.count or 0))
    end)
    badge:SetScript("OnLeave", Bricks.hideTip)
  end
end

local function padOf(spec)
  return spec.padding or (spec.frame and S("kit.padding")) or 0
end

local function barKind(parent, spec, direction)
  local bar = CreateFrame("Frame", nil, parent)

  if spec.frame then
    Bricks.frame(bar, lower(spec.frame), S("kit.bar.color"), S("kit.bar.border"))
  end

  bar.body = CreateFrame("Frame", nil, bar)
  makeContainer(bar, spec, direction, padOf(spec))

  function bar:kitResize(width, height)
    local pad = padOf(self.spec)

    self.kitPad = pad
    self.body:ClearAllPoints()
    self.body:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
    self.body:SetWidth(max(1, width))
    self.body:SetHeight(max(1, height))

    if not self.spec.width then
      self:SetWidth(width + pad * 2)
    end

    if not self.spec.height then
      self:SetHeight(height + pad * 2)
    end
  end

  bar.kitRefresh = refreshChildren

  return bar
end

KINDS.bar = function(owner, parent, spec)
  return barKind(parent, spec, "HORIZONTAL")
end

KINDS.grid = function(owner, parent, spec)
  return barKind(parent, spec, "GRID")
end

KINDS.group = function(owner, parent, spec)
  local group = Bricks.create("group", parent)
  local pad = S("widgets.group.padding")

  group:SetInnerHeight(0)
  group.kitChrome = group:GetHeight()
  group.body = CreateFrame("Frame", nil, group.box)
  makeContainer(group, spec, "VERTICAL", pad)
  scrollArea(group, group.box, spec):SetPoint("TOPLEFT", group.box, "TOPLEFT", pad, -pad)

  function group:kitResize(width, height)
    local title = self.title and (self.title:GetStringWidth() or 0) or 0
    local vertical, horizontal = scrolls(self)
    local room = barRoom()
    local outer = self.spec.width
      or (horizontal and max(S("kit.scroll.width"), title + pad))
      or max(width + (vertical and room or 0) + pad * 2, title + pad)
    local inner = height + (horizontal and room or 0) + pad * 2

    if vertical or self.spec.height then
      inner = max(pad * 2 + 1, (self.spec.height or S("kit.scroll.height")) - self.kitChrome)
    end

    self.body:SetWidth(max(1, width))
    self.body:SetHeight(max(1, height))

    if not self.spec.width then
      self:SetWidth(outer)
    end

    fitScroll(self, outer - pad * 2, inner - pad * 2, width, height)
    self:SetInnerHeight(inner)
  end

  function group:kitRefresh()
    self:SetLabel(textOf(self) or "")
    refreshChildren(self)
  end

  return group
end

local function animateHeight(frame, target, done)
  local duration = S("kit.animation")

  frame.kitTarget = target

  if duration <= 0 then
    frame:SetHeight(target)

    if done then
      done()
    end

    return
  end

  frame.kitFrom, frame.kitElapsed, frame.kitAnimating = frame:GetHeight(), 0, true
  frame:SetScript("OnUpdate", function(self, elapsed)
    self.kitElapsed = self.kitElapsed + (elapsed or 0)

    local share = min(1, self.kitElapsed / duration)

    self:SetHeight(self.kitFrom + (self.kitTarget - self.kitFrom) * share)

    if self.kitHost then
      relayout(self.kitHost, true)
    end

    if share >= 1 then
      self:SetScript("OnUpdate", nil)
      self.kitAnimating = false

      if done then
        done()
      end
    end
  end)
end

KINDS.panel = function(owner, parent, spec)
  local panel = CreateFrame("Frame", nil, parent)
  local spacing = S("kit.spacing")
  local head = Bricks.create("row", panel)
  local size = S("nav.tree.chevron")
  local inset = S("kit.inset")

  head:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  head:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
  head.chevron = head:CreateTexture(nil, "OVERLAY")
  head.chevron:SetTexture(Bricks.media("chevron"))
  head.chevron:SetWidth(size)
  head.chevron:SetHeight(size)
  head.chevron:SetPoint("LEFT", head, "LEFT", inset, 0)
  paint(head.chevron, "SetVertexColor", "text")
  head.label:ClearAllPoints()
  head.label:SetPoint("LEFT", head, "LEFT", size + inset * 2, 0)
  head.label:SetPoint("RIGHT", head, "RIGHT", -inset, 0)
  head.label:SetJustifyH("LEFT")
  panel.head = head
  panel.body = CreateFrame("Frame", nil, panel)
  makeContainer(panel, spec, "VERTICAL", 0)
  scrollArea(panel, panel, spec):SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -spacing)
  panel.expanded = spec.expanded ~= false
  Bricks.turn(head.chevron, panel.expanded)

  if not panel.expanded then
    panel.kitArea:Hide()
  end

  head.onClick = function()
    panel:SetExpanded(not panel.expanded)
  end

  function panel:kitTargetHeight()
    return head:GetHeight() + (self.expanded and (spacing + (self.kitViewHeight or self.kitContentHeight or 0)) or 0)
  end

  function panel:kitResize(width, height)
    local vertical, horizontal = scrolls(self)
    local room = barRoom()
    local least = ceil(head.label:GetStringWidth() or 0) + size + inset * 3
    local outer = self.spec.width
      or (horizontal and max(S("kit.scroll.width"), least))
      or max(width + (vertical and room or 0), least)
    local view = height + (horizontal and room or 0)

    if vertical or self.spec.height then
      view = max(1, (self.spec.height or S("kit.scroll.height")) - head:GetHeight() - spacing)
    end

    self.body:SetWidth(max(1, width))
    self.body:SetHeight(max(1, height))

    if not self.spec.width then
      self:SetWidth(outer)
    end

    self.kitViewHeight = view
    fitScroll(self, outer, view, width, height)

    if self.kitAnimating then
      self.kitTarget = self:kitTargetHeight()
    else
      self:SetHeight(self:kitTargetHeight())
    end
  end

  function panel:SetExpanded(state)
    local target

    if self.kitSecure and inCombat() then
      afterCombat(function()
        panel:SetExpanded(state)
      end)
      return self
    end

    if (state and true or false) == self.expanded then
      return self
    end

    self.expanded = state and true or false
    Bricks.turn(head.chevron, self.expanded)

    if not self.expanded then
      self.kitArea:Hide()
    end

    target = self:kitTargetHeight()
    animateHeight(self, target, function()
      if panel.expanded then
        panel.kitArea:Show()
      end

      if panel.kitHost then
        relayout(panel.kitHost, true)
      end
    end)
    callback(self, "onToggle", self.expanded)

    return self
  end

  function panel:kitRefresh()
    head:SetLabel(textOf(self) or "")
    refreshChildren(self)
  end

  return panel
end

KINDS.tabs = function(owner, parent, spec)
  local frame = CreateFrame("Frame", nil, parent)
  local height = S("nav.tab.height")
  local spacing = S("kit.spacing")

  frame.strip = CreateFrame("Frame", nil, frame)
  frame.strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.strip:SetHeight(height)
  frame.tabs, frame.pages, frame.order = {}, {}, {}

  function frame:kitSize()
    local page = self.current and self.pages[self.current]
    local width = max(self.kitTabsWidth or 0, page and page:GetWidth() or 0)

    if not self.spec.width then
      self:SetWidth(width)
    end

    if not self.spec.height then
      self:SetHeight(height + spacing + (page and page:GetHeight() or 0))
    end

    if self.kitHost then
      relayout(self.kitHost, true)
    end
  end

  function frame:kitLayoutTabs()
    local x = 0

    for _, id in ipairs(self.order) do
      local button = self.tabs[id]
      local page = self.pages[id]
      local hidden = evaluate(page, page.spec.hidden) and true or false
      local wanted = id == self.current and not hidden

      if wanted and not page:IsShown() then
        page:Show()
      elseif not wanted and page:IsShown() then
        page:Hide()
      end

      if hidden then
        button:Hide()
      else
        button:Show()
        button:SetLabel(textOf(page) or id)
        button:SetPadding(S("page.strip.padding"))
        button:Fit()
        button:SetHeight(height)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.strip, "TOPLEFT", x, 0)
        button:SetSelected(id == self.current)
        x = x + button:GetWidth() + S("kit.gap")
      end
    end

    self.kitTabsWidth = x
  end

  function frame:AddTab(id, tabSpec)
    if type(id) ~= "string" and type(id) ~= "number" then
      error(format("EbonAPI: %s: AddTab expects an id that is a string or a number, got %s", owner, tostring(id)), 2)
    end

    if self.pages[id] then
      error(format('EbonAPI: %s: AddTab id "%s" is already used', owner, tostring(id)), 2)
    end

    local button = Bricks.create("tab", self.strip)
    local page = CreateFrame("Frame", nil, self)

    tabSpec = tabSpec or {}
    page:SetPoint("TOPLEFT", self.strip, "BOTTOMLEFT", 0, -spacing)
    makeContainer(page, tabSpec, "VERTICAL")
    page.kitTabPage = true
    adopt(page, owner, "page", tabSpec)
    function page:kitResize(width, contentHeight)
      if not self.spec.width then
        self:SetWidth(max(1, width))
      end

      if not self.spec.height then
        self:SetHeight(max(1, contentHeight))
      end

      frame:kitSize()
    end

    function page:kitRefresh()
      refreshChildren(self)
      frame:kitLayoutTabs()
    end

    button.onClick = function()
      frame:Select(id)
    end
    self.tabs[id], self.pages[id] = button, page
    self.order[#self.order + 1] = id

    if not self.current then
      self.current = id
    end

    self:kitLayoutTabs()
    self:kitSize()

    return page
  end

  function frame:Select(id)
    local page = self.pages[id]

    if not page or evaluate(page, page.spec.hidden) then
      return self
    end

    if self.kitSecure and inCombat() then
      afterCombat(function()
        frame:Select(id)
      end)
      return self
    end

    self.current = id
    self:kitLayoutTabs()
    self:kitSize()
    callback(self, "onSelect", id)

    return self
  end

  function frame:Selected()
    return self.current
  end

  function frame:kitRefresh()
    for _, page in pairs(self.pages) do
      page:Refresh()
    end

    self:kitLayoutTabs()
    self:kitSize()
  end

  return frame
end

local function flatten(frame, nodes, depth, out)
  for _, node in ipairs(nodes) do
    frame.depths[node] = depth
    out[#out + 1] = node

    if node.children and frame:kitOpen(node) then
      flatten(frame, node.children, depth + 1, out)
    end
  end

  return out
end

local function everyNode(nodes, out)
  for _, node in ipairs(nodes) do
    out[#out + 1] = node

    if node.children then
      everyNode(node.children, out)
    end
  end

  return out
end

local function lineOf(owner, item)
  return item.key and localized(owner, item.key) or tostring(item.text or "")
end

local function menuOf(element, data, row)
  if data.menu then
    return data.menu
  end

  local menu = element.spec.menu

  if type(menu) == "function" then
    return ask(element, menu, data, row)
  end

  return menu
end

local function anchorsOf(region)
  local points = { justify = region:GetJustifyH() }

  for index = 1, region:GetNumPoints() do
    points[index] = { region:GetPoint(index) }
  end

  return points
end

local function restoreAnchors(region, points)
  region:ClearAllPoints()

  for _, point in ipairs(points) do
    region:SetPoint(point[1], point[2], point[3], point[4], point[5])
  end

  region:SetJustifyH(points.justify)
end

local function listCheck(frame, row, item, rowHeight)
  local check = row.kitCheck

  if item.checked == nil then
    if check and check:IsShown() then
      check:Hide()
      restoreAnchors(row.label, row.kitLabelPoints)
    end

    return
  end

  if not check then
    row.kitLabelPoints = anchorsOf(row.label)
    check = Bricks.create("toggle", row)
    check:SetLabel("")
    row.kitCheck = check
  end

  check:ClearAllPoints()
  check:SetPoint("LEFT", row, "LEFT", frame.kitTree and (S("nav.tree.chevron") + S("kit.gap")) or S("kit.inset"), 0)
  check:SetWidth(check:TextWidth())
  check:SetHeight(rowHeight)
  check:SetValue(item.checked)
  check:SetDisabledState(item.disabled and true or false)
  check.onToggle = function(value)
    frame:kitCheck(item, value)
  end
  check:Show()
  row.label:ClearAllPoints()
  row.label:SetPoint("LEFT", check, "RIGHT", 0, 0)
  row.label:SetPoint("RIGHT", row, "RIGHT", -S("kit.inset"), 0)
  row.label:SetJustifyH("LEFT")
end

local listRender

local function listFree(row)
  if row.kitRoom then
    restoreAnchors(row.label, row.kitRoom)
    row.kitRoom = nil
  end
end

local function rowBand(row, field, key, alpha)
  local band = row[field]

  if not band then
    band = row:CreateTexture(nil, "ARTWORK")
    band:SetTexture(Bricks.media("solid"))
    row[field] = band
  end

  paint(band, "SetVertexColor", S(key))
  band:SetAlpha(S(alpha))
  band:ClearAllPoints()

  return band
end

local function hover(row, name)
  local item = row.kitItem
  local fn = item and item[name]

  if type(fn) == "function" then
    local ok, err = pcall(fn, item, row)

    if not ok then
      report(err, row.kitOwner, "list", name)
    end
  end
end

local function hoverEnter(row)
  hover(row, "onEnter")
end

local function hoverLeave(row)
  hover(row, "onLeave")
end

local function rowAction(frame, row, action, index, right, height)
  local list = row.kitActions

  if not list then
    list = {}
    row.kitActions = list
  end

  local button = list[index]

  if not button then
    button = Bricks.create("button", row)
    list[index] = button
  end

  button:SetLabel(lineOf(frame.owner, action))
  button:SetSelected(action.pressed and true or false)
  button:SetDisabledState(action.disabled and true or false)

  local width = button:Fit(max(S("kit.rows.action"), button:TextWidth()))

  button:SetHeight(min(S("kit.rows.action"), height))
  button:ClearAllPoints()
  button:SetPoint("RIGHT", row, "RIGHT", -right, 0)
  button.tipTitle = action.tip and lineOf(frame.owner, action) or nil
  button.tipBody = action.tip
  button.onClick = function(_, mouse)
    if type(action.onClick) == "function" then
      local ok, err = pcall(action.onClick, action, mouse, button)

      if not ok then
        report(err, frame.owner, "list", "action")
      end
    end

    listRender(frame)
  end
  button:Show()

  return width
end

local function listTail(frame, row, item, rowHeight, rowWidth)
  local actions = item.actions
  local count = actions and #actions or 0
  local fill = item.fill
  local gap, right = S("kit.gap"), S("kit.inset")
  local used = right

  if count > 0 then
    for index = count, 1, -1 do
      used = used + rowAction(frame, row, actions[index], index, used, rowHeight) + gap
    end
  end

  for index = count + 1, row.kitActions and #row.kitActions or 0 do
    row.kitActions[index]:Hide()
  end

  if item.suffix ~= nil and item.suffix ~= "" then
    local suffix = row.kitSuffix

    if not suffix then
      suffix = Bricks.text(row, "small", S("kit.rows.suffix"))
      suffix:SetJustifyH("RIGHT")
      row.kitSuffix = suffix
    end

    local tint = item.suffixColor

    if type(tint) == "table" then
      Palette.unpaint(suffix, "SetTextColor")
      suffix:SetTextColor(tint[1], tint[2], tint[3], 1)
    else
      paint(suffix, "SetTextColor", tint or S("kit.rows.suffix"))
    end

    suffix:SetText(tostring(item.suffix))
    suffix:ClearAllPoints()
    suffix:SetPoint("RIGHT", row, "RIGHT", -used, 0)
    suffix:Show()
    used = used + suffix:GetStringWidth() + gap
  elseif row.kitSuffix then
    row.kitSuffix:Hide()
  end

  if used > right then
    local label = row.label
    local base = anchorsOf(label)
    local left = false

    for _, point in ipairs(base) do
      left = left or point[1] == "LEFT"
    end

    row.kitRoom = base
    label:ClearAllPoints()

    if left then
      for _, point in ipairs(base) do
        if point[1] == "LEFT" then
          label:SetPoint(point[1], point[2], point[3], point[4], point[5])
        end
      end
    else
      label:SetPoint("LEFT", row, "LEFT", S("kit.inset"), 0)
      label:SetJustifyH("LEFT")
    end

    label:SetPoint("RIGHT", row, "RIGHT", -used, 0)
  end

  if fill and fill > 0 then
    local band = rowBand(row, "kitFill", "kit.rows.fill", "kit.rows.fillAlpha")

    band:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    band:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    band:SetWidth(max(1, rowWidth * fill))
    band:Show()
  elseif row.kitFill then
    row.kitFill:Hide()
  end

  if item.marked then
    rowBand(row, "kitMark", "kit.rows.mark", "kit.rows.markAlpha"):SetAllPoints(row)
    row.kitMark:Show()
  elseif row.kitMark then
    row.kitMark:Hide()
  end
end

function listRender(frame)
  local owner, spec = frame.owner, frame.spec
  local rows = frame.rowsPool
  local rowHeight = spec.rowHeight or S("kit.row")
  local indent, inset = S("kit.indent"), S("kit.inset")
  local width = frame:GetWidth() - S("widgets.scroll.width") - S("kit.gap")
  local child = frame.scroll.child
  local items = frame.visible or frame.items
  local y = 0

  rows:releaseAll()
  frame.scroll:SetView(width, frame:GetHeight())

  for _, item in ipairs(items) do
    local row = rows:acquire(child)
    local depth = frame.depths[item] or 0
    local payload = item.drag

    if payload == nil and type(spec.drag) == "function" then
      payload = ask(frame, spec.drag, item)
    end

    row:SetWidth(max(1, width - depth * indent))
    row:SetHeight(rowHeight)
    row:SetPoint("TOPLEFT", child, "TOPLEFT", depth * indent, -y)
    row:SetLabel(lineOf(owner, item))
    row:SetSelected(frame.selected == item)
    row:SetDisabledState(item.disabled and true or false)

    row:SetTextKey(item.color)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.kitItem = item
    row.kitOwner = owner
    row.onEnter = item.onEnter and hoverEnter or nil
    row.onLeave = item.onLeave and hoverLeave or nil
    row.tipTitle = item.tip and (item.key and localized(owner, item.key) or item.text) or nil
    row.tipBody = item.tip
    row.onClick = function(_, mouse)
      frame:kitPick(item, mouse, row)
    end

    if frame.kitTree then
      local branch = item.children ~= nil and #item.children > 0

      if not row.kitChevron then
        row.kitChevron = row:CreateTexture(nil, "OVERLAY")
        row.kitChevron:SetTexture(Bricks.media("chevron"))
        row.kitChevron:SetWidth(S("nav.tree.chevron"))
        row.kitChevron:SetHeight(S("nav.tree.chevron"))
        row.kitChevron:SetPoint("LEFT", row, "LEFT", S("kit.gap"), 0)
        paint(row.kitChevron, "SetVertexColor", "text")
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", S("nav.tree.chevron") + S("kit.gap") + inset, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -inset, 0)
        row.label:SetJustifyH("LEFT")
      end

      if branch then
        Bricks.turn(row.kitChevron, frame:kitOpen(item))
        row.kitChevron:Show()
      else
        row.kitChevron:Hide()
      end
    end

    listFree(row)
    listCheck(frame, row, item, rowHeight)
    listTail(frame, row, item, rowHeight, width - depth * indent)

    if payload then
      row:RegisterForDrag("LeftButton")
      row:SetScript("OnDragStart", function(self)
        Kit.beginDrag(owner, payload, self)
      end)
      row:SetScript("OnDragStop", function()
        Kit.endDrag()
      end)
    else
      row:SetScript("OnDragStart", nil)
      row:SetScript("OnDragStop", nil)
    end

    y = y + rowHeight
  end

  if #items == 0 and (spec.empty or spec.emptyKey) then
    frame.emptyText:SetText(spec.emptyKey and localized(owner, spec.emptyKey) or spec.empty)
    frame.emptyText:Show()
  else
    frame.emptyText:Hide()
  end

  frame.scroll:SetContentHeight(y)
end

local function newList(owner, parent, spec, tree)
  local frame = CreateFrame("Frame", nil, parent)

  frame:SetWidth(spec.width or S("page.unit") * 2)
  frame:SetHeight(spec.height or S("kit.list"))
  frame.scroll = Bricks.create("scroll", frame)
  frame.scroll:SetAllPoints(frame)
  frame.rowsPool = Bricks.slotPool("row")
  frame.items = {}
  frame.nodes = {}
  frame.depths = {}
  frame.opened = setmetatable({}, WEAK)
  frame.kitTree = tree
  frame.emptyText = Bricks.text(frame, "small", "muted")
  frame.emptyText:SetPoint("TOPLEFT", frame, "TOPLEFT", S("kit.inset"), -S("kit.inset"))
  frame.emptyText:Hide()

  function frame:kitOpen(node)
    local state = self.opened[node]

    if state == nil then
      return node.expanded and true or false
    end

    return state
  end

  function frame:kitFlatten()
    self.depths = {}
    self.visible = flatten(self, self.nodes, 0, {})
  end

  function frame:kitKeep()
    local chosen = self.selected

    if chosen == nil then
      return
    end

    local lines = self.visible and everyNode(self.nodes, {}) or self.items
    local line = lineOf(owner, chosen)
    local found = nil

    for _, item in ipairs(lines) do
      if item == chosen then
        return
      end

      if found == nil and lineOf(owner, item) == line then
        found = item
      end
    end

    self.selected = found
  end

  function frame:SetItems(items)
    items = items or {}
    checkItems(owner, items, 2)
    self.items, self.visible, self.depths = items, nil, {}
    self:kitKeep()
    listRender(self)

    return self
  end

  function frame:SetNodes(nodes)
    nodes = nodes or {}
    checkItems(owner, nodes, 2)
    self.nodes = nodes
    self:kitFlatten()
    self:kitKeep()
    listRender(self)

    return self
  end

  function frame:Selected()
    return self.selected
  end

  function frame:Select(item)
    self.selected = item
    listRender(self)

    return self
  end

  function frame:kitPick(item, mouse, row)
    if item.disabled then
      return
    end

    local right = mouse == "RightButton"
    local menu = right and menuOf(self, item, row)

    if menu then
      Kit.openMenu(owner, menu)
      return
    end

    local keep = right and (item.menu or self.spec.menu or type(item.onClick) == "function")

    if self.kitTree and not keep and item.children and #item.children > 0 then
      self.opened[item] = not self:kitOpen(item)
      self:kitFlatten()
    end

    self.selected = item

    if type(item.onClick) == "function" then
      local ok, err = pcall(item.onClick, item, mouse)

      if not ok then
        report(err, owner, "list", "onClick")
      end
    end

    callback(self, "onSelect", item, mouse)
    listRender(self)
  end

  function frame:kitCheck(item, value)
    item.checked = value

    if type(item.onCheck) == "function" then
      local ok, err = pcall(item.onCheck, item, value)

      if not ok then
        report(err, self.owner, self.kind, "onCheck")
      end
    end

    callback(self, "onCheck", item, value)
  end

  function frame:kitRefresh()
    local items = source(self, "items")

    if type(items) == "table" then
      local problem = colorProblem(owner, items)

      if problem then
        report(problem, owner)
      elseif self.kitTree then
        self.nodes = items
        self:kitFlatten()
        self:kitKeep()
      else
        self.items = items
        self:kitKeep()
      end
    elseif self.visible then
      self:kitFlatten()
    end

    self.kitDone = true
    listRender(self)
  end

  frame:SetScript("OnSizeChanged", listRender)

  return frame
end

KINDS.list = function(owner, parent, spec)
  return newList(owner, parent, spec, false)
end

KINDS.tree = function(owner, parent, spec)
  return newList(owner, parent, spec, true)
end

local function compare(a, b)
  local na, nb = tonumber(a), tonumber(b)

  if na and nb then
    return na < nb
  end

  if na or nb then
    return na ~= nil
  end

  return lower(tostring(a or "")) < lower(tostring(b or ""))
end

local function cell(data, id)
  return data[id] ~= nil and tostring(data[id]) or ""
end

KINDS.table = function(owner, parent, spec)
  local frame = CreateFrame("Frame", nil, parent)
  local rowHeight = S("kit.table.row")
  local inset, arrow = S("kit.inset"), S("kit.table.sort")

  frame:SetWidth(spec.width or S("page.unit") * 3)
  frame:SetHeight(spec.height or S("kit.list"))
  frame.columns = spec.columns or {}
  frame.rows = {}
  frame.rowFrames = {}
  frame.head = CreateFrame("Frame", nil, frame)
  frame.head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.head:SetHeight(rowHeight)
  frame.rule = frame:CreateTexture(nil, "ARTWORK")
  frame.rule:SetTexture(Bricks.media("solid"))
  frame.rule:SetHeight(1)
  frame.rule:SetPoint("TOPLEFT", frame.head, "BOTTOMLEFT", 0, 0)
  frame.rule:SetPoint("TOPRIGHT", frame.head, "BOTTOMRIGHT", 0, 0)
  paint(frame.rule, "SetVertexColor", "borderDim")
  frame.scroll = Bricks.create("scroll", frame)
  frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(rowHeight + 1))
  frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  frame.headers = {}

  for index, column in ipairs(frame.columns) do
    local header = Bricks.flatButton(frame.head)

    header.label:ClearAllPoints()
    header.label:SetPoint("LEFT", header, "LEFT", inset, 0)
    header.label:SetPoint("RIGHT", header, "RIGHT", -(arrow + inset * 2), 0)
    header.label:SetJustifyH(column.align or "LEFT")
    header.sort = header:CreateTexture(nil, "OVERLAY")
    header.sort:SetTexture(Bricks.media("chevron"))
    header.sort:SetWidth(arrow)
    header.sort:SetHeight(arrow)
    header.sort:SetPoint("RIGHT", header, "RIGHT", -inset, 0)
    paint(header.sort, "SetVertexColor", "muted")
    header.sort:Hide()
    header.onClick = function()
      if column.sort ~= false then
        frame:SortBy(column.id)
      end
    end
    frame.headers[index] = header
  end

  local function paintRow(row)
    local selected = row.kitRow ~= nil and row.kitRow == frame.selected
    local key = selected and "selectedText" or "text"

    if selected then
      paint(row.fill, "SetVertexColor", S("kit.table.selected"))
      row.fill:Show()
    elseif row.hovered then
      paint(row.fill, "SetVertexColor", S("kit.table.hover"))
      row.fill:Show()
    else
      row.fill:Hide()
    end

    for _, cell in pairs(row.cells) do
      paint(cell, "SetTextColor", key)
    end
  end

  local function rowFrame(index)
    local row = frame.rowFrames[index]

    if row then
      return row
    end

    row = CreateFrame("Button", nil, frame.scroll.child)
    row:SetHeight(rowHeight)
    row.fill = row:CreateTexture(nil, "BACKGROUND")
    row.fill:SetTexture(Bricks.media("solid"))
    row.fill:SetAllPoints(row)
    row.fill:Hide()
    row.cells = {}
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", function(self)
      self.hovered = true
      paintRow(self)

      if self.kitRow and self.kitRow.tip then
        Bricks.tip(self, self.cells[1] and self.cells[1]:GetText() or "", self.kitRow.tip)
      end
    end)
    row:SetScript("OnLeave", function(self)
      self.hovered = false
      paintRow(self)
      Bricks.hideTip()
    end)
    row:SetScript("OnClick", function(self, mouse)
      local data = self.kitRow

      if not data then
        return
      end

      local menu = mouse == "RightButton" and menuOf(frame, data)

      if menu then
        Kit.openMenu(owner, menu)
        return
      end

      frame.selected = data

      if type(data.onClick) == "function" then
        local ok, err = pcall(data.onClick, data, mouse)

        if not ok then
          report(err, owner, "list", "onClick")
        end
      end

      callback(frame, "onSelect", data, mouse)
      frame:kitDraw()
    end)
    frame.rowFrames[index] = row

    return row
  end

  local function widths()
    local total = frame:GetWidth() - S("widgets.scroll.width") - S("kit.gap")
    local fixed, flexible = 0, 0
    local list = {}

    for _, column in ipairs(frame.columns) do
      if column.width then
        fixed = fixed + column.width
      else
        flexible = flexible + 1
      end
    end

    local share = flexible > 0 and max(S("kit.table.column"), (total - fixed) / flexible) or 0

    for index, column in ipairs(frame.columns) do
      list[index] = column.width or share
    end

    return list, total
  end

  function frame:SetRows(rows)
    self.rows = rows or {}
    self:kitKeep()
    self:kitDraw()

    return self
  end

  function frame:kitKeep()
    local chosen = self.selected

    if chosen == nil then
      return
    end

    local found = nil

    for _, data in ipairs(self.rows) do
      if data == chosen then
        return
      end

      if found == nil then
        local same = true

        for _, column in ipairs(self.columns) do
          same = same and cell(data, column.id) == cell(chosen, column.id)
        end

        if same then
          found = data
        end
      end
    end

    self.selected = found
  end

  function frame:SortBy(id)
    if self.sortId == id then
      self.sortDesc = not self.sortDesc
    else
      self.sortId, self.sortDesc = id, false
    end

    self:kitDraw()

    return self
  end

  function frame:Selected()
    return self.selected
  end

  function frame:Sorted()
    local list, order = {}, {}

    for index, row in ipairs(self.rows) do
      list[index] = row
      order[row] = order[row] or index
    end

    if self.sortId then
      local id, descending = self.sortId, self.sortDesc

      sort(list, function(a, b)
        local left, right = a[id], b[id]

        if descending then
          left, right = right, left
        end

        if compare(left, right) then
          return true
        end

        if compare(right, left) then
          return false
        end

        return order[a] < order[b]
      end)
    end

    return list
  end

  function frame:kitDraw()
    local sizes, total = widths()
    local x = 0

    for index, column in ipairs(self.columns) do
      local header = self.headers[index]

      header:SetWidth(sizes[index])
      header:SetHeight(rowHeight)
      header:ClearAllPoints()
      header:SetPoint("TOPLEFT", self.head, "TOPLEFT", x, 0)
      header:SetLabel(column.key and localized(owner, column.key) or tostring(column.text or column.id or ""))

      if self.sortId == column.id then
        Bricks.turn(header.sort, self.sortDesc and "DOWN" or "UP")
        header.sort:Show()
      else
        header.sort:Hide()
      end

      x = x + sizes[index]
    end

    local rows = self:Sorted()
    local y = 0

    self.scroll:SetView(total, self:GetHeight() - rowHeight - 1)

    for index, data in ipairs(rows) do
      local row = rowFrame(index)
      local cx = 0

      row:SetWidth(total)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", self.scroll.child, "TOPLEFT", 0, -y)
      row.kitRow = data

      for column, spec2 in ipairs(self.columns) do
        local label = row.cells[column]

        if not label then
          label = Bricks.text(row, "small", "text")
          row.cells[column] = label
        end

        label:ClearAllPoints()
        label:SetPoint("LEFT", row, "LEFT", cx + inset, 0)
        label:SetWidth(max(1, sizes[column] - inset * 2))
        label:SetJustifyH(spec2.align or "LEFT")
        label:SetText(cell(data, spec2.id))
        cx = cx + sizes[column]
      end

      paintRow(row)
      row:Show()
      y = y + rowHeight
    end

    for index = #rows + 1, #self.rowFrames do
      local row = self.rowFrames[index]

      if row.hovered then
        row.hovered = false
        Bricks.hideTip()
      end

      row:Hide()
      row.kitRow = nil
    end

    self.scroll:SetContentHeight(y)
  end

  function frame:kitRefresh()
    local rows = source(self, "rows")

    if type(rows) == "table" then
      self.rows = rows
      self:kitKeep()
    end

    self.kitDone = true
    self:kitDraw()
  end

  frame:SetScript("OnSizeChanged", function(self)
    self:kitDraw()
  end)

  return frame
end

KINDS.progress = function(owner, parent, spec)
  local bar = CreateFrame("Frame", nil, parent)
  local edge = S("border.size")

  bar:SetWidth(spec.width or S("page.unit"))
  bar:SetHeight(spec.height or S("kit.progress.height"))
  Bricks.frame(bar, "flat", S("kit.progress.background"), S("kit.progress.border"))
  bar.fill = bar:CreateTexture(nil, "ARTWORK")
  bar.fill:SetTexture(Bricks.media("solid"))
  bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", edge, -edge)
  bar.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", edge, edge)
  paint(bar.fill, "SetVertexColor", spec.color or S("kit.progress.color"))
  bar.text = Bricks.text(bar, "small", "text")
  bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  bar.value, bar.max = 0, 1

  function bar:SetValue(value, maximum)
    self.value = tonumber(value) or 0

    if maximum ~= nil then
      self.max = tonumber(maximum) or self.max
    end

    self:kitDraw()

    return self
  end

  function bar:kitDraw()
    local inner = max(0, self:GetWidth() - edge * 2)
    local share = self.max > 0 and max(0, min(1, self.value / self.max)) or 0

    if share * inner < 1 then
      self.fill:Hide()
    else
      self.fill:SetWidth(share * inner)
      self.fill:Show()
    end

    self.text:SetText(textOf(self) or "")
  end

  function bar:kitRefresh()
    local value, maximum = source(self, "value"), source(self, "max")

    if value ~= nil then
      self.value = tonumber(value) or 0
    end

    if maximum ~= nil then
      self.max = tonumber(maximum) or self.max
    end

    self.kitDone = true
    self:kitDraw()
  end

  bar:SetScript("OnSizeChanged", function(self)
    self:kitDraw()
  end)

  return bar
end

KINDS.timer = function(owner, parent, spec)
  local box = Bricks.create("text", parent)

  counter = counter + 1
  box.kitTicker = "EbonAPI.kit.timer." .. counter

  function box:kitShow(remaining)
    local label = textOf(self)
    local duration = Format.duration(ceil(remaining))

    if label and find(label, "%s", 1, true) then
      label = gsub(label, "%%([s%%])", function(mark)
        return mark == "s" and duration or "%"
      end)
    elseif label then
      label = label .. " " .. duration
    end

    self:SetContent(label or duration, self.spec.width or S("page.unit"), self.spec.size or S("kit.timer.font"), self.spec.color)
  end

  function box:Remaining()
    return self.endsAt and max(0, self.endsAt - GetTime()) or 0
  end

  function box:Stop()
    Bus.untick(self.kitTicker)
    self.endsAt, self.onDone = nil, nil

    return self
  end

  function box:kitRelease()
    self:Stop()
  end

  function box:kitTick()
    local remaining = self:Remaining()

    self:kitShow(remaining)

    if self.endsAt and remaining <= 0 then
      local done = self.onDone

      self:Stop()

      if type(done) == "function" then
        local ok, err = pcall(done, self)

        if not ok then
          report(err, self.owner, self.kind, "onDone")
        end
      end

      callback(self, "onDone")
    end
  end

  function box:Start(seconds, onDone)
    self.endsAt = GetTime() + (tonumber(seconds) or 0)
    self.onDone = onDone or self.onDone
    Bus.tick(self.kitTicker, S("kit.timer.every"), function()
      box:kitTick()
    end)
    self:kitTick()

    return self
  end

  function box:kitRefresh()
    self:kitShow(self:Remaining())
  end

  return box
end

KINDS.chart = function(owner, parent, spec)
  local frame = CreateFrame("Frame", nil, parent)

  frame:SetWidth(spec.width or S("page.unit") * 2)
  frame:SetHeight(spec.height or S("kit.chart.height"))
  Bricks.frame(frame, "flat", S("kit.chart.background"), S("kit.chart.border"))
  frame.bars = {}
  frame.values = {}

  function frame:SetValues(values)
    self.values = values or {}
    self:kitDraw()

    return self
  end

  function frame:kitDraw()
    local values = self.values
    local count = #values
    local inset, gap = S("border.size") + 1, S("kit.gap")
    local width, height = self:GetWidth() - inset * 2, self:GetHeight() - inset * 2
    local top = 0

    for _, value in ipairs(values) do
      top = max(top, tonumber(value) or 0)
    end

    local barWidth = count > 0 and max(1, (width - gap * (count - 1)) / count) or 0

    for index, value in ipairs(values) do
      local bar = self.bars[index]

      if not bar then
        bar = self:CreateTexture(nil, "ARTWORK")
        bar:SetTexture(Bricks.media("solid"))
        paint(bar, "SetVertexColor", self.spec.color or S("kit.chart.color"))
        self.bars[index] = bar
      end

      bar:ClearAllPoints()
      bar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", inset + (index - 1) * (barWidth + gap), inset)
      bar:SetWidth(barWidth)
      bar:SetHeight(top > 0 and max(1, height * (tonumber(value) or 0) / top) or 1)
      bar:Show()
    end

    for index = count + 1, #self.bars do
      self.bars[index]:Hide()
    end
  end

  function frame:kitRefresh()
    local values = source(self, "values")

    if type(values) == "table" then
      self.values = values
    end

    self.kitDone = true
    self:kitDraw()
  end

  frame:SetScript("OnSizeChanged", function(self)
    self:kitDraw()
  end)

  return frame
end

KINDS.icon = function(owner, parent, spec)
  local secure = spec.macro ~= nil or spec.spell ~= nil or spec.item ~= nil
  local size = spec.size or S("kit.icon.size")
  local inset = S("kit.icon.inset")

  if secure then
    secureCheck(owner)
  end

  local button = CreateFrame("Button", elementName(owner, spec), parent, secure and "SecureActionButtonTemplate" or nil)

  button:SetWidth(size)
  button:SetHeight(size)
  Bricks.frame(button, "small", S("kit.icon.color"), S("kit.icon.border"))
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
  button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
  trim(button.icon)
  button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.cooldown:SetAllPoints(button.icon)
  button.cooldown:Hide()
  button.count = Bricks.text(button, "small", "text")
  button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
  button:RegisterForClicks("AnyUp")

  local function border(self)
    paint(self, "SetBackdropBorderColor",
      self.hovered and S("kit.icon.hover") or (self.checkedState and S("kit.icon.checked") or S("kit.icon.border")))
  end

  button:SetScript("OnEnter", function(self)
    self.hovered = true
    border(self)
  end)
  button:SetScript("OnLeave", function(self)
    self.hovered = false
    border(self)
  end)

  if secure then
    button.secure = true
    button:SetScript("PostClick", function(self, mouse)
      click(self, mouse)
    end)

    if spec.preClick then
      button:SetScript("PreClick", function(self, mouse)
        callback(self, "preClick", mouse)
      end)
    end

    Kit.setAction(button, spec)
  else
    button:SetScript("OnClick", function(self, mouse)
      click(self, mouse)
    end)
  end

  function button:SetDisabledState(disabled)
    self.disabledState = disabled and true or false
    self.icon:SetDesaturated(self.disabledState)
    self:SetAlpha(self.disabledState and S("widgets.disabledAlpha") or 1)
  end

  if secure then
    secureDisabled(button)
  end

  function button:SetCooldown(start, duration)
    if start and duration and duration > 0 then
      self.cooldown:SetCooldown(start, duration)
      self.cooldown:Show()
    else
      self.cooldown:Hide()
    end

    return self
  end

  function button:SetCheckedState(state)
    self.checkedState = state and true or false
    border(self)

    return self
  end

  function button:SetAction(action)
    if not self.secure then
      error(format('EbonAPI: %s: element "icon" is not secure, give it macro, spell or item to accept SetAction', owner),
        2)
    end

    checkAction(owner, action, 2)
    Kit.setAction(self, action)

    return self
  end

  function button:kitRefresh()
    local count = evaluate(self, self.spec.count)

    self.icon:SetTexture(Lib.icon(evaluate(self, self.spec.icon)) or Bricks.media("addonIcon"))
    self.count:SetText(count ~= nil and tostring(count) or "")

    if reads(self, "checked") then
      self:SetCheckedState(evaluate(self, self.spec.checked))
    end

    if reads(self, "cooldown") then
      local cooldown = evaluate(self, self.spec.cooldown)

      if type(cooldown) == "table" then
        self:SetCooldown(cooldown[1], cooldown[2])
      else
        self:SetCooldown()
      end
    end

    self.kitDone = true
  end

  return button
end

KINDS.slot = function(owner, parent, spec)
  local slot = Bricks.create("row", parent)
  local height = spec.height or S("kit.slot")
  local inset = S("kit.inset")

  slot:SetWidth(spec.width or S("page.unit"))
  slot:SetHeight(height)
  slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  slot:RegisterForDrag("LeftButton")
  slot.onClick = function(self, mouse)
    click(self, mouse)
  end

  slot:SetScript("OnDragStart", function(self)
    local payload = evaluate(self, self.spec.drag)

    if payload then
      Kit.beginDrag(owner, payload, self)
    end
  end)
  slot:SetScript("OnDragStop", function()
    Kit.endDrag()
  end)
  slot:SetScript("OnReceiveDrag", function(self)
    Kit.receive(self)
  end)

  function slot:kitRefresh()
    self:SetLabel(textOf(self) or "")

    if self.spec.icon ~= nil and not self.icon then
      self.icon = self:CreateTexture(nil, "ARTWORK")
      self.icon:SetWidth(height - inset)
      self.icon:SetHeight(height - inset)
      self.icon:SetPoint("LEFT", self, "LEFT", floor(inset / 2), 0)
      trim(self.icon)
      self.label:ClearAllPoints()
      self.label:SetPoint("LEFT", self.icon, "RIGHT", inset, 0)
      self.label:SetPoint("RIGHT", self, "RIGHT", -inset, 0)
      self.label:SetJustifyH("LEFT")
    end

    if self.icon then
      self.icon:SetTexture(Lib.icon(evaluate(self, self.spec.icon)) or Bricks.media("addonIcon"))
    end
  end

  return slot
end

KINDS.handle = function(owner, parent, spec)
  local size = spec.size or S("kit.handle")
  local handle = CreateFrame("Button", nil, parent)

  handle:SetWidth(size)
  handle:SetHeight(size)
  handle.dot = handle:CreateTexture(nil, "ARTWORK")
  handle.dot:SetTexture(Bricks.media("circle"))
  handle.dot:SetAllPoints(handle)
  paint(handle.dot, "SetVertexColor", S("kit.dot.color"))
  handle:RegisterForDrag("LeftButton")
  handle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  handle:SetScript("OnEnter", function(self)
    paint(self.dot, "SetVertexColor", S("kit.dot.hover"))
  end)
  handle:SetScript("OnLeave", function(self)
    paint(self.dot, "SetVertexColor", S("kit.dot.color"))
  end)
  handle:SetScript("OnDragStart", function(self)
    local window = Kit.windowOf(self)

    if window and window.spec.move ~= "NONE" and not Parameters.value(nil, "locked")
      and not (window.kitSecure and inCombat()) then
      window:StartMoving()
      self.kitMoving = window
    end
  end)
  handle:SetScript("OnDragStop", function(self)
    local window = self.kitMoving

    self.kitMoving = nil

    if window then
      window:StopMovingOrSizing()

      if window.onMoved then
        ask(window, window.onMoved, window)
      end
    end
  end)
  handle:SetScript("OnClick", function(self, mouse)
    click(self, mouse)
  end)

  return handle
end

KINDS.shortcut = function(owner, parent, spec)
  local button = Bricks.create("button", parent)

  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:EnableKeyboard(false)
  button.onClick = function(self, mouse)
    if mouse == "RightButton" then
      self.waiting = false
      self:EnableKeyboard(false)
      Kit.setShortcut(owner, self.spec.target, nil)
    else
      self.waiting = true
      self:EnableKeyboard(true)
    end

    self:Refresh()
  end
  button:SetScript("OnKeyDown", function(self, key)
    if not self.waiting or MODIFIERS[key] then
      return
    end

    self.waiting = false
    self:EnableKeyboard(false)

    if key ~= "ESCAPE" then
      local combo = (IsAltKeyDown and IsAltKeyDown() and "ALT-" or "")
        .. (IsControlKeyDown and IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or "") .. key

      Kit.setShortcut(owner, self.spec.target, combo)
    end

    self:Refresh()
  end)
  button:HookScript("OnHide", function(self)
    self.waiting = false
    self:EnableKeyboard(false)
  end)

  function button:kitRefresh()
    local key = Kit.shortcut(owner, self.spec.target)
    local shown = L.UI_SHORTCUT_NONE
    local label = textOf(self)

    if self.waiting then
      shown = L.UI_SHORTCUT_WAIT
    elseif key then
      shown = GetBindingText and GetBindingText(key, "KEY_") or key
    end

    self:SetLabel(label and format(L.UI_SHORTCUT_LINE, label, shown) or shown)
    self.tipTitle, self.tipBody = label or shown, L.UI_SHORTCUT_TIP
    autoWidth(self)
  end

  return button
end

local function rotate(texture, angle)
  local c, s = cos(angle), sin(angle)

  local function corner(u, v)
    return 0.5 + u * c - v * s, 0.5 + u * s + v * c
  end

  local ulx, uly = corner(-0.5, -0.5)
  local llx, lly = corner(-0.5, 0.5)
  local urx, ury = corner(0.5, -0.5)
  local lrx, lry = corner(0.5, 0.5)

  texture:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

Kit.rotate = rotate

KINDS.arrow = function(owner, parent, spec)
  local size = spec.size or S("kit.pointer")
  local frame = CreateFrame("Frame", nil, parent)

  frame:SetWidth(size)
  frame:SetHeight(size)
  frame.pointer = frame:CreateTexture(nil, "ARTWORK")
  frame.pointer:SetTexture(Bricks.media("pointer"))
  frame.pointer:SetAllPoints(frame)
  frame.pointer:Hide()
  paint(frame.pointer, "SetVertexColor", spec.color or "heading")
  frame.text = Bricks.text(frame, "small", "text")
  frame.text:SetPoint("TOP", frame, "BOTTOM", 0, -S("kit.gap"))
  frame.kitElapsed = 0

  function frame:kitAim()
    if self.fixed then
      self.angle = self.fixed
      rotate(self.pointer, self.fixed)
      return
    end

    if not self.targetX then
      self.pointer:Hide()
      return
    end

    if not GetPlayerMapPosition or not GetPlayerFacing then
      return
    end

    local px, py = GetPlayerMapPosition("player")

    if not px or (px == 0 and py == 0) then
      self.pointer:Hide()
      return
    end

    self.angle = atan2(-(self.targetX - px), -(self.targetY - py)) - (GetPlayerFacing() or 0)
    self.pointer:Show()
    rotate(self.pointer, self.angle)
  end

  function frame:SetTarget(x, y)
    self.targetX, self.targetY, self.fixed = x, y, nil
    self:kitAim()

    return self
  end

  function frame:SetAngle(angle)
    self.fixed, self.targetX, self.targetY = angle, nil, nil
    self.pointer:Show()
    self:kitAim()

    return self
  end

  function frame:ClearTarget()
    self.targetX, self.targetY, self.fixed = nil, nil, nil
    self.pointer:Hide()

    return self
  end

  frame:SetScript("OnUpdate", function(self, elapsed)
    self.kitElapsed = self.kitElapsed + (elapsed or 0)

    if self.kitElapsed >= S("kit.aim.every") then
      self.kitElapsed = 0
      self:kitAim()
    end
  end)

  function frame:kitRefresh()
    self.text:SetText(textOf(self) or "")
  end

  return frame
end

KINDS.model = function(owner, parent, spec)
  local model = CreateFrame(spec.dress and "DressUpModel" or "PlayerModel", nil, parent)

  model:SetWidth(spec.width or S("kit.model.width"))
  model:SetHeight(spec.height or S("kit.model.height"))
  model.kitFacing, model.kitZoom = 0, 0
  model:EnableMouse(true)
  model:EnableMouseWheel(true)
  model:SetScript("OnMouseDown", function(self, button)
    self.kitDrag = GetCursorPosition()
    self.kitButton = button or "LeftButton"
  end)
  model:SetScript("OnMouseUp", function(self)
    self.kitDrag = nil
  end)
  model:SetScript("OnUpdate", function(self)
    if self.kitDrag and IsMouseButtonDown ~= nil and not IsMouseButtonDown(self.kitButton) then
      self.kitDrag = nil
    end

    if self.kitDrag then
      local x = GetCursorPosition()

      self.kitFacing = self.kitFacing + (x - self.kitDrag) * S("kit.model.turn")
      self.kitDrag = x
      self:SetFacing(self.kitFacing)
    end
  end)
  model:SetScript("OnMouseWheel", function(self, delta)
    self.kitZoom = max(S("kit.model.zoom.min"), min(S("kit.model.zoom.max"), self.kitZoom + delta * S("kit.model.zoom.step")))
    self:SetPosition(self.kitZoom, 0, 0)
  end)

  function model:kitRefresh()
    local unit = evaluate(self, self.spec.unit)
    local creature = evaluate(self, self.spec.creature)
    local path = evaluate(self, self.spec.model)

    if unit and self.SetUnit then
      self:SetUnit(unit)
    end

    if creature and self.SetCreature then
      self:SetCreature(creature)
    end

    if path then
      self:SetModel(path)
    end

    self:SetFacing(self.kitFacing)
    self:SetPosition(self.kitZoom, 0, 0)
  end

  return model
end

local function canMove(frame)
  local mode = frame.spec and frame.spec.move or "ALWAYS"

  if frame.kitAttach or mode == "NONE" or mode == "HANDLE" or Parameters.value(nil, "locked") then
    return false
  end

  if frame.kitSecure and inCombat() then
    return false
  end

  if mode == "SHIFT" then
    return IsShiftKeyDown ~= nil and IsShiftKeyDown() and true or false
  end

  return true
end

Kit.canMove = canMove

local function deferred(window)
  return window.kitSecure or window.spec.combat == "HIDE"
end

local function settle(window, shown)
  window.kitWant = shown

  if window.kitSettling then
    return
  end

  window.kitSettling = true
  afterCombat(function()
    local want = window.kitWant

    window.kitSettling, window.kitWant, window.kitCombatShown = nil, nil, nil

    if want then
      window:Show()
    else
      window:Hide()
    end
  end)
end

local followers = setmetatable({}, WEAK)

local function fold(window)
  window.kitFolding = true
  window:Hide()
  window.kitFolding = nil
end

local function follow(window, host)
  local members = followers[host]

  if not members then
    members = setmetatable({}, WEAK)
    followers[host] = members
    host:HookScript("OnShow", function()
      for member in pairs(members) do
        if member.kitMeant and not member:IsShown() then
          member:Show()
        end
      end
    end)
    host:HookScript("OnHide", function()
      for member in pairs(members) do
        if member:IsShown() then
          fold(member)
        end
      end
    end)
  end

  members[window] = true
end

local function track(window)
  window.kitTracked = true
  window:HookScript("OnShow", function(self)
    local at = self.kitAttach

    if at and not self.kitFolding then
      self.kitMeant = true

      if not at.frame:IsShown() then
        fold(self)
      end
    end
  end)
  window:HookScript("OnHide", function(self)
    if self.kitAttach and not self.kitFolding then
      self.kitMeant = false
    end
  end)
end

local function lay(window, at)
  local host = at.frame
  local right = at.side == "RIGHT"
  local side = right and "RIGHT" or "LEFT"
  local anchor, edge, x, top, bottom

  window:ClearAllPoints()

  if at.inside then
    local insets = at.insets or {}

    anchor, edge = at.anchor or host, side
    x = right and 0 - (insets.right or 0) or (insets.left or 0)
    top, bottom = 0 - (insets.top or 0), insets.bottom or 0
    window:SetParent(host)
    window:SetFrameStrata(host:GetFrameStrata())
  else
    anchor, edge = host, right and "LEFT" or "RIGHT"
    x = right and (at.gap or 0) or 0 - (at.gap or 0)
    top, bottom = 0, 0
    window:SetParent(UIParent)
    window:SetFrameStrata("DIALOG")
  end

  window:SetPoint("TOP" .. edge, anchor, "TOP" .. side, x, top)
  window:SetPoint("BOTTOM" .. edge, anchor, "BOTTOM" .. side, x, bottom)
end

local function attachTo(window, at)
  local old = window.kitAttach and window.kitAttach.frame

  if old and old ~= at.frame then
    followers[old][window] = nil
  end

  window.kitAttach = at

  if not window.kitTracked then
    track(window)
  end

  follow(window, at.frame)
  lay(window, at)

  if window.kitMeant == nil then
    window.kitMeant = window:IsShown() and true or false
  end

  if not at.frame:IsShown() then
    if window:IsShown() then
      fold(window)
    end
  elseif window.kitMeant and not window:IsShown() then
    window:Show()
  end
end

function Kit.window(owner, id, spec)
  local key = "addon:" .. owner .. ":" .. id
  local existing = Windows.get(key)

  if existing and existing.kitWindow then
    return existing
  end

  local header = spec.header ~= false
  local escape = spec.escape

  if escape == nil then
    escape = header
  end

  local frame = Windows.create(key, escape and frameName("W", owner, id) or nil, owner)
  local pad = spec.padding or S("kit.padding")
  local top = pad

  frame.kitWindow = true
  frame.body = CreateFrame("Frame", nil, frame)

  if header then
    local height = S("kit.header")
    local control = min(S("kit.control"), height)
    local left = S("header.controls") == "LEFT"
    local side, facing, sign = "RIGHT", "LEFT", -1
    local head = CreateFrame("Frame", nil, frame)
    local close = Bricks.create("close", head)
    local anchor, near

    if left then
      side, facing, sign = "LEFT", "RIGHT", 1
    end

    head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    head:SetHeight(height)
    frame.head = head
    frame.title = Bricks.text(head, "normal", "heading")
    frame.titleCentered = S("header.title.align") == "CENTER"

    if frame.titleCentered then
      frame.title:SetPoint("CENTER", head, "CENTER", 0, 0)
    else
      frame.title:SetPoint(facing, head, facing, -sign * pad, 0)
    end

    local closeShift = (S("header.height") - S("header.close.size")) / 2 - S("header.close.y")

    close:SetWidth(S("header.close.width"))
    close:SetHeight(min(S("header.close.size"), height))
    close:SetPoint(side, head, side, sign * floor(pad / 2), closeShift)
    close:SetLabel(S("header.close.glyph"))
    close.onClick = function()
      frame:Close()
    end
    close.onShade = function()
      frame:SetShaded(not frame.kitShaded)
    end
    close.tipTitle = L.UI_CLOSE
    frame.close = close
    frame.headButtons = {}
    anchor, near = close, facing

    if not S("header.close.show") then
      close:Hide()
      anchor, near = head, side
    end

    for index, button in ipairs(spec.buttons or {}) do
      local element = Kit.create(owner, button.icon ~= nil and "icon" or "button", head, button, 4)

      element:SetHeight(control)

      if button.icon ~= nil then
        element:SetWidth(control)
      end

      element:ClearAllPoints()
      element:SetPoint(side, anchor, near, sign * floor(pad / 2), 0)
      element.kitTop = false
      anchor, near = element, facing
      frame.headButtons[index] = element
    end

    top = height + S("kit.spacing")
  end

  makeContainer(frame, spec, "VERTICAL", pad)
  scrollArea(frame, frame, spec):SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -top)
  adopt(frame, owner, "window", spec)

  frame:SetScript("OnDragStart", function(self)
    if canMove(self) then
      self:StartMoving()
    end
  end)

  function frame:kitResize(width, height)
    local minimum = self.spec.minWidth or 0
    local top = top + (self.kitBandRoom or 0)

    if self.kitAreaTop ~= top then
      self.kitAreaTop = top
      self.kitArea:ClearAllPoints()
      self.kitArea:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -top)
    end

    if self.title then
      local buttons = (self.close and self.close:IsShown() and self.close:GetWidth() or 0) + pad

      for _, element in ipairs(self.headButtons) do
        buttons = buttons + element:GetWidth() + floor(pad / 2)
      end

      local title = self.title:GetStringWidth() or 0

      if self.titleCentered then
        minimum = max(minimum, title + buttons * 2)
      else
        minimum = max(minimum, title + pad * 2 + buttons)
      end
    end

    local vertical, horizontal = scrolls(self)
    local room = barRoom()
    local outerWidth = self.spec.width
      or (horizontal and max(minimum, S("kit.scroll.width")))
      or max(minimum, width + (vertical and room or 0) + pad * 2)
    local outerHeight = self.spec.height
      or (vertical and S("kit.scroll.height"))
      or (top + height + (horizontal and room or 0) + pad)

    self.body:SetWidth(max(1, width))
    self.body:SetHeight(max(1, height))
    fitScroll(self, outerWidth - pad * 2, outerHeight - top - pad, width, height)

    if self.kitShaded then
      self:Resize(outerWidth, self.head:GetHeight())
    else
      self:Resize(outerWidth, not self.kitAttach and outerHeight or nil)
    end
  end

  function frame:SetShaded(state)
    self.kitShaded = state and self.head ~= nil or false

    if self.kitShaded then
      self.kitArea:Hide()
    else
      self.kitArea:Show()
    end

    if self.band then
      self.band:Refresh()
    end

    relayout(self, false)

    return self
  end

  function frame:kitRefresh()
    if self.title then
      self.title:SetText(textOf(self) or "")
      headBadge(self)
      problemViews[self] = "window"
    end

    if self.band then
      self.band:Refresh()
    end

    for _, element in ipairs(self.headButtons or {}) do
      element:Refresh()
    end

    refreshChildren(self)
  end

  function frame:Open()
    if deferred(self) then
      settle(self, true)
    else
      self:Show()
    end

    self:Refresh()

    return self
  end

  function frame:Close()
    if deferred(self) then
      settle(self, false)
    else
      self:Hide()
    end

    return self
  end

  function frame:Attach(attach)
    local merged = attach

    if type(attach) == "table" then
      merged = {}

      for key, value in pairs(self.kitAttach or {}) do
        merged[key] = value
      end

      for key, value in pairs(attach) do
        merged[key] = value
      end
    end

    checkAttach(owner, merged, 2)
    attachTo(self, merged)

    return self
  end

  function frame:Toggle()
    local shown = self.kitWant

    if shown == nil then
      shown = self:IsShown()
    end

    if shown then
      return self:Close()
    end

    return self:Open()
  end

  function frame:SetTitle(text)
    self.spec.text = text
    self.spec.key = nil
    self:Refresh()

    return self
  end

  if spec.band ~= false then
    local band = Kit.create(owner, "band", frame.head or CreateFrame("Frame", nil, frame), { addon = owner })

    band.window = frame
    band:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -top)
    band:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -top)
    band.onToggle = function(show)
      frame.kitBandRoom = show and band:GetHeight() + S("kit.spacing") or 0
      relayout(frame, false)
    end
    frame.band = band

    if band.on then
      band.onToggle(true)
    end
  end

  if spec.attach then
    attachTo(frame, spec.attach)
  else
    Windows.place(frame, function(window)
      local point = spec.point or { "CENTER" }

      window:SetPoint(point[1], point[2] or UIParent, point[3] or point[1], point[4] or 0, point[5] or 0)
    end)
  end

  frame.kitTop = true
  frame:Refresh()

  local shown = spec.shown

  if shown == nil then
    shown = not header
  end

  if shown then
    frame:Show()
  end

  return frame
end

local function ensureCursorAnchor()
  if not cursorAnchor then
    cursorAnchor = CreateFrame("Frame", nil, UIParent)
    cursorAnchor:SetHeight(1)
  end

  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale() or 1

  cursorAnchor:SetWidth(S("page.unit"))
  cursorAnchor:ClearAllPoints()
  cursorAnchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)

  return cursorAnchor
end

function Kit.openMenu(owner, items, anchor)
  if type(items) ~= "table" then
    return false
  end

  local list, current = {}, nil

  for index, item in ipairs(items) do
    local entry = {
      key = index,
      text = item.key and localized(owner, item.key) or tostring(item.text or ""),
      title = item.title,
      disabled = item.disabled,
    }

    if type(item.range) == "table" then
      local range = item.range
      local low, high = range.min or 0, range.max or 1

      entry.range = {
        min = low, max = high, step = rangeStep(low, high, range.step), percent = range.percent,
        value = range.value or low, format = range.format,
      }
      entry.onChange = function(value)
        if type(item.onChange) == "function" then
          local ok, err = pcall(item.onChange, value, item)

          if not ok then
            report(err, owner, "menu", "onChange")
          end
        end
      end
    end

    list[index] = entry

    if item.checked then
      current = index
    end
  end

  if not anchor then
    Bricks.closeMenu()
  end

  Bricks.openMenu(anchor or ensureCursorAnchor(), list, current, function(index)
    local item = items[index]

    if item and not item.disabled and type(item.onClick) == "function" then
      local ok, err = pcall(item.onClick, item)

      if not ok then
        report(err, owner, "menu", "onClick")
      end
    end
  end)

  return true
end

local function ensureGhost()
  if ghost then
    return ghost
  end

  ghost = CreateFrame("Frame", nil, UIParent)
  ghost:SetFrameStrata("TOOLTIP")
  ghost:SetWidth(S("kit.ghost.width"))
  ghost:SetHeight(S("kit.row"))
  Bricks.frame(ghost, "small", S("kit.ghost.color"), S("kit.ghost.border"))
  ghost.text = Bricks.text(ghost, "small", "selectedText")
  ghost.text:SetPoint("CENTER", ghost, "CENTER", 0, 0)
  ghost:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1

    self:ClearAllPoints()
    self:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / scale + S("kit.drag"), y / scale)
  end)
  ghost:Hide()

  return ghost
end

function Kit.beginDrag(owner, payload, source)
  local frame = ensureGhost()

  dragging = { owner = owner, payload = payload, source = source }
  frame.text:SetText(source and (textOf(source) or "") or "")
  frame:Show()

  return true
end

function Kit.dragging()
  return dragging
end

function Kit.endDrag()
  local current = dragging

  dragging = nil

  if ghost then
    ghost:Hide()
  end

  if not current then
    return false
  end

  local focus = GetMouseFocus and GetMouseFocus()
  local item = nil

  while focus do
    if item == nil and focus.kitItem ~= nil then
      item = focus.kitItem
    end

    if elements[focus] and focus.spec and focus.spec.onDrop and focus.owner == current.owner then
      if focus == current.source then
        return false
      end

      callback(focus, "onDrop", current.payload, current.source, item)

      return true
    end

    focus = focus.GetParent and focus:GetParent() or nil
  end

  return false
end

function Kit.receive(target)
  if dragging then
    return Kit.endDrag()
  end

  if not GetCursorInfo then
    return false
  end

  if type(target.spec.onDrop) ~= "function" then
    return false
  end

  local kind, id, detail = GetCursorInfo()

  if not kind then
    return false
  end

  if ClearCursor then
    ClearCursor()
  end

  callback(target, "onDrop", { kind = kind, id = id, detail = detail }, nil, nil)

  return true
end

function Kit.bindTarget(element)
  local owner, id = element.owner, element.spec.shortcut
  local name = element:GetName()

  if not name then
    name = frameName("S", owner, id)
    proxies[name] = proxies[name] or CreateFrame("Button", name, UIParent)
    proxies[name]:SetScript("OnClick", function()
      click(element, "LeftButton")
    end)
  end

  targets[owner] = targets[owner] or {}
  targets[owner][id] = name
  Kit.applyShortcuts()
end

function Kit.unbindTarget(element)
  local owner, id = element.owner, element.spec.shortcut
  local name = targets[owner] and targets[owner][id]

  if proxies[name] then
    proxies[name]:SetScript("OnClick", nil)
  end

  if name then
    targets[owner][id] = nil
    Kit.applyShortcuts()
  end
end

function Kit.applyShortcuts()
  if not DB.isAttached() then
    return false
  end

  return afterCombat(function()
    if ClearOverrideBindings then
      ClearOverrideBindings(bindOwner)
    end

    for owner, list in pairs(targets) do
      local keys = saved(owner).shortcuts or {}

      for id, name in pairs(list) do
        local key = keys[id]

        if type(key) == "string" and key ~= "" and SetOverrideBindingClick then
          SetOverrideBindingClick(bindOwner, false, key, name, "LeftButton")
        end
      end
    end
  end)
end

function Kit.shortcut(owner, id)
  local data = saved(owner)

  return data and data.shortcuts and data.shortcuts[id]
end

function Kit.setShortcut(owner, id, key)
  local data = saved(owner)

  if not data then
    return false
  end

  data.shortcuts = data.shortcuts or {}
  data.shortcuts[id] = key
  Kit.applyShortcuts()

  return true
end

local function buildDialog()
  local frame = Bricks.Container("EbonAPIKitDialog")
  local copyField = CreateFrame("Frame", nil, frame)
  local copy = CreateFrame("EditBox", nil, copyField)

  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, S("kit.dialog.offset"))

  if type(UISpecialFrames) == "table" then
    UISpecialFrames[#UISpecialFrames + 1] = "EbonAPIKitDialog"
  end

  frame.title = Bricks.text(frame, "normal", "heading")
  frame.text = Bricks.text(frame, "normal", "text")
  frame.text:SetJustifyH("CENTER")
  frame.choices = CreateFrame("Frame", nil, frame)
  frame.choices.scroll = Bricks.create("scroll", frame.choices)
  frame.choices.scroll:SetAllPoints(frame.choices)
  frame.rows = Bricks.slotPool("row")
  frame.input = Bricks.create("input", frame)
  frame.input.edit:SetScript("OnEnterPressed", function()
    Kit.closeDialog(true)
  end)
  copy:SetMultiLine(true)
  copy:SetAutoFocus(false)
  Bricks.font(copy, "small")
  copy:SetTextInsets(S("widgets.input.padding"), S("widgets.input.padding"), S("widgets.input.paddingY"),
    S("widgets.input.paddingY"))
  Bricks.frame(copyField, "small", S("kit.dialog.field.color"), S("kit.dialog.field.border"))
  paint(copy, "SetTextColor", "text")
  copy:SetScript("OnTextChanged", function(self)
    if self:GetText() ~= frame.copyText then
      self:SetText(frame.copyText or "")
      self:HighlightText()
    end
  end)
  copy:SetScript("OnEscapePressed", function()
    Kit.closeDialog(false)
  end)
  frame.copy, frame.copyField = copy, copyField
  frame.copyArea = Bricks.editArea(copyField, copy)
  frame.copyArea:SetMultiLine(true)
  frame.hint = Bricks.text(frame, "small", "muted")
  frame.accept = Bricks.create("button", frame)
  frame.cancel = Bricks.create("button", frame)
  frame.accept.onClick = function()
    Kit.closeDialog(true)
  end
  frame.cancel.onClick = function()
    Kit.closeDialog(false)
  end
  frame:HookScript("OnHide", function(self)
    if self.options then
      Kit.closeDialog(false)
    end
  end)

  return frame
end

function Kit.openDialog(options)
  dialog = dialog or buildDialog()

  if dialog.options then
    Kit.closeDialog(false)
  end

  local pad, spacing = S("kit.padding"), S("kit.spacing")
  local width = S("kit.dialog.width")
  local inner = width - pad * 2
  local buttonHeight = S("widgets.button.height")
  local y = pad

  dialog.options = options
  dialog.choice, dialog.chosen = options.value, nil

  if options.title and options.title ~= "" then
    Bricks.font(dialog.title, S("kit.dialog.title.font"))
    paint(dialog.title, "SetTextColor", S("kit.dialog.title.color"))
    dialog.title:SetJustifyH(S("kit.dialog.title.align"))
    dialog.title:SetWidth(inner)
    dialog.title:SetText(options.title)
    dialog.title:ClearAllPoints()
    dialog.title:SetPoint("TOP", dialog, "TOP", 0, -y)
    dialog.title:Show()
    y = y + (dialog.title:GetStringHeight() or 0) + spacing
  else
    dialog.title:Hide()
  end

  dialog.text:SetWidth(inner)
  dialog.text:SetText(options.text or "")
  dialog.text:ClearAllPoints()
  dialog.text:SetPoint("TOP", dialog, "TOP", 0, -y)
  y = y + (dialog.text:GetStringHeight() or 0) + spacing

  dialog.rows:releaseAll()

  if type(options.choices) == "table" and #options.choices > 0 then
    local rowHeight = S("kit.row")
    local height = min(#options.choices, S("kit.dialog.choices")) * rowHeight
    local rowWidth = inner - S("widgets.scroll.width") - S("kit.gap")
    local scroll = dialog.choices.scroll

    dialog.choices:SetWidth(inner)
    dialog.choices:SetHeight(height)
    dialog.choices:ClearAllPoints()
    dialog.choices:SetPoint("TOPLEFT", dialog, "TOPLEFT", pad, -y)
    scroll:SetView(rowWidth, height)
    scroll:SetOffset(0)

    for index, choice in ipairs(options.choices) do
      local row = dialog.rows:acquire(scroll.child)

      row:SetWidth(rowWidth)
      row:SetHeight(rowHeight)
      row:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -(index - 1) * rowHeight)
      row:SetLabel(choice.text)
      row:SetTextKey(nil)
      row:SetDisabledState(false)

      if dialog.chosen == nil and options.value ~= nil and choice.value == options.value then
        dialog.chosen = index
      end

      row:SetSelected(dialog.chosen == index)
      row.kitIndex = index
      row.onClick = function()
        dialog.choice, dialog.chosen = choice.value, index

        for _, other in ipairs(dialog.rows.used) do
          other:SetSelected(other.kitIndex == index)
        end

        dialog.accept:SetDisabledState(false)
      end
    end

    scroll:SetContentHeight(#options.choices * rowHeight)
    dialog.choices:Show()
    dialog.accept:SetDisabledState(dialog.choice == nil)
    y = y + height + spacing
  else
    dialog.choices:Hide()
    dialog.accept:SetDisabledState(false)
  end

  if options.input ~= nil then
    dialog.input:SetWidth(inner)
    dialog.input:SetTitle("")
    dialog.input:SetLines(nil)
    dialog.input.edit:SetMaxLetters(options.maxLetters or 0)
    dialog.input:SetValue(options.input)
    dialog.input:ClearAllPoints()
    dialog.input:SetPoint("TOPLEFT", dialog, "TOPLEFT", pad, -y)
    dialog.input:Show()
    dialog.input.edit:SetFocus()
    y = y + dialog.input:GetHeight() + spacing
  else
    dialog.input:Hide()
  end

  if options.copy ~= nil then
    dialog.copyText = options.copy
    dialog.copyField:SetWidth(inner)
    dialog.copyField:SetHeight(S("kit.dialog.copy"))
    dialog.copyField:ClearAllPoints()
    dialog.copyField:SetPoint("TOPLEFT", dialog, "TOPLEFT", pad, -y)
    dialog.copy:SetText(options.copy)
    dialog.copyArea:Fit()
    dialog.copyArea.scroll:SetOffset(0)
    dialog.copyField:Show()
    dialog.copy:Show()
    dialog.copy:SetFocus()
    dialog.copy:HighlightText()
    y = y + S("kit.dialog.copy") + spacing
    dialog.hint:SetText(L.UI_COPY_HINT)
    dialog.hint:ClearAllPoints()
    dialog.hint:SetPoint("TOP", dialog, "TOP", 0, -y)
    dialog.hint:Show()
    y = y + (dialog.hint:GetStringHeight() or 0) + spacing
  else
    dialog.copyField:Hide()
    dialog.copy:Hide()
    dialog.hint:Hide()
  end

  for _, button in ipairs({ dialog.accept, dialog.cancel }) do
    button:SetHeight(buttonHeight)
    button:ClearAllPoints()
  end

  dialog.accept:SetLabel(options.accept or L.UI_OK)
  dialog.accept:Fit(max(S("kit.dialog.button"), dialog.accept:TextWidth()))

  if options.cancel then
    dialog.cancel:SetLabel(options.cancel)
    dialog.cancel:Fit(max(S("kit.dialog.button"), dialog.cancel:TextWidth()))
    dialog.accept:SetPoint("TOPRIGHT", dialog, "TOP", -floor(spacing / 2), -y)
    dialog.cancel:SetPoint("TOPLEFT", dialog, "TOP", floor(spacing / 2), -y)
    dialog.cancel:Show()
  else
    dialog.accept:SetPoint("TOP", dialog, "TOP", 0, -y)
    dialog.cancel:Hide()
  end

  y = y + buttonHeight + pad
  dialog:Resize(width, y)
  dialog:Show()

  return dialog
end

function Kit.closeDialog(accepted)
  if not dialog or not dialog.options then
    return false
  end

  local options = dialog.options
  local value = nil
  local fn = accepted and options.onAccept or options.onCancel

  if options.input ~= nil then
    value = dialog.input.edit:GetText() or ""
  elseif options.choices ~= nil then
    value = dialog.choice
  end

  dialog.options = nil
  dialog:Hide()

  if type(fn) == "function" then
    local ok, err = pcall(fn, value)

    if not ok then
      report(err, options.owner, "dialog", accepted and "onAccept" or "onCancel")
    end
  end

  return true
end

function Kit.dialog()
  return dialog
end

local function stackToasts()
  local y = S("kit.toast.top")
  local shown = {}

  for _, toast in ipairs(toasts) do
    if toast:IsShown() then
      shown[#shown + 1] = toast
    end
  end

  sort(shown, function(first, second)
    return first.kitArrival < second.kitArrival
  end)

  for _, toast in ipairs(shown) do
    toast:ClearAllPoints()
    toast:SetPoint("TOP", UIParent, "TOP", 0, -y)
    y = y + toast:GetHeight() + S("kit.spacing")
  end
end

function Kit.dismiss(toast)
  toast:Hide()
  toast.onClick = nil
  stackToasts()
end

local function toastFrame()
  for _, toast in ipairs(toasts) do
    if not toast:IsShown() then
      return toast
    end
  end

  local toast = CreateFrame("Button", nil, UIParent)

  toast:SetFrameStrata("FULLSCREEN_DIALOG")
  Bricks.frame(toast, "small", "bg", "border")
  toast.icon = toast:CreateTexture(nil, "ARTWORK")
  trim(toast.icon)
  toast.title = Bricks.text(toast, "small", "heading")
  toast.title:SetJustifyH("LEFT")
  toast.text = Bricks.text(toast, "normal", "text")
  toast.text:SetJustifyH("LEFT")
  toast:SetScript("OnClick", function(self)
    local fn = self.onClick

    Kit.dismiss(self)

    if type(fn) == "function" then
      local ok, err = pcall(fn)

      if not ok then
        report(err, self.owner, "toast", "onClick")
      end
    end
  end)
  toast:SetScript("OnUpdate", function(self)
    local left = (self.expires or 0) - GetTime()
    local fade = S("kit.toast.fade")

    if left <= 0 then
      Kit.dismiss(self)
    elseif left < fade then
      self:SetAlpha(left / fade)
    end
  end)
  toast:Hide()
  toasts[#toasts + 1] = toast

  return toast
end

function Kit.notify(owner, text, spec)
  local toast = toastFrame()
  local pad = S("kit.padding")
  local width = S("kit.toast.width")
  local left = pad
  local iconSize = S("kit.toast.icon")

  spec = spec or {}

  local icon = Lib.icon(spec.icon) or EbonAPI:AddonIcon(owner)

  if icon then
    toast.icon:SetTexture(icon)
    toast.icon:SetWidth(iconSize)
    toast.icon:SetHeight(iconSize)
    toast.icon:ClearAllPoints()
    toast.icon:SetPoint("TOPLEFT", toast, "TOPLEFT", pad, -pad)
    toast.icon:Show()
    left = pad * 2 + iconSize
  else
    toast.icon:Hide()
  end

  toast.title:SetWidth(width - left - pad)
  toast.title:SetText(spec.title or owner)
  toast.title:ClearAllPoints()
  toast.title:SetPoint("TOPLEFT", toast, "TOPLEFT", left, -pad)
  toast.text:SetWidth(width - left - pad)
  toast.text:SetText(tostring(text or ""))
  toast.text:ClearAllPoints()
  toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -S("kit.gap"))
  toast:SetWidth(width)
  toast:SetHeight(max(pad * 2 + (icon and iconSize or 0),
    pad * 2 + (toast.title:GetStringHeight() or 0) + S("kit.gap") + (toast.text:GetStringHeight() or 0)))
  arrivals = arrivals + 1
  toast.kitArrival = arrivals
  toast.expires = GetTime() + (spec.duration or S("kit.toast.duration"))
  toast.onClick = spec.onClick
  toast.owner = owner
  toast:SetAlpha(1)
  toast:Show()
  stackToasts()

  if spec.sound and PlaySound then
    PlaySound(spec.sound)
  end

  return toast
end

function Kit.combat(active)
  for element in pairs(elements) do
    local mode = element.kitWindow and element.spec and element.spec.combat

    if mode == "HIDE" and not element.kitSecure then
      if active then
        element.kitCombatShown = element:IsShown()
        element:Hide()
      elseif element.kitCombatShown then
        element.kitCombatShown = nil
        element:Show()
      end
    elseif mode == "FADE" then
      element:SetAlpha(active and S("kit.combatAlpha") or 1)
    end
  end
end

function Kit.refreshAll(owner)
  for element in pairs(elements) do
    if element.kitTop and (not owner or element.owner == owner) then
      element:Refresh()
    end
  end
end

Bus.on("PLAYER_REGEN_DISABLED", function()
  Kit.combat(true)
end)

Bus.on("PLAYER_REGEN_ENABLED", function()
  local waiting = pending

  pending = {}

  for _, fn in ipairs(waiting) do
    Lib.safeCall(fn)
  end

  Kit.combat(false)
end)

EbonAPI:On("LANGUAGE_CHANGED", function()
  Kit.refreshAll()
end)

local function problemsChanged(event, addon)
  for view, kind in pairs(problemViews) do
    if kind == "band" then
      if view.addonName == addon then
        view:Refresh()
      end
    elseif view.owner == addon and view.head then
      headBadge(view)
    end
  end
end

EbonAPI:On("PROBLEM", problemsChanged)
EbonAPI:On("PROBLEM_CLOSED", problemsChanged)

local RESCALE = "EbonAPI.Kit.rescale"

local function remeasure()
  Bus.tick(RESCALE, S("kit.rescale.delay"), function()
    Bus.untick(RESCALE)
    Kit.refreshAll()
  end)
end

Bus.on("UI_SCALE_CHANGED", remeasure)
Bus.on("DISPLAY_SIZE_CHANGED", remeasure)
Bus.on("PLAYER_ENTERING_WORLD", remeasure)

EbonAPI:On("PARAMETER_CHANGED", function(_, name)
  if name == "scale" then
    remeasure()
  end
end)

EbonAPI:On("READY", function()
  Kit.refreshAll()
  Kit.applyShortcuts()
end)

local function checkId(owner, id, what)
  if type(id) ~= "string" or not find(id, "^[%w_]+$") then
    error(format("EbonAPI: %s: %s expects an id of letters, digits or _, got %s", owner, what, tostring(id)), 3)
  end
end

function Handle:Window(id, spec)
  checkId(self.addonName, id, "api:Window")

  if spec ~= nil and type(spec) ~= "table" then
    error(format("EbonAPI: %s: api:Window expects a table, got %s", self.addonName, type(spec)), 2)
  end

  validate(self.addonName, "window", spec or {}, 2)

  local window = Kit.window(self.addonName, id, spec or {})

  return window
end

function Handle:Create(kind, parent, spec)
  local element = Kit.create(self.addonName, kind, parent, spec)

  return element
end

function Handle:Elements()
  return Kit.kinds()
end

function Handle:OpenMenu(items, anchor)
  return Kit.openMenu(self.addonName, items, anchor)
end

function Handle:Dialog(spec)
  if type(spec) ~= "table" then
    error(format("EbonAPI: %s: api:Dialog expects a table, got %s", self.addonName, type(spec)), 2)
  end

  local owner = self.addonName
  local choices = nil

  local function text(value, key)
    return key and localized(owner, key) or value
  end

  if type(spec.choices) == "table" then
    choices = {}

    for index, choice in ipairs(spec.choices) do
      if type(choice) ~= "table" then
        error(format("EbonAPI: %s: api:Dialog choices expects tables with text and value, got %s at %d", owner,
          tostring(choice), index), 2)
      end

      choices[index] = { value = choice.value, text = text(tostring(choice.text or ""), choice.key) }
    end
  end

  return Kit.openDialog({
    title = text(spec.title, spec.titleKey),
    text = text(spec.text, spec.textKey),
    accept = text(spec.accept, spec.acceptKey),
    cancel = text(spec.cancel, spec.cancelKey),
    input = spec.input,
    maxLetters = spec.maxLetters,
    choices = choices,
    value = spec.value,
    onAccept = spec.onAccept,
    onCancel = spec.onCancel,
    owner = owner,
  })
end

function Handle:Confirm(text, onYes, onNo)
  return self:Dialog({ text = text, accept = L.UI_YES, cancel = L.UI_NO, onAccept = onYes, onCancel = onNo })
end

function Handle:Prompt(text, default, onAccept, onCancel)
  return self:Dialog({
    text = text, input = default or "", accept = L.UI_OK, cancel = L.UI_CANCEL,
    onAccept = onAccept, onCancel = onCancel,
  })
end

function Handle:CopyBox(text, title)
  return Kit.openDialog({ text = title or "", copy = tostring(text or ""), accept = L.UI_CLOSE })
end

function Handle:Notify(text, spec)
  if spec ~= nil and type(spec) ~= "table" then
    error(format("EbonAPI: %s: api:Notify expects a table, got %s", self.addonName, type(spec)), 2)
  end

  return Kit.notify(self.addonName, text, spec)
end

function Handle:AfterCombat(fn)
  if type(fn) ~= "function" then
    error(format("EbonAPI: %s: api:AfterCombat expects a function, got %s", self.addonName, type(fn)), 2)
  end

  local owner = self.addonName

  return afterCombat(function()
    local ok, err = pcall(fn)

    if not ok then
      report(err, owner, "afterCombat", "callback")
    end
  end)
end

function Handle:GetShortcut(id)
  return Kit.shortcut(self.addonName, id)
end

function Handle:SetShortcut(id, key)
  checkId(self.addonName, id, "api:SetShortcut")

  return Kit.setShortcut(self.addonName, id, key)
end

function Handle:RefreshUI()
  Kit.refreshAll(self.addonName)
end
