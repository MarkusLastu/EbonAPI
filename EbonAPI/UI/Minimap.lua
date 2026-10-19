EbonAPI = EbonAPI or {}
EbonAPI.MinimapButtons = {}

local Buttons = EbonAPI.MinimapButtons
local Lib = EbonAPI.Lib
local Kit = EbonAPI.Kit
local Bricks = EbonAPI.Bricks
local Parameters = EbonAPI.Parameters
local Skins = EbonAPI.Skins
local Version = EbonAPI.Version
local Problems = EbonAPI.Problems
local Window = EbonAPI.Window
local Handle = EbonAPI.Handle
local L = EbonAPI.L

local type, pairs, ipairs, pcall, tostring, error = type, pairs, ipairs, pcall, tostring, error
local floor, ceil, max, min, sqrt, sin, cos, atan2, deg, rad =
  math.floor, math.ceil, math.max, math.min, math.sqrt, math.sin, math.cos, math.atan2, math.deg, math.rad
local format, lower, sort = string.format, string.lower, table.sort

local S = Skins.value
local evaluate = Kit.evaluate

local OWNER = "EbonAPI"
local DISPLAYS = { BUTTON = true, GROUP = true, HIDDEN = true }
local UNSUPPORTED = { "width", "height", "point", "disabled" }

