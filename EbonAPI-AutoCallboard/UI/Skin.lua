AutoCallboardSkin = {}
local RT = AutoCallboardRuntime

local Palette = EbonAPI.Palette
local Bricks = EbonAPI.Bricks
local THEME = Palette.THEME

local BUTTON_ICON_SIZE = 12
local SCROLL_BUTTON_SIZE = 18
local CHECK_MARK = "|TInterface\\Buttons\\UI-CheckBox-Check:16:16|t "
local MENU_MIN_WIDTH = 170
local MENU_TEXT_PAD = 48
local REFUSED = { 1, 0.25, 0.25, 0.45 }
local SELECTION_ALPHA = 0.28
local WEAK = { __mode = "k" }

local keyOf = {}
for key, color in pairs(THEME) do
  keyOf[color] = key
end

local roots = setmetatable({}, WEAK)
local windows = setmetatable({}, WEAK)

local function ApplyColor(target, methodName, color)
  if not (target and target[methodName] and color) then
    return
  end

  local key = type(color) == "string" and color or keyOf[color]

  if key then
    Palette.paint(target, methodName, key)
  else
    Palette.unpaint(target, methodName)
    target[methodName](target, color[1], color[2], color[3], color[4] or 1)
  end
end

local function PaintSelection(texture)
  ApplyColor(texture, "SetVertexColor", "selected")
  texture:SetAlpha(SELECTION_ALPHA)
end

local function SkinFont(target, size)
  Bricks.font(target, "button", "OUTLINE")
  target:SetFont((target:GetFont()), size, "OUTLINE")
end

local function Say(key)
  return key and EbonAPI.Kit.localized(RT.api:GetName(), key) or nil
end

local function OpenTip(owner, anchor, title)
  GameTooltip:SetOwner(owner, anchor)

  if Bricks.value("widgets.tooltip.skinned") and GameTooltip.SetBackdropColor then
    GameTooltip:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
    GameTooltip:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], THEME.border[4] or 1)
  end

  if title then
    GameTooltip:AddLine(title, THEME.heading[1], THEME.heading[2], THEME.heading[3])
  end

  return GameTooltip
end

local function ShowHoverTip(self)
  local tip = self.acbTip

  if not tip then
    return
  end

  Bricks.tip(self, Say(tip.title), Say(tip.body))

  if tip.extra then
    tip.extra(self)
    GameTooltip:Show()
  end
end

local function AttachHoverTip(widget, titleKey, bodyKey, extra)
  if not widget then
    return widget
  end

  if titleKey or bodyKey or extra then
    widget.acbTip = { title = titleKey, body = bodyKey, extra = extra }
  else
    widget.acbTip = nil
  end

  if not widget.acbTipHooked then
    widget.acbTipHooked = true
    widget:HookScript("OnEnter", ShowHoverTip)
    widget:HookScript("OnLeave", Bricks.hideTip)
  end

  return widget
end

local function Named(frame, name)
  if name then
    _G[name] = frame
  end

  return frame
end

local function Root(frame)
  roots[frame] = true
  frame:SetScale(RT.InterfaceParameter("scale"))

  return frame
end

local function Kit(kind, parent, spec)
  local element = RT.api:Create(kind, parent, spec or {})

  element.acbKit = true

  return element
end

local function CurrentLabel(element)
  return element.label and element.label:GetText() or ""
end

local function TextMethods(element)
  function element:SetText(text)
    self:SetLabel(text or "")

    if self.kitRefresh then
      self:Refresh()
    end
  end

  function element:GetText()
    return self.label:GetText()
  end

  function element:GetFontString()
    return self.label
  end

  return element
end

local function applyPoints(widget, one, many)
  if one then
    widget:SetPoint(one[1], one[2], one[3], one[4], one[5])
  end
  if many then
    for i = 1, #(many) do
      local p = many[i]
      widget:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
  end
end

local function PaintIcon(target)
  local icon = target and target.acbIcon

  if not icon then
    return
  end

  local color = target.acbIconColor or "buttonText"

  if target.disabledState then
    color = "muted"
  elseif target.acbSelected then
    color = "heading"
  end

  ApplyColor(icon, "SetVertexColor", color)
