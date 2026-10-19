EbonAPI = EbonAPI or {}
EbonAPI.Window = {}

local Window = EbonAPI.Window
local Lib = EbonAPI.Lib
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Bricks = EbonAPI.Bricks
local Windows = EbonAPI.Windows
local Options = EbonAPI.Options
local Parameters = EbonAPI.Parameters
local Handle = EbonAPI.Handle
local L = EbonAPI.L
local Problems = EbonAPI.Problems

local type, pairs, ipairs, pcall, tostring = type, pairs, ipairs, pcall, tostring
local floor, max, min = math.floor, math.max, math.min
local format, concat, lower, upper, sub = string.format, table.concat, string.lower, string.upper, string.sub
local remove = table.remove

local S = Skins.value

local NAME = "EbonAPIWindow"
local BLOCKS = { header = "Header", nav = "Nav", page = "Page" }
local BLOCK_ORDER = { "header", "nav", "page" }
local INLINE = { toggle = true, range = true, select = true, color = true, execute = true, input = true }
local POOLS = {
  toggle = "toggle", range = "range", select = "select", color = "color", execute = "execute",
  input = "input", header = "heading", description = "text", group = "group", output = "output",
}
local TIPS = { back = "UI_BACK", forward = "UI_FORWARD", minimize = "UI_MINIMIZE", sidebar = "UI_SIDEBAR" }
local HISTORY = 50

Window.NAME = NAME

local main, header, nav, page, footer, navScroll
local searchBox, searchHint, closeButton, searchWindow
local mainView = nil
local views = {}
local pageWindows = {}
local pageCount = 0
local selected = { owner = "EbonAPI", key = "general" }
local shown = { owner = "EbonAPI", key = "general" }
local query = ""
local installed = false
local shaded = false
local navHidden = false
local railOwner = "EbonAPI"
local traveling = false
local history, cursor = {}, 0
local openTabs = {}
local collapsed = {}
local controls = {}
local navPools = {}

Problems.declare("EbonAPI", "EBONAPI", {
  ["OPTIONS.DESC_FAILED"] = { class = "bug", key = "option" },
})

local function pathOf(node)
  local path = node and node.path
  if type(path) == "table" then return concat(path, ".") end
  return path and tostring(path) or (node and node.owner)
end

local function report(err, node, name)
  EbonAPI.Kit.fail("EBONAPI.KIT.CALLBACK_FAILED", err, node and node.owner,
    { element = pathOf(node), callback = name, addon = node and node.owner })
end

local function descFailed(node, err)
  EbonAPI.Kit.fail("EBONAPI.OPTIONS.DESC_FAILED", err, node.owner, { option = pathOf(node) })
end

local function blockBackground(frame, key)
  local texture = frame:CreateTexture(nil, "BACKGROUND")

  texture:SetTexture(Bricks.media("solid"))
  texture:SetAllPoints(frame)
  Bricks.paint(texture, "SetVertexColor", key)

  return texture
end

local function apply(node, ...)
  local ok, err = pcall(Options.set, node, ...)

  if not ok then
    report(err, node, "set")
  end

  Window.refresh()
end

local function widthOf(option, available)
  local width = option.width
  local unit = S("page.unit")

  if width == "full" then
    return available
  elseif width == "half" then
    return min(available, floor(unit / 2))
  elseif width == "double" then
    return min(available, unit * 2)
  elseif type(width) == "number" then
    return min(available, floor(unit * width))
  end

  return min(available, unit)
end

local builders = {}

local function read(node)
  local ok, desc = pcall(Options.desc, node)

  if not ok then
    descFailed(node, desc)
    desc = nil
  end

  return Options.name(node), desc, Options.isDisabled(node)
end

function builders.toggle(node, parent, available, pools)
  local name, desc, disabled = read(node)
  local value = Options.get(node)
  local widget = pools.toggle:acquire(parent)

  widget:SetLabel(name)
  widget:SetValue(value)
  widget:SetDisabledState(disabled)
  widget.tipTitle, widget.tipBody = name, desc
  widget.onToggle = function(checked)
    apply(node, checked)
  end

  local width = min(available, max(widthOf(node.option, available), widget:TextWidth()))

  widget:SetWidth(width)

  return widget, width, widget:GetHeight()
end

function builders.range(node, parent, available, pools)
  local name, desc, disabled = read(node)
  local value = Options.get(node)
  local option = node.option
  local low = option.softMin or option.min
  local high = option.softMax or option.max
  local step = option.step or (option.isPercent and 0.01) or ((high - low) >= 10 and 1 or 0.01)
  local width = widthOf(option, available)
  local widget = pools.range:acquire(parent)

  widget:SetWidth(width)
  widget:SetTitle(name)
  widget:SetRange(low, high, step, option.isPercent)
  widget:SetValue(value)
  widget:SetDisabledState(disabled)
  widget.tipTitle, widget.tipBody = name, desc
  widget.onCommit = function(committed)
    apply(node, max(option.min, min(option.max, committed)))
  end

  return widget, width, widget:GetHeight()
end

function builders.select(node, parent, available, pools)
  local name, desc, disabled = read(node)
  local items = Options.values(node)
  local value = Options.get(node)
  local width = widthOf(node.option, available)
  local widget = pools.select:acquire(parent)

  widget:SetWidth(width)
  widget:SetTitle(name)
  widget:SetItems(items)
  widget:SetValue(value)
  widget:SetDisabledState(disabled)
  widget.tipTitle, widget.tipBody = name, desc
  widget.onPick = function(picked)
    apply(node, picked)
  end

  return widget, width, widget:GetHeight()
end

function builders.color(node, parent, available, pools)
  local name, desc, disabled = read(node)
  local r, g, b, a = Options.get(node)
  local widget = pools.color:acquire(parent)

  widget:SetLabel(name)
  widget:SetColor(r, g, b, a)
  widget:SetDisabledState(disabled)
  widget.hasAlpha = node.option.hasAlpha and true or false
  widget.tipTitle, widget.tipBody = name, desc
  widget.onPick = function(nr, ng, nb, na)
    apply(node, nr, ng, nb, na)
  end

  local width = min(available, max(widthOf(node.option, available), widget:TextWidth()))

  widget:SetWidth(width)

  return widget, width, widget:GetHeight()
end

function builders.execute(node, parent, available, pools)
  local name, desc, disabled = read(node)
  local widget = pools.execute:acquire(parent)

  widget:SetLabel(name)
  widget:SetHeight(S("widgets.execute.height"))
  widget:SetSelected(false)
  widget:SetDisabledState(disabled)
  widget.tipTitle, widget.tipBody = name, desc
  widget.onClick = function()
    local ok, err = pcall(Options.run, node)

    if not ok then
      report(err, node, "run")
    end

    Window.refresh()
  end

  local width = widget:Fit(min(available, max(widthOf(node.option, available), widget:TextWidth())))

  return widget, width, widget:GetHeight()
end

function builders.input(node, parent, available, pools)
  local name, desc, disabled = read(node)
  local value = Options.get(node)
  local option = node.option
  local lines = option.multiline

  if lines == true then
    lines = S("widgets.input.lines")
  elseif type(lines) ~= "number" then
    lines = nil
  end

  local width = lines and available or widthOf(option, available)
  local widget = pools.input:acquire(parent)

  widget:SetWidth(width)
  widget:SetTitle(name)
  widget:SetLines(lines)
  widget:SetValue(value)
  widget:SetDisabledState(disabled)
  widget.tipTitle, widget.tipBody = name, desc
  widget.onCommit = function(text)
    apply(node, text)
  end

  return widget, width, widget:GetHeight(), lines ~= nil
end

function builders.header(node, parent, available, pools)
  local name = Options.name(node)
  local widget = pools.header:acquire(parent)

  widget:SetWidth(available)
  widget:SetLabel(name)

  return widget, available, widget:GetHeight(), true
end

function builders.description(node, parent, available, pools)
  local name = Options.name(node)

  if node.option.view == "result" and pools.output then
    local frame = pools.output:acquire(parent)

    frame:SetWidth(available)
    frame:SetModel(EbonAPI.Settings and EbonAPI.Settings.resultModel and EbonAPI.Settings.resultModel()
      or { kind = "text", text = name })

    return frame, available, frame:GetHeight(), true
  end

  local widget = pools.description:acquire(parent)
  local height = widget:SetContent(name, available, node.option.fontSize)

  return widget, available, height, true
