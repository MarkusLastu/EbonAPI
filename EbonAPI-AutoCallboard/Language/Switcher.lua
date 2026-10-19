local L = AutoCallboardLocale
local RT = AutoCallboardRuntime

function RT.RefreshLocalizedText()
  AutoCallboardSkin.RelabelWindows()

  for i = 1, #(RT.questTypeFilterOptions) do
    local option = RT.questTypeFilterOptions[i]
    option.label = option.questType > 0 and L.QUEST_TYPE_NAMES[option.questType] or L.QUEST_TYPE_OTHER

    local checkbox = RT.knownQuestTypeButtons[i]
    if checkbox and checkbox._acbLabel then
      checkbox._acbLabel:SetText(option.label)
    end
  end

  RT.RefreshEternalLabels()

  RT.knownEntriesSignature = nil

  local controlFrame = RT.controlFrame
  if controlFrame and controlFrame.questButton then
    controlFrame.questButton:SetText(RT.IsQuestWindowShown() and L.BUTTON_HIDE or L.BUTTON_QUESTS)
  end

  RT.UpdateRollToggleButtons()
  RT.UpdateSummonStatus()

  RT.RefreshQuestWindow()

  if RT.listsWindow and RT.listsWindow:IsShown() then
    RT.RefreshListsWindow()
  end

  if RT.buildsWindow and RT.buildsWindow:IsShown() then
    RT.RefreshBuildsWindow()
  end

  RT.RefreshBindingNames()

  RT.SyncQuestDataControls()
  RT.RefreshSettingsLanguage()
  RT.RefreshRouteWindow()
  RT.RefreshRouteArrowLabel()
  RT.RefreshUpdateNotice()
end

local applied

function RT.InitLanguage()
  applied = RT.GetLanguage()

  RT.api:On("LANGUAGE_CHANGED", function(_, code)
    if code == applied then
      return
    end

    applied = code
    RT.RefreshLocalizedText()
  end)
end
