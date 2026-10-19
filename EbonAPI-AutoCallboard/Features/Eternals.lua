local ADDON_NAME = ...
local Core = AutoCallboardCore
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime

local BUTTON_NAME = "AutoCallboardEternalButton"
local DEFAULT_BINDING = "CTRL-W"
local CRYSTAL_STACK_SIZE = 10
local QUEST_CHECK_INTERVAL = 1
local IDLE_WATCH_INTERVAL = 5
local SEQUENCE_TIMEOUT = 900

local ETERNAL_MAP = {
  {
    keyword = "eternal water", labelKey = "ETERNAL_LABEL_WATER", itemKey = "ETERNAL_ITEM_WATER",
    crystalItem = 37705, eternalItem = 35622,
    toEternalSpell = 49245, toCrystalSpell = 56040,
  },
  {
    keyword = "eternal fire", labelKey = "ETERNAL_LABEL_FIRE", itemKey = "ETERNAL_ITEM_FIRE",
    crystalItem = 37702, eternalItem = 36860,
    toEternalSpell = 49244, toCrystalSpell = 56042,
  },
  {
    keyword = "eternal earth", labelKey = "ETERNAL_LABEL_EARTH", itemKey = "ETERNAL_ITEM_EARTH",
    crystalItem = 37701, eternalItem = 35624,
    toEternalSpell = 49248, toCrystalSpell = 56041,
  },
  {
    keyword = "eternal air", labelKey = "ETERNAL_LABEL_AIR", itemKey = "ETERNAL_ITEM_AIR",
    crystalItem = 37700, eternalItem = 35623,
    toEternalSpell = 49234, toCrystalSpell = 56045,
  },
  {
    keyword = "eternal shadow", labelKey = "ETERNAL_LABEL_SHADOW", itemKey = "ETERNAL_ITEM_SHADOW",
    crystalItem = 37703, eternalItem = 35627,
    toEternalSpell = 49246, toCrystalSpell = 56044,
  },
}

local SPELL_LOOKUP = {}
for i = 1, #(ETERNAL_MAP) do
  local entry = ETERNAL_MAP[i]
  SPELL_LOOKUP[entry.toEternalSpell] = { entry = entry, step = 1 }
  SPELL_LOOKUP[entry.toCrystalSpell] = { entry = entry, step = 2 }
end

local function EntryLabel(entry)
  return L[entry.labelKey] or entry.labelKey
end

local function EntryItemName(entry)
  return L[entry.itemKey] or entry.itemKey
end

local pending
local button
local pendingConfig
local pendingHide
local events
local sequenceWatched = false
local combatQueued = false
local nextQuestCheckAt
local StopPending
local FlushAfterCombat

local function IsEnabled()
  if type(EbonAPIAutoCallboardEternalsDB) ~= "table" then
    return true
  end

  return EbonAPIAutoCallboardEternalsDB.enabled ~= false
end

RT.IsEternalsEnabled = IsEnabled

function RT.SetEternalsEnabled(enabled)
  EbonAPIAutoCallboardEternalsDB.enabled = enabled and true or false

  if not enabled then
    StopPending("desactive")
  end

  RT.RefreshOptions()
end

local function GetBinding()
  if type(EbonAPIAutoCallboardEternalsDB) == "table" and type(EbonAPIAutoCallboardEternalsDB.binding) == "string" and EbonAPIAutoCallboardEternalsDB.binding ~= "" then
    return EbonAPIAutoCallboardEternalsDB.binding
  end

  return DEFAULT_BINDING
end

local function FindEntryInText(text)
  local normalized = Core.normalizeMatchText(text)
  if normalized == "" then
    return nil
  end

  for i = 1, #(ETERNAL_MAP) do
    local entry = ETERNAL_MAP[i]
    if string.find(normalized, entry.keyword, 1, true) then
      return entry
    end
  end

  return nil
end

local function ItemUseName(itemID)
  if GetItemInfo then
    local name = GetItemInfo(itemID)
    if type(name) == "string" and name ~= "" then
      return name
    end
  end

  return "item:" .. tostring(itemID)
end

local function ItemCount(itemID)
  if not GetItemCount then
    return 0
  end

  return tonumber(GetItemCount(itemID)) or 0
end

local function CreateButton()
  if button then
    return button
  end

  button = AutoCallboardSkin.Root(AutoCallboardSkin.MakeButton(UIParent, {
    name = BUTTON_NAME,
    secure = true,
    point = { "CENTER", UIParent, "CENTER", 0, -150 },
  }))
  button:SetMovable(true)
  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp")
  button:SetAttribute("type", "item")

  button:SetScript("OnDragStart", function()
    if not InCombatLockdown() and not RT.IsInterfaceLocked() then button:StartMoving() end
  end)
  button:SetScript("OnDragStop", function() button:StopMovingOrSizing() end)
  button:HookScript("OnMouseUp", function(_, mouseButton)
    if mouseButton == "RightButton" then
      StopPending("fermeture manuelle")
    end
  end)

  button:Hide()

  return button
