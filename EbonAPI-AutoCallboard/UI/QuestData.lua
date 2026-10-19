local Lib = EbonAPI.Lib
local Core = AutoCallboardCore
local Skin = AutoCallboardSkin
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local Localized = RT.Localized
local CompactText = RT.CompactText
local state = RT.state

local dataWindow
local dataEditBox

local function ShowDebugWindow()
  if RT.ShowDebugWindow then
    RT.ShowDebugWindow()
  end
end

function RT.SetQuestDataSelectionVisible(selected)
  if RT.questDataSelectionOverlay then
    Lib.setShown(RT.questDataSelectionOverlay, selected)
  end

  if RT.questDataSelectionText then
    Lib.setShown(RT.questDataSelectionText, selected)
  end
end

function RT.SelectQuestDataText(alreadyFocused)
  if not dataEditBox then
    return
  end

  if not alreadyFocused then
    dataEditBox:SetFocus()
  end
  dataEditBox:HighlightText()
  RT.SetQuestDataSelectionVisible(true)
end

local function SetQuestDataText(text)
  if not dataEditBox then
    return
  end

  text = text or ""

  local lineCount = 1
  for _ in string.gmatch(text, "\n") do
    lineCount = lineCount + 1
  end

  dataEditBox:SetHeight(math.max(330, lineCount * 14))
  RT.questDataReadOnlyText = text
  RT.questDataEditBoxUpdating = true
  dataEditBox:SetText(text)
  dataEditBox:SetCursorPosition(0)
  RT.questDataEditBoxUpdating = false
  RT.SetQuestDataSelectionVisible(false)
end

