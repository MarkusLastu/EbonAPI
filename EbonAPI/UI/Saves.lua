EbonAPI = EbonAPI or {}
EbonAPI.Saves = { looks = {} }

-- The "saves" widget: tool bar, drawer, status line, keyboard, Kit type and default brick of the slot "saves".
-- This file holds the core (model, state, views, callbacks, status line, Kit type, default brick); the tool bar,
-- the keyboard come with the next tasks, through the hooks marked below. See the contract, section 3.

local Saves = EbonAPI.Saves
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit
local Lib = EbonAPI.Lib
local Data = EbonAPI.SavesData
local Views = EbonAPI.SavesViews

local format, max, min = string.format, math.max, math.min
local ipairs, pairs, pcall, type, tostring = ipairs, pairs, pcall, type, tostring
local S = Bricks.value
local STATUS_DELAY = 9

Bricks.CONTRACT.saves = {
  "SetModel", "SetView", "SetDetail", "SetSort", "SetStatus", "SetHeight", "SetWidth", "Select", "Selected",
  "Refresh", "PreferredWidth",
}

local VIEWS = { list = true, grid = true, gauge = true }
local DETAILS = { inline = true, dock = true }
local SORTS = { name = true, pct = true, cost = true }
local CALLBACKS = {
  "onActivate", "onMode", "onMenu", "onGroupMenu", "onHover", "onLeave", "onNew", "onSelect", "onView", "onSort",
}

local function text(key)
  local L = EbonAPI.L

  return (L and L[key]) or key
end

Saves.text = text

local function lookKey(name)
  return S("widgets.saves." .. name)
end

local function statusColor(kind)
  if kind == "ok" then
    return "success"
  elseif kind == "bad" then
    return "danger"
  end

  return "muted"
end

-- Behaviour of the widget (frame methods), copied on each box by Saves.build.
local BOX = {}

function BOX:CallBack(name, ...)
  local fn = self.spec and self.spec[name]

  if type(fn) ~= "function" then
    return nil
  end

  local ok, result = pcall(fn, ...)

  if not ok then
    Lib.report(result, self.owner or "EbonAPI")
    return nil
  end

  return result
end

function BOX:Find(id)
  return id ~= nil and self.byId[id] or nil
end

function BOX:ViewObject()
  local name = self.state.view

  if not (self.look.views or Views.views)[name] then
    name = "list"
  end

  if self.viewName ~= name then
    if self.viewObject then
      self.viewObject:Release()
    end

    -- Each view is built once and kept: a round trip of the three views creates no new frame.
    self.viewObjects = self.viewObjects or {}
    self.viewName = name

    if not self.viewObjects[name] then
      self.viewObjects[name] = (self.look.views or Views.views)[name](self)
    end

    self.viewObject = self.viewObjects[name]
  end

  return self.viewObject
end

-- The drawer follows the view: the grid always docks it.
function BOX:EffectiveDetail()
  if self.state.view == "grid" then
    return "dock"
  end

  return self.state.detail
end

function BOX:Drawer()
  if not self.drawer then
    self.drawer = Views.drawer(self)
    self.drawer:Hide()
  end

  return self.drawer
end

-- Places the drawer under a cell of the scrolled content; returns its height.
function BOX:InlineDrawer(item, cell, y, width)
  local drawer = self:Drawer()

  drawer:SetParent(self.scroll.child)
  drawer:ClearAllPoints()
  drawer:SetItem(item)

  local height = drawer:Fit(width)

  drawer:SetPoint("TOPLEFT", self.scroll.child, "TOPLEFT", 0, -y)
  drawer:Show()

  return height
end

-- The docked drawer: fixed at the bottom of the widget; returns the height it takes (0 when closed).
function BOX:DockDrawer(width)
  local state = self.state
  local item = state.open and state.selected and self.byId[state.selected]

  if not item or self:EffectiveDetail() ~= "dock" then
    return 0
  end

  local drawer = self:Drawer()

  drawer:SetParent(self)
  drawer:ClearAllPoints()
  drawer:SetItem(item)

  local height = drawer:Fit(width)

  drawer:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, self.statusHeight)
  drawer:Show()

  return height + 2
end

