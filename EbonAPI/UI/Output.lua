EbonAPI = EbonAPI or {}
EbonAPI.Output = {}

-- The output brick: a framed box with a guaranteed background (the "well" palette key, which the
-- player's opacity does not lower), its own scroll and a Copy button. A model describes what it shows;
-- Output.kinds[kind] draws one kind of model and returns the height of its content. Only "text" exists
-- for now (a model { kind = "text", text = "..." }); other kinds (sheet, journal, opcodes) are added there.
-- The default implementation is composed of the current skin's bricks (scroll, button) and keys.

local Output = EbonAPI.Output
local Bricks = EbonAPI.Bricks
local L = EbonAPI.L

local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil
local ipairs = ipairs
local format = string.format
local S =Bricks.value
local FRAMES = { LARGE = "large", SMALL = "small", FLAT = "flat" }
local GAP = 4

Bricks.CONTRACT.output = { "SetModel", "SetWidth", "Refresh" }

Output.kinds = {}

Output.kinds.text = function(widget, model, width)
  local text = widget.text

  text:SetWidth(width)
  text:SetText(model.text or "")

  return floor(max(text:GetStringHeight() or 0, text:GetHeight() or 0) + 0.5)
end

-- Fiche : sections de lignes « libellé / valeur », marqueur d'état, pastilles. Éléments réutilisés d'un
-- dessin à l'autre (widget.fiche) ; aucune couleur ni police en dur : tout vient du skin.
local MARKERS = {
  ok = { texture = "Interface\\Buttons\\UI-CheckBox-Check", color = "success", scale = 1 },
  warn = { media = "warning", color = "caution", scale = 1 },
  bad = { media = "error", color = "danger", scale = 1 },
  info = { media = "circle", color = "muted", scale = 0.5 },
  net = { media = "arrow", color = "focus", scale = 1 },
}

Output.MARKERS = MARKERS

local function hideFiche(widget)
  local f = widget.fiche

  if f then
    for _, list in ipairs({ f.fs, f.tex, f.fr }) do
      for _, item in ipairs(list) do
        item:Hide()
      end
    end

    f.used = { fs = 0, tex = 0, fr = 0 }
  end
end

local function take(widget, kind)
  widget.fiche = widget.fiche or { fs = {}, tex = {}, fr = {}, used = { fs = 0, tex = 0, fr = 0 } }

  local f = widget.fiche
  local list, used = f[kind], f.used
  local n = used[kind] + 1
  local item = list[n]

  used[kind] = n

  if not item then
    local child = widget.scroll.child

    if kind == "fs" then
      item = Bricks.text(child, "normal", "text")
      item:SetJustifyH("LEFT")
      item:SetJustifyV("TOP")
    elseif kind == "tex" then
      item = child:CreateTexture(nil, "ARTWORK")
    else
      item = CreateFrame("Frame", nil, child)
      item.text = Bricks.text(item, "small", "text")
    end

    list[n] = item
  end

  item:Show()

  return item
end

local function words(widget, x, y, width, role, key, text)
  local fs = take(widget, "fs")

  Bricks.font(fs, role)
  Bricks.paint(fs, "SetTextColor", key)
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", widget.scroll.child, "TOPLEFT", x, -y)
  fs:SetWidth(width)
  fs:SetJustifyH("LEFT")
  fs:SetText(text or "")

  return fs, ceil(fs:GetStringHeight() or 0)
end

local function marker(widget, level, x, y, size)
  local spec = MARKERS[level]

  if not spec then
    return
  end

  local tex = take(widget, "tex")
  local side = max(2, floor(size * spec.scale + 0.5))
  local pad = floor((size - side) / 2)

  tex:SetTexture(spec.texture or Bricks.media(spec.media))
  Bricks.paint(tex, "SetVertexColor", spec.color)
  tex:SetWidth(side)
  tex:SetHeight(side)
  tex:ClearAllPoints()
  tex:SetPoint("TOPLEFT", widget.scroll.child, "TOPLEFT", x + pad, -(y + pad))
  tex.level = level
end

-- Pastilles posées à la suite, à la ligne quand la largeur manque ; rend la hauteur occupée.
local function chips(widget, list, x, y, width)
  local padding = S("kit.tag.padding")
  local gap = S("widgets.output.row.gap")
  local cx, cy, lineH = 0, 0, 0

  for _, label in ipairs(list) do
    local fr = take(widget, "fr")
    local text = fr.text

    Bricks.frame(fr, "small", "well", S("kit.tag.color"))
    Bricks.font(text, S("kit.tag.font"))
    Bricks.paint(text, "SetTextColor", S("kit.tag.text"))
    text:SetWidth(0)
    text:SetText(tostring(label))

    local w = min(ceil(text:GetStringWidth() or 0) + padding * 2, width)
    local h = ceil(text:GetStringHeight() or 0) + padding

    text:ClearAllPoints()
    text:SetPoint("CENTER", fr, "CENTER", 0, 0)

    if cx > 0 and cx + w > width then
      cx, cy, lineH = 0, cy + lineH + gap, 0
    end

    fr:SetWidth(w)
    fr:SetHeight(h)
    fr:ClearAllPoints()
    fr:SetPoint("TOPLEFT", widget.scroll.child, "TOPLEFT", x + cx, -(y + cy))
    cx, lineH = cx + w + gap, max(lineH, h)
  end

  return cy + lineH
end

-- Filet sous un titre de section : une ligne d'un pixel, teinte borderDim, à la hauteur y.
local function lineRule(widget, y, width)
  local line = take(widget, "tex")

  line:SetTexture(Bricks.media("solid"))
  Bricks.paint(line, "SetVertexColor", "borderDim")
  line:SetWidth(width)
  line:SetHeight(1)
  line:ClearAllPoints()
  line:SetPoint("TOPLEFT", widget.scroll.child, "TOPLEFT", 0, -y)
  line.level = "rule"

  return line
end

Output.kinds.rows = function(widget, model, width)
  widget.fiche = widget.fiche or { fs = {}, tex = {}, fr = {}, used = { fs = 0, tex = 0, fr = 0 } }
  widget.sectionY = {}
  widget.text:SetText("")
  hideFiche(widget)

  local gap = S("widgets.output.row.gap")
  local size = S("widgets.output.marker.size")
  local labelW = min(S("widgets.output.label.width"), max(20, floor((width - size - gap * 2) / 2)))
  local valueX = size + gap + labelW + gap
  local valueW = max(1, width - valueX)
  local y = 0

  for index, section in ipairs(model.sections or {}) do
    if index > 1 then
      y = y + gap * 3
    end

    widget.sectionY[section.id] = y

    local _, h = words(widget, 0, y, width, S("widgets.output.section.font"), S("widgets.output.section.color"),
      section.name)

    y = y + h + 2
    lineRule(widget, y, width)
    y = y + 1 + gap

    for _, row in ipairs(section.rows or {}) do
      marker(widget, row.level, 0, y, size)

      local _, lh = words(widget, size + gap, y, labelW, "normal", S("widgets.output.label.color"), row.label)
      local rh

      if row.chips then
        rh = chips(widget, row.chips, valueX, y, valueW)
      else
        local tagW = 0
        local tag

        if row.tag then
          tag = take(widget, "fs")
          Bricks.font(tag, S("kit.tag.font"))
          Bricks.paint(tag, "SetTextColor", "caution")
          tag:SetWidth(0)
          tag:SetText(tostring(row.tag))
          tagW = min(ceil(tag:GetStringWidth() or 0), floor(valueW / 3))
          tag:SetWidth(tagW)
          tag:ClearAllPoints()
          tag:SetPoint("TOPLEFT", widget.scroll.child, "TOPLEFT", width - tagW, -y)
          tagW = tagW + gap
        end

        local _, vh = words(widget, valueX, y, max(1, valueW - tagW), "normal", S("widgets.output.value.color"),
          row.value)

        rh = vh
      end

      y = y + max(size, lh, rh or 0) + gap
    end
  end

  return y
end

-- Journal des traces : une ligne (Button) par trace, détail dépliable ; réserve d'éléments réutilisée (128 au plus).
local LOG_MAX = 128

local function hideJournal(widget)
  local j = widget.journal

  if j then
    for _, it in ipairs(j.items) do
      it.btn:Hide()
      it.detail.text:Hide()
      it.detail.meta:Hide()
      it.detail.copy:Hide()
    end

    j.empty:Hide()
    j.used = 0
  end

  if widget.count then
    widget.count:SetText("")
    widget.count:Hide()
  end
end

local function newLogItem(widget)
  local child = widget.scroll.child
  local btn = CreateFrame("Button", nil, child)
  local it = { btn = btn }

  it.band = btn:CreateTexture(nil, "BACKGROUND")
  it.band:SetTexture(Bricks.media("solid"))
  it.band:SetAllPoints(btn)
  it.hover = btn:CreateTexture(nil, "BORDER")
  it.hover:SetTexture(Bricks.media("solid"))
  it.hover:SetAllPoints(btn)
  it.hover:Hide()
  it.mark = btn:CreateTexture(nil, "ARTWORK")
  it.time = Bricks.text(btn, "small", "muted")
  it.time:SetJustifyH("RIGHT")
  it.time:SetJustifyV("TOP")
  it.owner = Bricks.text(btn, "small", "muted")
  it.owner:SetJustifyH("LEFT")
  it.owner:SetJustifyV("TOP")
  it.msg = Bricks.text(btn, "normal", "text")
  it.msg:SetJustifyH("LEFT")
  it.msg:SetJustifyV("TOP")

  local copyBtn = Bricks.create("button", child)

  copyBtn:SetLabel(L.UI_JOURNAL_COPY_ROW)
  copyBtn:Fit()

  it.detail = {
    text = Bricks.text(child, "normal", "text"),
    meta = Bricks.text(child, "small", "muted"),
    copy = copyBtn,
  }
  it.detail.text:SetJustifyH("LEFT")
  it.detail.text:SetJustifyV("TOP")
  it.detail.meta:SetJustifyH("LEFT")
  it.detail.meta:SetJustifyV("TOP")

  btn:SetScript("OnEnter", function()
    it.hover:Show()
  end)
  btn:SetScript("OnLeave", function()
    it.hover:Hide()
  end)
  btn:SetScript("OnClick", function()
    if it.row and EbonAPI.Settings then
      EbonAPI.Settings.toggleLogOpen(it.row.key)
      widget:Refresh()
    end
  end)
  copyBtn.onClick = function()
    if it.row and EbonAPI.Handle then
      EbonAPI.Handle.CopyBox({ addonName = "EbonAPI" }, EbonAPI.Settings.logText({ it.row }), L.UI_RESULT)
    end
  end

  return it
end

local function ageText(age)
  local s = format("%.1f", age or 0)

  if GetLocale and GetLocale() ~= "enUS" then
    s = s:gsub("%.", ",")
  end

  return s
end

Output.kinds.log = function(widget, model, width)
  local child = widget.scroll.child

  widget.journal = widget.journal or { items = {}, used = 0, empty = Bricks.text(child, "normal", "muted") }
  widget.sectionY = nil
  widget.text:SetText("")
  hideJournal(widget)

  local j = widget.journal
  local rows = model.rows or {}
  local n = min(#rows, LOG_MAX)
  local gap = S("widgets.output.log.gap")
  local size = S("widgets.output.marker.size")
  local timeW = S("widgets.output.log.time")
  local ownerW = S("widgets.output.log.owner")
  local tint = S("widgets.output.log.tint")
  local open = EbonAPI.Settings and EbonAPI.Settings.logState().open or {}
  local pad = gap * 2
  local ownerX = timeW + pad + size + pad
  local msgX = ownerX + ownerW + pad
  local msgW = max(20, width - msgX)
  local y = 0

  model.countText = n == 1 and format(L.UI_JOURNAL_COUNT_ONE, 1) or format(L.UI_JOURNAL_COUNT, n)
  widget.count:SetText(model.countText)
  widget.count:Show()

  if n == 0 then
    Bricks.font(j.empty, "normal")
    Bricks.paint(j.empty, "SetTextColor", "muted")
    j.empty:ClearAllPoints()
    j.empty:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    j.empty:SetWidth(width)
    j.empty:SetText(L.UI_JOURNAL_EMPTY)
    j.empty:Show()

    return ceil(j.empty:GetStringHeight() or 0)
  end

  for i = 1, n do
    local row = rows[i]
    local it = j.items[i]

    if not it then
      it = newLogItem(widget)
      j.items[i] = it
    end

    it.row = row

    local spec = MARKERS[row.level] or MARKERS.info
    local side = max(2, floor(size * spec.scale + 0.5))
    local mpad = floor((size - side) / 2)

    Bricks.font(it.time, "small")
    Bricks.paint(it.time, "SetTextColor", "muted")
    Bricks.font(it.owner, "small")
    Bricks.paint(it.owner, "SetTextColor", "muted")
    Bricks.font(it.msg, "normal")
    Bricks.paint(it.msg, "SetTextColor", "text")

    it.time:SetText(format(L.UI_JOURNAL_AGE, ageText(row.age)))
    it.owner:SetText(row.owner or EbonAPI.name or "")
    it.msg:SetText(row.text or "")

    it.time:ClearAllPoints()
    it.time:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    it.time:SetWidth(timeW)
    it.owner:ClearAllPoints()
    it.owner:SetPoint("TOPLEFT", child, "TOPLEFT", ownerX, -y)
    it.owner:SetWidth(ownerW)
    it.msg:ClearAllPoints()
    it.msg:SetPoint("TOPLEFT", child, "TOPLEFT", msgX, -y)
    it.msg:SetWidth(msgW)

    it.mark:SetTexture(spec.texture or Bricks.media(spec.media))
    Bricks.paint(it.mark, "SetVertexColor", spec.color)
    it.mark:SetWidth(side)
    it.mark:SetHeight(side)
    it.mark:ClearAllPoints()
    it.mark:SetPoint("TOPLEFT", child, "TOPLEFT", timeW + pad + mpad, -(y + mpad))
    it.mark.level = row.level

    local h = max(size, ceil(it.msg:GetStringHeight() or 0), ceil(it.time:GetStringHeight() or 0))

    it.btn:ClearAllPoints()
    it.btn:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    it.btn:SetWidth(width)
    it.btn:SetHeight(h)

    if row.level == "bad" or row.level == "warn" then
      Bricks.paint(it.band, "SetVertexColor", row.level == "bad" and "danger" or "caution")
      it.band:SetAlpha(tint)
      it.band:Show()
    else
      it.band:Hide()
    end

    Bricks.paint(it.hover, "SetVertexColor", "rowHover")
    it.hover:Hide()
    it.btn:Show()
    y = y + h + gap

    local d = it.detail

    if open[row.key] then
      local dw = max(20, width - timeW - pad)
      local dx = timeW + pad

      Bricks.font(d.text, "normal")
      Bricks.paint(d.text, "SetTextColor", "text")
      d.text:ClearAllPoints()
      d.text:SetPoint("TOPLEFT", child, "TOPLEFT", dx, -y)
      d.text:SetWidth(dw)
      d.text:SetText(row.text or "")
      d.text:Show()
      y = y + ceil(d.text:GetStringHeight() or 0) + gap

      Bricks.font(d.meta, "small")
      Bricks.paint(d.meta, "SetTextColor", "muted")
      d.meta:ClearAllPoints()
      d.meta:SetPoint("TOPLEFT", child, "TOPLEFT", dx, -y)
      d.meta:SetWidth(dw)
      d.meta:SetText(format(L.UI_JOURNAL_META, row.owner or EbonAPI.name or "", format(L.UI_JOURNAL_AGE, ageText(row.age))))
      d.meta:Show()
      y = y + ceil(d.meta:GetStringHeight() or 0) + gap

      d.copy:ClearAllPoints()
      d.copy:SetPoint("TOPLEFT", child, "TOPLEFT", dx, -y)
      d.copy:Show()
      y = y + d.copy:GetHeight() + gap
    else
      d.text:Hide()
      d.meta:Hide()
      d.copy:Hide()
    end
  end

  j.used = n

  return y
end

function Output.scrollToSection(widget, id)
  local top = widget.sectionY and widget.sectionY[id]

  if not top then
    return false
  end

  widget.scroll:SetOffset(top)

  return true
end

-- Table des opcodes : en-tête de trois colonnes (tri au clic) puis une ligne par opcode. Réserve de lignes réutilisée.
local OPS_MAX = 128
local OPS_COLUMNS = {
  { key = "dir", label = "UI_OPS_COL_DIR" },
  { key = "code", label = "UI_OPS_COL_CODE" },
  { key = "name", label = "UI_OPS_COL_NAME" },
}

local function hideOps(widget)
  local v = widget.opsView

  if v then
    for _, b in ipairs(v.head.btns) do
      b:Hide()
    end

    v.head.arrow:Hide()

    for _, it in ipairs(v.items) do
      it.btn:Hide()
    end

    v.empty:Hide()
    v.used = 0
  end
end

local function refreshOps(widget)
  local fresh = EbonAPI.Settings.resultModel()
  local model = widget.model

  if not (model and fresh and fresh.kind == "ops") then
    return
  end

  for _, field in ipairs({ "rows", "text", "filter", "total", "query", "sort", "desc", "counts", "countText" }) do
    model[field] = fresh[field]
  end

  widget:Refresh()
end

local function newOpsHead(widget)
  local child = widget.scroll.child
  local head = { btns = {}, arrow = child:CreateTexture(nil, "OVERLAY") }

  head.arrow:SetTexture(Bricks.media("chevron"))

  for i, col in ipairs(OPS_COLUMNS) do
    local btn = CreateFrame("Button", nil, child)

    btn.key = col.key
    btn.label = Bricks.text(btn, "small", "text")
    btn.label:SetJustifyH(col.key == "code" and "RIGHT" or "LEFT")
    btn:SetScript("OnClick", function()
      if EbonAPI.Settings then
        EbonAPI.Settings.setOpsSort(col.key)
        refreshOps(widget)
      end
    end)
    head.btns[i] = btn
  end

  return head
end

local function newOpsItem(widget)
  local child = widget.scroll.child
  local btn = CreateFrame("Button", nil, child)
  local it = { btn = btn }

  it.hover = btn:CreateTexture(nil, "BACKGROUND")
  it.hover:SetTexture(Bricks.media("solid"))
  it.hover:SetAllPoints(btn)
  it.hover:Hide()
  it.dir = Bricks.text(btn, "small", "heading")
  it.dir:SetJustifyH("LEFT")
  it.dir:SetJustifyV("TOP")
  it.code = Bricks.text(btn, "normal", "muted")
  it.code:SetJustifyH("RIGHT")
  it.code:SetJustifyV("TOP")
  it.name = Bricks.text(btn, "normal", "text")
  it.name:SetJustifyH("LEFT")
  it.name:SetJustifyV("TOP")
  btn:SetScript("OnEnter", function()
    it.hover:Show()
  end)
  btn:SetScript("OnLeave", function()
    it.hover:Hide()
  end)

  return it
end

Output.kinds.ops = function(widget, model, width)
  local child = widget.scroll.child

  widget.opsView = widget.opsView or {
    head = newOpsHead(widget), items = {}, used = 0, empty = Bricks.text(child, "normal", "muted"),
  }
  widget.sectionY = nil
  widget.text:SetText("")
  hideOps(widget)

  local v = widget.opsView
  local rows = model.rows or {}
  local n = min(#rows, OPS_MAX)
  local gap = S("widgets.output.log.gap")
  local size = S("widgets.output.marker.size")
  local dirW = S("widgets.output.ops.dir")
  local codeW = S("widgets.output.ops.code")
  local pad = gap * 2
  local codeX = dirW + pad
  local nameX = codeX + codeW + pad
  local nameW = max(20, width - nameX)
  local xs = { 0, codeX, nameX }
  local ws = { dirW, codeW, nameW }
  local y = 0
  local headH = size

  for i, btn in ipairs(v.head.btns) do
    local arrowRoom = size + gap

    Bricks.font(btn.label, "small")
    Bricks.paint(btn.label, "SetTextColor", "text")
    btn.label:SetText(L[OPS_COLUMNS[i].label])
    btn.label:ClearAllPoints()
    btn.label:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    btn.label:SetWidth(max(10, ws[i] - arrowRoom))
    headH = max(headH, ceil(btn.label:GetStringHeight() or 0))
  end

  for i, btn in ipairs(v.head.btns) do
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", child, "TOPLEFT", xs[i], 0)
    btn:SetWidth(ws[i])
    btn:SetHeight(headH)
    btn:Show()

    if btn.key == model.sort then
      local arrow = v.head.arrow

      arrow.owner = btn
      arrow.turned = model.desc and "DOWN" or "UP"
      Bricks.turn(arrow, arrow.turned)
      Bricks.paint(arrow, "SetVertexColor", "muted")
      arrow:SetWidth(size)
      arrow:SetHeight(size)
      arrow:ClearAllPoints()
      arrow:SetPoint("TOPLEFT", child, "TOPLEFT", xs[i] + ws[i] - size, -floor((headH - size) / 2))
      arrow:Show()
    end
  end

  y = headH + gap
  model.countText = n == 1 and format(L.UI_JOURNAL_COUNT_ONE, 1) or format(L.UI_JOURNAL_COUNT, n)
  widget.count:SetText(model.countText)
  widget.count:Show()

  if n == 0 then
    Bricks.font(v.empty, "normal")
    Bricks.paint(v.empty, "SetTextColor", "muted")
    v.empty:ClearAllPoints()
    v.empty:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    v.empty:SetWidth(width)
    v.empty:SetText(L.UI_JOURNAL_EMPTY)
    v.empty:Show()

    return y + ceil(v.empty:GetStringHeight() or 0)
  end

  for i = 1, n do
    local row = rows[i]
    local it = v.items[i]

    if not it then
      it = newOpsItem(widget)
      v.items[i] = it
    end

    it.row = row

    Bricks.font(it.dir, "small")
    Bricks.paint(it.dir, "SetTextColor", row.dir == "ss" and "heading" or "focus")
    Bricks.font(it.code, "normal")
    Bricks.paint(it.code, "SetTextColor", "muted")
    Bricks.font(it.name, "normal")
    Bricks.paint(it.name, "SetTextColor", "text")
    it.dir:SetText(row.dir == "ss" and L.UI_OPS_DIR_SS or L.UI_OPS_DIR_CS)
    it.code:SetText(tostring(row.code))
    it.name:SetText(tostring(row.name or ""))

    it.dir:ClearAllPoints()
    it.dir:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    it.dir:SetWidth(dirW)
    it.code:ClearAllPoints()
    it.code:SetPoint("TOPLEFT", child, "TOPLEFT", codeX, -y)
    it.code:SetWidth(codeW)
    it.name:ClearAllPoints()
    it.name:SetPoint("TOPLEFT", child, "TOPLEFT", nameX, -y)
    it.name:SetWidth(nameW)

    local h = max(ceil(it.name:GetStringHeight() or 0), ceil(it.code:GetStringHeight() or 0),
      ceil(it.dir:GetStringHeight() or 0))

    it.btn:ClearAllPoints()
    it.btn:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    it.btn:SetWidth(width)
    it.btn:SetHeight(h)
    Bricks.paint(it.hover, "SetVertexColor", "rowHover")
    it.hover:Hide()
    it.btn:Show()
    y = y + h + gap
  end

  v.used = n

  return y
end

-- Gives the synthesis brick its source, its click behaviour and its rebuild.
function Output.hookSynthesis(widget, syn)
  syn.source = function()
    local Synth = EbonAPI.Synthesis
    local report = widget.model and widget.model.report

    if not Synth then
      return nil
    end

    if report and Synth.forReport then
      local groups = Synth.forReport(report)

      if groups then
        return groups
      end
    end

    return Synth.status and Synth.status() or nil
  end
  syn.onRebuild = function(groups)
    if widget.model then
      widget.model.groups = groups
      widget:Refresh()
    end
  end
  syn.onSelect = function(item)
    local target = item and item.target

    if type(target) ~= "table" then
      return
    end

    if target.filter then
      local Settings = EbonAPI.Settings
      local model = widget.model

      if Settings and model and model.kind == "log" then
        local id = target.filter

        if Settings.logState().filter == id then
          id = "all"
        end

        Settings.setLogFilter(id)

        local fresh = Settings.resultModel()

        if fresh and fresh.kind == "log" then
          model.rows, model.text, model.filter, model.total = fresh.rows, fresh.text, fresh.filter, fresh.total
          model.query, model.reverse = fresh.query, fresh.reverse
        end

        widget:Refresh()
      elseif Settings and model and model.kind == "ops" then
        local id = target.filter

        if Settings.opsState().filter == id then
          id = "all"
        end

        Settings.setOpsFilter(id)
        refreshOps(widget)
        syn.activeId = widget.model.filter
        syn:Refresh()
      end
    elseif target.section then
      if syn.activeId == item.id then
        syn.activeId = nil
        syn:Refresh()
      elseif widget:ScrollToSection(target.section) ~= false then
        syn.activeId = item.id
        syn:Refresh()
      end
    elseif target.queue and EbonAPI.QueueView then
      pcall(EbonAPI.QueueView.open)
      pcall(EbonAPI.QueueView.select, target.queue)
    end
  end
end

-- Barre d'outils du journal : onglets de niveau, recherche, ordre. Créée une fois par widget (et par jeu de briques).
local LEVELS = {
  { id = "all", key = "UI_SYNTH_LEVEL_ALL" }, { id = "bad", key = "UI_SYNTH_LEVEL_BAD" },
  { id = "warn", key = "UI_SYNTH_LEVEL_WARN" }, { id = "net", key = "UI_SYNTH_LEVEL_NET" },
  { id = "oth", key = "UI_SYNTH_LEVEL_OTHER" },
}

local function applyLog(widget)
  local fresh = EbonAPI.Settings.resultModel()
  local model = widget.model

  if not (model and fresh and fresh.kind == "log") then
    return
  end

  for _, field in ipairs({ "rows", "text", "filter", "total", "query", "reverse", "counts", "countText" }) do
    model[field] = fresh[field]
  end

  widget:Refresh()
end

local OPS_TABS = {
  { id = "all", key = "UI_SYNTH_OPCODES_ALL" }, { id = "ss", key = "UI_OPS_DIR_SS" }, { id = "cs", key = "UI_OPS_DIR_CS" },
}

-- Description d'une barre : genre du modèle, onglets, champs du widget, état (Settings) et rafraîchissement.
local BARS = {
  log = {
    kind = "log", tabs = LEVELS, toggle = true, slots = { "tab", "toggle", "input" }, apply = applyLog,
    fields = { bar = "bar", tabs = "barTabs", input = "barInput", toggle = "barToggle", signature = "barSignature", sync = "barSync" },
    state = function() return EbonAPI.Settings.logState() end,
    setFilter = function(id) EbonAPI.Settings.setLogFilter(id) end,
    setQuery = function(text) EbonAPI.Settings.setLogQuery(text) end,
  },
  ops = {
    kind = "ops", tabs = OPS_TABS, toggle = false, slots = { "tab", "input" }, apply = refreshOps,
    fields = { bar = "opsBar", tabs = "opsBarTabs", input = "opsBarInput", signature = "opsBarSignature", sync = "opsBarSync" },
    state = function() return EbonAPI.Settings.opsState() end,
    setFilter = function(id) EbonAPI.Settings.setOpsFilter(id) end,
    setQuery = function(text) EbonAPI.Settings.setOpsQuery(text) end,
  },
}

local function barSignature(spec)
  local catalog = EbonAPI.Catalog
  local parts = {}

  for _, slot in ipairs(spec.slots) do
    parts[#parts + 1] = tostring(S(catalog.slotKey(slot)))
  end

  return table.concat(parts, "|")
end

local function buildBar(widget, well, spec)
  local Settings = EbonAPI.Settings
  local f = spec.fields
  local bar = CreateFrame("Frame", nil, well)
  local tabs = {}

  for _, level in ipairs(spec.tabs) do
    local btn = Bricks.create("tab", bar)
    local id = level.id

    btn.onClick = function()
      if spec.state().filter == id then
        return
      end

      spec.setFilter(id)
      spec.apply(widget)
    end
    tabs[#tabs + 1] = { id = id, key = level.key, btn = btn }
  end

  local input = Bricks.create("input", bar)

  input:SetLines(1)
  input.edit:HookScript("OnTextChanged", function(edit)
    if widget[f.sync] then
      return
    end

    local text = edit:GetText() or ""

    if text == spec.state().query then
      return
    end

    input.value = text
    spec.setQuery(text)
    spec.apply(widget)
  end)

  widget[f.bar], widget[f.tabs], widget[f.input] = bar, tabs, input

  if spec.toggle then
    local toggle = Bricks.create("toggle", bar)

    toggle:SetLabel(L.UI_JOURNAL_REVERSE)
    toggle.onToggle = function(value)
      Settings.setLogReverse(value)
      applyLog(widget)
    end
    widget[f.toggle] = toggle
  end

  widget[f.signature] = barSignature(spec)
end

local function layoutBar(widget, well, inset, width, model, spec)
  local f = spec.fields

  if not (model and model.kind == spec.kind and model.counts) then
    if widget[f.bar] then
      widget[f.bar]:Hide()
    end

    return 0
  end

  if widget[f.bar] and widget[f.signature] ~= barSignature(spec) then
    widget[f.bar]:Hide()
    widget[f.bar] = nil
  end

  if not widget[f.bar] then
    buildBar(widget, well, spec)
  end

  local state = spec.state()
  local bar, input, toggle = widget[f.bar], widget[f.input], f.toggle and widget[f.toggle]
  local gap = S("widgets.output.toolbar.gap")
  local x, y, rowHeight = 0, 0, 0

  local function place(item, itemWidth)
    if x > 0 and x + itemWidth > width then
      y = y + rowHeight + gap
      x, rowHeight = 0, 0
    end

    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -y)
    x = x + itemWidth + gap
    rowHeight = max(rowHeight, item:GetHeight())
  end

  bar:SetParent(well)
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", well, "TOPLEFT", inset, -inset)
  bar:SetWidth(width)
  bar:Show()

  for _, tab in ipairs(widget[f.tabs]) do
    local btn = tab.btn

    btn:SetLabel(format("%s %d", L[tab.key], model.counts[tab.id] or 0))
    btn:Fit(min(btn:Fit(), width))
    btn:SetSelected(tab.id == model.filter)
    place(btn, btn:GetWidth())
  end

  local searchWidth = min(S("widgets.output.toolbar.search"), width)

  input:SetWidth(searchWidth)
  place(input, searchWidth)

  if (input.edit:GetText() or "") ~= state.query then
    widget[f.sync] = true
    input:SetValue(state.query)
    widget[f.sync] = false
  end

  if toggle then
    toggle:SetValue(state.reverse)

    local toggleWidth = min(toggle:TextWidth(), width)

    toggle:SetWidth(toggleWidth)
    place(toggle, toggleWidth)
  end

  local total = y + rowHeight

  bar:SetHeight(total)

  return total
end

local function copy(widget)
  local model = widget.model

  if model and (model.kind == "text" or model.kind == "rows" or model.kind == "log" or model.kind == "ops") and EbonAPI.Handle then
    EbonAPI.Handle.CopyBox({ addonName = "EbonAPI" }, model.text or "", L.UI_RESULT)
  end
end

-- Looks : la présentation propre à un skin. Un skin déclare sa brique (bricks.output.nom = function(parent, B)
-- return Output.build(parent, look) end) et la choisit par widgets.output.brick. Le look par défaut est vide : tout
-- retombe sur le comportement ci-dessus. Un look peut définir (tout est optionnel) :
--   kinds  = { [genre] = function(widget, model, width) -> hauteur }  remplace Output.kinds[genre] pour ce widget
--            (genres text, rows, log, ops) ; un genre absent retombe sur Output.kinds[genre] ;
--   setup  = function(widget)  appelé une fois à la création, après celle des éléments (décoration) ;
--   frame  = function(widget, well, model)  appelé à chaque Refresh après la peinture du cadre, avant la mise en
--            page ; il peint sur well sans rien déplacer ni créer (ses éléments restent sur widget) ;
--   insets = function(widget, model) -> pixels  ajoutés au retrait intérieur du cadre (défaut 0).
-- Contrat d'un dessinateur de genre (comme Output.kinds[...]) : dessiner avec Output.tools (qui réutilisent le pool
-- widget.fiche), poser widget.sectionY[section.id] pour la fiche (clic des tuiles -> Output.scrollToSection) et
-- rendre la hauteur du contenu.
Output.looks = {}
Output.looks.default = {}

Output.tools = {
  take = take,
  words = words,
  marker = marker,
  chips = chips,
  hideFiche = hideFiche,
  lineRule = lineRule,
  copy = copy,
}

-- A frame keeps the level it had when it was created: once the box has moved (SetParent when the widget is taken
-- again from its pool, Raise of the window), the frames made before can be level with, or under, the well that
-- is forced to the level of the box, and the content is then drawn under its own background.
local function lift(frame, level)
  frame:SetFrameLevel(level)

  for _, child in ipairs({ frame:GetChildren() }) do
    lift(child, level + 1)
  end
end

function Output.build(parent, look)
  look = look or Output.looks.default

  local box = CreateFrame("Frame", nil, parent)
  local scroll = Bricks.create("scroll", box)
  local button = Bricks.create("button", box)
  local text = Bricks.text(scroll.child, S("widgets.output.font"), "text")

  scroll:SetMode("VERTICAL")
  text:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, 0)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("TOP")
  button:SetLabel(L.ALERT_COPY)
  button:Fit()
  button.onClick = function()
    copy(box)
  end

  box.count = Bricks.text(box, "small", "muted")
  box.count:SetJustifyH("LEFT")
  box.count:Hide()
  box.scroll, box.text, box.copyButton = scroll, text, button
  box.box = box
  box.look = look
  box.model = nil
  box.boxWidth = 1

  function box:Refresh()
    local padding = S("widgets.output.padding")
    local height = S("widgets.output.height")
    local width = self.boxWidth
    local footer = button:GetHeight()
    local groups = self.model and self.model.groups
    local well, tilesHeight = self, 0

    if groups and #groups > 0 then
      local syn = self.synthBrick or Bricks.create("synthesis", self)

      if not self.synthBrick then
        Output.hookSynthesis(self, syn)
      end

      self.synthBrick = syn
      well = self.well or CreateFrame("Frame", nil, self)
      self.well = well
      well:SetFrameLevel(self:GetFrameLevel())
      syn:Show()
      syn:ClearAllPoints()
      syn:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
      if self.model.kind == "log" or self.model.kind == "ops" then
        syn.activeId = self.model.filter
      end

      syn:SetGroups(groups, syn.activeId)
      syn:SetWidth(width)
      tilesHeight = syn:GetHeight() + S("widgets.synthesis.gap")
      self.synthesis = syn
      Bricks.unframe(self)
      well:Show()
      well:ClearAllPoints()
      well:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -tilesHeight)
      well:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
    else
      self.synthesis = nil

      if self.synthBrick then
        self.synthBrick:Hide()
      end

      if self.well then
        Bricks.unframe(self.well)
        self.well:Hide()
      end
    end

    local base = self:GetFrameLevel()

    if self.liftedFor ~= base then
      self.liftedFor = base
      lift(scroll, base + 1)
      lift(button, base + 1)

      if self.synthBrick then
        lift(self.synthBrick, base + 1)
      end
    end

    Bricks.frame(well, FRAMES[S("widgets.output.frame")] or "small", S("widgets.output.fill"),
      S("widgets.output.border"))

    if look.frame then
      look.frame(self, well, self.model)
    end

    Bricks.font(text, S("widgets.output.font"))
    Bricks.paint(text, "SetTextColor", "text")
    self:SetHeight(height + tilesHeight)

    local inset = Bricks.insetOf(well) + padding + (look.insets and look.insets(self, self.model) or 0)
    local viewWidth = max(1, width - inset * 2)
    local barHeight = layoutBar(self, well, inset, viewWidth, self.model, BARS.log)
      + layoutBar(self, well, inset, viewWidth, self.model, BARS.ops)
    local barSpace = barHeight > 0 and barHeight + GAP or 0
    local viewHeight = max(1, height - inset * 2 - footer - GAP - barSpace)

    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", well, "TOPLEFT", inset, -inset - barSpace)
    scroll:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -inset, inset + footer + GAP)
    scroll:SetView(viewWidth, viewHeight)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -inset, inset)
    self.count:ClearAllPoints()
    self.count:SetPoint("BOTTOMLEFT", well, "BOTTOMLEFT", inset, inset)

    local model = self.model
    local draw = model and ((look.kinds and look.kinds[model.kind]) or Output.kinds[model.kind])
    local content = 0
    local keep = (self.lastKind == "log" or self.lastKind == "ops") and model and model.kind == self.lastKind
      and scroll:Offset() or 0

    if not (model and model.kind == "rows") then
      hideFiche(self)
      self.sectionY = nil
    end

    if not (model and model.kind == "log") then
      hideJournal(self)
    end

    if not (model and model.kind == "ops") then
      hideOps(self)
    end

    if draw then
      content = draw(self, model, max(1, viewWidth - S("widgets.scroll.width") - GAP))
    else
      text:SetText("")
    end

    scroll.child:SetWidth(viewWidth)
    scroll:SetContentHeight(content)
    scroll:SetOffset(keep)
    self.lastKind = model and model.kind
    self.contentHeight = content

    return height + tilesHeight
  end

  function box:ScrollToSection(id)
    return Output.scrollToSection(self, id)
  end

  function box:SetModel(model)
    self.model = model
    self:Refresh()
  end

  local setWidth = box.SetWidth

  function box:SetWidth(width)
    self.boxWidth = width
    setWidth(self, width)

    if self.model then
      self:Refresh()
    end
  end

  if look.setup then
    look.setup(box)
  end

  return box
end

Bricks.register("output", "default", function(parent)
  return Output.build(parent, Output.looks.default)
end)

return Output
