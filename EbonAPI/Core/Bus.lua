EbonAPI = EbonAPI or {}
EbonAPI.Bus = {}

local Bus = EbonAPI.Bus
local Lib = EbonAPI.Lib
local Listeners = EbonAPI.Listeners
local Handle = EbonAPI.Handle

local type, error, pairs, pcall = type, error, pairs, pcall
local remove = table.remove
local report = Lib.report

local frame = CreateFrame("Frame", "EbonAPIBusFrame")
local handlers = {}
local core = {}
local tickers = {}
local tickerCount = 0
local running = false

Bus.frame = frame

local function listening(event)
  local own = core[event]

  if own and own.n > 0 then
    return true
  end

  local list = handlers[event]

  return list ~= nil and list.n > 0
end

local function dispatch(_, event, ...)
  local own = core[event]

  if own then
    own:fire(...)
  end

  local list = handlers[event]

  if list then
    list:fire(...)
  end
end

frame:SetScript("OnEvent", dispatch)

local function subscribe(registry, event, fn, who, owner)
  if type(event) ~= "string" then
    error(who .. " expects an event name, got " .. type(event), 3)
  end

  if type(fn) ~= "function" then
    error(who .. " expects a function for '" .. event .. "', got " .. type(fn), 3)
  end

  local list = registry[event]

  if not list then
    list = Listeners.new()
    registry[event] = list
  end

  local wasListening = listening(event)

  if not list:add(fn, owner) then
    return false
  end

  if not wasListening then
    frame:RegisterEvent(event)
  end

  return true
end

local function unsubscribe(registry, event, fn, owner)
  local list = registry[event]

  if not list or not list:remove(fn, owner) then
    return false
  end

  if list.n == 0 then
    registry[event] = nil
  end

  if not listening(event) then
    frame:UnregisterEvent(event)
  end

  return true
end

function Bus.on(event, fn, owner)
  return subscribe(handlers, event, fn, "EbonAPI.Bus.on", owner)
end

function Bus.off(event, fn, owner)
  return unsubscribe(handlers, event, fn, owner)
end

function Bus.onCore(event, fn)
  return subscribe(core, event, fn, "EbonAPI.Bus.onCore")
end

function Bus.offCore(event, fn)
  return unsubscribe(core, event, fn)
end

function Bus.isRegistered(event)
  return listening(event)
end

function Bus.events()
  local seen = {}

  for event in pairs(handlers) do
    seen[event] = true
  end

  for event in pairs(core) do
    seen[event] = true
  end

  return Lib.sortedKeys(seen)
end

local dispatching = false
local dirty = false
local onUpdate

local function refreshTicker()
  if tickerCount > 0 then
    if not running then
      running = true
      frame:SetScript("OnUpdate", onUpdate)
    end
  elseif running then
    running = false
    frame:SetScript("OnUpdate", nil)
  end
end

local function compact()
  for index = tickerCount, 1, -1 do
    if tickers[index].dead then
      remove(tickers, index)
      tickerCount = tickerCount - 1
    end
  end

  dirty = false

  refreshTicker()
end

onUpdate = function(_, elapsed)
  dispatching = true

  for index = tickerCount, 1, -1 do
    local ticker = tickers[index]

    if ticker and not ticker.dead then
      local left = ticker.left - elapsed

      if left <= 0 then
        local owner = ticker.owner
        local ok, err

        if ticker.once then
          ticker.dead = true
          dirty = true
          ok, err = pcall(ticker.fn)
        else
          local every = ticker.every

          left = left + every

          if left <= 0 then
            left = every
          end

          ticker.left = left
          ok, err = pcall(ticker.fn, every)
        end

        if not ok then
          report(err, owner)
        end
      else
        ticker.left = left
      end
    end
  end

  dispatching = false

  if dirty then
    compact()
  end
end

local function checkTicker(who, id, every, fn)
  if type(id) ~= "string" then
    error(who .. " expects a ticker id, got " .. type(id), 3)
  end

  if type(fn) ~= "function" then
    error(who .. " expects a function for '" .. id .. "', got " .. type(fn), 3)
  end

  if type(every) ~= "number" or not (every > 0) then
    error(who .. ": invalid interval for '" .. id .. "', expected a number above 0, got " .. tostring(every), 3)
  end