function BOX:Relayout()
  local model = self.model

  if not model then
    return self
  end

  local state = self.state

  if state.reduced then
    return self:RelayoutReduced()
  end

  local width = max(1, (self.boxWidth or self:GetWidth() or 1))
  local height = max(1, self:GetHeight() or 1)
  local bar = S("widgets.scroll.width") + 2
  local arranged = Data.arrange(model, state)

  -- A chosen save that is gone, folded or filtered out has no drawer.
  if state.open then
    local shown = false

    for _, id in ipairs(arranged.ids) do
      if id == state.selected then
        shown = true
        break
      end
    end

    if not shown then
      state.open = false
    end
  end

  if self.drawer then
    self.drawer:Hide()
  end

  self.dockHeight = self:DockDrawer(width)
  self:Place()

  local viewHeight = max(1, height - self.barHeight - self.dockHeight - self.statusHeight)
  local viewWidth = max(1, width - bar)
  local offset = self.scroll:Offset()
  local view = self:ViewObject()

  self.arranged = arranged
  self.scroll:SetView(viewWidth, viewHeight)

  local content = view:Layout(arranged, viewWidth)

  self.scroll:SetContentHeight(content)
  self.scroll:SetOffset(offset)

  if arranged.count == 0 then
    self.empty:SetText(arranged.total == 0 and (self.spec and self.spec.empty or "") or text("SAVES_NO_MATCH"))
    self.empty:SetWidth(max(1, viewWidth - 16))
    self.empty:Show()
  else
    self.empty:Hide()
  end

  return self:UpdateBar()
end

function BOX:Place()
  self.scroll:ClearAllPoints()
  self.scroll:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -self.barHeight)
  self.scroll:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, self.statusHeight + self.dockHeight)

  return self
end

function BOX:SetModel(model)
  local ok, problem = Data.check(model)

  if not ok then
    Lib.report(format("EbonAPI: %s: saves: SetModel: %s", tostring(self.owner or "EbonAPI"), tostring(problem)),
      self.owner or "EbonAPI")

    return self
  end

  local byId = {}

  for _, group in ipairs(model.groups) do
    for _, item in ipairs(group.items) do
      byId[item.id] = item
    end
  end

  self.model, self.byId = model, byId

  if self.state.selected ~= nil and not byId[self.state.selected] then
    self.state.selected, self.state.open = nil, false
  end

  return self:Relayout()
end

function BOX:SetView(view)
  if not VIEWS[view] then
    error(format("EbonAPI: saves: SetView expects list, grid or gauge, got %s", tostring(view)), 2)
  end

  self.state.view = view
  self:UpdateBar()

  return self:Relayout()
end

function BOX:SetDetail(detail)
  if not DETAILS[detail] then
    error(format("EbonAPI: saves: SetDetail expects inline or dock, got %s", tostring(detail)), 2)
  end

  self.state.detail = detail

  return self:Relayout()
end

function BOX:SetSort(sort, grouped)
  if not SORTS[sort] then
    error(format("EbonAPI: saves: SetSort expects name, pct or cost, got %s", tostring(sort)), 2)
  end

  self.state.sort = sort

  if grouped ~= nil then
    self.state.grouped = grouped and true or false
  end

  return self:Relayout()
end

function BOX:SetHeight(height)
  -- Reduced, the widget keeps the height of its one line; the height asked for comes back with the full display.
  if self.state.reduced then
    self.fullHeight = height

    return self
  end

  self.nativeSetHeight(self, height)

  return self:Relayout()
end

function BOX:SetWidth(width)
  self.boxWidth = width
  self.nativeSetWidth(self, width)

  return self:Relayout()
end

function BOX:Select(id)
  if id == nil or self.byId[id] then
    self.state.selected = id
    self.state.open = id ~= nil

    self:Relayout()
  end

  return self
end

function BOX:Selected()
  return self.state.selected
end

function BOX:Refresh()
  return self:Relayout()
end

function BOX:PreferredWidth()
  local width = self.spec and self.spec.width or lookKey("width")

  return max(160, min(400, width))
end

-- Keyboard. A frame with EnableKeyboard swallows every key of the 3.3.5 client (movement included) and there is no
-- SetPropagateKeyboardInput: the keys are read through a hidden one-pixel EditBox (self.keys) that takes the focus on a
-- click in the widget and gives it back as soon as the mouse leaves, on Escape, when the widget hides, when the
-- search field takes over and when it loses the focus by itself.
local ARROWS = { UP = "UP", DOWN = "DOWN", LEFT = "LEFT", RIGHT = "RIGHT" }