end

local layoutList

local function placeGroup(title, list, parent, left, top, width, pools)
  local group = pools.group:acquire(parent)
  local padding = S("widgets.group.padding")

  group:SetWidth(width)
  group:SetLabel(title)
  group:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -top)

  local inner = layoutList(list, group.box, padding, padding, width - padding * 2, false, pools)

  group:SetInnerHeight(max(inner, 0) + padding * 2 - S("page.gap.y"))

  return group:GetHeight()
end

local function inlineDesc(child)
  local ok, desc = pcall(Options.desc, child)

  if not ok then
    descFailed(child, desc)
  elseif type(desc) == "string" and desc ~= "" then
    return desc
  end

  return nil
end

layoutList = function(list, parent, left, top, width, skipNavGroups, pools)
  local gapX, gapY = S("page.gap.x"), S("page.gap.y")
  local stacked = S("page.layout") == "LIST"
  local mode = S("page.descriptions")
  local below = S("page.description.below")
  local x, y, rowHeight = 0, 0, 0

  local function breakRow()
    if x > 0 then
      y = y + rowHeight + gapY
      x, rowHeight = 0, 0
    end
  end

  for _, child in ipairs(list) do
    local kind = child.option.type

    if kind == "group" then
      if not skipNavGroups or child.option.inline then
        breakRow()

        local ok, height = pcall(function()
          return placeGroup(Options.name(child), Options.children(child), parent, left, top + y, width, pools)
        end)

        if ok then
          y = y + height + gapY
        else
          report(height, child, "group")
        end
      end
    else
      local builder = builders[kind]
      local ok, widget, used, height, full = pcall(builder, child, parent, width, pools)

      if not ok then
        report(widget, child, "build")
      elseif widget then
        local desc = mode ~= "TOOLTIP" and INLINE[kind] and inlineDesc(child)
        local alone = full or stacked or desc

        if mode == "INLINE" then
          widget.tipBody = nil
        end

        if alone or (x > 0 and x + used > width) then
          breakRow()
        end

        widget:SetPoint("TOPLEFT", parent, "TOPLEFT", left + x, -(top + y))

        if alone then
          y = y + height

          if desc then
            local note = pools.description:acquire(parent)
            local noteHeight = note:SetContent(desc, width, S("page.description.font"), S("page.description.color"))

            note:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -(top + y + below))
            y = y + below + noteHeight
          end

          y = y + gapY
        else
          x = x + used + gapX
          rowHeight = max(rowHeight, height)
        end
      end
    end
  end

  breakRow()

  return y
end

Window.layoutList = layoutList

local function hasContent(node)
  for _, child in ipairs(Options.children(node)) do
    if child.option.type ~= "group" or child.option.inline then
      return true
    end
  end

  return false
end

local function navGroups(node)
  local list = {}

  for _, child in ipairs(Options.children(node)) do
    if child.option.type == "group" and not child.option.inline then
      list[#list + 1] = child
    end
  end

  return list
end

local function pageId(owner, key)
  return key and (owner .. "/" .. key) or owner
end

local function pageDetached(owner, key)
  if S("windows.detach.pages") then
    return true
  end

  local id = pageId(owner, key)

  for _, entry in ipairs(S("windows.detach.list")) do
    if entry == id then
      return true
    end
  end

  return false
end

local function nodeOf(owner, key)
  local root = Options.root(owner)

  if not root then
    return nil
  end

  if key then
    local child = Options.child(root, key)

    if child and not Options.isHidden(child) then
      return child
    end

    return nil
  end

  return root
end

local function normalized(owner, key)
  local root = Options.root(owner)

  if not root then
    return "EbonAPI", "general"
  end

  if key then
    local child = Options.child(root, key)

    if child and not Options.isHidden(child) then
      return owner, key
    end

    key = nil
  end

  if not hasContent(root) then
    local first = navGroups(root)[1]

    if first then
      return owner, first.key
    end
  end

  return owner, key
end

local function currentNode()
  local owner, key = normalized(shown.owner, shown.key)

  shown.owner, shown.key = owner, key

  return nodeOf(owner, key)
end

local function resultTitle(node)
  local parts = { Options.name(Options.root(node.owner)) }
  local chain = {}
  local at = node.parent

  while at and at.parent do
    chain[#chain + 1] = Options.name(at)
    at = at.parent
  end

  for index = #chain, 1, -1 do
    parts[#parts + 1] = chain[index]
  end

  return concat(parts, " / ")
end

local function pageName(owner, key)
  local node = nodeOf(owner, key)

  if not node then
    return nil
  end

  return Options.name(node)
end

local function remember(owner, key)
  if traveling then
    return
  end

  local current = history[cursor]

  if current and current.owner == owner and current.key == key then
    return
  end

  for index = #history, cursor + 1, -1 do
    history[index] = nil
  end

  history[#history + 1] = { owner = owner, key = key }

  if #history > HISTORY then
    remove(history, 1)
  end

  cursor = #history
end

local function openTab(owner, key)
  local limit = S("page.strip.tabs")

  if limit <= 1 then
    return
  end

  for _, entry in ipairs(openTabs) do
    if entry.owner == owner and entry.key == key then
      return
    end
  end

  openTabs[#openTabs + 1] = { owner = owner, key = key }

  while #openTabs > limit do
    for index, entry in ipairs(openTabs) do
      if not (entry.owner == owner and entry.key == key) then
        remove(openTabs, index)
        break
      end
    end
  end
end

local function crumbsOf(node)
  local parts = {}
  local at = node

  while at do
    parts[#parts + 1] = Options.name(at)
    at = at.parent
  end

  local ordered = {}

  for index = #parts, 1, -1 do
    ordered[#ordered + 1] = parts[index]
  end

  return concat(ordered, " " .. S("page.crumbs.separator") .. " ")
end

local function stripTab(strip)
  local height, padding = strip.height, S("page.strip.padding")
  local closeWidth = S("page.strip.close")
  local border = S("page.strip.border")
  local tab = CreateFrame("Button", nil, strip.frame)

  tab:SetHeight(height)
  tab.fill = blockBackground(tab, S("page.strip.idle"))
  tab.separator = tab:CreateTexture(nil, "ARTWORK")
  tab.separator:SetTexture(Bricks.media("solid"))
  tab.separator:SetWidth(S("page.strip.separatorWidth"))
  tab.separator:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
  tab.separator:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
  Bricks.paint(tab.separator, "SetVertexColor", S("page.strip.separator"))

  if border > 0 then
    tab.accent = tab:CreateTexture(nil, "OVERLAY")
    tab.accent:SetTexture(Bricks.media("solid"))
    tab.accent:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    tab.accent:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
    tab.accent:SetHeight(border)
    Bricks.paint(tab.accent, "SetVertexColor", S("page.strip.accent"))
  end

  tab.text = Bricks.text(tab, S("page.strip.font"), S("page.strip.idleText"))
  tab.text:SetPoint("LEFT", tab, "LEFT", padding, 0)

  local function hover(state)
    tab.hovered = state
    tab:Refresh()
  end

  if closeWidth > 0 then
    tab.close = Bricks.flatButton(tab)
    tab.close:SetWidth(closeWidth)
    tab.close:SetHeight(closeWidth)
    tab.close:SetPoint("RIGHT", tab, "RIGHT", -floor(padding / 2), 0)
    tab.close:SetLabel(S("page.close.glyph"))
    tab.close.tipTitle = L.UI_CLOSE
    tab.close:HookScript("OnEnter", function()
      hover(true)
    end)
    tab.close:HookScript("OnLeave", function()
      hover(false)
    end)
  end

  tab:SetScript("OnEnter", function()
    hover(true)
  end)
  tab:SetScript("OnLeave", function()
    hover(false)
  end)
  tab:SetScript("OnClick", function(self)
    if self.onClick then
      self.onClick()
    end
  end)

  function tab:Setup(text, active, closable)
    local width

    self.active, self.closable = active, closable
    self.text:SetText(text or "")
    width = (self.text:GetStringWidth() or 0) + padding * 2

    if self.close then
      width = width + closeWidth
    end

    self:SetWidth(width)
    self:Refresh()
  end

  function tab:Refresh()
    Bricks.paint(self.fill, "SetVertexColor", self.active and S("page.strip.tab") or S("page.strip.idle"))
    Bricks.paint(self.text, "SetTextColor", self.active and S("page.strip.text") or S("page.strip.idleText"))

    if self.accent then
      Lib.setShown(self.accent, self.active)
    end

    if self.close then
      Lib.setShown(self.close, self.closable and (self.active or self.hovered))
    end
  end

  return tab
end

local function newStrip(frame, height, edge)
  local strip = { frame = frame, height = height, edge = edge, tabs = {} }
  local bar = frame:CreateTexture(nil, "BACKGROUND")

  bar:SetTexture(Bricks.media("solid"))
  bar:SetPoint("TOPLEFT", frame, "TOPLEFT", edge, -edge)
  bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -edge, -edge)
  bar:SetHeight(height)
  Bricks.paint(bar, "SetVertexColor", S("page.strip.color"))
  strip.bar = bar

  return strip
end

local function drawStrip(strip, entries)
  local x = strip.edge

  for index, entry in ipairs(entries) do
    local tab = strip.tabs[index]

    if not tab then
      tab = stripTab(strip)
      strip.tabs[index] = tab
    end

    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", strip.frame, "TOPLEFT", x, -strip.edge)
    tab.onClick = entry.onClick

    if tab.close then
      tab.close.onClick = entry.onClose
    end

    tab:Setup(entry.text, entry.active, entry.closable)
    tab:Show()
    x = x + tab:GetWidth()
  end

  for index = #entries + 1, #strip.tabs do
    strip.tabs[index]:Hide()
  end
end

local function newView(id, parent, closable, card)
  local view = { id = id, pools = {} }
  local width, height = S("page.width"), S("page.height")
  local insetX, insetY = S("page.inset.x"), S("page.inset.y")
  local stripHeight = S("page.strip.show") and S("page.strip.height") or 0
  local crumbsHeight = S("page.crumbs.show") and S("page.crumbs.height") or 0
  local style = card and S("page.frame") or "NONE"
  local frame = CreateFrame("Frame", nil, parent)
  local edge = 0

  frame:SetWidth(width)
  frame:SetHeight(height)

  if style ~= "NONE" then
    Bricks.frame(frame, lower(style), "pageBg", S("window.card.border"))
    edge = Bricks.insetOf(frame)
  else
    view.background = blockBackground(frame, "pageBg")
  end

  local left = insetX + edge
  local top = edge + stripHeight + crumbsHeight + insetY
  local titleY = -(top + S("page.title.y"))

  if stripHeight > 0 then
    view.strip = newStrip(frame, stripHeight, edge)
  end

  if crumbsHeight > 0 then
    local middle = -(edge + stripHeight + crumbsHeight / 2)

    view.crumbs = Bricks.text(frame, S("page.crumbs.font"), S("page.crumbs.color"))
    view.crumbs:SetPoint("LEFT", frame, "TOPLEFT", left, middle)
    view.crumbs:SetPoint("RIGHT", frame, "TOPRIGHT", -left, middle)
    view.crumbs:SetJustifyH("LEFT")
  end

  local title = Bricks.text(frame, S("page.title.font"), S("page.title.color"))

  title:SetPoint("TOPLEFT", frame, "TOPLEFT", left, titleY)
  title:SetJustifyH("LEFT")

  if closable then
    local close = Bricks.create("close", frame)

    close:SetWidth(S("page.close.width"))
    close:SetHeight(S("page.close.size"))
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -left, -top)
    close:SetLabel(S("page.close.glyph"))
    close.onClick = function()
      parent:Hide()
    end
    close.tipTitle = L.UI_CLOSE
    view.close = close
    title:SetPoint("TOPRIGHT", close, "TOPLEFT", -S("page.close.gap"), -S("page.title.y"))
  else
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -left, titleY)
  end

  if not S("page.title.show") then
    title:Hide()
  end

  local gap = S("page.description.gap")
  local desc = Bricks.text(frame, S("page.description.font"), S("page.description.color"))

  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -gap)
  desc:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -gap)
  desc:SetJustifyH("LEFT")

  if not S("page.description.show") then
    desc:Hide()
  end

  local pageTop = top + S("page.top")
  local scroll = Bricks.create("scroll", frame)

  view.childWidth = width - S("page.gutter") - left * 2
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -pageTop)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -left, insetY + edge)
  scroll:SetView(view.childWidth, height - pageTop - insetY - edge)

  for kind, slot in pairs(POOLS) do
    view.pools[kind] = Bricks.slotPool(slot)
  end

  view.frame, view.title, view.desc, view.scroll = frame, title, desc, scroll
  views[id] = view

  return view
