local RT, Core, Skin, L = AutoCallboardRuntime, AutoCallboardCore, AutoCallboardSkin, AutoCallboardLocale
local buttons
local ACTIONS = {
  {"BUTTON_LISTS", "ToggleListsWindow"}, {"BUTTON_BUILDS", "ToggleBuildsWindow"},
  {"ADDON_NAME_TOOLTIP"}, {"BUTTON_START", "StartRolling"},
  {"BUTTON_SHARE", "ShareAcceptedQuest"}, {"BUTTON_QUESTS", "ShowQuestWindow"},
  {"BUTTON_EXPORT", "ShowQuestDataWindow", "export"}, {"BUTTON_IMPORT", "ShowQuestDataWindow", "import"},
  {"UI_ETERNALS", "ShowSettings", 1}, {"UI_HELP", "ShowAddonHelp", "about"},
  {"UI_SETTINGS", "ShowSettings"}, {"AUTO_CURRENT_INSTANCE_LABEL", "ToggleInstanceMode"},
  {"BUTTON_ROUTES", "ToggleRouteWindow"},
}
local PAGES = {"general", "appearance", "toolbar", "gold"}
local LOOK = {background = true, accent = true, scale = true, opacity = true, locked = true}
local ARROW_FIELDS = {"arrowScale", "arrowFont", "arrowSkin"}
local GOLD_FIELDS = {"goldMain", "goldTotal", "goldLast", "goldCurrent", "goldSession"}
local layoutWaiter, lookWaiting, setting
local RUN_SPEED = 7
local TOOLBAR_WRAP, TOOLBAR_GAP, STATUS_GAP, STATUS_ROOM, QUEST_GAP, QUEST_ROOM, GOLD_ROOM = 620, 5, 5, 20, 28, 528, 22
local speedText, speedShown

local function Config() return RT.state.appearance end
local function Character()
  local entry = RT.EnsureCharacterState()
  if not entry.toolbar then entry.toolbar = Core.copyToolbar() end
  return entry
end
local function Label(id) return id == 3 and "Callboard" or L[ACTIONS[id][1]] end
local function Invoke(id)
  local action = ACTIONS[id]
  if id == 4 and RT.IsRolling() then RT.StopRolling(L.ROLL_STOPPED)
  elseif action[2] then RT[action[2]](action[3]) end
end
function RT.ToggleInstanceMode()
  RT.SetField("autoCurrentInstanceQuest", not RT.state.autoCurrentInstanceQuest)
  if RT.state.autoCurrentInstanceQuest then RT.ShowAutoCurrentInstanceWarning() end
end

function RT.InterfaceParameter(name)
  return RT.api:GetParameter(name)
end
function RT.IsInterfaceLocked()
  return RT.InterfaceParameter("locked") and true or false
end