-- The 3.3.5 client has no OnArrowPressed script on an EditBox (SetScript raises "doesn't have a script"): when the
-- script is refused, the arrows are read from OnKeyDown, which carries the key name. Only the arrows reach the handler.
local function onArrows(edit, handler)
  local function arrow(_, key)
    local name = ARROWS[Lib.upper and Lib.upper(tostring(key)) or tostring(key):upper()]

    if name then
      handler(name)
    end
  end

  if not pcall(edit.SetScript, edit, "OnArrowPressed", arrow) then
    edit:SetScript("OnKeyDown", arrow)
  end
end

function BOX:Focus()
  local keys = self.keys

  if not keys or self.keysOn or not self:IsShown() or self.state.reduced then
    return self
  end

  self.keysOn = true
  keys:Show()
  keys:SetText("")
  keys:SetScript("OnUpdate", function()
    self.keepKeys = nil

    if not self:IsShown() or not self:IsMouseOver() then
      self:ReleaseKeys()
    end
  end)
  keys:SetFocus()

  return self
end

function BOX:ReleaseKeys()
  local keys = self.keys

  if not keys or not self.keysOn then
    return self
  end

  self.keysOn = false
  keys:SetScript("OnUpdate", nil)
  keys:ClearFocus()
  keys:Hide()

  return self
end

-- Scrolls the content so that the cell of a save is entirely in view.
function BOX:Reveal(id)
  local view = self.viewObject
  local scroll = self.scroll

  if not view or not scroll then
    return self
  end

  for _, cell in ipairs(view:Cells()) do
    if cell.saveId == id then
      local _, _, _, _, y = cell:GetPoint(1)
      local top = -(y or 0)

      -- The first save brings its group title (and the budget cursor) into view with it.
      if self.arranged and self.arranged.ids[1] == id then
        top = 0
      end

      local bottom = top + (cell:GetHeight() or 0)
      local offset, shown = scroll:Offset(), scroll.viewHeight or 0

      if top < offset then
        scroll:SetOffset(math.floor(top))
      elseif bottom > offset + shown then
        scroll:SetOffset(math.ceil(bottom - shown))
      end

      break
    end
  end

  return self
end

-- Moves the chosen save by `delta` places among the visible ones (bounded); the drawer keeps its state.
function BOX:Step(delta)
  local state = self.state
  local ids = self.arranged and self.arranged.ids

  if not ids then
    return self
  end

  local target = Data.neighbor(ids, state.selected, delta)

  if target == nil or target == state.selected then
    return self
  end

  state.selected = target
  self:CallBack("onSelect", target)
  self:Relayout()

  return self:Reveal(target)
end

-- One key read by the hidden field; `keyName` is UP, DOWN, LEFT, RIGHT, ENTER, SPACE, M or ESCAPE.
function BOX:Key(keyName)
  local state = self.state
  local selected = state.selected

  if ARROWS[keyName] then
    local grid = state.view == "grid"
    local columns = grid and self.viewObject and self.viewObject:ColumnCount() or 1

    if keyName == "UP" then
      return self:Step(-columns)
    elseif keyName == "DOWN" then
      return self:Step(columns)
    elseif grid and keyName == "LEFT" then
      return self:Step(-1)
    elseif grid and keyName == "RIGHT" then
      return self:Step(1)
    end
  elseif keyName == "ENTER" then
    if selected ~= nil then
      return self:DoubleClick(selected)
    end
  elseif keyName == "SPACE" then
    if selected ~= nil then
      state.open = not state.open
      self:Relayout()

      return self:Reveal(selected)
    elseif self.arranged and self.arranged.ids[1] ~= nil then
      return self:Pick(self.arranged.ids[1])
    end
  elseif keyName == "M" then
    if selected ~= nil then
      return self:ToggleMode(selected)
    end
  elseif keyName == "ESCAPE" then
    if state.open then
      state.open = false

      return self:Relayout()
    end

    return self:ReleaseKeys()
  end

  return self
end

