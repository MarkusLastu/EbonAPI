EbonAPI:RegisterSkin("Split", {
  parent = "AutoCallboard",

  windows = {
    detach = { nav = true, pages = true },
    snap = 16,
  },

  header = {
    controls = "LEFT",
  },

  widgets = {
    -- Saves: like AutoCallboard, but the detail drawer docks at the bottom of the panel.
    saves = { view = "list", detail = "dock", row = { frame = "SMALL", fill = "card", border = "borderDim" } },
  },
})