local goldTotal, goldLast, goldCurrent, goldSession, goldConfig
function RT.RefreshGoldDisplay()
  local text = RT.questGoldText
  if not text then return end
  local config, tracker = Config(), RT.GetGoldTrackerState()
  local current, session = RT.trackedQuestSpend or 0, RT.sessionGoldSpent or 0
  if goldTotal == tracker.totalSpent and goldLast == tracker.lastQuestSpent and goldCurrent == current
      and goldSession == session and goldConfig == config then return end
  goldTotal, goldLast, goldCurrent, goldSession, goldConfig = tracker.totalSpent, tracker.lastQuestSpent, current, session, config
  local parts = {}
  for _, item in ipairs({{"goldTotal", "UI_TOTAL", tracker.totalSpent}, {"goldLast", "UI_LAST", tracker.lastQuestSpent},
    {"goldCurrent", "UI_CURRENT", RT.trackedQuestSpend or 0}, {"goldSession", "UI_SESSION", RT.sessionGoldSpent or 0}}) do
    if config[item[1]] then parts[#parts + 1] = L[item[2]] .. ": " .. RT.FormatMoney(item[3]) end
  end
  text:SetText(table.concat(parts, "  |  "))
end

function RT.RefreshSpeedDisplay()
  if not speedText then return end
  if not RT.state.showSpeed then speedText:Hide(); return end
  speedText:Show()
  if not speedText:IsVisible() then return end
  local percent = math.floor(GetUnitSpeed("player") / RUN_SPEED * 100 + 0.5)
  if percent == speedShown then return end
  speedShown = percent
  speedText:SetText(string.format(L.SPEED_VALUE, percent))
end

local function PlaceGold()
  if Config().goldMain and not RT.questWindow then RT.CreateQuestWindow() end
  local text, frame = RT.questGoldText, RT.controlFrame
  if not text then return end
  text:SetParent(Config().goldMain and frame.content or RT.questWindow)
  text:ClearAllPoints()
  text:SetPoint("BOTTOMLEFT", text:GetParent(), "BOTTOMLEFT", Config().goldMain and 0 or 24, Config().goldMain and -1 or 32)
  text:SetWidth(Config().goldMain and Skin.WindowSize(frame) or 540)
  RT.RefreshGoldDisplay()
end

local function WidestText(fontString, ...)
  if not fontString then return 0 end
  local previous, widest = fontString:GetText(), 0
  for index = 1, select("#", ...) do
    fontString:SetText((select(index, ...)))
    widest = math.max(widest, fontString:GetStringWidth() or 0)
  end
  fontString:SetText(previous)
  return widest
end

local function CollapsedFloor()
  local status = WidestText(RT.summonStatusText,
    string.format(L.SUMMON_STATUS_ACTIVE, "0000s", "0000s"),
    string.format(L.SUMMON_STATUS_COOLDOWN, "0000s"),
    L.SUMMON_STATUS_READY)
  local speed = RT.state.showSpeed and WidestText(speedText, string.format(L.SPEED_VALUE, 888)) or 0
  local floor = status + (speed > 0 and speed + 12 or 0)

  if Config().goldMain and RT.questGoldText then
    floor = math.max(floor, RT.questGoldText:GetStringWidth() or 0)
  end

  return floor
end

function RT.LayoutMainToolbar()
  local frame = RT.controlFrame
  if not buttons then return end
  if InCombatLockdown() then
    if not layoutWaiter then
      layoutWaiter = true
      RT.api:AfterCombat(function()
        layoutWaiter = nil
        RT.LayoutMainToolbar()
      end)
    end
    return
  end
  local order = Character().toolbar
  local width, x, y, rowHeight = CollapsedFloor(), 0, 0, 0
  local content = frame.content
  local function PlaceButton(button)
    local size = button:GetWidth()
    if x > 0 and x + size > TOOLBAR_WRAP then y, x, rowHeight = y + rowHeight + TOOLBAR_GAP, 0, 0 end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
    button:Show()
    x = x + size + TOOLBAR_GAP
    rowHeight = math.max(rowHeight, button:GetHeight())
    width = math.max(width, x - TOOLBAR_GAP)
  end
  for _, button in pairs(buttons) do button:Hide() end
  for _, id in ipairs(order) do
    local button = buttons[id]
    if not button then
      button = Skin.MakeButton(content, {textKey = ACTIONS[id][1], onClick = function() Invoke(id) end})
      buttons[id] = button
    end
    PlaceButton(button)
  end
  if RT.GetAvailableUpdate() then
    PlaceButton(frame.updateButton)
  else
    frame.updateButton:Hide()
  end
  local bottom = y + rowHeight
  local gold = Config().goldMain and GOLD_ROOM or 0
  RT.controlCollapsedWidth, RT.controlCollapsedHeight = width, bottom + STATUS_ROOM + gold
  RT.controlExpandedHeight = bottom + QUEST_GAP + QUEST_ROOM + gold
  RT.summonStatusText:ClearAllPoints()
  RT.summonStatusText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(bottom + STATUS_GAP))
  RT.summonStatusText:SetWidth(Skin.WindowSize(frame))
  speedText:ClearAllPoints()
  speedText:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(bottom + STATUS_GAP))
  RT.RefreshSpeedDisplay()
  if RT.questWindow then
    RT.questWindow:ClearAllPoints()
    RT.questWindow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(bottom + QUEST_GAP))
  end
  if not RT.questPanelChanging then
    local expanded = RT.IsQuestWindowShown() and not RT.questWindowCreating
    RT.SetControlFrameSize(expanded and RT.controlExpandedWidth or width, expanded and RT.controlExpandedHeight or RT.controlCollapsedHeight)
  end
  PlaceGold()
