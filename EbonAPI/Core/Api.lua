EbonAPI = EbonAPI or {}

local Lib = EbonAPI.Lib

local type, pairs, tostring, tonumber = type, pairs, tostring, tonumber
local setmetatable, pcall, error = setmetatable, pcall, error
local report = Lib.report

EbonAPI.name = "EbonAPI"

local VERSION = GetAddOnMetadata(EbonAPI.name, "Version")
local MAJOR, MINOR, PATCH = string.match(VERSION, "^(%d+)%.(%d+)%.(%d+)")

EbonAPI.MAJOR = tonumber(MAJOR)
EbonAPI.MINOR = tonumber(MINOR)
EbonAPI.PATCH = tonumber(PATCH)
EbonAPI.version = VERSION

local NAME_MAX = 32

EbonAPI.NAME_MAX = NAME_MAX

local runFns, runOwners, runIndex, runCount

local function ownerName(owner)
  return owner and (owner.addonName or owner.name)
end

local function runner(...)
  while runIndex <= runCount do
    local index = runIndex
    runIndex = index + 1

    runFns[index](...)
  end
end

function EbonAPI.fanout(fns, owners, count, ...)
  if count == 0 then
    return 0
  end

  local savedFns, savedOwners, savedIndex, savedCount = runFns, runOwners, runIndex, runCount

  runFns, runOwners, runIndex, runCount = fns, owners, 1, count

  while runIndex <= runCount do
    local ok, err = pcall(runner, ...)

    if ok then
      break
    end

    report(err, ownerName(runOwners[runIndex - 1]))
  end

  runFns, runOwners, runIndex, runCount = savedFns, savedOwners, savedIndex, savedCount

  return count
end

local fanout = EbonAPI.fanout

local events = {}
local sticky = {}
local stickyValues = {}

function EbonAPI:DeclareSticky(event)
  sticky[event] = true
end

local function listFor(event)
  local list = events[event]

  if not list then
    list = { n = 0, fns = {}, owners = {}, busy = 0 }
    events[event] = list
  end

  return list
end

local function mutable(list)
  if list.busy > 0 then
    local fns, owners = {}, {}
    local oldFns, oldOwners = list.fns, list.owners

    for index = 1, list.n do
      fns[index] = oldFns[index]
      owners[index] = oldOwners[index]
    end

    list.fns, list.owners = fns, owners
  end

  return list
end

local function subscribe(owner, event, fn)
  if type(event) ~= "string" then
    error("EbonAPI: the event name must be a string, got " .. type(event), 2)
  end

  if type(fn) ~= "function" then
    error("EbonAPI: the callback for '" .. event .. "' must be a function, got " .. type(fn), 2)
  end

  local list = listFor(event)
  local fns, owners = list.fns, list.owners

  for index = 1, list.n do
    if fns[index] == fn and owners[index] == owner then
      return false
    end
  end

  mutable(list)

  local n = list.n + 1
  list.n = n
  list.fns[n] = fn
  list.owners[n] = owner

  if sticky[event] then
    local held = stickyValues[event]

    if held then
      local ok, err = pcall(fn, event, held[1], held[2], held[3], held[4], held[5], held[6])

      if not ok then
        report(err, ownerName(owner))
      end
    end
  end

  return true
end

local function unsubscribe(owner, event, fn)
  local list = events[event]

  if not list or list.n == 0 then
    return false
  end

  local removed = false

  for index = list.n, 1, -1 do
    if list.owners[index] == owner and (fn == nil or list.fns[index] == fn) then
      mutable(list)

      local fns, owners, n = list.fns, list.owners, list.n

      for slide = index, n - 1 do
        fns[slide] = fns[slide + 1]
        owners[slide] = owners[slide + 1]
      end

      fns[n] = nil
      owners[n] = nil
      list.n = n - 1
      removed = true
    end
  end

  return removed
end

local function unsubscribeAll(owner)
  for event in pairs(events) do
    unsubscribe(owner, event, nil)
  end
end

function EbonAPI:Emit(event, a, b, c, d, e, f)
  if sticky[event] then
    local held = stickyValues[event]

    if not held then
      held = {}
      stickyValues[event] = held
    end

    held[1], held[2], held[3], held[4], held[5], held[6] = a, b, c, d, e, f
  end

  local list = events[event]

  if not list then
    return 0
  end

  local count = list.n

  if count == 0 then
    return 0
  end

  list.busy = list.busy + 1

  local served = fanout(list.fns, list.owners, count, event, a, b, c, d, e, f)

  list.busy = list.busy - 1

  return served
end

function EbonAPI:On(event, fn)
  return subscribe(self, event, fn)
end

function EbonAPI:Off(event, fn)
  return unsubscribe(self, event, fn)
end

function EbonAPI:LastValue(event)
  local held = stickyValues[event]

  if not held then
    return nil
  end

  return held[1], held[2], held[3], held[4], held[5], held[6]
end

function EbonAPI:ClearSticky(event)
  if event == nil then
    for key in pairs(stickyValues) do
      stickyValues[key] = nil
    end

    return
  end

  stickyValues[event] = nil
end

local features = {}

function EbonAPI:RegisterFeature(name, available)
  local value = available and true or false

  if features[name] == value then
    return
  end

  features[name] = value
  self:Emit("FEATURE_CHANGED", name, value)
end

function EbonAPI:HasFeature(name)
  return features[name] == true
end

function EbonAPI:Features()
  return Lib.copyShallow(features)
end

local Handle = {}
Handle.__index = Handle

EbonAPI.Handle = Handle
EbonAPI._addons = {}

