local PANEL = "Interface\\Buttons\\UI-Panel-Button-"
local SLICES = { { 0, 0.09375 }, { 0.09375, 0.53125 }, { 0.53125, 0.625 } }
local CAP = 12

local function panelButton(parent, B)
  local button = B.baseButton(parent, function(self)
    local state = "Up"
    local text = self.hovered and "text" or "heading"

    if self.disabledState then
      state, text = "Disabled", "muted"
    elseif self.pressed then
      state = "Down"
    end

    for _, part in ipairs(self.parts) do
      part:SetTexture(PANEL .. state)
    end

    B.paint(self.label, "SetTextColor", text)
    B.labelFont(self, text)
  end)

  button.role = "normal"
  button.parts = {}

  for index, slice in ipairs(SLICES) do
    local part = button:CreateTexture(nil, "BACKGROUND")

    part:SetTexCoord(slice[1], slice[2], 0, 0.6875)
    button.parts[index] = part
  end

  local left, middle, right = button.parts[1], button.parts[2], button.parts[3]

  left:SetWidth(CAP)
  left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  right:SetWidth(CAP)
  right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
  middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
  middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)

  local glow = button:CreateTexture(nil, "HIGHLIGHT")

  glow:SetTexture(PANEL .. "Highlight")
  glow:SetTexCoord(0, 0.625, 0, 0.6875)
  glow:SetBlendMode("ADD")
  glow:SetAllPoints(button)

  button:SetScript("OnMouseDown", function(self)
    self.pressed = true
    self:Visual()
  end)
  button:SetScript("OnMouseUp", function(self)
    self.pressed = false
    self:Visual()
  end)

  button:Visual()

  return button
end