end

local function SetButtonIcon(target, texture, color)
  if not target or not target.CreateTexture then
    return
  end

  if not target.acbIcon then
    local icon = target:CreateTexture(nil, "OVERLAY")
    icon:SetWidth(BUTTON_ICON_SIZE)
    icon:SetHeight(BUTTON_ICON_SIZE)
    icon:SetPoint("CENTER", target, "CENTER", 0, 0)
    target.acbIcon = icon
  end

  target.acbIcon:SetTexture(texture)
  target.acbIconColor = color
  PaintIcon(target)
end

local function SetButtonSelected(target, selected)
  if not target then
    return target
  end

  target.acbSelected = selected and true or nil
  target:SetSelected(selected and true or false)
  PaintIcon(target)

  return target
end

local function BuildButton(parent, opts)
  local button = TextMethods(Kit(opts.secure and "secure" or "button", parent, {
    name = opts.secure and opts.name or nil,
    text = CurrentLabel,
    tipKey = opts.tipKey,
    tip = opts.tip,
    onClick = opts.onClick and function(self, mouse) opts.onClick(self, mouse) end or nil,
  }))

  if not opts.secure then
    button:RegisterForClicks("LeftButtonUp")
    Named(button, opts.name)
  end

  if opts.textKey then
    RT.Localized(button, opts.textKey)
  elseif opts.text then
    button:SetText(opts.text)
  end

  applyPoints(button, opts.point, opts.points)

  if opts.icon then
    SetButtonIcon(button, opts.icon, opts.iconColor)
  end

  if opts.tipTitle or opts.tipBody or opts.tipExtra then
    AttachHoverTip(button, opts.tipTitle, opts.tipBody, opts.tipExtra)
  end

  return button
end

local function ApplySize(frame)
  local size = frame.acbSize

  frame.acbSizing = nil
  frame.content:SetWidth(size[1])
  frame.content:SetHeight(size[2])
  frame:Layout()
end

local function SizeWindow(frame, width, height)
  frame.acbSize = { width, height }
  frame.content.spec.width, frame.content.spec.height = width, height

  if frame.kitSecure and InCombatLockdown() then
    if not frame.acbSizing then
      frame.acbSizing = true
      RT.api:AfterCombat(function() ApplySize(frame) end)
    end

    return
  end

  ApplySize(frame)
end

local function WindowSize(frame)
  local size = frame.acbSize

  if not size then
    return 0, 0
  end

  return size[1], size[2]
end

local function SavedPoint(name)
  local point = RT.state and RT.state.windowPositions and RT.state.windowPositions[name]

  if type(point) ~= "table" then
    return nil
  end

  return { point.point or "CENTER", UIParent, point.relativePoint or "CENTER", point.x or 0, point.y or 0 }
end

local function BareWindow(name, opts)
  local frame = CreateFrame("Frame", name, UIParent)

  frame:SetFrameStrata(opts.strata or "HIGH")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  Root(frame)

  if opts.movable then
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
      if not InCombatLockdown() and not RT.IsInterfaceLocked() then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      RT.state.windowPositions = RT.state.windowPositions or {}
      local point = RT.state.windowPositions[name] or {}
      RT.state.windowPositions[name] = point
      RT.SavePoint(self, point)
    end)
    frame:HookScript("OnShow", function(self)
      local point = RT.state.windowPositions and RT.state.windowPositions[name]
      if point then RT.RestorePoint(self, point) end
    end)
  end

  return frame
end

