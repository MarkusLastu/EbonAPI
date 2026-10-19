local Core = AutoCallboardCore
local Skin = AutoCallboardSkin
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime

local WINDOW_NAME = "AutoCallboardRouteArrow"
local ARROW_TEXTURE = [[Interface\AddOns\EbonAPI-AutoCallboard\Media\Arrow]]

local SHEET_W = 2048
local SHEET_H = 1024
local COLUMNS = 10
local CELL_W = 200
local CELL_H = 152
local STORED_FRAMES = 60
local ARROW_W = 100
local ARROW_H = 76

local MODEL_W = 142
local MODEL_H = 134

local WIDGET_W = 176
local BASE_FONT = 10
local LINE_PAD = 6
local TEXT_GAP = 2
local REFRESH_INTERVAL = 0.05
local ARRIVED_YARDS = 12
local ARRIVED_FLYING_YARDS = 45
local TWO_PI = math.pi * 2

local CurrentSkin

local arrowFrame
local target
local activeTile
local elapsedSince = 0

CurrentSkin = function()
  local appearance = RT.state and RT.state.appearance

  return Core.findArrowSkin(appearance and appearance.arrowSkin or Core.ARROW_SKIN_DEFAULT)
end

RT.CurrentArrowSkin = CurrentSkin

function RT.LayoutRouteArrow()
  if not arrowFrame then
    return false
  end

  local appearance = RT.state and RT.state.appearance

  if type(appearance) ~= "table" then
    appearance = {}
  end

  local arrowScale = tonumber(appearance.arrowScale) or 1
  local font = tonumber(appearance.arrowFont) or BASE_FONT
  local line = font + LINE_PAD
  local width = math.max(MODEL_W * arrowScale, WIDGET_W * font / BASE_FONT)

  arrowFrame.shape:SetScale(arrowScale)

  for _, text in ipairs({ arrowFrame.status, arrowFrame.label }) do
    Skin.Font(text, font)
    text:SetWidth(width)
    text:SetHeight(line)
  end

  arrowFrame:SetWidth(width)
  arrowFrame:SetHeight(MODEL_H * arrowScale + TEXT_GAP + 2 * line)

  return true
end

function RT.IsRouteArrowOverhead(yards, flying)
  local limit = flying and ARRIVED_FLYING_YARDS or ARRIVED_YARDS

  return (tonumber(yards) or 0) <= limit
end

function RT.RouteArrowRotation(bearing, facing)
  local angle = (bearing or 0) + (facing or 0)

  angle = math.fmod(angle, TWO_PI)

  if angle < 0 then
    angle = angle + TWO_PI
  end

  return angle
end

function RT.RouteArrowFrame(angle)
  local turn = math.fmod(angle or 0, TWO_PI)

  if turn < 0 then
    turn = turn + TWO_PI
  end

  local mirrored = turn > math.pi
  local half = mirrored and (TWO_PI - turn) or turn
  local cell = math.floor(half / math.pi * (STORED_FRAMES - 1) + 0.5)

  if cell < 0 then
    cell = 0
  end

  if cell > STORED_FRAMES - 1 then
    cell = STORED_FRAMES - 1
  end

  return cell, mirrored
end

function RT.PaintArrowSheet(texture, angle)
  local cell, mirrored = RT.RouteArrowFrame(angle)
  local column = math.fmod(cell, COLUMNS)
  local row = math.floor(cell / COLUMNS)

  local left = (column * CELL_W) / SHEET_W
  local right = ((column + 1) * CELL_W) / SHEET_W
  local top = (row * CELL_H) / SHEET_H
  local bottom = ((row + 1) * CELL_H) / SHEET_H

  if mirrored then
    left, right = right, left
  end

  texture:SetTexCoord(left, right, top, bottom)
end

function RT.ArrowSheetTexture()
  return ARROW_TEXTURE
end

function RT.ArrowSheetSize(boxWidth)
  local ratio = (tonumber(boxWidth) or MODEL_W) / MODEL_W

  return ARROW_W * ratio, ARROW_H * ratio
end

