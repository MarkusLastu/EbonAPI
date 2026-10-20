EbonAPI = EbonAPI or {}
EbonAPI.Problems = {}

local Problems = EbonAPI.Problems
local DB = EbonAPI.DB
local Log = EbonAPI.Log
local Handle = EbonAPI.Handle

local type, pairs, tostring, error, pcall, xpcall = type, pairs, tostring, error, pcall, xpcall
local select, unpack, sort = select, unpack, table.sort
local ipairs, next, tonumber = ipairs, next, tonumber
local concat = table.concat
local sub, gsub, match, upper = string.sub, string.gsub, string.match, string.upper
local char, floor = string.char, math.floor

local SEP = "\031"
local MAX_ENTRIES = 200
local MAX_PENDING = 50
local MAX_QUARANTINE = 50
local MAX_REJECTS = 100
local MAX_RECENT = 10
local MAX_DEPTH = 5
local FACT_LIMIT = 200
local EXAMPLE_LIMIT = 60

local CLASSES = {
  refus = true, echec = true, partiel = true, panne = true, bug = true, rejet = true, reparation = true,
}
local ENTRY_CLASSES = { echec = true, partiel = true, panne = true, bug = true, reparation = true }
local NEIGHBOR_CLASSES = { bug = true, echec = true, partiel = true, panne = true }
local RANK = { refus = 2, echec = 2, partiel = 3, bug = 4, reparation = 5 }

local LUA_ERROR = "EBONAPI.LUA.ERROR"

local catalogs = {}
local prefixes = {}
local defs = {}
local requirements = {}
local active = {}
local pending = {}
local pendingCount = 0
local lost = 0
local early = {}
local earlyCount = 0
local MAX_EARLY = 3
local store = nil
local versions = {}
local choices = {}
local missing = {}
local PIECES = { alert = true, line = true, center = true, badge = true }

Problems.internal = nil
Problems.internalCount = 0

local function internalError(err)
  Problems.internal = err
  Problems.internalCount = Problems.internalCount + 1
  Log.trace("problem_internal", "EbonAPI", tostring(err))
end

local function newJournal()
  return {
    v = 1, entries = {}, size = 0, evicted = 0,
    refusals = {}, rejects = {}, nrejects = 0, foreign = {}, quarantine = {}, qn = 0,
  }
end

local function ensure(journal)
  journal.v = journal.v or 1
  journal.entries = journal.entries or {}
  journal.evicted = journal.evicted or 0
  journal.refusals = journal.refusals or {}
  journal.rejects = journal.rejects or {}
  journal.foreign = journal.foreign or {}
  journal.quarantine = journal.quarantine or {}
  journal.qn = journal.qn or 0

  if type(journal.nrejects) ~= "number" then
    local count = 0

    for _ in pairs(journal.rejects) do
      count = count + 1
    end

    journal.nrejects = count
  end

  if type(journal.size) ~= "number" then
    local size = 0

    for _ in pairs(journal.entries) do
      size = size + 1
    end

    journal.size = size
  end

  return journal
end

local function current()
  if not store then
    return nil
  end

  local account = store.account
  local journal = account.journal

  if type(journal) ~= "table" then
    journal = newJournal()
    account.journal = journal
  end

  return journal
end

local function submit(op, a, b, c)
  local journal = current()

  if journal then
    return op(journal, a, b, c)
  end

  if pendingCount >= MAX_PENDING then
    lost = lost + 1
    return
  end

  local base = pendingCount * 4
  pendingCount = pendingCount + 1
  pending[base + 1], pending[base + 2], pending[base + 3], pending[base + 4] = op, a, b, c
end

local function versionOf(addon)
  local version = versions[addon]

  if version == nil then
    -- A module has no version of its own: it is EbonAPI's.
    local Modules = EbonAPI.ModuleLoader

    if Modules and Modules.owns(addon) then
      version = EbonAPI.version
    else
      version = (GetAddOnMetadata and GetAddOnMetadata(addon, "Version")) or false
    end
    versions[addon] = version
  end

  return version or nil
