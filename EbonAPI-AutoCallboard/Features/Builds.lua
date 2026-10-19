local Lib = EbonAPI.Lib
local Core = AutoCallboardCore
local Skin = AutoCallboardSkin
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local Localized = RT.Localized

RT.buildsRefreshDelay = 5
RT.buildsRefreshThrottle = 30

local State = EbonAPI.State
local CS = EbonAPI.CS

function RT.SendEchoMessage(opcode, body)
  return RT.api:SendServer(opcode, body)
end

local function OnServerBuilds(_, builds)
  RT.api:Trace("builds.list", builds.active)
  RT.RefreshBuildsWindowIfShown()
  RT.RefreshEchoBar()
end

local function OnServerBuildActive(_, slot)
  RT.api:Trace("builds.active", slot)
  RT.RefreshBuildsWindowIfShown()
  RT.RefreshEchoBar()
end

function RT.InitBuilds()
  RT.api:On("SERVER_BUILDS", OnServerBuilds)
  RT.api:On("SERVER_BUILD_ACTIVE", OnServerBuildActive)
end

function RT.RefreshBuildsWindowIfShown()
  local buildsWindow = RT.buildsWindow

  if buildsWindow and buildsWindow:IsShown() then
    RT.RefreshBuildsWindow()
  end
end

function RT.BuildLabel(build)
  local name = build and tostring(build.name or "") or ""

  if name == "" then
    return string.format(L.BUILD_SLOT_FALLBACK, tostring(build and build.slot or "?"))
  end

  return name
end

function RT.RequestBuildsRefresh(source)
  local now = GetTime()

  if RT.lastBuildsRequestAt
      and now - RT.lastBuildsRequestAt < RT.buildsRefreshThrottle then
    return false
  end

  RT.lastBuildsRequestAt = now

  RT.api:RequestServer(CS.REFRESH_PERKS, "", RT.buildsRefreshThrottle)
  local ok = RT.api:RequestServer(CS.REFRESH_BUILDS, "", RT.buildsRefreshThrottle)

  return ok
end

function RT.CanSwitchBuild()
  if UnitAffectingCombat and UnitAffectingCombat("player") then
    return false, L.BUILD_SWITCH_BLOCKED_COMBAT
  end

  return true
end

function RT.SwitchToBuild(slot, source)
  slot = tonumber(slot)

  if not slot then
    return false
  end

  local builds = State.sortedBuilds()
  local label = string.format(L.BUILD_SLOT_FALLBACK, tostring(slot))

  for i = 1, #(builds) do
    if tonumber(builds[i].slot) == slot then
      label = RT.BuildLabel(builds[i])
      break
    end
  end

  local _, activeSlot = State.activeBuild()
  if activeSlot == slot then
    return false
  end

  if not RT.CanSwitchBuild() then
    RT.api:Report(RT.api:Problem("BUILDS.SWITCH_BLOCKED_COMBAT", { slot = slot }))
    return false
  end

  if not RT.SendEchoMessage(CS.BUILD_SELECT, tostring(slot)) then
    RT.api:Report(RT.api:Problem("BUILDS.SWITCH_SEND_FAILED", { slot = slot, source = source }))
    return false
  end

  RT.api:Trace("builds.switch", slot, source)

  return true
end

function RT.RefreshBuildRowVisual(row)
  if not row.build then
    return
  end

  local _, activeSlot = State.activeBuild()

  Skin.PaintRow(row,
      activeSlot and tonumber(row.build.slot) == activeSlot,
      not RT.CanSwitchBuild())
end

local function BuildTooltip(owner, build, extraKey)
  local _, activeSlot = State.activeBuild()
  local allowed, reason = RT.CanSwitchBuild()

  EbonAPI.Bricks.tip(owner, RT.BuildLabel(build))

  if tonumber(build.slot) == activeSlot then
    GameTooltip:AddLine(L.BUILDS_ROW_ACTIVE, 0.8, 0.8, 0.8)
  elseif not allowed then
    GameTooltip:AddLine(reason, 1, 0.4, 0.4)
  else
    GameTooltip:AddLine(L.BUILDS_ROW_LEFT_CLICK_SWITCH, 0.8, 0.8, 0.8)
  end

  if extraKey then
    GameTooltip:AddLine(L[extraKey], 0.8, 0.8, 0.8)
  end

  GameTooltip:Show()
