EbonAPI = EbonAPI or {}
EbonAPI.QuestLogChecks = {}

local QuestLogChecks = EbonAPI.QuestLogChecks
local Lib = EbonAPI.Lib
local Locale = EbonAPI.Locale
local QuestLog = EbonAPI.QuestLog
local L = EbonAPI.L

local ipairs, type = ipairs, type
local format = string.format
local S = EbonAPI.Skins.value

-- Multi-select for the quest log of the game. An interrupt switch beside the quest counter turns on a check
-- box on each quest (left, in the empty margin) and on each category (right), and replaces the Abandon
-- button by "Abandon (n)". Nothing is moved: the title, the +/- sign and the text anchor stay where the
-- game puts them. A quest is its questID and a category its rank; a title is never used to find anything.

local CHECK_ON = "Interface\\Buttons\\UI-CheckBox-Check"
local CHECK_PARTIAL = "Interface\\Buttons\\UI-CheckBox-Check-Disabled"
local GAP = 6

local installed = false
local enabled = false
local toggle, abandon

local function api(name)
  return rawget(_G, name)
end

local function busy()
  return QuestLog.isAbandoning()
end

local function refreshAbandon()
  if not abandon then
    return
  end

  if not enabled then
    abandon:Hide()

    return
  end

  local count = #QuestLog.checkedList()
  local position, size = QuestLog.progress()

  if position then
    abandon:SetText(format(L.QUESTLOG_ABANDON_PROGRESS, position, size))
  else
    abandon:SetText(format(L.QUESTLOG_ABANDON_COUNT, count))
  end

  if count > 0 and not busy() then
    abandon:Enable()
  else
    abandon:Disable()
  end

  abandon:Show()
end

local function refreshToggle()
  local frame = api("QuestLogFrame")
  local _, quests = GetNumQuestLogEntries()

  if not frame or not frame:IsShown() or (quests or 0) == 0 then
    toggle:Hide()

    return
  end

  toggle:SetChecked(enabled)
  toggle:Show()

  if busy() then
    toggle:Disable()
  else
    toggle:Enable()
  end
end

local function rankMap()
  local map, rank = {}, 0

  for index = 1, (GetNumQuestLogEntries()) do
    local _, _, _, _, isHeader = GetQuestLogTitle(index)

    if isHeader then
      rank = rank + 1
      map[index] = rank
    end
  end

  return map
end

local function categoryOf(rank)
  for _, category in ipairs(QuestLog.last or {}) do
    if category.rank == rank then
      return category
    end
  end

  return nil
end

local function onCheckClick(self)
  local row = self:GetParent()
  local index = row:GetID()
  local _, _, _, _, isHeader, isCollapsed, _, _, questID = GetQuestLogTitle(index)

  if isHeader then
    if isCollapsed or not QuestLog.last then
      QuestLog.read()
    end

    local category = categoryOf(rankMap()[index])
    local ids, all = {}, true

    for _, quest in ipairs(category and category.quests or {}) do
      ids[#ids + 1] = quest.questID
      all = all and QuestLog.isChecked(quest.questID)
    end

    QuestLog.check(ids, not all)
  elseif questID then
    QuestLog.check({ questID }, self:GetChecked() and true or false)
  end
end

local function buildCheck(row)
  local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")

  local size = S("kit.questlog.check")

  check:SetSize(size, size)
  check:SetFrameLevel(row:GetFrameLevel() + 2)
  check:SetScript("OnClick", onCheckClick)
  check.partial = false
  row.ebonapiCheck = check

  return check
end

local function decorateRow(row, ranks)
  local check = row.ebonapiCheck or buildCheck(row)
  local index = row:GetID()

  if not row:IsShown() or index > (GetNumQuestLogEntries()) then
    check:Hide()

    return
  end

  local _, _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)

  check:ClearAllPoints()

  if isHeader then
    local category = categoryOf(ranks[index])
    local total, marked = 0, 0

    for _, quest in ipairs(category and category.quests or {}) do
      total = total + 1

      if QuestLog.isChecked(quest.questID) then
        marked = marked + 1
      end
    end

    check:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    check.partial = marked > 0 and marked < total
    check:SetCheckedTexture(check.partial and CHECK_PARTIAL or CHECK_ON)
    check:SetChecked(marked > 0)
  else
    check:SetPoint("LEFT", row, "LEFT", 3, 0)
    check.partial = false
    check:SetCheckedTexture(CHECK_ON)
    check:SetChecked(questID and QuestLog.isChecked(questID) or false)

    if row.groupMates then
      row.groupMates:Hide()
    end
  end

  if busy() then
    check:Disable()
  else
    check:Enable()
  end

  check:Show()
