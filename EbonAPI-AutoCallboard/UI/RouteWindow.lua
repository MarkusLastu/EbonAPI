local Core = AutoCallboardCore
local Skin = AutoCallboardSkin
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime

local CONTENT_WIDTH = 300
local ROW_GAP = 2
local VISIBLE_ROWS = 16
local TOOLBAR_GAP = 6
local GROUP_GAP = 8
local ROW_RIGHT = 4
local EMPTY_GAP = 4
local INDENT = 12

local WINDOW_NAME = "AutoCallboardRouteWindow"

local COMPACT_WIDTH = 240
local COMPACT_STRATA = "FULLSCREEN_DIALOG"
local FULL_STRATA = "HIGH"
local ICON_RECORD = [[Interface\AddOns\EbonAPI-AutoCallboard\Media\Record]]
local ICON_PLAY = [[Interface\AddOns\EbonAPI-AutoCallboard\Media\Play]]
local ICON_SKIP = [[Interface\AddOns\EbonAPI-AutoCallboard\Media\Skip]]
local ICON_STOP = [[Interface\AddOns\EbonAPI-AutoCallboard\Media\Stop]]
local ICON_LOOP = [[Interface\AddOns\EbonAPI-AutoCallboard\Media\Loop]]
local RECORD_RED = { 0.86, 0.16, 0.16, 1 }

local RECORD_TIP = { tipTitle = "ROUTE_BUTTON_RECORD", tipBody = "ROUTE_BUTTON_RECORD_TOOLTIP" }
local RECORD_STOP_TIP = { tipTitle = "ROUTE_BUTTON_RECORD_STOP", tipBody = "ROUTE_BUTTON_RECORD_STOP_TOOLTIP" }
local PLAY_TIP = { tipTitle = "ROUTE_BUTTON_PLAY", tipBody = "ROUTE_BUTTON_PLAY_TOOLTIP" }
local PLAY_STOP_TIP = { tipTitle = "ROUTE_BUTTON_PLAY_STOP", tipBody = "ROUTE_BUTTON_PLAY_STOP_TOOLTIP" }
local SKIP_TIP = { tipTitle = "ROUTE_BUTTON_SKIP", tipBody = "ROUTE_BUTTON_SKIP_TOOLTIP" }

RT.ROUTE_ICONS = { record = ICON_RECORD, play = ICON_PLAY, skip = ICON_SKIP, stop = ICON_STOP, loop = ICON_LOOP }

local routeWindow
local rows = {}
local expanded = {}
local scrollOffset = 0
local entries = {}

local function AccountProfile()
  return RT.GetAccountProfile()
end

local function Report(code, facts)
  RT.api:Report(RT.api:Problem(code, facts or {}))
end

local function Reject(action, route, facts, stepIndex, result)
  if type(result) == "table" and result.code then
    RT.api:Report(result)
  else
    local found = Core.findRoute(AccountProfile(), route.id)
    local missing = not found or (stepIndex ~= nil and not (found.steps and found.steps[stepIndex]))
    local data = facts or {}

    data.route = route.name
    data.action = action
    Report(missing and "ROUTEWINDOW.ROUTE_MISSING" or "ROUTEWINDOW.CHANGE_REFUSED", data)
  end

  RT.RefreshRouteWindow()
end

local function RunDraftChange(action, route, change)
  if not RT.CanEditRoutes() then
    Report("ROUTEWINDOW.EDIT_LOCKED", { route = route.name })
  elseif #(RT.GetRouteDraft()) == 0 then
    Report("ROUTEWINDOW.DRAFT_EMPTY")
  else
    local ok, problem = change(route.id)

    if not ok then
      Reject(action, route, nil, nil, problem)
    end
  end

  RT.RefreshRouteWindow()
end

local function ExpansionKey(kind, id)
  return kind .. ":" .. tostring(id)
end

local function IsExpanded(kind, id)
  return expanded[ExpansionKey(kind, id)] and true or false
end

local function ToggleExpanded(kind, id)
  local key = ExpansionKey(kind, id)
  expanded[key] = not expanded[key] or nil
end

local function Marker(open)
  return open and "-" or "+"
end

