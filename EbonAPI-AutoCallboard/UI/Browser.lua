local Core = AutoCallboardCore
local Skin = AutoCallboardSkin
local RT = AutoCallboardRuntime
local IsUnder = RT.IsUnder

local LIST_WIDTH = 214
local GROUP_OPEN_WIDTH = 202
local GROUP_BAND_WIDTH = 30
local PANEL_GAP = 4
local PANEL_TOP = 5
local PANEL_HEADER_GAP = 3
local PANEL_BOTTOM = 6
local PANEL_INSET = 6
local SCROLL_INSET = 5
local SCROLL_ROOM = 10
local ROW_GAP = 2
local VISIBLE_ROWS = 10
local ANIMATION_SECONDS = 0.3

local DROP_LINE_HEIGHT = 2
local DRAG_SOURCE_ALPHA = 0.4
local DROP_REFUSED_BORDER = { 1, 0.25, 0.25, 1 }

local BAND_LABEL_TOP = 22
local BAND_LABEL_BOTTOM = 22
local BAND_STACK_LINE = 11
local BAND_SHORT_CHARS = 3
local BAND_LABEL_BOTTOM_UP = true

local rowHeight, panelHeader, panelHeight, bandLabelSpan

local COLLAPSE_ALL = 0
local LIST_KEY = 0

local instances = {}

