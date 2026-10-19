EbonAPI = EbonAPI or {}
EbonAPI.Legacy = {}

local Legacy = EbonAPI.Legacy
local Log = EbonAPI.Log
local Channel = EbonAPI.Channel
local Version = EbonAPI.Version
local Share = EbonAPI.Share

-- Compatibility with the 2.1.x clients, which announce themselves with a parts line (op F) and a
-- versions line (op V) instead of the beacon (op B). Retire this module, and the EA2 grouping
-- switch in Channel.lua, when the client moves to the PTR.
local NAME = "EbonAPI"
local LINE_OP = "F"
local VERSION_OP = "V"

local enabled = false
local discovered = false

local function onPartsLine(sender, body)
  local level = Share.lineLevel(body)

  if level < Share.LEVEL then
    Share.hear(sender, Share.lineDigest(body), level)
  end
end

local function onVersionLine(sender, body)
  Version.onBeacon(sender, body)
end

-- Called by every announcement of Share: the first one of a session finds out who is old, then
-- the old formats go out for as long as an old peer is around.
function Legacy.announce()
  if not enabled or discovered and not Share.legacyPeerHeard() then
    return false
  end

  if not Channel.say(NAME, LINE_OP, Share.line(Channel.bodyMax(NAME, LINE_OP))) then
    return false
  end

  discovered = true

  local versions = Version.line()

  if versions then
    Channel.say(NAME, VERSION_OP, versions)
  end

  Log.trace("share", nil, LINE_OP)

  return true
end

function Legacy.enable()
  if enabled then
    return false
  end

  enabled = true
  discovered = false

  Channel.on(NAME, LINE_OP, onPartsLine)
  Channel.on(NAME, VERSION_OP, onVersionLine)

  return true
end

function Legacy.disable()
  if not enabled then
    return false
  end

  enabled = false

  Channel.off(NAME, LINE_OP, onPartsLine)
  Channel.off(NAME, VERSION_OP, onVersionLine)

  return true
end
