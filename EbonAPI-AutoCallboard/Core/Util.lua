local Lib = EbonAPI.Lib
local ADDON_NAME = ...
local Core = AutoCallboardCore
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime

local ADDON_TITLE = "AutoCallboard"
RT.ADDON_TITLE = ADDON_TITLE

local registeredSpecialFrames = {}

local function Localized(widget, key)
  if not widget or not widget.SetText then
    return widget
  end

  return RT.api:Localized(widget, key)
end

local function GetQuestTypeName(questType)
  questType = tonumber(questType) or 0
  return L.QUEST_TYPE_NAMES[questType] or L.QUEST_TYPE_OTHER
end

local function LinkMethod()
  return RT.api:LinkMethod()
end

local function OpenLink(url)
  if type(url) ~= "string" or url == "" then
    return nil
  end

  return RT.api:OpenLink(url)
end

local function LinkTip()
  local method = LinkMethod()

  if method == "open" then
    return L.LINK_TIP_OPEN
  elseif method == "copy" then
    return L.LINK_TIP_COPY
  end

  return nil
end

local function NormalizeCopper(value)
  value = tonumber(value) or 0
  if value < 0 then
    value = 0
  end

  return math.floor(value)
end

local function FormatMoney(copper)
  copper = NormalizeCopper(copper)

  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local coin = copper % 100
  local parts = {}

  if gold > 0 then
    table.insert(parts, tostring(gold) .. "g")
  end

  if silver > 0 or gold > 0 then
    table.insert(parts, tostring(silver) .. "s")
  end

  table.insert(parts, tostring(coin) .. "c")

  return table.concat(parts, " ")
end

local function SecondsRemaining(untilTime)
  if not untilTime then
    return 0
  end

  return math.max(0, untilTime - GetTime())
end

local function FormatSeconds(value)
  return tostring(math.floor(math.max(0, value or 0))) .. "s"
end

local function RegisterSpecialFrame(frameName)
  if type(frameName) ~= "string" or frameName == "" or registeredSpecialFrames[frameName] then
    return
  end

  if type(UISpecialFrames) ~= "table" then
    return
  end

  for i = 1, #(UISpecialFrames) do
    if UISpecialFrames[i] == frameName then
      registeredSpecialFrames[frameName] = true
      return
    end
  end

  table.insert(UISpecialFrames, frameName)
  registeredSpecialFrames[frameName] = true
end

