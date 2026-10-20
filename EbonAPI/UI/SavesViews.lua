EbonAPI = EbonAPI or {}
EbonAPI.SavesViews = { views = {} }

-- The cells and the three views (list, grid, gauge) of the "saves" widget, rings and icons (atlas).
-- This file holds the shared pieces (atlas coordinates, ring, state icon) and the list view; the grid and the
-- gauge views, and the drawer, come with the next tasks. See the contract, section 7.

local Views = EbonAPI.SavesViews
local Bricks = EbonAPI.Bricks
local Data = EbonAPI.SavesData

local floor, max, min = math.floor, math.max, math.min
local ipairs, pairs, pcall, type = ipairs, pairs, pcall, type
local lower = string.lower
local S = Bricks.value
local PAD = 4
local DOUBLE = 0.4
local PCT = 32

local ICONS = {
  list = 0, grid = 1, gauge = 2, search = 3, sort = 4, plus = 5, close = 6, check = 7, play = 8, half = 9,
  lock = 10, warn = 11, cross = 12, bolt = 13, dots = 14, left = 15, right = 16, star = 17, starOn = 18,
}

Views.ICONS = ICONS

-- SetTexCoord values of the case `k` of an atlas of 8 x 8 cases (case 0 at the top left).
local function cellCoords(k)
  local column, line = k % 8, floor(k / 8)

  return column / 8, (column + 1) / 8, line / 8, (line + 1) / 8
end

function Views.ringCoords(k)
  return cellCoords(max(0, min(63, floor(k or 0))))
end

function Views.iconCoords(name)
  return cellCoords(ICONS[name] or 63)
end

-- Frame:SetShown does not exist in the 3.3.5 client.
local function show(target, on)
  if on then
    target:Show()
  else
    target:Hide()
  end
end

local function lookKey(name)
  return S("widgets.saves." .. name)
end

-- A texture of the icon atlas, tinted by a palette key.
local function iconTexture(parent, name, key, layer)
  local texture = parent:CreateTexture(nil, layer or "OVERLAY")

  texture:SetTexture(Bricks.media("icons"))
  Bricks.paint(texture, "SetVertexColor", key or "text")
  Views.setIcon(texture, name)

  return texture
end

function Views.setIcon(texture, name)
  texture:SetTexCoord(Views.iconCoords(name))
  texture.icon = name
end

Views.iconTexture = iconTexture

-- The three superposed textures of a ring: track, activated now, owned.
local function newRing(parent, size)
  local ring = { size = size }

  for _, name in ipairs({ "track", "now", "owned" }) do
    local texture = parent:CreateTexture(nil, "ARTWORK")

    texture:SetTexture(Bricks.media("ring"))
    texture:SetWidth(size)
    texture:SetHeight(size)
    ring[name] = texture
  end

  Bricks.paint(ring.track, "SetVertexColor", "muted")
  ring.track:SetAlpha(0.3)
  ring.track:SetTexCoord(Views.ringCoords(40))
  Bricks.paint(ring.now, "SetVertexColor", lookKey("now"))

  function ring:SetPoint(...)
    for _, name in ipairs({ "track", "now", "owned" }) do
      self[name]:ClearAllPoints()
      self[name]:SetPoint(...)
    end
  end

  function ring:Set(item)
    local owned, now = item.owned or 0, item.now or 0
    local ownedCase = floor(owned * 40 + 0.5)
    local nowCase = min(40, floor((owned + now) * 40 + 0.5))

    Bricks.paint(self.owned, "SetVertexColor", item.state == "active" and lookKey("now") or lookKey("owned"))

    if ownedCase > 0 then
      self.owned:SetTexCoord(Views.ringCoords(min(40, ownedCase)))
      self.owned:Show()
    else
      self.owned:Hide()
    end

    if nowCase > ownedCase then
      self.now:SetTexCoord(Views.ringCoords(nowCase))
      self.now:Show()
    else
      self.now:Hide()
    end

    self.ownedCase, self.nowCase = ownedCase, nowCase
  end

  return ring
end

Views.newRing = newRing

-- The icon and the colour that tell the state when nothing can be activated.
local function stateIcon(item)
  if item.state == "active" then
    return "check", "success"
  elseif item.state == "blocked" then
    return "warn", "caution"
  elseif item.state == "error" then
    return "cross", "danger"
  end

  return "lock", "muted"
end

local function frameKeys(frame, prefix)
  local fill, border = S("widgets.saves." .. prefix .. ".fill"), S("widgets.saves." .. prefix .. ".border")

  if type(fill) ~= "string" or fill == "" or type(border) ~= "string" or border == "" then
    Bricks.unframe(frame)
    return
  end

  Bricks.frame(frame, lower(S("widgets.saves." .. prefix .. ".frame")), fill, border)