function BOX:BuildKeys()
  local keys = CreateFrame("EditBox", nil, self)

  self.keys = keys
  keys:SetWidth(1)
  keys:SetHeight(1)
  keys:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
  keys:SetAutoFocus(false)
  keys:SetMaxLetters(1)
  keys:Hide()

  onArrows(keys, function(name)
    self:Key(name)
  end)
  keys:SetScript("OnEnterPressed", function()
    self:Key("ENTER")
  end)
  keys:SetScript("OnEscapePressed", function()
    -- The client drops the focus after Escape: when the drawer was open, this first Escape only closes it.
    self.keepKeys = self.state.open and true or nil
    self:Key("ESCAPE")
  end)
  keys:SetScript("OnChar", function(control, char)
    control:SetText("")

    if char == " " then
      self:Key("SPACE")
    elseif char == "m" or char == "M" then
      self:Key("M")
    end
  end)
  keys:SetScript("OnEditFocusLost", function(control)
    if self.keepKeys and self.keysOn then
      self.keepKeys = nil
      control:SetFocus()

      return
    end

    self:ReleaseKeys()
  end)
  keys:SetScript("OnHide", function()
    self:ReleaseKeys()
  end)

  local hook = self.HookScript or self.SetScript

  hook(self, "OnHide", function()
    self:ReleaseKeys()
  end)

  return self
end

-- Applies the fields of a Kit spec (view, detail, sort, grouped) through the setters; an unknown value is reported and
-- ignored.
function BOX:Configure(spec)
  local function apply(name, ...)
    local ok, problem = pcall(self[name], self, ...)

    if not ok then
      Lib.report(problem, self.owner or "EbonAPI")
    end
  end

  if spec.view then
    apply("SetView", spec.view)
  end

  if spec.detail then
    apply("SetDetail", spec.detail)
  end

  if spec.sort then
    apply("SetSort", spec.sort, spec.grouped)
  elseif spec.grouped ~= nil then
    self.state.grouped = spec.grouped and true or false
  end

  return self
end

-- Choose a save; choosing the chosen one again opens or closes the drawer.
function BOX:Pick(id)
  local state = self.state

  if not self.byId[id] then
    return self
  end

  self:Focus()

  if state.selected == id then
    state.open = not state.open
  else
    state.selected, state.open = id, true
    self:CallBack("onSelect", id)
  end

  return self:Relayout()
end

function BOX:Activate(id)
  self:CallBack("onActivate", id)

  return self
end

function BOX:DoubleClick(id)
  local item = self.byId[id]

  if not item then
    return self
  end

  self:Focus()

  if item.canActivate then
    return self:Activate(id)
  end

  local why = item.why

  if why and why ~= "" then
    self:SetStatus(why, "bad")

    if UIErrorsFrame then
      UIErrorsFrame:AddMessage(why, 1, 0.2, 0.2)
    end
  end

  return self
end

function BOX:ToggleMode(id)
  self:CallBack("onMode", id)

  return self
end

function BOX:OpenMenu(id, anchor)
  self:CallBack("onMenu", id, anchor)

  return self
end

function BOX:OpenGroupMenu(groupId, anchor)
  self:CallBack("onGroupMenu", groupId, anchor)

  return self
end

function BOX:ToggleFold(groupId)
  local fold = self.state.fold

  fold[groupId] = (not fold[groupId]) or nil

  return self:Relayout()
end

function BOX:Hover(id, frame)
  self.state.hover = id
  self:CallBack("onHover", id, frame)

  return self
end

function BOX:Unhover()
  self.state.hover = nil
  self:CallBack("onLeave")

  return self
end

-- The status line: empty shows the reminder; a text goes away after STATUS_DELAY seconds, driven by an OnUpdate
-- that exists only during that delay.
function BOX:SetStatus(message, kind)
  local line = self.status

  if message == nil or message == "" then
    self:SetScript("OnUpdate", nil)
    self.statusLeft = nil
    line:SetText(text("SAVES_HINT"))
    Bricks.paint(line, "SetTextColor", "muted")

    return self
  end

  line:SetText(message)
  Bricks.paint(line, "SetTextColor", statusColor(kind))
  self.statusLeft = STATUS_DELAY
  self:SetScript("OnUpdate", function(box, elapsed)
    box.statusLeft = (box.statusLeft or 0) - (elapsed or 0)

    if box.statusLeft <= 0 then
      box:SetStatus(nil)
    end
  end)

  return self
end

-- Tool bar: three view buttons on the left; search, sort and "+" on the right. The search field takes the bar's place
-- (or sits between the view buttons and the sort button when widgets.saves.search keeps it open).
local BUTTON, BAR_PAD = 22, 2
local VIEW_ICONS = { list = "list", grid = "grid", gauge = "gauge" }
local VIEW_TIPS = { list = "SAVES_VIEW_LIST", grid = "SAVES_VIEW_GRID", gauge = "SAVES_VIEW_GAUGE" }

