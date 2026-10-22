local Lib = EbonAPI.Lib
local Skin = AutoCallboardSkin
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime

local Localized = RT.Localized
local IsCallboardActive = RT.IsCallboardActive
local IsSummonSpellUsable = RT.IsSummonSpellUsable
local GetSummonCooldownRemaining = RT.GetSummonCooldownRemaining
local GetObjectivesService = RT.GetObjectivesService
local CaptureCurrentObjectives = RT.CaptureCurrentObjectives
local QueueCallboardFollowup = RT.QueueCallboardFollowup
local UpdateSummonStatus = RT.UpdateSummonStatus
local state = RT.state

local ADDON_TITLE = RT.ADDON_TITLE
local GEAR_TEXTURE = "Interface\\WorldMap\\Gear_64Grey"

local controlFrame
local button
local minimapButton
local summonStatusText
local preClickCooldownRemaining = 0
local preClickWasActive = false
local preClickWasUsable = true

local ApplySummonButtonAttributes
local PositionMinimapButton
local UpdateRollToggleButtons


local function SetButtonEnabled(target, enabled)
  if not target then
    return
  end

  enabled = enabled and true or false
  target:SetDisabledState(not enabled)

  if not (target.secure and InCombatLockdown()) then
    if enabled then
      target:Enable()
    else
      target:Disable()
    end
  end

  Skin.RefreshButtonIcon(target)
end

RT.SetButtonEnabled = SetButtonEnabled

function RT.UpdateShareButtonState()
  local enabled = RT.lastAcceptedQuest ~= nil

  SetButtonEnabled(RT.shareQuestButton, enabled)

  if controlFrame and controlFrame.shareButton then
    SetButtonEnabled(controlFrame.shareButton, enabled)
  end
end


function RT.RefreshUpdateNotice()
  if not controlFrame or not controlFrame.updateButton then
    return false
  end

  RT.LayoutMainToolbar()

  return controlFrame.updateButton:IsShown() and true or false
end

function RT.RefreshCallboardButtonEnabled()
  if not button then
    return
  end

  local blocked = RT.IsSummonBlockedIndoors()
  if blocked == RT.summonBlockedIndoors then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    return
  end

  RT.summonBlockedIndoors = blocked
  SetButtonEnabled(button, not blocked)
end

function RT.SyncOverlayFrameLevels()
  local referenceFrame = RT.ResolveFramePath("ObjectivesMainFrame")
  local referenceLevel = 20

  if referenceFrame and referenceFrame.GetFrameLevel then
    referenceLevel = referenceFrame:GetFrameLevel() or referenceLevel
  end

  if referenceLevel == RT.lastOverlayReferenceLevel and RT.questWindow == RT.lastOverlayQuestWindow then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    return
  end

  RT.lastOverlayReferenceLevel = referenceLevel
  RT.lastOverlayQuestWindow = RT.questWindow

  if controlFrame then
    if controlFrame.SetFrameStrata then
      controlFrame:SetFrameStrata("HIGH")
    end
    if controlFrame.SetFrameLevel then
      controlFrame:SetFrameLevel(referenceLevel + 20)
    end
  end

  if RT.questWindow then
    if RT.questWindow.SetFrameStrata then
      RT.questWindow:SetFrameStrata("HIGH")
    end
    if controlFrame and RT.questWindow.SetFrameLevel then
      RT.questWindow:SetFrameLevel((controlFrame:GetFrameLevel() or referenceLevel + 20) + 1)
    end
  end
end

local function RefreshRollButtonMacroState(target)
  if not target or not target._acbRollToggle or not target.SetAttribute then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    return
  end

  RT.ApplySecureMacroButtonAttributes(target, "", "start")
end

local function UpdateRollToggleButtonState(target, canStart)
  if not target then
    return
  end

  if RT.IsRolling() then
    Skin.SetButtonSelected(target, true)
    target:SetText(L.BUTTON_STOP)
    SetButtonEnabled(target, true)
    RefreshRollButtonMacroState(target)
    return
  end

  Skin.SetButtonSelected(target, false)
  target:SetText(L.BUTTON_START)
  SetButtonEnabled(target, canStart)
  RefreshRollButtonMacroState(target)