end

local function hideChecks()
  local scroll = api("QuestLogScrollFrame")

  for _, row in ipairs(scroll and scroll.buttons or {}) do
    if row.ebonapiCheck then
      row.ebonapiCheck:Hide()
    end
  end
end

local function decorate()
  if not installed or QuestLog.reading then
    return
  end

  refreshToggle()
  refreshAbandon()

  if not enabled then
    hideChecks()

    return
  end

  if not busy() then
    local _, quests = GetNumQuestLogEntries()

    if quests ~= QuestLog.count then
      QuestLog.read()
    end
  end

  local ranks = rankMap()

  for _, row in ipairs(api("QuestLogScrollFrame").buttons or {}) do
    decorateRow(row, ranks)
  end
end

local function redraw()
  local update = api("QuestLog_Update")

  if type(update) == "function" then
    update()
  end
end

local function setEnabled(on)
  enabled = on and true or false

  if enabled then
    QuestLog.read()
  else
    QuestLog.clear()
  end

  decorate()
  redraw()
end

local function buildToggle(frame)
  toggle = CreateFrame("CheckButton", "EbonAPIQuestLogToggle", frame, "UICheckButtonTemplate")
  toggle:SetSize(20, 20)
  toggle:SetPoint("LEFT", api("QuestLogCount"), "RIGHT", GAP, 0)

  toggle.label = toggle:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  toggle.label:SetPoint("LEFT", toggle, "RIGHT", 0, 1)
  toggle.label:SetJustifyH("LEFT")

  local map = api("QuestLogFrameShowMapButton")

  if map then
    toggle.label:SetPoint("RIGHT", map, "LEFT", -GAP, 1)
  end

  if toggle.label.SetWordWrap then
    toggle.label:SetWordWrap(false)
  end

  Locale.bind("EbonAPI", toggle.label, "QUESTLOG_MULTI")

  toggle:SetScript("OnClick", function(self)
    setEnabled(self:GetChecked())
  end)

  toggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.QUESTLOG_MULTI, 1, 1, 1)
    GameTooltip:AddLine(L.QUESTLOG_MULTI_TIP, nil, nil, nil, true)
    GameTooltip:Show()
  end)

  toggle:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

local function buildAbandon()
  local blizzard = api("QuestLogFrameAbandonButton")

  abandon = CreateFrame("Button", "EbonAPIQuestLogAbandon", blizzard:GetParent(), "UIPanelButtonTemplate")
  abandon:SetAllPoints(blizzard)
  abandon:SetFrameLevel(blizzard:GetFrameLevel() + 2)
  abandon:Hide()

  abandon:SetScript("OnClick", function()
    QuestLog.abandon(QuestLog.checkedList())
  end)
end

function QuestLogChecks.install()
  local frame = api("QuestLogFrame")
  local scroll = api("QuestLogScrollFrame")

  if installed or not frame or not scroll or not api("QuestLogCount") or not api("QuestLogFrameAbandonButton")
    or type(api("QuestLog_Update")) ~= "function" or type(api("CreateFrame")) ~= "function" then
    return
  end

  installed = true

  buildToggle(frame)
  buildAbandon()

  QuestLog.onChange = decorate

  hooksecurefunc("QuestLog_Update", function()
    Lib.safeCall(decorate)
  end)

  hooksecurefunc(scroll, "update", function()
    Lib.safeCall(decorate)
  end)

  frame:HookScript("OnHide", function()
    enabled = false
    toggle:SetChecked(false)
    QuestLog.clear()
  end)

  EbonAPI:On("LANGUAGE_CHANGED", function()
    Lib.safeCall(decorate)
  end)
end