local function StackedText(value)
  local chars = {}
  local limit = math.floor(bandLabelSpan / BAND_STACK_LINE)

  for character in string.gmatch(tostring(value or ""), "[\1-\127\194-\244][\128-\191]*") do
    chars[#(chars) + 1] = character

    if #(chars) >= limit then
      break
    end
  end

  return table.concat(chars, "\n")
end

local function EnsureBandRotator(band)
  if band.rotator ~= nil then
    return band.rotator
  end

  band.rotator = false

  if type(band.labelHolder.CreateAnimationGroup) ~= "function" then
    return false
  end

  local group = RT.api:Guard("Browser.BandRotator", function()
    local created = band.labelHolder:CreateAnimationGroup()
    local rotation = created:CreateAnimation("Rotation")

    rotation:SetDegrees(BAND_LABEL_BOTTOM_UP and 90 or -90)
    rotation:SetDuration(0)
    rotation:SetOrigin("CENTER", 0, 0)
    created:SetLooping("REPEAT")
    created:Play()

    return created
    end)

  if not group then
    return false
  end

  band.rotator = group

  return group
end

local function ResolveBandLabelMode(fontString)
  local mode = RT.bandLabelMode or "auto"

  if mode ~= "auto" then
    return mode
  end

  if type(fontString.SetRotation) == "function" then
    return "rotate"
  end

  return "stack"
end

local function ApplyBandLabel(band, name)
  local mode = ResolveBandLabelMode(band.label)

  if mode == "anim" and not EnsureBandRotator(band) then
    mode = "stack"
  end

  RT.bandLabelResolved = mode

  band.label:ClearAllPoints()

  if mode == "rotate" or mode == "anim" then
    band.label:SetWidth(bandLabelSpan)
    band.label:SetHeight(14)
    band.label:SetJustifyH("CENTER")
    band.label:SetJustifyV("MIDDLE")
    band.label:SetPoint("CENTER", band.labelHolder, "CENTER", 0, 0)
    band.label:SetText(name)

    if mode == "rotate" then
      band.label:SetRotation(BAND_LABEL_BOTTOM_UP and (math.pi / 2) or -(math.pi / 2))
    end

    return
  end

  band.label:SetWidth(GROUP_BAND_WIDTH - 6)
  band.label:SetHeight(bandLabelSpan)
  band.label:SetJustifyH("CENTER")
  band.label:SetJustifyV("MIDDLE")
  band.label:SetPoint("CENTER", band.labelHolder, "CENTER", 0, 0)
  band.label:SetText(mode == "short" and Core.truncateLetters(name, BAND_SHORT_CHARS) or StackedText(name))
end

local function Groups(browser)
  return browser.spec.groups() or {}
end

local function FindGroupIndex(browser, id)
  local groups = Groups(browser)

  for i = 1, #(groups) do
    if groups[i].id == id then
      return i, groups[i]
    end
  end

  return nil
end

local function ContainerKeyFor(browser, stored)
  if stored == nil then
    return browser.spec.hasList and LIST_KEY or nil
  end

  if stored == COLLAPSE_ALL then
    return nil
  end

  return stored
end

local function OpenContainerKey(browser)
  return ContainerKeyFor(browser, browser.spec.getOpen())
end

local function IsListOpen(browser)
  return browser.spec.hasList and OpenContainerKey(browser) == LIST_KEY
end

local function OpenGroupId(browser)
  local key = OpenContainerKey(browser)

  if key == nil or key == LIST_KEY then
    return nil
  end

  return key
end

local function ContainerKey(groupId)
  return groupId or "list"
end

local function ScrollOffset(browser, groupId)
  return browser.scrollOffsets[ContainerKey(groupId)] or 0
end

local function SetScrollOffset(browser, groupId, value)
  browser.scrollOffsets[ContainerKey(groupId)] = math.max(0, math.floor((tonumber(value) or 0) + 0.5))
end

local function SetAnimating(browser, flag)
  if browser.spec.onAnimating then
    browser.spec.onAnimating(flag)
  end
end

local Refresh
local BeginEntryDrag
local BeginGroupDrag
local EndDrag
local SetOpen

local function RefreshRowVisual(browser, row)
  local entry = row.entry
  if not entry then
    return
  end

  local selected, disabled = browser.spec.rowState(entry)
  local drag = browser.drag

  Skin.PaintRow(row, selected, disabled)

  if drag then
    row:SetAlpha(drag.id == entry.id and DRAG_SOURCE_ALPHA or 1)
  else
    row:SetAlpha(1)
  end
end

local function RefreshRowVisuals(browser)
  local panels = { browser.listPanel, browser.groupPanel }

  for i = 1, #(panels) do
    local panel = panels[i]

    if panel and panel.rows then
      for j = 1, #(panel.rows) do
        RefreshRowVisual(browser, panel.rows[j])
      end
    end
  end
end

local function Measure(panel)
  if panelHeight then
    return
  end

  rowHeight = panel.rows[1]:GetHeight()
  panelHeader = PANEL_TOP + panel.closeButton:GetHeight() + PANEL_HEADER_GAP
  panelHeight = panelHeader + VISIBLE_ROWS * (rowHeight + ROW_GAP) + PANEL_BOTTOM
  bandLabelSpan = panelHeight - BAND_LABEL_TOP - BAND_LABEL_BOTTOM
end

local function RowRight(panel, scrolling)
  return scrolling and -(panel.scrollUp:GetWidth() + SCROLL_ROOM) or -PANEL_INSET
end

local function CreateRow(browser, parent, name)
  local spec = browser.spec
  local row = Skin.Row(parent, spec.names.row .. tostring(name), "LeftButtonUp", "RightButtonUp")
  row:RegisterForDrag("LeftButton")

  row:SetScript("OnDragStart", function(self)
    if self.entry and spec.canDrag and spec.canDrag(self.entry) then
      BeginEntryDrag(browser, self.entry)
    end
    end)
  row:SetScript("OnDragStop", function()
    EndDrag(browser)
    end)

  row:SetScript("OnClick", function(self, mouseButton)
    if self.entry then
      spec.onRowClick(self, self.entry, mouseButton)
    end
    end)

  row:HookScript("OnEnter", function(self)
    if browser.drag then
      return
    end

    if self.entry then
      spec.rowTooltip(self, self.entry)
    end
    end)

  row:HookScript("OnLeave", function()
    if browser.drag then
      return
    end

    GameTooltip:Hide()
    end)

  return row
end

local function CreatePanel(browser, name, isList)
  local spec = browser.spec
  local panel = Skin.Box(browser.window.content, { name = name })

  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  panel.title:SetJustifyH("LEFT")
  panel.title:SetHeight(14)
  if panel.title.SetWordWrap then
    panel.title:SetWordWrap(false)
  end
  Skin.HeadingText(panel.title)

  if spec.onAdd then
    panel.addButton = Skin.MakeButton(panel, {
      text = "+",
      points = { { "TOPRIGHT", panel, "TOPRIGHT", -PANEL_INSET, -PANEL_TOP } },
      onClick = function()
        spec.onAdd(panel.groupId)
        end,
      tipTitle = spec.addTip and spec.addTip[1],
      tipBody = spec.addTip and spec.addTip[2],
    })
  end

  panel.closeButton = Skin.MakeButton(panel, {
    text = ">>",
    points = { { "TOPLEFT", panel, "TOPLEFT", PANEL_INSET, -PANEL_TOP } },
    onClick = function()
      SetOpen(browser, COLLAPSE_ALL)
      end,
    tipTitle = "LISTS_CLOSE_GROUP_TITLE",
    tipBody = "LISTS_CLOSE_GROUP_TOOLTIP",
  })
  panel.title:SetPoint("LEFT", panel.closeButton, "RIGHT", 6, 0)

  if panel.addButton then
    panel.title:SetPoint("RIGHT", panel.addButton, "LEFT", -6, 0)
  else
    panel.title:SetPoint("RIGHT", panel, "RIGHT", -6, 0)
  end

  if not isList and (spec.groupMenu or spec.moveGroup) then
    panel.headerHit = CreateFrame("Button", nil, panel)
    panel.headerHit:SetPoint("TOPLEFT", panel.closeButton, "TOPRIGHT", 2, 0)
    panel.headerHit:SetPoint("BOTTOMRIGHT", panel.addButton or panel, panel.addButton and "BOTTOMLEFT" or "TOPRIGHT",
      panel.addButton and -2 or -PANEL_INSET, panel.addButton and 0 or -(PANEL_TOP + panel.closeButton:GetHeight()))
    panel.headerHit:RegisterForClicks("RightButtonUp")
    panel.headerHit:RegisterForDrag("LeftButton")
    panel.headerHit:SetScript("OnClick", function(self)
      if spec.groupMenu then
        spec.groupMenu(self, panel.group)
      end
      end)
    panel.headerHit:SetScript("OnDragStart", function()
      if panel.group and spec.moveGroup then
        BeginGroupDrag(browser, panel.group)
      end
      end)
    panel.headerHit:SetScript("OnDragStop", function()
      EndDrag(browser)
      end)
  end

  local function Step(delta)
    SetScrollOffset(browser, panel.groupId, ScrollOffset(browser, panel.groupId) + delta)
    Refresh(browser)
  end

  panel.scrollUp = Skin.MakeButton(panel, {
    text = "^",
    onClick = function() Step(-1) end,
  })
  panel.scrollUp:Hide()

  panel.scrollDown = Skin.MakeButton(panel, {
    text = "v",
    points = { { "BOTTOMRIGHT", panel, "BOTTOMRIGHT", -SCROLL_INSET, PANEL_BOTTOM } },
    onClick = function() Step(1) end,
  })
  panel.scrollDown:Hide()

  panel.scrollText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  panel.scrollText:SetPoint("RIGHT", panel.scrollUp, "RIGHT", 0, 0)
  panel.scrollText:SetPoint("TOP", panel.scrollUp, "BOTTOM", 0, -4)
  panel.scrollText:SetWidth(panel.scrollUp:GetWidth())
  panel.scrollText:SetJustifyH("CENTER")
  Skin.MutedText(panel.scrollText)
  panel.scrollText:Hide()

  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta)
    Step(-delta)
    end)

  panel.emptyLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  panel.emptyLabel:SetJustifyH("LEFT")
  RT.Localized(panel.emptyLabel, spec.emptyKey)
  Skin.MutedText(panel.emptyLabel)

  panel.dropLayer = CreateFrame("Frame", nil, panel)
  panel.dropLayer:SetAllPoints(panel)
  panel.dropLayer:SetFrameLevel(panel:GetFrameLevel() + 10)

  panel.dropLine = panel.dropLayer:CreateTexture(nil, "OVERLAY")
  panel.dropLine:SetTexture(EbonAPI.Bricks.media("solid"))
  panel.dropLine:SetHeight(DROP_LINE_HEIGHT)
  panel.dropLine:Hide()

  panel.rows = {}
  for i = 1, VISIBLE_ROWS do
    local row = CreateRow(browser, panel, tostring(name) .. i)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta)
      Step(-delta)
      end)
    panel.rows[i] = row
  end

  Measure(panel)
  panel.spec.height = panelHeight
  panel:SetHeight(panelHeight)
  panel.scrollUp:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -SCROLL_INSET, -panelHeader)

  for i = 1, VISIBLE_ROWS do
    panel.rows[i]:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_INSET, -(panelHeader + (i - 1) * (rowHeight + ROW_GAP)))
  end

  return panel