-- Frame:SetShown does not exist in the 3.3.5 client.
local function show(target, on)
  if on then
    target:Show()
  else
    target:Hide()
  end
end

local function barButton(parent, icon, tip)
  local button = CreateFrame("Button", nil, parent)

  button:SetWidth(BUTTON)
  button:SetHeight(BUTTON)
  Bricks.frame(button, "small", "button", "buttonBorder")
  button.glyph = Views.iconTexture(button, icon, "text")
  button.glyph:SetWidth(14)
  button.glyph:SetHeight(14)
  button.glyph:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.tipKey = tip
  button:SetScript("OnEnter", function(self)
    Bricks.paint(self, "SetBackdropBorderColor", "buttonHover")
    Bricks.tip(self, text(self.tipKey))
  end)
  button:SetScript("OnLeave", function(self)
    Bricks.paint(self, "SetBackdropBorderColor", self.pressed and "focus" or "buttonBorder")
    Bricks.hideTip()
  end)

  return button
end

local function setPressed(button, on)
  button.pressed = on and true or false
  Bricks.paint(button, "SetBackdropColor", on and "selected" or "button")
  Bricks.paint(button, "SetBackdropBorderColor", on and "focus" or "buttonBorder")
end

-- Reduced mode: the bar and the scrolled area give way to one line, < [list] > and the button of the chosen save, above
-- the status line. The drawer is shut, the keyboard released and the preview of the tree freed.
local function miniButton(parent, icon, tip)
  local button = barButton(parent, icon, tip or "")

  button:RegisterForClicks("LeftButtonUp")

  -- No tip text for a button without key.
  if not tip then
    button:SetScript("OnEnter", function(self)
      Bricks.paint(self, "SetBackdropBorderColor", "buttonHover")
    end)
  end

  return button
end

function BOX:BuildMini()
  local mini = CreateFrame("Frame", nil, self)

  self.mini = mini
  mini:SetHeight(self.barHeight)
  mini:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
  mini:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
  mini:Hide()

  mini.prev = miniButton(mini, "left", "SAVES_PREVIOUS")
  mini.prev:SetPoint("TOPLEFT", mini, "TOPLEFT", 0, -BAR_PAD)
  mini.prev:SetScript("OnClick", function()
    self:StepReduced(-1)
  end)

  mini.go = miniButton(mini, "play", "SAVES_ACTIVATE")
  mini.go:SetPoint("TOPRIGHT", mini, "TOPRIGHT", 0, -BAR_PAD)
  mini.go:SetScript("OnClick", function()
    local id = self.state.selected

    if id ~= nil then
      self:DoubleClick(id)
    end
  end)

  mini.next = miniButton(mini, "right", "SAVES_NEXT")
  mini.next:SetPoint("TOPRIGHT", mini.go, "TOPLEFT", -BAR_PAD, 0)
  mini.next:SetScript("OnClick", function()
    self:StepReduced(1)
  end)

  mini.select = Bricks.create("select", mini)
  mini.select:SetPoint("TOPLEFT", mini.prev, "TOPRIGHT", BAR_PAD, 0)
  mini.select:SetPoint("TOPRIGHT", mini.next, "TOPLEFT", -BAR_PAD, 0)
  mini.select:SetHeight(BUTTON)
  mini.select.onPick = function(id)
    if self.state.selected ~= id then
      self:Pick(id)
    end
  end

  -- The hover follows the chosen save over the line (the tree shows it like over a cell).
  for _, target in ipairs({ mini.select.button, mini.go }) do
    target:HookScript("OnEnter", function(control)
      if self.state.selected ~= nil then
        self:Hover(self.state.selected, control)
      end
    end)
    target:HookScript("OnLeave", function()
      self:Unhover()
    end)
  end

  return mini
end

-- Moves the choice by one save in the order of the display (filter and folds do not count here).
function BOX:StepReduced(delta)
  local ids = self.reducedIds

  if not ids then
    return self
  end

  local target = Data.neighbor(ids, self.state.selected, delta)

  if target ~= nil and target ~= self.state.selected then
    self:Pick(target)
  end

  return self
end

