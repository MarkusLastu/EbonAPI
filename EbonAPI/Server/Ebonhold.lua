EbonAPI = EbonAPI or {}
EbonAPI.Ebonhold = {}

local Ebonhold = EbonAPI.Ebonhold
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Handle = EbonAPI.Handle
local L = EbonAPI.L

local Problems = EbonAPI.Problems

local type, tostring, pairs, pcall, concat, next = type, tostring, pairs, pcall, table.concat, next

Problems.declare("EbonAPI", "EBONAPI", {
  ["PE.MISSING"] = { class = "panne", key = "piece" },
  ["PE.CALL_FAILED"] = { class = "echec", key = "fn" },
  ["PE.HOOK_FAILED"] = { class = "panne", key = "hook" },
  ["PE.HOOK_REPLACED"] = { class = "panne", key = "hook" },
  ["SERVER.NO_SEND"] = { class = "echec", key = "reason" },
  ["PE.PERK_BUSY"] = { class = "refus" },
  ["PE.PERK_NO_OFFER"] = { class = "echec" },
  ["PE.PERK_NOT_OFFERED"] = { class = "echec", key = "spell" },
  ["PE.PERK_REFUSED"] = { class = "echec" },
  ["PE.PERK_BAD_ID"] = { class = "echec" },
  ["PE.CHECKPOINT_INVALID"] = { class = "echec", key = "checkpoint" },
  ["PE.SPEND_INVALID"] = { class = "echec", key = "spell" },
})

local lacks = {}
local stores = { ["PE.MISSING"] = {}, ["PE.HOOK_FAILED"] = {}, ["PE.HOOK_REPLACED"] = {} }
local failures = {}

