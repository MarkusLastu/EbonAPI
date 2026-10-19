EbonAPI = EbonAPI or {}
EbonAPI.Pin = {}

local Pin = EbonAPI.Pin
local Kit = EbonAPI.Kit
local Lib = EbonAPI.Lib
local Skins = EbonAPI.Skins
local Bricks = EbonAPI.Bricks

local type, pairs, ipairs, pcall, setmetatable, tostring, error = type, pairs, ipairs, pcall, setmetatable, tostring,
  error
local max, min, abs = math.max, math.min, math.abs
local format, sort = string.format, table.sort

local S = Skins.value
local EDGE = 0.001
local BAND_LEVEL = 10

local Engine = {}
Engine.__index = Engine

local function wheel(pin)
  return function(_, delta)
    local ok, err = pcall(pin.adapter.wheel, delta)

    if not ok then
      Lib.report(err, pin.owner)
    end
  end
end

function Pin.new(outer, holder, adapter, owner)
  local pin = setmetatable({ outer = outer, adapter = adapter, owner = owner, slots = {}, top = 0 }, Engine)
  local clip = CreateFrame("ScrollFrame", nil, holder)
  local band = CreateFrame("ScrollFrame", nil, holder)
  local child = CreateFrame("Frame", nil, band)
  local sheet = CreateFrame("Frame", nil, clip)

  clip:SetFrameLevel(max(0, outer:GetFrameLevel() - 1))
  sheet:SetFrameLevel(outer:GetFrameLevel())
  band:SetFrameLevel(outer:GetFrameLevel() + BAND_LEVEL)

  for _, frame in ipairs({ child, sheet }) do
    frame:SetWidth(1)
    frame:SetHeight(1)
  end

  clip:SetScrollChild(sheet)
  band:SetScrollChild(child)
  band:Hide()

  for _, frame in ipairs({ clip, band }) do
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", wheel(pin))
  end

  pin.clip, pin.band, pin.child, pin.sheet = clip, band, child, sheet
  pin:Place()

  return pin
end

function Engine:Hold(content)
  content:SetParent(self.sheet)
  content:ClearAllPoints()
  content:SetPoint("TOPLEFT", self.sheet, "TOPLEFT", 0, 0)
end

function Engine:Width()
  return max(1, self.adapter.width() or 1)
end

function Engine:Place()
  local outer, clip, band = self.outer, self.clip, self.band
  local width = self:Width()

  clip:ClearAllPoints()
  clip:SetPoint("TOPLEFT", outer, "TOPLEFT", 0, self.top > 0 and -self.top or 0)
  clip:SetPoint("BOTTOMLEFT", outer, "BOTTOMLEFT", 0, 0)
  clip:SetWidth(width)
  band:ClearAllPoints()
  band:SetPoint("TOPLEFT", outer, "TOPLEFT", 0, 0)
  band:SetWidth(width)
  self.child:SetWidth(width)
  self.sheet:SetWidth(width)
end

function Engine:Invalidate()
  for _, slot in pairs(self.slots) do
    slot.dirty = true
  end
end

local function hideSlot(pin, slot)
  if slot.header then
    pin.adapter.clear(slot.frame, slot.header)
    slot.header, slot.key = nil, nil
  end

  for _, frame in pairs(slot.frames) do
    frame:Hide()
  end

  slot.frame = nil
end

function Engine:Slot(index, header, y)
  local slot = self.slots[index]

  if not header then
    if slot then
      hideSlot(self, slot)
    end

    return
  end

  if not slot then
    slot = { frames = {} }
    self.slots[index] = slot
  end

  local kind = self.adapter.kind and self.adapter.kind(header) or "header"
  local frame = slot.frames[kind]

  if not frame then
    frame = self.adapter.copy(self.child, header)
    frame.pinSlot = index
    slot.frames[kind] = frame
  end

  if slot.frame ~= frame or slot.key ~= header.key or slot.dirty then
    if slot.header then
      self.adapter.clear(slot.frame, slot.header)
    end

    for other, each in pairs(slot.frames) do
      if other ~= kind then
        each:Hide()
      end
    end

    slot.frame, slot.key, slot.header, slot.dirty = frame, header.key, header, false
    frame:SetWidth(header.width or self:Width())
    self.adapter.fill(frame, header)
  else
    slot.header = header
  end

  frame.pinY = y
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", self.child, "TOPLEFT", header.x or 0, 0 - y)
  frame:Show()