end

RT.UpdateRollToggleButtonState = UpdateRollToggleButtonState

local function IsQuestRollStartAvailable()
  local service = GetObjectivesService()

  return service ~= nil
end

RT.IsQuestRollStartAvailable = IsQuestRollStartAvailable

UpdateRollToggleButtons = function()
  if controlFrame and controlFrame.startButton then
    UpdateRollToggleButtonState(controlFrame.startButton, true)
  end

  UpdateRollToggleButtonState(RT.startRollButton, IsQuestRollStartAvailable())
end

RT.UpdateRollToggleButtons = UpdateRollToggleButtons

function RT.ApplySecureMacroButtonAttributes(target, macroText, label)
  if not target then
    return
  end

  macroText = macroText or ""

  if InCombatLockdown and InCombatLockdown() then
    return
  end

  if target._acbSecureType == "macro" and target._acbSecureMacroText == macroText then
    return
  end

  target:SetAttribute("type", "macro")
  target:SetAttribute("macrotext", macroText)
  target._acbSecureType = "macro"
  target._acbSecureMacroText = macroText
end

function RT.ConfigureStartButton(target)
  if not target then
    return
  end

  target._acbRollToggle = true
  RT.ApplySecureMacroButtonAttributes(target, "", "start")
  target:SetScript("PreClick", function()
    if RT.IsRolling() then
      return
    end

    preClickWasActive = IsCallboardActive()
    RT.ApplySecureMacroButtonAttributes(target, "", "start")
    end)
  target:SetScript("PostClick", function()
    if RT.IsRolling() then
      RT.StopRolling(L.ROLL_STOPPED)
      UpdateSummonStatus()
      return
    end

    if not preClickWasActive then
      RT.api:Trace("roll_without_summon")
    end

    RT.StartRolling()
    UpdateSummonStatus()
    end)
end

function RT.SetControlFrameSize(width, height)
  if not controlFrame then
    return
  end

  local centerX = controlFrame:GetCenter()
  local top = controlFrame:GetTop()

  Skin.SizeWindow(controlFrame, width, height)

  if centerX and top then
    controlFrame:ClearAllPoints()
    controlFrame:SetPoint("TOP", UIParent, "BOTTOMLEFT", centerX, top)
  end
end

function RT.AnimateControlFrameSize(width, height, onComplete)
  if not controlFrame then
    if onComplete then
      onComplete()
    end
    return
  end

  local startWidth, startHeight = Skin.WindowSize(controlFrame)
  local startedAt = GetTime()

  if RT.questPanelAnimation then
    RT.questPanelAnimation.finished = true
  end

  RT.questPanelAnimation = {
    finished = false,
    onComplete = onComplete,
    startHeight = startHeight,
    startWidth = startWidth,
    startedAt = startedAt,
    targetHeight = height,
    targetWidth = width,
  }
end

function RT.UpdateQuestPanelAnimation()
  local animation = RT.questPanelAnimation

  if not animation or animation.finished then
    return
  end

  local elapsed = GetTime() - animation.startedAt
  local progress = elapsed / RT.questPanelAnimationSeconds

  if progress >= 1 then
    progress = 1
    animation.finished = true
  end

  local eased = 1 - ((1 - progress) * (1 - progress))
  local width = animation.startWidth + ((animation.targetWidth - animation.startWidth) * eased)
  local height = animation.startHeight + ((animation.targetHeight - animation.startHeight) * eased)

  RT.SetControlFrameSize(width, height)
  RT.PositionControlHeader()

  if animation.finished then
    RT.SetControlFrameSize(animation.targetWidth, animation.targetHeight)
    RT.PositionControlHeader()
    RT.questPanelAnimation = nil

    if animation.onComplete then
      animation.onComplete()
    end
  end
end