end

Views.frameKeys = frameKeys

local function paintCell(cell)
  show(cell.hoverFill, cell.hovered and not cell.selected)
  show(cell.chosen, cell.selected and true or false)
end

-- A gauge row is always framed: when the skin gives no fill or border, the rows use well / borderDim.
local function gaugeFrame(cell, selected)
  local fill, border = lookKey("row.fill"), lookKey("row.border")
  local style = lower(lookKey("row.frame"))

  if type(fill) ~= "string" or fill == "" then
    fill = "well"
  end

  if type(border) ~= "string" or border == "" then
    border = "borderDim"
  end

  cell.border = selected and lookKey("row.selected") or border
  Bricks.frame(cell, style == "flat" and "small" or style, fill, cell.border)
end

local function tipBody(item)
  if item.marked and item.marked ~= "" then
    return item.tip and (item.marked .. "\n" .. item.tip) or item.marked
  end

  return item.tip
end

-- Plugs the mouse on a cell of the list: choose, activate (double click), menu, tooltip, hover.
local function wireCell(box, cell)
  cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  cell:SetScript("OnClick", function(self, button)
    local item = self.item

    if not item then
      return
    end

    if button == "RightButton" then
      box:OpenMenu(item.id, self)
      return
    end

    local now = GetTime and GetTime() or 0

    if self.lastClick and now - self.lastClick <= DOUBLE then
      self.lastClick = nil
      box:DoubleClick(item.id)
      return
    end

    self.lastClick = now
    box:Pick(item.id)
  end)
  cell:SetScript("OnEnter", function(self)
    local item = self.item

    self.hovered = true
    paintCell(self)

    if item then
      Bricks.tip(self, item.name, tipBody(item))
      box:Hover(item.id, self)
    end
  end)
  cell:SetScript("OnLeave", function(self)
    self.hovered = false
    paintCell(self)
    Bricks.hideTip()
    box:Unhover()
  end)
end