end

function RT.RefreshOptions()
  if not setting then RT.api:RefreshOptions() end
end

local function T(key) return function() return L[key] end end
local function Setter(fn)
  return function(info, ...)
    setting = true
    RT.api:Guard("Settings.set", fn, info, ...)
    setting = false
    RT.TouchState()
  end
end
local function Toggle(order, key, tipKey, get, set, disabled)
  return {type = "toggle", order = order, name = T(key), desc = tipKey and T(tipKey) or nil,
    get = get, set = Setter(function(_, value) set(value and true or false) end), disabled = disabled}
end
local function Field(field)
  return function() return RT.state[field] and true or false end, function(value) RT.SetField(field, value) end
end
local function Defaults(set)
  return {type = "execute", order = 1000, name = T("UI_DEFAULTS"), func = Setter(set)}
end

local function RollSpeedValues()
  local values = {}
  for _, preset in ipairs(Core.rollSpeedPresetList()) do
    values[preset.index] = string.format("%s  -  %s", L.ROLL_SPEED_PRESET_NAMES[preset.key] or preset.key,
      string.format(L.ROLL_SPEED_FORMAT, tostring(preset.delay), tostring(preset.timeout)))
  end
  return values
end
local function RollSpeedOrder()
  local order = {}
  for index in ipairs(Core.rollSpeedPresetList()) do order[index] = index end
  return order
end

local function GeneralPage()
  local instanceGet = Field("autoCurrentInstanceQuest")
  local remoteGet, remoteSet = Field("remoteRoll")
  local acceptGet, acceptSet = Field("autoAccept")
  local speedGet, speedSet = Field("showSpeed")
  return {type = "group", order = 1, name = T("UI_GENERAL"), args = {
    instance = Toggle(1, "AUTO_CURRENT_INSTANCE_LABEL", "AUTO_CURRENT_INSTANCE_TOOLTIP", instanceGet, function(value)
      RT.SetField("autoCurrentInstanceQuest", value)
      if value then RT.ShowAutoCurrentInstanceWarning() end
    end),
    echoBar = Toggle(2, "ECHO_BAR_LABEL", "ECHO_BAR_TOOLTIP", function() return RT.IsEchoBarEnabled() end, RT.SetEchoBarEnabled),
    echoOrientation = {type = "select", order = 3, name = T("ECHO_BAR_ORIENTATION_LABEL"), desc = T("ECHO_BAR_ORIENTATION_TOOLTIP"),
      values = function() return {H = L.ECHO_BAR_HORIZONTAL, V = L.ECHO_BAR_VERTICAL} end, sorting = {"H", "V"},
      get = function() return RT.GetEchoBarOrientation() end,
      set = Setter(function(_, value) if value ~= RT.GetEchoBarOrientation() then RT.ToggleEchoBarOrientation() end end),
      disabled = function() return not RT.IsEchoBarEnabled() end},
    minimap = Toggle(4, "MINIMAP_BUTTON_LABEL", "MINIMAP_BUTTON_TOOLTIP",
      function() return RT.state.minimap.shown and true or false end, RT.SetMinimapShown),
    travel = Toggle(5, "TRAVEL_LABEL", "TRAVEL_TOOLTIP", function() return RT.state.travelEnabled and true or false end, RT.SetTravelEnabled),
    travelAuto = Toggle(6, "TRAVEL_AUTO_LABEL", "TRAVEL_AUTO_TOOLTIP", function() return RT.state.travelAuto and true or false end,
      RT.SetTravelAutoEnabled, function() return not RT.state.travelEnabled end),
    remote = Toggle(7, "REMOTE_ROLL_LABEL", "REMOTE_ROLL_TOOLTIP", remoteGet, remoteSet),
    accept = Toggle(8, "UI_AUTO_ACCEPT", nil, acceptGet, acceptSet),
    eternals = Toggle(9, "UI_ETERNALS", nil, function() return RT.IsEternalsEnabled() end, RT.SetEternalsEnabled),
    speed = Toggle(10, "UI_SHOW_SPEED", nil, speedGet, speedSet),
    rollSpeed = {type = "select", order = 11, width = "double", name = T("ROLL_SPEED_LABEL"), desc = T("ROLL_SPEED_TOOLTIP"),
      values = RollSpeedValues, sorting = RollSpeedOrder,
      get = function() local preset = Core.nearestRollSpeedPreset(RT.state.rerollDelay) return preset and preset.index or 1 end,
      set = Setter(function(_, index)
        local preset = Core.rollSpeedPresetList()[index]
        if not preset or (RT.state.rerollDelay == preset.delay and RT.state.rerollTimeout == preset.timeout) then return end
        RT.SetRollSpeed(preset.delay, preset.timeout, preset.key)
      end)},
  }}