local function AppendLines(list, steps, route)
  for index = 1, #(steps) do
    local step = steps[index]

    table.insert(list, {
      kind = route and "step" or "draftStep",
      route = route,
      stepIndex = index,
      depth = 1,
      step = step,
    })

    if step.actions then
      for actionIndex = 1, #(step.actions) do
        local action = step.actions[actionIndex]

        if Core.routeActionHasLine(action) then
          table.insert(list, {
            kind = route and "action" or "draftAction",
            route = route,
            stepIndex = index,
            actionIndex = actionIndex,
            depth = 2,
            action = action,
          })
        end
      end
    end
  end
end

local function LineText(entry, titles)
  if entry.action then
    return Core.routeActionLine(entry.action, titles)
  end

  return Core.routeStepLine(entry.step, titles)
end

local function BuildEntries()
  local list = {}
  local draft = RT.GetRouteDraft()

  if #(draft) > 0 or RT.IsRecordingRoute() then
    local open = IsExpanded("draft", 0)

    table.insert(list, { kind = "draft", depth = 0, open = open })

    if open then
      AppendLines(list, draft)
    end
  end

  local route = RT.GetActiveRoute()

  if route then
    local open = not IsExpanded("folded", route.id)

    table.insert(list, { kind = "route", route = route, depth = 0, open = open })

    if open then
      AppendLines(list, route.steps, route)
    end
  end

  return list
end

local function IsCurrentBlock(entry, activeId, currentBlock)
  return entry.kind == "step" and currentBlock ~= nil and entry.route.id == activeId
    and entry.stepIndex == currentBlock
end

local function RowText(entry, current)
  if current then
    return "> " .. tostring(entry.text or "")
  end

  if entry.kind == "draft" then
    return Marker(entry.open) .. " " .. L.ROUTE_DRAFT_TITLE
  end

  if entry.kind == "route" then
    return Marker(entry.open) .. " " .. Core.routeTitle(entry.route)
  end

  return tostring(entry.text or "")
end

local RequestSaveDraft

local function RequestSaveCategory(name, onCancel)
  local profile = AccountProfile()
  local choices = {}

  for category = 1, Core.routeCategoryCount() do
    choices[category] = {
      text = string.format(L.ROUTE_CATEGORY_CHOICE, Core.routeCategoryName(category),
        tostring(Core.routeCount(profile, category))),
      value = category,
    }
  end

  Skin.Dialog({
    title = L.ROUTE_CATEGORY_TITLE,
    body = string.format(L.ROUTE_CATEGORY_BODY, tostring(name)),
    choices = choices,
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function(category)
      if #(RT.GetRouteDraft()) == 0 then
        Report("ROUTEWINDOW.DRAFT_EMPTY")
      elseif Core.routesFull(AccountProfile(), category) then
        Report("ROUTEWINDOW.ROUTES_FULL", { category = Core.routeCategoryName(category), limit = Core.MAX_SAVED_ROUTES })
      else
        local saved, problem = RT.SaveRouteDraftAs(name, category)

        if not saved then
          if type(problem) == "table" and problem.code then
            RT.api:Report(problem)
          else
            Report("ROUTEWINDOW.CHANGE_REFUSED", { route = tostring(name), action = "save" })
          end
        end
      end

      RT.RefreshRouteWindow()
      end,
    onCancel = onCancel,
  })
end

RequestSaveDraft = function(onCancel, name)
  if #(RT.GetRouteDraft()) == 0 then
    Report("ROUTEWINDOW.DRAFT_EMPTY")
    return
  end

  Skin.Dialog({
    title = L.ROUTE_NEW_TITLE,
    body = "",
    editBox = { default = name or Core.peekNextRouteName(AccountProfile()), maxLetters = Core.MAX_SELECTION_NAME_LENGTH },
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function(text)
      RequestSaveCategory(text, function()
        RequestSaveDraft(onCancel, text)
        end)
      end,
    onCancel = onCancel,
  })
end

local RequestNameRecording