end

local function schedule(id, every, fn, owner, once)
  for index = 1, tickerCount do
    local ticker = tickers[index]

    if ticker.id == id then
      if once or ticker.dead or ticker.every ~= every then
        ticker.left = every
      end

      ticker.every = every
      ticker.fn = fn
      ticker.owner = owner
      ticker.once = once

      if ticker.dead then
        ticker.dead = nil
        refreshTicker()
      end

      return true
    end
  end

  tickerCount = tickerCount + 1
  tickers[tickerCount] = { id = id, every = every, left = every, fn = fn, owner = owner, once = once }

  refreshTicker()

  return true
end

function Bus.tick(id, every, fn, owner)
  checkTicker("EbonAPI.Bus.tick", id, every, fn)

  return schedule(id, every, fn, owner, nil)
end

function Bus.after(id, delay, fn, owner)
  checkTicker("EbonAPI.Bus.after", id, delay, fn)

  return schedule(id, delay, fn, owner, true)
end

function Bus.untick(id)
  local removed = false

  for index = tickerCount, 1, -1 do
    local ticker = tickers[index]

    if ticker.id == id and not ticker.dead then
      removed = true

      if dispatching then
        ticker.dead = true
        dirty = true
      else
        remove(tickers, index)
        tickerCount = tickerCount - 1
      end
    end
  end

  if removed and not dispatching then
    refreshTicker()
  end

  return removed
end

function Bus.tickerCount()
  local live = 0

  for index = 1, tickerCount do
    if not tickers[index].dead then
      live = live + 1
    end
  end

  return live
end

function Handle:OnEvent(event, fn)
  if not Bus.on(event, fn, self) then
    return false
  end

  local owned = self._busEvents

  if not owned then
    owned = {}
    self._busEvents = owned
  end

  owned[#owned + 1] = event
  owned[#owned + 1] = fn

  return true
end

function Handle:OffEvent(event, fn)
  local owned = self._busEvents

  if owned then
    for index = #owned - 1, 1, -2 do
      if owned[index] == event and owned[index + 1] == fn then
        remove(owned, index + 1)
        remove(owned, index)
      end
    end
  end

  return Bus.off(event, fn, self)
end

local function own(handle, scoped)
  local owned = handle._busTickers

  if not owned then
    owned = {}
    handle._busTickers = owned
  end

  if not Lib.indexOf(owned, scoped) then
    owned[#owned + 1] = scoped
  end
end

function Handle:Tick(id, every, fn)
  checkTicker("EbonAPI:Tick", id, every, fn)

  local scoped = self.addonName .. ":" .. id

  Bus.tick(scoped, every, fn, self.addonName)
  own(self, scoped)

  return true
end

function Handle:Untick(id)
  if type(id) ~= "string" then
    error("EbonAPI:Untick expects a ticker id, got " .. type(id), 2)
  end

  local scoped = self.addonName .. ":" .. id

  if self._busTickers then
    Lib.removeValue(self._busTickers, scoped)
  end

  return Bus.untick(scoped)
end

function Handle:After(id, delay, fn)
  checkTicker("EbonAPI:After", id, delay, fn)

  local scoped = self.addonName .. "/" .. id

  Bus.after(scoped, delay, fn, self.addonName)
  own(self, scoped)

  return true
end

function Handle:CancelAfter(id)
  if type(id) ~= "string" then
    error("EbonAPI:CancelAfter expects a timer id, got " .. type(id), 2)
  end

  local scoped = self.addonName .. "/" .. id

  if self._busTickers then
    Lib.removeValue(self._busTickers, scoped)
  end

  return Bus.untick(scoped)
end

EbonAPI:AddTeardown(function(handle)
  local owned = handle._busEvents

  if owned then
    for index = #owned - 1, 1, -2 do
      Bus.off(owned[index], owned[index + 1], handle)
      owned[index + 1] = nil
      owned[index] = nil
    end
  end

  local ticking = handle._busTickers

  if ticking then
    for index = #ticking, 1, -1 do
      Bus.untick(ticking[index])
      ticking[index] = nil
    end
  end
end)