end

local function ArrowChanged()
  RT.LayoutRouteArrow()
  RT.OnArrowSkinChanged()
  RT.RefreshArrowGallery()
end
local function AppearancePage()
  return {type = "group", order = 2, name = T("UI_APPEARANCE"), args = {
    arrowScale = {type = "range", order = 1, name = T("UI_ARROW_SCALE"), min = 0.25, max = 2, step = 0.05, isPercent = true,
      get = function() return Config().arrowScale end,
      set = Setter(function(_, value) Config().arrowScale = value; RT.LayoutRouteArrow() end)},
    arrowFont = {type = "select", order = 2, name = T("UI_ARROW_FONT"),
      values = function()
        local values = {}
        for _, size in ipairs(Core.ARROW_FONT_SIZES) do values[size] = tostring(size) end
        return values
      end, sorting = Core.ARROW_FONT_SIZES,
      get = function() return Config().arrowFont end,
      set = Setter(function(_, value) Config().arrowFont = value; RT.LayoutRouteArrow() end)},
    gallery = {type = "execute", order = 3, name = T("ARROW_GALLERY_OPEN"), func = function() RT.ToggleArrowGallery() end},
    defaults = Defaults(function()
      local fresh = Core.copyAppearance()
      for _, key in ipairs(ARROW_FIELDS) do Config()[key] = fresh[key] end
      ArrowChanged()
    end),
  }}
end