local function RequestDiscardRecording()
  Skin.Dialog({
    title = L.ROUTE_DISCARD_TITLE,
    body = string.format(L.ROUTE_DISCARD_TEXT, tostring(#(RT.GetRouteDraft()))),
    acceptText = L.BUTTON_OKAY,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function()
      RT.ClearRouteDraft()
      end,
    onCancel = function()
      RequestNameRecording()
      end,
  })
end

RequestNameRecording = function()
  RequestSaveDraft(RequestDiscardRecording)
end

local function ToggleRecording()
  if not RT.IsRecordingRoute() then
    RT.StartRouteRecording("button")
    return
  end

  RT.StopRouteRecording("button")

  if #(RT.GetRouteDraft()) > 0 then
    RequestNameRecording()
  end
end

local function RequestRenameRoute(route)
  Skin.Dialog({
    title = string.format(L.LISTS_RENAME_DIALOG_TITLE, route.name),
    body = "",
    editBox = { default = route.name, maxLetters = Core.MAX_SELECTION_NAME_LENGTH },
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function(text)
      local nextProfile, ok = Core.renameRoute(AccountProfile(), route.id, text)

      if not ok then
        Reject("rename", route, nil, nil, ok)
        return
      end

      RT.SaveAccountProfile(nextProfile)
      RT.RefreshRouteWindow()
      end,
  })
end

local function RequestDeleteRoute(route)
  Skin.Dialog({
    title = route.name,
    body = string.format(L.ROUTE_DELETE_CONFIRM_TEXT, route.name),
    acceptText = L.BUTTON_DELETE,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function()
      local nextProfile, ok = Core.deleteRoute(AccountProfile(), route.id)

      if not ok then
        Reject("delete", route)
        return
      end

      RT.SaveAccountProfile(nextProfile)

      if RT.GetActiveRouteId() == route.id then
        RT.SetActiveRouteId(nil)
      end

      RT.RefreshRouteWindow()
      end,
  })
end

local function RequestOverwriteRoute(route)
  Skin.Dialog({
    title = route.name,
    body = string.format(L.ROUTE_OVERWRITE_CONFIRM_TEXT, route.name),
    acceptText = L.BUTTON_OKAY,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function()
      RunDraftChange("overwrite", route, RT.OverwriteRouteFromDraft)
      end,
  })
end

local function EnsureMenu()
  if not RT.routeContextMenu then
    RT.routeContextMenu = Skin.Menu("AutoCallboardRouteContextMenu")
  end

  return RT.routeContextMenu
end

function RT.ToggleLoadedRoute(id)
  if not RT.CanEditRoutes() then
    local found = Core.findRoute(AccountProfile(), id)

    Report("ROUTEWINDOW.EDIT_LOCKED", { route = found and found.name or tostring(id) })
    return false
  end

  if RT.GetActiveRouteId() == id then
    RT.SetActiveRouteId(nil)
  else
    RT.SetActiveRouteId(id)
  end

  return true
end

local BuildRouteMenu
local BuildRouteDifficultyMenu

local function BuildCategoryMenu(menu, route)
  menu:Reset()
  menu:AddItem(route.name, { header = true })
  menu:AddItem("< " .. L.ROUTE_MENU_CATEGORY, {
    keepOpen = true,
    onClick = function() BuildRouteMenu(menu, route) end,
  })

  for category = 1, Core.routeCategoryCount() do
    menu:AddItem(Core.routeCategoryName(category), {
      checked = route.category == category,
      onClick = function()
        local nextProfile, ok, err = Core.setRouteCategory(AccountProfile(), route.id, category)

        if ok then
          RT.SaveAccountProfile(nextProfile)
          RT.RefreshRouteWindow()
        elseif err == "full" then
          Report("ROUTEWINDOW.ROUTES_FULL", { category = Core.routeCategoryName(category), limit = Core.MAX_SAVED_ROUTES })
          RT.RefreshRouteWindow()
        else
          Reject("category", route, { category = Core.routeCategoryName(category) }, nil, err)
        end
        end,
    })
  end

  menu:Layout()
end

BuildRouteDifficultyMenu = function(menu, route)
  menu:Reset()
  menu:AddItem(route.name, { header = true })
  menu:AddItem("< " .. L.ROUTE_MENU_START_DIFFICULTY, {
    keepOpen = true,
    onClick = function() BuildRouteMenu(menu, route) end,
  })

  RT.AddDifficultySlider(menu, route.difficulty, function(tier)
    local nextProfile, ok = Core.setRouteDifficulty(AccountProfile(), route.id, tier)

    if ok then
      RT.SaveAccountProfile(nextProfile)
      RT.RefreshRouteWindow()
    else
      Reject("difficulty", route)
    end
    end)

  menu:Layout()
end

BuildRouteMenu = function(menu, route)
  local hasDraft = #(RT.GetRouteDraft()) > 0
  local locked = not RT.CanEditRoutes()

  menu:Reset()
  menu:AddItem(route.name, { header = true })
  menu:AddItem(L.ROUTE_MENU_START_DIFFICULTY, {
    arrow = true,
    keepOpen = true,
    disabled = locked,
    onClick = function() BuildRouteDifficultyMenu(menu, route) end,
  })

  menu:AddItem(RT.GetActiveRouteId() == route.id and L.ROUTE_MENU_UNLOAD or L.ROUTE_MENU_LOAD, {
    disabled = locked,
    onClick = function() RT.ToggleLoadedRoute(route.id) end,
  })

  menu:AddItem(L.ROUTE_MENU_CATEGORY, {
    arrow = true,
    keepOpen = true,
    disabled = locked,
    onClick = function() BuildCategoryMenu(menu, route) end,
  })

  local shared = Core.isRouteShared(route)

  menu:AddItem(shared and L.ROUTE_MENU_UNSHARE or L.ROUTE_MENU_SHARE, {
    disabled = locked,
    onClick = function() RT.ShareRoute(route.id, not shared) end,
  })

  menu:AddItem(L.ROUTE_MENU_APPEND, {
    disabled = locked or not hasDraft,
    onClick = function()
      RunDraftChange("append", route, RT.AppendRouteFromDraft)
      end,
  })
  menu:AddItem(L.ROUTE_MENU_OVERWRITE, {
    disabled = locked or not hasDraft,
    onClick = function() RequestOverwriteRoute(route) end,
  })
  menu:AddItem(L.LISTS_MENU_RENAME, {
    disabled = locked,
    onClick = function() RequestRenameRoute(route) end,
  })
  menu:AddItem(L.LISTS_MENU_DELETE, {
    disabled = locked,
    onClick = function() RequestDeleteRoute(route) end,
  })

  menu:Layout()
end

function RT.ShowRouteMenu(row, route)
  local menu = EnsureMenu()
  BuildRouteMenu(menu, route)
  menu:OpenAt(row, "TOPLEFT", "TOPRIGHT", 4, 2)
end

local function BuildStepMenu(menu, entry)
  local step = entry.route.steps[entry.stepIndex]
  local locked = not RT.CanEditRoutes()

  menu:Reset()
  menu:AddItem(entry.text or "", { header = true })

  if step and step.resting then
    menu:AddItem(L.LISTS_MENU_DIFFICULTY, {
      arrow = true,
      keepOpen = true,
      disabled = locked,
      onClick = function()
        menu:Reset()
        menu:AddItem(entry.text or "", { header = true })
        menu:AddItem("< " .. L.LISTS_MENU_DIFFICULTY, {
          keepOpen = true,
          onClick = function() BuildStepMenu(menu, entry) end,
        })

        RT.AddDifficultySlider(menu, step.difficulty, function(tier)
          local nextProfile, ok = Core.setRouteStepDifficulty(AccountProfile(), entry.route.id,
            entry.stepIndex, tier)

          if ok then
            RT.SaveAccountProfile(nextProfile)
            RT.RefreshRouteWindow()
          else
            Reject("step_difficulty", entry.route, { step = entry.stepIndex }, entry.stepIndex)
          end
          end)

        menu:Layout()
        end,
    })
  else
    menu:AddItem(L.ROUTE_MENU_DIFFICULTY_LOCKED, { disabled = true })
  end

  menu:AddItem(L.ROUTE_MENU_POINT_AT, {
    disabled = not (step and step.map and step.map ~= "" and step.x and step.y),
    onClick = function()
      RT.SetRouteArrowTarget(step, entry.actionIndex and step.actions[entry.actionIndex])
      end,
  })
  menu:AddItem(L.ROUTE_MENU_DELETE_LINE, {
    disabled = locked,
    onClick = function()
      local profile = AccountProfile()
      local nextProfile, ok

      if entry.kind == "action" then
        nextProfile, ok = Core.deleteRouteAction(profile, entry.route.id, entry.stepIndex, entry.actionIndex)
      else
        nextProfile, ok = Core.deleteRouteStep(profile, entry.route.id, entry.stepIndex)
      end

      if ok then
        RT.SaveAccountProfile(nextProfile)
        RT.RefreshRouteWindow()
      else
        Reject("delete_line", entry.route, { step = entry.stepIndex }, entry.stepIndex)
      end
      end,
  })
  menu:Layout()
end

local function ShowStepMenu(row, entry)
  local menu = EnsureMenu()
  BuildStepMenu(menu, entry)
  menu:OpenAt(row, "TOPLEFT", "TOPRIGHT", 4, 2)
end

local function OnRowClick(row, mouseButton)
  local entry = row.entry

  if not entry then
    return
  end

  if mouseButton == "RightButton" then
    if entry.kind == "route" then
      RT.ShowRouteMenu(row, entry.route)
    elseif entry.kind == "step" or entry.kind == "action" then
      ShowStepMenu(row, entry)
    end

    return
  end

  if entry.kind == "step" or entry.kind == "action" then
    if RT.IsRecordingRoute() then
      Report("ROUTEWINDOW.PLAYBACK_REFUSED", { route = entry.route.name })
      return
    end

    local started, problem = RT.StartRoutePlayback("row", entry.route.id, entry.stepIndex)

    if not started and type(problem) == "table" and problem.code then
      RT.api:Report(problem)
    end

    return
  end

  if entry.kind == "route" then
    ToggleExpanded("folded", entry.route.id)
  elseif entry.kind == "draft" then
    ToggleExpanded("draft", 0)
  else
    return
  end

  RT.RefreshRouteWindow()
end

local function Scroll(delta)
  scrollOffset = scrollOffset + delta
  RT.RefreshRouteWindow()
end

local function CreateRow(index)
  local row = Skin.Row(routeWindow.content, "AutoCallboardRouteRow" .. index, "LeftButtonUp", "RightButtonUp")

  row:SetScript("OnClick", OnRowClick)
  row:HookScript("OnEnter", function(self)
    if self.entry and self.entry.text and self.entry.text ~= "" then
      EbonAPI.Bricks.tip(self, self.entry.text)

      if self.entry.kind == "step" or self.entry.kind == "action" then
        GameTooltip:AddLine(L.ROUTE_ROW_PLAY_HINT, 1, 1, 1)
      end

      GameTooltip:Show()
    end
    end)
  row:HookScript("OnLeave", function()
    GameTooltip:Hide()
    end)
  row:EnableMouseWheel(true)
  row:SetScript("OnMouseWheel", function(_, delta) Scroll(-delta) end)

  return row
end

local Toggle = RT.ShowIf

local function BodyTop()
  return math.max(routeWindow.transport:GetHeight(), routeWindow.browsers:GetHeight()) + TOOLBAR_GAP
end

local function RowStride()
  return rows[1]:GetHeight() + ROW_GAP
end

local function ContentWidth()
  return math.max(CONTENT_WIDTH, routeWindow.transport:GetWidth() + GROUP_GAP + routeWindow.browsers:GetWidth())
end

local function CompactLine()
  if RT.IsPlayingRoute() then
    local route, current = RT.GetActiveRoute(), RT.RouteCurrentBlock()

    if route and current then
      return Core.routeStepLine(route.steps[current])
    end

    return L.ROUTE_COMPACT_END
  end

  local line = RT.LastRecordedRouteLine()

  if line == "" then
    line = RT.IsRecordingRoute() and L.ROUTE_COMPACT_WAITING or L.ROUTE_COMPACT_IDLE
  end

  return line
end

local function SetTransport(button, busy, idleIcon, idleColor, idleTip, busyTip, enabled)
  local tip = busy and busyTip or idleTip

  if busy then
    Skin.SetButtonIcon(button, ICON_STOP)
  else
    Skin.SetButtonIcon(button, idleIcon, idleColor)
  end

  Skin.HoverTip(button, tip.tipTitle, tip.tipBody)
  RT.SetButtonEnabled(button, enabled)
end

local function RefreshCompact()
  local line = CompactLine()

  for i = 2, VISIBLE_ROWS do
    rows[i]:Hide()
    rows[i].entry = nil
  end

  local row = rows[1]
  row.entry = nil
  row.selected = false
  row.title:SetText(line)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", routeWindow.content, "TOPLEFT", 0, 0)
  row:SetPoint("RIGHT", routeWindow.content, "RIGHT", 0, 0)
  Skin.PaintRow(row, false)
  row:Show()

  Toggle(routeWindow.emptyLabel, false)
  Toggle(routeWindow.scrollUp, false)
  Toggle(routeWindow.scrollDown, false)
  Toggle(routeWindow.playButton, false)
  Toggle(routeWindow.skipButton, false)
  Toggle(routeWindow.loopButton, false)
  Toggle(routeWindow.routesButton, false)
  Toggle(routeWindow.libraryButton, false)
  Toggle(routeWindow.recordButton, false)

  Skin.SizeWindow(routeWindow, COMPACT_WIDTH, row:GetHeight())
  routeWindow:SetFrameStrata(COMPACT_STRATA)
end

function RT.RefreshRouteWindow()
  RT.RefreshRouteBrowsers()

  if not routeWindow or not routeWindow:IsShown() then
    return
  end

  local compact = RT.IsRouteWindowCompact()

  routeWindow.compactButton:SetText(compact and L.ROUTE_BUTTON_EXPAND or L.ROUTE_BUTTON_COMPACT)

  if compact then
    RefreshCompact()
    return
  end

  routeWindow:SetFrameStrata(FULL_STRATA)
  Toggle(routeWindow.playButton, true)
  Toggle(routeWindow.skipButton, true)
  Toggle(routeWindow.loopButton, true)
  Toggle(routeWindow.routesButton, true)
  Toggle(routeWindow.libraryButton, true)
  Toggle(routeWindow.recordButton, true)
  routeWindow.transport:Layout()
  routeWindow.browsers:Layout()

  local bodyTop, stride = BodyTop(), RowStride()

  Skin.SizeWindow(routeWindow, ContentWidth(), bodyTop + VISIBLE_ROWS * stride)

  entries = BuildEntries()

  local activeId = RT.GetActiveRouteId()
  local currentBlock = RT.RouteCurrentBlock()

  local maxOffset = math.max(0, #(entries) - VISIBLE_ROWS)

  if scrollOffset > maxOffset then
    scrollOffset = maxOffset
  end

  if scrollOffset < 0 then
    scrollOffset = 0
  end

  local titles

  for i = 1, VISIBLE_ROWS do
    local row = rows[i]
    local entry = entries[i + scrollOffset]

    row.entry = entry

    if not entry then
      row:Hide()
    else
      if (entry.step or entry.action) and not entry.text then
        titles = titles or RT.QuestLogTitles()
        entry.text = LineText(entry, titles)
      end

      local current = IsCurrentBlock(entry, activeId, currentBlock)

      row.selected = current or entry.kind == "route"
      row.title:SetText(RowText(entry, current))
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", routeWindow.content, "TOPLEFT", entry.depth * INDENT, -(bodyTop + (i - 1) * stride))
      row:SetPoint("RIGHT", routeWindow.content, "RIGHT", -ROW_RIGHT, 0)
      Skin.PaintRow(row, row.selected)
      row:Show()
    end
  end

  Toggle(routeWindow.emptyLabel, #(entries) == 0)
  Toggle(routeWindow.scrollUp, scrollOffset > 0)
  Toggle(routeWindow.scrollDown, scrollOffset < maxOffset)

  local recording = RT.IsRecordingRoute()
  local playing = RT.IsPlayingRoute()

  SetTransport(routeWindow.recordButton, recording, ICON_RECORD, RECORD_RED, RECORD_TIP, RECORD_STOP_TIP,
    not playing)
  SetTransport(routeWindow.playButton, playing, ICON_PLAY, nil, PLAY_TIP, PLAY_STOP_TIP,
    playing or (not recording and activeId ~= nil))
  RT.SetButtonEnabled(routeWindow.skipButton, currentBlock ~= nil)
  Skin.SetButtonSelected(routeWindow.loopButton, RT.IsRouteLooping())
end

function RT.CreateRouteWindow()
  routeWindow = Skin.Window(WINDOW_NAME, {
    width = CONTENT_WIDTH,
    height = CONTENT_WIDTH,
    titleKey = "ROUTE_WINDOW_TITLE",
    noEsc = true,
    movable = true,
    point = { "CENTER", UIParent, "CENTER", 0, 0 },
    buttons = {
      {
        onClick = function()
          RT.SetRouteWindowCompact(not RT.IsRouteWindowCompact())
          end,
        tipTitle = "ROUTE_BUTTON_COMPACT",
        tipBody = "ROUTE_BUTTON_COMPACT_TOOLTIP",
      },
    },
  })

  RT.routeWindow = routeWindow
  local content = routeWindow.content

  routeWindow.closeButton:HookScript("OnClick", function()
    RT.SetRouteWindowOpen(false)
    end)

  routeWindow.compactButton = routeWindow.headButtons[1]
  routeWindow.compactButton:SetText(L.ROUTE_BUTTON_COMPACT)

  routeWindow.transport = Skin.ButtonRow(content, { point = { "TOPLEFT", content, "TOPLEFT", 0, 0 } })
  routeWindow.browsers = Skin.ButtonRow(content, { point = { "TOPRIGHT", content, "TOPRIGHT", 0, 0 } })

  routeWindow.recordButton = Skin.MakeButton(routeWindow.transport, {
    icon = ICON_RECORD,
    iconColor = RECORD_RED,
    onClick = ToggleRecording,
    tipTitle = RECORD_TIP.tipTitle,
    tipBody = RECORD_TIP.tipBody,
  })

  routeWindow.playButton = Skin.MakeButton(routeWindow.transport, {
    icon = ICON_PLAY,
    onClick = function() RT.ToggleRoutePlayback() end,
    tipTitle = PLAY_TIP.tipTitle,
    tipBody = PLAY_TIP.tipBody,
  })

  routeWindow.skipButton = Skin.MakeButton(routeWindow.transport, {
    icon = ICON_SKIP,
    onClick = function() RT.SkipRouteBlock() end,
    tipTitle = SKIP_TIP.tipTitle,
    tipBody = SKIP_TIP.tipBody,
  })

  routeWindow.loopButton = Skin.MakeButton(routeWindow.transport, {
    icon = ICON_LOOP,
    onClick = function() RT.SetRouteLooping(not RT.IsRouteLooping()) end,
    tipTitle = "ROUTE_BUTTON_LOOP",
    tipBody = "ROUTE_BUTTON_LOOP_TOOLTIP",
  })

  routeWindow.routesButton = Skin.MakeButton(routeWindow.browsers, {
    textKey = "ROUTES_BROWSER_TITLE",
    onClick = function() RT.ToggleRoutesWindow() end,
    tipKey = "ROUTES_BUTTON_TOOLTIP",
  })

  routeWindow.libraryButton = Skin.MakeButton(routeWindow.browsers, {
    textKey = "LIBRARY_BUTTON",
    onClick = function() RT.ToggleLibraryWindow() end,
    tipTitle = "LIBRARY_WINDOW_TITLE",
    tipBody = "LIBRARY_BUTTON_TOOLTIP",
  })

  routeWindow.scrollUp = Skin.MakeButton(content, {
    text = "^",
    points = { { "TOPRIGHT", content, "TOPRIGHT", 0, -BodyTop() } },
    onClick = function() Scroll(-1) end,
  })
  routeWindow.scrollUp:Hide()

  routeWindow.scrollDown = Skin.MakeButton(content, {
    text = "v",
    points = { { "BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0 } },
    onClick = function() Scroll(1) end,
  })
  routeWindow.scrollDown:Hide()

  routeWindow.emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  routeWindow.emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(BodyTop() + EMPTY_GAP))
  routeWindow.emptyLabel:SetPoint("RIGHT", content, "RIGHT", 0, 0)
  routeWindow.emptyLabel:SetJustifyH("LEFT")
  RT.Localized(routeWindow.emptyLabel, "ROUTE_WINDOW_EMPTY")
  Skin.MutedText(routeWindow.emptyLabel)

  routeWindow:EnableMouseWheel(true)
  routeWindow:SetScript("OnMouseWheel", function(_, delta) Scroll(-delta) end)

  for i = 1, VISIBLE_ROWS do
    rows[i] = CreateRow(i)
    rows[i]:Hide()
  end

  routeWindow:Hide()

  return routeWindow
end

function RT.ToggleRouteWindow()
  if routeWindow and routeWindow:IsShown() then
    RT.SetRouteWindowOpen(false)
    routeWindow:Hide()
    return
  end

  RT.ShowRouteWindow()

  if routeWindow.Raise then
    routeWindow:Raise()
  end
end

function RT.ShowRouteWindow()
  if not routeWindow then
    RT.CreateRouteWindow()
  end

  RT.SetRouteWindowOpen(true)
  routeWindow:Show()
  RT.RefreshRouteWindow()
end

function RT.RestoreRouteWindow()
  if RT.IsRouteWindowOpen() then
    RT.ShowRouteWindow()
  end
end