local function ResolveFramePath(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end

  local current

  for segment in string.gmatch(path, "[^%.]+") do
    if not current then
      current = _G[segment]
    elseif type(current) == "table" then
      current = current[segment]
    else
      return nil
    end

    if not current then
      return nil
    end
  end

  return current
end

local function RunFrameScript(target, scriptName)
  if not target.GetScript then
    return false
  end

  local script = target:GetScript(scriptName)
  if not script then
    return false
  end

  script(target, "LeftButton")
  return true
end

local function CompactText(value)
  if value == nil then
    return "nil"
  end

  value = Core.stripColorCodes(tostring(value))
  value = value:gsub("|", "/")
  value = value:gsub("%s+", " ")

  if value:len() > 80 then
    return value:sub(1, 77) .. "..."
  end

  return value
end

local function FrameName(target)
  if not target then
    return "nil"
  end

  if target.GetName and target:GetName() then
    return target:GetName()
  end

  return tostring(target)
end

local function FrameType(target)
  if target and target.GetObjectType then
    return target:GetObjectType()
  end

  return type(target)
end

local function FrameText(target)
  local texts = {}

  if target and target.GetText then
    local value = target:GetText()
    if value and value ~= "" then
      table.insert(texts, CompactText(value))
    end
  end

  if target and target.GetRegions then
    local regions = { target:GetRegions() }
    for i = 1, #(regions) do
      local region = regions[i]
      if region and region.GetText then
        local value = region:GetText()
        if value and value ~= "" then
          table.insert(texts, CompactText(value))
        end
      end
    end
  end

  if #(texts) == 0 then
    return ""
  end

  return table.concat(texts, " | ")
end

local function FrameSummary(target)
  if not target then
    return "nil"
  end

  local parts = { FrameName(target), FrameType(target) }

  if target.GetID then
    table.insert(parts, "id=" .. tostring(target:GetID()))
  end

  if target.IsShown then
    table.insert(parts, "shown=" .. tostring(target:IsShown() and true or false))
  end

  if target.IsVisible then
    table.insert(parts, "visible=" .. tostring(target:IsVisible() and true or false))
  end

  if target.IsEnabled then
    table.insert(parts, "enabled=" .. tostring(target:IsEnabled() and true or false))
  end

  local text = FrameText(target)
  if text ~= "" then
    table.insert(parts, "text=\"" .. text .. "\"")
  end

  return table.concat(parts, " ")
end

function RT.ShowIf(frame, shown)
  Lib.setShown(frame, shown)
end

local silenceDepth = 0
local savedPlaySound, savedPlaySoundFile

local function MuteSound() end

local function BeginSilence()
  silenceDepth = silenceDepth + 1

  if silenceDepth > 1 then
    return
  end

  savedPlaySound = PlaySound
  savedPlaySoundFile = PlaySoundFile
  PlaySound = MuteSound
  PlaySoundFile = MuteSound
end

local function EndSilence()
  silenceDepth = silenceDepth - 1

  if silenceDepth > 0 then
    return
  end

  silenceDepth = 0
  PlaySound = savedPlaySound
  PlaySoundFile = savedPlaySoundFile
  savedPlaySound = nil
  savedPlaySoundFile = nil
end

local function ClickNamedFrame(frameName, label)
  local target = ResolveFramePath(frameName)

  if not target then
    return false, RT.api:Problem("UTIL.CLICK_FRAME_MISSING", { frame = tostring(frameName) })
  end

  if target.IsShown and not target:IsShown() then
    return false, RT.api:Problem("UTIL.CLICK_FRAME_HIDDEN", { frame = tostring(frameName) })
  end

  RT.api:Trace("click", label, FrameSummary(target))

  BeginSilence()
  local clicked = RT.api:Guard("click", function()
        if target.Click then
          target:Click()
          return true
        end

        if RunFrameScript(target, "OnClick") then
          return true
        end

        if RunFrameScript(target, "OnMouseDown") then
          RunFrameScript(target, "OnMouseUp")
          return true
        end

        if RunFrameScript(target, "OnMouseUp") then
          return true
        end

        return false
    end)
  EndSilence()

  if clicked == nil then
    return false
  end

  if not clicked then
    return false, RT.api:Problem("UTIL.CLICK_NO_HANDLER", { frame = tostring(frameName) })
  end

  return true
end

RT.ClickNamedFrame = ClickNamedFrame

function RT.SavePoint(frame, store)
  if not frame or type(store) ~= "table" then
    return
  end

  local point, _, relativePoint, x, y = frame:GetPoint(1)

  store.point = point or "CENTER"
  store.relativePoint = relativePoint or "CENTER"
  store.x = x or 0
  store.y = y or 0
end

function RT.RestorePoint(frame, store)
  if not frame or type(store) ~= "table" then
    return
  end

  frame:ClearAllPoints()
  frame:SetPoint(store.point or "CENTER", UIParent,
      store.relativePoint or "CENTER", store.x or 0, store.y or 0)
end

function RT.IsUnder(frame, x, y)
  if not frame or not frame:IsShown() then
    return false
  end

  local left, right = frame:GetLeft(), frame:GetRight()
  local top, bottom = frame:GetTop(), frame:GetBottom()

  return left and right and top and bottom
      and x >= left and x <= right and y >= bottom and y <= top
end

local function NewEventRelay(dispatch)
  local relay = { listeners = {}, active = {} }

  function relay:Listen(event)
    local listener = self.listeners[event]

    if not listener then
      listener = function(...)
        dispatch(event, ...)
      end
      self.listeners[event] = listener
    end

    local added = RT.api:OnEvent(event, listener)
    self.active[event] = true

    return added
  end

  function relay:Unlisten(event)
    local listener = self.listeners[event]

    if not listener then
      return false
    end

    self.active[event] = nil

    return RT.api:OffEvent(event, listener)
  end

  function relay:Watch(event, enabled)
    if enabled then
      return self:Listen(event)
    end

    return self:Unlisten(event)
  end

  function relay:IsListening(event)
    return self.active[event] == true
  end

  return relay
end

RT.NewEventRelay = NewEventRelay
RT.Localized = Localized
RT.GetQuestTypeName = GetQuestTypeName
RT.LinkMethod = LinkMethod
RT.OpenLink = OpenLink
RT.LinkTip = LinkTip
RT.NormalizeCopper = NormalizeCopper
RT.FormatMoney = FormatMoney
RT.SecondsRemaining = SecondsRemaining
RT.FormatSeconds = FormatSeconds
RT.RegisterSpecialFrame = RegisterSpecialFrame
RT.ResolveFramePath = ResolveFramePath
RT.CompactText = CompactText
RT.FrameName = FrameName
RT.FrameType = FrameType
RT.FrameSummary = FrameSummary