end

local function CreateGroupBand(browser, index, isList)
  local spec = browser.spec
  local band = CreateFrame("Button", spec.names.band .. tostring(index), browser.window.content)
  band.isList = isList and true or false
  band:SetWidth(GROUP_BAND_WIDTH)
  band:SetHeight(panelHeight)
  band:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local surface = Skin.Backdrop(band)

  if not isList and spec.moveGroup then
    band:RegisterForDrag("LeftButton")
    band:SetScript("OnDragStart", function(self)
      if self.group then
        BeginGroupDrag(browser, self.group)
      end
      end)
    band:SetScript("OnDragStop", function()
      EndDrag(browser)
      end)
  end

  band.arrow = surface:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  band.arrow:SetPoint("TOP", band, "TOP", 0, -6)
  band.arrow:SetText("<<")
  Skin.ApplyColor(band.arrow, "SetTextColor", "heading")

  band.labelHolder = CreateFrame("Frame", nil, surface)
  band.labelHolder:SetPoint("TOPLEFT", band, "TOPLEFT", 3, -BAND_LABEL_TOP)
  band.labelHolder:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", -3, BAND_LABEL_BOTTOM)

  band.label = band.labelHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  band.label:SetJustifyH("CENTER")

  band.count = surface:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  band.count:SetPoint("BOTTOM", band, "BOTTOM", 0, 6)
  band.count:SetWidth(GROUP_BAND_WIDTH - 6)
  band.count:SetJustifyH("CENTER")
  Skin.MutedText(band.count)

  band:SetScript("OnClick", function(self, mouseButton)
    if not self.isList and not self.group then
      return
    end

    if mouseButton == "RightButton" then
      if not self.isList and spec.groupMenu then
        spec.groupMenu(self, self.group)
      end

      return
    end

    if self.isList then
      SetOpen(browser, nil)
    else
      SetOpen(browser, self.group.id)
    end
    end)

  band:SetScript("OnEnter", function(self)
    if browser.drag then
      return
    end

    Skin.Highlight(self.acbBox, "hover")

    if not self.isList and not self.group then
      return
    end

    local groupId
    local title = spec.listTitle and spec.listTitle() or ""

    if not self.isList then
      groupId = self.group.id
      title = self.group.name
    end

    Skin.OpenTip(self, "ANCHOR_LEFT", title)

    for _, line in ipairs(spec.bandLines(groupId)) do
      GameTooltip:AddLine(line[1], line[2], line[3], line[4])
    end

    GameTooltip:Show()
    end)

  band:SetScript("OnLeave", function(self)
    if browser.drag then
      return
    end

    Skin.Highlight(self.acbBox, nil)
    GameTooltip:Hide()
    end)

  return band