-- Quadrants where the minimap is round, by the shape name minimap addons return from
-- GetMinimapShape (the table of LibDBIcon-1.0). Quadrant 1 is bottom right, then bottom left,
-- top right, top left.
local SHAPES = {
  ROUND = { true, true, true, true },
  SQUARE = { false, false, false, false },
  ["CORNER-TOPLEFT"] = { false, false, false, true },
  ["CORNER-TOPRIGHT"] = { false, false, true, false },
  ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
  ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
  ["SIDE-LEFT"] = { false, true, false, true },
  ["SIDE-RIGHT"] = { true, false, true, false },
  ["SIDE-TOP"] = { false, false, true, true },
  ["SIDE-BOTTOM"] = { true, true, false, false },
  ["TRICORNER-TOPLEFT"] = { false, true, true, true },
  ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
  ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
  ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local buttons = {}
local members = {}
local group = nil
local flyout = nil
local selfBroker = nil

local function held(owner)
  local data = Kit.saved(owner)

  if not data then
    return nil
  end

  if type(data.minimap) ~= "table" then
    data.minimap = { angle = type(data.minimap) == "number" and data.minimap or nil }
  end

  return data.minimap
end

local function addonDisplay(button)
  if evaluate(button, button.spec.hidden) then
    return "HIDDEN"
  end

  return button.spec.display or "BUTTON"
end

local function displayOf(button)
  local data = held(button.owner)

  return data and data.display or addonDisplay(button)
end

function Buttons.isLocked(owner)
  local data = held(owner)

  if Parameters.value(nil, "locked") then
    return true
  end

  return data and data.locked or false
end

local function angleOf(button)
  local data = held(button.owner)
  local default = button == group and S("kit.minimap.group.angle") or S("kit.minimap.angle")

  return data and data.angle or button.angle or button.spec.angle or default
end

local function place(button, angle)
  local frame = button:GetParent()
  local radians = rad(angle)
  local x, y, quadrant = cos(radians), sin(radians), 1

  if x < 0 then
    quadrant = quadrant + 1
  end

  if y > 0 then
    quadrant = quadrant + 2
  end

  local shape = SHAPES[type(GetMinimapShape) == "function" and GetMinimapShape() or "ROUND"] or SHAPES.ROUND
  local offset = S("kit.minimap.offset")
  local width, height = frame:GetWidth() / 2 + offset, frame:GetHeight() / 2 + offset

  if shape[quadrant] then
    x, y = x * width, y * height
  else
    local corner = S("kit.minimap.corner")

    x = max(-width, min(x * (width * sqrt(2) - corner), width))
    y = max(-height, min(y * (height * sqrt(2) - corner), height))
  end

  button:ClearAllPoints()
  button:SetPoint("CENTER", frame, "CENTER", x, y)
end

local function dock(button, parent)
  if button:GetParent() ~= parent then
    button:SetParent(parent)
  end

  if parent == flyout then
    button:SetFrameStrata(flyout:GetFrameStrata())
    button:SetFrameLevel(flyout:GetFrameLevel() + 1)
  else
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
  end
end

local function titleOf(button)
  local text = button ~= group and Kit.textOf(button)

  if text then
    return text
  end

  return EbonAPI.Settings.addonTitle(button.owner)
end

local function scopeOf(button)
  if button ~= group and button.owner ~= OWNER then
    return button.owner
  end
end

local function describe(button, tooltip)
  local lines = Kit.lines(tooltip)
  local latest = Version.available(button.owner)
  local count = Problems.summary(scopeOf(button), "badge").count

  if latest then
    lines:Add(format(L.UI_ADDON_UPDATE, latest), "heading")
  end

  if count > 0 then
    lines:Add(count == 1 and L.MINIMAP_PROBLEM_ONE or format(L.MINIMAP_PROBLEMS, count), "text")
  end

  if button == group then
    if #members > 0 then
      lines:Add(L.MINIMAP_HINT_GROUP, "muted")
      lines:Add(L.MINIMAP_HINT_WINDOW, "muted")
    else
      lines:Add(L.MINIMAP_HINT_OPEN, "muted")
    end

    return
  end

  local spec = button.spec
  local body = spec.tipKey and Kit.localized(button.owner, spec.tipKey) or (type(spec.tip) == "string" and spec.tip)

  if body then
    lines:Add(body, "text", true)
  end

  if type(spec.tip) == "function" then
    local ok, err = pcall(spec.tip, lines, button)

    if not ok then
      Lib.report(err)
    end
  end
end

local function showTip(button)
  Bricks.tip(button, titleOf(button))

  if GameTooltip then
    describe(button, GameTooltip)
    GameTooltip:Show()
  end
end

local function follow(button)
  local frame = button:GetParent()
  local mx, my = frame:GetCenter()
  local x, y = GetCursorPosition()
  local scale = frame:GetEffectiveScale() or 1

  button:SetAngle(deg(atan2(y / scale - my, x / scale - mx)))
end

local function build(owner)
  local button = CreateFrame("Button", owner .. "MinimapButton", Minimap)

  button.owner = owner
  button:SetWidth(S("kit.minimap.size"))
  button:SetHeight(S("kit.minimap.size"))
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints(button)
  Kit.trim(button.icon)
  Bricks.create("minimap", button)
  dock(button, Minimap)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")

  function button:SetAngle(value)
    if type(value) ~= "number" then
      error(format("EbonAPI: %s: button:SetAngle expects a number, got %s", self.owner, tostring(value)), 2)
    end

    local data = held(self.owner)

    self.angle = value

    if data then
      data.angle = value
    end

    if self:GetParent() == Minimap then
      place(self, value)
    end

    return self
  end

  button:SetScript("OnDragStart", function(self)
    if self:GetParent() ~= Minimap or Buttons.isLocked(self.owner) then
      return
    end

    Bricks.hideTip()
    self:SetScript("OnUpdate", follow)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  button:SetScript("OnEnter", showTip)
  button:SetScript("OnLeave", Bricks.hideTip)

  return button
end

local function badgeOf(button)
  local summary = Problems.summary(scopeOf(button), "badge")

  if summary.count > 0 then
    return summary.count, summary.severe and "danger" or "caution"
  end

  if button == group then
    if Version.available(OWNER) then
      return true
    end

    for _, member in ipairs(members) do
      if member.badgeValue then
        return true
      end
    end

    return nil
  end

  local value = evaluate(button, button.spec.badge)

  if value ~= nil and value ~= false and value ~= "" then
    return value
  end

  return Version.available(button.owner) and true or nil
end

local function refreshBadge(button)
  local value, color = badgeOf(button)

  button.badgeValue = value
  button:SetBadge(value, color)
end

local function refresh(button)
  local icon

  if button == group then
    icon = Bricks.media("icon")
  else
    icon = Lib.icon(evaluate(button, button.spec.icon)) or EbonAPI:AddonIcon(button.owner) or Bricks.media("addonIcon")
  end

  button.iconPath = icon
  button.icon:SetTexture(icon)
  refreshBadge(button)

  if button.broker then
    button.broker.icon = icon
  end
end

local function ensureFlyout()
  if not flyout then
    flyout = CreateFrame("Frame", nil, UIParent)
    flyout:SetFrameStrata("HIGH")
    flyout:SetClampedToScreen(true)
    Bricks.frame(flyout, "small", "bg", "border")
    flyout:Hide()
  end

  return flyout
end

local function anchorFlyout()
  local x, y = group:GetCenter()
  local scale = group:GetEffectiveScale() or 1
  local screen = UIParent:GetEffectiveScale() or 1
  local vertical = (y or 0) * scale > UIParent:GetHeight() * screen / 2 and "TOP" or "BOTTOM"
  local horizontal = (x or 0) * scale > UIParent:GetWidth() * screen / 2 and "RIGHT" or "LEFT"
  local opposite = (vertical == "TOP" and "BOTTOM" or "TOP") .. (horizontal == "RIGHT" and "LEFT" or "RIGHT")

  flyout:ClearAllPoints()
  flyout:SetPoint(vertical .. horizontal, group, opposite, 0, 0)
end

local function arrange()
  local frame = ensureFlyout()
  local size, spacing, pad = S("kit.minimap.size"), S("kit.spacing"), S("kit.padding")
  local columns = max(1, min(S("kit.minimap.group.columns"), #members))
  local rows = max(1, ceil(#members / columns))

  for index, button in ipairs(members) do
    local column, row = (index - 1) % columns, floor((index - 1) / columns)

    dock(button, frame)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + column * (size + spacing), -(pad + row * (size + spacing)))
    button:Show()
  end

  frame:SetWidth(pad * 2 + columns * size + (columns - 1) * spacing)
  frame:SetHeight(pad * 2 + rows * size + (rows - 1) * spacing)
end

local function byOwner(a, b)
  return lower(a.owner) < lower(b.owner)
end

local function groupClick(_, mouse)
  if mouse == "RightButton" or #members == 0 then
    Window.toggle()
    return
  end

  Buttons.toggleGroup()
end

local function ensureGroup()
  if not group then
    group = build(OWNER)
    group.spec = {}
    group:SetScript("OnClick", groupClick)
    Kit.adopt(group, OWNER, "minimap", group.spec)
  end

  return group
end

function Buttons.layout()
  for index = #members, 1, -1 do
    members[index] = nil
  end

  for _, button in pairs(buttons) do
    local display = displayOf(button)

    if display == "GROUP" then
      members[#members + 1] = button
    else
      dock(button, Minimap)
      place(button, angleOf(button))

      Lib.setShown(button, display ~= "HIDDEN")
    end
  end

  sort(members, byOwner)

  local data = held(OWNER)

  if #members == 0 and not (data and data.display == "BUTTON") then
    if group then
      group:Hide()
    end

    if flyout then
      flyout:Hide()
    end

    return
  end

  ensureGroup()
  refresh(group)
  dock(group, Minimap)
  place(group, angleOf(group))
  group:Show()
  arrange()

  if #members == 0 then
    flyout:Hide()
  elseif flyout:IsShown() then
    anchorFlyout()
  end
end

function Buttons.toggleGroup()
  if not group or not group:IsShown() or #members == 0 then
    return false
  end

  if flyout:IsShown() then
    flyout:Hide()
    return false
  end

  anchorFlyout()
  flyout:Show()

  return true
end

local function brokerLibrary()
  local stub = _G.LibStub

  if type(stub) ~= "table" then
    return nil
  end

  return stub("LibDataBroker-1.1", true)
end

local function publish(button)
  if button.broker ~= nil then
    return
  end

  local broker = brokerLibrary()

  if not broker then
    return
  end

  button.broker = broker:NewDataObject(button.owner, {
    type = "launcher",
    label = button.owner,
    icon = button.iconPath,
    OnClick = function(frame, mouse)
      Kit.click(button, mouse, frame)
    end,
    OnTooltipShow = function(tooltip)
      Kit.lines(tooltip):Add(titleOf(button), "heading")
      describe(button, tooltip)
    end,
  }) or false
end

local function publishSelf()
  if selfBroker ~= nil then
    return
  end

  local broker = brokerLibrary()

  if not broker then
    return
  end

  selfBroker = broker:NewDataObject(OWNER, {
    type = "launcher",
    label = OWNER,
    icon = Bricks.media("icon"),
    OnClick = function()
      Window.toggle()
    end,
    OnTooltipShow = function(tooltip)
      local lines = Kit.lines(tooltip)
      local latest = Version.available(OWNER)

      lines:Add(EbonAPI.Settings.addonTitle(OWNER), "heading")

      if latest then
        lines:Add(format(L.UI_ADDON_UPDATE, latest), "heading")
      end

      lines:Add(L.MINIMAP_HINT_OPEN, "muted")
    end,
  }) or false
end

local function memberClick(self, mouse)
  Kit.click(self, mouse)

  if flyout and self:GetParent() == flyout and mouse ~= "RightButton" then
    flyout:Hide()
  end
end

function Buttons.create(owner, spec)
  local button = buttons[owner]

  if button then
    button.spec = spec

    return button:Refresh()
  end

  button = build(owner)
  button.kitOwnTip = true
  button:SetScript("OnClick", memberClick)

  function button:Refresh()
    refresh(self)
    Buttons.layout()

    return self
  end

  Kit.adopt(button, owner, "minimap", spec)
  button.kitTop = true
  buttons[owner] = button
  refresh(button)
  publish(button)
  Buttons.layout()

  return button
end

function Buttons.refreshAll()
  for _, button in pairs(buttons) do
    refresh(button)
  end

  Buttons.layout()
end

local function problemsChanged(_, addon)
  local button = buttons[addon]

  if button then
    refreshBadge(button)
  end

  if group then
    refreshBadge(group)
  end
end

EbonAPI:On("PROBLEM", problemsChanged)
EbonAPI:On("PROBLEM_CLOSED", problemsChanged)

function Buttons.has(owner)
  return buttons[owner] ~= nil
end

function Buttons.get(owner)
  return buttons[owner]
end

function Buttons.group()
  return group
end

function Buttons.flyout()
  return flyout
end

function Buttons.members()
  return members
end

function Buttons.display(owner)
  local button = buttons[owner]

  return button and displayOf(button)
end

function Buttons.setDisplay(owner, value)
  local button = buttons[owner]
  local data = held(owner)

  if not button or not data or not DISPLAYS[value] then
    return false
  end

  if value == addonDisplay(button) then
    value = nil
  end

  data.display = value
  Buttons.layout()

  return true
end

function Buttons.alwaysShown()
  local data = held(OWNER)

  return data and data.display == "BUTTON" or false
end

function Buttons.setAlwaysShown(value)
  local data = held(OWNER)

  if not data then
    return false
  end

  data.display = value and "BUTTON" or nil
  Buttons.layout()

  return true
end

function Buttons.setLocked(owner, value)
  local data = held(owner)

  if not data then
    return false
  end

  data.locked = value and true or nil

  return true
end

function Buttons.reset(owner)
  local data = held(owner)

  if data then
    data.angle = nil
  end

  local button = owner == OWNER and group or buttons[owner]

  if button then
    button.angle = nil
  end

  Buttons.layout()
end

function Handle:MinimapButton(spec)
  if spec ~= nil and type(spec) ~= "table" then
    error(format("EbonAPI: %s: api:MinimapButton expects a table, got %s", self.addonName, type(spec)), 2)
  end

  spec = spec or {}

  if spec.display ~= nil and not DISPLAYS[spec.display] then
    error(format("EbonAPI: %s: api:MinimapButton display expects BUTTON, GROUP or HIDDEN, got %s",
      self.addonName, tostring(spec.display)), 2)
  end

  if spec.angle ~= nil and type(spec.angle) ~= "number" then
    error(format("EbonAPI: %s: api:MinimapButton angle expects a number, got %s",
      self.addonName, tostring(spec.angle)), 2)
  end

  for _, field in ipairs(UNSUPPORTED) do
    if spec[field] ~= nil then
      error(format("EbonAPI: %s: api:MinimapButton does not take %s, EbonAPI sets the size, place and state of the button",
        self.addonName, field), 2)
    end
  end

  return Buttons.create(self.addonName, spec)
end

function Buttons.publish()
  for _, button in pairs(buttons) do
    publish(button)
  end

  publishSelf()
end

EbonAPI:On("READY", function()
  Buttons.publish()
  Buttons.refreshAll()
end)

EbonAPI:On("UPDATE_AVAILABLE", function()
  Buttons.refreshAll()
end)
