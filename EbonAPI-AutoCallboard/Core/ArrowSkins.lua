local Core = AutoCallboardCore or {}
AutoCallboardCore = Core

local MODEL_HALF_TURN = math.pi

local MODEL_SCALE = 0.2144

local type, tonumber = type, tonumber

Core.ARROW_SKIN_DEFAULT = "sheet"

local SKINS = {
  { id = "sheet", kind = "sheet", labelKey = "ARROW_SKIN_SHEET" },
  { id = "arcane", kind = "model", labelKey = "ARROW_SKIN_ARCANE",
    path = [[SPELLS\ArcaneShot_Missile.m2]], scale = 18, facing = MODEL_HALF_TURN },
  { id = "frost", kind = "model", labelKey = "ARROW_SKIN_FROST",
    path = [[SPELLS\FrostShot_Missile.m2]], scale = 18, facing = MODEL_HALF_TURN },
  { id = "fireshot", kind = "model", labelKey = "ARROW_SKIN_FIRESHOT",
    path = [[SPELLS\FireShot_Missile.m2]], scale = 18, facing = MODEL_HALF_TURN },
  { id = "wood", kind = "model", labelKey = "ARROW_SKIN_WOOD",
    path = [[Item\ObjectComponents\AMMO\ArrowFlight_01.m2]], scale = 18, facing = MODEL_HALF_TURN, pivot = 0.73 },
  { id = "fire", kind = "model", labelKey = "ARROW_SKIN_FIRE",
    path = [[Item\ObjectComponents\AMMO\ArrowFireFlight_01.m2]], scale = 15, facing = MODEL_HALF_TURN, pivot = 0.62 },
  { id = "ice", kind = "model", labelKey = "ARROW_SKIN_ICE",
    path = [[Item\ObjectComponents\AMMO\ArrowIceFlight_01.m2]], scale = 12, facing = MODEL_HALF_TURN, pivot = 0.62 },
  { id = "acid", kind = "model", labelKey = "ARROW_SKIN_ACID",
    path = [[Item\ObjectComponents\AMMO\ArrowAcidFlight_01.m2]], scale = 15, facing = MODEL_HALF_TURN, pivot = 0.62 },
  { id = "magic", kind = "model", labelKey = "ARROW_SKIN_MAGIC",
    path = [[Item\ObjectComponents\AMMO\ArrowMagicFlight_01.m2]], scale = 15, facing = MODEL_HALF_TURN, pivot = 0.62 },
  { id = "cupid", kind = "model", labelKey = "ARROW_SKIN_CUPID",
    path = [[SPELLS\HOLIDAYS\Valentines_CupidsArrow_Missle.m2]], scale = 22.5, facing = MODEL_HALF_TURN, pivot = -0.25 },
}

Core.arrowSkins = SKINS

function Core.arrowSkinCount()
  return #(SKINS)
end

function Core.arrowSkinAt(index)
  index = tonumber(index)

  if not index then
    return SKINS[1]
  end

  index = math.floor(index + 0.5)

  if index < 1 then
    index = 1
  end

  if index > #(SKINS) then
    index = #(SKINS)
  end

  return SKINS[index]
end

function Core.arrowSkinIndex(id)
  for i = 1, #(SKINS) do
    if SKINS[i].id == id then
      return i
    end
  end

  return 1
end

function Core.findArrowSkin(id)
  return SKINS[Core.arrowSkinIndex(id)]
end

function Core.sanitizeArrowSkin(id)
  if type(id) == "string" then
    for i = 1, #(SKINS) do
      if SKINS[i].id == id then
        return id
      end
    end
  end

  if id ~= nil then
    Core.repaired("STATE.REPAIRED", { field = "arrowSkin", setting = "arrowSkin", value = tostring(id) }, id)
  end

  return Core.ARROW_SKIN_DEFAULT
end

function Core.arrowModelScale(skin)
  local base = (type(skin) == "table" and tonumber(skin.scale)) or 6

  return base * MODEL_SCALE
end

function Core.arrowModelOffset(skin, facing)
  local pivot = type(skin) == "table" and tonumber(skin.pivot)

  if not pivot then
    return nil
  end

  local reach = pivot * Core.arrowModelScale(skin)
  local turn = tonumber(facing) or 0

  return -reach * math.cos(turn), -reach * math.sin(turn), 0
end

function Core.arrowModelFacing(skin, angle)
  local offset = (type(skin) == "table" and tonumber(skin.facing)) or 0

  return offset - (tonumber(angle) or 0)
end