end

local function ClearBinding()
  if ClearOverrideBindings and button then
    ClearOverrideBindings(button)
  end
end

local function ApplyBinding()
  if not button then
    return
  end

  ClearBinding()

  if SetOverrideBindingClick then
    SetOverrideBindingClick(button, true, GetBinding(), BUTTON_NAME, "LeftButton")
  end
end

local function WaitCombatEnd()
  if combatQueued then
    return
  end

  combatQueued = true
  RT.api:AfterCombat(FlushAfterCombat)
end

local function WatchSequenceEvents(enabled)
  if not events or sequenceWatched == enabled then
    return
  end

  sequenceWatched = enabled
  events:Watch("BAG_UPDATE", enabled)
  RT.api:Guard("ETERNALS.WATCH_SPELLCAST", events.Watch, events, "UNIT_SPELLCAST_SUCCEEDED", enabled)
end

local function HideButton()
  if InCombatLockdown and InCombatLockdown() then
    pendingHide = true
    WaitCombatEnd()
    return false
  end

  pendingHide = nil
  ClearBinding()

  if button then
    button:Hide()
  end

  return true
end

local function ConfigureButton(entry, step)
  CreateButton()

  if InCombatLockdown and InCombatLockdown() then
    pendingConfig = { entry = entry, step = step }
    WaitCombatEnd()
    RT.api:Notify(string.format(L.ETERNALS_CONVERSION_WAITING_COMBAT, EntryItemName(entry)))
    return false
  end

  pendingConfig = nil
  pendingHide = nil

  local itemID = (step == 1) and entry.crystalItem or entry.eternalItem
  button:SetAttribute("type", "item")
  button:SetAttribute("item", ItemUseName(itemID))

  button:SetText(string.format(L.ETERNALS_BUTTON_STATUS, GetBinding(), EntryLabel(entry), step))

  button:Show()
  ApplyBinding()

  return true
end

FlushAfterCombat = function()
  combatQueued = false

  local config = pendingConfig
  pendingConfig = nil

  if config and pending then
    pendingHide = nil
    ConfigureButton(config.entry, config.step)
  elseif pendingHide and HideButton() then
    WatchSequenceEvents(false)
  end
end

StopPending = function(reason)
  if not pending and not pendingHide and not pendingConfig and button and not button:IsShown() then
    return
  end

  if pending then
    RT.api:Trace("eternals.end", reason)
  end

  pending = nil
  pendingConfig = nil
  nextQuestCheckAt = nil

  if HideButton() then
    WatchSequenceEvents(false)
  end
end

local function TouchSequence()
  if pending then
    pending.expiresAt = GetTime() + SEQUENCE_TIMEOUT
  end
end

local function AdvanceToStepTwo(entry)
  if not pending or pending.entry ~= entry then
    return
  end

  if ItemCount(entry.eternalItem) < 1 then
    RT.api:Report(RT.api:Problem("ETERNALS.ETERNAL_ITEM_MISSING", { item = EntryItemName(entry), step = 1 }))
    StopPending("eternel absent")
    return
  end

  pending.step = 2
  pending.eternalBaseline = ItemCount(entry.eternalItem)
  pending.crystalBaseline = ItemCount(entry.crystalItem)
  TouchSequence()
  ConfigureButton(entry, 2)
end

local function MatchSpell(spellName, spellID)
  local match = spellID and SPELL_LOOKUP[spellID]

  if match or type(spellName) ~= "string" or spellName == "" or not GetSpellInfo then
    return match
  end

  for id, candidate in pairs(SPELL_LOOKUP) do
    if GetSpellInfo(id) == spellName then
      return candidate
    end
  end

  return nil
end

function RT.RefreshEternalLabels()
  if pending and button then
    button:SetText(string.format(L.ETERNALS_BUTTON_STATUS, GetBinding(), EntryLabel(pending.entry), pending.step))
  end
end

local function FindQuestInLog(questID, title, preferredIndex)
  if questID > 0 then
    local index = RT.FindQuestLogIndexByID(questID, preferredIndex)
    if index then
      return index
    end
  end

  local normalized = Core.normalizeMatchText(title or "")
  if normalized == "" or not GetNumQuestLogEntries then
    return nil
  end

  for i = 1, GetNumQuestLogEntries() do
    local entry = RT.GetQuestLogEntryInfo(i)
    if entry and not entry.isHeader and Core.normalizeMatchText(entry.title or "") == normalized then
      return i
    end
  end

  return nil
end

local function SequenceQuestGone()
  local questID = tonumber(pending.questID) or 0
  local index = FindQuestInLog(questID, pending.title, pending.questLogIndex)

  if index then
    pending.questLogIndex = index
    pending.seenInLog = true
    return false
  end

  if pending.seenInLog then
    return true, "quete absente du journal"
  end

  return false
end