function BOX:RelayoutReduced()
  local state = self.state
  local mini = self.mini or self:BuildMini()
  local arranged = Data.arrange(self.model, { sort = state.sort, grouped = state.grouped, query = "", fold = {} })
  local items = {}

  self.arranged, self.reducedIds, self.dockHeight = arranged, arranged.ids, 0

  for _, id in ipairs(arranged.ids) do
    items[#items + 1] = { key = id, text = self.byId[id].name }
  end

  if self.drawer then
    self.drawer:Hide()
  end

  self.nativeSetHeight(self, self.barHeight + self.statusHeight)
  mini:Show()
  mini.select:SetItems(items)
  mini.select:SetValue(state.selected)

  local item = state.selected ~= nil and self.byId[state.selected] or nil
  local can = item and item.canActivate

  if item then
    local icon = "play"

    if item.state == "active" then
      icon = "check"
    elseif not can then
      icon = item.state == "blocked" and "warn" or item.state == "error" and "cross" or "lock"
    end

    Views.setIcon(mini.go.glyph, icon)
    mini.go.tipKey = "SAVES_ACTIVATE"
    mini.go:Show()
  else
    mini.go:Hide()
  end

  show(mini.prev, true)
  show(mini.next, true)

  return self
end

function BOX:SetReduced(on)
  on = on and true or false

  local state = self.state

  if (state.reduced and true or false) == on then
    return self
  end

  state.reduced = on

  if on then
    self:ReleaseKeys()
    self.bar:Hide()
    self.scroll:Hide()
    self.empty:Hide()

    if self.drawer then
      self.drawer:Hide()
    end

    if state.hover ~= nil then
      self:Unhover()
    end

    self.fullHeight = self.fullHeight or self:GetHeight()
    self.nativeSetHeight(self, self.barHeight + self.statusHeight)
    self:Relayout()
  else
    if self.mini then
      self.mini:Hide()
    end

    self.bar:Show()
    self.scroll:Show()
    self.nativeSetHeight(self, self.fullHeight or S("kit.list"))
    self.fullHeight = nil
    self:Relayout()
  end

  return self
end

function BOX:Reduced()
  return self.state.reduced and true or false
end

function BOX:SearchPermanent()
  return lookKey("search") and true or false
end

-- Places the buttons and the search field according to the search state.
function BOX:LayoutBar()
  local bar, field = self.bar, self.field
  local permanent = self:SearchPermanent()
  local open = self.state.searchOpen or permanent

  for _, name in ipairs({ "list", "grid", "gauge" }) do
    show(self.viewButtons[name], permanent or not open)
  end

  show(self.searchButton, not open)
  show(self.sortButton, permanent or not open)
  show(self.newButton, permanent or not open)
  show(field, open)
  show(field.close, open and not permanent)
  field:ClearAllPoints()

  if permanent then
    field:SetPoint("TOPLEFT", bar, "TOPLEFT", 3 * (BUTTON + BAR_PAD), -BAR_PAD)
    field:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2 * (BUTTON + BAR_PAD), BAR_PAD)
  else
    field:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -BAR_PAD)
    field:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, BAR_PAD)
  end

  field.edit:SetPoint("RIGHT", field, "RIGHT", permanent and -40 or -(BUTTON + 40), 0)
  field.count:SetPoint("RIGHT", field, "RIGHT", permanent and -4 or -(BUTTON + 4), 0)

  return self
end

-- Pressed state of the view buttons, counter and placeholder of the field.
function BOX:UpdateBar()
  if not self.bar then
    return self
  end

  for name, button in pairs(self.viewButtons) do
    setPressed(button, self.state.view == name)
  end

  local arranged = self.arranged

  self.field.count:SetText(Data.counter(arranged and arranged.count or 0, arranged and arranged.total or 0))
  self.field.placeholder:SetText(text("SAVES_SEARCH_PLACEHOLDER"))
  show(self.field.placeholder, (self.field.edit:GetText() or "") == "")

  return self
end

function BOX:OpenSearch()
  self.state.searchOpen = true
  self:LayoutBar()
  self:UpdateBar()
  self:ReleaseKeys()
  self.field.edit:SetFocus()

  return self
end

-- Applies the text of the field as the filter; a chosen save that disappears gives way to the first visible one.
function BOX:ApplyQuery()
  local state = self.state

  state.query = self.field.edit:GetText() or ""
  self:Relayout()

  local selected = state.selected

  if selected ~= nil and self.arranged then
    local seen = false

    for _, id in ipairs(self.arranged.ids) do
      if id == selected then
        seen = true
        break
      end
    end

    if not seen then
      local first = self.arranged.ids[1]

      state.selected, state.open = first, false
      self:Relayout()

      if first ~= nil then
        self:CallBack("onSelect", first)
      end
    end
  end

  return self:UpdateBar()
end