function RT.RouteArrowBearing(fromX, fromY, toX, toY)
  local dx, dy = toX - fromX, toY - fromY

  if dx == 0 and dy == 0 then
    return nil, 0
  end

  local distance = math.sqrt(dx * dx + dy * dy)

  return math.atan2(-dx, dy), distance
end

function RT.DressArrowModel(model, skin)
  if not model or type(skin) ~= "table" or skin.kind ~= "model" then
    return false
  end

  pcall(model.ClearModel, model)
  local loaded, detail = pcall(model.SetModel, model, skin.path)

  pcall(model.SetModelScale, model, Core.arrowModelScale(skin))

  if not loaded then
    local problem = RT.api:Problem("ARROW.MODEL_LOAD_FAILED", {
      skin = tostring(skin.id),
      path = tostring(skin.path),
      detail = tostring(detail),
    })

    RT.api:Report(problem)

    return nil, problem
  end

  return true
end

function RT.RouteArrowPreviewAngle()
  local facing = GetPlayerFacing and GetPlayerFacing() or 0

  if not target then
    return RT.RouteArrowRotation(0, facing)
  end

  local map, x, y = RT.ReadPlayerMapPoint()
  local here = map and RT.WorldPointFor(map, x, y)
  local there = RT.WorldPointFor(target.map, target.x, target.y)

  if not here or not there or here.map ~= there.map then
    return RT.RouteArrowRotation(0, facing)
  end

  local bearing = RT.RouteArrowBearing(here.x, here.y, there.x, there.y)

  if not bearing then
    return RT.RouteArrowRotation(0, facing)
  end

  return RT.RouteArrowRotation(bearing, facing)
end

function RT.RouteArrowTile()
  return activeTile
end

function RT.HideRouteArrowShape()
  if activeTile then
    activeTile:Hide()
  end
end

function RT.ShowRouteArrowTile(skin)
  if not arrowFrame or type(skin) ~= "table" then
    return nil
  end

  arrowFrame.tiles = arrowFrame.tiles or {}

  local tile = arrowFrame.tiles[skin.id]

  if not tile then
    tile = RT.BuildArrowTile(arrowFrame.shape, skin, { bare = true, boxWidth = MODEL_W, boxHeight = MODEL_H })
    tile:SetPoint("TOP", arrowFrame.shape, "TOP", 0, 0)
    arrowFrame.tiles[skin.id] = tile
  end

  if activeTile and activeTile ~= tile then
    activeTile:Hide()
  end

  activeTile = tile
  tile:Show()

  return tile
end

function RT.OnArrowSkinChanged()
  if arrowFrame and arrowFrame.tiles then
    for _, tile in pairs(arrowFrame.tiles) do
      tile:Hide()
    end
  end

  activeTile = nil

  if arrowFrame and RT.GetRouteArrowTarget() then
    RT.UpdateRouteArrow(true)
  end
end

function RT.GetRouteArrowTarget()
  return target
end

function RT.ClearRouteArrowTarget()
  target = nil

  if arrowFrame then
    arrowFrame:Hide()
  end
end

local function StepFacts(step)
  local active = RT.GetActiveRoute and RT.GetActiveRoute()
  local facts = { route = "?", position = "?" }

  if type(active) == "table" then
    facts.route = tostring(active.name or "?")

    for index, candidate in ipairs(active.steps or {}) do
      if candidate == step then
        facts.position = tostring(index)
        break
      end
    end
  end

  return facts
end

function RT.SetRouteArrowTarget(step, action)
  if type(step) ~= "table" or not step.map or step.map == "" or not step.x or not step.y then
    RT.ClearRouteArrowTarget()

    local facts = StepFacts(step)

    RT.api:Report(RT.api:Problem("ARROW.NO_COORDINATES", facts))
    return false
  end

  local point = RT.WorldPointFor(step.map, step.x, step.y)

  if not point then
    RT.ClearRouteArrowTarget()

    local facts = StepFacts(step)

    facts.map = tostring(step.map)
    RT.api:Report(RT.api:Problem("ARROW.UNKNOWN_ZONE", facts))
    return false
  end

  target = {
    map = step.map,
    x = step.x,
    y = step.y,
    step = step,
    action = action,
  }

  RT.CreateRouteArrow()
  RT.RefreshRouteArrowLabel()
  RT.UpdateRouteArrow(true)
  arrowFrame:Show()

  return true
