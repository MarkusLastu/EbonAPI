EbonAPI:RegisterSkin("Tiling", {
  parent = "AutoCallboard",

  background = 0x1E1E2E,
  accent = 0xCBA6F7,
  opacity = 0.86,
  shadow = 0.5,
  corners = 10,

  palette = {
    bg = { 0x1E1E2E, 0.86 },
    bgSoft = 0x313244,
    card = { 0x181825, 0.9 },
    border = 0xCBA6F7,
    borderDim = 0x45475A,
    button = 0x313244,
    buttonBorder = 0x45475A,
    buttonHover = 0xCBA6F7,
    buttonHoverFill = 0x45475A,
    buttonDisabledBorder = { 0x45475A, 0.5 },
    buttonText = 0xCDD6F4,
    buttonDisabledText = { 0xCDD6F4, 0.4 },
    checkbox = 0x313244,
    checkboxBorder = 0x6C7086,
    checked = 0xA6E3A1,
    thumb = 0x6C7086,
    selected = 0xCBA6F7,
    selectedText = 0x11111B,
    text = 0xCDD6F4,
    muted = 0xA6ADC8,
    title = 0xB4BEFE,
    heading = 0x89B4FA,
    menu = 0xCBA6F7,
    shadow = 0xCBA6F7,
    focus = 0xF5C2E7,
    rowHover = 0x313244,
    headerBg = { 0x11111B, 0.5 },
    navBg = { 0x000000, 0 },
    pageBg = { 0x000000, 0 },
    footerBg = { 0x000000, 0 },
    success = 0xA6E3A1,
    danger = 0xF38BA8,
    caution = 0xFAB387,
  },

  fonts = {
    small = { file = "Fonts\\ARIALN.TTF", size = 11 },
    normal = { file = "Fonts\\ARIALN.TTF", size = 13 },
    large = { file = "Fonts\\ARIALN.TTF", size = 18 },
    button = { file = "Fonts\\ARIALN.TTF", size = 12, outline = "NONE" },
    shadow = { alpha = 0.6 },
  },

  border = {
    size = 2,
  },

  window = {
    padding = 12,
    spacing = 34,
    shadow = { spread = 16, alphaBase = 0.1, alphaSpread = 0.35 },
    glass = {
      enabled = true, tint = 0xB4BEFE, darken = 0.5, milk = 0.03, grain = 0.04,
      sheen = 0.04, sheenHeight = 0.3, edge = 0.06,
    },
  },

  windows = {
    detach = { header = true, nav = true, page = true },
    gap = 10,
    snap = 20,
  },

  header = {
    height = 30,
    title = { y = 9, font = "normal", color = "title" },
    version = { y = 0 },
    search = { position = "CENTER", width = 220, height = 20 },
    close = { brick = "flat", size = 30, width = 36, y = 0, glyph = "×", hover = 0xF38BA8 },
    rule = { show = false },
    inset = -12,
  },

  nav = {
    width = 170,
    inset = 4,
    section = { upper = true, x = 4 },
    tab = { brick = "bar", gap = 3, align = "LEFT", font = "normal" },
  },

  page = {
    width = 600,
    height = 500,
    top = 44,
    inset = { x = 6, y = 4 },
    close = { size = 30, width = 36, glyph = "×" },
    title = { color = "title" },
  },

  widgets = {
    toggle = { brick = "switch", mark = 2, roundKnob = true, switch = { width = 30, height = 16 } },
    range = { fill = true, fillColor = "border", roundThumb = true, thumb = { width = 12, height = 12 } },
    menu = { brick = "list", title = { align = "LEFT" } },
    heading = { upper = true },
    group = { brick = "line", upper = true, font = "small", padding = 8 },
    scroll = { trackAlpha = 0.3 },
    synthesis = { brick = "pills" },
  },

  bricks = {
    -- The summary tiles as workspace pills laid out in a flow: a square block (the numeric token of the value on
    -- a tint of the level, or the level marker) then the label. The row wraps when the next pill does not fit;
    -- a pill is never wider than the box. The sub-text is only in the tooltip.
    synthesis = {
      pills = function(parent, B)
        local Tiles = EbonAPI.Tiles
        local MARGIN = 4
        local look = {}
        local TINT = { ok = "success", warn = "caution", bad = "danger", info = "muted", net = "focus" }

        local labelRole, valueRole, selected = EbonAPI.Skins.synthesisRoles(B)

        -- The block shows the numeric token at the head of the value, else the marker of the level.
        local function paintBlock(box, tile)
          local item = tile.item
          local token = (item.value or ""):match("^[%d][%d%.,]*")
          local side = tile.blockSide or 1
          local key = selected(box, tile) and B.value("widgets.synthesis.selected") or TINT[item.level] or "muted"

          tile.blockKey = key
          B.paint(tile.block, "SetVertexColor", key)

          -- value and sub carry the full texts of the item for the readers of the tile (hidden, never drawn)
          tile.value:SetText(item.value or "")
          tile.sub:SetText(item.sub or "")
          tile.token:SetText(token or "")
          Tiles.paintMarker(tile, side)

          if tile.marker:IsShown() then
            local pad = math.floor((side - tile.marker:GetWidth()) / 2)
            local inset = B.insetOf(tile.frame)

            tile.marker:ClearAllPoints()
            tile.marker:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", inset + pad, -(inset + pad))
          end

          if token then
            tile.token:Show()
            tile.marker:Hide()
          else
            tile.token:Hide()
          end
        end

        local function paintBorder(box, tile)
          local key = Tiles.borderKey(box, tile)

          if key ~= tile.border then
            B.frame(tile.frame, "small", B.value("widgets.synthesis.fill"), key)
            tile.border = key
          end
        end

        local function paintLook(box, tile)
          local item = tile.item

          paintBorder(box, tile)
          paintBlock(box, tile)
          B.paint(tile.label, "SetTextColor", item.level == "info" and "muted" or "text")
          B.paint(tile.token, "SetTextColor", "text")
          Tiles.setTip(tile)
        end

        function look.new(box)
          local frame = CreateFrame("Button", nil, box)
          local tile = { frame = frame, lookName = "pills", margin = MARGIN }

          Tiles.wire(box, tile)
          tile.block = frame:CreateTexture(nil, "ARTWORK")
          tile.block:SetTexture(B.media("solid"))
          tile.marker = frame:CreateTexture(nil, "OVERLAY")
          tile.token = B.text(frame, valueRole(), "text")
          tile.token:SetJustifyH("CENTER")
          tile.token:SetJustifyV("MIDDLE")
          EbonAPI.Tiles.wrap(tile.token, false)
          tile.value = B.text(frame, valueRole(), "text")
          tile.value:Hide()
          tile.sub = B.text(frame, labelRole(), "muted")
          tile.sub:Hide()
          tile.label = B.text(frame, labelRole(), "text")
          tile.label:SetJustifyH("LEFT")
          tile.label:SetJustifyV("MIDDLE")
          EbonAPI.Tiles.wrap(tile.label, false)

          return tile
        end

        -- One line of text and a margin above and below.
        function look.height(box)
          return math.ceil(B.value("fonts." .. labelRole() .. ".size")) + 2 * MARGIN
        end

        -- Paints and sizes one pill: width is the room left in the box, the pill takes its measured width.
        function look.paint(box, tile, width, height)
          local frame = tile.frame
          local lr, vr = labelRole(), valueRole()

          tile.border = nil
          B.frame(frame, "small", B.value("widgets.synthesis.fill"), Tiles.borderKey(box, tile))
          tile.border = Tiles.borderKey(box, tile)
          B.font(tile.label, lr)
          B.font(tile.token, vr)
          tile.label:SetText(tile.item.label or "")
          tile.label:SetWidth(4096)

          local inset = B.insetOf(frame)
          local side = math.max(1, height - 2 * inset)
          local lh = math.min(Tiles.lineHeight(tile.label, lr), side)
          local left = inset + side + MARGIN
          local total = math.min(width, left + math.ceil(tile.label:GetStringWidth() or 0) + MARGIN + inset)

          frame:SetWidth(total)
          frame:SetHeight(height)
          tile.blockSide = side
          tile.block:ClearAllPoints()
          tile.block:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
          tile.block:SetWidth(side)
          tile.block:SetHeight(side)
          tile.token:ClearAllPoints()
          tile.token:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
          tile.token:SetWidth(side)
          tile.token:SetHeight(side)
          tile.label:ClearAllPoints()
          tile.label:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -(inset + math.floor((side - lh) / 2)))
          tile.label:SetWidth(math.max(1, total - left - MARGIN - inset))
          tile.label:SetHeight(lh)
          paintLook(box, tile)
        end

        function look.update(box, tile, old)
          if tile.item.label ~= old.label then
            -- the width of the pill changes: the flow is laid out again (nothing is created)
            box:Refresh()

            return
          end

          paintLook(box, tile)
        end

        -- The flow: pills one after the other, the row wraps when the next one does not fit.
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
            label:SetText(EbonAPI.Lib.upper(group.label or ""))
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
            label:SetWidth(width)

            local lh = Tiles.lineHeight(label, role)

            label:SetHeight(lh)
            label:Show()
            y = y + lh + gap

            local x, row = 0, 0

            for _, tile in ipairs(group.tiles) do
              box.look.paint(box, tile, width, th)

              local w = tile.frame:GetWidth()

              if x > 0 and x + w > width + 0.01 then
                x = 0
                row = row + 1
              end

              tile.frame:ClearAllPoints()
              tile.frame:SetPoint("TOPLEFT", box, "TOPLEFT", x, -(y + row * (th + gap)))
              tile.frame:Show()
              x = x + w + gap
            end

            local rows = #group.tiles > 0 and row + 1 or 0

            y = y + rows * th + math.max(0, rows - 1) * gap

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
  },

  kit = {
    icon = { border = "checkboxBorder" },
    rows = { action = 20, fill = "selected", fillAlpha = 0.35, mark = "danger", markAlpha = 0.3, suffix = "muted" },
  },

  chat = {
    prefix = 0xCBA6F7,
    text = 0xCDD6F4,
    error = 0xF38BA8,
    warn = 0xFAB387,
    success = 0xA6E3A1,
    highlight = 0xF9E2AF,
    muted = 0xA6ADC8,
  },

  board = {
    header = { line = "border" },
  },
})