-- Clears the text; closes the field unless widgets.saves.search keeps it open.
function BOX:CloseSearch()
  self.field.edit:SetText("")
  self.field.edit:ClearFocus()

  if not self:SearchPermanent() then
    self.state.searchOpen = false
  end

  self:ApplyQuery()

  return self:LayoutBar()
end

function BOX:OpenSortMenu()
  local state = self.state
  local items = { { title = true, text = text("SAVES_SORT_BY") } }

  for _, entry in ipairs({ { "name", "SAVES_SORT_NAME" }, { "pct", "SAVES_SORT_PCT" }, { "cost", "SAVES_SORT_COST" } }) do
    local sort = entry[1]

    items[#items + 1] = {
      text = text(entry[2]), checked = state.sort == sort,
      onClick = function()
        -- Not "and false or": that always gives the second value.
        if sort == "cost" then
          self:ChooseSort(sort, false)
        else
          self:ChooseSort(sort, state.grouped)
        end
      end,
    }
  end

  -- Kit.openMenu marks one entry only (the last checked): the sort carries the mark, the grouping a text mark.
  items[#items + 1] = {
    text = (state.grouped and "[x] " or "[ ] ") .. text("SAVES_GROUPED"), grouped = state.grouped,
    onClick = function()
      self:ChooseSort(state.sort, not state.grouped)
    end,
  }

  return Kit.openMenu(self.owner or "EbonAPI", items, self.bar)
end

-- A change made by the player: apply, tell the owner, and say when the cost sort cuts the groups.
function BOX:ChooseSort(sort, grouped)
  local cut = sort == "cost" and self.state.grouped and grouped == false

  self:SetSort(sort, grouped)
  self:CallBack("onSort", sort, self.state.grouped)

  if cut then
    local L = EbonAPI.L

    self:SetStatus((L and L.SAVES_GROUPED_OFF) or (text("SAVES_SORT_COST") .. " : " .. text("SAVES_GROUPED") .. " (off)"))
  end

  return self
end

function BOX:BuildBar()
  local bar = CreateFrame("Frame", nil, self)

  self.bar = bar
  bar:SetHeight(self.barHeight)
  bar:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
  bar:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)

  self.viewButtons = {}

  for index, name in ipairs({ "list", "grid", "gauge" }) do
    local button = barButton(bar, VIEW_ICONS[name], VIEW_TIPS[name])

    button:SetPoint("TOPLEFT", bar, "TOPLEFT", (index - 1) * (BUTTON + BAR_PAD), -BAR_PAD)
    button:SetScript("OnClick", function()
      self:SetView(name)
      self:CallBack("onView", name)
    end)
    self.viewButtons[name] = button
  end

  self.newButton = barButton(bar, "plus", "SAVES_NEW")
  self.newButton:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -BAR_PAD)
  self.newButton:SetScript("OnClick", function()
    self:CallBack("onNew")
  end)

  self.sortButton = barButton(bar, "sort", "SAVES_SORT")
  self.sortButton:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -(BUTTON + BAR_PAD), -BAR_PAD)
  self.sortButton:SetScript("OnClick", function()
    self:OpenSortMenu()
  end)

  self.searchButton = barButton(bar, "search", "SAVES_SEARCH")
  self.searchButton:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -2 * (BUTTON + BAR_PAD), -BAR_PAD)
  self.searchButton:SetScript("OnClick", function()
    self:OpenSearch()
  end)

  local field = CreateFrame("Frame", nil, bar)

  Bricks.frame(field, "small", "bgSoft", "borderDim")
  self.field = field

  local edit = CreateFrame("EditBox", nil, field)

  edit:SetAutoFocus(false)
  edit:SetPoint("TOPLEFT", field, "TOPLEFT", 6, -2)
  edit:SetPoint("BOTTOMLEFT", field, "BOTTOMLEFT", 6, 2)
  edit:SetPoint("RIGHT", field, "RIGHT", -(BUTTON + 40), 0)
  Bricks.font(edit, lookKey("small.font"))
  Bricks.paint(edit, "SetTextColor", "text")
  field.edit = edit

  field.placeholder = Bricks.text(field, lookKey("small.font"), "muted")
  field.placeholder:SetPoint("LEFT", edit, "LEFT", 0, 0)
  field.placeholder:SetJustifyH("LEFT")

  field.count = Bricks.text(field, lookKey("small.font"), "muted")
  field.count:SetPoint("RIGHT", field, "RIGHT", -(BUTTON + 4), 0)
  field.count:SetJustifyH("RIGHT")

  field.close = barButton(field, "close", "SAVES_SEARCH_CLOSE")
  field.close:SetPoint("RIGHT", field, "RIGHT", -1, 0)
  field.close:SetScript("OnClick", function()
    self:CloseSearch()
  end)

  edit:SetScript("OnTextChanged", function()
    self:ApplyQuery()
  end)
  edit:SetScript("OnEscapePressed", function()
    self:CloseSearch()
  end)
  onArrows(edit, function(name)
    if name == "UP" then
      self:Step(-1)
    elseif name == "DOWN" then
      self:Step(1)
    end
  end)
  edit:SetScript("OnEnterPressed", function(control)
    control:ClearFocus()

    if self.state.selected ~= nil then
      self:Activate(self.state.selected)
    end
  end)

  self:LayoutBar()
  self:UpdateBar()

  return self