EbonAPI._teardowns = {}

function EbonAPI:AddTeardown(fn)
  self._teardowns[#self._teardowns + 1] = fn
end

function Handle:On(event, fn)
  return subscribe(self, event, fn)
end

function Handle:Off(event, fn)
  return unsubscribe(self, event, fn)
end

function Handle:OffAll()
  unsubscribeAll(self)

  local teardowns = EbonAPI._teardowns

  for index = 1, #teardowns do
    local ok, err = pcall(teardowns[index], self)

    if not ok then
      report(err, self.addonName)
    end
  end
end

function Handle:Emit(event, a, b, c, d, e, f)
  return EbonAPI:Emit(event, a, b, c, d, e, f)
end

function Handle:LastValue(event)
  return EbonAPI:LastValue(event)
end

function Handle:HasFeature(name)
  return EbonAPI:HasFeature(name)
end

function Handle:IsReady()
  return EbonAPI._ready == true
end

function Handle:GetName()
  return self.addonName
end

local function versionRefusal(name, major, minor)
  local Problems = EbonAPI.Problems

  Problems.report(Problems.make(name, "EBONAPI.ADDON.VERSION_TOO_OLD",
    { addon = name, needs = tostring(major) .. "." .. tostring(minor), have = EbonAPI.version }))
end

local CONNECTION = { globals = "table", icon = "string", url = "string", updates = "boolean", version = "string" }

local function connectionProblem(name, info)
  if type(info) ~= "table" then
    return "the fourth argument must be a table (globals, icon, updates, url, version), got " .. type(info)
  end

  local keys = Lib.sortedKeys(info)

  for index = 1, #keys do
    local key = keys[index]
    local value = info[key]
    local kind = CONNECTION[key]

    if not kind then
      return 'unknown connection option "' .. tostring(key) .. '" (known: globals, icon, updates, url, version)'
    end

    if type(value) ~= kind then
      return 'connection option "' .. key .. '" expects a ' .. (kind == "string" and "non-empty text" or kind)
        .. ", got " .. type(value)
    end

    if value == "" then
      return 'connection option "' .. key .. '" expects a non-empty text, got an empty text'
    end
  end

  if info.version and not info.updates then
    return 'connection option "version" needs updates = true'
  end

  if info.updates and not EbonAPI.ModuleLoader.owns(name) then
    local version = info.version or (GetAddOnMetadata and GetAddOnMetadata(name, "Version"))

    if not EbonAPI.Version.parse(version) then
      return "updates needs a version, from the version option or ## Version in the .toc, got " .. tostring(version)
    end
  end

  return nil
end

local function connect(handle, name, info)
  if info.url then
    handle.link = info.url
  end

  if info.icon then
    handle.icon = info.icon
  end

  -- A module follows EbonAPI's version: nothing to register for it.
  if info.updates and not EbonAPI.ModuleLoader.owns(name) then
    EbonAPI.Version.register(name, info.version or GetAddOnMetadata(name, "Version"))
  end
end

local function requiredNumber(name, part, value)
  if value == nil then
    return nil
  end

  if type(value) ~= "number" then
    error('EbonAPI:NewAddon: "' .. name .. '": the required ' .. part .. " version must be a number, got "
      .. type(value), 3)
  end

  return value
end

function EbonAPI:NewAddon(name, needMajor, needMinor, info)
  if type(name) ~= "string" or name == "" then
    error("EbonAPI:NewAddon expects a non-empty addon name, got " .. type(name), 2)
  end

  if string.find(name, "[^%w_]") or string.len(name) > NAME_MAX then
    error('EbonAPI:NewAddon: addon name "' .. name .. '" must be 1 to ' .. NAME_MAX
      .. ' letters, digits or "_"', 2)
  end

  if info ~= nil then
    local problem = connectionProblem(name, info)

    if problem then
      error('EbonAPI:NewAddon: "' .. name .. '": ' .. problem, 2)
    end
  end

  needMajor = requiredNumber(name, "major", needMajor) or self.MAJOR
  needMinor = requiredNumber(name, "minor", needMinor) or 0

  if needMajor > self.MAJOR or (needMajor == self.MAJOR and needMinor > self.MINOR) then
    versionRefusal(name, needMajor, needMinor)
    return nil
  end

  local handle = self._addons[name]
  local fresh = handle == nil

  if fresh then
    handle = setmetatable({ addonName = name }, Handle)
    self._addons[name] = handle
    EbonAPI.Catch.declare(name, debugstack and debugstack(2, 1, 0) or "", info and info.globals)
  end

  if info ~= nil then
    connect(handle, name, info)
  end

  if fresh then
    if self._consumerHook then
      self._consumerHook(name)
    end

    self:Emit("ADDON_CONNECTED", name)
  end

  return handle
end

function EbonAPI:AddonLink(name)
  local handle = self._addons[name]

  return handle and handle.link
end

function Handle:Link()
  return self.link
end

function EbonAPI:AddonIcon(name)
  local handle = self._addons[name]

  return handle and Lib.icon(handle.icon)
end

function Handle:Icon()
  return Lib.icon(self.icon)
end

function EbonAPI:AddonNames()
  return Lib.sortedKeys(self._addons)
end

EbonAPI._ready = false

function EbonAPI:IsReady()
  return self._ready == true
end

function EbonAPI:GetVersion()
  return self.version, self.MAJOR, self.MINOR, self.PATCH
end

EbonAPI:DeclareSticky("READY")
EbonAPI:DeclareSticky("LANGUAGE_CHANGED")
