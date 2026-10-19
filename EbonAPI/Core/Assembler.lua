EbonAPI = EbonAPI or {}
EbonAPI.Assembler = {}

local Assembler = EbonAPI.Assembler
local Bus = EbonAPI.Bus

local pairs, next, setmetatable = pairs, next, setmetatable
local concat = table.concat

local Streams = {}
Streams.__index = Streams

local function now()
  return (GetTime and GetTime()) or 0
end

function Assembler.new(tickId, timeout, sweep, maxParts, onExpire)
  local self = setmetatable({
    tickId = tickId,
    timeout = timeout,
    sweep = sweep,
    maxParts = maxParts,
    onExpire = onExpire,
    streams = {},
    live = 0,
  }, Streams)

  self.sweeper = function()
    self:purge(now())
  end

  return self
end

function Streams:drop(owner, id, byId)
  byId = byId or self.streams[owner]

  if byId and byId[id] then
    byId[id] = nil
    self.live = self.live - 1

    if next(byId) == nil then
      self.streams[owner] = nil
    end
  end

  if self.live == 0 then
    Bus.untick(self.tickId)
  end
end

function Streams:add(owner, id, index, total, slice, at)
  if not index or not total or total < 1 or total > self.maxParts or index < 1 or index > total then
    return nil, "bounds"
  end

  local byId = self.streams[owner]

  if not byId then
    byId = {}
    self.streams[owner] = byId
  end

  local record = byId[id]

  if not record or record.total ~= total then
    if not record then
      self.live = self.live + 1
    end

    record = { total = total, count = 0, parts = {}, at = at }
    byId[id] = record
    Bus.tick(self.tickId, self.sweep, self.sweeper)
  end

  record.at = at

  if record.parts[index] then
    return nil, "repeat"
  end

  record.parts[index] = slice
  record.count = record.count + 1

  if record.count < total then
    return nil, "progress"
  end

  self:drop(owner, id, byId)

  return concat(record.parts, "", 1, total), "done"
end

function Streams:purge(current)
  for owner, byId in pairs(self.streams) do
    for id, record in pairs(byId) do
      if current - record.at > self.timeout then
        self:drop(owner, id, byId)
        if self.onExpire then
          self.onExpire(owner, id, record)
        end
      end
    end
  end

  return self.live
end

function Streams:count()
  return self.live
end

function Streams:clear()
  for owner in pairs(self.streams) do
    self.streams[owner] = nil
  end

  self.live = 0
  Bus.untick(self.tickId)
end
