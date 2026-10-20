local DOTS = {
  { color = "header.close.hover", glyph = "header.close.glyph", ink = "header.close.ink" },
  { color = "header.minimize.color", glyph = "header.minimize.glyph", ink = "header.minimize.ink" },
  { color = "header.zoom.color", glyph = "header.zoom.glyph", ink = "header.zoom.ink" },
}

local function dot(button, B, spec)
  local Palette = EbonAPI.Palette
  local disk = button:CreateTexture(nil, "ARTWORK")

  disk:SetTexture(B.media("circle"))
  disk:SetPoint("LEFT", button, "LEFT", 0, 0)
  disk:SetVertexColor(Palette.unpackColor(B.value(spec.color)))
  button.disk = disk
  B.font(button.label, "button", "")
  button.label:ClearAllPoints()
  button.label:SetPoint("CENTER", disk, "CENTER", 0, 0)
  button.label:SetTextColor(Palette.unpackColor(B.value(spec.ink)))
  button.label:SetText(B.value(spec.glyph))
end

local function lights(parent, B)
  local close = B.baseButton(parent, function(self)
    local over = self.hovered or self.others[1].hovered or self.others[2].hovered

    self.label:SetAlpha(over and 1 or 0)

    for _, other in ipairs(self.others) do
      other.label:SetAlpha(over and 1 or 0)
    end
  end)

  close.others = {}
  dot(close, B, DOTS[1])

  for index = 2, 3 do
    local other = CreateFrame("Button", nil, close)

    other.label = other:CreateFontString(nil, "OVERLAY")
    dot(other, B, DOTS[index])
    other:SetScript("OnEnter", function(self)
      self.hovered = true
      close:Visual()
    end)
    other:SetScript("OnLeave", function(self)
      self.hovered = false
      close:Visual()
    end)
    close.others[index - 1] = other
  end

  close.others[1]:SetScript("OnClick", function()
    if close.onShade then
      close.onShade(close)
    end
  end)

  local setWidth, setHeight = close.SetWidth, close.SetHeight

  local function layout(self)
    local size = self:GetHeight()
    local gap = math.max(0, (self:GetWidth() - size * 3) / 2)

    self.disk:SetWidth(size)
    self.disk:SetHeight(size)

    for index, other in ipairs(self.others) do
      other:SetWidth(size)
      other:SetHeight(size)
      other.disk:SetWidth(size)
      other.disk:SetHeight(size)
      other:ClearAllPoints()
      other:SetPoint("LEFT", self, "LEFT", index * (size + gap), 0)
    end

    self:SetHitRectInsets(0, math.max(0, self:GetWidth() - size), 0, 0)
  end

  function close:SetWidth(width)
    setWidth(self, width)
    layout(self)
  end

  function close:SetHeight(size)
    setHeight(self, size)
    layout(self)
  end

  function close:TextWidth()
    return self:GetWidth()
  end

  close:Visual()

  return close
end

