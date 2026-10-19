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
})