end

local function sanitize(facts, limit)
  local out = {}

  if type(facts) == "table" then
    for key, value in pairs(facts) do
      local kind = type(value)

      if kind ~= "number" and kind ~= "boolean" then
        if kind ~= "string" then
          value = tostring(value)
        end

        if #value > limit then
          value = sub(value, 1, limit)
        end
      end

      out[key] = value
    end
  end

  return out
end

function Problems.where(message)
  local file, line = match(tostring(message), "^(.-):(%d+):")

  if not file then
    return nil
  end

  return (match(file, "[Aa]dd[Oo]ns\\[^\\]+\\(.*)$") or file) .. ":" .. line
end

local function prune(journal, keep)
  local entries = journal.entries
  local victim, victimRank, victimLast

  for key, entry in pairs(entries) do
    if key ~= keep then
      local rank

      if entry.class == "panne" then
        rank = (entry.open and active[key]) and 6 or 1
      else
        rank = RANK[entry.class] or 5
      end

      local last = entry.last or 0

      if not victimRank or rank < victimRank or (rank == victimRank and last < victimLast) then
        victim, victimRank, victimLast = key, rank, last
      end
    end
  end

  if victim then
    entries[victim] = nil
    active[victim] = nil
    journal.size = journal.size - 1
    journal.evicted = journal.evicted + 1
  end
end

local function opEntry(journal, problem)
  local key = problem.addon .. SEP .. problem.code .. SEP .. (problem.key or "")
  local entries = journal.entries
  local entry = entries[key]
  local fresh = entry == nil
  local at = problem.at

  if fresh then
    entry = {
      code = problem.code, class = problem.class, addon = problem.addon, key = problem.key,
      realm = GetRealmName and GetRealmName() or nil, first = at, count = 0, versions = {},
    }
    entries[key] = entry
    journal.size = journal.size + 1
  end

  entry.count = entry.count + 1
  entry.last = at
  entry.class = problem.class
  entry.facts = problem.facts
  entry.guarded = problem.guarded
  entry.where = problem.where
  entry.stack = problem.stack
  entry.neighbors = problem.neighbors
  entry.versions.addon = versionOf(problem.addon)
  entry.versions.ebonapi = EbonAPI.version

  local cause = problem.cause

  if cause then
    local kept = entry.cause

    if not kept then
      kept = {}
      entry.cause = kept
    end

    kept.code, kept.facts = cause.code, cause.facts
  else
    entry.cause = nil
  end

  if problem.open then
    entry.open = true
    entry.closed = nil
  end

  if problem.open or problem.class == "bug" or problem.class == "reparation" then
    active[key] = entry
  end

  if problem.class == "reparation" and problem.old ~= nil then
    local index = journal.qn % MAX_QUARANTINE + 1

    journal.qn = journal.qn + 1
    journal.quarantine[index] = {
      at = at, addon = problem.addon, code = problem.code,
      path = problem.facts and problem.facts.path, old = problem.old,
    }
  end

  if fresh and journal.size > MAX_ENTRIES then
    prune(journal, key)
  end
end

local function opRefusal(journal, problem)
  local key = problem.addon .. SEP .. problem.code
  local item = journal.refusals[key]

  if not item then
    item = { n = 0 }
    journal.refusals[key] = item
  end

  item.n = item.n + 1
  item.last = problem.at

  local ring = item.recent

  if not ring then
    ring = {}
    item.recent, item.rn = ring, 0
  end

  local slot = item.rn % MAX_RECENT + 1

  item.rn = item.rn + 1
  ring[slot] = { at = problem.at, facts = problem.facts }
end

local function opAlertLost(journal)
  journal.alertsLost = (journal.alertsLost or 0) + 1
end

