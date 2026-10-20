EbonAPI:RegisterSkin("Midnight", {
  parent = "AutoCallboard",

  background = 0x0B1020,
  accent = 0x3FA7F5,
  opacity = 0.55,
  shadow = 0.7,
  corners = 6,

  window = {
    glass = { enabled = true, tint = 0xB8D4FF, darken = 0.45, milk = 0.06, grain = 0.05, sheen = 0.1, edge = 0.14 },
    gradient = { orientation = "VERTICAL", color = "selected", to = 0.08 },
    fade = 0.15,
  },

  nav = {
    tab = { brick = "bar", align = "LEFT" },
  },

  widgets = {
    toggle = { brick = "switch" },
    group = { brick = "line" },
    heading = { lines = "AFTER" },
    range = { fill = true },
    synthesis = { brick = "glass", tile = { width = 150 } },
    -- Saves: gauge rows of glass, a glow in the focus color on the chosen one.
    saves = {
      view = "gauge", detail = "inline",
      row = { frame = "SMALL", fill = "card", border = "borderDim", selected = "focus" },
    },
  },

  bricks = {
    -- The summary tiles as frosted-glass cards of three lines: marker and label (muted), value (text, larger
    -- font), sub-text on two lines (muted). The selected card gets an inner hairline (four 1 px textures made
    -- once) in the selection key, a glow next to its border. The grid is the common one.
    synthesis = {
      glass = function(parent, B)
        local Tiles = EbonAPI.Tiles
        local MARGIN, SPACE = 6, 3
        local look = {}

        local labelRole, valueRole, selected = EbonAPI.Skins.synthesisRoles(B)

        -- Marker on the first line, centred on the line height of the label.
        local function paintMarker(tile)
          local size = tile.markerSize or 1

          Tiles.paintMarker(tile, size)

          if tile.marker:IsShown() then
            local side = tile.marker:GetWidth()
            local pad = math.floor((size - side) / 2)

            tile.marker:ClearAllPoints()
            tile.marker:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", MARGIN + pad, -(MARGIN + pad))
          end
        end

        -- The inner hairline: shown in the selection key on the selected card only.
        local function paintGlow(box, tile)
          local on = selected(box, tile)

          tile.glowKey = on and B.value("widgets.synthesis.selected") or nil

          for _, edge in ipairs(tile.glow) do
            if on then
              B.paint(edge, "SetVertexColor", tile.glowKey)
              edge:Show()
            else
              edge:Hide()
            end
          end
        end

        local function paintBorder(box, tile)
          local key = Tiles.borderKey(box, tile)

          if key ~= tile.border then
            B.frame(tile.frame, "small", B.value("widgets.synthesis.fill"), key)
            tile.border = key
          end

          paintGlow(box, tile)
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
          local tile = { frame = frame, lookName = "glass", margin = MARGIN, space = SPACE, glow = {} }
          local solid = B.media("solid")

          Tiles.wire(box, tile)
          tile.marker = frame:CreateTexture(nil, "OVERLAY")

          for index = 1, 4 do
            tile.glow[index] = frame:CreateTexture(nil, "BORDER")
            tile.glow[index]:SetTexture(solid)
            tile.glow[index]:SetAlpha(0.7)
            tile.glow[index]:Hide()
          end

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

        -- Margins, one label line, one value line, two sub-text lines, two gaps (from the font sizes).
        function look.height(box)
          local small = math.ceil(B.value("fonts." .. labelRole() .. ".size"))

          return 2 * MARGIN + small + math.ceil(B.value("fonts." .. valueRole() .. ".size")) + 2 * small + 2 * SPACE
        end

        function look.paint(box, tile, width, height)
          local frame = tile.frame
          local lr, vr = labelRole(), valueRole()
          local inner = math.max(1, width - 2 * MARGIN)

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

          local first = Tiles.lineHeight(tile.label, lr)
          local second = Tiles.lineHeight(tile.value, vr)
          local small = math.ceil(B.value("fonts." .. lr .. ".size"))

          tile.markerSize = first
          paintMarker(tile)

          tile.label:ClearAllPoints()
          tile.label:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN + first + SPACE, -MARGIN)
          tile.label:SetWidth(math.max(1, inner - first - SPACE))
          tile.label:SetHeight(first)
          tile.value:ClearAllPoints()
          tile.value:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -(MARGIN + first + SPACE))
          tile.value:SetWidth(inner)
          tile.value:SetHeight(second)
          tile.sub:ClearAllPoints()
          tile.sub:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -(MARGIN + first + SPACE + second + SPACE))
          tile.sub:SetWidth(inner)
          tile.sub:SetHeight(2 * small)

          -- Inner hairline, one pixel inside the border.
          local edge = tile.glow
          local inset = B.insetOf(frame) + 1

          edge[1]:ClearAllPoints()
          edge[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
          edge[1]:SetWidth(math.max(1, width - 2 * inset))
          edge[1]:SetHeight(1)
          edge[2]:ClearAllPoints()
          edge[2]:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -(height - inset - 1))
          edge[2]:SetWidth(math.max(1, width - 2 * inset))
          edge[2]:SetHeight(1)
          edge[3]:ClearAllPoints()
          edge[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
          edge[3]:SetWidth(1)
          edge[3]:SetHeight(math.max(1, height - 2 * inset))
          edge[4]:ClearAllPoints()
          edge[4]:SetPoint("TOPLEFT", frame, "TOPLEFT", width - inset - 1, -inset)
          edge[4]:SetWidth(1)
          edge[4]:SetHeight(math.max(1, height - 2 * inset))
        end

        function look.update(box, tile, old)
          local item = tile.item

          if item.label ~= old.label or item.value ~= old.value or item.sub ~= old.sub then
            paintTexts(tile)
          end

          if item.level ~= old.level then
            paintMarker(tile)
          end

          paintBorder(box, tile)
        end

        return Tiles.build(parent, look)
      end,
    },
  },
})