EbonAPI:RegisterSkin("Porcelain", {
  parent = "AutoCallboard",

  background = 0xF6F6F6,
  accent = 0x007AFF,
  opacity = 0.94,
  shadow = 0.6,
  corners = 8,

  palette = {
    bg = 0xF6F6F6,
    bgSoft = 0xFFFFFF,
    card = 0xFFFFFF,
    border = 0xC4C4C4,
    borderDim = 0xDADADA,
    button = 0xFFFFFF,
    buttonBorder = 0xC6C6C6,
    buttonHover = 0x007AFF,
    buttonHoverFill = 0xF2F2F2,
    buttonDisabledBorder = { 0xC6C6C6, 0.5 },
    buttonText = 0x1D1D1F,
    buttonDisabledText = { 0x1D1D1F, 0.4 },
    checkbox = 0xFFFFFF,
    checkboxBorder = 0xB8B8BD,
    checked = 0x007AFF,
    thumb = 0x8E8E93,
    selected = 0x007AFF,
    selectedText = 0xFFFFFF,
    text = 0x1D1D1F,
    muted = 0x6E6E73,
    title = 0x1D1D1F,
    heading = 0x1D1D1F,
    menu = 0x007AFF,
    focus = 0x007AFF,
    rowHover = { 0x000000, 0.06 },
    headerBg = { 0xEBEBEB, 0.92 },
    navBg = { 0xE3E3E8, 0.85 },
    pageBg = { 0xF2F2F7, 0.9 },
    footerBg = { 0xEBEBEB, 0 },
    success = 0x137333,
    danger = 0xC5221F,
    caution = 0x9A5B00,
  },

  fonts = {
    small = { file = "Fonts\\ARIALN.TTF", size = 11 },
    normal = { file = "Fonts\\ARIALN.TTF" },
    large = { file = "Fonts\\ARIALN.TTF", size = 17 },
    button = { file = "Fonts\\ARIALN.TTF", size = 12, outline = "NONE" },
    shadow = { alpha = 0 },
  },

  window = {
    padding = 0,
    spacing = 0,
    shadow = { base = 10, spread = 20, alphaBase = 0.12, alphaSpread = 0.3, y = -8 },
    glass = {
      enabled = true, darken = 0, milk = 0.18, grain = 0.02,
      sheen = 0.12, sheenHeight = 0.25, edge = 0.35,
    },
    fade = 0.12,
  },

  header = {
    height = 38,
    controls = "LEFT",
    inset = 14,
    title = { align = "CENTER", y = 13, font = "normal", color = "title" },
    version = { show = false },
    search = { position = "OPPOSITE", width = 170 },
    close = { brick = "lights", size = 12, width = 52, y = 13, glyph = "×", hover = 0xFF5F57 },
  },

  nav = {
    width = 190,
    inset = 4,
    padding = 10,
    divider = { size = 1 },
    section = { x = 6, before = 10 },
    tab = { brick = "list", gap = 2, align = "LEFT", font = "normal", padding = 10 },
  },

  page = {
    width = 620,
    height = 520,
    gutter = 10,
    top = 44,
    inset = { x = 24, y = 18 },
    close = { size = 12, width = 52, glyph = "×" },
    title = { color = "title" },
    gap = { x = 16, y = 14 },
  },

  widgets = {
    toggle = {
      brick = "switch", gap = 8, mark = 2, roundKnob = true,
      switch = { width = 30, height = 16 },
    },
    range = { fill = true, roundThumb = true, track = 3, thumb = { width = 14 } },
    menu = { brick = "list", padding = 4, inset = 12, title = { align = "LEFT" } },
    heading = { lines = "NONE", color = "muted", upper = true, height = 20 },
    group = { padding = 12, title = 20, titleX = 4, color = "title" },
    scroll = { thumb = 30, trackAlpha = 0 },
    synthesis = { brick = "widgets", tile = { width = 130 }, value = { font = "large" } },
    -- Saves: each group is a small card with an upper-case title, thin flat rows inside.
    saves = {
      view = "list", detail = "inline",
      group = { frame = "SMALL", fill = "card", upper = true }, row = { frame = "FLAT" },
    },
    output = { brick = "grouped" },
  },

  kit = {
    header = 24,
    control = 18,
    icon = { border = "checkboxBorder" },
    rows = { action = 16, fill = "checked", fillAlpha = 0.22, mark = "danger", markAlpha = 0.14, suffix = "muted" },
  },

  chat = {
    prefix = 0x007AFF,
  },

  bricks = {
    close = { lights = lights },

    -- The summary tiles as control-centre widget cards: a round icon badge (tinted by the level, with the
    -- level marker on it) at the top left, the value in the large font under it, then the label and the
    -- sub-text (two lines) in the muted colour. The grid is the common one.
    synthesis = {
      widgets = function(parent, B)
        local Tiles = EbonAPI.Tiles
        local MARGIN, SPACE = 8, 3
        local TINT = { ok = "success", warn = "caution", bad = "danger", info = "muted", net = "focus" }
        local look = {}

        local labelRole, valueRole = EbonAPI.Skins.synthesisRoles(B)
        local function dotSize()
          return math.ceil(B.value("fonts." .. labelRole() .. ".size")) + 7
        end

        -- The badge is tinted by the level key; the marker is centred on it.
        local function paintBadge(tile)
          local size = tile.dot or dotSize()
          local key = TINT[tile.item.level] or "muted"

          tile.diskKey = key
          B.paint(tile.disk, "SetVertexColor", key)
          Tiles.paintMarker(tile, size)

          if tile.marker:IsShown() then
            local side = tile.marker:GetWidth()
            local pad = math.floor((size - side) / 2)

            tile.marker:ClearAllPoints()
            tile.marker:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", MARGIN + pad, -(MARGIN + pad))
          end
        end

        local function paintBorder(box, tile)
          local key = Tiles.borderKey(box, tile)

          if key ~= tile.border then
            B.frame(tile.frame, "large", B.value("widgets.synthesis.fill"), key)
            tile.border = key
          end
        end

        local function paintTexts(tile)
          local item = tile.item

          tile.label:SetText(item.label or "")
          tile.value:SetText(item.value or "")
          tile.sub:SetText(item.sub or "")
          Tiles.setTip(tile)
        end

        function look.new(box)
          local frame = CreateFrame("Button", nil, box)
          local tile = { frame = frame, lookName = "widgets", margin = MARGIN, space = SPACE }

          Tiles.wire(box, tile)
          tile.disk = frame:CreateTexture(nil, "ARTWORK")
          tile.disk:SetTexture(B.media("circle"))
          tile.disk:SetAlpha(0.2)
          tile.marker = frame:CreateTexture(nil, "OVERLAY")
          tile.label = B.text(frame, labelRole(), "muted")
          tile.value = B.text(frame, valueRole(), "text")
          tile.sub = B.text(frame, labelRole(), "muted")

          for _, fs in ipairs({ tile.label, tile.value, tile.sub }) do
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("TOP")
            EbonAPI.Tiles.wrap(fs, false)
          end

          EbonAPI.Tiles.wrap(tile.sub, true)

          return tile
        end

        -- Margins, badge, value line, label line, two sub-text lines, three gaps (from the font sizes).
        function look.height(box)
          local small = math.ceil(B.value("fonts." .. labelRole() .. ".size"))

          return 2 * MARGIN + dotSize() + math.ceil(B.value("fonts." .. valueRole() .. ".size")) + 3 * small + 3 * SPACE
        end

        function look.paint(box, tile, width, height)
          local frame = tile.frame
          local lr, vr = labelRole(), valueRole()
          local inner = math.max(1, width - 2 * MARGIN)
          local small = math.ceil(B.value("fonts." .. lr .. ".size"))
          local big = math.ceil(B.value("fonts." .. vr .. ".size"))
          local dot = dotSize()

          tile.border = nil
          paintBorder(box, tile)
          frame:SetWidth(width)
          frame:SetHeight(height)

          B.font(tile.label, lr)
          B.font(tile.value, vr)
          B.font(tile.sub, lr)
          B.paint(tile.label, "SetTextColor", "muted")
          B.paint(tile.value, "SetTextColor", "text")
          B.paint(tile.sub, "SetTextColor", "muted")
          paintTexts(tile)

          tile.dot = dot
          tile.disk:ClearAllPoints()
          tile.disk:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -MARGIN)
          tile.disk:SetWidth(dot)
          tile.disk:SetHeight(dot)
          tile.disk:Show()
          paintBadge(tile)

          local top = MARGIN + dot + SPACE

          tile.value:ClearAllPoints()
          tile.value:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -top)
          tile.value:SetWidth(inner)
          tile.value:SetHeight(big)
          top = top + big + SPACE
          tile.label:ClearAllPoints()
          tile.label:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -top)
          tile.label:SetWidth(inner)
          tile.label:SetHeight(small)
          top = top + small + SPACE
          tile.sub:ClearAllPoints()
          tile.sub:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -top)
          tile.sub:SetWidth(inner)
          tile.sub:SetHeight(2 * small)
        end

        function look.update(box, tile, old)
          local item = tile.item

          if item.label ~= old.label or item.value ~= old.value or item.sub ~= old.sub then
            paintTexts(tile)
          end

          if item.level ~= old.level then
            paintBadge(tile)
          end

          paintBorder(box, tile)
        end

        return Tiles.build(parent, look)
      end,
    },

    -- The status sheet as grouped lists, like phone settings: the title in small muted capitals, then the rows of
    -- the section as one group between hairlines (textures, drawn under the texts), the label on the left and the
    -- value right-aligned before the level marker. The chips of a row stay on the left of the values column.
    output = {
      grouped = function(parent, B)
        local Output = EbonAPI.Output
        local T = Output.tools
        local INSET, MARGIN, MIN_ROW, PAD = 10, 4, 26, 8
        local look = { kinds = {} }

        -- One hairline texture (a full-width pixel, borderDim), under the texts of the group.
        local function hairline(widget, y, width)
          local line = T.take(widget, "tex")

          line:SetTexture(B.media("solid"))
          line:SetDrawLayer("BACKGROUND")
          line:SetTexCoord(0, 1, 0, 1)
          line:SetAlpha(1)
          B.paint(line, "SetVertexColor", "borderDim")
          line:SetWidth(width)
          line:SetHeight(1)
          line:ClearAllPoints()
          line:SetPoint("TOPLEFT", widget.scroll.child, "TOPLEFT", 0, -y)
          line.level = "rule"
        end

        local function place(fs, x, y)
          fs:ClearAllPoints()
          fs:SetPoint("TOPLEFT", fs:GetParent(), "TOPLEFT", x, -y)
        end

        look.kinds.rows = function(widget, model, width)
          widget.fiche = widget.fiche or { fs = {}, tex = {}, fr = {}, used = { fs = 0, tex = 0, fr = 0 } }
          widget.sectionY = {}
          widget.text:SetText("")
          T.hideFiche(widget)

          local child = widget.scroll.child
          local gap = B.value("widgets.output.row.gap")
          local size = B.value("widgets.output.marker.size")
          local reserved = size + gap
          local edge = width - INSET - reserved
          local labelW = math.min(B.value("widgets.output.label.width"),
            math.max(20, math.floor((width - INSET * 2 - reserved - gap * 2) / 2)))
          local valueX = INSET + labelW + gap
          local valueW = math.max(1, edge - valueX)
          local y = 0

          for index, section in ipairs(model.sections or {}) do
            if index > 1 then
              y = y + gap * 3
            end

            widget.sectionY[section.id] = y

            local _, th = T.words(widget, INSET, y, math.max(1, width - INSET * 2), B.value("widgets.output.section.font"),
              "muted", EbonAPI.Lib.upper(section.name or ""))

            y = y + th + MARGIN
            hairline(widget, y, width)
            y = y + 1

            for _, row in ipairs(section.rows or {}) do
              local label, lh = T.words(widget, INSET, y, labelW, "normal", B.value("widgets.output.label.color"), row.label)
              local tag, tagW, tagH = nil, 0, 0
              local value, vh, ch = nil, 0, 0
              local firstChip = widget.fiche.used.fr + 1

              if row.chips then
                ch = T.chips(widget, row.chips, valueX, y, valueW)
              else
                if row.tag then
                  tag = T.take(widget, "fs")
                  B.font(tag, B.value("kit.tag.font"))
                  B.paint(tag, "SetTextColor", "caution")
                  tag:SetWidth(4096)
                  EbonAPI.Tiles.wrap(tag, false)
                  tag:SetText(tostring(row.tag))
                  tagW = math.min(math.ceil(tag:GetStringWidth() or 0), math.floor(valueW / 3))
                  EbonAPI.Tiles.wrap(tag, true)
                  tag:SetWidth(tagW)
                  tag:SetJustifyH("RIGHT")
                  tagH = math.ceil(tag:GetStringHeight() or 0)
                  tagW = tagW + gap
                end

                value, vh = T.words(widget, valueX, y, math.max(1, valueW - tagW), "normal",
                  B.value("widgets.output.value.color"), row.value)
                value:SetJustifyH("RIGHT")
              end

              local rowH = math.max(MIN_ROW, math.max(size, lh, vh, tagH, ch) + PAD)

              -- Content centred in the row.
              place(label, INSET, y + math.floor((rowH - lh) / 2))

              if value then
                place(value, valueX, y + math.floor((rowH - vh) / 2))
              end

              if tag then
                place(tag, edge - (tagW - gap), y + math.floor((rowH - tagH) / 2))
              end

              for n = firstChip, widget.fiche.used.fr do
                local fr = widget.fiche.fr[n]
                local _, _, _, fx, fy = fr:GetPoint()

                fr:ClearAllPoints()
                fr:SetPoint("TOPLEFT", child, "TOPLEFT", fx, fy - math.floor((rowH - ch) / 2))
              end

              if row.level and Output.MARKERS[row.level] then
                T.marker(widget, row.level, width - INSET - size, y + math.floor((rowH - size) / 2), size)

                local mk = widget.fiche.tex[widget.fiche.used.tex]

                mk:SetDrawLayer("ARTWORK")
                mk:SetTexCoord(0, 1, 0, 1)
                mk:SetAlpha(1)
              end

              y = y + rowH
              hairline(widget, y, width)
              y = y + 1
            end
          end

          return y
        end

        return Output.build(parent, look)
      end,
    },
  },

  board = {
    header = { color = "text", line = "border" },
  },
})