local function opReject(journal, problem)
  local reason = problem.facts and problem.facts.reason
  local key = problem.addon .. SEP .. problem.code .. SEP .. (reason ~= nil and tostring(reason) or "")
  local rejects = journal.rejects
  local item = rejects[key]

  if not item then
    if journal.nrejects >= MAX_REJECTS then
      key = problem.addon .. SEP .. problem.code .. SEP .. "other"
      item = rejects[key]
    end

    if not item then
      item = { n = 0 }
      rejects[key] = item
      journal.nrejects = journal.nrejects + 1
    end
  end

  item.n = item.n + 1
  item.last = problem.at
  item.example = problem.facts
end

local function opForeign(journal, name, message, at)
  local item = journal.foreign[name]

  if not item then
    item = { n = 0 }
    journal.foreign[name] = item
  end

  item.n = item.n + 1
  item.last = at
  item.message = message
end

function Problems.foreign(name, message, at)
  submit(opForeign, name, message, at or time())
end

local function opRestore(journal, addon, code)
  local closed = false

  for key, entry in pairs(active) do
    if entry.addon == addon and entry.code == code and entry.open then
      entry.open = false
      entry.closed = time()
      active[key] = nil
      closed = true
    end
  end

  return closed
end

function Problems.attach()
  if store or not DB.isAttached() then
    return store ~= nil
  end

  store = DB.store("EbonAPI", { account = { journal = {} } })

  local journal = ensure(current())

  for _, entry in pairs(journal.entries) do
    if entry.open then
      entry.open = false
      entry.closed = time()
      entry.facts = entry.facts or {}
      entry.facts.stale = true
    end
  end

  if lost > 0 then
    journal.lost = (journal.lost or 0) + lost
    lost = 0
  end

  local count = pendingCount

  pendingCount = 0

  for i = 0, count - 1 do
    local base = i * 4
    local ok, err = pcall(pending[base + 1], journal, pending[base + 2], pending[base + 3], pending[base + 4])

    if not ok then
      internalError(err)
    end

    pending[base + 1], pending[base + 2], pending[base + 3], pending[base + 4] = nil, nil, nil, nil
  end

  return true
end

function Problems.journal()
  return current()
end

function Problems.networkShown()
  return store ~= nil and store.account.showNetwork == true
end

function Problems.setNetworkShown(value)
  if not store then
    return false
  end

  store.account.showNetwork = value and true or nil

  return true
end

function Problems.clear()
  local journal = current()
  local closed = {}

  if journal then
    store.account.journal = newJournal()
  end

  for key, entry in pairs(active) do
    closed[entry.addon .. SEP .. entry.code] = entry
    active[key] = nil
  end

  for _, entry in pairs(closed) do
    EbonAPI:Emit("PROBLEM_CLOSED", entry.addon, entry.code)
  end
end

function Problems.option(addon, piece)
  local set = choices[addon]

  return not (set and set[piece] == false)
end

function Problems.addonOf(key)
  return match(tostring(key), "^(.-)" .. SEP)
end

local function suffix(n)
  local text = ""

  while n > 0 do
    local rest = (n - 1) % 26

    text = char(65 + rest) .. text
    n = floor((n - 1) / 26)
  end

  return text
end