function RT.SetQuestPanelExpanded(expanded)
  if not controlFrame then
    return
  end

  expanded = expanded and true or false
  RT.SaveQuestPanelExpanded(expanded)

  if RT.questPanelChanging then
    return
  end

  RT.questPanelChanging = true

  if expanded then
    if not RT.questWindow then
      RT.CreateQuestWindow()
    end

    if summonStatusText then
      summonStatusText:SetWidth(256)
    end

    if controlFrame.questButton then
      controlFrame.questButton:SetText(L.BUTTON_HIDE)
    end

    CaptureCurrentObjectives()
    RT.UpdateQuestWindow()
    RT.AnimateControlFrameSize(RT.controlExpandedWidth, RT.controlExpandedHeight, function()
        if RT.questWindow then
          RT.questWindow:Show()
          RT.UpdateQuestWindow()
        end

        RT.questPanelChanging = false
    end)
  else
    if RT.IsQuestWindowShown() then
      RT.questWindow:Hide()
    end

    if summonStatusText then
      summonStatusText:SetWidth(256)
    end

    if controlFrame.questButton then
      controlFrame.questButton:SetText(L.BUTTON_QUESTS)
    end

    RT.AnimateControlFrameSize(RT.controlCollapsedWidth, RT.controlCollapsedHeight, function()
        RT.PositionControlHeader()
        RT.questPanelChanging = false
    end)
  end
end

function RT.ToggleQuestPanel()
  RT.SetQuestPanelExpanded(not RT.IsQuestWindowShown())
end

local function SavedButtonPoint()
  local saved = state.button

  if type(saved) ~= "table" or not saved.point then
    return nil
  end

  return { saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0 }
end

PositionMinimapButton = function()
  if minimapButton then
    minimapButton:Refresh()
  end
end

function RT.SetMinimapShown(shown)
  if not state then
    return
  end

  state.minimap.shown = shown and true or false
  PositionMinimapButton()
  RT.RefreshOptions()
end

local function MinimapTip(lines)
  lines:Add(L.MINIMAP_TOOLTIP_LEFT_CLICK, "text")
  lines:Add(L.MINIMAP_TOOLTIP_RIGHT_CLICK, "text")
  lines:Add(L.MINIMAP_TOOLTIP_DRAG, "muted")
end

local function CreateMinimapButton()
  if minimapButton then
    PositionMinimapButton()
    return
  end

  minimapButton = Skin.Named(RT.api:MinimapButton({
    text = function() return L.ADDON_NAME_TOOLTIP end,
    tip = MinimapTip,
    hidden = function() return not state.minimap.shown end,
    angle = state.minimap.angle,
    onClick = function(_, mouseButton)
      if mouseButton == "RightButton" then
        RT.ShowSettings()
        return
      end

      if controlFrame and controlFrame:IsShown() then
        controlFrame:Hide()
      elseif controlFrame then
        RT.SaveControlFrameShown(true)
        controlFrame:Show()
      end
    end,
  }), "AutoCallboardMinimapButton")
end

local function StartMovingButton(self)
  if IsShiftKeyDown() and not InCombatLockdown() and not RT.IsInterfaceLocked() then
    controlFrame:StartMoving()
  end
end

local function StopMovingButton(self)
  local stop = controlFrame:GetScript("OnDragStop")

  if stop then
    stop(controlFrame)
  end
end

local function MakeActionButton(name, text, point, relativeTo, relativePoint, x, y, onClick, secure, tipKey)
  local actionButton = Skin.MakeButton(controlFrame.content, {
    name = name,
    secure = secure,
    text = text,
    tipKey = tipKey,
    point = { point, relativeTo, relativePoint, x, y },
    onClick = onClick,
  })
  actionButton:RegisterForDrag("LeftButton")
  actionButton:SetScript("OnDragStart", StartMovingButton)
  actionButton:SetScript("OnDragStop", StopMovingButton)

  return actionButton
end

