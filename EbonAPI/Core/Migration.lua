EbonAPI = EbonAPI or {}
EbonAPI.Migration = {}

local Migration = EbonAPI.Migration
local Lib = EbonAPI.Lib
local DB = EbonAPI.DB
local Log = EbonAPI.Log

local type, ipairs, next = type, ipairs, next
local gmatch, match = string.gmatch, string.match

-- Everything here is driven by the fields of a module's .toc; no module or variable name lives in this file.
--   X-EbonAPI-Legacy:                     the folder of the former standalone addon (its carrier)
--   X-EbonAPI-Legacy-Variables:           "former=new,former=new" for the account variables
--   X-EbonAPI-Legacy-CharacterVariables:  the same for the per-character variables
-- A carrier is a folder named like the former addon, with a .toc and no code, that declares the former
-- saved variables so that the game keeps loading the old files.
local LEGACY_FIELD = "X-EbonAPI-Legacy"
local CARRIER_FIELD = "X-EbonAPI-Carrier"

local TAKEN, DONE = "taken", "done"
local RECORDS = "adoptions"

-- Each scope has its variable list field and the place of its records in EbonAPIDB (account, or the current
-- character): the account variables are taken once, the character ones at the first login of each character.
local SCOPES = {
  { field = "X-EbonAPI-Legacy-Variables", holder = function(store) return store.account end },
  { field = "X-EbonAPI-Legacy-CharacterVariables", holder = function(store) return store.char end },
}

local loadedCarriers = {}

function Migration.metadata(name, field)
  local value = GetAddOnMetadata(name, field)

  return type(value) == "string" and value ~= "" and value or nil
end

local metadata = Migration.metadata

local function carrierFolder(module)
  return metadata(module.name, LEGACY_FIELD)
end

-- The pairs {former, new} a module declares for one scope.
local function variables(module, scope)
  local out = {}

  for entry in gmatch(metadata(module.name, scope.field) or "", "[^,]+") do
    local former, current = match(entry, "^%s*([%w_]+)%s*=%s*([%w_]+)%s*$")

    if former then
      out[#out + 1] = { former = former, current = current }
    end
  end

  return out
end

-- Calls visit(scope, pair) for each variable pair of the module, scope by scope; the first truthy result stops
-- the walk and is returned.
local function eachVariable(module, visit)
  for _, scope in ipairs(SCOPES) do
    for _, pair in ipairs(variables(module, scope)) do
      local found = visit(scope, pair)

      if found then
        return found
      end
    end
  end

  return nil
end

local function records(scope, create)
  if not DB.isAttached() then
    return nil
  end

  local holder = scope.holder(DB.shared())

  if not holder then
    return nil
  end

  if type(holder[RECORDS]) ~= "table" then
    if not create then
      return nil
    end

    holder[RECORDS] = {}
  end

  return holder[RECORDS]
end

local function recorded(scope, current)
  local list = records(scope)

  return list and list[current]
end

-- The former standalone addon, still installed and enabled: a folder with the carrier's name that does not
-- declare itself a carrier. Its module must not load (two addons would share one name) and the carrier
-- must not load either.
function Migration.former(module)
  local folder = carrierFolder(module)

  if not folder then
    return nil
  end

  local name, _, _, enabled = GetAddOnInfo(folder)

  if name and enabled and not metadata(folder, CARRIER_FIELD) then
    return folder
  end

  return nil
end

-- Loads the module's carrier once per session. A missing carrier is not an error: a clean install has none.
local function loadCarrier(module)
  local folder = carrierFolder(module)

  if not folder or Migration.former(module) then
    return false
  end

  if loadedCarriers[folder] ~= nil then
    return loadedCarriers[folder]
  end

  local name, _, _, enabled = GetAddOnInfo(folder)
  local ready = false

  if name and metadata(folder, CARRIER_FIELD) then
    if not enabled then
      EnableAddOn(folder)
    end

    ready = IsAddOnLoaded(folder) and true or false

    if not ready then
      Lib.safeCall(LoadAddOn, folder)
      ready = IsAddOnLoaded(folder) and true or false
    end
  end

  loadedCarriers[folder] = ready

  return ready
end

-- Whether any variable of the module still has to be taken or released from its carrier. Only a proven
-- release (DONE) is final; a carrier that had nothing is looked at again next session, so a data file that
-- shows up later is never ignored.
local function pending(module)
  return eachVariable(module, function(scope, pair)
    return recorded(scope, pair.current) ~= DONE
  end) or false
end

-- Whether a former addon left data for this module: a record of an earlier takeover, or a value in one of
-- the carrier's (or the former addon's) variables. Loading the carrier only reads its files.
function Migration.hasData(module)
  if not DB.isAttached() then
    return false
  end

  if eachVariable(module, function(scope, pair) return recorded(scope, pair.current) end) then
    return true
  end

  -- With the former addon itself installed, its variables are already loaded: there is no carrier to read.
  if not Migration.former(module) and (not pending(module) or not loadCarrier(module)) then
    return false
  end

  return eachVariable(module, function(_, pair) return _G[pair.former] ~= nil end) or false
end

-- First step, before the module loads: each variable of the module that is still nil is set to the very
-- table of the carrier's variable (both files then keep the data until the logout). The module's own file,
-- when it has data, replaces the value as the module loads. A carrier variable that is not a table is ignored.
function Migration.adopt(module)
  if not DB.isAttached() or not pending(module) or not loadCarrier(module) then
    return
  end

  eachVariable(module, function(scope, pair)
    if recorded(scope, pair.current) ~= DONE and _G[pair.current] == nil and type(_G[pair.former]) == "table" then
      _G[pair.current] = _G[pair.former]
    end
  end)
end

-- Second step, after the module loaded. A variable that still is the carrier's own table is taken over:
-- the takeover is recorded. A variable of the module with its own data, a different and non-empty table,
-- ends the takeover once one was recorded: the carrier's variable is set to nil, so the game rewrites the
-- carrier's file empty at the logout. Without a record the carrier is left intact.
function Migration.settle(module)
  local folder = carrierFolder(module)

  if not DB.isAttached() or not folder or not loadedCarriers[folder] then
    return
  end

  eachVariable(module, function(scope, pair)
    local state = recorded(scope, pair.current)
    local former, current = _G[pair.former], _G[pair.current]
    local list = state ~= DONE and type(former) == "table" and type(current) == "table" and records(scope, true)

    if not list then
      return
    end

    if current == former then
      if state ~= TAKEN then
        list[pair.current] = TAKEN
        Log.trace("migration", module.name, pair.current, "taken over")
      end
    elseif state == TAKEN and next(current) ~= nil then
      _G[pair.former] = nil
      list[pair.current] = DONE
      Log.trace("migration", module.name, pair.current, "carrier released")
    end
  end)
end
