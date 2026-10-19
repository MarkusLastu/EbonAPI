EbonAPI = EbonAPI or {}
EbonAPI.AddonList = {}

local AddonList = EbonAPI.AddonList
local Lib = EbonAPI.Lib
local Palette = EbonAPI.Palette
local Modules = EbonAPI.ModuleLoader

local gsub = string.gsub

-- The game's addon list (Esc, AddOns) writes each title from the `.toc`, whose color is fixed. EbonAPI and its
-- modules are repainted here in the accent color of the interface, so they follow the player's choice. The
-- character screen cannot do it: no addon code runs there, and the list shows the plain `.toc` titles.

local hooked = false

local function bare(text)
  return (gsub(gsub(text, "|c%x%x%x%x%x%x%x%x", ""), "|r", ""))
end

local function ours(name)
  return name == EbonAPI.name or Modules.isModule(name)
end

local function paint()
  local list, offsetOf = rawget(_G, "AddonListScrollFrame"), rawget(_G, "FauxScrollFrame_GetOffset")
  local offset = list and offsetOf and offsetOf(list) or 0

  for row = 1, rawget(_G, "MAX_ADDONS_DISPLAYED") or 19 do
    local text = _G["AddonListEntry" .. row .. "Title"]
    local name, title, _, enabled = GetAddOnInfo(offset + row)

    if text and name and enabled and ours(name) then
      text:SetText(Palette.code("heading") .. bare(title or name) .. "|r")
    end
  end
end

function AddonList.refresh()
  local frame = rawget(_G, "AddonList")

  if hooked and frame and frame.IsShown and frame:IsShown() then
    Lib.safeCall(rawget(_G, "AddonList_Update"))
  end
end

function AddonList.install()
  if hooked or type(rawget(_G, "AddonList_Update")) ~= "function" then
    return
  end

  hooked = true

  hooksecurefunc("AddonList_Update", function()
    Lib.safeCall(paint)
  end)
end