local function newCell(box, gauge)
  local cell = CreateFrame("Button", nil, box.scroll.child)
  local fontRole = lookKey("font")
  local solid = Bricks.media("solid")

  cell.hoverFill = cell:CreateTexture(nil, "BACKGROUND")
  cell.hoverFill:SetTexture(solid)
  cell.hoverFill:SetAllPoints(cell)
  Bricks.paint(cell.hoverFill, "SetVertexColor", lookKey("row.hover"))
  cell.hoverFill:Hide()
  cell.chosen = cell:CreateTexture(nil, "BACKGROUND")
  cell.chosen:SetTexture(solid)
  cell.chosen:SetAllPoints(cell)
  Bricks.paint(cell.chosen, "SetVertexColor", lookKey("row.selected"))
  cell.chosen:SetAlpha(0.38)
  cell.chosen:Hide()
  cell.gauge = gauge and true or false

  if gauge then
    -- The row is its own bar: owned part, then the part activated now (textures of the solid media).
    cell.barOwned = cell:CreateTexture(nil, "BORDER")
    cell.barOwned:SetTexture(solid)
    cell.barOwned:SetAlpha(0.5)
    cell.barNow = cell:CreateTexture(nil, "BORDER")
    cell.barNow:SetTexture(solid)
    cell.barNow:SetAlpha(0.5)
    Bricks.paint(cell.barNow, "SetVertexColor", lookKey("now"))
    cell.pct = Bricks.text(cell, lookKey("small.font"), "muted")
    cell.pct:SetJustifyH("RIGHT")
    cell.pct:SetWidth(PCT)

    if cell.pct.SetWordWrap then
      cell.pct:SetWordWrap(false)
    end
  else
    cell.ring = newRing(cell, lookKey("ring.size"))
  end

  cell.name = Bricks.text(cell, fontRole, "text")
  cell.name:SetJustifyH("LEFT")

  if cell.name.SetWordWrap then
    cell.name:SetWordWrap(false)
  end

  cell.bolt = iconTexture(cell, "bolt", lookKey("later"))
  cell.mark = iconTexture(cell, "warn", "caution")
  cell.state = iconTexture(cell, "lock", "muted")
  cell.go = CreateFrame("Button", nil, cell)
  cell.go.icon = iconTexture(cell.go, "play", "success")
  cell.go.icon:SetAllPoints(cell.go)
  cell.go:SetScript("OnClick", function(self)
    if cell.item then
      box:Activate(cell.item.id)
    end
  end)
  cell.go:SetScript("OnEnter", function(self)
    local item = cell.item

    cell.hovered = true
    paintCell(cell)

    if item then
      Bricks.tip(self, item.name, tipBody(item))
      box:Hover(item.id, cell)
    end
  end)
  cell.go:SetScript("OnLeave", function()
    cell.hovered = false
    paintCell(cell)
    Bricks.hideTip()
    box:Unhover()
  end)
  wireCell(box, cell)

  function cell:SetSelected(selected)
    self.selected = selected and true or false
    paintCell(self)
  end

  -- Gauge rows: the two bars follow the owned and the activated parts of the save.
  function cell:SetBars(item)
    local inner = max(0, self:GetWidth() - 2)
    local owned = item.state == "active" and 1 or min(1, max(0, item.owned or 0))
    local now = item.state == "active" and 0 or min(1 - owned, max(0, item.now or 0))

    Bricks.paint(self.barOwned, "SetVertexColor", item.state == "active" and lookKey("now") or lookKey("owned"))

    for _, part in ipairs({ { self.barOwned, 0, owned }, { self.barNow, owned, now } }) do
      local bar, from, share = part[1], part[2], part[3]

      bar:ClearAllPoints()
      bar:SetPoint("TOPLEFT", self, "TOPLEFT", 1 + inner * from, -1)
      bar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 1 + inner * from, 1)
      bar:SetWidth(max(0.01, inner * share))
      show(bar, share > 0)
    end

    self.ownedShare, self.nowShare = owned, now
  end

  function cell:SetItem(item, state)
    local height = self:GetHeight()
    local ringSize = lookKey("ring.size")
    local side = max(12, height - 2 * PAD)
    local icon, key = stateIcon(item)
    local nameLeft = PAD * 2 + (self.gauge and 0 or ringSize)
    local nameRight = side + PAD * 2
    local pctSpace = self.gauge and (PCT + 2) or 0

    self.item = item
    self.saveId = item.id

    if self.ring then
      self.ring:Set(item)
      self.ring:SetPoint("LEFT", self, "LEFT", PAD, 0)
    else
      self:SetBars(item)
      self.pct:SetText(floor((item.state == "active" and 1 or (item.owned or 0)) * 100 + 0.5) .. "%")
      self.pct:ClearAllPoints()
      self.pct:SetPoint("RIGHT", self, "RIGHT", -nameRight, 0)
    end

    self.name:SetText(item.name or "")
    Bricks.paint(self.name, "SetTextColor",
      (item.state == "short" or item.state == "blocked" or item.state == "error") and "muted" or "text")

    self.go:SetWidth(side)
    self.go:SetHeight(side)
    self.go:ClearAllPoints()
    self.go:SetPoint("RIGHT", self, "RIGHT", -PAD, 0)
    self.state:SetWidth(side - 4)
    self.state:SetHeight(side - 4)
    self.state:ClearAllPoints()
    self.state:SetPoint("RIGHT", self, "RIGHT", -PAD - 2, 0)
    Views.setIcon(self.state, icon)
    Bricks.paint(self.state, "SetVertexColor", key)

    if item.state ~= "active" and item.canActivate then
      self.go:Show()
      self.state:Hide()
    else
      self.go:Hide()
      self.state:Show()
    end

    local extra = 0

    for _, name in ipairs({ "bolt", "mark" }) do
      local texture = self[name]
      local on = (name == "bolt" and item.progressive) or (name == "mark" and item.marked)

      texture:SetWidth(12)
      texture:SetHeight(12)
      texture:ClearAllPoints()

      if on then
        texture:SetPoint("RIGHT", self, "RIGHT", -(nameRight + pctSpace + extra), 0)
        texture:Show()
        extra = extra + 14
      else
        texture:Hide()
      end
    end

    self.name:ClearAllPoints()
    self.name:SetPoint("LEFT", self, "LEFT", nameLeft, 0)
    self.name:SetPoint("RIGHT", self, "RIGHT", -(nameRight + pctSpace + extra), 0)
    self.hovered = false
    self.selected = state and state.selected == item.id and true or false
    paintCell(self)
  end

  return cell
end