local function BuildWindow(name, opts)
  opts = opts or {}

  if opts.bare then
    return BareWindow(name, opts)
  end

  for _, button in ipairs(opts.buttons or {}) do
    if button.icon == nil and button.text == nil then
      button.text = CurrentLabel
    end
  end

  local id = string.gsub(name, "^AutoCallboard", "")
  local frame = RT.api:Window(id, {
    key = opts.titleKey,
    text = opts.title,
    escape = not opts.noEsc,
    move = opts.movable and "ALWAYS" or "NONE",
    buttons = opts.buttons,
    point = SavedPoint(name) or opts.point,
    shown = false,
  })

  frame.acbKit = true
  frame.closeButton = frame.close
  frame:SetToplevel(true)
  windows[frame] = true

  if not opts.movable then
    frame:RegisterForDrag()
  end

  if opts.strata then
    frame:SetFrameStrata(opts.strata)
  end

  frame.content = Kit("bar", frame, { layout = "NONE" })

  for index, button in ipairs(frame.headButtons or {}) do
    if button.label then
      TextMethods(button)
    end

    local spec = opts.buttons[index]

    if spec.tipTitle or spec.tipBody then
      AttachHoverTip(button, spec.tipTitle, spec.tipBody)
    end
  end

  if opts.width and opts.height then
    SizeWindow(frame, opts.width, opts.height)
  end

  return Named(frame, name)
end

local function BuildBox(parent, opts)
  opts = opts or {}

  local box = Kit("bar", parent, {
    frame = "SMALL",
    layout = "NONE",
    width = opts.width or 1,
    height = opts.height or 1,
  })

  return Named(box, opts.name)
end

local function BuildButtonRow(parent, opts)
  opts = opts or {}

  local row = Kit("bar", parent, { layout = "HORIZONTAL" })

  applyPoints(row, opts.point, opts.points)

  return row
end

local function Backdrop(frame)
  local box = BuildBox(frame)

  box:SetAllPoints(frame)
  frame.acbBox = box

  return box
end

local function Field(editBox)
  local box = BuildBox(editBox:GetParent())

  box:SetPoint("TOPLEFT", editBox, "TOPLEFT", -4, 2)
  box:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 4, -2)
  editBox:SetFrameLevel(box:GetFrameLevel() + 1)
  ApplyColor(editBox, "SetTextColor", "text")
  editBox.acbBox = box

  return box
end

local function BuildRow(parent, name, ...)
  local row = Kit("slot", parent, { text = CurrentLabel })

  if select("#", ...) > 0 then
    row:RegisterForClicks(...)
  else
    row:RegisterForClicks("LeftButtonUp")
  end

  row.label:SetJustifyH("LEFT")
  row.title = row.label

  return Named(row, name)
end

local function PaintRow(row, selected, disabled)
  row:SetSelected(selected and true or false)
  row:SetDisabledState(disabled and true or false)
end

local function Highlight(frame, mode)
  local overlay = frame.acbHighlight

  if not mode then
    if overlay then
      overlay:Hide()
    end

    return
  end

  if not overlay then
    overlay = frame:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture(Bricks.media("solid"))
    overlay:SetAllPoints(frame)
    frame.acbHighlight = overlay
  end

  if mode == "refused" then
    ApplyColor(overlay, "SetVertexColor", REFUSED)
    overlay:SetAlpha(1)
  else
    PaintSelection(overlay)
  end

  overlay:Show()
end

local function BuildCheckbox(parent, opts)
  opts = opts or {}

  local box = Kit("toggle", parent, {
    text = CurrentLabel,
    onChange = opts.onClick and function(self, value) opts.onClick(self, value) end or nil,
  })

  function box:GetChecked()
    return self.value and 1 or nil
  end

  function box:SetChecked(checked)
    self:SetValue(checked and true or false)
  end

  return box
end

local blocker
local replacing = false
local hookedDialogs = setmetatable({}, WEAK)

local function Blocker()
  if not blocker then
    blocker = CreateFrame("Frame", nil, UIParent)
    blocker:SetFrameStrata("DIALOG")
    blocker:SetAllPoints(UIParent)
    blocker:EnableMouse(true)
    blocker:Hide()
  end

  return blocker
end

local function Unless(fn)
  if not fn then
    return nil
  end

  return function(...)
    if not replacing then
      return fn(...)
    end
  end
end

