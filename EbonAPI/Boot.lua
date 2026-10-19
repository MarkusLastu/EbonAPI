EbonAPI = EbonAPI or {}

local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local DB = EbonAPI.DB
local Locale = EbonAPI.Locale
local Bridge = EbonAPI.Bridge
local Channel = EbonAPI.Channel
local Profile = EbonAPI.Profile
local Session = EbonAPI.Session
local Version = EbonAPI.Version
local Share = EbonAPI.Share
local Ebonhold = EbonAPI.Ebonhold
local State = EbonAPI.State
local Problems = EbonAPI.Problems
local Skins = EbonAPI.Skins
local Bricks = EbonAPI.Bricks
local Window = EbonAPI.Window

local ADDON_NAME = "EbonAPI"
local safeCall = Lib.safeCall

local onAddonLoaded, onPlayerLogin

onAddonLoaded = function(name)
  if name ~= ADDON_NAME then
    return
  end

  Bus.offCore("ADDON_LOADED", onAddonLoaded)

  DB.attach(EbonAPIDB)
  Problems.attach()

  Locale.applyPersisted()
  Skins.resolve()
  Bricks.apply()

  safeCall(State.enable)

  Log.trace("boot", ADDON_NAME, "database attached")
end

onPlayerLogin = function()
  Bus.offCore("PLAYER_LOGIN", onPlayerLogin)

  safeCall(EbonAPI.Catch.login)
  safeCall(DB.bindCharacter)
  safeCall(Session.begin)
  safeCall(Ebonhold.Detect)

  safeCall(Bridge.enable)

  safeCall(Channel.enable)
  safeCall(Profile.enable)
  safeCall(Version.enable)
  safeCall(Share.enable)
  safeCall(Window.install)

  EbonAPI._ready = true
  EbonAPI:Emit("READY", EbonAPI.version)

  Log.trace("boot", ADDON_NAME, DB.CharacterKey() or "character unknown")
end

local function onEnteringWorld()
  Ebonhold.Detect()

  if not DB.CharacterKey() then
    DB.bindCharacter()
  end
end

Bus.onCore("ADDON_LOADED", onAddonLoaded)
Bus.onCore("PLAYER_LOGIN", onPlayerLogin)
Bus.onCore("PLAYER_ENTERING_WORLD", onEnteringWorld)
