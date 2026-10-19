EbonAPI = EbonAPI or {}
EbonAPI.DB = {}

local DB = EbonAPI.DB
local Lib = EbonAPI.Lib
local Handle = EbonAPI.Handle

local type, pairs, ipairs, error = type, pairs, ipairs, error
local setmetatable, pcall = setmetatable, pcall

DB.repaired = 0

local DEFAULT_PARTS = { "account", "character" }

local root = nil
local characterKey = nil
local characterName = nil
local stores = {}

function DB.ResolveCharacter()
  if not UnitName then
    return nil
  end

  local name = UnitName("player")

  if not name or name == "" or name == UNKNOWNOBJECT then
    return nil
  end

  characterName = name
  characterKey = name .. "-" .. ((GetRealmName and GetRealmName()) or "")

  return characterKey
end

function DB.CharacterKey()
  return characterKey
end

function DB.CharacterName()
  return characterName
end

local declared = false

local function problems()
  local Problems = EbonAPI.Problems

  if not declared then
    declared = true

    Problems.declare("EbonAPI", "EBONAPI", {
      ["DB.REPAIRED"] = { class = "reparation", key = "path" },
      ["DB.MIGRATION_FAILED"] = { class = "bug", key = "migration" },
    })
  end

  return Problems
end

local function repaired(first, second, key, old, lost)
  DB.repaired = DB.repaired + 1

  local Problems = problems()

  key = tostring(key)

  if second then
    key = second .. "." .. key
  end

  if first then
    key = first .. "." .. key
  end

  Problems.repaired("EbonAPI", "DB.REPAIRED", { path = key, found = type(old), lost = lost }, old)
end

local function ensureTable(container, key, first, second)
  local found = container[key]

  if type(found) ~= "table" then
    if found ~= nil then
      repaired(first, second, key, found)
    end

    container[key] = {}
  end

  return container[key]
end

local function ensureBucket(container, key, parent)
  local bucket = ensureTable(container, key, nil, parent)

  ensureTable(bucket, "account", parent, key)
  ensureTable(bucket, "characters", parent, key)

  return bucket
end

local function shape(db)
  local addons = ensureTable(db, "addons")

  ensureBucket(db, "shared")
  ensureTable(db, "migrations")

  for name in pairs(addons) do
    ensureBucket(addons, name, "addons")
  end

  return db
end

function DB.attach(saved)
  if type(saved) ~= "table" then
    if saved ~= nil then
      repaired(nil, nil, "EbonAPIDB", saved, 1)
    end

    saved = {}
  end

  root = shape(saved)
  _G.EbonAPIDB = root

  for _, store in pairs(stores) do
    store:Rebind()
  end

  return root
end

function DB.root()
  if not root then
    DB.attach(_G.EbonAPIDB)
  end

  return root
end

function DB.isAttached()
  return root ~= nil
end

function DB.bindCharacter()
  if not DB.ResolveCharacter() then
    return false
  end

  for _, store in pairs(stores) do
    store:Rebind()
  end

  return true
end

local Store = {}
Store.__index = Store

local function bucketFor(owner)
  local db = DB.root()

  if owner == nil then
    return db.shared
  end

  return ensureBucket(db.addons, owner, "addons")
end

function Store:Rebind()
  local bucket = bucketFor(self.owner)
  local defaults = self.defaults

  self.bucket = bucket
  self.account = Lib.applyDefaults(bucket.account, defaults.account)

  if characterKey then
    local entry = ensureTable(bucket.characters, characterKey, self.owner or "shared", "characters")

    Lib.applyDefaults(entry, defaults.character)
    self.char = entry
  else
    self.char = nil
  end

  return self
end

function Store:CharacterKeys()
  return Lib.sortedKeys(self.bucket.characters)
end

function Store:CharacterAt(key)
  return self.bucket.characters[key]
end