local function ShowDialog(opts)
  opts = opts or {}

  local editBox = opts.editBox

  replacing = true
  local ok, dialog = pcall(RT.api.Dialog, RT.api, {
    title = opts.title,
    text = opts.body,
    accept = opts.acceptText,
    cancel = opts.cancelText,
    input = editBox and tostring(editBox.default or "") or nil,
    maxLetters = editBox and tonumber(editBox.maxLetters) or nil,
    choices = opts.choices,
    value = opts.value,
    onAccept = opts.onAccept,
    onCancel = Unless(opts.onCancel),
  })
  replacing = false

  if not ok then
    error(dialog, 0)
  end

  if not hookedDialogs[dialog] then
    hookedDialogs[dialog] = true
    dialog:HookScript("OnHide", function(self)
      if not self:IsShown() then
        Blocker():Hide()
      end
    end)
  end

  Blocker():Show()

  return dialog
end

local Menu = {}
local measure

function Menu:Reset()
  self.items = {}
end

function Menu:AddItem(text, options)
  options = options or {}

  local item = { text = text or "" }

  if options.header then
    item.title = true
  else
    item.disabled = options.disabled and true or nil

    if options.checked then
      item.text = CHECK_MARK .. item.text
    end

    if options.arrow then
      item.text = item.text .. " >"
    end

    local handler = options.onClick

    if handler then
      local menu = self

      item.onClick = function()
        menu.picking = true
        local ok, err = pcall(handler)
        menu.picking = false

        if not ok then
          error(err, 0)
        end
      end
    end
  end

  self.items[#(self.items) + 1] = item

  return item
end

function Menu:AddSlider(options)
  options = options or {}

  local commit = options.onCommit

  self.items[#(self.items) + 1] = {
    text = options.title or "",
    range = {
      min = options.min or 0,
      max = options.max or 1,
      step = options.step or 1,
      value = options.value,
      format = options.format,
    },
    onChange = commit and function(value) commit(value) end or nil,
  }
end

function Menu:Width()
  measure = measure or UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

  local widest = 0

  for _, item in ipairs(self.items) do
    measure:SetText(item.text or "")
    widest = math.max(widest, measure:GetStringWidth() or 0)
  end

  return math.max(MENU_MIN_WIDTH, widest + MENU_TEXT_PAD)
end

function Menu:Open()
  self.flip = not self.flip

  local holder = self.flip and self.holders[1] or self.holders[2]
  local place = self.place

  holder:SetParent(place.anchor or UIParent)
  holder:ClearAllPoints()

  if place.anchor then
    holder:SetPoint("BOTTOMLEFT", place.anchor, place.relativePoint or "BOTTOMLEFT", place.x or 0, place.y or 0)
  else
    holder:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end

  holder:SetWidth(self:Width())
  RT.api:OpenMenu(self.items, holder)
end

function Menu:Layout()
  if self.picking and self.place then
    self:Open()
  end
end

function Menu:OpenAt(anchor, _, relativePoint, x, y)
  self.place = { anchor = anchor, relativePoint = relativePoint, x = x, y = y }
  self:Open()
end

local function BuildMenu(name)
  local menu = { items = {}, holders = {} }

  for index = 1, 2 do
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetHeight(1)
    menu.holders[index] = holder
  end

  for key, method in pairs(Menu) do
    menu[key] = method
  end

  return Named(menu, name)
end

local function HideTextureRegions(target)
  if not target or not target.GetRegions then
    return
  end

  local regions = { target:GetRegions() }

  for i = 1, #(regions) do
    local region = regions[i]

    if region and region.GetObjectType and region:GetObjectType() == "Texture" then
      region:SetTexture(nil)
      region:SetAlpha(0)
      region:Hide()
    end
  end
end

local function StripButtonChrome(target)
  target:SetNormalTexture("")
  target:SetHighlightTexture("")
  target:SetPushedTexture("")
  target:SetDisabledTexture("")
  HideTextureRegions(target)
end

local function SetScrollButtonVisual(target, hovered)
  ApplyColor(target, "SetBackdropBorderColor", hovered and "buttonHover" or "button")
end

local function SkinScrollButton(target, glyph)
  if not target then
    return
  end

  StripButtonChrome(target)
  target:SetWidth(SCROLL_BUTTON_SIZE)
  target:SetHeight(SCROLL_BUTTON_SIZE)
  Bricks.frame(target, "flat", "button", "button")

  local label = target:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("CENTER", target, "CENTER", 0, 0)
  SkinFont(label, 9)
  label:SetText(glyph)
  ApplyColor(label, "SetTextColor", "buttonText")
  target.acbGlyph = label

  target:HookScript("OnEnter", function(self) SetScrollButtonVisual(self, true) end)
  target:HookScript("OnLeave", function(self) SetScrollButtonVisual(self) end)
end

local function SkinScrollBar(scrollFrame)
  if not scrollFrame or not scrollFrame.GetName then
    return
  end

  local frameName = scrollFrame:GetName()
  local scrollBar = _G[frameName .. "ScrollBar"] or scrollFrame.ScrollBar

  if not scrollBar then
    return
  end

  local scrollBarName = scrollBar.GetName and scrollBar:GetName() or frameName .. "ScrollBar"
  local upButton = _G[scrollBarName .. "ScrollUpButton"] or _G[frameName .. "ScrollUpButton"]
  local downButton = _G[scrollBarName .. "ScrollDownButton"] or _G[frameName .. "ScrollDownButton"]

  HideTextureRegions(scrollBar)
  scrollBar:SetWidth(SCROLL_BUTTON_SIZE)
  Bricks.frame(scrollBar, "flat", "bgSoft", "borderDim")

  SkinScrollButton(upButton, "^")
  SkinScrollButton(downButton, "v")

  local thumb = scrollBar:GetThumbTexture()
  if thumb then
    thumb:SetTexture(Bricks.media("solid"))
    ApplyColor(thumb, "SetVertexColor", "thumb")
    thumb:Show()
  end

  scrollBar.acbUpButton = upButton
  scrollBar.acbDownButton = downButton

  return scrollBar
end

local function SkinHeadingText(target)
  ApplyColor(target, "SetTextColor", "heading")
end

local function SkinMutedText(target)
  ApplyColor(target, "SetTextColor", "muted")
end

AutoCallboardSkin.THEME = THEME
AutoCallboardSkin.CHECK_MARK = CHECK_MARK
AutoCallboardSkin.ApplyColor = ApplyColor
AutoCallboardSkin.PaintSelection = PaintSelection
AutoCallboardSkin.Font = SkinFont
AutoCallboardSkin.OpenTip = OpenTip
AutoCallboardSkin.HoverTip = AttachHoverTip
AutoCallboardSkin.Named = Named
AutoCallboardSkin.Root = Root
AutoCallboardSkin.Window = BuildWindow
AutoCallboardSkin.SizeWindow = SizeWindow
AutoCallboardSkin.WindowSize = WindowSize
AutoCallboardSkin.Box = BuildBox
AutoCallboardSkin.Backdrop = Backdrop
AutoCallboardSkin.ButtonRow = BuildButtonRow
AutoCallboardSkin.Field = Field
AutoCallboardSkin.MakeButton = BuildButton
AutoCallboardSkin.SetButtonIcon = SetButtonIcon
AutoCallboardSkin.RefreshButtonIcon = PaintIcon
AutoCallboardSkin.SetButtonSelected = SetButtonSelected
AutoCallboardSkin.Row = BuildRow
AutoCallboardSkin.PaintRow = PaintRow
AutoCallboardSkin.Highlight = Highlight
AutoCallboardSkin.Checkbox = BuildCheckbox
AutoCallboardSkin.Dialog = ShowDialog
AutoCallboardSkin.Menu = BuildMenu
AutoCallboardSkin.ScrollBar = SkinScrollBar
AutoCallboardSkin.HeadingText = SkinHeadingText
AutoCallboardSkin.MutedText = SkinMutedText

function AutoCallboardSkin.RelabelWindows()
  for frame in pairs(windows) do
    frame.close.tipTitle = EbonAPI.L["UI_CLOSE"]
  end
end

function AutoCallboardSkin.ScaleRoots(scale)
  for frame in pairs(roots) do
    frame:SetScale(scale)
  end
end

