local Lib = EbonAPI.Lib
EbonAPI:RegisterSkin("VSCode", {
  parent = "AutoCallboard",

  background = 0x1F1F1F,
  accent = 0x0078D4,
  opacity = 1,
  shadow = 0.35,
  corners = 6,
  tabs = "RIGHT",

  palette = {
    bg = 0x181818,
    bgSoft = 0x313131,
    card = 0x181818,
    border = 0x2B2B2B,
    borderDim = 0x3C3C3C,
    button = 0x313131,
    buttonBorder = 0x3C3C3C,
    buttonHover = 0x0078D4,
    buttonHoverFill = 0x3C3C3C,
    buttonDisabledBorder = { 0x3C3C3C, 0.5 },
    buttonText = 0xCCCCCC,
    buttonDisabledText = { 0xCCCCCC, 0.5 },
    checkbox = 0x313131,
    checkboxBorder = 0x3C3C3C,
    checked = 0xCCCCCC,
    thumb = { 0x797979, 0.4 },
    selected = 0x04395E,
    selectedText = 0xFFFFFF,
    text = 0xCCCCCC,
    muted = 0x9D9D9D,
    title = 0xFFFFFF,
    heading = 0xE7E7E7,
    menu = 0x0078D4,
    focus = 0x0078D4,
    rowHover = 0x2A2D2E,
    headerBg = { 0x181818, 0 },
    navBg = 0x1F1F1F,
    pageBg = 0x1F1F1F,
    footerBg = { 0x181818, 0 },
  },

  fonts = {
    small = { file = "Fonts\\ARIALN.TTF", size = 11 },
    normal = { file = "Fonts\\ARIALN.TTF" },
    large = { file = "Fonts\\ARIALN.TTF", size = 18 },
    button = { file = "Fonts\\ARIALN.TTF", size = 12, outline = "NONE" },
    shadow = { alpha = 0 },
  },

  border = {
    round = { small = 6 },
  },

  window = {
    padding = 5,
    spacing = 5,
    shadow = { base = 6, spread = 16, alphaBase = 0.2, alphaSpread = 0.4, y = -2 },
  },

  header = {
    height = 30,
    inset = -5,
    spacing = 0,
    title = { x = 8, y = 9, font = "normal", color = "text" },
    version = { gap = 6, y = 0 },
    search = { position = "CENTER", width = 300, height = 20, insetY = 1 },
    close = { brick = "flat", size = 30, width = 40, y = 0, glyph = "×" },
    minimize = { show = true, width = 40, glyph = "—" },
    sidebar = { show = true, size = 14, width = 24 },
    history = { show = true, back = "←", forward = "→", width = 24 },
    rule = { show = false },
  },

  footer = {
    show = true,
    rule = false,
    badge = { show = true },
    items = true,
    gap = 12,
  },

  nav = {
    width = 220,
    inset = 0,
    padding = 6,
    frame = "LARGE",
    rail = { show = true, gap = 5, spacing = 6, dim = 0.55 },
    tree = { collapsible = true, guides = true },
    section = { x = 8, height = 26, color = "text", font = "normal" },
    tab = { brick = "list", height = 22, gap = 0, align = "LEFT", font = "normal", padding = 20 },
  },

  page = {
    width = 640,
    height = 540,
    gutter = 12,
    top = 40,
    frame = "LARGE",
    close = { size = 30, width = 40, glyph = "×" },
    inset = { x = 22, y = 10 },
    title = { y = 0, color = "title" },
    description = { gap = 4, below = 2 },
    unit = 240,
    gap = { x = 12, y = 16 },
    layout = "LIST",
    descriptions = "INLINE",
    strip = { show = true, height = 30, tabs = 6, color = "card", idle = "card", separator = "border" },
    crumbs = { show = true, height = 22, separator = "›" },
  },

  widgets = {
    button = { padding = 10 },
    toggle = {
      height = 20, size = 14, gap = 8, mark = -3,
      markTexture = "Interface\\Buttons\\UI-CheckBox-Check",
    },
    range = {
      height = 46, top = 16, bar = 12, track = 2, fill = true, fillColor = "focus",
      thumb = { width = 6, height = 12 },
      edit = { width = 50, height = 18 },
    },
    select = { height = 40 },
    menu = { brick = "list", gap = 0, padding = 2, inset = 10, title = { align = "LEFT" } },
    heading = { lines = "NONE", color = "title", height = 26 },
    group = { brick = "plain", padding = 0, title = 22, titleX = 0, color = "title", frame = "FLAT" },
    scroll = { width = 8, thumb = 30, trackAlpha = 0 },
    synthesis = { brick = "barItems" },
    -- Saves: flat list, search always open; the transparent palette key stands for "no fill, no border".
    saves = {
      view = "list", detail = "dock", search = true,
      row = { frame = "FLAT", fill = "headerBg", border = "headerBg" },
    },
    output = { brick = "tree" },
  },

  bricks = {
    -- The summary tiles as status-bar items: one line each (level marker, label, value), laid out one after the
    -- other in a flat row with a 1 px vertical separator on the right of every item except the last of its row.
    -- The row wraps when the next item does not fit; an item is never wider than the box. The sub-text is only
    -- in the tooltip. The selected item is a plain fill of the selection key.
    synthesis = {
      barItems = function(parent, B)
        local Tiles = EbonAPI.Tiles
        local MARGIN, SPACE = 4, 4
        local look = {}

        local labelRole, valueRole, selected = EbonAPI.Skins.synthesisRoles(B)

        -- The marker sits on the line of the text, centred in the height of the item.
        local function placeMarker(tile)
          local marker = tile.marker

          Tiles.paintMarker(tile, tile.markerSide or 1)

          if marker:IsShown() then
            local inset = B.insetOf(tile.frame)
            local inner = tile.frame:GetHeight() - 2 * inset
            local side = tile.markerSide or 1

            marker:ClearAllPoints()
            marker:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", inset + MARGIN + math.floor((side - marker:GetWidth()) / 2),
              -(inset + math.floor((inner - marker:GetHeight()) / 2)))
          end
        end

        local function paintFrame(box, tile)
          local key = Tiles.borderKey(box, tile)
          local fill = selected(box, tile) and B.value("widgets.synthesis.selected") or B.value("widgets.synthesis.fill")

          if key ~= tile.border or fill ~= tile.fillKey then
            B.frame(tile.frame, "flat", fill, key)
            tile.border = key
            tile.fillKey = fill
          end
        end

        local function paintLook(box, tile)
          paintFrame(box, tile)
          B.paint(tile.label, "SetTextColor", "text")
          B.paint(tile.value, "SetTextColor", selected(box, tile) and "text" or "muted")
          B.paint(tile.sep, "SetVertexColor", "borderDim")
          placeMarker(tile)
          Tiles.setTip(tile)
        end

        function look.new(box)
          local frame = CreateFrame("Button", nil, box)
          local tile = { frame = frame, lookName = "barItems", margin = MARGIN }

          Tiles.wire(box, tile)
          tile.marker = frame:CreateTexture(nil, "OVERLAY")
          tile.sep = frame:CreateTexture(nil, "OVERLAY")
          tile.sep:SetTexture(B.media("solid"))
          tile.label = B.text(frame, labelRole(), "text")
          tile.label:SetJustifyH("LEFT")
          tile.label:SetJustifyV("MIDDLE")
          EbonAPI.Tiles.wrap(tile.label, false)
          tile.value = B.text(frame, valueRole(), "muted")
          tile.value:SetJustifyH("LEFT")
          tile.value:SetJustifyV("MIDDLE")
          EbonAPI.Tiles.wrap(tile.value, false)
          -- the sub-text is never drawn: it carries the full text of the item for the readers of the tile
          tile.sub = B.text(frame, labelRole(), "muted")
          tile.sub:Hide()

          return tile
        end

        -- One line of text and a margin above and below.
        function look.height(box)
          return math.max(math.ceil(B.value("fonts." .. labelRole() .. ".size")),
            math.ceil(B.value("fonts." .. valueRole() .. ".size"))) + 2 * MARGIN
        end

        -- Paints and sizes one item: width is the room of the box, the item takes its measured width.
        function look.paint(box, tile, width, height)
          local frame = tile.frame
          local item = tile.item
          local lr, vr = labelRole(), valueRole()

          tile.border = nil
          paintFrame(box, tile)
          B.font(tile.label, lr)
          B.font(tile.value, vr)
          B.font(tile.sub, lr)
          tile.label:SetText(item.label or "")
          tile.value:SetText(item.value or "")
          tile.sub:SetText(item.sub or "")
          EbonAPI.Tiles.wrap(tile.label, false)
          EbonAPI.Tiles.wrap(tile.value, false)
          tile.label:SetWidth(4096)
          tile.value:SetWidth(4096)

          local inset = B.insetOf(frame)
          local inner = math.max(1, height - 2 * inset)
          local side = math.ceil(B.value("fonts." .. lr .. ".size"))
          local lw = math.ceil(tile.label:GetStringWidth() or 0)
          local vw = (item.value ~= nil and item.value ~= "") and math.ceil(tile.value:GetStringWidth() or 0) or 0
          local ll = math.min(Tiles.lineHeight(tile.label, lr), inner)
          local vl = math.min(Tiles.lineHeight(tile.value, vr), inner)

          frame:SetHeight(height)
          tile.markerSide = side
          paintLook(box, tile)

          local left = inset + MARGIN + (tile.marker:IsShown() and side + SPACE or 0)
          local want = left + lw + (vw > 0 and SPACE + vw or 0) + MARGIN + inset
          local total = math.min(width, want)
          local room = total - left - MARGIN - inset
          local labelWidth = math.max(1, math.min(lw, room))
          local rest = room - labelWidth - SPACE

          frame:SetWidth(total)
          tile.label:ClearAllPoints()
          tile.label:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -(inset + math.floor((inner - ll) / 2)))
          tile.label:SetWidth(labelWidth)
          tile.label:SetHeight(ll)
          tile.value:ClearAllPoints()
          tile.value:SetPoint("TOPLEFT", frame, "TOPLEFT", left + labelWidth + SPACE, -(inset + math.floor((inner - vl) / 2)))
          tile.value:SetWidth(math.max(1, math.min(vw, rest)))
          tile.value:SetHeight(vl)

          Lib.setShown(tile.value, vw > 0 and rest >= 4)

          tile.sep:ClearAllPoints()
          tile.sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
          tile.sep:SetWidth(1)
          tile.sep:SetHeight(inner)
        end

        -- A text or a marker slot that changes the width of the item lays the flow out again (nothing is created).
        function look.update(box, tile, old)
          local item = tile.item

          if item.label ~= old.label or item.value ~= old.value or (item.level == nil) ~= (old.level == nil) then
            box:Refresh()

            return
          end

          tile.sub:SetText(item.sub or "")
          paintLook(box, tile)
        end

        -- The flow: items one after the other without a gap, the row wraps when the next one does not fit.
        function look.layout(box)
          local width = math.max(1, box.boxWidth)
          local gap = B.value("widgets.synthesis.gap")
          local th = box.look.height(box)
          local role = labelRole()
          local y = 0

          for index, group in ipairs(box.groups or {}) do
            local label = box.labelPool[index]

            B.font(label, role)
            B.paint(label, "SetTextColor", B.value("widgets.synthesis.group.color"))
            label:SetText(group.label or "")
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
            label:SetWidth(width)

            local lh = Tiles.lineHeight(label, role)

            label:SetHeight(lh)
            label:Show()
            y = y + lh + gap

            local x, row, previous = 0, 0, nil

            for _, tile in ipairs(group.tiles) do
              box.look.paint(box, tile, width, th)

              local w = tile.frame:GetWidth()

              if x > 0 and x + w > width + 0.01 then
                x = 0
                row = row + 1

                if previous then
                  previous.sep:Hide()
                end
              end

              tile.frame:ClearAllPoints()
              tile.frame:SetPoint("TOPLEFT", box, "TOPLEFT", x, -(y + row * th))
              tile.frame:Show()
              tile.sep:Show()
              x = x + w
              previous = tile
            end

            if previous then
              previous.sep:Hide()
            end

            local rows = #group.tiles > 0 and row + 1 or 0

            y = y + rows * th

            if index < #box.groups then
              y = y + gap
            end
          end

          box:SetHeight(math.max(1, y))
          box.contentHeight = y

          return y
        end

        return Tiles.build(parent, look)
      end,
    },

    -- The status sheet as the explorer tree of a code editor: a chevron and the name on each section title (a
    -- click on the line folds or unfolds the section; the state lives on the widget, not in the saved variables),
    -- a count pill at the right end when the section has warning or error lines, the rows indented by 16 px with
    -- the level marker at the right end of the line. No rule under the titles, no band: only the explorer's
    -- vertical rhythm. The click targets are transparent frames; nothing is drawn on a frame.
    output = {
      tree = function(parent, B)
        local Output = EbonAPI.Output
        local T = Output.tools
        local INDENT = 16
        local look = { kinds = {} }

        -- The click targets and the pills have their own small pool (widget.tree), apart from the one of the sheet
        -- (widget.fiche.fr), which only holds the chips of the rows: nothing of the pool can answer to the mouse by
        -- mistake and the readers of the sheet find the same chips as with the default look.
        local function grab(widget, kind)
          local t = widget.tree
          local n = t.used[kind] + 1
          local fr = t[kind][n]

          t.used[kind] = n

          if not fr then
            fr = CreateFrame("Frame", nil, widget.scroll.child)
            fr.text = B.text(fr, "small", "text")
            t[kind][n] = fr
          end

          fr:Show()

          return fr
        end

        local function release(widget)
          widget.tree = widget.tree or { hits = {}, pills = {}, used = { hits = 0, pills = 0 } }

          for _, kind in ipairs({ "hits", "pills" }) do
            for _, fr in ipairs(widget.tree[kind]) do
              fr:Hide()
            end
          end

          widget.tree.used = { hits = 0, pills = 0 }
        end

        -- Another kind of report is drawn: nothing of the tree stays on the screen.
        function look.frame(widget, _, model)
          if not (model and model.kind == "rows") then
            release(widget)
          end
        end

        -- A marker of the pool may have been a chevron: its crop and opacity are put back.
        local function mark(widget, level, x, y, side)
          T.marker(widget, level, x, y, side)

          local f = widget.fiche
          local tex = f.tex[f.used.tex]

          if tex and tex.level == level then
            tex:SetTexCoord(0, 1, 0, 1)
            tex:SetAlpha(1)
            tex:SetDrawLayer("ARTWORK")
          end
        end

        local function chevron(widget, open, x, y, side)
          local tex = T.take(widget, "tex")

          tex:SetTexture(B.media("arrow"))
          B.turn(tex, open and "DOWN" or "RIGHT")
          B.paint(tex, "SetVertexColor", "muted")
          tex:SetAlpha(1)
          tex:SetDrawLayer("ARTWORK")
          tex:SetWidth(side)
          tex:SetHeight(side)
          tex:ClearAllPoints()
          tex:SetPoint("TOPLEFT", widget.scroll.child, "TOPLEFT", x, -y)
          tex.level = "chevron"
        end

        -- The count of the warning and error lines, framed in the colour of the worst level.
        local function pill(widget, count, bad)
          local fr = grab(widget, "pills")
          local text = fr.text
          local padding = B.value("kit.tag.padding")

          B.frame(fr, "small", "well", bad and "danger" or "caution")
          B.font(text, B.value("kit.tag.font"))
          B.paint(text, "SetTextColor", B.value("kit.tag.text"))
          text:SetWidth(0)
          text:SetText(tostring(count))
          text:ClearAllPoints()
          text:SetPoint("CENTER", fr, "CENTER", 0, 0)
          fr:SetWidth(math.ceil(text:GetStringWidth() or 0) + padding * 2)
          fr:SetHeight(math.ceil(text:GetStringHeight() or 0) + padding)

          return fr
        end

        look.kinds.rows = function(widget, model, width)
          widget.fiche = widget.fiche or { fs = {}, tex = {}, fr = {}, used = { fs = 0, tex = 0, fr = 0 } }
          widget.sectionY = {}
          widget.collapsed = widget.collapsed or {}
          widget.text:SetText("")
          T.hideFiche(widget)
          release(widget)

          local child = widget.scroll.child
          local gap = B.value("widgets.output.row.gap")
          local size = B.value("widgets.output.marker.size")
          local labelW = math.min(B.value("widgets.output.label.width"),
            math.max(20, math.floor((width - INDENT - size - gap * 3) / 2)))
          local valueX = INDENT + labelW + gap
          local valueW = math.max(1, width - valueX - size - gap)
          local y = 0

          for index, section in ipairs(model.sections or {}) do
            if index > 1 then
              y = y + gap * 2
            end

            widget.sectionY[section.id] = y

            local open = not widget.collapsed[section.id]
            local count, bad = 0, false

            for _, row in ipairs(section.rows or {}) do
              if row.level == "warn" or row.level == "bad" then
                count = count + 1
              end

              if row.level == "bad" then
                bad = true
              end
            end

            -- The click target: transparent, the whole line of the title; its script is set again at every drawing.
            local hit = grab(widget, "hits")

            hit:EnableMouse(true)
            hit:SetScript("OnMouseUp", function(_, button)
              if button == nil or button == "LeftButton" then
                widget.collapsed[section.id] = not widget.collapsed[section.id]
                widget:Refresh()
              end
            end)

            local badge = count > 0 and pill(widget, count, bad) or nil
            local badgeW = badge and badge:GetWidth() + gap or 0
            local badgeH = badge and badge:GetHeight() or 0
            local title, th = T.words(widget, size + gap, y, math.max(1, width - size - gap - badgeW),
              B.value("widgets.output.section.font"), B.value("widgets.output.section.color"), section.name)
            local rowH = math.max(size, th, badgeH)

            title:SetPoint("TOPLEFT", child, "TOPLEFT", size + gap, -(y + math.floor((rowH - th) / 2)))
            chevron(widget, open, 0, y + math.floor((rowH - size) / 2), size)
            hit:SetWidth(width)
            hit:SetHeight(rowH)
            hit:ClearAllPoints()
            hit:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)

            if badge then
              badge:ClearAllPoints()
              badge:SetPoint("TOPLEFT", child, "TOPLEFT", width - badge:GetWidth(), -(y + math.floor((rowH - badgeH) / 2)))
            end

            y = y + rowH

            if open then
              y = y + gap

              for _, row in ipairs(section.rows or {}) do
                mark(widget, row.level, width - size, y, size)

                local _, lh = T.words(widget, INDENT, y, labelW, "normal", B.value("widgets.output.label.color"), row.label)
                local rh

                if row.chips then
                  rh = T.chips(widget, row.chips, valueX, y, valueW)
                else
                  local tagW = 0

                  if row.tag then
                    local tag = T.take(widget, "fs")

                    B.font(tag, B.value("kit.tag.font"))
                    B.paint(tag, "SetTextColor", "caution")
                    tag:SetWidth(0)
                    tag:SetText(tostring(row.tag))
                    tagW = math.min(math.ceil(tag:GetStringWidth() or 0), math.floor(valueW / 3))
                    tag:SetWidth(tagW)
                    tag:ClearAllPoints()
                    tag:SetPoint("TOPLEFT", child, "TOPLEFT", width - size - gap - tagW, -y)
                    tagW = tagW + gap
                  end

                  local _, vh = T.words(widget, valueX, y, math.max(1, valueW - tagW), "normal",
                    B.value("widgets.output.value.color"), row.value)

                  rh = vh
                end

                y = y + math.max(size, lh, rh or 0) + gap
              end
            end
          end

          return y
        end

        return Output.build(parent, look)
      end,
    },
  },

  chat = {
    prefix = 0x0078D4,
    text = 0xCCCCCC,
    muted = 0x9D9D9D,
  },

  board = {
    header = { height = 22, color = "text", line = "border" },
    row = { height = 40, gap = 2 },
  },
})