function Store:ResetCharacter()
  if not characterKey then
    return false
  end

  local entry = ensureTable(self.bucket.characters, characterKey, self.owner or "shared", "characters")

  for key in pairs(entry) do
    entry[key] = nil
  end

  self:Rebind()

  return true
end

local function markerKey(owner, key, perCharacter)
  local base = (owner or "*shared*") .. "/" .. key

  if perCharacter then
    return base .. "@" .. (characterKey or "?")
  end

  return base
end

local function migrate(store, key, legacy, fn, perCharacter)
  if type(key) ~= "string" then
    error("EbonAPI: the migration key must be a string, got " .. type(key), 3)
  end

  if type(fn) ~= "function" then
    error("EbonAPI: migration '" .. key .. "' expects a function, got " .. type(fn), 3)
  end

  if perCharacter and not characterKey then
    return false
  end

  local migrations = DB.root().migrations
  local marker = markerKey(store.owner, key, perCharacter)

  if migrations[marker] then
    return false
  end

  local ok, result = pcall(fn, store, legacy, characterName, characterKey)

  if not ok then
    local Problems = problems()
    local problem = Problems.new("EbonAPI", "DB.MIGRATION_FAILED", {
      migration = key, owner = store.owner or "shared", error = result,
    })

    problem.where = Problems.where(problem.facts.error)
    Problems.report(problem)

    return false
  end

  if not result then
    return false
  end

  migrations[marker] = true

  return true, result
end

function Store:MigrateOnce(key, legacy, fn)
  return migrate(self, key, legacy, fn, false)
end

function Store:MigrateOncePerCharacter(key, legacy, fn)
  return migrate(self, key, legacy, fn, true)
end

function Store:IsMigrated(key, perCharacter)
  return DB.root().migrations[markerKey(self.owner, key, perCharacter)] == true
end

function DB.store(owner, defaults)
  if defaults ~= nil then
    if type(defaults) ~= "table" then
      error("EbonAPI: the defaults of '" .. (owner or "shared") .. "' must be a table, got "
        .. type(defaults), 3)
    end

    for _, part in ipairs(DEFAULT_PARTS) do
      if defaults[part] ~= nil and type(defaults[part]) ~= "table" then
        error("EbonAPI: the " .. part .. " defaults of '" .. (owner or "shared") .. "' must be a table, got "
          .. type(defaults[part]), 3)
      end
    end
  end

  local key = owner or "*shared*"
  local existing = stores[key]

  if existing then
    if defaults then
      Lib.applyDefaults(existing.defaults.account, defaults.account or {})
      Lib.applyDefaults(existing.defaults.character, defaults.character or {})
      existing:Rebind()
    end

    return existing
  end

  defaults = defaults or {}

  local store = setmetatable({
    owner = owner,
    defaults = {
      account = Lib.applyDefaults({}, defaults.account or {}),
      character = Lib.applyDefaults({}, defaults.character or {}),
    },
  }, Store)

  stores[key] = store
  store:Rebind()

  return store
end

function DB.shared()
  return DB.store(nil, nil)
end

function DB.dump()
  local db = DB.root()
  local lines = {
    "EbonAPIDB  character=" .. (characterKey or "not resolved"),
  }

  for _, name in ipairs(Lib.sortedKeys(db.addons)) do
    local bucket = db.addons[name]

    lines[#lines + 1] = "  " .. name
      .. "  account=" .. Lib.count(bucket.account) .. " keys"
      .. "  characters=" .. Lib.count(bucket.characters)
  end

  local markers = Lib.count(db.migrations)

  if markers > 0 then
    lines[#lines + 1] = "  migrations applied: " .. markers
  end

  if DB.repaired > 0 then
    lines[#lines + 1] = "  entries repaired at load: " .. DB.repaired
  end

  return table.concat(lines, "\n")
end

function Handle:DB(defaults)
  local store = self._store

  if not store then
    store = DB.store(self.addonName, defaults)
    self._store = store
  elseif defaults ~= nil then
    DB.store(self.addonName, defaults)
  end

  return store
end
