EbonAPI = EbonAPI or {}
EbonAPI.ModuleLoader = {}

local Modules = EbonAPI.ModuleLoader
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local DB = EbonAPI.DB
local Problems = EbonAPI.Problems
local Migration = EbonAPI.Migration

local type, pairs, ipairs, sort, sub = type, pairs, ipairs, table.sort, string.sub

Problems.declare("EbonAPI", "EBONAPI", {
  ["MODULE.LOAD_FAILED"] = { class = "panne", key = "module" },
  ["MODULE.LEGACY_ADDON"] = { class = "panne", key = "module" },
})

local FIELD = "X-EbonAPI-Module"
-- The folder is "EbonAPI-<Name>"; the name the module gives to EbonAPI:NewAddon (its data bucket, kit
-- entry, window ids) is read from this field, and is the folder name when the field is absent.
local KEY_FIELD = "X-EbonAPI-Name"

local list = nil
local byName = {}
local applied = {}
local outcome = {}

local metadata = Migration.metadata

local function discover()
  if list then
    return list
  end

  list = {}

  for index = 1, GetNumAddOns() do
    local name, title, notes = GetAddOnInfo(index)

    if name and metadata(name, FIELD) == "1" then
      -- A module ships inside EbonAPI and has no version of its own: it takes EbonAPI's.
      local module = { name = name, key = metadata(name, KEY_FIELD) or name, title = title or name,
        notes = notes ~= "" and notes or nil, version = metadata(name, "Version") or EbonAPI.version }

      list[#list + 1] = module
      byName[name] = module
    end
  end

  sort(list, function(a, b)
    return a.name < b.name
  end)

  return list
end

local function choices()
  if not DB.isAttached() then
    return nil
  end

  local account = DB.shared().account

  if type(account.modules) ~= "table" then
    account.modules = {}
  end

  return account.modules
end

-- A standalone version leaves its own bucket (api:DB), its kit entry (minimap button, shortcuts)
-- or a window position in EbonAPIDB: such a trace means the player used it before.
local function traced(name)
  local addons = DB.root().addons

  if addons[name] then
    return true
  end

  local own = addons.EbonAPI and addons.EbonAPI.account
  local kit = own and own.kit

  if type(kit) == "table" and type(kit[name]) == "table" then
    return true
  end

  local windows = own and own.windows
  local prefix = "addon:" .. name .. ":"

  if type(windows) == "table" then
    for id in pairs(windows) do
      if type(id) == "string" and sub(id, 1, #prefix) == prefix then
        return true
      end
    end
  end

  return false
end

function Modules.list()
  return discover()
end

function Modules.isModule(name)
  discover()

  return byName[name] ~= nil
end

function Modules.isEnabled(name)
  local saved = Modules.isModule(name) and choices()

  if not saved then
    return false
  end

  if type(saved[name]) == "boolean" then
    return saved[name]
  end

  local module = byName[name]

  return traced(module.key) or Migration.hasData(module) and true or false
end

function Modules.setEnabled(name, enabled)
  if not Modules.isModule(name) then
    return false, "unknown_module"
  end

  local saved = choices()

  if not saved then
    return false
  end

  enabled = enabled and true or false

  local changed = Modules.isEnabled(name) ~= enabled

  saved[name] = enabled

  if enabled then
    local _, _, _, active = GetAddOnInfo(name)

    if not active then
      EnableAddOn(name)
    end
  end

  if changed then
    Log.trace("module", name, enabled and "enabled" or "disabled", "applies at reload")
  end

  return changed
end

function Modules.pending()
  for _, module in ipairs(discover()) do
    local wanted = applied[module.name]

    if wanted ~= nil and wanted ~= Modules.isEnabled(module.name) then
      return true
    end
  end

  return false
end

function Modules.anyDisabled()
  for _, module in ipairs(discover()) do
    if not Modules.isEnabled(module.name) then
      return true
    end
  end

  return false
end

local function load(module)
  local name = module.name
  local _, _, _, active = GetAddOnInfo(name)

  if not active then
    EnableAddOn(name)
  end

  Migration.adopt(module)

  local loaded, reason = LoadAddOn(name)

  if loaded then
    Migration.settle(module)
  end

  outcome[name] = loaded and true or reason or "failed"
end

-- Loads one wanted module and returns the problem code it raised, if any.
local function loadOne(module)
  local name = module.name
  local former = Migration.former(module)

  if former then
    outcome[name] = "legacy"
    Problems.degrade(Problems.new("EbonAPI", "MODULE.LEGACY_ADDON", { module = name, addon = former }))

    return "MODULE.LEGACY_ADDON"
  end

  if not IsAddOnLoaded(name) and not Lib.safeCall(load, module) then
    outcome[name] = "error"
  end

  if outcome[name] == true or IsAddOnLoaded(name) then
    outcome[name] = true
    Log.trace("module", name, "loaded")

    return nil
  end

  Problems.degrade(Problems.new("EbonAPI", "MODULE.LOAD_FAILED", { module = name, failure = outcome[name] }))

  return "MODULE.LOAD_FAILED"
end

-- A problem entry is closed by its code, so it closes only when no module raised that code this session.
function Modules.load()
  local raised = {}

  for _, module in ipairs(discover()) do
    local name = module.name
    local wanted = Modules.isEnabled(name)

    applied[name] = wanted

    if wanted then
      local code = loadOne(module)

      raised[code or true] = true
    else
      outcome[name] = "off"
    end
  end

  for _, code in ipairs({ "MODULE.LOAD_FAILED", "MODULE.LEGACY_ADDON" }) do
    if not raised[code] then
      Problems.restore("EbonAPI", code)
    end
  end
end

function Modules.state(name)
  local module = byName[name]
  local loaded = IsAddOnLoaded(name) and true or false
  local result = outcome[name]

  return {
    name = name,
    title = module.title,
    version = module.version,
    enabled = Modules.isEnabled(name),
    loaded = loaded,
    reason = not loaded and (type(result) == "string" and result or "not_loaded") or nil,
  }
end

function EbonAPI:Modules()
  local out = {}

  for index, module in ipairs(discover()) do
    out[index] = Modules.state(module.name)
  end

  return out
end

function EbonAPI:IsModuleEnabled(name)
  return Modules.isEnabled(name)
end

function EbonAPI:SetModuleEnabled(name, enabled)
  return Modules.setEnabled(name, enabled)
end
