EbonAPI:RegisterSkin("AutoCallboard", {
  background = 0x050505,
  accent = 0xB048F8,
  opacity = 0.96,
  shadow = 0.4,

  palette = {
    bg = { 0x050505, 0.96 },
    bgSoft = { 0x050505, 0.86 },
    card = { 0x050505, 0.92 },
    border = 0x4B2E83,
    borderDim = { 0x4B2E83, 0.65 },
    button = 0x4B2E83,
    buttonBorder = 0x4B2E83,
    buttonHover = 0xE879FF,
    buttonDisabledBorder = { 0x4B2E83, 0 },
    buttonText = 0xD1D1F6,
    buttonDisabledText = { 0xD1D1F6, 0.45 },
    checkbox = 0x050505,
    checkboxBorder = 0x4B2E83,
    checked = 0xB048F8,
    thumb = 0x4B2E83,
    selected = 0xB048F8,
    selectedText = 0x0A0A0A,
    text = 0xD1F6F6,
    muted = { 0xD1E3F6, 0.78 },
    title = 0xD1D1F6,
    heading = 0xB048F8,
    menu = 0xB048F8,
    focus = 0xE879FF,
    buttonHoverFill = 0x4B2E83,
    rowHover = { 0xB048F8, 0.2 },
    headerBg = { 0x050505, 0 },
    navBg = { 0x050505, 0 },
    pageBg = { 0x050505, 0 },
    footerBg = { 0x050505, 0 },
  },

  border = {
    style = "ROUND",
    large = {
      background = "Interface\\Buttons\\WHITE8X8", edge = "Interface\\Tooltips\\UI-Tooltip-Border",
      size = 16, inset = 4, tile = 0,
    },
    small = { background = "Interface\\Buttons\\WHITE8X8", size = 10, inset = 2, tile = 0 },
  },

  window = {
    padding = 14,
  },

  header = {
    height = 44,
    title = { y = 14, align = "SIDE", font = "large" },
    banner = { texture = "", width = 256 },
    version = { show = true },
    search = { width = 200, height = 22, inset = 8 },
    close = { brick = "default", size = 22, width = 22, y = 11, glyph = "X" },
    rule = { show = true },
    inset = 0,
  },

  nav = {
    width = 184,
    padding = 0,
    tab = { brick = "fill", height = 24, gap = 4, align = "CENTER", font = "button", padding = 6 },
  },

  page = {
    width = 634,
    height = 528,
    description = { color = "muted" },
    close = { size = 22, width = 22, glyph = "X" },
    inset = { x = 0, y = 0 },
  },

  widgets = {
    tooltip = { skinned = true },
    button = { brick = "default", padding = 12 },
    execute = { brick = "default", height = 24 },
    toggle = { brick = "box", height = 22, size = 16, gap = 6 },
    range = { brick = "default", height = 50, top = 15, bar = 14, thumb = { width = 8, height = 14 } },
    menu = { brick = "fill", inset = 6, title = { align = "CENTER" } },
    input = { brick = "default", field = 22 },
    group = { padding = 10, frame = "LARGE" },
    synthesis = { brick = "cards", tile = { width = 210 } },
    -- Saves: rows as small rounded cards, the detail drawer under the chosen row.
    saves = { view = "list", detail = "inline", row = { frame = "SMALL", fill = "card", border = "borderDim" } },
    output = { brick = "default" },
  },

  board = {
    header = { color = "heading", line = "borderDim" },
  },

  bricks = {
    -- The summary tiles as cards: an icon disc (ring tinted by the level, marker in the centre) on the left,
    -- the label and the value on one line, the sub-text under them. The grid is the common one.
    synthesis = {
      cards = function(parent, B)
        local Tiles = EbonAPI.Tiles
        local MARGIN, SPACE = 6, 6
        local look = {}
        local LEVEL_KEY = { ok = "success", warn = "caution", bad = "danger", info = "muted", net = "focus" }

        local function mainRole()
          return B.value("widgets.synthesis.value.font")
        end

        local function disc(box)
          return math.ceil(B.value("fonts." .. mainRole() .. ".size")) + math.ceil(B.value("fonts.small.size"))
        end

        local function paintRing(tile)
          tile.ringKey = LEVEL_KEY[tile.item.level] or "muted"
          B.paint(tile.ring, "SetVertexColor", tile.ringKey)
        end

        local function paintMarker(tile)
          Tiles.paintMarker(tile, tile.ring:GetHeight() * 0.6)
          tile.marker:ClearAllPoints()
          tile.marker:SetPoint("CENTER", tile.ring, "CENTER", 0, 0)
        end

        -- Texts, tooltip and the widths of the label (its measured text) and of the value (the rest).
        local function paintTexts(tile)
          local item = tile.item
          local width = tile.cardWidth or 1
          local x0 = MARGIN + tile.ring:GetWidth() + SPACE
          local avail = math.max(1, width - x0 - MARGIN)

          tile.label:SetText(item.label or "")
          tile.value:SetText(item.value or "")
          tile.sub:SetText(item.sub or "")
          Tiles.setTip(tile)

          local first = math.ceil(B.value("fonts." .. mainRole() .. ".size"))
          -- Measured on an unconstrained width: the string width follows the field width when it is narrow.
          tile.label:SetWidth(4096)

          local lw = math.min(math.max(1, math.ceil(tile.label:GetStringWidth() or 0) + 1), math.max(1, avail - SPACE - 1))

          tile.label:ClearAllPoints()
          tile.label:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", x0, -MARGIN)
          tile.label:SetWidth(lw)
          tile.label:SetHeight(first)
          tile.value:ClearAllPoints()
          tile.value:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", x0 + lw + SPACE, -MARGIN)
          tile.value:SetWidth(math.max(1, avail - lw - SPACE))
          tile.value:SetHeight(first)
          tile.sub:ClearAllPoints()
          tile.sub:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", x0, -(MARGIN + first))
          tile.sub:SetWidth(avail)
          tile.sub:SetHeight(math.ceil(B.value("fonts.small.size")))
        end

        function look.new(box)
          local frame = CreateFrame("Button", nil, box)
          local tile = { frame = frame, lookName = "cards", discKey = "well" }

          Tiles.wire(box, tile)
          tile.ring = frame:CreateTexture(nil, "BACKGROUND")
          tile.disc = frame:CreateTexture(nil, "BORDER")
          tile.marker = frame:CreateTexture(nil, "OVERLAY")
          tile.ring:SetTexture(B.media("circle"))
          tile.disc:SetTexture(B.media("circle"))
          tile.label = B.text(frame, mainRole(), "text")
          tile.value = B.text(frame, mainRole(), "muted")
          tile.sub = B.text(frame, "small", "muted")

          for _, fs in ipairs({ tile.label, tile.value, tile.sub }) do
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("TOP")
            EbonAPI.Tiles.wrap(fs, false)
          end

          return tile
        end

        function look.height(box)
          return disc(box) + 2 * MARGIN
        end

        function look.paint(box, tile, width, height)
          local frame = tile.frame
          local key = Tiles.borderKey(box, tile)
          local size = disc(box)
          local ring = 4

          B.frame(frame, "small", B.value("widgets.synthesis.fill"), key)
          tile.border = key
          frame:SetWidth(width)
          frame:SetHeight(height)
          tile.cardWidth = width

          tile.ring:SetWidth(size)
          tile.ring:SetHeight(size)
          tile.ring:ClearAllPoints()
          tile.ring:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -MARGIN)
          tile.disc:SetWidth(size - ring)
          tile.disc:SetHeight(size - ring)
          tile.disc:ClearAllPoints()
          tile.disc:SetPoint("CENTER", tile.ring, "CENTER", 0, 0)
          B.paint(tile.disc, "SetVertexColor", tile.discKey)
          paintRing(tile)

          B.font(tile.label, mainRole())
          B.font(tile.value, mainRole())
          B.font(tile.sub, "small")
          B.paint(tile.label, "SetTextColor", "text")
          B.paint(tile.value, "SetTextColor", "muted")
          B.paint(tile.sub, "SetTextColor", "muted")
          paintTexts(tile)
          paintMarker(tile)
        end

        function look.update(box, tile, old)
          local item = tile.item

          if item.label ~= old.label or item.value ~= old.value or item.sub ~= old.sub then
            paintTexts(tile)
          end

          if item.level ~= old.level then
            paintRing(tile)
            paintMarker(tile)
          end

          local key = Tiles.borderKey(box, tile)

          if key ~= tile.border then
            B.frame(tile.frame, "small", B.value("widgets.synthesis.fill"), key)
            tile.border = key
          end
        end

        return Tiles.build(parent, look)
      end,
    },
  },
})