end

local function releaseView(view)
  for _, pool in pairs(view.pools) do
    pool:releaseAll()
  end
end

local function renderSearch(view)
  view.title:SetText(format(L.UI_SEARCH_RESULTS, query))
  view.desc:SetText("")

  local results = Options.search(query)
  local child = view.scroll.child
  local width = view.childWidth

  if #results == 0 then
    local widget = view.pools.description:acquire(child)
    local height = widget:SetContent(format(L.UI_SEARCH_NONE, query), width, S("page.description.font"))

    widget:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)

    return height
  end

  local y = 0
  local bucket, title = {}, nil

  local function flush()
    if #bucket > 0 then
      local ok, height = pcall(placeGroup, title, bucket, child, 0, y, width, view.pools)

      if ok then
        y = y + height + S("page.gap.y")
      else
        report(height, bucket[1], "group")
      end
    end

    bucket = {}
  end

  for _, node in ipairs(results) do
    local heading = resultTitle(node)

    if heading ~= title then
      flush()
      title = heading
    end

    bucket[#bucket + 1] = node
  end

  flush()

  return y
end

local function tabEntries()
  local entries = {}

  openTab(shown.owner, shown.key)

  for _, entry in ipairs(openTabs) do
    local owner, key = entry.owner, entry.key
    local text = pageName(owner, key)

    if text then
      entries[#entries + 1] = {
        text = text,
        active = owner == shown.owner and key == shown.key,
        onClick = function()
          Window.select(owner, key)
        end,
        onClose = function()
          Window.closeTab(owner, key)
        end,
      }
    end
  end

  for _, entry in ipairs(entries) do
    entry.closable = #entries > 1
  end

  return entries
end

local function renderView(view)
  local offset = view.scroll:Offset()
  local height = 0
  local crumbs = ""

  releaseView(view)

  if view.search or (view == mainView and query ~= "") then
    height = renderSearch(view)
    crumbs = view.title:GetText()
  else
    local node

    if view == mainView then
      node = currentNode()
    else
      node = nodeOf(view.owner, view.key)
    end

    if node then
      local okDesc, desc = pcall(Options.desc, node)

      if not okDesc then
        descFailed(node, desc)
      end

      view.title:SetText(Options.name(node))
      view.desc:SetText(okDesc and desc or "")
      crumbs = crumbsOf(node)
      height = layoutList(Options.children(node), view.scroll.child, 0, 0, view.childWidth, node.parent == nil, view.pools)
    else
      view.title:SetText("")
      view.desc:SetText("")
    end
  end

  if view.crumbs then
    view.crumbs:SetText(crumbs)
  end

  if view.strip then
    local entries

    if view == mainView and query == "" and S("page.strip.tabs") > 1 then
      entries = tabEntries()
    else
      entries = { { text = view.title:GetText(), active = true, closable = false } }
    end

    drawStrip(view.strip, entries)
  end

  view.scroll:SetContentHeight(height)
  view.scroll:SetOffset(offset)
end

function Window.render()
  if not main then
    return
  end

  Bricks.closeMenu()

  for _, view in pairs(views) do
    if view.frame:IsVisible() then
      renderView(view)
    end
  end
end

local function railed()
  return nav ~= nil and nav.rail ~= nil and S("nav.rail.filter")
end

local function isCollapsed(owner)
  if not S("nav.tree.collapsible") then
    return false
  end

  local state = collapsed[owner]

  if state == nil then
    return not S("nav.tree.expanded")
  end

  return state
end

local function navEntries()
  local entries = {}
  local addonsTitled = false
  local indent = S("nav.tab.indent")
  local filter = railed()

  for _, owner in ipairs(Options.owners()) do
    if not filter or owner == railOwner then
      local ok, err = pcall(function()
        local root = Options.root(owner)
        local groups = navGroups(root)

        if owner == "EbonAPI" then
          entries[#entries + 1] = { label = Options.name(root) }

          for _, child in ipairs(groups) do
            entries[#entries + 1] = { owner = owner, key = child.key, text = Options.name(child), indent = 0 }
          end

          return
        end

        if filter then
          entries[#entries + 1] = { label = Options.name(root) }
        elseif not addonsTitled then
          addonsTitled = true
          entries[#entries + 1] = { label = L.UI_NAV_ADDONS }
        end

        entries[#entries + 1] = { owner = owner, text = Options.name(root), indent = 0, branch = #groups > 0 }

        if not isCollapsed(owner) then
          for _, child in ipairs(groups) do
            entries[#entries + 1] = {
              owner = owner, key = child.key, text = Options.name(child), indent = indent, leaf = true,
            }
          end
        end
      end)

      if not ok then
        report(err, { owner = owner }, "nav")
      end
    end
  end

  return entries
end

local function isSelected(entry)
  if pageDetached(entry.owner, entry.key) then
    local host = pageWindows[pageId(entry.owner, entry.key)]

    return host ~= nil and host:IsShown()
  end

  return query == "" and mainView ~= nil and entry.owner == shown.owner and entry.key == shown.key
end

local function normalize()
  local ok, err = pcall(currentNode)

  if not ok then
    report(err, { owner = shown.owner, path = shown.key }, "page")
  end
end

local function decorateTab(button, entry)
  local size = S("nav.tree.chevron")
  local offset = max(S("nav.tree.margin"), floor((S("nav.tab.padding") - size) / 2))

  if entry.branch and S("nav.tree.collapsible") then
    if not button.chevron then
      button.chevron = button:CreateTexture(nil, "OVERLAY")
      button.chevron:SetTexture(Bricks.media("chevron"))
      Bricks.paint(button.chevron, "SetVertexColor", S("nav.tree.chevronColor"))
    end

    button.chevron:SetWidth(size)
    button.chevron:SetHeight(size)
    button.chevron:ClearAllPoints()
    button.chevron:SetPoint("LEFT", button, "LEFT", offset, 0)
    Bricks.turn(button.chevron, not isCollapsed(entry.owner))
    button.chevron:Show()
  elseif button.chevron then
    button.chevron:Hide()
  end

  if entry.leaf and S("nav.tree.guides") then
    local x = offset + floor(size / 2) - entry.indent

    if not button.guide then
      button.guide = button:CreateTexture(nil, "ARTWORK")
      button.guide:SetTexture(Bricks.media("solid"))
      button.guide:SetWidth(S("nav.tree.guideWidth"))
      Bricks.paint(button.guide, "SetVertexColor", S("nav.tree.guideColor"))
    end

    button.guide:ClearAllPoints()
    button.guide:SetPoint("TOPLEFT", button, "TOPLEFT", x, 0)
    button.guide:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", x, 0)
    button.guide:Show()
  elseif button.guide then
    button.guide:Hide()
  end
end

local function refreshControls()
  if controls.back then
    controls.back:SetDisabledState(history[cursor - 1] == nil)
  end

  if controls.forward then
    controls.forward:SetDisabledState(history[cursor + 1] == nil)
  end
end

local function railIcon(owner)
  local root = Options.root(owner)
  local icon = Lib.icon(root and root.option.icon) or EbonAPI:AddonIcon(owner)

  if icon then
    return icon
  end

  return owner == "EbonAPI" and Bricks.media("icon") or Bricks.media("addonIcon")
end

local function isNavHere()
  return not S("windows.detach.nav")
end

local function isPageHere()
  return page ~= nil and not S("windows.detach.page")
end

local function navOnRight()
  return Parameters.value(nil, "tabs") == "RIGHT" and isNavHere() and isPageHere()
end

local function railItem(rail)
  local size, iconSize = S("nav.rail.width"), S("nav.rail.icon")
  local crop = S("nav.rail.crop")
  local item = CreateFrame("Button", nil, rail)

  item:SetWidth(size)
  item:SetHeight(size)
  item.icon = item:CreateTexture(nil, "ARTWORK")
  item.icon:SetWidth(iconSize)
  item.icon:SetHeight(iconSize)
  item.icon:SetPoint("CENTER", item, "CENTER", 0, 0)
  item.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
  item.indicator = item:CreateTexture(nil, "OVERLAY")
  item.indicator:SetTexture(Bricks.media("solid"))
  item.indicator:SetWidth(S("nav.rail.indicator"))
  Bricks.paint(item.indicator, "SetVertexColor", S("nav.rail.indicatorColor"))

  item:SetScript("OnEnter", function(self)
    self.hovered = true
    self:Refresh()
    Bricks.tip(self, self.tipTitle)
  end)
  item:SetScript("OnLeave", function(self)
    self.hovered = false
    self:Refresh()
    Bricks.hideTip()
  end)
  item:SetScript("OnClick", function(self)
    Window.railSelect(self.owner)
  end)

  function item:Refresh()
    local active = self.owner == railOwner and not navHidden

    self.icon:SetDesaturated(S("nav.rail.desaturate") and not active)
    self.icon:SetAlpha((active or self.hovered) and 1 or S("nav.rail.dim"))

    Lib.setShown(self.indicator, active and S("nav.rail.indicator") > 0)
  end

  return item
end

local function buildRail()
  local rail = nav.rail

  if not rail then
    return
  end

  local size, spacing = S("nav.rail.width"), S("nav.rail.spacing")
  local outer = navOnRight() and "RIGHT" or "LEFT"
  local owners = Options.owners()
  local y = spacing

  for index, owner in ipairs(owners) do
    local item = rail.items[index]
    if not item then
      item = railItem(rail)
      rail.items[index] = item
    end

    item.owner = owner
    item.tipTitle = Options.name(Options.root(owner))
    item.icon:SetTexture(railIcon(owner))
    item:ClearAllPoints()
    item:SetPoint("TOP", rail, "TOP", 0, -y)
    item.indicator:ClearAllPoints()
    item.indicator:SetPoint("TOP" .. outer, item, "TOP" .. outer, 0, 0)
    item.indicator:SetPoint("BOTTOM" .. outer, item, "BOTTOM" .. outer, 0, 0)
    item:Refresh()
    item:Show()
    y = y + size + spacing
  end

  for index = #owners + 1, #rail.items do
    rail.items[index]:Hide()
  end
end

function Window.buildNav()
  if not nav then
    return
  end

  normalize()
  buildRail()
  refreshControls()
  navPools.button:releaseAll()
  navPools.label:releaseAll()

  local child = navScroll.child
  local padding = S("nav.padding")
  local inner = S("nav.width") - S("nav.inset") - padding * 2
  local sections = S("nav.section.show")
  local sectionX, sectionHeight = padding + S("nav.section.x"), S("nav.section.height")
  local before, after = S("nav.section.before"), S("nav.section.after")
  local tabHeight, tabGap = S("nav.tab.height"), S("nav.tab.gap")
  local y = padding

  for _, entry in ipairs(navEntries()) do
    if entry.label then
      if sections then
        local label = navPools.label:acquire(child)
        local space = y > padding and before or 0

        label:SetLabel(entry.label)
        label:SetWidth(inner)
        label:SetPoint("TOPLEFT", child, "TOPLEFT", sectionX, -(y + space))
        y = y + space + sectionHeight + after
      end
    else
      local button = navPools.button:acquire(child)

      button:SetLabel(entry.text)
      button:SetWidth(inner - entry.indent)
      button:SetHeight(tabHeight)
      button:SetPoint("TOPLEFT", child, "TOPLEFT", padding + entry.indent, -y)
      button:SetDisabledState(false)
      button:SetSelected(isSelected(entry))
      decorateTab(button, entry)
      button.entry = entry
      button.onClick = function()
        if entry.branch and S("nav.tree.collapsible") then
          if shown.owner == entry.owner or isCollapsed(entry.owner) then
            collapsed[entry.owner] = not isCollapsed(entry.owner)
          end
        end

        Window.select(entry.owner, entry.key)
      end
      y = y + tabHeight + tabGap
    end
  end

  navScroll:SetContentHeight(y)
end

local function blockHost(id)
  return Windows.create(id, NAME .. BLOCKS[id])
end

local function hold(block, id, here, point, x, y, width, height)
  local pad = S("window.padding")

  block:ClearAllPoints()

  if here then
    block:SetParent(main)
    block:SetPoint(point, main, point, x, y)
  else
    local host = blockHost(id)

    block:SetParent(host)
    block:SetPoint("TOPLEFT", host, "TOPLEFT", pad, -pad)
    host:Resize(width + pad * 2, height + pad * 2)
  end
end

local function navSpan()
  local width = navHidden and 0 or S("nav.width")

  if nav and nav.rail then
    width = width + S("nav.rail.width") + (navHidden and 0 or S("nav.rail.gap"))
  end

  return width
end

local function layoutNav(right)
  local panel, rail = nav.panel, nav.rail
  local outer, inner = right and "RIGHT" or "LEFT", right and "LEFT" or "RIGHT"

  nav:SetWidth(navSpan())

  if rail then
    rail:ClearAllPoints()
    rail:SetPoint("TOP" .. outer, nav, "TOP" .. outer, 0, 0)
    rail:SetPoint("BOTTOM" .. outer, nav, "BOTTOM" .. outer, 0, 0)
  end

  panel:ClearAllPoints()
  panel:SetPoint("TOP" .. inner, nav, "TOP" .. inner, 0, 0)
  panel:SetPoint("BOTTOM" .. inner, nav, "BOTTOM" .. inner, 0, 0)

  Lib.setShown(panel, not navHidden)

  if panel.divider then
    panel.divider:ClearAllPoints()
    panel.divider:SetPoint("TOP" .. inner, panel, "TOP" .. inner, 0, 0)
    panel.divider:SetPoint("BOTTOM" .. inner, panel, "BOTTOM" .. inner, 0, 0)
  end

  if header and header.sidebar then
    if right then
      header.sidebar:SetTexCoord(0, 1, 0, 1)
    else
      header.sidebar:SetTexCoord(1, 0, 0, 1)
    end
  end
end

local function rollUp()
  for _, block in ipairs({ nav, page, footer }) do
    if block and block:GetParent() == main then
      block:Hide()
    end
  end

  main:Resize(main:GetWidth(), S("header.height"))
end

local function arrange()
  local pad, spacing = S("window.padding"), S("window.spacing")
  local navWidth, pageWidth, pageHeight = navSpan(), S("page.width"), S("page.height")
  local headerHeight = S("header.height")
  local headerHere = header ~= nil and not S("windows.detach.header")
  local navHere, pageHere = isNavHere(), isPageHere()
  local navShown = navHere and navWidth > 0
  local columns = navShown or pageHere
  local top = headerHere and (headerHeight + spacing) or pad
  local right = navOnRight()
  local width, height = pad * 2 + spacing + S("nav.width") + pageWidth, 0

  if navShown and pageHere then
    width = pad * 2 + spacing + navWidth + pageWidth
  elseif navShown then
    width = pad * 2 + navWidth
  elseif pageHere then
    width = pad * 2 + pageWidth
  end

  if columns then
    height = top + pageHeight + pad
  elseif headerHere then
    height = headerHeight
  end

  if footer and (columns or headerHere) then
    height = height + S("footer.height")
  end

  main:Resize(width, height)
  main.used = headerHere or columns

  if header then
    local host = headerHere and main or blockHost("header")

    header:SetParent(host)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
    header:SetHeight(headerHeight)

    if not headerHere then
      host:Resize(width, headerHeight)
    end
  end

  if footer then
    footer:SetParent(main)
    footer:ClearAllPoints()
    footer:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, 0)
    footer:Show()
  end

  layoutNav(right)
  hold(nav, "nav", navHere, right and "TOPRIGHT" or "TOPLEFT", right and -pad or pad, -top, navWidth, pageHeight)
  nav:Show()

  if page then
    local left = right or not navShown

    hold(page, "page", pageHere, left and "TOPLEFT" or "TOPRIGHT", left and pad or -pad, -top, pageWidth, pageHeight)
    page:Show()
  end

  if nav.panel.divider then
    Lib.setShown(nav.panel.divider, navHere and pageHere and not navHidden)
  end

  if shaded then
    rollUp()
  end
end

Window.arrange = arrange

local function besideNav()
  return Windows.get("page") or Windows.get("nav") or main
end

local function placeAll()
  local gap = S("windows.gap")
  local right = Parameters.value(nil, "tabs") == "RIGHT"
  local navHost = Windows.get("nav")

  Windows.place(main)

  if navHost then
    Windows.place(navHost, function(frame)
      if main.used and page and not S("windows.detach.page") then
        if right then
          frame:SetPoint("TOPLEFT", main, "TOPRIGHT", gap, 0)
        else
          frame:SetPoint("TOPRIGHT", main, "TOPLEFT", -gap, 0)
        end
      elseif main.used then
        frame:SetPoint("TOPLEFT", main, "BOTTOMLEFT", 0, -gap)
      else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      end
    end)
  end

  local headerHost = Windows.get("header")

  if headerHost then
    Windows.place(headerHost, function(frame)
      local below = main.used and main or navHost

      if below then
        frame:SetPoint("BOTTOMLEFT", below, "TOPLEFT", 0, gap)
      else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      end
    end)
  end

  local pageHost = Windows.get("page")

  if pageHost then
    Windows.place(pageHost, function(frame)
      frame:SetPoint("TOPLEFT", navHost or main, "TOPRIGHT", gap, 0)
    end)
  end
end

local function freeSlot()
  local used = {}

  for _, host in pairs(pageWindows) do
    if host:IsShown() then
      used[host.slot] = true
    end
  end

  if searchWindow and searchWindow:IsShown() then
    used[searchWindow.slot] = true
  end

  local slot = 1

  while used[slot] do
    slot = slot + 1
  end

  return slot
end

local function placeDetached(host)
  local anchor = besideNav()
  local gap, cascade = S("windows.gap"), S("windows.cascade")
  local slot = freeSlot()

  host.slot = slot
  Windows.place(host, function(frame)
    frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", gap + cascade * (slot - 1), -cascade * (slot - 1))
  end)
end

local function detachedHost(id, name)
  local pad = S("window.padding")
  local host = Windows.create(id, name)

  host:Resize(S("page.width") + pad * 2, S("page.height") + pad * 2)
  placeDetached(host)
  host:HookScript("OnHide", function()
    if installed then
      Window.buildNav()
    end
  end)

  return host
end

local function openPageWindow(owner, key)
  local id = pageId(owner, key)
  local host = pageWindows[id]

  if not host then
    pageCount = pageCount + 1
    host = detachedHost("page:" .. id, NAME .. "Page" .. pageCount)

    local view = newView(id, host, true)
    local pad = S("window.padding")

    view.owner, view.key = owner, key
    view.frame:SetPoint("TOPLEFT", host, "TOPLEFT", pad, -pad)
    host.view = view
    pageWindows[id] = host
  elseif not host:IsShown() then
    placeDetached(host)
  end

  host:Show()
  host:Raise()

  return host
end

local function openSearchWindow()
  if not searchWindow then
    searchWindow = detachedHost("search", NAME .. "Search")

    local view = newView("search", searchWindow, true)
    local pad = S("window.padding")

    view.search = true
    view.frame:SetPoint("TOPLEFT", searchWindow, "TOPLEFT", pad, -pad)
    searchWindow.view = view
  elseif not searchWindow:IsShown() then
    placeDetached(searchWindow)
  end

  searchWindow:Show()
  searchWindow:Raise()

  return searchWindow
end

local function showPage(owner, key)
  owner, key = normalized(owner or "EbonAPI", key)
  selected.owner, selected.key = owner, key
  railOwner = owner
  remember(owner, key)

  if pageDetached(owner, key) then
    openPageWindow(owner, key)
  elseif mainView then
    shown.owner, shown.key = owner, key
    openTab(owner, key)
    mainView.scroll:SetOffset(0)
  end

  EbonAPI:Emit("WINDOW_PAGE", owner, key)
end

local function anyPageShown()
  for _, host in pairs(pageWindows) do
    if host:IsShown() then
      return true
    end
  end

  return false
end

local function refreshSearchHint()
  if not searchHint then
    return
  end

  Lib.setShown(searchHint, query == "" and not searchBox.focused)
end

local function setQuery(text)
  text = Lib.trim(text or "")

  if text == query then
    return
  end

  query = text
  refreshSearchHint()

  if query ~= "" and not mainView and Windows.anyShown() then
    openSearchWindow()
  elseif query == "" and searchWindow then
    searchWindow:Hide()
  end

  Window.buildNav()
  Window.render()
end

local function buildHeader()
  local frame = CreateFrame("Frame", nil, UIParent)
  local pad = S("window.padding")
  local height = S("header.height")
  local left = S("header.controls") == "LEFT"
  local from = left and "TOPLEFT" or "TOPRIGHT"
  local sign = left and 1 or -1

  frame:SetHeight(height)
  frame.background = blockBackground(frame, "headerBg")

  local banner = S("header.banner.texture")

  if banner ~= "" then
    frame.banner = frame:CreateTexture(nil, "ARTWORK")
    frame.banner:SetTexture(banner)
    frame.banner:SetWidth(S("header.banner.width"))
    frame.banner:SetHeight(S("header.banner.height"))
    frame.banner:SetPoint("TOP", frame, "TOP", 0, S("header.banner.y"))
  end

  local title = Bricks.text(frame, S("header.title.font"), S("header.title.color"))
  local version = Bricks.text(frame, "small", "muted")
  local titleX, titleY = pad + S("header.title.x"), -S("header.title.y")
  local versionGap, versionY = S("header.version.gap"), S("header.version.y")

  title:SetText(L.UI_NAME)
  version:SetText(EbonAPI.version)

  if S("header.title.align") == "CENTER" then
    title:SetPoint("TOP", frame, "TOP", 0, titleY)
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", versionGap, versionY)
  elseif left then
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -titleX, titleY)
    version:SetPoint("BOTTOMRIGHT", title, "BOTTOMLEFT", -versionGap, versionY)
  else
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", titleX, titleY)
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", versionGap, versionY)
  end

  if not S("header.title.show") then
    title:Hide()
  end

  if not S("header.version.show") then
    version:Hide()
  end

  local closeY = -S("header.close.y")
  local edge = pad + S("header.inset")
  local close = Bricks.create("close", frame)

  close:SetWidth(S("header.close.width"))
  close:SetHeight(S("header.close.size"))
  close:SetPoint(from, frame, from, sign * edge, closeY)
  close:SetLabel(S("header.close.glyph"))
  close.onClick = function()
    Window.close()
  end
  close.onShade = function()
    Window.shade()
  end

  local closeShown = S("header.close.show")

  if not closeShown then
    close:Hide()
  end

  closeButton = close

  local spacing = S("header.spacing")
  local anchor = closeShown and close or nil

  local function control(name, width)
    local button = Bricks.flatButton(frame)

    button:SetWidth(width)
    button:SetHeight(S("header.close.size"))

    if anchor then
      button:SetPoint(from, anchor, left and "TOPRIGHT" or "TOPLEFT", left and spacing or -spacing, 0)
    else
      button:SetPoint(from, frame, from, sign * edge, closeY)
    end

    controls[name] = button
    anchor = button

    return button
  end

  if S("header.minimize.show") then
    local minimize = control("minimize", S("header.minimize.width"))

    minimize:SetLabel(S("header.minimize.glyph"))
    minimize.onClick = function()
      Window.shade()
    end
  end

  if S("header.sidebar.show") then
    local toggle = control("sidebar", S("header.sidebar.width"))
    local size = S("header.sidebar.size")

    frame.sidebar = toggle:CreateTexture(nil, "OVERLAY")
    frame.sidebar:SetTexture(Bricks.media("sidebar"))
    frame.sidebar:SetWidth(size)
    frame.sidebar:SetHeight(size)
    frame.sidebar:SetPoint("CENTER", toggle, "CENTER", 0, 0)
    Bricks.paint(frame.sidebar, "SetVertexColor", "text")
    toggle.onClick = function()
      Window.toggleNav()
    end
  end

  local inset, insetY = S("header.search.inset"), S("header.search.insetY")
  local gap = S("header.search.gap")
  local position = S("header.search.position")

  searchBox = CreateFrame("EditBox", nil, frame)
  searchBox:SetWidth(S("header.search.width"))
  searchBox:SetHeight(S("header.search.height"))

  if position == "CENTER" then
    searchBox:SetPoint("CENTER", frame, "CENTER", 0, 0)
  elseif position == "OPPOSITE" then
    local other = left and "RIGHT" or "LEFT"

    searchBox:SetPoint(other, frame, other, -sign * edge, 0)
  elseif anchor then
    searchBox:SetPoint(from, anchor, left and "TOPRIGHT" or "TOPLEFT", left and gap or -gap, 0)
  else
    searchBox:SetPoint(from, frame, from, sign * edge, closeY)
  end

  searchBox:SetAutoFocus(false)
  Bricks.font(searchBox, "small")
  searchBox:SetTextInsets(inset, inset, insetY, insetY)
  Bricks.frame(searchBox, "small", "bgSoft", "borderDim")
  Bricks.paint(searchBox, "SetTextColor", "text")

  searchHint = Bricks.text(searchBox, "small", "muted")
  searchHint:SetPoint("LEFT", searchBox, "LEFT", inset, 0)

  searchBox:SetScript("OnTextChanged", function(self)
    setQuery(self:GetText())
  end)
  searchBox:SetScript("OnEditFocusGained", function(self)
    self.focused = true
    Bricks.paint(self, "SetBackdropBorderColor", "focus")
    refreshSearchHint()
  end)
  searchBox:SetScript("OnEditFocusLost", function(self)
    self.focused = false
    Bricks.paint(self, "SetBackdropBorderColor", "borderDim")
    refreshSearchHint()
  end)
  searchBox:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    self:ClearFocus()
  end)
  searchBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)

  if not S("header.search.show") then
    searchBox:Hide()
  end

  if S("header.history.show") then
    local width, size = S("header.history.width"), S("header.search.height")
    local forward = Bricks.flatButton(frame)
    local back = Bricks.flatButton(frame)

    forward:SetWidth(width)
    forward:SetHeight(size)
    back:SetWidth(width)
    back:SetHeight(size)
    forward:SetPoint("RIGHT", searchBox, "LEFT", -spacing, 0)
    back:SetPoint("RIGHT", forward, "LEFT", -spacing, 0)
    forward:SetLabel(S("header.history.forward"))
    back:SetLabel(S("header.history.back"))
    forward.onClick = function()
      Window.forward()
    end
    back.onClick = function()
      Window.back()
    end
    controls.back, controls.forward = back, forward
  end

  if S("header.rule.show") then
    local rule = frame:CreateTexture(nil, "ARTWORK")

    rule:SetTexture(Bricks.media("solid"))
    rule:SetHeight(S("header.rule.size"))
    rule:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -height)
    rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -height)
    Bricks.paint(rule, "SetVertexColor", "borderDim")
    frame.rule = rule
  end

  frame.title, frame.version, frame.close, frame.search = title, version, close, searchBox

  return frame