ApplySummonButtonAttributes = function()
  if not button then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    return
  end

  RT.ApplySecureMacroButtonAttributes(button, RT.GetSummonMacroText(), "callboard")

  if RT.startRollButton then
    RT.ConfigureStartButton(RT.startRollButton)
  end

  if controlFrame and controlFrame.startButton then
    RT.ConfigureStartButton(controlFrame.startButton)
  end

  UpdateRollToggleButtonState(RT.startRollButton, IsQuestRollStartAvailable())
  UpdateRollToggleButtonState(controlFrame and controlFrame.startButton or nil, true)

  button:SetText(state.targetName)
end

local function CreateControlFrame()
  controlFrame = Skin.Window("AutoCallboardFrame", {
    title = ADDON_TITLE,
    noEsc = true,
    movable = true,
    point = SavedButtonPoint(),
    width = RT.controlCollapsedWidth,
    height = RT.controlCollapsedHeight,
    buttons = {
      { text = "?", onClick = function() RT.ShowAddonHelp("about") end, tipTitle = "UI_HELP" },
      { icon = GEAR_TEXTURE, onClick = function() RT.ShowSettings() end, tipTitle = "UI_SETTINGS" },
    },
  })
  RT.controlFrame = controlFrame
  controlFrame.helpButton = controlFrame.headButtons[1]
  controlFrame.settingsButton = controlFrame.headButtons[2]
  RT.SyncOverlayFrameLevels()
  controlFrame:HookScript("OnShow", function()
    RT.SaveControlFrameShown(true)
    RT.SyncOverlayFrameLevels()
    end)
  controlFrame:HookScript("OnHide", function()
    RT.SaveControlFrameShown(false)

    if RT.IsQuestWindowShown() then
      RT.SaveQuestPanelExpanded(false)
      RT.questWindow:Hide()
    end

    if RT.HideDebugWindow then
      RT.HideDebugWindow()
    end

    if RT.listsWindow and RT.listsWindow:IsShown() then
      RT.listsWindow:Hide()
    end
    end)
end

local function CreateHeaderButtons()
  controlFrame.closeButton.onClick = function()
    if RT.IsQuestWindowShown() then
      RT.SetQuestPanelExpanded(false)
    else
      controlFrame:Hide()
    end
  end

  controlFrame.updateButton = Skin.MakeButton(controlFrame.content, {
    name = "AutoCallboardUpdateButton",
    textKey = "UPDATE_BUTTON",
    onClick = function() RT.OpenUpdatePage() end,
    tip = function()
      local version, installed = RT.GetAvailableUpdate()
      local tip = RT.LinkTip()

      if version then
        GameTooltip:AddLine(string.format(L.UPDATE_VERSIONS, version, installed), 1, 1, 1)
      end

      if tip then
        GameTooltip:AddLine(tip, 1, 1, 1, true)
      end
      end,
  })
  controlFrame.updateButton:Hide()
end

local function CreateSummonButton(anchor)
  button = Skin.MakeButton(controlFrame.content, {
    name = "AutoCallboardButton",
    secure = true,
    text = state.targetName,
    point = { "LEFT", anchor, "RIGHT", 5, 0 },
  })
  button:RegisterForDrag("LeftButton")
  ApplySummonButtonAttributes()
  button:SetScript("PreClick", function()
    preClickCooldownRemaining = GetSummonCooldownRemaining()
    preClickWasActive = IsCallboardActive()
    preClickWasUsable = IsSummonSpellUsable()

    if preClickWasActive then
      RT.ApplySecureMacroButtonAttributes(button, "", "callboard active")
    else
      ApplySummonButtonAttributes()
    end
    end)
  button:SetScript("PostClick", function()
    if preClickWasActive then
      RT.ResumeRollingAfterCallboardActive("secure button active")
      QueueCallboardFollowup("secure button active")
    elseif preClickCooldownRemaining and preClickCooldownRemaining > 0 then
      RT.api:Report(RT.api:Problem("CONTROL.SUMMON_ON_COOLDOWN", { cooldown = math.ceil(preClickCooldownRemaining) }))
    elseif not preClickWasUsable then
      RT.api:Report(RT.api:Problem("CONTROL.SUMMON_UNUSABLE", { spell = RT.GetSummonSpellName(), target = tostring(state.targetName or "") }))
    else
      RT.BeginSummonAttempt("secure button")
    end

    ApplySummonButtonAttributes()
    UpdateSummonStatus()
    end)
  button:SetScript("OnDragStart", StartMovingButton)
  button:SetScript("OnDragStop", StopMovingButton)
  Skin.HoverTip(button, "ADDON_NAME_TOOLTIP", nil, function()
    if RT.IsSummonBlockedIndoors() then
      GameTooltip:AddLine(L.SUMMON_BLOCKED_INDOORS, 1, 0.3, 0.3)
    else
      GameTooltip:AddLine(L.SUMMON_BUTTON_CLICK_HINT, 1, 1, 1)
    end
    GameTooltip:AddLine(L.SUMMON_BUTTON_DRAG_HINT, 0.8, 0.8, 0.8)
    end)