function Problems.declare(addon, prefix, catalogue, level, options)
  level = level or 2

  if type(prefix) ~= "string" or not match(prefix, "^[A-Z]+$") then
    error("EbonAPI: " .. tostring(addon) .. ": the problem prefix must be uppercase ASCII letters, got "
      .. tostring(prefix), level)
  end

  if type(catalogue) ~= "table" then
    error("EbonAPI: " .. tostring(addon) .. ": the problem catalogue must be a table, got " .. type(catalogue),
      level)
  end

  if options ~= nil then
    if type(options) ~= "table" then
      error("EbonAPI: " .. tostring(addon) .. ": the problem options must be a table, got " .. type(options), level)
    end

    for key, value in pairs(options) do
      if not PIECES[key] or type(value) ~= "boolean" then
        error("EbonAPI: " .. tostring(addon) .. ': the problem option "' .. tostring(key)
          .. '" is unknown or not a boolean', level)
      end
    end
  end

  local list = catalogs[addon]
  local given = prefix

  if list then
    if list.wanted ~= prefix then
      error("EbonAPI: " .. tostring(addon) .. ' already declares the problem prefix "' .. tostring(list.wanted) .. '"',
        level)
    end

    given = list.prefix
  elseif prefixes[prefix] and prefixes[prefix] ~= addon then
    local n = 0

    repeat
      n = n + 1
      given = prefix .. suffix(n)
    until not prefixes[given]
  end

  for name, spec in pairs(catalogue) do
    if type(spec) ~= "table" or not CLASSES[spec.class] then
      error("EbonAPI: " .. tostring(addon) .. ': problem "' .. tostring(name) .. '" has an unknown class "'
        .. tostring(type(spec) == "table" and spec.class or spec) .. '"', level)
    end
  end

  if options then
    for key, value in pairs(options) do
      if value then
        if choices[addon] then
          choices[addon][key] = nil

          if next(choices[addon]) == nil then
            choices[addon] = nil
          end
        end
      else
        choices[addon] = choices[addon] or {}
        choices[addon][key] = false
      end
    end
  end

  if not list then
    list = { prefix = given, wanted = prefix, names = {} }
    catalogs[addon] = list

    if given ~= prefix then
      Log.trace("prefix_taken", nil, addon, prefix .. " -> " .. given)
    end
  end

  prefixes[given] = addon

  for name, spec in pairs(catalogue) do
    local def = {
      addon = addon, name = name, code = given .. "." .. name, class = spec.class, key = spec.key,
      entry = spec.entry and true or nil, quiet = spec.quiet and true or nil, silent = spec.silent and true or nil,
      textKey = "PROBLEM_" .. gsub(name, "%.", "_"),
    }

    list.names[name] = def
    defs[def.code] = def
  end
end

local function make(addon, name, facts, cause, limit, level)
  local def = name

  if type(name) ~= "table" then
    local list = catalogs[addon]

    def = list and list.names[name]

    if not def then
      error('EbonAPI: ' .. tostring(addon) .. ': unknown problem code "' .. tostring(name) .. '"', level or 2)
    end
  end

  if type(cause) == "string" then
    cause = { code = LUA_ERROR, addon = "EbonAPI", facts = { message = sub(cause, 1, FACT_LIMIT) } }
  end

  facts = sanitize(facts, limit or FACT_LIMIT)

  local key = def.key and facts[def.key]

  return {
    code = def.code, addon = addon, class = def.class, facts = facts,
    key = key ~= nil and tostring(key) or nil, cause = cause, at = time(),
  }
end

function Problems.make(addon, code, facts, cause)
  return make(addon, defs[code] or code, facts, cause, nil, 2)
end

function Problems.new(addon, name, facts, cause, level)
  return make(addon, name, facts, cause, nil, level or 2)
end

local cur, depth = nil, 0
local render

local function fill(name)
  if name == "cause" then
    local cause = cur.cause

    if not cause or depth >= MAX_DEPTH then
      return ""
    end

    local savedCur, savedDepth = cur, depth
    local text = render(cause, depth + 1)

    cur, depth = savedCur, savedDepth

    return text
  end

  local value = cur.facts and cur.facts[name]

  if value == nil and name == "addon" then
    value = cur.addon
  end

  if value == nil then
    return "?"
  end

  return tostring(value)
end