end

function RT.UpdateRouteArrow(force)
  if not arrowFrame or not target then
    return
  end

  if IsInInstance and IsInInstance() then
    arrowFrame.status:SetText(L.ROUTE_ARROW_INSTANCE)
    RT.HideRouteArrowShape()
    return
  end

  local map, x, y = RT.ReadPlayerMapPoint()

  if not map then
    arrowFrame.status:SetText(L.ROUTE_ARROW_NO_POSITION)
    RT.HideRouteArrowShape()
    return
  end

  local here = RT.WorldPointFor(map, x, y)
  local there = RT.WorldPointFor(target.map, target.x, target.y)

  if not here or not there then
    arrowFrame.status:SetText(L.ROUTE_ARROW_UNKNOWN_SPOT)
    RT.HideRouteArrowShape()
    return
  end

  if here.map ~= there.map then
    arrowFrame.status:SetText(L.ROUTE_ARROW_FAR)
    RT.HideRouteArrowShape()
    return
  end

  local bearing, distance = RT.RouteArrowBearing(here.x, here.y, there.x, there.y)
  local yards = math.floor(distance + 0.5)
  local flying = IsFlying and IsFlying() and true or false
  local overhead = RT.IsRouteArrowOverhead(yards, flying)

  if overhead and not flying then
    arrowFrame.status:SetText(L.ROUTE_ARROW_ARRIVED)
    RT.HideRouteArrowShape()
    return
  end

  local facing = GetPlayerFacing and GetPlayerFacing() or nil

  if not facing or not bearing then
    arrowFrame.status:SetText(flying and string.format(L.ROUTE_ARROW_DESCEND, tostring(yards))
      or L.ROUTE_ARROW_NO_FACING)
    RT.HideRouteArrowShape()
    return
  end

  arrowFrame.status:SetText(overhead
    and string.format(L.ROUTE_ARROW_DESCEND, tostring(yards))
    or string.format(L.ROUTE_ARROW_DISTANCE, tostring(yards)))

  local tile = RT.ShowRouteArrowTile(CurrentSkin())

  if tile then
    RT.PaintArrowTile(tile, RT.RouteArrowRotation(bearing, facing))
  end
end

function RT.CreateRouteArrow()
  if arrowFrame then
    return arrowFrame
  end

  arrowFrame = Skin.Window(WINDOW_NAME, {
    movable = true,
    noEsc = true,
    strata = "HIGH",
    bare = true,
  })

  RT.routeArrow = arrowFrame

  arrowFrame.shape = CreateFrame("Frame", nil, arrowFrame)
  arrowFrame.shape:SetWidth(MODEL_W)
  arrowFrame.shape:SetHeight(MODEL_H)
  arrowFrame.shape:SetPoint("TOP", arrowFrame, "TOP", 0, 0)

  local function Line(anchor, gap, paint)
    local line = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line:SetPoint("TOP", anchor, "BOTTOM", 0, -gap)
    line:SetJustifyH("CENTER")
    paint(line)

    return line
  end

  arrowFrame.status = Line(arrowFrame.shape, TEXT_GAP, Skin.HeadingText)
  arrowFrame.label = Line(arrowFrame.status, 0, Skin.MutedText)

  arrowFrame:SetScript("OnUpdate", function(_, delta)
    elapsedSince = elapsedSince + (delta or 0)

    if elapsedSince < REFRESH_INTERVAL then
      return
    end

    elapsedSince = 0
    RT.UpdateRouteArrow()
    end)

  arrowFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
  RT.LayoutRouteArrow()
  RT.RefreshRouteArrowLock()
  arrowFrame:Hide()

  return arrowFrame
end

function RT.RefreshRouteArrowLock()
  if arrowFrame then
    arrowFrame:EnableMouse(not RT.IsInterfaceLocked())
  end
end

function RT.RefreshRouteArrowLabel()
  if arrowFrame and target then
    arrowFrame.label:SetText(target.action and Core.routeActionLine(target.action) or Core.routeStepLine(target.step))
  end
end