end

local BUILDS_WIDTH = 196
local BUILD_ROW_GAP = 2
local BUILDS_FOOTER_GAP = 8

function RT.CreateBuildRow(index)
  local row = Skin.Row(RT.buildsWindow.content, "AutoCallboardBuildRow" .. tostring(index))

  row:RegisterForDrag("LeftButton")

  row:SetScript("OnClick", function(self)
    if not self.build then
      return
    end

    if RT.SwitchToBuild(self.build.slot, "fenetre") then
      RT.buildsWindow:Hide()
    end
    end)

  row:SetScript("OnDragStart", function(self)
    if self.build then
      RT.BeginEchoAssign(tonumber(self.build.slot))
    end
    end)

  row:SetScript("OnDragStop", function()
    RT.EndEchoAssign()
    end)

  row:HookScript("OnEnter", function(self)
    if self.build then
      BuildTooltip(self, self.build, "ECHO_BAR_DRAG_TIP")
    end
    end)

  row:HookScript("OnLeave", function()
    GameTooltip:Hide()
    end)

  return row
end

function RT.RefreshBuildsWindow()
  local buildsWindow = RT.buildsWindow

  if not buildsWindow then
    return
  end

  local builds = State.sortedBuilds()
  local count = #(builds)
  local rows = RT.buildRows

  rows[1] = rows[1] or RT.CreateBuildRow(1)

  local stride = rows[1]:GetHeight() + BUILD_ROW_GAP

  for i = 1, math.max(count, #(rows)) do
    local row = rows[i]

    if not row and i <= count then
      row = RT.CreateBuildRow(i)
      rows[i] = row
    end

    if row then
      local build = builds[i]

      if build then
        row.build = build
        row.title:SetText(RT.BuildLabel(build))
        row:ClearAllPoints()
        local y = -((i - 1) * stride)
        row:SetPoint("TOPLEFT", buildsWindow.content, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", buildsWindow.content, "TOPRIGHT", 0, y)
        row:Show()
        RT.RefreshBuildRowVisual(row)
      else
        row.build = nil
        row:Hide()
      end
    end
  end

  if buildsWindow.emptyLabel then
    Lib.setShown(buildsWindow.emptyLabel, count == 0)
  end

  Skin.SizeWindow(buildsWindow, BUILDS_WIDTH,
    math.max(count, 1) * stride + BUILDS_FOOTER_GAP + buildsWindow.refreshButton:GetHeight())
end

function RT.CreateBuildsWindow()
  local anchor = RT.controlFrame and RT.controlFrame.buildsButton
  local buildsWindow = Skin.Window("AutoCallboardBuildsWindow", {
    width = BUILDS_WIDTH,
    height = BUILDS_WIDTH / 2,
    titleKey = "BUILDS_WINDOW_TITLE",
    point = anchor and { "TOPLEFT", anchor, "BOTTOMLEFT", 0, -6 } or { "CENTER", UIParent, "CENTER", 0, 0 },
  })
  RT.buildsWindow = buildsWindow
  RT.buildRows = RT.buildRows or {}

  local content = buildsWindow.content

  buildsWindow.emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  buildsWindow.emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  buildsWindow.emptyLabel:SetPoint("RIGHT", content, "RIGHT", 0, 0)
  buildsWindow.emptyLabel:SetJustifyH("LEFT")
  Localized(buildsWindow.emptyLabel, "BUILDS_WINDOW_EMPTY")
  Skin.MutedText(buildsWindow.emptyLabel)

  buildsWindow.refreshButton = Skin.MakeButton(content, {
    textKey = "BUILDS_WINDOW_REFRESH_BUTTON",
    points = {
      { "BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0 },
      { "BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0 },
    },
    onClick = function()
      RT.lastBuildsRequestAt = nil
      RT.RequestBuildsRefresh("bouton")
      end,
  })
end

function RT.ToggleBuildsWindow()
  if not RT.buildsWindow then
    RT.CreateBuildsWindow()
  end

  local buildsWindow = RT.buildsWindow

  if buildsWindow:IsShown() then
    buildsWindow:Hide()
    return
  end

  RT.RequestBuildsRefresh("ouverture de la fenetre")
  RT.RefreshBuildsWindow()
  buildsWindow:Show()

  if buildsWindow.Raise then
    buildsWindow:Raise()
  end
end

local ECHO_SLOTS = Core.ECHO_BAR_SLOTS
local ECHO_CELL_W = 96
local ECHO_GAP = 2
local ECHO_PAD = 2
local ECHO_DOT = 18
local ECHO_DOT_TEXTURE = [[Interface\Buttons\UI-RadioButton]]

local echoBar
local echoCells
local echoDotButton
local echoDotTexture
local echoDrag
local echoDropIndex
local echoCombatWatched = false

local function EchoBarState()
  local entry = RT.EnsureCharacterState()

  if not entry then
    return nil
  end

  if type(entry.echoBar) ~= "table" then
    entry.echoBar = Core.copyEchoBar(nil)
  end

  return entry.echoBar
end

local function BuildBySlot(slot)
  local builds = State.GetBuilds()

  if not slot or not builds or type(builds.slots) ~= "table" then
    return nil
  end

  return builds.slots[slot]
end

local function PaintEchoCell(cell)
  local _, activeSlot = State.activeBuild()

  Skin.PaintRow(cell,
      cell.slot ~= nil and activeSlot == cell.slot,
      not RT.CanSwitchBuild())
end

local function SetEchoDropIndex(index)
  if index == echoDropIndex then
    return
  end

  if echoDropIndex and echoCells[echoDropIndex] then
    Skin.Highlight(echoCells[echoDropIndex], nil)
  end

  echoDropIndex = index

  if index then
    Skin.Highlight(echoCells[index], "drop")
  end
end

local function EchoCellUnderCursor()
  if not echoBar or not echoBar:IsShown() or not GetCursorPosition then
    return nil
  end

  local scale = echoBar:GetEffectiveScale() or 1
  local x, y = GetCursorPosition()

  if not x then
    return nil
  end

  x = x / scale
  y = y / scale

  for i = 1, ECHO_SLOTS do
    if RT.IsUnder(echoCells[i], x, y) then
      return i
    end
  end

  return nil
end

local function TrackEchoDrop()
  SetEchoDropIndex(EchoCellUnderCursor())
end

local function ApplyEchoDrop(drag, target)
  local bar = EchoBarState()

  if not bar or bar.locked then
    return
  end

  if drag.fromIndex then
    if target == drag.fromIndex then
      return
    end

    local moved = bar.slots[drag.fromIndex]
    bar.slots[drag.fromIndex] = target and bar.slots[target] or nil

    if target then
      bar.slots[target] = moved
    end
  elseif target then
    for i = 1, ECHO_SLOTS do
      if bar.slots[i] == drag.slot then
        bar.slots[i] = nil
      end
    end

    bar.slots[target] = drag.slot
  else
    return
  end

  RT.TouchState()
  RT.RefreshEchoBar()
end

local function BeginEchoDrag(drag)
  echoDrag = drag
  GameTooltip:Hide()
  echoBar:SetScript("OnUpdate", TrackEchoDrop)
  TrackEchoDrop()
end

local function EndEchoDrag()
  echoBar:SetScript("OnUpdate", nil)

  local drag = echoDrag
  echoDrag = nil
  SetEchoDropIndex(nil)

  if drag then
    ApplyEchoDrop(drag, EchoCellUnderCursor())
  end
end

function RT.BeginEchoAssign(slot)
  local bar = EchoBarState()

  if not slot or not echoBar or not echoBar:IsShown() or not bar or bar.locked then
    return
  end

  BeginEchoDrag({ slot = slot })
end

function RT.EndEchoAssign()
  if echoDrag then
    EndEchoDrag()
  end
end

local function PaintEchoDot(locked)
  Skin.ApplyColor(echoDotTexture, "SetVertexColor", locked and "border" or "checked")
end

local function ApplyEchoLock(locked)
  echoBar:SetMovable(not locked)

  for i = 1, ECHO_SLOTS do
    if locked then
      echoCells[i]:RegisterForDrag()
    else
      echoCells[i]:RegisterForDrag("LeftButton")
    end
  end

  PaintEchoDot(locked)
end

local function LayoutEchoBar(orientation)
  local horizontal = orientation ~= "V"
  local cellHeight = echoCells[1]:GetHeight()

  if horizontal then
    echoBar:SetWidth(ECHO_PAD * 2 + ECHO_SLOTS * ECHO_CELL_W + (ECHO_SLOTS - 1) * ECHO_GAP)
    echoBar:SetHeight(ECHO_PAD * 2 + cellHeight)
  else
    echoBar:SetWidth(ECHO_PAD * 2 + ECHO_CELL_W)
    echoBar:SetHeight(ECHO_PAD * 2 + ECHO_SLOTS * cellHeight + (ECHO_SLOTS - 1) * ECHO_GAP)
  end

  for i = 1, ECHO_SLOTS do
    local cell = echoCells[i]
    cell:ClearAllPoints()
    cell:SetWidth(ECHO_CELL_W)

    if horizontal then
      cell:SetPoint("TOPLEFT", echoBar, "TOPLEFT",
          ECHO_PAD + (i - 1) * (ECHO_CELL_W + ECHO_GAP), -ECHO_PAD)
    else
      cell:SetPoint("TOPLEFT", echoBar, "TOPLEFT",
          ECHO_PAD, -(ECHO_PAD + (i - 1) * (cellHeight + ECHO_GAP)))
    end
  end
end

local function CreateEchoCell(index)
  local cell = Skin.Row(echoBar, "AutoCallboardEchoCell" .. tostring(index), "LeftButtonUp", "RightButtonUp")

  cell.index = index
  cell.title:SetJustifyH("CENTER")

  cell:SetScript("OnClick", function(self, button)
    local bar = EchoBarState()

    if not bar then
      return
    end

    if button == "RightButton" then
      if bar.locked or not self.slot then
        return
      end

      bar.slots[self.index] = nil
      RT.TouchState()
      RT.RefreshEchoBar()
      return
    end

    if self.slot then
      RT.SwitchToBuild(self.slot, "barre echo")
    end
    end)

  cell:SetScript("OnDragStart", function(self)
    local bar = EchoBarState()

    if not bar or bar.locked or not self.slot then
      return
    end

    BeginEchoDrag({ fromIndex = self.index })
    end)

  cell:SetScript("OnDragStop", function()
    if echoDrag then
      EndEchoDrag()
    end
    end)

  cell:HookScript("OnEnter", function(self)
    if echoDrag then
      return
    end

    if self.slot then
      BuildTooltip(self, self.build or { slot = self.slot }, "ECHO_BAR_CLEAR_TIP")
    else
      Skin.OpenTip(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L.ECHO_BAR_EMPTY_TIP, 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end
    end)

  cell:HookScript("OnLeave", function()
    GameTooltip:Hide()
    end)

  return cell
end

local function CreateEchoBar()
  if echoBar then
    return
  end

  echoBar = Skin.Root(Skin.Box(UIParent, { name = "AutoCallboardEchoBar" }))
  echoBar:SetFrameStrata("MEDIUM")
  echoBar:SetClampedToScreen(true)
  echoBar:EnableMouse(true)

  echoCells = {}
  for i = 1, ECHO_SLOTS do
    echoCells[i] = CreateEchoCell(i)
  end

  echoDotButton = CreateFrame("Button", nil, echoBar)
  echoDotButton:SetWidth(ECHO_DOT)
  echoDotButton:SetHeight(ECHO_DOT)
  echoDotButton:SetPoint("CENTER", echoBar, "TOPLEFT", 0, 0)
  echoDotButton:RegisterForClicks("LeftButtonUp")
  echoDotButton:RegisterForDrag("LeftButton")

  echoDotTexture = echoDotButton:CreateTexture(nil, "OVERLAY")
  echoDotTexture:SetAllPoints(echoDotButton)
  echoDotTexture:SetTexture(ECHO_DOT_TEXTURE)
  echoDotTexture:SetTexCoord(0.25, 0.5, 0, 1)

  echoDotButton:SetScript("OnClick", function()
    local bar = EchoBarState()

    if not bar then
      return
    end

    bar.locked = not bar.locked
    ApplyEchoLock(bar.locked)
    RT.TouchState()
    end)

  echoDotButton:SetScript("OnDragStart", function()
    local bar = EchoBarState()

    if bar and not bar.locked and not InCombatLockdown() and not RT.IsInterfaceLocked() then
      echoBar:StartMoving()
    end
    end)

  echoDotButton:SetScript("OnDragStop", function()
    echoBar:StopMovingOrSizing()

    local bar = EchoBarState()

    if bar then
      RT.SavePoint(echoBar, bar)
      RT.TouchState()
    end
    end)

  echoDotButton:SetScript("OnEnter", function(self)
    local bar = EchoBarState()

    Skin.OpenTip(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(bar and bar.locked and L.ECHO_BAR_LOCKED_TIP or L.ECHO_BAR_UNLOCKED_TIP,
        0.8, 0.8, 0.8)
    GameTooltip:Show()
    end)

  echoDotButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
    end)
end

local function WatchEchoCombat(enabled)
  local events = RT.events

  if not events or echoCombatWatched == enabled then
    return
  end

  echoCombatWatched = enabled

  RT.api:Guard("ECHO.WATCH_COMBAT", events.Watch, events, "PLAYER_REGEN_DISABLED", enabled)
  RT.api:Guard("ECHO.WATCH_COMBAT", events.Watch, events, "PLAYER_REGEN_ENABLED", enabled)
end

function RT.RefreshEchoBar()
  if not echoBar or not echoBar:IsShown() then
    return
  end

  local bar = EchoBarState()

  if not bar then
    return
  end

  for i = 1, ECHO_SLOTS do
    local cell = echoCells[i]
    local slot = bar.slots[i]
    local build = BuildBySlot(slot)

    cell.slot = slot
    cell.build = build

    if slot then
      cell.title:SetText(build and RT.BuildLabel(build)
          or string.format(L.BUILD_SLOT_FALLBACK, tostring(slot)))
    else
      cell.title:SetText("")
    end

    PaintEchoCell(cell)
  end
end

function RT.ApplyEchoBar()
  local bar = EchoBarState()

  if not bar or not bar.enabled then
    if echoBar then
      echoBar:Hide()
    end

    WatchEchoCombat(false)
    return
  end

  CreateEchoBar()
  RT.RestorePoint(echoBar, bar)
  LayoutEchoBar(bar.orientation)
  ApplyEchoLock(bar.locked)
  echoBar:Show()
  RT.RefreshEchoBar()
  WatchEchoCombat(true)
end

function RT.IsEchoBarEnabled()
  local bar = EchoBarState()
  return bar ~= nil and bar.enabled == true
end

function RT.GetEchoBarOrientation()
  local bar = EchoBarState()
  return bar and bar.orientation or "H"
end

function RT.SetEchoBarEnabled(enabled)
  local bar = EchoBarState()

  if not bar then
    return
  end

  bar.enabled = enabled and true or false
  RT.TouchState()
  RT.ApplyEchoBar()
  RT.RefreshOptions()
end

function RT.ToggleEchoBarOrientation()
  local bar = EchoBarState()

  if not bar then
    return
  end

  bar.orientation = bar.orientation == "V" and "H" or "V"
  RT.TouchState()

  if echoBar then
    LayoutEchoBar(bar.orientation)
  end

  RT.RefreshOptions()
end

function RT.TriggerEchoSlot(index)
  index = tonumber(index)

  if not index or index < 1 or index > ECHO_SLOTS then
    return
  end

  local bar = EchoBarState()
  local slot = bar and bar.slots[index]

  if slot then
    RT.SwitchToBuild(slot, "raccourci")
  end
end

function RT.RefreshBindingNames()
  for i = 1, ECHO_SLOTS do
    _G["BINDING_NAME_AUTOCALLBOARD_ECHO" .. tostring(i)] =
        string.format(L.ECHO_BAR_BINDING_NAME, i)
  end
end

BINDING_HEADER_AutoCallboard = "AutoCallboard"
RT.RefreshBindingNames()