end

local function ContainerWidths(browser)
  local spec = browser.spec
  local animation = browser.animation
  local groups = Groups(browser)
  local widths = {}
  local openKey = OpenContainerKey(browser)

  if spec.hasList then
    widths[LIST_KEY] = (openKey == LIST_KEY) and LIST_WIDTH or GROUP_BAND_WIDTH
  end

  for i = 1, #(groups) do
    local id = groups[i].id
    widths[id] = (id == openKey) and GROUP_OPEN_WIDTH or GROUP_BAND_WIDTH
  end

  if animation then
    local eased = animation.progress

    if animation.openingKey and widths[animation.openingKey] then
      local full = (animation.openingKey == LIST_KEY and spec.hasList) and LIST_WIDTH or GROUP_OPEN_WIDTH
      widths[animation.openingKey] = GROUP_BAND_WIDTH + (full - GROUP_BAND_WIDTH) * eased
    end

    if animation.closingKey and widths[animation.closingKey] then
      local full = (animation.closingKey == LIST_KEY and spec.hasList) and LIST_WIDTH or GROUP_OPEN_WIDTH
      widths[animation.closingKey] = full - (full - GROUP_BAND_WIDTH) * eased
    end
  end

  return widths, openKey
end

local function LayoutPanels(browser)
  local spec = browser.spec
  local window = browser.window
  local animation = browser.animation
  local groups = Groups(browser)
  local widths, openKey = ContainerWidths(browser)
  local listWidth = spec.hasList and widths[LIST_KEY] or 0
  local total = listWidth
  local groupCount = #(groups)

  for i = 1, groupCount do
    total = total + (widths[groups[i].id] or GROUP_BAND_WIDTH) + PANEL_GAP
  end

  if not spec.hasList and groupCount > 0 then
    total = total - PANEL_GAP
  end

  Skin.SizeWindow(window, math.max(total, spec.minWidth or 0), panelHeight)

  local content = window.content
  local offset = 0

  if spec.hasList then
    local listIsOpen = (openKey == LIST_KEY) and not animation

    if listIsOpen then
      browser.listPanel:ClearAllPoints()
      browser.listPanel:SetWidth(listWidth)
      browser.listPanel:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
      browser.listPanel:Show()
      browser.listBand:Hide()
    else
      browser.listPanel:Hide()
      browser.listBand:ClearAllPoints()
      browser.listBand:SetWidth(listWidth)
      browser.listBand:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
      browser.listBand:Show()
    end

    offset = listWidth + PANEL_GAP
  end

  for i = 1, groupCount do
    local group = groups[i]
    local width = widths[group.id] or GROUP_BAND_WIDTH

    if group.id == openKey and not animation then
      browser.groupPanel:ClearAllPoints()
      browser.groupPanel:SetWidth(width)
      browser.groupPanel:SetPoint("TOPRIGHT", content, "TOPRIGHT", -offset, 0)
      browser.groupPanel:Show()
      browser.groupBands[i]:Hide()
    else
      local band = browser.groupBands[i]
      band:ClearAllPoints()
      band:SetWidth(width)
      band:SetPoint("TOPRIGHT", content, "TOPRIGHT", -offset, 0)
      band:Show()
    end

    offset = offset + width + PANEL_GAP
  end

  for i = groupCount + 1, #(browser.groupBands) do
    browser.groupBands[i]:Hide()
  end

  if animation or openKey == nil or openKey == LIST_KEY then
    browser.groupPanel:Hide()
  end
