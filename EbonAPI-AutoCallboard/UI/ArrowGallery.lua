local Core = AutoCallboardCore
local Skin = AutoCallboardSkin
local RT = AutoCallboardRuntime

local WINDOW_NAME = "AutoCallboardArrowGallery"
local COLUMNS = 5
local TILE_W = 112
local TILE_H = 124
local TILE_GAP = 8
local FOOTER = 22
local PREVIEW_W = 100
local PREVIEW_H = 90
local PREVIEW_TOP = 6
local REFRESH_INTERVAL = 0.05

local gallery
local tiles = {}
local elapsedSince = 0

local function ApplySkin(id)
  local appearance = RT.state and RT.state.appearance

  if not appearance then
    return
  end

  appearance.arrowSkin = Core.sanitizeArrowSkin(id)
  RT.TouchState()
  RT.OnArrowSkinChanged()
  RT.RefreshArrowGallery()
end

function RT.BuildArrowTile(parent, skin, options)
  options = options or {}

  local boxWidth = options.boxWidth or PREVIEW_W
  local boxHeight = options.boxHeight or PREVIEW_H
  local top = options.bare and 0 or PREVIEW_TOP

  local tile = CreateFrame("Button", options.name, parent)
  local surface = tile

  if options.bare then
    tile:SetWidth(boxWidth)
    tile:SetHeight(boxHeight)
    tile:EnableMouse(false)
  else
    tile:SetWidth(TILE_W)
    tile:SetHeight(TILE_H)
    surface = Skin.Backdrop(tile)
  end

  tile.skin = skin

  if skin.kind == "model" then
    tile.model = CreateFrame("PlayerModel", nil, tile)
    tile.model:SetFrameLevel(surface:GetFrameLevel() + 1)
    tile.model:SetWidth(boxWidth)
    tile.model:SetHeight(boxHeight)
    tile.model:SetPoint("TOP", tile, "TOP", 0, -top)
    tile.model:SetScript("OnShow", function(self)
      RT.DressArrowModel(self, skin)

      if tile.angle then
        RT.PaintArrowTile(tile, tile.angle)
      end
      end)
    RT.DressArrowModel(tile.model, skin)
  else
    local width, height = RT.ArrowSheetSize(boxWidth)
    tile.texture = surface:CreateTexture(nil, "ARTWORK")
    tile.texture:SetTexture(RT.ArrowSheetTexture())
    tile.texture:SetWidth(width)
    tile.texture:SetHeight(height)
    tile.texture:SetPoint("CENTER", tile, "TOP", 0, -(top + boxHeight / 2))
    Skin.ApplyColor(tile.texture, "SetVertexColor", "checked")
  end

  if not options.bare then
    tile.label = surface:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tile.label:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 4, 6)
    tile.label:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -4, 6)
    tile.label:SetJustifyH("CENTER")
    RT.Localized(tile.label, skin.labelKey)
  end

  if options.pick then
    tile:RegisterForClicks("LeftButtonUp")
    tile:SetScript("OnClick", function(self)
      options.pick(self.skin.id)
      end)
    tile:SetScript("OnEnter", function(self)
      Skin.Highlight(self.acbBox, "hover")
      end)
    tile:SetScript("OnLeave", function(self)
      Skin.Highlight(self.acbBox, self.selected and "drop" or nil)
      end)
  end

  return tile
end

function RT.PaintArrowTile(tile, angle)
  if type(tile) ~= "table" then
    return
  end

  tile.angle = angle

  if tile.model then
    local facing = Core.arrowModelFacing(tile.skin, angle)

    tile.model:SetFacing(facing)

    if tile.skin.pivot then
      tile.model:SetPosition(Core.arrowModelOffset(tile.skin, facing))
    end
  elseif tile.texture then
    RT.PaintArrowSheet(tile.texture, angle)
  end
end

local function BuildTile(index)
  local skin = Core.arrowSkinAt(index)

  local tile = RT.BuildArrowTile(gallery.content, skin, {
    name = WINDOW_NAME .. "Tile" .. index,
    pick = ApplySkin,
  })

  local column = math.fmod(index - 1, COLUMNS)
  local row = math.floor((index - 1) / COLUMNS)

  tile:SetPoint("TOPLEFT", gallery.content, "TOPLEFT",
    column * (TILE_W + TILE_GAP),
    -(row * (TILE_H + TILE_GAP)))

  return tile
end

function RT.RefreshArrowGallery()
  if not gallery then
    return
  end

  local appearance = RT.state and RT.state.appearance
  local current = appearance and appearance.arrowSkin or Core.ARROW_SKIN_DEFAULT

  for i = 1, #(tiles) do
    local tile = tiles[i]
    tile.selected = tile.skin.id == current
    Skin.Highlight(tile.acbBox, tile.selected and "drop" or nil)
  end
end

function RT.UpdateArrowGalleryAngles()
  if not gallery or not gallery:IsShown() then
    return
  end

  local angle = RT.RouteArrowPreviewAngle()

  for i = 1, #(tiles) do
    RT.PaintArrowTile(tiles[i], angle)
  end
end

function RT.CreateArrowGallery()
  if gallery then
    return gallery
  end

  local count = Core.arrowSkinCount()
  local rows = math.ceil(count / COLUMNS)

  gallery = Skin.Window(WINDOW_NAME, {
    width = COLUMNS * TILE_W + (COLUMNS - 1) * TILE_GAP,
    height = rows * TILE_H + (rows - 1) * TILE_GAP + FOOTER,
    titleKey = "ARROW_GALLERY_TITLE",
    movable = true,
    point = { "CENTER", UIParent, "CENTER", 0, 0 },
  })

  RT.arrowGallery = gallery

  gallery.hint = gallery.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  gallery.hint:SetPoint("BOTTOMLEFT", gallery.content, "BOTTOMLEFT", 0, 0)
  gallery.hint:SetPoint("BOTTOMRIGHT", gallery.content, "BOTTOMRIGHT", 0, 0)
  gallery.hint:SetJustifyH("LEFT")
  RT.Localized(gallery.hint, "ARROW_GALLERY_HINT")
  Skin.MutedText(gallery.hint)

  for i = 1, count do
    tiles[i] = BuildTile(i)
  end

  gallery:SetScript("OnUpdate", function(_, delta)
    elapsedSince = elapsedSince + (delta or 0)

    if elapsedSince < REFRESH_INTERVAL then
      return
    end

    elapsedSince = 0
    RT.UpdateArrowGalleryAngles()
    end)

  gallery:Hide()

  return gallery
end

function RT.ToggleArrowGallery()
  if not gallery then
    RT.CreateArrowGallery()
  end

  if gallery:IsShown() then
    gallery:Hide()
    return
  end

  gallery:Show()
  RT.RefreshArrowGallery()
  RT.UpdateArrowGalleryAngles()

  if gallery.Raise then
    gallery:Raise()
  end
end