local function Sequence()
  local sequence, selected, position = {}, {}, {}
  for _, id in ipairs(Character().toolbar) do sequence[#sequence + 1], selected[id] = id, true end
  for id = 1, #ACTIONS do if not selected[id] then sequence[#sequence + 1] = id end end
  for index, id in ipairs(sequence) do position[id] = index end
  return sequence, selected, position
end
local function SaveToolbar(list)
  Character().toolbar = Core.copyToolbar(list)
  RT.LayoutMainToolbar()
end
local function Move(id, delta)
  local list = Core.copyToolbar(Character().toolbar)
  for index, value in ipairs(list) do
    if value == id and list[index + delta] then
      list[index], list[index + delta] = list[index + delta], list[index]
      SaveToolbar(list)
      return
    end
  end
end
local function ToolbarPage()
  local args = {defaults = Defaults(function() SaveToolbar(Core.copyToolbar()) end)}
  local function Order(offset)
    return function(info) local _, _, position = Sequence() return position[info.arg] * 3 + offset end
  end
  local function Stuck(delta)
    return function(info)
      local _, selected = Sequence()
      local list = Character().toolbar
      if not selected[info.arg] then return true end
      return (delta < 0 and list[1] == info.arg) or (delta > 0 and list[#list] == info.arg)
    end
  end
  for id = 1, #ACTIONS do
    args["action" .. id] = {type = "toggle", arg = id, width = "double", order = Order(0),
      name = function(info) return Label(info.arg) end,
      get = function(info) local _, selected = Sequence() return selected[info.arg] == true end,
      set = Setter(function(info, value)
        local list = Core.copyToolbar(Character().toolbar)
        if value then
          list[#list + 1] = info.arg
        else
          for index, known in ipairs(list) do if known == info.arg then table.remove(list, index) break end end
        end
        SaveToolbar(list)
      end)}
    args["up" .. id] = {type = "execute", arg = id, width = "half", order = Order(1), name = T("UI_UP"),
      disabled = Stuck(-1), func = Setter(function(info) Move(info.arg, -1) end)}
    args["down" .. id] = {type = "execute", arg = id, width = "half", order = Order(2), name = T("UI_DOWN"),
      disabled = Stuck(1), func = Setter(function(info) Move(info.arg, 1) end)}
  end
  return {type = "group", order = 3, name = T("UI_TOOLBAR"), args = args}
end

local function GoldPage()
  local args = {defaults = Defaults(function()
    local fresh = Core.copyAppearance()
    for _, key in ipairs(GOLD_FIELDS) do Config()[key] = fresh[key] end
    goldConfig = nil
    RT.LayoutMainToolbar()
  end)}
  for index, spec in ipairs({{"goldMain", "UI_GOLD_MAIN"}, {"goldTotal", "UI_TOTAL"}, {"goldLast", "UI_LAST"},
    {"goldCurrent", "UI_CURRENT"}, {"goldSession", "UI_SESSION"}}) do
    local key = spec[1]
    args[key] = Toggle(index, spec[2], nil, function() return Config()[key] and true or false end, function(value)
      Config()[key] = value
      goldConfig = nil
      RT.LayoutMainToolbar()
    end)
  end
  return {type = "group", order = 4, name = T("UI_GOLD"), args = args}
end

function RT.RegisterOptions()
  RT.api:Options({type = "group", name = RT.ADDON_TITLE, args = {
    general = GeneralPage(),
    appearance = AppearancePage(),
    toolbar = ToolbarPage(),
    gold = GoldPage(),
    help = {type = "group", order = 5, name = T("UI_HELP"), args = RT.HelpOptions()},
  }})
end

function RT.ShowSettings(page)
  RT.api:OpenOptions(PAGES[page] or page)
end

function RT.ApplyWindowScale()
  Skin.ScaleRoots(RT.InterfaceParameter("scale"))
  RT.LayoutRouteArrow()
  RT.RefreshRouteArrowLock()
  RT.OnArrowSkinChanged()
  RT.RefreshArrowGallery()
end
function RT.ApplyLook()
  if not InCombatLockdown() then RT.ApplyWindowScale() return end
  if lookWaiting then return end
  lookWaiting = true
  RT.api:AfterCombat(function()
    lookWaiting = false
    RT.ApplyWindowScale()
  end)
end
function RT.InitAppearance()
  RT.state.appearance = Core.copyAppearance(RT.state.appearance)
  RT.api:On("PARAMETER_CHANGED", function(_, name) if LOOK[name] then RT.ApplyLook() end end)
  RT.api:On("READY", function() RT.ApplyLook() end)
end
function RT.InitSettingsAccess()
  local frame = RT.controlFrame
  buttons = {frame.listsButton, frame.buildsButton, AutoCallboardButton, frame.startButton, frame.shareButton, frame.questButton}
  RT.PositionControlHeader = function()
    RT.summonStatusText:SetWidth(Skin.WindowSize(frame))
    if RT.questGoldText and Config().goldMain then RT.questGoldText:SetWidth(Skin.WindowSize(frame)) end
  end
  speedText = frame.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  speedText:SetJustifyH("RIGHT")
  Skin.MutedText(speedText)
  RT.LayoutMainToolbar()
  RT.RegisterOptions()
end

function RT.RefreshSettingsLanguage()
  goldConfig = nil
  RT.RefreshGoldDisplay()
  speedShown = nil
  RT.RefreshSpeedDisplay()
  RT.RegisterOptions()
  if buttons then
    for id, button in pairs(buttons) do
      if id ~= 3 and id ~= 4 and id ~= 6 then button:SetText(Label(id)) end
    end
    if not InCombatLockdown() then RT.LayoutMainToolbar() end
  end
end