end

function Engine:Fade(frame)
  if self.faded == frame then
    return
  end

  if self.faded then
    self.faded:SetAlpha(self.fadedAlpha or 1)
  end

  self.faded, self.fadedAlpha = frame, frame and frame:GetAlpha() or nil

  if frame then
    frame:SetAlpha(0)
  end
end

function Engine:Update()
  local adapter = self.adapter
  local offset = adapter.offset() or 0
  local list = adapter.headers() or {}
  local current

  for index, header in ipairs(list) do
    if header.top < offset - EDGE then
      current = index
    else
      break
    end
  end

  local top, push, coming, at = 0, 0, nil, 0

  if current then
    local head = list[current]

    top = head.height + min(max(0, S("board.header.room") or 0), offset - head.top)
    coming = list[current + 1]

    if coming then
      at = coming.top - offset

      if at < top then
        push = max(0, head.height - at)
      else
        coming = nil
      end
    end
  end

  if abs(top - self.top) > EDGE then
    self.top = top
    self:Place()
  end

  local view = adapter.viewHeight and adapter.viewHeight() or self.outer:GetHeight()

  self.sheet:SetHeight(max(1, (adapter.height() or 0) + (view or 0) + top))
  self.clip:SetVerticalScroll(offset + top)

  local wanted = { current and list[current] or nil, coming }

  for index = 1, 2 do
    local slot = self.slots[index]
    local want = wanted[index]

    if slot and slot.header and (not want or want.key ~= slot.key or slot.dirty) then
      adapter.clear(slot.frame, slot.header)
      slot.header, slot.key = nil, nil
    end
  end

  self:Slot(1, wanted[1], push > 0 and -push or 0)
  self:Slot(2, wanted[2], at)
  self:Fade(coming and coming.frame or nil)

  if current then
    self.band:SetHeight(max(1, top + (coming and coming.height or 0)))
    self.band:Show()
  else
    self.band:Hide()
  end

  self.state = { index = current, push = push, top = top, offset = offset, key = current and list[current].key or nil,
    coming = coming and coming.key or nil }

  return self.state
end

function Engine:Touched(frame)
  local sync = self.adapter.sync

  if not sync then
    return
  end

  for _, slot in pairs(self.slots) do
    if slot.header and slot.header.frame == frame and slot.frame and slot.frame:IsShown() then
      sync(slot.frame, slot.header)
    end
  end
end

function Engine:Clear()
  self:Fade(nil)
  self.band:Hide()

  for _, slot in pairs(self.slots) do
    hideSlot(self, slot)
  end

  if self.top ~= 0 then
    self.top = 0
    self:Place()
  end

  self.state = nil
end

function Engine:Pinned(index)
  local slot = self.slots[index or 1]

  if slot and slot.frame and slot.frame:IsShown() then
    return slot.frame, slot.header
  end

  return nil
end

function Engine:TopOf(frame)
  local offset = self.state and self.state.offset or (self.adapter.offset() or 0)

  return offset + (frame.pinY or 0)
end

function Engine:BottomOf(frame)
  if frame.pinSlot == 1 and self.state and self.state.index then
    return self.state.offset + self.state.top
  end

  return self:TopOf(frame) + frame:GetHeight()
end

function Engine:State()
  return self.state
end

local STACK = {}

local function report(stack, err)
  Lib.report(err, stack.owner)
end

local function call(stack, name, ...)
  local fn = stack.spec[name]

  if type(fn) == "function" then
    local ok, err = pcall(fn, ...)

    if not ok then
      report(stack, err)
    end
  end
end

