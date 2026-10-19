local Core = AutoCallboardCore

local DEFAULT = { goldTotal = true, goldLast = true, goldCurrent = true, goldSession = false, goldMain = false,
  arrowScale = 1, arrowFont = 10, arrowSkin = "sheet" }
local LIMIT = { arrowScale = {0.25, 2} }
local ARROW_FONT_SIZES = { 8, 9, 10, 11, 12, 14, 16, 18, 20 }

Core.ARROW_FONT_SIZES = ARROW_FONT_SIZES

function Core.isArrowFontSize(size)
  for _, known in ipairs(ARROW_FONT_SIZES) do
    if size == known then return true end
  end
  return false
end

function Core.copyAppearance(source)
  local result = {}
  source = type(source) == 'table' and source or {}
  for key, default in pairs(DEFAULT) do
    local given = source[key]
    local value, limit = given, LIMIT[key]
    if type(value) ~= type(default) or (limit and (value ~= value or value < limit[1] or value > limit[2])) then value = default end
    if key == 'arrowSkin' then
      value = Core.sanitizeArrowSkin(value) or default
    elseif key == 'arrowFont' then
      if not Core.isArrowFontSize(value) then value = default end
    end
    if given ~= nil and value ~= given and not (key == 'arrowSkin' and type(given) == 'string') then
      Core.repaired("STATE.REPAIRED", { field = key, setting = key, value = tostring(given) }, given)
    end
    result[key] = value
  end
  return result
end

function Core.copyToolbar(source)
  if type(source) ~= "table" then
    if source ~= nil then
      Core.repaired("STATE.REPAIRED", { field = "toolbar", setting = "toolbar", value = type(source) }, source)
    end
    return {1, 2, 3, 4, 5, 6}
  end
  local result, seen, given = {}, {}, {}
  for i = 1, 13 do
    local id = source[i]
    if id ~= nil then given[#given + 1] = tostring(id) end
    if type(id) == "number" and id == math.floor(id) and id >= 1 and id <= 13 and not seen[id] then
      result[#result + 1], seen[id] = id, true
    end
  end
  if #result < #given then
    Core.repaired("STATE.REPAIRED", { field = "toolbar", setting = "toolbar", value = table.concat(given, ",") }, source)
  end
  return result
end