EbonAPI:RegisterSkin("Azeroth", {
  background = 0x000000,
  accent = 0xFFD100,
  scale = 1,
  opacity = 1,
  shadow = 0.5,
  corners = 0,
  tabs = "LEFT",
  locked = false,

  palette = {
    bg = 0xFFFFFF,
    bgSoft = { 0x0C0C1A, 0.9 },
    card = { 0x191919, 0.6 },
    border = 0xFFFFFF,
    borderDim = 0x666666,
    button = 0x2A1A0A,
    buttonBorder = 0x8C6E3C,
    buttonHover = 0xFFD100,
    buttonDisabledBorder = { 0x8C6E3C, 0.4 },
    buttonText = 0xFFD100,
    buttonDisabledText = { 0x808080, 1 },
    checkbox = 0x000000,
    checkboxBorder = 0x8C6E3C,
    checked = 0xFFD100,
    thumb = 0x8C6E3C,
    selected = 0x3263CC,
    selectedText = 0xFFFFFF,
    text = 0xFFFFFF,
    muted = 0x9D9D9D,
    title = 0xFFD100,
    heading = 0xFFD100,
    menu = 0xFFD100,
    shadow = 0x000000,
    focus = 0xFFD100,
    buttonHoverFill = 0x3A2410,
    rowHover = { 0x3263CC, 0.45 },
    headerBg = { 0x000000, 0 },
    navBg = { 0x000000, 0.35 },
    pageBg = { 0x000000, 0 },
    footerBg = { 0x000000, 0 },
    success = 0x40FF40,
    danger = 0xFF4444,
    caution = 0xFF9900,
  },

  contrast = { minimum = 4.5, enforce = true, light = 0.96, dark = 0.04, step = 0.15, attempts = 30, mutedStep = 0.05 },

  fonts = {
    small = { file = "game", size = 10, outline = "NONE" },
    normal = { file = "game", size = 12, outline = "NONE" },
    large = { file = "game", size = 16, outline = "NONE" },
    button = { file = "game", size = 10, outline = "AUTO" },
    shadow = { x = 1, y = -1, color = 0x000000, alpha = 1 },
  },

  media = {
    solid = "Interface\\Buttons\\WHITE8X8",
    rounded = "Interface\\Tooltips\\UI-Tooltip-Border",
    arrow = "Interface\\Buttons\\Arrow-Down-Up",
    shadow = "Interface\\AddOns\\EbonAPI\\Media\\Shadow",
    grain = "Interface\\AddOns\\EbonAPI\\Media\\Grain",
    circle = "Interface\\AddOns\\EbonAPI\\Media\\Circle",
    chevron = "Interface\\AddOns\\EbonAPI\\Media\\Chevron",
    sidebar = "Interface\\AddOns\\EbonAPI\\Media\\Sidebar",
    error = "Interface\\AddOns\\EbonAPI\\Media\\Error",
    warning = "Interface\\AddOns\\EbonAPI\\Media\\Warning",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    addonIcon = "Interface\\Icons\\INV_Misc_QuestionMark",
    pointer = "Interface\\AddOns\\EbonAPI\\Media\\Pointer",
  },

  border = {
    size = 1,
    round = { base = 4, small = 10, inset = 0.25 },
    style = "TEXTURE",
    large = {
      background = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edge = "Interface\\DialogFrame\\UI-DialogBox-Border",
      size = 32, inset = 11, tile = 32,
    },
    small = {
      background = "Interface\\Tooltips\\UI-Tooltip-Background",
      edge = "Interface\\Tooltips\\UI-Tooltip-Border",
      size = 16, inset = 4, tile = 16,
    },
  },

  window = {
    padding = 18,
    spacing = 14,
    card = { border = "border" },
    strata = "HIGH",
    texture = "",
    textureAlpha = 1,
    gradient = { orientation = "NONE", color = "text", from = 0, to = 0.06 },
    shadow = { base = 4, spread = 14, alphaBase = 0.25, alphaSpread = 0.5, x = 0, y = 0, level = -1 },
    glass = {
      enabled = false, tint = 0xFFFFFF, darken = 0.35, milk = 0.1, grain = 0.06,
      sheen = 0.08, sheenHeight = 0.4, edge = 0.12, edgeSize = 1,
    },
    fade = 0,
    sound = { open = "", close = "" },
  },

  windows = {
    detach = { header = false, nav = false, page = false, pages = false, list = {} },
    gap = 8,
    snap = 12,
    cascade = 24,
  },

  header = {
    show = true,
    height = 40,
    controls = "RIGHT",
    title = { show = true, x = 2, y = 2, align = "CENTER", color = "heading", font = "normal" },
    banner = { texture = "Interface\\DialogFrame\\UI-DialogBox-Header", width = 300, height = 64, y = 12 },
    version = { show = false, gap = 8, y = 1 },
    search = { show = true, width = 160, height = 20, gap = 10, inset = 6, insetY = 2, position = "CONTROLS" },
    close = { brick = "native", show = true, size = 32, width = 32, y = 4, glyph = "", hover = 0xE81123, ink = 0x4D0000 },
    rule = { show = false, size = 1 },
    inset = -14,
    spacing = 4,
    history = { show = false, back = "<", forward = ">", width = 22 },
    minimize = { show = false, width = 32, glyph = "-", color = 0xFEBC2E, ink = 0x995700 },
    zoom = { glyph = "+", color = 0x28C840, ink = 0x006500 },
    sidebar = { show = false, size = 16, width = 22 },
  },

  footer = {
    show = false,
    height = 22,
    version = true,
    rule = true,
    ruleSize = 1,
    inset = 2,
    refresh = 1,
    badge = { show = false, color = "focus", text = "selectedText", padding = 8 },
    items = false,
    gap = 10,
    icon = 12,
  },

  panel = { button = { width = 240, height = 24 }, margin = 16, gap = 12 },
  gamemenu = { gap = 1 },

  nav = {
    width = 175,
    inset = 10,
    padding = 6,
    divider = { size = 0, color = "borderDim" },
    frame = "NONE",
    rail = {
      show = false, width = 36, gap = 4, icon = 20, spacing = 4, indicator = 2,
      color = "headerBg", desaturate = true, dim = 0.6, filter = true, crop = 0.08, indicatorColor = "focus",
    },
    tree = {
      collapsible = false, expanded = true, guides = false, chevron = 10, chevronColor = "text",
      guideColor = "borderDim", guideWidth = 1, margin = 2,
    },
    section = {
      brick = "default", show = true, x = 2, height = 20, before = 6, after = 2,
      upper = false, color = "muted", font = "small",
    },
    tab = {
      brick = "native", height = 18, gap = 1, indent = 12, align = "LEFT", bar = 3,
      font = "normal", padding = 8, glow = { selected = 1, hover = 0.5 },
    },
  },

  page = {
    width = 600,
    height = 480,
    gutter = 16,
    top = 46,
    title = { show = true, y = 2, color = "heading", font = "large" },
    description = { show = true, gap = 6, below = 4, color = "text", font = "small" },
    unit = 170,
    gap = { x = 14, y = 12 },
    inset = { x = 6, y = 4 },
    layout = "FLOW",
    descriptions = "TOOLTIP",
    addons = "CARDS",
    strip = {
      show = false, height = 26, padding = 12, border = 1,
      color = "headerBg", tab = "pageBg", accent = "focus", text = "title",
      tabs = 1, idle = "headerBg", idleText = "muted", separator = "borderDim", close = 16,
      font = "button", separatorWidth = 1,
    },
    close = { size = 32, width = 32, gap = 10, glyph = "" },
    frame = "NONE",
    crumbs = { show = false, height = 20, separator = ">", color = "muted", font = "small" },
  },

  widgets = {
    disabledAlpha = 0.5,
    tooltip = { anchor = "ANCHOR_RIGHT", skinned = false },
    button = { brick = "native", height = 22, padding = 15 },
    execute = { brick = "native", height = 22 },
    toggle = {
      brick = "native", height = 26, size = 26, mark = 3, gap = 2, margin = 2,
      markTexture = "", roundKnob = false,
      switch = { width = 28, height = 14 },
    },
    range = {
      brick = "native", height = 52, top = 16, bar = 17, track = 4, labels = 3,
      fill = false, fillColor = "checked", roundThumb = false,
      thumb = { width = 32, height = 32 },
      edit = { width = 60, height = 16, y = 2 },
    },
    select = {
      brick = "default", height = 42, top = 16, padding = 8,
      arrow = { size = 12, right = 22, x = 6, y = 1 },
    },
    menu = {
      brick = "list", row = 20, gap = 1, padding = 3, inset = 12, offset = 2, strata = "FULLSCREEN_DIALOG",
      title = { font = "small", color = "heading", align = "LEFT" },
    },
    color = { brick = "default", height = 22, size = 18, gap = 6, margin = 2 },
    input = {
      brick = "native", height = 42, top = 16, field = 20, padding = 6, paddingY = 2,
      line = 14, lines = 4, linePad = 8, bottom = 2, gap = 2,
    },
    heading = {
      brick = "default", height = 22, gap = 8, lines = "BOTH", size = 1, upper = false, color = "heading",
    },
    text = { brick = "default", extra = 4 },
    group = {
      brick = "card", padding = 12, title = 18, titleX = 2,
      upper = false, color = "heading", font = "normal", frame = "SMALL",
    },
    scroll = { brick = "default", width = 6, thumb = 40, step = 40, trackAlpha = 1 },
  },

  kit = {
    padding = 8,
    spacing = 6,
    inset = 4,
    gap = 2,
    columns = 4,
    wrap = 320,
    text = { font = "small" },
    bar = { color = "card", border = "borderDim" },
    header = 30,
    control = 22,
    icon = {
      size = 32, inset = 2, trim = 0.08,
      color = "checkbox", border = "buttonBorder", hover = "buttonHover", checked = "checked",
    },
    badge = { size = 14, level = 3, color = "focus", text = "selectedText" },
    progress = { height = 14, color = "checked", background = "bgSoft", border = "borderDim" },
    row = 20,
    rows = { action = 18, fill = "checked", fillAlpha = 0.3, mark = "danger", markAlpha = 0.2, suffix = "muted" },
    slot = 24,
    indent = 12,
    list = 200,
    scroll = { width = 320, height = 240 },
    table = { row = 18, sort = 8, column = 20, selected = "selected", hover = "rowHover" },
    toast = { width = 260, duration = 4, top = 120, icon = 24, fade = 0.5 },
    problem = { alert = { width = 300, max = 3 }, discreet = { duration = 6, quiet = 60 } },
    band = { height = 22, alpha = 0.35, text = "text" },
    drag = 12,
    ghost = { width = 170, color = "selected", border = "focus" },
    handle = 12,
    dot = { color = "thumb", hover = "buttonHover" },
    pointer = 48,
    aim = { every = 0.05 },
    timer = { every = 0.1, font = "small" },
    chart = { color = "checked", height = 60, background = "bgSoft", border = "borderDim" },
    dialog = {
      width = 320, copy = 80, button = 80, choices = 6, offset = 120,
      title = { font = "normal", color = "heading", align = "CENTER" },
      field = { color = "bgSoft", border = "borderDim" },
    },
    minimap = {
      brick = "native", size = 31, inset = 4, ring = 2, offset = 10, corner = 10, angle = 225,
      group = { angle = 245, columns = 4 },
    },
    model = { width = 160, height = 220, turn = 0.02, zoom = { step = 0.25, min = -1, max = 3 } },
    combatAlpha = 0.3,
    animation = 0.15,
    rescale = { delay = 0.01 },
  },

  chat = {
    prefix = 0x8A6FD4,
    text = 0xD1D1F6,
    error = 0xFF4444,
    warn = 0xFF9900,
    success = 0x40FF40,
    highlight = 0xFFD200,
    muted = 0x9090A0,
    gold = 0xFFD700,
    silver = 0xC7C7CF,
    copper = 0xEDA55F,
  },

  bricks = {
    button = { native = panelButton },

    -- The minimap button of the game, as LibDBIcon-1.0 lays it out for a 31 px button: the tracking
    -- border in gold, its dark background and the icon, scaled to the size of the skin.
    minimap = {
      native = function(button, B)
        local size = B.value("kit.minimap.size")
        local unit = size / 31
        local edge = B.value("kit.icon.trim")
        local border = button:CreateTexture(nil, "OVERLAY")
        local background = button:CreateTexture(nil, "BACKGROUND")

        button:SetWidth(size)
        button:SetHeight(size)
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetWidth(53 * unit)
        border:SetHeight(53 * unit)
        border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        background:SetWidth(20 * unit)
        background:SetHeight(20 * unit)
        background:SetPoint("TOPLEFT", button, "TOPLEFT", 7 * unit, -5 * unit)
        button.icon:ClearAllPoints()
        button.icon:SetWidth(17 * unit)
        button.icon:SetHeight(17 * unit)
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7 * unit, -6 * unit)
        button.icon:SetTexCoord(edge, 1 - edge, edge, 1 - edge)

        return button
      end,
    },
    execute = { native = panelButton },

    close = {
      native = function(parent, B)
        local button = B.baseButton(parent, function(self)
          self.icon:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-" .. (self.pressed and "Down" or "Up"))
          B.paint(self.label, "SetTextColor", "heading")
          B.labelFont(self, "heading")
        end)
        local glow = button:CreateTexture(nil, "HIGHLIGHT")

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints(button)
        glow:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        glow:SetBlendMode("ADD")
        glow:SetAllPoints(button)
        button:SetPadding(0)
        button:SetScript("OnMouseDown", function(self)
          self.pressed = true
          self:Visual()
        end)
        button:SetScript("OnMouseUp", function(self)
          self.pressed = false
          self:Visual()
        end)

        button:Visual()

        return button
      end,
    },

    tab = {
      native = function(parent, B)
        local padding = B.value("nav.tab.padding")
        local button = B.baseButton(parent, function(self)
          local text = "heading"

          if self.disabledState then
            text = "muted"
          elseif self.selectedState or self.hovered then
            text = "text"
          end

          B.paint(self.label, "SetTextColor", text)
          B.labelFont(self, text)

          if self.selectedState or self.hovered then
            self.glow:SetAlpha(B.value(self.selectedState and "nav.tab.glow.selected" or "nav.tab.glow.hover"))
            self.glow:Show()
          else
            self.glow:Hide()
          end
        end)

        button.role = B.value("nav.tab.font")
        button.glow = button:CreateTexture(nil, "BACKGROUND")
        button.glow:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
        button.glow:SetBlendMode("ADD")
        button.glow:SetAllPoints(button)
        B.paint(button.glow, "SetVertexColor", "selected")
        button.label:SetJustifyH("LEFT")
        button:SetPadding(padding)
        button:Visual()

        return button
      end,
    },

    toggle = {
      native = function(parent, B)
        local row = B.toggleRow(parent, function(owner)
          local size = B.value("widgets.toggle.size")
          local texture = B.value("widgets.toggle.markTexture")
          local box = CreateFrame("Frame", nil, owner)
          local up = box:CreateTexture(nil, "ARTWORK")
          local check = box:CreateTexture(nil, "OVERLAY")
          local glow = box:CreateTexture(nil, "OVERLAY")

          box:SetWidth(size)
          box:SetHeight(size)
          box:SetPoint("LEFT", owner, "LEFT", 0, 0)
          up:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
          up:SetAllPoints(box)
          check:SetTexture(texture ~= "" and texture or "Interface\\Buttons\\UI-CheckBox-Check")
          check:SetAllPoints(box)
          glow:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
          glow:SetBlendMode("ADD")
          glow:SetAllPoints(box)
          owner.mark, owner.glow = check, glow

          return box, size
        end)

        function row:Visual()
          if self.value then
            self.mark:Show()
          else
            self.mark:Hide()
          end

          if self.hovered and not self.disabledState then
            self.glow:Show()
          else
            self.glow:Hide()
          end
        end

        row:SetValue(false)

        return row
      end,
    },

    range = {
      native = function(parent, B)
        return B.rangeBox(parent, function(slider)
          slider:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 },
          })
          slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

          return {}
        end)
      end,
    },

    input = {
      native = function(parent, B)
        local parts = {}
        local box = B.inputBox(parent, function(field)
          for index, slice in ipairs({ { 0, 0.0625 }, { 0.0625, 0.9375 }, { 0.9375, 1 } }) do
            local part = field:CreateTexture(nil, "BACKGROUND")

            part:SetTexture("Interface\\Common\\Common-Input-Border")
            part:SetTexCoord(slice[1], slice[2], 0, 0.625)
            parts[index] = part
          end

          parts[1]:SetWidth(8)
          parts[1]:SetPoint("TOPLEFT", field, "TOPLEFT", 0, 0)
          parts[1]:SetPoint("BOTTOMLEFT", field, "BOTTOMLEFT", 0, 0)
          parts[3]:SetWidth(8)
          parts[3]:SetPoint("TOPRIGHT", field, "TOPRIGHT", 0, 0)
          parts[3]:SetPoint("BOTTOMRIGHT", field, "BOTTOMRIGHT", 0, 0)
          parts[2]:SetPoint("TOPLEFT", parts[1], "TOPRIGHT", 0, 0)
          parts[2]:SetPoint("BOTTOMRIGHT", parts[3], "BOTTOMLEFT", 0, 0)
        end)

        box.parts = parts

        return box
      end,
    },
  },
})