local function spacing(stack)
  return stack.spec.spacing or S("board.row.gap") or 4
end

local function foldTime()
  return S("board.header.fold") or 0
end

local function make(stack, kind, parent)
  local build = stack.spec.kinds[kind]

  if type(build) ~= "function" then
    error(format('EbonAPI: %s: stack item kind "%s" is not in kinds', stack.owner, tostring(kind)), 0)
  end

  local element = build(parent)

  element.stackKind = kind

  return element
end

function STACK:kitAcquire(kind)
  local pool = self.pools[kind]

  if not pool then
    pool = {}
    self.pools[kind] = pool
  end

  local element = table.remove(pool)

  if not element then
    element = make(self, kind, self.child)
  end

  element:SetAlpha(1)

  return element
end

function STACK:kitRelease(element)
  local pool = self.pools[element.stackKind]

  element:Hide()
  element:ClearAllPoints()
  element:SetAlpha(1)
  element.stackItem, element.stackKey, element.stackTop, element.stackY = nil, nil, nil, nil
  pool[#pool + 1] = element
end

local function place(stack, element, y)
  element.stackY = y
  element:ClearAllPoints()
  element:SetPoint("TOPLEFT", stack.child, "TOPLEFT", 0, 0 - y)
end

local function bind(stack, element, item)
  element.stackItem, element.stackKey, element.stackHeader = item, item.key, item.header and true or false
  call(stack, "fill", element, item)
  element:SetWidth(stack.viewWidth)
  element:Refresh()
  call(stack, "finish", element, item)
end

function STACK:kitHeaders()
  local list = {}

  if self.spec.pin == false then
    return list
  end

  for _, element in ipairs(self.order) do
    if element.stackHeader and element:IsShown() then
      list[#list + 1] = { frame = element, key = element.stackKey, item = element.stackItem, kind = element.stackKind,
        top = element.stackY or 0, height = element:GetHeight() }
    end
  end

  sort(list, function(a, b) return a.top < b.top end)

  return list
end

function STACK:kitPin()
  if self.kitPinning then
    return
  end

  self.kitPinning = true

  local ok, err = pcall(self.pin.Update, self.pin)

  self.kitPinning = false

  if not ok then
    report(self, err)
  end
end

local function setHeight(stack, height)
  stack.contentHeight = height
  stack.child:SetHeight(max(1, height))
  stack.scroll:SetContentHeight(height)
end

local function settle(stack)
  local anim = stack.kitAnim

  stack.kitAnim = nil
  stack:SetScript("OnUpdate", nil)

  for _, element in ipairs(stack.order) do
    place(stack, element, element.stackTop)
    element:Show()
  end

  setHeight(stack, stack.layoutHeight + (stack.tail or 0))

  if anim and anim.offset1 then
    stack.scroll:SetOffset(anim.offset1)
  end

  stack.pin:Invalidate()
  stack:kitPin()
end

local function eased(share)
  return 1 - (1 - share) * (1 - share)
end

local function step(stack, elapsed)
  local anim = stack.kitAnim

  if not anim then
    stack:SetScript("OnUpdate", nil)
    return
  end

  anim.elapsed = anim.elapsed + (elapsed or 0)

  local share = min(1, anim.elapsed / anim.duration)

  if share >= 1 then
    settle(stack)
    return
  end

  local factor = eased(share)

  for _, element in ipairs(stack.order) do
    local from = anim.from[element.stackKey]

    if from then
      place(stack, element, from + (element.stackTop - from) * factor)
    end
  end

  if anim.offset1 then
    stack.scroll:SetOffset(anim.offset0 + (anim.offset1 - anim.offset0) * factor)
  end

  stack:kitPin()
end

local function sameKeys(stack, items)
  local order = stack.order

  if #order ~= #items then
    return false
  end

  for index, item in ipairs(items) do
    local element = order[index]

    if element.stackKey ~= item.key or element.stackKind ~= item.kind then
      return false
    end
  end

  return true
end

local function rebind(stack, items)
  for index, item in ipairs(items) do
    local element = stack.order[index]
    local height = element:GetHeight()

    bind(stack, element, item)

    if element:GetHeight() ~= height then
      return false
    end
  end

  stack.items = items
  stack.pin:Invalidate()
  stack:kitPin()

  return true
end

function STACK:kitLayout(items, options)
  options = options or {}

  if self.kitAnim and not options.animate and sameKeys(self, items) and rebind(self, items) then
    return self
  end

  if self.kitAnim then
    settle(self)
  end

  local from = {}

  for key, element in pairs(self.byKey) do
    if element:IsShown() and element.stackY then
      from[key] = element.stackY
    end
  end

  local old, byKey, order = self.byKey, {}, {}
  local y, gap = 0, spacing(self)
  local before = self.contentHeight or 0

  self.items = items
  self.pin:Fade(nil)

  for index, item in ipairs(items) do
    local element = old[item.key]

    if element and element.stackKind ~= item.kind then
      element = nil
    end

    if element then
      old[item.key] = nil
    else
      element = self:kitAcquire(item.kind)
    end

    bind(self, element, item)
    element.stackTop = y
    byKey[item.key] = element
    order[index] = element
    y = y + element:GetHeight() + gap
  end

  for _, element in pairs(old) do
    self:kitRelease(element)
  end

  self.byKey, self.order, self.layoutHeight, self.tail = byKey, order, y, options.tail or 0

  local offset = options.offset

  if type(offset) == "function" then
    local ok, result = pcall(offset, self)

    if not ok then
      report(self, result)
      result = nil
    end

    offset = result
  end

  local duration = foldTime()

  if options.animate and duration > 0 and self:IsVisible() then
    for _, element in ipairs(order) do
      local start = from[element.stackKey]

      if start then
        place(self, element, start)
        element:Show()
      else
        element:Hide()
      end
    end

    setHeight(self, max(before, y + self.tail))
    self.kitAnim = { elapsed = 0, duration = duration, from = from, offset0 = self.scroll:Offset(), offset1 = offset }
    self:SetScript("OnUpdate", step)
    self.pin:Invalidate()
    self:kitPin()
    return self
  end

  for _, element in ipairs(order) do
    place(self, element, element.stackTop)
    element:Show()
  end

  setHeight(self, y + self.tail)

  if offset then
    self.scroll:SetOffset(offset)
  end

  self.pin:Invalidate()
  self:kitPin()

  return self
end

function STACK:SetItems(items, options)
  if type(items) ~= "table" then
    error(format("EbonAPI: %s: SetItems expects a table, got %s", self.owner, type(items)), 2)
  end

  local seen = {}

  for index, item in ipairs(items) do
    if type(item) ~= "table" or item.key == nil or type(item.kind) ~= "string" then
      error(format("EbonAPI: %s: SetItems: item %d needs a key and a kind", self.owner, index), 2)
    end

    if seen[item.key] then
      error(format("EbonAPI: %s: SetItems: item %d has the key of item %d", self.owner, index, seen[item.key]), 2)
    end

    seen[item.key] = index
  end

  if options ~= nil and type(options) ~= "table" then
    error(format("EbonAPI: %s: SetItems expects options as a table, got %s", self.owner, type(options)), 2)
  end

  if options and options.tail ~= nil and (type(options.tail) ~= "number" or options.tail < 0) then
    error(format("EbonAPI: %s: SetItems: tail expects a number of 0 or more, got %s", self.owner, tostring(options.tail)), 2)
  end

  return self:kitLayout(items, options)
end

function STACK:SetView(width, height)
  width, height = max(1, width or 1), max(1, height or 1)

  if width == self.viewWidth and height == self.viewHeight then
    return self
  end

  self.viewWidth, self.viewHeight = width, height
  self.child:SetWidth(self.viewWidth)
  self.scroll:SetView(self.viewWidth, self.viewHeight)
  self.pin:Place()

  if self.items then
    self:kitLayout(self.items, { tail = self.tail })
  else
    self:kitPin()
  end

  return self
end

function STACK:Elements()
  local out = {}

  for index, element in ipairs(self.order) do
    out[index] = element
  end

  return out
end

function STACK:Element(key)
  return self.byKey[key]
end

function STACK:TopOf(element)
  if element.pinSlot then
    return self.pin:TopOf(element)
  end

  return element.stackY or 0
end

function STACK:BottomOf(element)
  if element.pinSlot then
    return self.pin:BottomOf(element)
  end

  return (element.stackY or 0) + element:GetHeight()
end

function STACK:LayoutTop(key)
  local element = self.byKey[key]

  return element and element.stackTop or nil
end

function STACK:Pinned(index)
  return self.pin:Pinned(index)
end

function STACK:PinState()
  return self.pin:State()
end

function STACK:Offset()
  return self.scroll:Offset()
end

function STACK:SetOffset(value)
  self.scroll:SetOffset(value)

  return self
end

function STACK:ContentHeight()
  return self.layoutHeight or 0
end

function STACK:Animating()
  return self.kitAnim ~= nil
end

function STACK:Finish()
  if self.kitAnim then
    settle(self)
  end

  return self
end

function STACK:kitRefresh()
  if self.items then
    self:kitLayout(self.items, { tail = self.tail })
  end
end

local function newStack(owner, parent, spec)
  local stack = CreateFrame("Frame", nil, parent)
  local scroll = Bricks.create("scroll", stack)
  local child = CreateFrame("Frame", nil, stack)

  child:SetWidth(1)
  child:SetHeight(1)
  stack:SetWidth(spec.width or S("page.unit") * 2)
  stack:SetHeight(spec.height or S("kit.list"))
  scroll:SetMode("VERTICAL")
  scroll:SetAllPoints(stack)
  stack.owner, stack.spec, stack.scroll, stack.child = owner, spec, scroll, child
  stack.viewWidth, stack.viewHeight = 1, 1
  stack.pools, stack.byKey, stack.order, stack.contentHeight, stack.layoutHeight = {}, {}, {}, 0, 0

  for name, fn in pairs(STACK) do
    stack[name] = fn
  end

  stack.pin = Pin.new(scroll, stack, {
    offset = function() return scroll:Offset() end,
    headers = function() return stack:kitHeaders() end,
    width = function() return stack.viewWidth end,
    height = function() return stack.contentHeight end,
    viewHeight = function() return stack.viewHeight end,
    wheel = function(delta) scroll:Wheel(delta) end,
    kind = function(header) return header.kind end,
    copy = function(band, header) return make(stack, header.kind, band) end,
    fill = function(frame, header)
      frame.stackItem, frame.stackKey, frame.stackHeader = header.item, header.key, true
      call(stack, "fill", frame, header.item)
      frame:SetWidth(stack.viewWidth)
      frame:Refresh()
      call(stack, "finish", frame, header.item)
    end,
    clear = function() end,
  }, owner)
  stack.pin:Hold(child)
  scroll.bar:HookScript("OnValueChanged", function()
    stack:kitPin()
  end)
  stack:SetScript("OnHide", function(self)
    if self.kitAnim then
      settle(self)
    end
  end)

  return stack
end

local function checkStack(owner, spec, level)
  if type(spec.kinds) ~= "table" then
    error(format("EbonAPI: %s: stack expects kinds, a table of functions that build an element", owner), level + 1)
  end

  for name, build in pairs(spec.kinds) do
    if type(name) ~= "string" or type(build) ~= "function" then
      error(format("EbonAPI: %s: stack kinds expects names and functions, got %s", owner, tostring(name)), level + 1)
    end
  end

  for _, name in ipairs({ "fill", "finish" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "function" then
      error(format("EbonAPI: %s: %s expects a function, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  if spec.spacing ~= nil and type(spec.spacing) ~= "number" then
    error(format("EbonAPI: %s: spacing expects a number, got %s", owner, tostring(spec.spacing)), level + 1)
  end
end

Kit.addKind("stack", newStack, checkStack)