local function plain(problem)
  local facts = problem.facts
  local keys = {}

  if facts then
    for key in pairs(facts) do
      keys[#keys + 1] = tostring(key)
    end

    sort(keys)

    for i = 1, #keys do
      keys[i] = keys[i] .. "=" .. tostring(facts[keys[i]])
    end
  end

  if #keys == 0 then
    return tostring(problem.code)
  end

  return tostring(problem.code) .. " " .. concat(keys, " ")
end

render = function(problem, level)
  local def = defs[problem.code]
  local Locale = EbonAPI.Locale
  local strings = def and Locale and Locale.get(def.addon)
  local template = strings and strings[def.textKey]

  if type(template) ~= "string" then
    local owner = def and def.addon or problem.addon
    local id = tostring(owner) .. SEP .. tostring(problem.code)

    if not missing[id] and Log.isDebug(owner) then
      missing[id] = true
      Log.trace("problem_text_missing", nil, owner, problem.code)
    end

    return plain(problem)
  end

  cur, depth = problem, level

  return (gsub(template, "{([%w_]+)}", fill))
end

function Problems.text(problem)
  local savedCur, savedDepth = cur, depth
  local ok, text = pcall(render, problem, 1)

  cur, depth = savedCur, savedDepth

  if ok then
    return (gsub(text, "^%l", upper))
  end

  internalError(text)

  return plain(problem)
end

function Problems.route(problem)
  local class = problem.class

  if class == "refus" then
    return "line"
  elseif class == "echec" or class == "partiel" or class == "panne" then
    return "block"
  elseif class == "bug" then
    return problem.guarded and "block" or "quiet"
  elseif class == "reparation" then
    local lost = tonumber(problem.facts and problem.facts.lost)

    return lost and lost > 0 and "block" or nil
  end

  return nil
end

function Problems.earlyCount()
  return earlyCount
end

function Problems.flushEarly()
  local Alerts = EbonAPI.Alerts
  local count = earlyCount

  earlyCount = 0

  for i = 1, count do
    local item = early[i]

    early[i] = nil
    Alerts.show(item[1], item[2])
  end
end

function Problems.show(problem)
  local def = defs[problem.code]

  if def and (def.silent or (def.quiet and not Problems.networkShown())) then
    return
  end

  local route = Problems.route(problem)

  if route == "line" then
    if UIErrorsFrame and Problems.option(problem.addon, "line") then
      UIErrorsFrame:AddMessage(Problems.text(problem), 1.0, 0.1, 0.1)
    end
  elseif route and Problems.option(problem.addon, "alert") then
    local Alerts = EbonAPI.Alerts

    if Alerts and Alerts.ready() then
      Alerts.show(problem, route)
    elseif earlyCount < MAX_EARLY then
      earlyCount = earlyCount + 1
      early[earlyCount] = { problem, route }
    else
      submit(opAlertLost)
    end
  end
end

function Problems.entry(problem)
  local journal = current()
  local entry = journal and journal.entries[Problems.keyOf(problem)]

  return entry or problem
end

function Problems.keyOf(problem)
  return problem.addon .. SEP .. problem.code .. SEP .. (problem.key or "")
end

function Problems.open(addon, key)
  Problems.opened = { addon = addon, key = key }
  EbonAPI:Emit("PROBLEM_OPEN", addon, key)
end

local function sortedFacts(facts)
  local keys = {}

  for key in pairs(facts or {}) do
    keys[#keys + 1] = tostring(key)
  end

  sort(keys)

  return keys
end

function Problems.copyText(entry)
  local out = {}
  local n = 0
  local stamp = "%Y-%m-%d %H:%M:%S"

  local function add(text)
    n = n + 1
    out[n] = text
  end

  local function lines(title, facts, indent)
    for _, key in ipairs(sortedFacts(facts)) do
      add(indent .. title .. key .. " = " .. tostring(facts[key]))
    end
  end

  local addon = tostring(entry.addon)
  local versions = entry.versions or {}
  local first = entry.first or entry.at
  local last = entry.last or entry.at

  add("EbonAPI " .. tostring(versions.ebonapi or EbonAPI.version) .. " | " .. tostring(entry.realm or (GetRealmName and GetRealmName()) or "?") .. " | " .. date(stamp, time()))
  add("Addon: " .. addon .. " " .. tostring(versions.addon or versionOf(entry.addon) or "?"))
  add("Code: " .. tostring(entry.code) .. " (" .. tostring(entry.class) .. ")")
  add("Count: " .. tostring(entry.count or 1) .. " | first: " .. (first and date(stamp, first) or "?") .. " | last: " .. (last and date(stamp, last) or "?"))

  if entry.facts and next(entry.facts) then
    add("Facts:")
    lines("", entry.facts, "  ")
  end

  local cause = entry.cause

  if cause then
    add("Cause: " .. Problems.text(cause) .. " (" .. tostring(cause.code) .. ")")
    lines("", cause.facts, "  ")
  end

  if entry.where then
    add("Where: " .. tostring(entry.where))
  end

  if entry.class == "bug" and entry.stack and entry.stack ~= "" then
    add("Stack:")
    add(tostring(entry.stack))
  end

  if entry.neighbors and #entry.neighbors > 0 then
    add("Neighbors:")

    for i = 1, #entry.neighbors do
      add("  " .. tostring(entry.neighbors[i]))
    end
  end

  local recent = EbonAPI.Log.recent(entry.addon, 10)

  if #recent > 0 then
    add("Trace:")

    for i = 1, #recent do
      add("  " .. recent[i])
    end
  end

  add("Message: " .. Problems.text(entry))

  if GetNumAddOns and GetAddOnInfo then
    local names = {}

    for i = 1, GetNumAddOns() do
      local name = GetAddOnInfo(i)

      if name and IsAddOnLoaded and IsAddOnLoaded(i) then
        names[#names + 1] = name .. " " .. tostring(versionOf(name) or "?")
      end
    end

    add("Loaded addons: " .. concat(names, ", "))
  end

  return concat(out, string.char(10))
end

local function process(problem)
  local class = problem.class

  if NEIGHBOR_CLASSES[class] and not problem.neighbors then
    local Catch = EbonAPI.Catch

    if Catch and Catch.neighbors then
      problem.neighbors = Catch.neighbors(problem.at)
    end
  end

  local def = defs[problem.code]

  if class == "rejet" then
    submit(opReject, problem)
  elseif ENTRY_CLASSES[class] or (def and def.entry) then
    submit(opEntry, problem)
  elseif class == "refus" then
    submit(opRefusal, problem)
  end

  Log.trace("problem", problem.addon, problem.code, class)
  Problems.show(problem)
  EbonAPI:Emit("PROBLEM", problem.addon, problem)
end

local function run(problem)
  local ok, err = pcall(process, problem)

  if not ok then
    internalError(err)
  end

  return problem
end

function Problems.report(problem)
  if problem.reported then
    return problem
  end

  problem.reported = true

  return run(problem)
end

function Problems.degrade(problem)
  problem.class = "panne"
  problem.open = true
  problem.reported = true

  return run(problem)
end

function Problems.restore(addon, name, level)
  local code = make(addon, name, nil, nil, nil, (level or 2) + 1).code

  if submit(opRestore, addon, code) then
    EbonAPI:Emit("PROBLEM_CLOSED", addon, code)
  end
end

function Problems.reject(addon, name, facts, level)
  local problem = make(addon, name, facts, nil, EXAMPLE_LIMIT, (level or 2) + 1)

  problem.class = "rejet"

  return Problems.report(problem)
end

function Problems.repaired(addon, name, facts, old, level)
  local problem = make(addon, name, facts, nil, nil, (level or 2) + 1)

  problem.class = "reparation"
  problem.old = old

  return Problems.report(problem)
end

local function guardError(message)
  return { message = tostring(message), stack = debugstack and debugstack(2, 8, 0) or "" }
end

function Problems.bug(addon, step, message, stack, at, triggered, guarded)
  local where = Problems.where(message)
  local problem = make(addon, defs[LUA_ERROR], { step = step or where or "lua", message = message, triggered = triggered })

  problem.where = where
  problem.guarded = guarded
  problem.stack = stack
  problem.key = where or (step ~= nil and tostring(step)) or sub(tostring(message), 1, 80)
  problem.at = at or problem.at

  return Problems.report(problem)
end

local function finish(addon, step, ok, ...)
  if ok then
    return ...
  end

  local info = ...

  if type(info) ~= "table" then
    info = { message = tostring(info), stack = "" }
  end

  return nil, Problems.bug(addon, step, info.message, info.stack, nil, nil, true)
end

function Problems.guard(addon, step, fn, ...)
  local count = select("#", ...)

  if count == 0 then
    return finish(addon, step, xpcall(fn, guardError))
  end

  local args = { ... }

  return finish(addon, step, xpcall(function()
    return fn(unpack(args, 1, count))
  end, guardError))
end

function Problems.requires(addon)
  return requirements[addon]
end

function Problems.active(addon)
  local list = {}

  for _, entry in pairs(active) do
    if entry.addon == addon then
      list[#list + 1] = entry
    end
  end

  sort(list, function(a, b)
    return a.first < b.first
  end)

  return list
end

function Problems.summary(addon, piece)
  local count, severe, graves, latest, latestSevere = 0, false, 0, nil, nil

  for _, entry in pairs(active) do
    if (addon == nil or entry.addon == addon) and (piece == nil or Problems.option(entry.addon, piece)) then
      count = count + 1

      local grave = entry.open or Problems.route(entry) == "block"

      if grave then
        severe = true
        graves = graves + 1
      end

      if grave then
        if not latestSevere or (entry.last or 0) > (latestSevere.last or 0) then
          latestSevere = entry
        end
      elseif not latest or (entry.last or 0) > (latest.last or 0) then
        latest = entry
      end
    end
  end

  return { count = count, severe = severe, grave = graves, latest = latestSevere or latest }
end

function Handle:Problems(prefix, catalogue, options)
  Problems.declare(self.addonName, prefix, catalogue, 3, options)
end

function Handle:Problem(name, facts, cause)
  return Problems.new(self.addonName, name, facts, cause)
end

function Handle:Report(problem)
  return Problems.report(problem)
end

function Handle:Degrade(problem)
  return Problems.degrade(problem)
end

function Handle:Restore(name)
  Problems.restore(self.addonName, name, 3)
end

function Handle:Reject(name, facts)
  return Problems.reject(self.addonName, name, facts)
end

function Handle:Repaired(name, facts, old)
  return Problems.repaired(self.addonName, name, facts, old)
end

function Handle:Guard(step, fn, ...)
  return Problems.guard(self.addonName, step, fn, ...)
end

function Handle:Requires(pieces)
  if type(pieces) ~= "table" then
    error("EbonAPI: " .. self.addonName .. ": api:Requires expects a list, got " .. type(pieces), 2)
  end

  requirements[self.addonName] = pieces
end

function Handle:ProblemText(problem)
  return Problems.text(problem)
end

function Handle:ActiveProblems()
  return Problems.active(self.addonName)
end

Problems.declare("EbonAPI", "EBONAPI", {
  ["LUA.ERROR"] = { class = "bug" },
  ["GAME.ACTION_BLOCKED"] = { class = "bug", key = "action" },
  ["GAME.ACTION_FORBIDDEN"] = { class = "bug", key = "action" },
  ["UNCODED"] = { class = "refus", key = "text", entry = true },
  ["ADDON.VERSION_TOO_OLD"] = { class = "echec", key = "needs" },
  ["CHANNEL.NOT_JOINED"] = { class = "panne" },
})

local Catch = EbonAPI.Catch

if Catch and Catch.problemsReady then
  Catch.problemsReady()
end