function RT.CheckEternalQuestStillActive(source, force)
  if not pending then
    return
  end

  local now = GetTime()
  if not force and nextQuestCheckAt and now < nextQuestCheckAt then
    return
  end

  nextQuestCheckAt = now + QUEST_CHECK_INTERVAL

  local itemName = EntryItemName(pending.entry)
  local gone, reason = SequenceQuestGone()

  if gone then
    RT.api:Report(RT.api:Problem("ETERNALS.QUEST_GONE", { item = itemName, source = source }))
    StopPending(tostring(reason) .. " source=" .. tostring(source))
    return
  end

  if pending.expiresAt and now >= pending.expiresAt then
    RT.api:Report(RT.api:Problem("ETERNALS.SEQUENCE_TIMEOUT",
        { item = itemName, source = source, seconds = SEQUENCE_TIMEOUT }))
    StopPending("expiration source=" .. tostring(source))
  end
end

function RT.WatchEternalSequence()
  if not pending then
    return IDLE_WATCH_INTERVAL
  end

  RT.CheckEternalQuestStillActive("poll")
end

function RT.HandleEternalQuest()
  if not IsEnabled() then
    return
  end

  local accepted = RT.lastAcceptedQuest
  if type(accepted) ~= "table" then
    return
  end

  local text = accepted.title or ""

  if text == "" and accepted.questLogIndex then
    local info = RT.GetQuestLogEntryInfo(accepted.questLogIndex)
    if type(info) == "table" then
      text = info.title or ""
    end
  end

  if text == "" and accepted.questLogIndex and GetQuestLogTitle then
    text = GetQuestLogTitle(accepted.questLogIndex) or ""
  end

  local entry = FindEntryInText(text)
  if not entry then
    return
  end

  local crystals = ItemCount(entry.crystalItem)
  if crystals < CRYSTAL_STACK_SIZE then
    RT.api:Report(RT.api:Problem("ETERNALS.NOT_ENOUGH_CRYSTALS",
        { item = EntryItemName(entry), count = crystals, required = CRYSTAL_STACK_SIZE }))
    return
  end

  pending = {
    entry = entry,
    step = 1,
    questID = tonumber(accepted.questID) or 0,
    questLogIndex = accepted.questLogIndex,
    title = text,
    seenInLog = false,
    eternalBaseline = ItemCount(entry.eternalItem),
    expiresAt = GetTime() + SEQUENCE_TIMEOUT,
  }
  nextQuestCheckAt = nil

  WatchSequenceEvents(true)
  ConfigureButton(entry, 1)
end

local function OnEvent(event, arg1, arg2, arg3, arg4, arg5)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON_NAME then
      events:Unlisten("ADDON_LOADED")

      if type(EbonAPIAutoCallboardEternalsDB) ~= "table" then
        EbonAPIAutoCallboardEternalsDB = { enabled = true, binding = DEFAULT_BINDING }
      end

      RT.api:On("READY", function()
        if InCombatLockdown() then
          RT.api:AfterCombat(CreateButton)
        else
          CreateButton()
        end
      end)

      SLASH_AUTOCALLBOARDETERNALS1 = "/acbe"
      SlashCmdList.AUTOCALLBOARDETERNALS = function(input)
        local command = string.lower(input or "")
        command = command:gsub("^%s+", ""):gsub("%s+$", "")

        if command == "bind" or string.find(command, "^bind ") then
          local key = string.upper((command:gsub("^bind%s*", "")))
          if key ~= "" then
            EbonAPIAutoCallboardEternalsDB.binding = key
            if pending then
              ConfigureButton(pending.entry, pending.step)
            end
            RT.api:Notify(string.format(L.ETERNALS_BIND_DONE, key))
          else
            RT.api:Report(RT.api:Problem("ETERNALS.BIND_KEY_MISSING", { input = command }))
          end
        else
          RT.api:Report(RT.api:Problem("ETERNALS.UNKNOWN_COMMAND", { input = command }))
        end
      end
    end

    return
  end

  if not pending then
    return
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    if arg1 ~= "player" then
      return
    end

    local match = MatchSpell(arg2, tonumber(arg5))

    if not match or match.entry ~= pending.entry then
      return
    end

    if match.step == 1 and pending.step == 1 then
      AdvanceToStepTwo(pending.entry)
    elseif match.step == 2 and pending.step == 2 then
      StopPending("succes")
    end

    return
  end

  if event == "BAG_UPDATE" then
    local eternals = ItemCount(pending.entry.eternalItem)

    if pending.step == 1 then
      if eternals > (pending.eternalBaseline or 0) then
        AdvanceToStepTwo(pending.entry)
      elseif eternals < (pending.eternalBaseline or 0) then
        pending.eternalBaseline = eternals
      end
    elseif eternals > (pending.eternalBaseline or 0) then
      pending.eternalBaseline = eternals
    elseif eternals < (pending.eternalBaseline or 0)
        and ItemCount(pending.entry.crystalItem) > (pending.crystalBaseline or 0) then
      StopPending("succes")
    end

    return
  end
end

events = RT.NewEventRelay(OnEvent)
events:Listen("ADDON_LOADED")