local function consumers(piece)
  local names = {}
  local all = EbonAPI:AddonNames()

  for index = 1, #all do
    local list = Problems.requires(all[index])

    for position = 1, list and #list or 0 do
      if list[position] == piece then
        names[#names + 1] = all[index]
        break
      end
    end
  end

  if #names == 0 then
    return "EbonAPI"
  end

  return concat(names, ", ")
end

local function lack(piece)
  local problem = lacks[piece]

  if not problem then
    problem = Problems.new("EbonAPI", "PE.MISSING", { piece = piece, feature = consumers(piece) })
    lacks[piece] = problem
  end

  return problem
end

local function sync(code, wanted)
  local store = stores[code]
  local shrunk = false

  for id in pairs(store) do
    if not wanted[id] then
      store[id] = nil
      shrunk = true
    end
  end

  if shrunk then
    Problems.restore("EbonAPI", code)

    for id, old in pairs(store) do
      local problem = Problems.new("EbonAPI", code, old.facts)

      store[id] = problem
      Problems.degrade(problem)
    end
  end

  for id, facts in pairs(wanted) do
    if not store[id] then
      local problem = Problems.new("EbonAPI", code, facts)

      store[id] = problem
      Problems.degrade(problem)
    end
  end
end

local function root()
  local pe = _G.ProjectEbonhold

  if type(pe) == "table" then
    return pe
  end

  return nil, lack("ProjectEbonhold")
end

local function service(name)
  local pe, problem = root()

  if not pe then
    return nil, problem
  end

  local entry = pe[name]

  if type(entry) == "table" then
    return entry
  end

  return nil, lack(name)
end

local function frame(name)
  local value = _G[name]

  if type(value) == "table" then
    return value
  end

  return nil, lack(name)
end

local function call(name, fn, ...)
  local ok, err = pcall(fn, ...)

  if ok then
    return true
  end

  return false, Problems.report(Problems.new("EbonAPI", "PE.CALL_FAILED", { fn = name, text = err }))
end

local function use(piece, present)
  if present then
    if stores["PE.MISSING"][piece] then
      Ebonhold.Detect()
    end

    return nil
  end

  Ebonhold.Detect()

  return lack(piece)
end

function Ebonhold.IsPresent()
  return root() ~= nil
end

function Ebonhold.Raw()
  return root()
end

function Ebonhold.Objectives()
  return service("ObjectivesService")
end

function Ebonhold.ObjectivesUI()
  return service("ObjectivesUI")
end

function Ebonhold.Checkpoints()
  return service("CheckpointService")
end

function Ebonhold.Hardmode()
  return service("HardmodeService")
end

function Ebonhold.Perks()
  return service("PerkService")
end

function Ebonhold.PerkDatabase()
  return service("PerkDatabase")
end

function Ebonhold.PlayerRun()
  return service("PlayerRunService")
end

function Ebonhold.SkillTree()
  return service("SkillTree")
end

function Ebonhold.WorldMapBounds()
  return service("WorldMapBounds")
end

function Ebonhold.Orbs()
  return service("OrbService")
end

function Ebonhold.PerkUI()
  return service("PerkUI")
end

function Ebonhold.EchoJournal()
  return service("EchoJournal")
end

function Ebonhold.PerkDropSources()
  return service("PerkDropSources")
end

function Ebonhold.PerkDropSourceByGroup()
  return service("PerkDropSourceByGroup")
end

function Ebonhold.OptionsService()
  local svc = _G.ProjectEbonholdOptionsService

  if type(svc) == "table" then
    return svc
  end

  return nil, lack("ProjectEbonholdOptionsService")
end

function Ebonhold.PerkFrame()
  return frame("ProjectEbonholdPerkFrame")
end

function Ebonhold.SkillTreeImportButton()
  return frame("skillTreeImportButton")
end

function Ebonhold.CanRequestLoadout()
  local pe = root()

  return pe ~= nil and type(pe.RequestLoadoutFromServer) == "function"
end

function Ebonhold.RequestLoadout()
  local pe, problem = root()

  if not pe then
    return false, problem
  end

  local fn = pe.RequestLoadoutFromServer
  local missing = use("RequestLoadout", type(fn) == "function")

  if missing then
    return false, missing
  end

  return call("RequestLoadoutFromServer", fn)
end

local function refuse(code, facts)
  return false, Problems.report(Problems.new("EbonAPI", code, facts))
end

local function entry(owner, name, piece)
  local table_, problem = service(owner)

  if not table_ then
    return nil, problem
  end

  local fn = table_[name]
  local missing = use(piece, type(fn) == "function")

  if missing then
    return nil, missing
  end

  return table_, nil, fn
end

local function selectCause(spellId)
  local ok, code = pcall(function()
    local perks = _G.ProjectEbonhold.Perks

    if perks.pendingSelectSpellId then
      return "PE.PERK_BUSY"
    end

    local choices = perks.currentChoice

    if type(choices) ~= "table" or #choices == 0 then
      return "PE.PERK_NO_OFFER"
    end

    for index = 1, #choices do
      local choice = choices[index]

      if type(choice) == "table" and choice.spellId == spellId then
        return nil
      end
    end

    return "PE.PERK_NOT_OFFERED"
  end)

  if ok and code then
    return code
  end

  return "PE.PERK_REFUSED"
end

function Ebonhold.SelectPerk(spellId)
  if type(spellId) ~= "number" or spellId <= 0 then
    return refuse("PE.PERK_BAD_ID")
  end

  local perks, problem, fn = entry("PerkService", "SelectPerk", "SelectPerk")

  if not perks then
    return false, problem
  end

  local ok, result = pcall(fn, spellId)

  if not ok then
    return false, Problems.report(Problems.new("EbonAPI", "PE.CALL_FAILED", { fn = "SelectPerk", text = result }))
  end

  if result == true then
    return true
  end

  return refuse(selectCause(spellId), { spell = tostring(spellId) })
end

function Ebonhold.UseCheckpoint(checkpointId)
  if type(checkpointId) ~= "number" or checkpointId <= 0 then
    return refuse("PE.CHECKPOINT_INVALID", { checkpoint = tostring(checkpointId) })
  end

  local checkpoints, problem, fn = entry("CheckpointService", "UseCheckpoint", "UseCheckpoint")

  if not checkpoints then
    return false, problem
  end

  return call("UseCheckpoint", fn, checkpointId)
end

function Ebonhold.ConfirmSpend(spellId, orbs)
  if type(spellId) ~= "number" or spellId <= 0 or type(orbs) ~= "number" or orbs < 1 or orbs % 1 ~= 0 then
    return refuse("PE.SPEND_INVALID", { spell = tostring(spellId), orbs = tostring(orbs) })
  end

  local orbService, problem, fn = entry("OrbService", "ConfirmSpend", "ConfirmSpend")

  if not orbService then
    return false, problem
  end

  return call("ConfirmSpend", fn, spellId, orbs)
end

function Ebonhold.CurrentHardmodeTier()
  local pe = root()

  if not pe then
    return nil
  end

  return pe.currentHardmodeTier
end

function Ebonhold.SkillTreeFrame()
  return frame("skillTreeFrame")
end

function Ebonhold.TalentDatabase()
  local db = _G.TalentDatabase

  if type(db) == "table" and type(db[0]) == "table" and type(db[0].nodes) == "table" then
    return db
  end

  return nil, lack("TalentDatabase")
end

function Ebonhold.Utils()
  local utils = _G.utils

  if type(utils) == "table" and utils.EncodeVarInt and utils.Base64Encode then
    return utils
  end

  return nil, lack("utils")
end

function Ebonhold.PublishedRunData()
  local published = _G.EbonholdPlayerRunData

  if type(published) == "table" and next(published) ~= nil then
    return published
  end

  return nil
end

function Ebonhold.PublishedIntensity()
  local published = _G.EbonholdIntensityData

  if type(published) == "table" then
    return published
  end

  return nil
end

function Ebonhold.OpcodeCS(name)
  local pe = root()

  if not pe or type(pe.CS) ~= "table" then
    return nil
  end

  return pe.CS[name]
end

function Ebonhold.SendToServer(opcodeName, body)
  local pe, problem = root()

  if not pe then
    return false, problem
  end

  local send = pe.sendToServer
  local missing = use("sendToServer", type(send) == "function")

  if missing then
    return false, Problems.report(Problems.new("EbonAPI", "SERVER.NO_SEND",
      { opcode = opcodeName, reason = "ProjectEbonhold has no sendToServer function" }, missing))
  end

  local opcode = Ebonhold.OpcodeCS(opcodeName)

  if opcode == nil then
    return false, Problems.report(Problems.new("EbonAPI", "SERVER.NO_SEND",
      { opcode = opcodeName, reason = "ProjectEbonhold has no opcode of that name" }))
  end

  local ok, failed = call("sendToServer", send, opcode, body)

  if not ok then
    return false, failed
  end

  Log.trace("send", "EbonAPI", "PE:" .. tostring(opcodeName))

  return true
end

local hooked = {}

local function resolve(path)
  if path == nil then
    return (root())
  elseif type(path) == "string" then
    return (service(path))
  end

  return path
end

local REASONS = {
  no_target = "the function to hook does not exist",
  no_wrapper = "no wrapper function was given",
  already_hooked = "already hooked",
}

local function refuse(marker, path, key, reason)
  local facts = { path = tostring(path), key = tostring(key), reason = REASONS[reason], hook = marker }

  if reason == "already_hooked" then
    return false, Problems.new("EbonAPI", "PE.HOOK_FAILED", facts)
  end

  failures[marker] = facts
  sync("PE.HOOK_FAILED", failures)

  return false, stores["PE.HOOK_FAILED"][marker]
end

function Ebonhold.Hook(path, key, wrapper)
  local shown = path == nil and "ProjectEbonhold" or path
  local marker = tostring(shown) .. "." .. tostring(key)
  local target = resolve(path)

  if type(target) ~= "table" or type(target[key]) ~= "function" then
    return refuse(marker, shown, key, "no_target")
  end

  if type(wrapper) ~= "function" then
    return refuse(marker, shown, key, "no_wrapper")
  end

  if hooked[marker] then
    return refuse(marker, shown, key, "already_hooked")
  end

  local original = target[key]
  local entry = { path = path, shown = tostring(shown), key = tostring(key), name = key }

  entry.fn = function(...)
    return wrapper(original, ...)
  end

  target[key] = entry.fn
  hooked[marker] = entry

  if failures[marker] then
    failures[marker] = nil
    sync("PE.HOOK_FAILED", failures)
  end

  return true
end

function Ebonhold.VerifyHooks()
  local wanted = {}

  for marker, entry in pairs(hooked) do
    local target = resolve(entry.path)

    if type(target) == "table" and target[entry.name] ~= entry.fn then
      wanted[marker] = { path = entry.shown, key = entry.key, hook = marker }
    end
  end

  sync("PE.HOOK_REPLACED", wanted)
end

function Ebonhold.IsHooked(path, key)
  if path == nil then
    path = "ProjectEbonhold"
  end

  Ebonhold.VerifyHooks()

  return hooked[tostring(path) .. "." .. tostring(key)] ~= nil
end

function Ebonhold.LinkMethod()
  if type(_G.EbonholdOpenURL) == "function" then
    return "open"
  end

  if type(_G.CopyToClipboard) == "function" then
    return "copy"
  end

  return nil
end

function Ebonhold.OpenLink(url)
  local method = Ebonhold.LinkMethod()

  if not method then
    return nil
  end

  if not Lib.safeCall(method == "open" and _G.EbonholdOpenURL or _G.CopyToClipboard, url) then
    return nil
  end

  return method
end

function Ebonhold.LinkTip()
  local method = Ebonhold.LinkMethod()

  if method == "open" then
    return L.LINK_TIP_OPEN
  elseif method == "copy" then
    return L.LINK_TIP_COPY
  end

  return nil
end

local function badUrl(url)
  if url == "" then
    return "an empty string"
  end

  if type(url) ~= "string" then
    return type(url)
  end

  return nil
end

function EbonAPI:OpenLink(url)
  local bad = badUrl(url)

  if bad then
    error("EbonAPI:OpenLink expects a URL text, got " .. bad, 2)
  end

  return Ebonhold.OpenLink(url)
end

function EbonAPI:LinkMethod()
  return Ebonhold.LinkMethod()
end

function EbonAPI:LinkTip()
  return Ebonhold.LinkTip()
end

function Handle:OpenLink(url)
  local bad = badUrl(url)

  if bad then
    error("EbonAPI: " .. self.addonName .. ": api:OpenLink expects a URL text, got " .. bad, 2)
  end

  return Ebonhold.OpenLink(url)
end

function Handle:LinkMethod()
  return Ebonhold.LinkMethod()
end

function Handle:LinkTip()
  return Ebonhold.LinkTip()
end

local PROBES = {
  { "ProjectEbonhold", Ebonhold.IsPresent },
  { "Objectives", Ebonhold.Objectives },
  { "Checkpoints", Ebonhold.Checkpoints },
  { "Hardmode", Ebonhold.Hardmode },
  { "Perks", Ebonhold.Perks },
  { "PerkDatabase", Ebonhold.PerkDatabase },
  { "PerkUI", Ebonhold.PerkUI },
  { "Orbs", Ebonhold.Orbs },
  { "EchoJournal", Ebonhold.EchoJournal },
  { "PlayerRun", Ebonhold.PlayerRun },
  { "SkillTree", Ebonhold.SkillTree },
  { "SkillTreeFrame", Ebonhold.SkillTreeFrame },
  { "TalentDatabase", Ebonhold.TalentDatabase },
  { "Utils", Ebonhold.Utils },
  { "RequestLoadout", Ebonhold.CanRequestLoadout },
}

function Ebonhold.Check()
  local wanted = {}
  local users = {}
  local needs = {}
  local names = EbonAPI:AddonNames()

  for index = 1, #names do
    local list = Problems.requires(names[index])

    if list then
      users[#users + 1] = names[index]

      for position = 1, #list do
        local piece = list[position]

        if not EbonAPI:HasFeature(piece) then
          local who = needs[piece]

          if not who then
            who = {}
            needs[piece] = who
          end

          who[#who + 1] = names[index]
        end
      end
    end
  end

  if next(needs) then
    if root() then
      for piece, who in pairs(needs) do
        wanted[piece] = { piece = piece, feature = concat(who, ", ") }
      end
    else
      wanted.ProjectEbonhold = { piece = "ProjectEbonhold", feature = concat(users, ", ") }
    end
  end

  sync("PE.MISSING", wanted)
  Ebonhold.VerifyHooks()
end

function Ebonhold.Detect()
  for index = 1, #PROBES do
    local probe = PROBES[index]

    EbonAPI:RegisterFeature(probe[1], Lib.safeGet(probe[2]) and true or false)
  end

  local pe = root()

  EbonAPI:RegisterFeature("sendToServer", pe ~= nil and type(pe.sendToServer) == "function")
  EbonAPI:RegisterFeature("openLink", Ebonhold.LinkMethod() ~= nil)
  Ebonhold.Check()

  return EbonAPI:Features()
end

EbonAPI:On("READY", Ebonhold.Check)

function Ebonhold.Summary()
  local features = EbonAPI:Features()
  local present = {}
  local missing = {}

  for _, name in pairs(Lib.sortedKeys(features)) do
    if features[name] then
      present[#present + 1] = name
    else
      missing[#missing + 1] = name
    end
  end

  return present, missing
end

function Handle:Ebonhold()
  return Ebonhold
end