local function ImportQuestDataFromText(text)
  local quests, imported, skipped = Core.importKnownQuestText(text)

  if imported <= 0 then
    local firstLine = tostring(text or ""):match("([^\r\n]+)") or ""
    local preview = CompactText(firstLine)
    local info = Core.analyzeQuestImportText(text)
    local code = "QUESTDATA.IMPORT_NO_VALID_LINE"

    if info.nonEmptyLineCount == 0 then
      code = "QUESTDATA.IMPORT_EMPTY"
    elseif info.marker == nil then
      code = "QUESTDATA.IMPORT_NO_MARKER"
    end

    RT.api:Report(RT.api:Problem(code, { preview = preview, skipped = skipped }))
    ShowDebugWindow()
    return
  end

  state.knownQuests = Core.mergeKnownQuestLists(state.knownQuests, quests)
  RT.TouchState()

  if skipped > 0 then
    RT.api:Report(RT.api:Problem("QUESTDATA.IMPORT_PARTIAL", { imported = imported, skipped = skipped }))
  else
    RT.api:Notify(string.format(L.QUESTDATA_IMPORTED, imported, #(state.knownQuests or {})))
  end

  RT.RefreshQuestWindow()
end

function RT.ExportQuestDataText()
  RT.CaptureCurrentObjectives()

  return Core.exportKnownQuestText(state.knownQuests)
end

function RT.SyncQuestDataControls()
  local mode = RT.questDataMode

  if RT.questDataExportButton then
    Lib.setShown(RT.questDataExportButton, mode == "export")
  end

  if RT.questDataImportButton then
    Lib.setShown(RT.questDataImportButton, mode == "import")
  end

  if RT.questDataSelectButton then
    Lib.setShown(RT.questDataSelectButton, mode == "export")
  end

  if RT.questDataClearButton then
    Lib.setShown(RT.questDataClearButton, mode == "import")
  end

  if RT.questDataButtons then
    RT.questDataButtons:Layout()
  end
end

local function CreateQuestDataEditBox(scrollFrame)
  dataEditBox = CreateFrame("EditBox", "AutoCallboardQuestDataEditBox", scrollFrame)
  dataEditBox:SetMultiLine(true)
  dataEditBox:SetAutoFocus(false)
  dataEditBox:SetFontObject(ChatFontNormal)
  dataEditBox:SetWidth(650)
  dataEditBox:SetHeight(330)
  dataEditBox:SetTextInsets(3, 3, 3, 3)
  Skin.ApplyColor(dataEditBox, "SetTextColor", "text")
  dataEditBox:SetScript("OnTextChanged", function(self)
    if RT.questDataEditBoxUpdating then
      return
    end

    if RT.questDataMode == "export" then
      RT.questDataEditBoxUpdating = true
      self:SetText(RT.questDataReadOnlyText or "")
      self:HighlightText()
      RT.questDataEditBoxUpdating = false
      RT.SetQuestDataSelectionVisible(true)
    else
      RT.SetQuestDataSelectionVisible(false)
    end
    end)
  dataEditBox:SetScript("OnEditFocusGained", function()
    if RT.questDataMode == "export" then
      RT.SelectQuestDataText(true)
    end
    end)
  dataEditBox:SetScript("OnMouseUp", function()
    if RT.questDataMode == "export" then
      RT.SelectQuestDataText()
    end
    end)
  dataEditBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    dataWindow:Hide()
    end)
  scrollFrame:SetScrollChild(dataEditBox)
end

local function CreateQuestDataButtons()
  local content = dataWindow.content
  local buttons = Skin.ButtonRow(content, { point = { "BOTTOMLEFT", content, "BOTTOMLEFT", 8, 8 } })

  RT.questDataButtons = buttons

  local exportButton = Skin.MakeButton(buttons, {
    textKey = "BUTTON_EXPORT",
    onClick = function()
      RT.questDataMode = "export"
      RT.SyncQuestDataControls()
      SetQuestDataText(RT.ExportQuestDataText("button"))
      RT.SelectQuestDataText()
      end,
  })
  RT.questDataExportButton = exportButton

  local importButton = Skin.MakeButton(buttons, {
    textKey = "BUTTON_IMPORT",
    onClick = function()
      ImportQuestDataFromText(dataEditBox:GetText() or "")
      end,
  })
  RT.questDataImportButton = importButton

  local selectButton = Skin.MakeButton(buttons, {
    textKey = "BUTTON_SELECT_ALL",
    onClick = function()
      if RT.questDataMode == "export" then
        SetQuestDataText(RT.ExportQuestDataText("select-all"))
      end
      RT.SelectQuestDataText()
      end,
  })
  RT.questDataSelectButton = selectButton

  local clearButton = Skin.MakeButton(buttons, {
    textKey = "BUTTON_CLEAR",
    onClick = function()
      RT.questDataMode = "import"
      RT.SyncQuestDataControls()
      SetQuestDataText("")
      dataEditBox:SetFocus()
      end,
  })
  RT.questDataClearButton = clearButton

  RT.questDataSelectionText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  RT.questDataSelectionText:SetPoint("LEFT", buttons, "RIGHT", 12, 0)
  Localized(RT.questDataSelectionText, "QUESTDATA_SELECTED_HINT")
  Skin.HeadingText(RT.questDataSelectionText)
  RT.questDataSelectionText:Hide()
end

local function CreateQuestDataWindow()
  dataWindow = Skin.Window("AutoCallboardQuestDataWindow", {
    width = 688,
    height = 376,
    strata = "FULLSCREEN_DIALOG",
    movable = true,
    titleKey = "QUESTDATA_WINDOW_TITLE",
    point = { "CENTER", UIParent, "CENTER", 0, 0 },
  })

  local scrollFrame = CreateFrame("ScrollFrame", "AutoCallboardQuestDataScrollFrame", dataWindow.content, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", dataWindow.content, "TOPLEFT", 8, -8)
  scrollFrame:SetPoint("BOTTOMRIGHT", dataWindow.content, "BOTTOMRIGHT", -20, 40)
  Skin.Field(scrollFrame)
  Skin.ScrollBar(scrollFrame)
  RT.questDataScrollFrame = scrollFrame
  RT.questDataSelectionOverlay = scrollFrame:CreateTexture(nil, "ARTWORK")
  RT.questDataSelectionOverlay:SetTexture(EbonAPI.Bricks.media("solid"))
  RT.questDataSelectionOverlay:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 3, -3)
  RT.questDataSelectionOverlay:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -22, 3)
  Skin.PaintSelection(RT.questDataSelectionOverlay)
  RT.questDataSelectionOverlay:Hide()

  CreateQuestDataEditBox(scrollFrame)
  CreateQuestDataButtons()
end

local function ShowQuestDataWindow(mode)
  if not dataWindow then
    CreateQuestDataWindow()
  end

  RT.questDataMode = mode
  RT.SyncQuestDataControls()
  if mode == "export" then
    SetQuestDataText(RT.ExportQuestDataText("open"))
  elseif mode == "import" then
    SetQuestDataText("")
  end

  dataWindow:Show()
  if dataWindow.Raise then
    dataWindow:Raise()
  end
  dataEditBox:SetFocus()

  if mode == "export" then
    RT.SelectQuestDataText()
  end
end

RT.ShowQuestDataWindow = ShowQuestDataWindow