end

local function FillPanel(browser, panel, entries, storedCount)
  panel.entries = entries
  panel.storedCount = storedCount or #(entries)

  local maxOffset = math.max(0, #(entries) - VISIBLE_ROWS)
  local offset = math.min(ScrollOffset(browser, panel.groupId), maxOffset)

  SetScrollOffset(browser, panel.groupId, offset)

  if maxOffset > 0 then
    panel.scrollUp:Show()
    panel.scrollDown:Show()
    panel.scrollText:SetText(tostring(offset + 1) .. "-" .. tostring(math.min(#(entries), offset + VISIBLE_ROWS)))
    panel.scrollText:Show()
  else
    panel.scrollUp:Hide()
    panel.scrollDown:Hide()
    panel.scrollText:Hide()
  end

  local rowWidth = RowRight(panel, maxOffset > 0)

  local shownRows = 0

  for i = 1, VISIBLE_ROWS do
    local row = panel.rows[i]
    local entry = entries[offset + i]

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_INSET, -(panelHeader + (i - 1) * (rowHeight + ROW_GAP)))
    row:SetPoint("RIGHT", panel, "RIGHT", rowWidth, 0)

    if entry then
      shownRows = shownRows + 1
      row.entry = entry
      row.title:SetText(browser.spec.rowText(entry))
      RefreshRowVisual(browser, row, false)
      row:Show()
    else
      row.entry = nil
      row:Hide()
    end
  end

  if (storedCount or #(entries)) == 0 then
    panel.emptyLabel:ClearAllPoints()
    panel.emptyLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_INSET + 2,
        -(panelHeader + shownRows * (rowHeight + ROW_GAP) + 4))
    panel.emptyLabel:SetPoint("RIGHT", panel, "RIGHT", -(PANEL_INSET + 2), 0)
    panel.emptyLabel:Show()
  else
    panel.emptyLabel:Hide()
  end
end

Refresh = function(browser)
  local spec = browser.spec
  local window = browser.window

  if not window then
    return
  end

  if spec.beforeRefresh then
    spec.beforeRefresh()
  end

  LayoutPanels(browser)

  if spec.hasList then
    browser.listPanel.groupId = nil
    browser.listBand.groupId = nil

    local listEntries, listStored = spec.listEntries()

    if IsListOpen(browser) and not browser.animation then
      browser.listPanel.title:SetText(spec.listTitle())
      FillPanel(browser, browser.listPanel, listEntries, listStored)
    end

    ApplyBandLabel(browser.listBand, spec.listTitle())
    browser.listBand.count:SetText(tostring(listStored))
    Skin.ApplyColor(browser.listBand.label, "SetTextColor", "text")
  end

  if window.newGroupButton then
    RT.SetButtonEnabled(window.newGroupButton, spec.newGroup.enabled())
  end

  local openId = OpenGroupId(browser)
  local _, openGroup = FindGroupIndex(browser, openId)

  if openGroup and not browser.animation then
    browser.groupPanel.groupId = openGroup.id
    browser.groupPanel.group = openGroup
    browser.groupPanel.title:SetText(openGroup.name)
    FillPanel(browser, browser.groupPanel, spec.groupEntries(openGroup.id))
  end

  local groups = Groups(browser)

  for i = 1, #(groups) do
    local band = browser.groupBands[i]
    local group = groups[i]

    band.group = group
    band.groupId = group.id
    ApplyBandLabel(band, group.name)
    band.count:SetText(tostring(spec.count(group.id)))
    Skin.ApplyColor(band.label, "SetTextColor", "text")
  end

  if spec.afterRefresh then
    spec.afterRefresh(window)
  end
end

local function HideDropFeedback(panel)
  if panel then
    panel.dropLine:Hide()
  end
end

local function ClearBandHighlights(browser)
  if not browser.highlightedBand then
    return
  end

  Skin.Highlight(browser.highlightedBand.acbBox, nil)
  browser.highlightedBand = nil
end

local function DropTargetUnderCursor(browser)
  local window = browser.window

  if not window then
    return nil
  end

  local scale = window:GetEffectiveScale() or 1
  local x, y = GetCursorPosition()

  if not x then
    return nil
  end

  x, y = x / scale, y / scale

  local panels = { browser.listPanel, browser.groupPanel }

  for i = 1, #(panels) do
    if panels[i] and IsUnder(panels[i], x, y) then
      return panels[i], panels[i]:GetTop() - y, false
    end
  end

  if browser.listBand and IsUnder(browser.listBand, x, y) then
    return browser.listBand, 0, true
  end

  for i = 1, #(browser.groupBands) do
    if IsUnder(browser.groupBands[i], x, y) then
      return browser.groupBands[i], 0, true
    end
  end

  return nil
end

local function GapUnderCursor(browser, panel, depth)
  local entries = panel.entries or {}
  local offset = ScrollOffset(browser, panel.groupId)
  local slot = math.floor((depth - panelHeader) / (rowHeight + ROW_GAP) + 0.5)

  if slot < 0 then
    slot = 0
  elseif slot > VISIBLE_ROWS then
    slot = VISIBLE_ROWS
  end

  local gap = offset + slot

  if gap > #(entries) then
    gap = #(entries)
  end

  if panel == browser.listPanel and gap < (browser.spec.listReservedRows or 0) then
    gap = browser.spec.listReservedRows
  end

  return gap, gap - offset
end

local function ShowDropFeedback(panel, gap, visibleSlot, refused)
  local rowWidth = RowRight(panel, (panel.storedCount or 0) > VISIBLE_ROWS)

  panel.dropLine:ClearAllPoints()
  panel.dropLine:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_INSET,
      -(panelHeader + visibleSlot * (rowHeight + ROW_GAP)) + 1)
  panel.dropLine:SetPoint("RIGHT", panel, "RIGHT", rowWidth, 0)

  Skin.ApplyColor(panel.dropLine, "SetVertexColor", refused and DROP_REFUSED_BORDER or "checked")

  panel.dropLine:Show()
end

local function GroupFrame(browser, index)
  local group = Groups(browser)[index]

  if not group then
    return nil
  end

  if group.id == OpenContainerKey(browser) and not browser.animation then
    return browser.groupPanel
  end

  return browser.groupBands[index]
end

local function ResetContainerAlpha(browser)
  if browser.listPanel then
    browser.listPanel:SetAlpha(1)
    browser.listBand:SetAlpha(1)
  end

  browser.groupPanel:SetAlpha(1)

  for i = 1, #(browser.groupBands) do
    browser.groupBands[i]:SetAlpha(1)
  end
end

local function GroupIndexAt(browser, x)
  local count = #(Groups(browser))

  if count == 0 then
    return nil
  end

  for i = 1, count do
    local frame = GroupFrame(browser, i)
    local left = frame and frame:GetLeft()
    local right = frame and frame:GetRight()

    if left and right and x > (left + right) / 2 then
      return i
    end
  end

  return count
end

local function ShowGroupDropLine(browser, index)
  local window = browser.window
  local frame = GroupFrame(browser, index)
  local edge = frame and frame:GetRight()
  local windowEdge = window.content:GetRight()

  if not edge or not windowEdge then
    return
  end

  window.groupDropLine:ClearAllPoints()
  window.groupDropLine:SetPoint("TOP", window.content, "TOPRIGHT",
      (edge + PANEL_GAP / 2) - windowEdge, 0)
  window.groupDropLine:SetHeight(panelHeight)
  window.groupDropLine:Show()
end

local function TrackGroupDrag(browser)
  local window = browser.window
  local drag = browser.drag
  local scale = window:GetEffectiveScale() or 1
  local x = GetCursorPosition()

  drag.targetIndex = nil

  if not x then
    return
  end

  x = x / scale

  if not IsUnder(window, x, (window:GetTop() or 0) - 1) then
    return
  end

  local index = GroupIndexAt(browser, x)

  if not index then
    return
  end

  drag.targetIndex = index
  ShowGroupDropLine(browser, index)
end

local function TrackDrag(browser)
  local drag = browser.drag

  if not drag then
    return
  end

  HideDropFeedback(browser.listPanel)
  HideDropFeedback(browser.groupPanel)
  ClearBandHighlights(browser)
  browser.window.groupDropLine:Hide()

  if drag.kind == "group" then
    TrackGroupDrag(browser)
    return
  end

  drag.target = nil
  drag.beforeId = nil
  drag.noop = false
  drag.refused = false

  local target, depth, isBand = DropTargetUnderCursor(browser)

  if not target then
    return
  end

  local movingIn = not Core.sameContainer(drag.groupId, target.groupId)
  local refused = movingIn and browser.spec.dropRefused(target.groupId)

  drag.target = target
  drag.refused = refused

  if isBand then
    browser.highlightedBand = target

    Skin.Highlight(target.acbBox, refused and "refused" or "drop")

    drag.noop = not movingIn
    return
  end

  local gap, visibleSlot = GapUnderCursor(browser, target, depth)
  local entries = target.entries or {}
  local nextEntry = entries[gap + 1]
  local beforeId = nextEntry and nextEntry.id or nil

  if beforeId == drag.id then
    beforeId = nil
    drag.noop = true
  end

  drag.beforeId = beforeId

  ShowDropFeedback(target, gap, visibleSlot, refused)
end

BeginEntryDrag = function(browser, entry)
  browser.drag = { kind = "entry", id = entry.id, name = entry.name, groupId = browser.spec.entryGroup(entry) }
  GameTooltip:Hide()
  RefreshRowVisuals(browser)
  browser.window:SetScript("OnUpdate", browser.trackDrag)
  TrackDrag(browser)
end

BeginGroupDrag = function(browser, group)
  browser.drag = { kind = "group", id = group.id }
  GameTooltip:Hide()

  local index = FindGroupIndex(browser, group.id)
  local frame = index and GroupFrame(browser, index)

  if frame then
    frame:SetAlpha(DRAG_SOURCE_ALPHA)
  end

  browser.window:SetScript("OnUpdate", browser.trackDrag)
  TrackDrag(browser)
end

EndDrag = function(browser)
  local pending = browser.drag
  local window = browser.window

  browser.drag = nil

  if window then
    window:SetScript("OnUpdate", nil)
    HideDropFeedback(browser.listPanel)
    HideDropFeedback(browser.groupPanel)
    ClearBandHighlights(browser)
    window.groupDropLine:Hide()
    ResetContainerAlpha(browser)
    RefreshRowVisuals(browser)
  end

  if not pending then
    return
  end

  if pending.kind == "group" then
    if pending.targetIndex and browser.spec.moveGroup(pending.id, pending.targetIndex) then
      Refresh(browser)
    end

    return
  end

  if not pending.target or pending.refused then
    return
  end

  if pending.noop and Core.sameContainer(pending.groupId, pending.target.groupId) then
    return
  end

  if browser.spec.moveEntry(pending.id, pending.target.groupId, pending.beforeId) then
    Refresh(browser)
  end
end

SetOpen = function(browser, groupId, immediate)
  local spec = browser.spec
  local previous = spec.getOpen()

  if previous == groupId then
    return
  end

  spec.setOpen(groupId)

  if spec.onOpenGroup and OpenGroupId(browser) then
    spec.onOpenGroup(OpenGroupId(browser))
  end

  local window = browser.window

  if immediate or not window or not window:IsShown() then
    browser.animation = nil
    SetAnimating(browser, false)
    Refresh(browser)
    return
  end

  SetAnimating(browser, true)
  browser.animation = {
    startedAt = GetTime(),
    progress = 0,
    openingKey = OpenContainerKey(browser),
    closingKey = ContainerKeyFor(browser, previous),
  }

  Refresh(browser)
end

local function UpdateAnimation(browser)
  local animation = browser.animation

  if not animation then
    return
  end

  local elapsed = GetTime() - animation.startedAt
  local progress = elapsed / ANIMATION_SECONDS

  if progress >= 1 then
    browser.animation = nil
    SetAnimating(browser, false)
    Refresh(browser)
    return
  end

  animation.progress = 1 - ((1 - progress) * (1 - progress))
  LayoutPanels(browser)
end

local function Create(browser)
  local spec = browser.spec
  local newGroup = spec.newGroup
  local window = spec.createWindow(LIST_WIDTH, LIST_WIDTH, newGroup and {
    {
      text = "+",
      onClick = function() newGroup.onClick() end,
      tipTitle = newGroup.tipTitle,
      tipBody = newGroup.tipBody,
    },
  } or nil)

  browser.window = window

  window.dropLayer = CreateFrame("Frame", nil, window)
  window.dropLayer:SetAllPoints(window)
  window.dropLayer:SetFrameLevel(window:GetFrameLevel() + 20)

  window.groupDropLine = window.dropLayer:CreateTexture(nil, "OVERLAY")
  window.groupDropLine:SetTexture(EbonAPI.Bricks.media("solid"))
  window.groupDropLine:SetWidth(DROP_LINE_HEIGHT)
  Skin.ApplyColor(window.groupDropLine, "SetVertexColor", "checked")
  window.groupDropLine:Hide()

  if newGroup then
    window.newGroupButton = window.headButtons[1]
  end

  if spec.hasList then
    browser.listPanel = CreatePanel(browser, spec.names.listPanel, true)
  end

  browser.groupPanel = CreatePanel(browser, spec.names.groupPanel, false)
  browser.groupPanel:Hide()

  if spec.hasList then
    browser.listBand = CreateGroupBand(browser, "List", true)
    browser.listBand:Hide()
  end

  for i = 1, spec.maxGroups() do
    browser.groupBands[i] = CreateGroupBand(browser, i)
    browser.groupBands[i]:Hide()
  end

  window:Hide()

  return window
end

local function Toggle(browser)
  if not browser.window then
    Create(browser)
  end

  local window = browser.window

  if window:IsShown() then
    window:Hide()
  else
    browser.animation = nil
    SetAnimating(browser, false)
    Refresh(browser)
    window:Show()
    if window.Raise then
      window:Raise()
    end

    if browser.spec.onOpenGroup and OpenGroupId(browser) then
      browser.spec.onOpenGroup(OpenGroupId(browser))
    end
  end
end

function RT.BuildBrowser(spec)
  local B = { spec = spec, groupBands = {}, scrollOffsets = { list = 0 } }

  B.trackDrag = function()
    TrackDrag(B)
  end

  B.Refresh = function()
    return Refresh(B)
  end

  B.IsDragging = function()
    return B.drag ~= nil
  end

  B.SetOpen = function(groupId, immediate)
    return SetOpen(B, groupId, immediate)
  end

  B.UpdateAnimation = function()
    return UpdateAnimation(B)
  end

  B.IsAnimating = function()
    return B.animation ~= nil
  end

  B.Window = function()
    return B.window
  end

  B.IsShown = function()
    return B.window ~= nil and B.window:IsShown()
  end

  B.Create = function()
    return Create(B)
  end

  B.Toggle = function()
    return Toggle(B)
  end

  table.insert(instances, B)

  return B
end

function RT.UpdateBrowserAnimations()
  for i = 1, #(instances) do
    instances[i].UpdateAnimation()
  end
end

function RT.IsAnyBrowserAnimating()
  for i = 1, #(instances) do
    if instances[i].IsAnimating() then
      return true
    end
  end

  return false
end