end

function Saves.build(parent, look)
  local box = CreateFrame("Frame", nil, parent)
  local smallSize = S("fonts." .. lookKey("small.font") .. ".size")

  box.look = look or Saves.looks.default
  box.nativeSetHeight, box.nativeSetWidth = box.SetHeight, box.SetWidth

  for name, fn in pairs(BOX) do
    box[name] = fn
  end

  box.state = {
    view = lookKey("view"), detail = lookKey("detail"), sort = "name", grouped = true, query = "",
    searchOpen = lookKey("search") and true or false, fold = {}, selected = nil, open = false, hover = nil,
  }
  box.byId = {}
  box.barHeight, box.dockHeight = BUTTON + 2 * BAR_PAD, 0
  box.statusHeight = math.ceil(smallSize * 2) + 4
  box.nativeSetWidth(box, box:PreferredWidth())
  box.nativeSetHeight(box, S("kit.list"))

  box.scroll = Bricks.create("scroll", box)
  box.scroll:SetMode("VERTICAL")
  box:Place()
  box:BuildBar()

  box.empty = Bricks.text(box, lookKey("font"), "muted")
  box.empty:SetPoint("CENTER", box.scroll, "CENTER", 0, 0)
  box.empty:SetJustifyH("CENTER")
  box.empty:Hide()

  if box.empty.SetWordWrap then
    box.empty:SetWordWrap(true)
  end

  box.status = Bricks.text(box, lookKey("small.font"), "muted")
  box.status:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 4, 2)
  box.status:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 2)
  box.status:SetHeight(box.statusHeight - 2)
  box.status:SetJustifyH("LEFT")
  box.status:SetJustifyV("TOP")

  if box.status.SetWordWrap then
    box.status:SetWordWrap(true)
  end

  box:SetStatus(nil)
  box:BuildKeys()

  return box
end

Saves.looks.default = {}

Bricks.register("saves", "default", function(parent)
  return Saves.build(parent, Saves.looks.default)
end)

local function checkSaves(owner, spec, level)
  for _, name in ipairs(CALLBACKS) do
    if spec[name] ~= nil and type(spec[name]) ~= "function" then
      error(format("EbonAPI: %s: %s expects a function, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  if spec.view ~= nil and not VIEWS[spec.view] then
    error(format("EbonAPI: %s: saves view expects list, grid or gauge, got %s", owner, tostring(spec.view)), level + 1)
  end

  if spec.detail ~= nil and not DETAILS[spec.detail] then
    error(format("EbonAPI: %s: saves detail expects inline or dock, got %s", owner, tostring(spec.detail)), level + 1)
  end

  if spec.sort ~= nil and not SORTS[spec.sort] then
    error(format("EbonAPI: %s: saves sort expects name, pct or cost, got %s", owner, tostring(spec.sort)), level + 1)
  end

  if spec.grouped ~= nil and type(spec.grouped) ~= "boolean" then
    error(format("EbonAPI: %s: saves grouped expects a boolean, got %s", owner, tostring(spec.grouped)), level + 1)
  end

  if spec.empty ~= nil and type(spec.empty) ~= "string" then
    error(format("EbonAPI: %s: saves empty expects a text, got %s", owner, tostring(spec.empty)), level + 1)
  end
end

local function newSaves(owner, parent, spec)
  local box = Bricks.create("saves", parent)

  box.owner, box.spec = owner, spec

  if box.Configure then
    box:Configure(spec)
  end

  return box
end

Kit.addKind("saves", newSaves, checkSaves)