local function newHeader(box)
  local header = CreateFrame("Button", nil, box.scroll.child)

  header:RegisterForClicks("LeftButtonUp")
  header.chevron = header:CreateTexture(nil, "OVERLAY")
  header.chevron:SetTexture(Bricks.media("chevron"))
  header.chevron:SetWidth(10)
  header.chevron:SetHeight(10)
  header.chevron:SetPoint("LEFT", header, "LEFT", PAD, 0)
  Bricks.paint(header.chevron, "SetVertexColor", "muted")
  header.title = Bricks.text(header, lookKey("font"), lookKey("group.color"))
  header.title:SetJustifyH("LEFT")
  header.count = Bricks.text(header, lookKey("small.font"), "muted")
  header.count:SetJustifyH("RIGHT")
  header.check = iconTexture(header, "check", "success")
  header.check:SetWidth(10)
  header.check:SetHeight(10)
  header.dots = CreateFrame("Button", nil, header)
  header.dots:SetWidth(16)
  header.dots.icon = iconTexture(header.dots, "dots", "muted")
  header.dots.icon:SetAllPoints(header.dots)

  for _, fs in ipairs({ header.title, header.count }) do
    if fs.SetWordWrap then
      fs:SetWordWrap(false)
    end
  end

  header:SetScript("OnClick", function(self)
    if self.groupId ~= nil then
      box:ToggleFold(self.groupId)
    end
  end)
  header.dots:SetScript("OnClick", function()
    if header.groupId ~= nil then
      box:OpenGroupMenu(header.groupId, header.dots)
    end
  end)

  function header:SetBlock(block, shut)
    local group = block.group
    local active = 0

    for _, item in ipairs(block.items) do
      if item.state == "active" then
        active = active + 1
      end
    end

    self.groupId = group.id
    self.title:SetText(Bricks.label(group.name, "widgets.saves.group.upper"))
    self.count:SetText(active > 0 and (#block.items .. " · " .. active) or tostring(#block.items))
    show(self.check, active > 0)
    self.chevron:SetTexCoord(0, 1, shut and 0 or 1, shut and 1 or 0)

    local hasMenu = group.id ~= ""

    self.dots:SetHeight(max(12, self:GetHeight()))
    self.dots:ClearAllPoints()
    self.dots:SetPoint("RIGHT", self, "RIGHT", -PAD, 0)
    show(self.dots, hasMenu)

    local right = hasMenu and (PAD + 18) or PAD

    self.check:ClearAllPoints()
    self.check:SetPoint("RIGHT", self, "RIGHT", -right, 0)
    self.count:ClearAllPoints()
    self.count:SetPoint("RIGHT", self, "RIGHT", -(right + (active > 0 and 12 or 0)), 0)
    self.title:ClearAllPoints()
    self.title:SetPoint("LEFT", self.chevron, "RIGHT", 4, 0)
    self.title:SetPoint("RIGHT", self.count, "LEFT", -4, 0)
  end

  return header
end

-- The base of the three views (its Layout is the one of the list and the gauge): groups, cells, budget cursor.
local function baseView(box, kind, make)
  local view = { box = box, cells = {}, headers = {}, kind = kind }
  local cellPool = Bricks.pool(function() return make(box) end)
  local headerPool = Bricks.pool(function() return newHeader(box) end)

  view.cellPool, view.headerPool = cellPool, headerPool
  view.cursor = Bricks.text(box.scroll.child, lookKey("small.font"), lookKey("group.color"))
  view.cursor:SetJustifyH("CENTER")
  view.cursor:Hide()

  -- The card of a group (skins whose group.frame is not FLAT, with a group.fill): a framed block under the header and
  -- the cells of the group, from y `top` to y `bottom`.
  local cardPool = Bricks.pool(function()
    return CreateFrame("Frame", nil, box.scroll.child)
  end)

  view.cardPool = cardPool

  function view:Card(top, bottom, width)
    local style, fill = lower(S("widgets.saves.group.frame")), S("widgets.saves.group.fill")

    if style == "flat" or style == "" or type(fill) ~= "string" or fill == "" then
      return
    end

    local child = box.scroll.child
    local card = cardPool:acquire(child)

    if card.SetFrameLevel and child.GetFrameLevel then
      card:SetFrameLevel(child:GetFrameLevel())
    end

    card:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -top)
    card:SetWidth(width)
    card:SetHeight(max(1, bottom - top))
    Bricks.frame(card, style, fill, "borderDim")
  end

  function view:Cells()
    return self.cells
  end

  function view:ColumnCount()
    return 1
  end

  function view:Release()
    cellPool:releaseAll()
    headerPool:releaseAll()
    cardPool:releaseAll()
    self.cells = {}
    self.headers = {}
    self.cursor:Hide()
  end

  function view:PlaceCursor(y, width)
    local balance = box.model and box.model.balance

    self.cursor:SetText((EbonAPI.L and EbonAPI.L.SAVES_YOU_HAVE or "%s"):format(Data.compact(balance or 0)))
    self.cursor:ClearAllPoints()
    self.cursor:SetPoint("TOPLEFT", box.scroll.child, "TOPLEFT", 0, -y)
    self.cursor:SetWidth(width)
    self.cursor:SetHeight(16)
    self.cursor:Show()

    return 16
  end

  function view:Layout(arranged, width)
    local child = box.scroll.child
    local rowHeight = lookKey("row.height") + (self.kind == "gauge" and 2 or 0)
    local gap = lookKey("row.gap")
    local headerHeight = max(18, rowHeight - 6)
    local state = box.state
    local y = 0

    self:Release()

    for _, block in ipairs(arranged.blocks) do
      local top = y

      if block.group then
        local header = headerPool:acquire(child)

        header:SetWidth(width)
        header:SetHeight(headerHeight)
        header:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        header:SetBlock(block, block.shut)
        self.headers[#self.headers + 1] = header
        y = y + headerHeight + gap
      end

      if not block.shut then
        for _, item in ipairs(block.items) do
          if arranged.cursorBefore == item.id then
            y = y + self:PlaceCursor(y, width) + gap
          end

          local cell = cellPool:acquire(child)

          cell:SetWidth(width)
          cell:SetHeight(rowHeight)
          cell:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
          if self.kind == "gauge" then
            gaugeFrame(cell, state.selected == item.id)
          else
            frameKeys(cell, "row")
          end

          cell:SetItem(item, state)
          self.cells[#self.cells + 1] = cell
          y = y + rowHeight + gap

          -- The inline drawer: box:InlineDrawer(item, cell, y, width) places it and returns its height.
          if state.selected == item.id and state.open and box:EffectiveDetail() == "inline" and box.InlineDrawer then
            y = y + box:InlineDrawer(item, cell, y, width) + gap
          end
        end

        if arranged.cursorBefore == "end" and not block.group then
          y = y + self:PlaceCursor(y, width) + gap
        end
      end

      if block.group then
        self:Card(top, y - gap, width)
      end
    end

    return max(0, y - gap)
  end

  return view
end

Views.views.list = function(box)
  return baseView(box, "list", newCell)
end

Views.views.gauge = function(box)
  return baseView(box, "gauge", function(owner)
    return newCell(owner, true)
  end)
end

-- The grid view: square cells spread over the width, state icon, name, mini gauge; the drawer always docks.
local STATE_BORDER = { active = "success", blocked = "caution", error = "danger", short = "borderDim" }
local MINI = 3

-- The palette key of the border of a grid cell, by state.
local function slotBorder(item)
  if item.state == "ready" or item.state == "step" then
    return lookKey("owned")
  end

  return STATE_BORDER[item.state] or "borderDim"
end

Views.slotBorder = slotBorder

local function newSlot(box)
  local slot = CreateFrame("Button", nil, box.scroll.child)
  local solid = Bricks.media("solid")

  slot.hoverFill = slot:CreateTexture(nil, "BACKGROUND")
  slot.hoverFill:SetTexture(solid)
  slot.hoverFill:SetAllPoints(slot)
  Bricks.paint(slot.hoverFill, "SetVertexColor", lookKey("row.hover"))
  slot.hoverFill:Hide()
  slot.chosen = slot:CreateTexture(nil, "BACKGROUND")
  slot.chosen:SetTexture(solid)
  slot.chosen:SetAllPoints(slot)
  Bricks.paint(slot.chosen, "SetVertexColor", lookKey("row.selected"))
  slot.chosen:SetAlpha(0.38)
  slot.chosen:Hide()

  -- The sharp outline of the chosen cell: an edge-only frame over the cell.
  slot.outline = CreateFrame("Frame", nil, slot)
  slot.outline:SetAllPoints(slot)
  slot.outline:EnableMouse(false)
  Bricks.frame(slot.outline, "small", "bg", "text")
  Bricks.unpaint(slot.outline, "SetBackdropColor")
  slot.outline:SetBackdropColor(0, 0, 0, 0)
  slot.outline:Hide()

  slot.glyph = iconTexture(slot, "lock", "muted")
  slot.glyph:SetWidth(12)
  slot.glyph:SetHeight(12)
  slot.glyph:SetPoint("TOPLEFT", slot, "TOPLEFT", 3, -3)
  slot.bolt = iconTexture(slot, "bolt", lookKey("later"))
  slot.bolt:SetWidth(12)
  slot.bolt:SetHeight(12)
  slot.bolt:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -3, -3)
  slot.name = Bricks.text(slot, lookKey("small.font"), "text")
  slot.name:SetJustifyH("CENTER")
  slot.name:SetJustifyV("MIDDLE")

  if slot.name.SetWordWrap then
    slot.name:SetWordWrap(true)
  end

  slot.barOwned = slot:CreateTexture(nil, "ARTWORK")
  slot.barOwned:SetTexture(solid)
  slot.barNow = slot:CreateTexture(nil, "ARTWORK")
  slot.barNow:SetTexture(solid)
  Bricks.paint(slot.barNow, "SetVertexColor", lookKey("now"))
  wireCell(box, slot)

  function slot:SetSelected(selected)
    self.selected = selected and true or false
    show(self.outline, self.selected)
    paintCell(self)
  end

  function slot:SetItem(item, state)
    local side = self:GetWidth()
    local icon, key = stateIcon(item)
    local lineHeight = (S("fonts." .. lookKey("small.font") .. ".size") or 12) + 1
    local inner = max(0, side - 2 - 2 * PAD)
    local active = item.state == "active"
    local owned = active and 1 or min(1, max(0, item.owned or 0))
    local now = active and 0 or min(1 - owned, max(0, item.now or 0))
    local fill = lookKey("cell.fill")

    self.item = item
    self.saveId = item.id
    self.border = slotBorder(item)
    Bricks.frame(self, lower(lookKey("cell.frame")), (type(fill) == "string" and fill ~= "") and fill or "card", self.border)

    if item.state == "ready" or item.state == "step" then
      Views.setIcon(self.glyph, "play")
      Bricks.paint(self.glyph, "SetVertexColor", "success")
    else
      Views.setIcon(self.glyph, icon)
      Bricks.paint(self.glyph, "SetVertexColor", key)
    end

    show(self.bolt, item.progressive and true or false)
    self.name:SetText(Data.shortName(item.name or ""))
    Bricks.paint(self.name, "SetTextColor",
      (item.state == "short" or item.state == "blocked" or item.state == "error") and "muted" or "text")
    self.name:ClearAllPoints()
    self.name:SetPoint("TOP", self, "TOP", 0, -(PAD + 10))
    self.name:SetWidth(max(1, side - 2 * PAD))
    self.name:SetHeight(3 * lineHeight)

    Bricks.paint(self.barOwned, "SetVertexColor", active and lookKey("now") or lookKey("owned"))

    for _, part in ipairs({ { self.barOwned, 0, owned }, { self.barNow, owned, now } }) do
      local bar, from, share = part[1], part[2], part[3]

      bar:ClearAllPoints()
      bar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 1 + PAD + inner * from, 1 + PAD / 2)
      bar:SetWidth(max(0.01, inner * share))
      bar:SetHeight(MINI)
      show(bar, share > 0)
    end

    self.hovered = false
    self.selected = state and state.selected == item.id and true or false
    show(self.outline, self.selected)
    paintCell(self)
  end

  return slot
end

Views.views.grid = function(box)
  local view = baseView(box, "grid", newSlot)
  local cellPool, headerPool = view.cellPool, view.headerPool

  view.columns = 1

  function view:ColumnCount()
    return self.columns
  end

  function view:Layout(arranged, width)
    local child = box.scroll.child
    local size, gap = lookKey("cell.size"), lookKey("cell.gap")
    local rowGap = lookKey("row.gap")
    local headerHeight = max(18, lookKey("row.height") - 6)
    local columns = max(1, floor(width / (size + gap)))
    local side = (width - (columns - 1) * gap) / columns
    local state = box.state
    local y = 0

    self:Release()
    self.columns = columns

    for _, block in ipairs(arranged.blocks) do
      local top = y

      if block.group then
        local header = headerPool:acquire(child)

        header:SetWidth(width)
        header:SetHeight(headerHeight)
        header:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        header:SetBlock(block, block.shut)
        self.headers[#self.headers + 1] = header
        y = y + headerHeight + rowGap
      end

      if not block.shut then
        local column = 0

        -- Closes the unfinished line (before the full-width budget cursor, and at the end of a block).
        local function endLine()
          if column > 0 then
            y = y + side + gap
            column = 0
          end
        end

        for _, item in ipairs(block.items) do
          if arranged.cursorBefore == item.id then
            endLine()
            y = y + self:PlaceCursor(y, width) + gap
          end

          local slot = cellPool:acquire(child)

          slot:SetWidth(side)
          slot:SetHeight(side)
          slot:SetPoint("TOPLEFT", child, "TOPLEFT", column * (side + gap), -y)
          slot:SetItem(item, state)
          self.cells[#self.cells + 1] = slot
          column = column + 1

          if column >= columns then
            endLine()
          end
        end

        endLine()

        if arranged.cursorBefore == "end" and not block.group then
          y = y + self:PlaceCursor(y, width) + gap
        end
      end

      if block.group then
        self:Card(top, y - gap, width)
      end
    end

    return max(0, y - gap)
  end

  return view
end

-- The drawer: detail of the chosen save (ring, name, state in clear, nodes, remaining cost, progressive switch,
-- activate button). One frame per widget; `inline` puts it under the chosen cell, `dock` at the bottom of the widget.
local TINT = { active = "success", ready = "success", short = "muted", blocked = "caution", error = "danger" }

local function stateTint(item)
  if item.state == "step" then
    return lookKey("later")
  end

  return TINT[item.state] or "muted"
end

local function textOf(key)
  local L = EbonAPI.L

  return (L and L[key]) or key
end

local function fontSize(role)
  return S("fonts." .. role .. ".size") or 12
end

function Views.drawer(box)
  local drawer = CreateFrame("Frame", nil, box)
  local fontRole, smallRole = lookKey("font"), lookKey("small.font")
  local big = lookKey("ring.big")
  local nameHeight, dotsSize = 20, 20
  local STRIP = 3

  drawer:EnableMouse(true)
  frameKeys(drawer, "drawer")

  drawer.strip = drawer:CreateTexture(nil, "ARTWORK")
  drawer.strip:SetTexture(Bricks.media("solid"))
  drawer.strip:SetWidth(STRIP)
  drawer.strip:SetPoint("TOPLEFT", drawer, "TOPLEFT", 1, -1)
  drawer.strip:SetPoint("BOTTOMLEFT", drawer, "BOTTOMLEFT", 1, 1)

  drawer.ring = newRing(drawer, big)
  drawer.percent = Bricks.text(drawer, smallRole, "text")
  drawer.percent:SetPoint("CENTER", drawer.ring.track, "CENTER", 0, 0)
  drawer.name = Bricks.text(drawer, fontRole, "text")
  drawer.name:SetJustifyH("LEFT")
  drawer.state = Bricks.text(drawer, smallRole, "muted")
  drawer.state:SetJustifyH("LEFT")
  drawer.state:SetJustifyV("TOP")
  drawer.probe = Bricks.text(drawer, smallRole, "muted")
  drawer.probe:Hide()
  drawer.nodes = Bricks.text(drawer, smallRole, "muted")
  drawer.nodes:SetJustifyH("LEFT")
  drawer.rest = Bricks.text(drawer, smallRole, "muted")
  drawer.rest:SetJustifyH("RIGHT")
  drawer.doneText = Bricks.text(drawer, smallRole, "success")
  drawer.doneText:SetJustifyH("RIGHT")

  for _, fs in ipairs({ drawer.name, drawer.probe, drawer.nodes, drawer.rest, drawer.doneText }) do
    if fs.SetWordWrap then
      fs:SetWordWrap(false)
    end
  end

  if drawer.state.SetWordWrap then
    drawer.state:SetWordWrap(true)
  end

  drawer.dots = CreateFrame("Button", nil, drawer)
  drawer.dots:SetWidth(dotsSize)
  drawer.dots:SetHeight(dotsSize)
  drawer.dots.icon = iconTexture(drawer.dots, "dots", "muted")
  drawer.dots.icon:SetAllPoints(drawer.dots)
  drawer.dots:SetScript("OnClick", function(self)
    if drawer.item then
      box:OpenMenu(drawer.item.id, self)
    end
  end)
  drawer.dots:SetScript("OnEnter", function(self)
    if drawer.item then
      Bricks.tip(self, (textOf("SAVES_MENU")):format(drawer.item.name or ""))
    end
  end)
  drawer.dots:SetScript("OnLeave", function()
    Bricks.hideTip()
  end)

  drawer.toggle = Bricks.create("toggle", drawer)
  drawer.toggle:SetLabel(textOf("SAVES_PROGRESSIVE"))
  drawer.toggle.onToggle = function()
    local item = drawer.item

    if item then
      box:ToggleMode(item.id)
      -- The model is the truth: STAL sends the new value through SetModel; until then show the item as it is.
      drawer.toggle:SetValue(drawer.item and drawer.item.progressive and true or false)
    end
  end

  drawer.button = Bricks.create("button", drawer)
  drawer.button.onClick = function()
    if drawer.item then
      box:Activate(drawer.item.id)
    end
  end

  drawer.done = iconTexture(drawer, "check", "success")
  drawer.done:SetWidth(12)
  drawer.done:SetHeight(12)

  -- Number of lines taken by the state text (0 to 2) for the width it has.
  function drawer:StateLines(available)
    local item = self.item

    if not item or not item.text or item.text == "" then
      return 0
    end

    self.probe:SetText(item.text)

    return (self.probe:GetStringWidth() or 0) > available + 0.5 and 2 or 1
  end

  function drawer:SetItem(item)
    local active = item.state == "active"
    local tint = stateTint(item)
    local nodes = item.nodes

    self.item = item
    self.ring:Set(item)
    self.percent:SetText(floor((active and 1 or (item.owned or 0)) * 100 + 0.5) .. "%")
    self.name:SetText(item.name or "")
    self.state:SetText(item.text or "")
    Bricks.paint(self.state, "SetTextColor", tint)
    Bricks.paint(self.strip, "SetVertexColor", tint)
    self.nodes:SetText(nodes and (textOf("SAVES_NODES")):format(nodes.owned or 0, nodes.total or 0) or "")

    if active then
      self.rest:SetText(textOf("SAVES_ACQUIRED"))
    elseif item.remaining ~= nil then
      self.rest:SetText((textOf("SAVES_REMAINING")):format(Data.compact(item.remaining)))
    else
      self.rest:SetText("?")
    end

    self.toggle:SetValue(item.progressive and true or false)
    self.button:SetLabel(item.count and (textOf("SAVES_ACTIVATE_COUNT")):format(item.count) or textOf("SAVES_ACTIVATE"))
    self.button:Fit()
    self.button:SetDisabledState(not item.canActivate)
    self.button.tipTitle = (not item.canActivate and item.why and item.why ~= "") and item.why or nil
    self.button.tipBody = nil
    self.doneText:SetText(textOf("SAVES_ACTIVE"))
    show(self.button, not active)
    show(self.done, active)
    show(self.doneText, active)

    return self
  end

  -- Lays the content out for `width`, sets the frame size and returns the height.
  function drawer:Fit(width)
    local left, right, gap = STRIP + PAD + 1, PAD, 4
    local textLeft = left + big + 6
    local available = max(1, width - textLeft - right)
    local lines = self:StateLines(available)
    local smallHeight = fontSize(smallRole) + 2
    local stateHeight = lines * smallHeight
    local top = max(big, nameHeight + stateHeight)
    local actionHeight = max(S("widgets.button.height"), S("widgets.toggle.height"))
    local y = PAD

    self:SetWidth(width)
    self.stateLines = lines
    self.ring:SetPoint("TOPLEFT", self, "TOPLEFT", left, -(y + (top - big) / 2))
    self.dots:ClearAllPoints()
    self.dots:SetPoint("TOPRIGHT", self, "TOPRIGHT", -right, -y)
    self.name:ClearAllPoints()
    self.name:SetPoint("TOPLEFT", self, "TOPLEFT", textLeft, -y)
    self.name:SetPoint("TOPRIGHT", self, "TOPRIGHT", -(right + dotsSize + 2), -y)
    self.name:SetHeight(nameHeight)
    self.state:ClearAllPoints()
    self.state:SetPoint("TOPLEFT", self, "TOPLEFT", textLeft, -(y + nameHeight))
    self.state:SetWidth(available)
    self.state:SetHeight(max(1, stateHeight))
    show(self.state, lines > 0)
    y = y + top + gap

    self.nodes:ClearAllPoints()
    self.nodes:SetPoint("TOPLEFT", self, "TOPLEFT", left, -y)
    self.nodes:SetHeight(smallHeight)
    self.nodes:SetWidth(max(1, (width - left - right) * 0.55))
    self.rest:ClearAllPoints()
    self.rest:SetPoint("TOPRIGHT", self, "TOPRIGHT", -right, -y)
    self.rest:SetHeight(smallHeight)
    self.rest:SetWidth(max(1, (width - left - right) * 0.42))
    y = y + smallHeight + gap

    self.button:ClearAllPoints()
    self.button:SetPoint("TOPRIGHT", self, "TOPRIGHT", -right, -y)
    self.button:SetHeight(actionHeight)
    self.doneText:ClearAllPoints()
    self.doneText:SetPoint("TOPRIGHT", self, "TOPRIGHT", -right, -y)
    self.doneText:SetWidth(60)
    self.doneText:SetHeight(actionHeight)
    self.done:ClearAllPoints()
    self.done:SetPoint("RIGHT", self.doneText, "LEFT", -4, 0)
    self.toggle:ClearAllPoints()
    self.toggle:SetPoint("TOPLEFT", self, "TOPLEFT", left, -y)
    self.toggle:SetHeight(actionHeight)
    self.toggle:SetWidth(max(20, min(self.toggle:TextWidth(), width - left - right - self.button:GetWidth() - gap)))
    y = y + actionHeight + PAD

    self:SetHeight(y)

    return y
  end

  return drawer
end