end

local function CreateToolbar()
  local content = controlFrame.content
  local listsButton = Skin.MakeButton(content, {
    name = "AutoCallboardListsButton",
    textKey = "BUTTON_LISTS",
    points = { { "TOPLEFT", content, "TOPLEFT", 0, 0 } },
    onClick = RT.ToggleListsWindow,
    tipKey = "LISTS_BUTTON_TOOLTIP",
  })
  controlFrame.listsButton = listsButton

  local buildsButton = Skin.MakeButton(content, {
    name = "AutoCallboardBuildsButton",
    textKey = "BUTTON_BUILDS",
    points = { { "LEFT", listsButton, "RIGHT", 5, 0 } },
    onClick = function() RT.ToggleBuildsWindow() end,
    tipKey = "BUILDS_BUTTON_TOOLTIP",
    tip = function()
      local activeBuild = EbonAPI.State.activeBuild()
      if activeBuild then
        GameTooltip:AddLine(string.format(L.BUILDS_BUTTON_ACTIVE, RT.BuildLabel(activeBuild)), 1, 1, 1)
      end
      end,
  })
  controlFrame.buildsButton = buildsButton

  CreateSummonButton(controlFrame.buildsButton or listsButton)

  local mainStartButton = MakeActionButton("AutoCallboardStartButton", L.BUTTON_START, "LEFT", button, "RIGHT", 5, 0, nil, true)
  controlFrame.startButton = mainStartButton
  RT.ConfigureStartButton(mainStartButton)
  UpdateRollToggleButtonState(mainStartButton, true)
  controlFrame.shareButton = MakeActionButton(
      "AutoCallboardShareButton",
      L.BUTTON_SHARE,
      "LEFT",
      mainStartButton,
      "RIGHT",
      4,
      0,
      function()
        RT.ShareAcceptedQuest("main button")
      end,
      nil,
      "SHARE_BUTTON_TOOLTIP"
    )
  Localized(controlFrame.shareButton, "BUTTON_SHARE")
  controlFrame.questButton = MakeActionButton(
      "AutoCallboardQuestsButton",
      L.BUTTON_QUESTS,
      "LEFT",
      controlFrame.shareButton,
      "RIGHT",
      4,
      0,
      RT.ToggleQuestPanel
    )
  RT.UpdateShareButtonState()
end

local function CreateCallboardButton()
  CreateControlFrame()
  CreateHeaderButtons()
  CreateToolbar()

  summonStatusText = controlFrame.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  RT.summonStatusText = summonStatusText
  summonStatusText:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -5)
  summonStatusText:SetWidth(256)
  summonStatusText:SetJustifyH("LEFT")
  Skin.MutedText(summonStatusText)
  UpdateSummonStatus()

  Lib.setShown(controlFrame, state.buttonShown)

  if state.buttonShown and state.questPanelExpanded then
    RT.SetQuestPanelExpanded(true)
  end
end

RT.CreateCallboardButton = CreateCallboardButton
RT.CreateMinimapButton = CreateMinimapButton

RT.ApplySummonButtonAttributes = function(...)
  return ApplySummonButtonAttributes(...)
end

RT.PositionMinimapButton = function(...)
  return PositionMinimapButton(...)
end

RT.SetCallboardButtonText = function(text)
  if button then
    button:SetText(text)
  end
end