end

local function loggedCount(journal, name)
  local total = 0

  for key, item in pairs(journal and journal[name] or {}) do
    if Problems.option(Problems.addonOf(key), "center") then
      total = total + item.n
    end
  end

  return total
end

local function refreshFooter()
  local items = footer and footer.items

  if not items then
    return
  end

  local names = EbonAPI:AddonNames()
  local updates = 0

  for _, name in ipairs(names) do
    if EbonAPI.Version.available(name) then
      updates = updates + 1
    end
  end

  local journal = Problems.journal()

  items.errors:SetValue(tostring(Problems.summary(nil, "center").count))
  items.warnings:SetValue(tostring(loggedCount(journal, "refusals") + loggedCount(journal, "rejects")))
  items.language:SetValue(upper(sub(EbonAPI:GetLanguage() or "", 1, 2)))
  items.addons:SetValue(format(L.UI_STATUS_ADDONS, #names))
  items.updates:SetValue(format(L.UI_STATUS_UPDATES, updates))
  items.errors.tipTitle, items.warnings.tipTitle = L.UI_STATUS_ERRORS, L.UI_STATUS_WARNINGS
  items.language.tipTitle = L.UI_LANGUAGE
  items.addons.tipTitle, items.updates.tipTitle = L.UI_ADDONS, L.UI_ADDONS

  local x = 0

  if footer.badge then
    x = footer.badge:GetWidth()
  elseif footer.version then
    x = S("window.padding") + S("footer.inset") + (footer.version:GetStringWidth() or 0) + S("footer.gap")
  end

  for _, item in ipairs({ items.errors, items.warnings }) do
    item:ClearAllPoints()
    item:SetPoint("LEFT", footer, "LEFT", x, 0)
    x = x + item:GetWidth()
  end

  local right = 0

  Lib.setShown(items.updates, updates > 0)

  for _, item in ipairs({ items.updates, items.addons, items.language }) do
    if item:IsShown() then
      item:ClearAllPoints()
      item:SetPoint("RIGHT", footer, "RIGHT", -right, 0)
      right = right + item:GetWidth()
    end
  end
end

local function statusItem(parent, icon)
  local item = CreateFrame("Button", nil, parent)
  local size, spacing = S("footer.icon"), S("header.spacing")
  local padding = floor(S("footer.gap") / 2)

  item:SetHeight(S("footer.height"))
  item.hover = item:CreateTexture(nil, "BACKGROUND")
  item.hover:SetTexture(Bricks.media("solid"))
  item.hover:SetAllPoints(item)
  Bricks.paint(item.hover, "SetVertexColor", "rowHover")
  item.hover:Hide()
  item.text = Bricks.text(item, "small", "text")

  if icon then
    item.icon = item:CreateTexture(nil, "ARTWORK")
    item.icon:SetTexture(icon)
    item.icon:SetWidth(size)
    item.icon:SetHeight(size)
    item.icon:SetPoint("LEFT", item, "LEFT", padding, 0)
    Bricks.paint(item.icon, "SetVertexColor", "text")
    item.text:SetPoint("LEFT", item.icon, "RIGHT", spacing, 0)
  else
    item.text:SetPoint("LEFT", item, "LEFT", padding, 0)
  end

  item:SetScript("OnEnter", function(self)
    self.hover:Show()
    Bricks.tip(self, self.tipTitle)
  end)
  item:SetScript("OnLeave", function(self)
    self.hover:Hide()
    Bricks.hideTip()
  end)
  item:SetScript("OnClick", function(self)
    if self.onClick then
      self.onClick()
    end
  end)

  function item:SetValue(text)
    local width

    self.text:SetText(text)
    width = (self.text:GetStringWidth() or 0) + padding * 2

    if self.icon then
      width = width + size + spacing
    end

    self:SetWidth(width)
  end

  return item
end

local function buildFooter()
  local frame = CreateFrame("Frame", nil, UIParent)

  frame:SetHeight(S("footer.height"))
  frame.background = blockBackground(frame, "footerBg")

  if S("footer.rule") then
    frame.rule = frame:CreateTexture(nil, "ARTWORK")
    frame.rule:SetTexture(Bricks.media("solid"))
    frame.rule:SetHeight(S("footer.ruleSize"))
    frame.rule:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    Bricks.paint(frame.rule, "SetVertexColor", "borderDim")
  end

  if S("footer.badge.show") then
    local badge = CreateFrame("Button", nil, frame)
    local padding = S("footer.badge.padding")

    badge.fill = blockBackground(badge, S("footer.badge.color"))
    badge.text = Bricks.text(badge, "small", S("footer.badge.text"))
    badge.text:SetPoint("LEFT", badge, "LEFT", padding, 0)
    badge.text:SetText(L.UI_NAME .. " " .. EbonAPI.version)
    badge:SetWidth((badge.text:GetStringWidth() or 0) + padding * 2)
    badge:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    badge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    badge:SetScript("OnClick", function()
      Window.select("EbonAPI", "general")
    end)
    frame.badge = badge
  elseif S("footer.version") then
    frame.version = Bricks.text(frame, "small", "muted")
    frame.version:SetPoint("LEFT", frame, "LEFT", S("window.padding") + S("footer.inset"), 0)
    frame.version:SetText(EbonAPI.version)
  end

  if S("footer.items") then
    local items = {
      errors = statusItem(frame, Bricks.media("error")),
      warnings = statusItem(frame, Bricks.media("warning")),
      language = statusItem(frame),
      addons = statusItem(frame),
      updates = statusItem(frame),
    }
    local elapsed, refresh = 0, S("footer.refresh")

    items.errors.onClick = function()
      Problems.open(nil)
    end
    items.warnings.onClick = items.errors.onClick
    items.language.onClick = function()
      Window.select("EbonAPI", "general")
    end
    items.addons.onClick = function()
      Window.select("EbonAPI", "addons")
    end
    items.updates.onClick = items.addons.onClick
    frame.items = items
    frame:SetScript("OnUpdate", function(_, delta)
      elapsed = elapsed + (delta or 0)

      if elapsed >= refresh then
        elapsed = 0
        refreshFooter()
      end
    end)
  end

  return frame
end

local function buildNav()
  local frame = CreateFrame("Frame", nil, UIParent)
  local panel = CreateFrame("Frame", nil, frame)
  local width, height = S("nav.width"), S("page.height")
  local divider = S("nav.divider.size")
  local style = S("nav.frame")

  frame:SetWidth(width)
  frame:SetHeight(height)
  panel:SetWidth(width)
  panel:SetHeight(height)

  if style ~= "NONE" then
    Bricks.frame(panel, lower(style), "navBg", S("window.card.border"))
  else
    panel.background = blockBackground(panel, "navBg")
  end

  if divider > 0 then
    panel.divider = panel:CreateTexture(nil, "ARTWORK")
    panel.divider:SetTexture(Bricks.media("solid"))
    panel.divider:SetWidth(divider)
    Bricks.paint(panel.divider, "SetVertexColor", S("nav.divider.color"))
  end

  if S("nav.rail.show") then
    frame.rail = CreateFrame("Frame", nil, frame)
    frame.rail:SetWidth(S("nav.rail.width"))
    frame.rail.background = blockBackground(frame.rail, S("nav.rail.color"))
    frame.rail.items = {}
  end

  navScroll = Bricks.create("scroll", panel)
  navScroll:SetAllPoints(panel)
  navScroll:SetView(width - S("nav.inset"), height)

  navPools.button = Bricks.slotPool("tab")
  navPools.label = Bricks.slotPool("section")
  frame.panel = panel

  return frame
end

local function create()
  if main then
    return main
  end

  main = Windows.create("main", NAME)

  if S("header.show") then
    header = buildHeader()
  end

  if S("footer.show") then
    footer = buildFooter()
  end

  nav = buildNav()

  if not S("windows.detach.pages") then
    mainView = newView("main", UIParent, false, true)
    page = mainView.frame
  end

  main.closeButton = closeButton
  main.header, main.nav, main.page, main.footer = header, nav, page, footer

  arrange()
  placeAll()
  Window.relabel()

  return main
end

function Window.relabel()
  refreshSearchHint()

  if searchHint then
    searchHint:SetText(L.UI_SEARCH)
  end

  if closeButton then
    closeButton.tipTitle = L.UI_CLOSE
  end

  for name, key in pairs(TIPS) do
    if controls[name] then
      controls[name].tipTitle = L[key]
    end
  end

  for _, view in pairs(views) do
    if view.close then
      view.close.tipTitle = L.UI_CLOSE
    end

    if view.strip then
      for _, tab in ipairs(view.strip.tabs) do
        if tab.close then
          tab.close.tipTitle = L.UI_CLOSE
        end
      end
    end
  end
end

function Window.refresh()
  if main and Windows.anyShown() then
    refreshFooter()
    Window.buildNav()
    Window.render()
  end
end

local function clearQuery()
  if query ~= "" then
    query = ""

    if searchBox then
      searchBox:SetText("")
    end

    if searchWindow then
      searchWindow:Hide()
    end

    refreshSearchHint()
  end
end

function Window.select(owner, key)
  clearQuery()
  showPage(owner, key)
  Window.buildNav()
  Window.render()
end

local function travel(step)
  local target = history[cursor + step]

  if not target or not main then
    return false
  end

  cursor = cursor + step
  traveling = true
  clearQuery()

  local ok, err = pcall(showPage, target.owner, target.key)

  traveling = false

  if not ok then
    error(err, 0)
  end

  Window.buildNav()
  Window.render()

  return true
end

function Window.back()
  return travel(-1)
end

function Window.forward()
  return travel(1)
end

function Window.history()
  return history, cursor
end

function Window.openTabs()
  return openTabs
end

local function shownTab(entry)
  return entry and pageName(entry.owner, entry.key) and entry or nil
end

function Window.closeTab(owner, key)
  for index, entry in ipairs(openTabs) do
    if entry.owner == owner and entry.key == key then
      remove(openTabs, index)

      if shown.owner == owner and shown.key == key then
        local nearby = shownTab(openTabs[index]) or shownTab(openTabs[index - 1])

        if nearby then
          Window.select(nearby.owner, nearby.key)
          return true
        end
      end

      Window.refresh()
      return true
    end
  end

  return false
end

function Window.railSelect(owner)
  railOwner = owner
  navHidden = false

  if main then
    arrange()
    Window.refresh()
  end
end

function Window.toggleNav()
  navHidden = not navHidden

  if main then
    arrange()
    Window.refresh()
  end

  return navHidden
end

function Window.isNavHidden()
  return navHidden
end

function Window.control(name)
  return controls[name]
end

function Window.open(owner, key)
  create()

  local wasShown = Windows.anyShown()

  if main.used then
    main:Show()
  end

  for _, id in ipairs(BLOCK_ORDER) do
    local host = Windows.get(id)

    if host then
      host:Show()
    end
  end

  if owner then
    showPage(owner, key)
  elseif not mainView and not anyPageShown() then
    showPage(selected.owner, selected.key)
  elseif cursor == 0 then
    remember(shown.owner, shown.key)
  end

  if not wasShown then
    Bricks.sound("window.sound.open")
  end

  refreshFooter()
  Window.buildNav()
  Window.render()

  return main
end

function Window.close()
  Windows.hideAll()
end

function Window.shade()
  if not main or not header or header:GetParent() ~= main then
    return nil
  end

  if shaded then
    shaded = false
    arrange()
  else
    shaded = true
    rollUp()
  end

  return shaded
end

function Window.isShaded()
  return shaded
end

function Window.toggle()
  if Windows.anyShown() then
    Window.close()
    return false
  end

  Window.open()

  return true
end

function Window.isShown()
  return main ~= nil and Windows.anyShown()
end

function Window.frame()
  return main
end

function Window.selected()
  return selected.owner, selected.key
end

function Window.search(text)
  create()

  if searchBox then
    searchBox:SetText(text or "")
    searchBox:GetScript("OnTextChanged")(searchBox)
  else
    setQuery(text)
  end
end

function Window.view(id)
  return views[id or "main"]
end

function Window.views()
  return views
end

function Window.pageWindow(owner, key)
  return pageWindows[pageId(owner, key)]
end

function Window.searchWindow()
  return searchWindow
end

function Window.pool(kind, id)
  if id then
    return views[id] and views[id].pools[kind]
  end

  return (views.main and views.main.pools[kind]) or navPools[kind]
end

local function hideMenus()
  if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
    if HideUIPanel then
      HideUIPanel(InterfaceOptionsFrame)
    else
      InterfaceOptionsFrame:Hide()
    end
  end

  if GameMenuFrame and GameMenuFrame:IsShown() then
    if HideUIPanel then
      HideUIPanel(GameMenuFrame)
    else
      GameMenuFrame:Hide()
    end
  end
end

local function installPanel()
  if not InterfaceOptions_AddCategory then
    return
  end

  local panel = CreateFrame("Frame", nil, UIParent)

  panel.name = L.UI_NAME

  local margin = S("panel.margin")
  local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

  text:SetPoint("TOPLEFT", panel, "TOPLEFT", margin, -margin)
  text:SetPoint("RIGHT", panel, "RIGHT", -margin, 0)
  text:SetJustifyH("LEFT")

  local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")

  open:SetWidth(S("panel.button.width"))
  open:SetHeight(S("panel.button.height"))
  open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -S("panel.gap"))
  open:SetScript("OnClick", function()
    hideMenus()
    Window.open()
  end)

  panel:SetScript("OnShow", function()
    text:SetText(L.UI_PANEL_TEXT)
    open:SetText(L.UI_OPEN)
  end)

  InterfaceOptions_AddCategory(panel)
  Window.panel = panel
end

local function installGameMenu()
  local menu, logout = GameMenuFrame, GameMenuButtonLogout

  if not menu or not logout then
    return
  end

  local button = CreateFrame("Button", nil, menu, "GameMenuButtonTemplate")

  button:SetScript("OnClick", function()
    hideMenus()
    Window.open()
  end)

  local padding = nil

  local function isChained()
    local at = logout

    while at do
      local _, relative = at:GetPoint(1)

      if relative == button then
        return true
      end

      at = relative
    end

    return false
  end

  local function place()
    local point, relative, relativePoint, x, y = logout:GetPoint(1)

    if relative and not isChained() then
      button:ClearAllPoints()
      button:SetPoint("TOP", relative, "BOTTOM", 0, -S("gamemenu.gap"))
      logout:ClearAllPoints()
      logout:SetPoint(point, button, relativePoint, x, y)
    end
  end

  local function lowest()
    local bottom = nil

    for _, child in ipairs({ menu:GetChildren() }) do
      if child:IsShown() and child:GetObjectType() == "Button" then
        local edge = child:GetBottom()

        if edge and (not bottom or edge < bottom) then
          bottom = edge
        end
      end
    end

    return bottom
  end

  local function refresh()
    if not padding then
      local bottom, base = lowest(), menu:GetBottom()

      if not bottom or not base then
        return
      end

      padding = bottom - base
    end

    place()

    local top, bottom = menu:GetTop(), lowest()

    if top and bottom then
      menu:SetHeight(top - bottom + padding)
    end
  end

  local waiter = CreateFrame("Frame", nil, menu)

  waiter:Hide()
  waiter:SetScript("OnUpdate", function(self)
    self:Hide()
    refresh()
  end)

  refresh()
  menu:HookScript("OnShow", function()
    refresh()
    waiter:Show()
  end)

  Window.menuButton = button
  Window.paintMenuButton()
end

function Window.paintMenuButton()
  if Window.menuButton then
    Window.menuButton:SetText(Palette.code("menu") .. L.UI_NAME .. "|r")
  end
end

function Window.install()
  if installed then
    return
  end

  installed = true

  EbonAPI:On("PARAMETER_CHANGED", function(_, name)
    Bricks.apply()
    Window.paintMenuButton()

    if main then
      if name == "tabs" then
        arrange()
      end

      Window.refresh()
    end
  end)

  EbonAPI:On("LANGUAGE_CHANGED", function()
    Window.relabel()
    Window.refresh()
  end)

  EbonAPI:On("OPTIONS_CHANGED", function()
    Window.refresh()
  end)

  installPanel()
  installGameMenu()
end

local function requireOptions(owner)
  if not Options.has(owner) then
    error("EbonAPI: " .. tostring(owner) .. ": OpenOptions needs options registered with api:Options first", 3)
  end
end

function EbonAPI:OpenOptions(owner, key)
  if owner then
    requireOptions(owner)
  end

  return Window.open(owner, key)
end

function Handle:OpenOptions(key)
  requireOptions(self.addonName)

  return Window.open(self.addonName, key)
end
