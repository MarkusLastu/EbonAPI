EbonAPI = EbonAPI or {}
EbonAPI.Settings = {}

local Settings = EbonAPI.Settings
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local DB = EbonAPI.DB
local Format = EbonAPI.Format
local Perf = EbonAPI.Perf
local Queue = EbonAPI.Queue
local Opcodes = EbonAPI.Opcodes
local Bridge = EbonAPI.Bridge
local Ebonhold = EbonAPI.Ebonhold
local State = EbonAPI.State
local Channel = EbonAPI.Channel
local Profile = EbonAPI.Profile
local Version = EbonAPI.Version
local Share = EbonAPI.Share
local Options = EbonAPI.Options
local Parameters = EbonAPI.Parameters
local Palette = EbonAPI.Palette
local Skins = EbonAPI.Skins
local Buttons = EbonAPI.MinimapButtons
local Modules = EbonAPI.ModuleLoader
local Kit = EbonAPI.Kit
local Window = EbonAPI.Window
local L = EbonAPI.L

local ipairs = ipairs
local format, concat = string.format, table.concat

local ALL = "*"
local NAME = EbonAPI.name

local shown = nil
local perfTarget = ALL
local traceKind = ALL
local debugTarget = NAME
local logState = { filter = "all", query = "", reverse = false, open = {} }
local opsState = { filter = "all", query = "", sort = "dir", desc = false }

local function T(key)
  return function()
    return L[key]
  end
end

function Settings.status()
  local lines = {}

  local function say(text)
    lines[#lines + 1] = text
  end

  say(format(L.STATUS_VERSION, EbonAPI.version))

  local names = EbonAPI:AddonNames()

  if #names == 0 then
    say(L.STATUS_NO_ADDONS)
  else
    say(format(L.STATUS_ADDONS, Format.list(names)))
  end

  if Bridge.seen then
    say(format(L.STATUS_BRIDGE_UP, Bridge.received, GetTime() - Bridge.lastMessageAt))
  else
    say(L.STATUS_BRIDGE_IDLE)
  end

  say(format(L.STATUS_BRIDGE_COUNTS, Bridge.sent, Bridge.queueLength(), Bridge.streamCount()))

  if Channel.isJoined() then
    say(format(L.STATUS_CHANNEL_UP, Channel.NAME, Channel.index() or 0, Channel.joinedFor() or 0))
  elseif Channel.isWanted() then
    say(format(L.STATUS_CHANNEL_DOWN, Channel.NAME, Channel.requests()))
  else
    say(format(L.STATUS_CHANNEL_OFF, Channel.NAME))
  end

  local qs, qd = Queue.sent, Queue.dropped

  say(format(L.STATUS_QUEUE, Queue.serverLength(), Queue.peerLength(), qs.channel, qs.whisper))

  local queueDrops = qd.offline + qd.full + qd.failed
  local channelDrops = Channel.droppedTotal()

  if queueDrops > 0 or channelDrops > 0 then
    say(format(L.STATUS_QUEUE_DROPS, qd.offline, qd.full, qd.failed, channelDrops))
  end

  say(format(L.STATUS_PROFILE, Profile.sent.P, Profile.sent.D, Profile.sent.X,
    Profile.received, Profile.rejected))
  say(format(L.STATUS_VERSIONS, Version.summary()))
  say(format(L.STATUS_SHARE, Share.summary()))

  local drops = Bridge.drops
  local total = Bridge.droppedTotal()

  if total > 0 or State.rejected > 0 or DB.repaired > 0 then
    say(format(L.STATUS_REJECTED, total, drops.header, drops.bounds, drops.sender, drops.expired))
    say(format(L.STATUS_BODIES, State.rejected, DB.repaired))
  end

  say(Ebonhold.IsPresent() and L.STATUS_EBONHOLD_YES or L.STATUS_EBONHOLD_NO)

  local present, missing = Ebonhold.Summary()

  if #present > 0 then
    say("  " .. Format.list(present))
  end

  if #missing > 0 then
    say("  " .. Palette.code("muted") .. format(L.STATUS_EBONHOLD_MISSING, Format.list(missing)) .. "|r")
  end

  local key = DB.CharacterKey()

  say(key and format(L.STATUS_CHARACTER, key) or L.STATUS_CHARACTER_NONE)

  return lines
end

-- Fiche d'état : mêmes données et mêmes appels que Settings.status(), en sections
-- { id, name, rows } ; ligne { id, label, value, chips, level, tag }.
-- Niveaux : nil (aucun jugement), "ok", "warn", "bad", "info". Lecture seule.
local DASH = "\226\128\148"

function Settings.statusRows()
  local E = EbonAPI
  local sections = {}

  local function section(id, name)
    local s = { id = id, name = name, rows = {} }
    sections[#sections + 1] = s
    return s.rows
  end

  -- fn rend { value, chips, level, tag } ; toute erreur ou source absente donne « — » en info.
  local function add(rows, id, label, fn)
    local ok, r = pcall(fn)

    if not ok or type(r) ~= "table" then
      r = { value = DASH, level = "info" }
    end

    rows[#rows + 1] = { id = id, label = label, value = r.value, chips = r.chips, level = r.level, tag = r.tag }
  end

  -- gen
  local gen = section("gen", L.UI_FICHE_SEC_GEN)

  add(gen, "version", L.UI_FICHE_VERSION, function()
    return { value = format("%s", E.version) }
  end)
  add(gen, "consommateurs", L.UI_FICHE_CONSUMERS, function()
    local names = E:AddonNames()

    if #names == 0 then
      return { value = L.STATUS_NO_ADDONS, level = "info" }
    end

    local chips = {}

    for i = 1, #names do
      chips[i] = tostring(names[i])
    end

    return { chips = chips }
  end)

  -- srv
  local srv = section("srv", L.UI_FICHE_SEC_SRV)

  add(srv, "pont", L.UI_SYNTH_BRIDGE, function()
    local B = E.Bridge

    if B.seen then
      return { value = format(L.UI_FICHE_BRIDGE_UP, B.received, GetTime() - B.lastMessageAt), level = "ok" }
    end

    return { value = L.UI_FICHE_BRIDGE_IDLE, level = "warn" }
  end)
  add(srv, "compteurs", L.UI_FICHE_COUNTS, function()
    local B = E.Bridge

    return { value = format("%d \194\183 %d \194\183 %d", B.sent, B.queueLength(), B.streamCount()) }
  end)
  add(srv, "canal", L.UI_SYNTH_CHANNEL, function()
    local C = E.Channel

    if C.isJoined() then
      return { value = format(L.UI_FICHE_CHANNEL_UP, C.index() or 0, C.joinedFor() or 0), level = "ok" }
    elseif C.isWanted() then
      return { value = format(L.UI_FICHE_CHANNEL_DOWN, C.requests()), level = "warn" }
    end

    return { value = format(L.STATUS_CHANNEL_OFF, C.NAME), level = "info" }
  end)

  -- file
  local file = section("file", L.UI_SYNTH_GROUP_QUEUE)

  add(file, "file", L.UI_FICHE_QUEUE, function()
    local Q = E.Queue

    return { value = format(L.UI_FICHE_QUEUE_VALUE, Q.serverLength(), Q.peerLength()) }
  end)
  add(file, "envoyes", L.UI_FICHE_SENT, function()
    local qs = E.Queue.sent

    return { value = format(L.UI_FICHE_SENT_VALUE, qs.channel, qs.whisper) }
  end)

  local okDrops, queueDrops, channelDrops = pcall(function()
    local qd = E.Queue.dropped

    return qd.offline + qd.full + qd.failed, E.Channel.droppedTotal()
  end)

  if okDrops and (queueDrops > 0 or channelDrops > 0) then
    add(file, "refuses", L.UI_FICHE_DROPS, function()
      local qd = E.Queue.dropped

      return {
        value = format(L.UI_FICHE_DROPS_VALUE, qd.offline, qd.full, qd.failed, channelDrops),
        level = "warn",
        tag = format(L.UI_FICHE_DROPS_TAG, queueDrops + channelDrops),
      }
    end)
  end

  -- ech
  local ech = section("ech", L.UI_FICHE_SEC_ECH)

  add(ech, "profil", L.UI_SYNTH_PROFILE, function()
    local P = E.Profile
    local r = { value = format(L.UI_FICHE_PROFILE_VALUE, P.sent.P, P.sent.D, P.sent.X, P.received, P.rejected) }

    if P.rejected > 0 then
      r.level = "warn"
      r.tag = format(L.UI_FICHE_PROFILE_TAG, P.rejected)
    end

    return r
  end)
  add(ech, "versions", L.UI_FICHE_VERSIONS, function()
    local summary = E.Version.summary()

    if type(summary) == "table" then
      return #summary > 0 and { chips = summary } or { value = DASH, level = "info" }
    end

    -- Version.summary() rend une chaîne « nom 1.0, nom 2.0 » : une pastille par addon.
    local chips = {}

    for part in string.gmatch(tostring(summary), "[^,]+") do
      part = string.gsub(part, "^%s+", "")
      part = string.gsub(part, "%s+$", "")

      if part ~= "" then
        chips[#chips + 1] = part
      end
    end

    if #chips == 0 then
      return { value = DASH, level = "info" }
    end

    return { chips = chips }
  end)
  add(ech, "partage", L.UI_SYNTH_SHARE, function()
    local keys, addons, peers, received, refused = E.Share.summary()

    return {
      value = format(L.UI_FICHE_SHARE_VALUE, keys, addons, peers, received, refused),
      level = refused > 0 and "warn" or "ok",
      tag = refused > 0 and format(L.UI_FICHE_SHARE_TAG, refused) or nil,
    }
  end)

  local okRej, showRej = pcall(function()
    return E.Bridge.droppedTotal() > 0 or E.State.rejected > 0 or E.DB.repaired > 0
  end)

  if okRej and showRej then
    add(ech, "rejets", L.UI_FICHE_REJECTS, function()
      local drops = E.Bridge.drops

      return {
        value = format(L.UI_FICHE_REJECTS_VALUE, E.Bridge.droppedTotal(), drops.header, drops.bounds,
          drops.sender, drops.expired),
        level = "warn",
      }
    end)
    add(ech, "corps", L.UI_FICHE_BODIES, function()
      return { value = format("%d \194\183 %d", E.State.rejected, E.DB.repaired), level = "warn" }
    end)
  end

  -- pe
  local pe = section("pe", L.UI_SYNTH_PE)

  add(pe, "etat", L.UI_FICHE_STATE, function()
    if E.Ebonhold.IsPresent() then
      return { value = L.UI_SYNTH_DETECTED, level = "ok" }
    end

    return { value = L.UI_SYNTH_ABSENT, level = "warn" }
  end)

  local okPe, present, missing = pcall(function()
    return E.Ebonhold.Summary()
  end)

  if okPe and type(present) == "table" and type(missing) == "table" then
    if #present > 0 then
      local chips = {}

      for i = 1, #present do
        chips[i] = tostring(present[i])
      end

      pe[#pe + 1] = { id = "elements", label = format(L.UI_FICHE_ITEMS, #chips), chips = chips }
    end

    if #missing > 0 then
      local chips = {}

      for i = 1, #missing do
        chips[i] = tostring(missing[i])
      end

      pe[#pe + 1] = { id = "manquants", label = format(L.UI_FICHE_MISSING, #chips), chips = chips, level = "warn" }
    end
  else
    add(pe, "elements", format(L.UI_FICHE_ITEMS, 0), function()
      return { value = DASH, level = "info" }
    end)
  end

  -- per
  local per = section("per", L.UI_FICHE_SEC_PER)

  add(per, "portee", L.UI_FICHE_SCOPE, function()
    local key = E.DB.CharacterKey()

    if key then
      return { value = tostring(key) }
    end

    return { value = L.STATUS_CHARACTER_NONE, level = "info" }
  end)

  return sections
end

function Settings.senders()
  local senders = Bridge.observedSenders()

  if Lib.isEmpty(senders) then
    return L.SENDERS_NONE
  end

  local lines = {}

  for _, name in ipairs(Lib.sortedKeys(senders)) do
    lines[#lines + 1] = format(L.SENDERS_LINE, name, senders[name])
  end

  lines[#lines + 1] = format(L.SENDERS_STRICT, Format.boolean(Bridge.isStrictSender()))

  return concat(lines, "\n")
end

function Settings.addons()
  local names = EbonAPI:AddonNames()

  if #names == 0 then
    return L.UI_ADDONS_NONE
  end

  local lines = {}

  for _, name in ipairs(names) do
    -- A module follows EbonAPI's version: no number of its own, no update line.
    local own = Modules.owns(name)
    local version = not own and GetAddOnMetadata and GetAddOnMetadata(name, "Version")
    local latest = not own and Version.available(name)
    local line = name

    if version and latest then
      line = format(L.VERSION_UPDATE, name, version, latest)
    elseif version then
      line = name .. " " .. version
    end

    if Options.has(name) then
      line = line .. "  " .. Palette.code("muted") .. L.UI_ADDONS_IN_WINDOW .. "|r"
    end

    lines[#lines + 1] = line
  end

  return concat(lines, "\n")
end

local REPORTS = {
  status = function()
    return concat(Settings.status(), "\n")
  end,
  trace = function()
    return Log.dump(30, traceKind ~= ALL and traceKind or nil)
  end,
  db = function()
    return DB.dump()
  end,
  opcodes = function()
    return Opcodes.list()
  end,
  senders = function()
    return Settings.senders()
  end,
}

Settings.REPORTS = REPORTS

local function perfOwners()
  if perfTarget == ALL then
    return Perf.owners()
  end

  return { perfTarget }
end

function Settings.output()
  if not shown then
    return nil
  end

  if shown.report then
    return REPORTS[shown.report]()
  end

  local lines = {}

  for _, item in ipairs(shown.reports) do
    for _, line in ipairs(Perf.describeReport(item.owner, item.report)) do
      lines[#lines + 1] = line
    end
  end

  return concat(lines, "\n")
end

-- Modèle du cadre du résultat : la fiche pour le rapport « status », du texte pour les autres.
function Settings.resultModel()
  if shown and shown.report == "status" then
    return {
      kind = "rows", sections = Settings.statusRows(), text = Settings.output(),
      groups = EbonAPI.Synthesis and EbonAPI.Synthesis.status() or nil,
    }
  end

  if shown and shown.report == "trace" then
    local rows, total = Settings.logRows()
    local counts = { all = 0, bad = 0, warn = 0, net = 0, oth = 0 }

    for _, row in ipairs(Log.rows(Log.CAPACITY, traceKind ~= ALL and traceKind or nil) or {}) do
      local level = row.level
      local group = (level == "bad" or level == "warn" or level == "net") and level or "oth"

      counts.all = counts.all + 1
      counts[group] = counts[group] + 1
    end

    return {
      kind = "log", report = "trace", rows = rows, total = total, text = Settings.logText(rows), counts = counts,
      filter = logState.filter, query = logState.query, reverse = logState.reverse,
      groups = EbonAPI.Synthesis and EbonAPI.Synthesis.forReport and EbonAPI.Synthesis.forReport("trace") or nil,
    }
  end

  if shown and shown.report == "opcodes" and Settings.opsModel then
    return Settings.opsModel()
  end

  return { kind = "text", text = Settings.output() or L.UI_RESULT_EMPTY }
end

-- Journal des traces : état (filtre de niveau, recherche, ordre, lignes ouvertes) gardé tant que le jeu tourne.
local LOG_FILTERS = { all = true, bad = true, warn = true, net = true, oth = true }

function Settings.setLogFilter(id)
  logState.filter = LOG_FILTERS[id] and id or "all"

  return logState.filter
end

function Settings.setLogQuery(text)
  logState.query = type(text) == "string" and text or ""
end

function Settings.setLogReverse(flag)
  logState.reverse = flag and true or false
end

function Settings.toggleLogOpen(key)
  logState.open[key] = (not logState.open[key]) or nil

  return logState.open[key] == true
end

function Settings.logState()
  local open = {}

  for key in pairs(logState.open) do
    open[key] = true
  end

  return { filter = logState.filter, query = logState.query, reverse = logState.reverse, open = open }
end

-- Lignes à afficher (rend aussi le nombre de lignes avant le filtre de niveau et la recherche).
function Settings.logRows()
  local source = Log.rows(Log.CAPACITY, traceKind ~= ALL and traceKind or nil) or {}
  local query = string.lower(logState.query or "")
  local rows = {}

  for _, row in ipairs(source) do
    local level = row.level
    local group = (level == "bad" or level == "warn" or level == "net") and level or "oth"
    local keep = logState.filter == "all" or group == logState.filter

    if keep and query ~= "" then
      local hay = string.lower(tostring(row.kind) .. " " .. tostring(row.owner or EbonAPI.name) .. " "
        .. tostring(row.owner or "") .. " " .. tostring(row.text))

      keep = string.find(hay, query, 1, true) ~= nil
    end

    if keep then
      row.key = tostring(row.at) .. "|" .. tostring(row.kind) .. "|" .. tostring(row.text)
      rows[#rows + 1] = row
    end
  end

  if logState.reverse then
    local reversed = {}

    for index = #rows, 1, -1 do
      reversed[#reversed + 1] = rows[index]
    end

    rows = reversed
  end

  return rows, #source
end

function Settings.logText(rows)
  local lines = {}

  for _, row in ipairs(rows or {}) do
    lines[#lines + 1] = format("%6.1fs  %-5s  %-14s  %s", row.age, row.kind, row.owner or "-", row.text)
  end

  return concat(lines, "\n")
end

-- Table des opcodes : état (filtre de sens, recherche, tri) gardé tant que le jeu tourne.
local OPS_FILTERS = { all = true, ss = true, cs = true }
local OPS_SORTS = { dir = true, code = true, name = true }
local OPS_TAGS = { ss = "S>C", cs = "C>S" }

function Settings.setOpsFilter(id)
  opsState.filter = OPS_FILTERS[id] and id or "all"

  return opsState.filter
end

function Settings.setOpsQuery(text)
  opsState.query = type(text) == "string" and text or ""
end

function Settings.setOpsSort(key)
  key = OPS_SORTS[key] and key or "code"

  if key == opsState.sort then
    opsState.desc = not opsState.desc
  else
    opsState.sort = key
    opsState.desc = false
  end

  return opsState.sort, opsState.desc
end

function Settings.opsState()
  return { filter = opsState.filter, query = opsState.query, sort = opsState.sort, desc = opsState.desc }
end

-- Lignes de la table des opcodes (rend aussi le nombre de lignes avant le filtre et la recherche).
function Settings.opsRows()
  local ok, source = pcall(function()
    return EbonAPI.Opcodes and EbonAPI.Opcodes.rows and EbonAPI.Opcodes.rows()
  end)

  if not ok or type(source) ~= "table" then
    return {}, 0
  end

  local query = string.lower(opsState.query or "")
  local rows = {}

  for _, row in ipairs(source) do
    local keep = opsState.filter == "all" or row.dir == opsState.filter

    if keep and query ~= "" then
      local hay = string.lower(tostring(row.name) .. " " .. tostring(row.code) .. " " .. (OPS_TAGS[row.dir] or ""))

      keep = string.find(hay, query, 1, true) ~= nil
    end

    if keep then
      rows[#rows + 1] = { dir = row.dir, code = row.code, name = row.name, key = tostring(row.dir) .. ":" .. tostring(row.code) }
    end
  end

  local sort = opsState.sort

  table.sort(rows, function(a, b)
    if sort == "dir" and a.dir ~= b.dir then
      return a.dir == "ss"
    end

    if sort == "name" then
      local x, y = string.lower(a.name), string.lower(b.name)

      if x ~= y then
        return x < y
      end
    end

    if a.code ~= b.code then
      return a.code < b.code
    end

    return a.dir < b.dir
  end)

  if opsState.desc then
    local reversed = {}

    for index = #rows, 1, -1 do
      reversed[#reversed + 1] = rows[index]
    end

    rows = reversed
  end

  return rows, #source
end

-- Texte copiable : même format que Opcodes.list, dans l'ordre affiché.
function Settings.opsText(rows)
  local lines = {}

  for _, row in ipairs(rows or {}) do
    lines[#lines + 1] = "  " .. (OPS_TAGS[row.dir] or "") .. "  " .. tostring(row.code) .. "  " .. tostring(row.name)
  end

  return concat(lines, "\n")
end

-- Modèle prêt pour la vue (pas encore appelé par resultModel).
function Settings.opsModel()
  local rows, total = Settings.opsRows()
  local counts = { all = 0, ss = 0, cs = 0 }
  local ok, source = pcall(function()
    return EbonAPI.Opcodes and EbonAPI.Opcodes.rows and EbonAPI.Opcodes.rows()
  end)

  if ok and type(source) == "table" then
    for _, row in ipairs(source) do
      counts.all = counts.all + 1

      if counts[row.dir] then
        counts[row.dir] = counts[row.dir] + 1
      end
    end
  end

  local groups

  if EbonAPI.Synthesis and EbonAPI.Synthesis.forReport then
    groups = EbonAPI.Synthesis.forReport("opcodes")
  end

  return {
    kind = "ops", report = "opcodes", rows = rows, total = total, text = Settings.opsText(rows), counts = counts,
    filter = opsState.filter, query = opsState.query, sort = opsState.sort, desc = opsState.desc, groups = groups,
  }
end

function Settings.show(name)
  shown = REPORTS[name] and { report = name } or nil

  return Settings.output()
end

function Settings.perf(action)
  local reports = {}

  local function keep(owner, report)
    reports[#reports + 1] = { owner = owner, report = Perf.record(owner, report) }
  end

  if action == "measure" then
    if perfTarget == ALL then
      for _, row in ipairs(Perf.summarySample()) do
        keep(row.owner, { summary = row })
      end
    else
      local _, _, report = Perf.measure(perfTarget)

      reports[1] = { owner = perfTarget, report = report }
    end
  elseif action == "reset" then
    for _, owner in ipairs(perfOwners()) do
      Perf.reset(owner)
      keep(owner, { reset = true })
    end
  elseif action == "gc" then
    for _, owner in ipairs(perfOwners()) do
      local before, after = Perf.gc(owner)

      keep(owner, { before = before, after = after })
    end
  else
    shown = nil

    return nil
  end

  shown = { reports = reports }

  return Settings.output()
end

function Settings.setPerfTarget(target)
  perfTarget = target or ALL
end

function Settings.setTraceKind(kind)
  traceKind = kind or ALL
end

function Settings.setDebugTarget(name)
  debugTarget = name or NAME
end

local function addonValues(withAll)
  local values = {}

  if withAll then
    values[ALL] = L.UI_ALL_ADDONS
  end

  for _, owner in ipairs(Perf.owners()) do
    values[owner] = owner
  end

  return values
end

local function report(order, key, name)
  return {
    type = "execute", order = order, name = T(key),
    func = function()
      Settings.show(name)
    end,
  }
end

local function perfAction(order, key, action)
  return {
    type = "execute", order = order, name = T(key),
    func = function()
      Settings.perf(action)
    end,
  }
end

local function range(order, key, name, desc)
  local entry = Parameters.entry(name)

  return {
    type = "range", order = order, name = T(key), desc = desc and T(desc) or nil,
    min = entry.min, max = entry.max, step = entry.step, isPercent = entry.isPercent,
  }
end

local function notPending()
  return not Modules.pending()
end

local MODULE_STATES = {
  off = "UI_MODULE_OFF",
  error = "UI_MODULE_ERROR",
  legacy = "UI_MODULE_LEGACY",
  not_loaded = "UI_MODULE_NOT_LOADED",
}

function Settings.moduleState(name)
  local state = Modules.state(name)
  local reason = state.reason

  if state.loaded then
    return L.UI_MODULE_LOADED
  elseif MODULE_STATES[reason] then
    return L[MODULE_STATES[reason]]
  end

  return format(L.UI_MODULE_FAILED, _G["ADDON_" .. reason] or reason)
end

local function moduleCard(module, order)
  local name = module.name

  return {
    type = "group", inline = true, order = order,
    -- The card carries the module's own name, not the `.toc` title (a fixed color and the "EbonAPI - " prefix
    -- that groups the addon list): the window's colors follow the interface color.
    name = module.key,
    args = {
      enabled = {
        type = "toggle", order = 1, name = T("UI_MODULE_ENABLE"), desc = T("UI_MODULES_DESC"),
        get = function()
          return EbonAPI:IsModuleEnabled(name)
        end,
        set = function(_, value)
          EbonAPI:SetModuleEnabled(name, value)
        end,
      },
      about = {
        type = "description", order = 2, fontSize = "medium",
        name = function()
          local state = Palette.code("muted") .. Settings.moduleState(name) .. "|r"

          return module.notes and (module.notes .. "\n" .. state) or state
        end,
      },
    },
  }
end

local function modulesPage()
  local args = {
    pending = {
      type = "description", order = 1, fontSize = "medium", name = T("UI_MODULES_PENDING"), hidden = notPending,
    },
    reload = {
      type = "execute", order = 2, name = T("UI_RELOAD"), hidden = notPending,
      func = function()
        ReloadUI()
      end,
    },
  }
  local modules = Modules.list()

  if #modules == 0 then
    args.none = { type = "description", order = 3, fontSize = "medium", name = T("UI_MODULES_NONE") }
  end

  for index, module in ipairs(modules) do
    args["module_" .. module.name] = moduleCard(module, 2 + index)
  end

  return args
end

local function noAddons()
  return { type = "description", order = 1, fontSize = "medium", name = T("UI_ADDONS_NONE") }
end

Settings.tree = {
  type = "group",
  name = T("UI_NAME"),
  args = {
    general = {
      type = "group", order = 1, name = T("UI_GENERAL"),
      args = {
        language = {
          type = "select", order = 1, name = T("UI_LANGUAGE"), desc = T("UI_LANGUAGE_DESC"),
          values = function()
            local values = {}

            for _, entry in ipairs(EbonAPI:GetAvailableLanguages()) do
              values[entry.code] = entry.name
            end

            return values
          end,
          get = function()
            return EbonAPI:GetLanguage()
          end,
          set = function(_, code)
            EbonAPI:SetLanguage(code)
          end,
        },
        minimap = {
          type = "group", inline = true, order = 2, name = T("UI_MINIMAP"),
          args = {
            always = {
              type = "toggle", order = 1, name = T("UI_MINIMAP_ALWAYS"), desc = T("UI_MINIMAP_ALWAYS_DESC"),
              get = function()
                return Buttons.alwaysShown()
              end,
              set = function(_, value)
                Buttons.setAlwaysShown(value)
              end,
            },
            lock = {
              type = "toggle", order = 2, name = T("UI_MINIMAP_LOCK"),
              get = function()
                return Buttons.isLocked(NAME)
              end,
              set = function(_, value)
                Buttons.setLocked(NAME, value)
              end,
            },
            reset = {
              type = "execute", order = 3, name = T("UI_MINIMAP_RESET"),
              func = function()
                Buttons.reset(NAME)
              end,
            },
          },
        },
      },
    },
    appearance = {
      type = "group", order = 2, name = T("UI_APPEARANCE"),
      get = function(info)
        return Parameters.value(nil, info[#info])
      end,
      set = function(info, value)
        Parameters.setPlayer(info[#info], value)
      end,
      args = {
        skin = {
          type = "group", inline = true, order = 0, name = T("UI_SKIN"),
          args = {
            choice = {
              type = "select", order = 1, name = T("UI_SKIN_ACTIVE"), desc = T("UI_SKIN_DESC"),
              values = function()
                local values = {}

                for _, name in ipairs(Skins.list()) do
                  values[name] = name
                end

                return values
              end,
              sorting = function()
                return Skins.list()
              end,
              get = function()
                return Skins.chosen()
              end,
              set = function(_, name)
                Skins.choose(name)
              end,
            },
            pending = {
              type = "description", order = 2, fontSize = "medium",
              name = function()
                return format(L.UI_SKIN_PENDING, Skins.chosen())
              end,
              hidden = function()
                return not Skins.pending()
              end,
            },
            reload = {
              type = "execute", order = 3, name = T("UI_RELOAD"),
              hidden = function()
                return not Skins.pending()
              end,
              func = function()
                ReloadUI()
              end,
            },
          },
        },
        colors = {
          type = "group", inline = true, order = 1, name = T("UI_COLORS"),
          get = function(info)
            return Palette.unpackColor(Parameters.value(nil, info[#info]))
          end,
          set = function(info, r, g, b)
            Parameters.setPlayer(info[#info], Palette.packColor(r, g, b))
          end,
          args = {
            background = { type = "color", order = 1, name = T("UI_BACKGROUND") },
            accent = { type = "color", order = 2, name = T("UI_ACCENT") },
          },
        },
        windows = {
          type = "group", inline = true, order = 2, name = T("UI_WINDOWS"),
          args = {
            scale = range(1, "UI_SCALE", "scale"),
            opacity = range(2, "UI_OPACITY", "opacity"),
            shadow = range(3, "UI_SHADOW", "shadow"),
            corners = range(4, "UI_CORNERS", "corners", "UI_CORNERS_DESC"),
          },
        },
        layout = {
          type = "group", inline = true, order = 3, name = T("UI_LAYOUT"),
          args = {
            tabs = {
              type = "select", order = 1, name = T("UI_TABS"),
              values = function()
                return { LEFT = L.UI_TABS_LEFT, RIGHT = L.UI_TABS_RIGHT }
              end,
              sorting = { "LEFT", "RIGHT" },
            },
            locked = { type = "toggle", order = 2, name = T("UI_LOCK") },
          },
        },
        defaults = {
          type = "execute", order = 4, name = T("UI_DEFAULTS"), desc = T("UI_DEFAULTS_DESC"),
          func = function()
            Parameters.resetPlayer()
          end,
        },
      },
    },
    modules = {
      type = "group", order = 6, name = T("UI_MODULES"),
      args = modulesPage(),
    },
    addons = {
      type = "group", order = 3, name = T("UI_ADDONS"),
      args = { none = noAddons() },
    },
    problems = {
      type = "group", order = 5, name = T("CENTER_TITLE"),
      hidden = function()
        local Center = EbonAPI.Center

        if Center then
          Center.ensure()
        end

        return false
      end,
      args = {},
    },
    diagnostic = {
      type = "group", order = 4, name = T("UI_DIAGNOSTIC"),
      args = {
        errors = {
          type = "group", inline = true, order = 0, name = T("UI_ERRORS"),
          args = {
            network = {
              type = "toggle", order = 1, name = T("UI_ERRORS_NETWORK"), desc = T("UI_ERRORS_NETWORK_DESC"),
              get = function()
                return EbonAPI.Problems.networkShown()
              end,
              set = function(_, value)
                EbonAPI.Problems.setNetworkShown(value)
              end,
            },
          },
        },
        reports = {
          type = "group", inline = true, order = 1, name = T("UI_REPORTS"),
          args = {
            status = report(1, "UI_REPORT_STATUS", "status"),
            trace = report(2, "UI_REPORT_TRACE", "trace"),
            db = report(3, "UI_REPORT_DB", "db"),
            opcodes = report(4, "UI_REPORT_OPCODES", "opcodes"),
            senders = report(5, "UI_REPORT_SENDERS", "senders"),
            kind = {
              type = "select", order = 6, name = T("UI_TRACE_KIND"),
              values = function()
                local values = { [ALL] = L.UI_TRACE_ALL }

                for _, kind in ipairs(Log.kinds()) do
                  values[kind] = kind
                end

                return values
              end,
              get = function()
                return traceKind
              end,
              set = function(_, value)
                Settings.setTraceKind(value)
              end,
            },
          },
        },
        debug = {
          type = "group", inline = true, order = 2, name = T("UI_DEBUG"),
          args = {
            all = {
              type = "toggle", order = 1, name = T("UI_ALL_ADDONS"),
              get = function()
                return Log.isDebug(nil)
              end,
              set = function(_, value)
                Log.setDebug(nil, value)
              end,
            },
            target = {
              type = "select", order = 2, name = T("UI_ADDON"),
              values = function()
                return addonValues(false)
              end,
              get = function()
                return debugTarget
              end,
              set = function(_, value)
                Settings.setDebugTarget(value)
              end,
            },
            one = {
              type = "toggle", order = 3, name = T("UI_DEBUG_ONE"),
              disabled = function()
                return Log.isDebug(nil)
              end,
              get = function()
                return Log.isDebug(debugTarget)
              end,
              set = function(_, value)
                Log.setDebug(debugTarget, value)
              end,
            },
          },
        },
        queue = {
          type = "group", inline = true, order = 4, name = T("UI_QUEUEVIEW"),
          args = {
            open = {
              type = "execute", order = 1, name = T("UI_QUEUEVIEW_OPEN"),
              func = function()
                EbonAPI.QueueView.open()
              end,
            },
          },
        },
        perf = {
          type = "group", inline = true, order = 3, name = T("UI_PERF"),
          args = {
            target = {
              type = "select", order = 1, name = T("UI_ADDON"),
              values = function()
                return addonValues(true)
              end,
              get = function()
                return perfTarget
              end,
              set = function(_, value)
                Settings.setPerfTarget(value)
              end,
            },
            measure = perfAction(2, "UI_PERF_MEASURE", "measure"),
            reset = perfAction(3, "UI_PERF_RESET", "reset"),
            gc = perfAction(4, "UI_PERF_GC", "gc"),
          },
        },
        result = { type = "header", order = 4, name = T("UI_RESULT") },
        output = {
          type = "description", order = 5, fontSize = "medium", view = "result",
          name = function()
            return Settings.output() or L.UI_RESULT_EMPTY
          end,
        },
      },
    },
  },
}

local function metadata(name, field)
  local value = GetAddOnMetadata and GetAddOnMetadata(name, field)

  return type(value) == "string" and value ~= "" and value or nil
end

function Settings.addonTitle(name)
  -- A module has no version of its own: the name alone.
  local version = not Modules.owns(name) and metadata(name, "Version")

  return version and (name .. " " .. version) or name
end

function Settings.addonAbout(name)
  local lines = {}
  local notes, author = metadata(name, "Notes"), metadata(name, "Author")
  local latest = Version.available(name)
  local link = EbonAPI:AddonLink(name)

  if notes then
    lines[#lines + 1] = notes
  end

  if author then
    lines[#lines + 1] = Palette.code("muted") .. format(L.UI_ADDON_AUTHOR, author) .. "|r"
  end

  if latest then
    lines[#lines + 1] = Palette.code("heading") .. format(L.UI_ADDON_UPDATE, latest) .. "|r"
  end

  if link and not EbonAPI:LinkMethod() then
    lines[#lines + 1] = link
  end

  return concat(lines, "\n")
end

local function noMinimap(name)
  return function()
    return not Buttons.has(name)
  end
end

local function notOnMinimap(name)
  return function()
    return Buttons.display(name) ~= "BUTTON"
  end
end

local function cardTitle(name)
  return function()
    local icon = EbonAPI:AddonIcon(name)
    local title = Settings.addonTitle(name)

    return icon and format("|T%s:0|t %s", icon, title) or title
  end
end

local function minimapControls(args, name, order)
  args.minimap = {
    type = "select", order = order, name = T("UI_MINIMAP"), desc = T("UI_MINIMAP_DESC"),
    values = function()
      return { BUTTON = L.UI_MINIMAP_BUTTON, GROUP = L.UI_MINIMAP_GROUP, HIDDEN = L.UI_MINIMAP_HIDDEN }
    end,
    sorting = { "BUTTON", "GROUP", "HIDDEN" },
    hidden = noMinimap(name),
    get = function()
      return Buttons.display(name)
    end,
    set = function(_, value)
      Buttons.setDisplay(name, value)
    end,
  }
  args.minimapLock = {
    type = "toggle", order = order + 1, name = T("UI_MINIMAP_LOCK"),
    hidden = noMinimap(name),
    disabled = notOnMinimap(name),
    get = function()
      return Buttons.isLocked(name)
    end,
    set = function(_, value)
      Buttons.setLocked(name, value)
    end,
  }
  args.minimapReset = {
    type = "execute", order = order + 2, name = T("UI_MINIMAP_RESET"),
    hidden = noMinimap(name),
    disabled = notOnMinimap(name),
    func = function()
      Buttons.reset(name)
    end,
  }

  return args
end

local function addonCard(name, order)
  return {
    type = "group", inline = true, order = order,
    name = cardTitle(name),
    args = minimapControls({
      about = {
        type = "description", order = 1, fontSize = "medium",
        name = function()
          return Settings.addonAbout(name)
        end,
        hidden = function()
          return Settings.addonAbout(name) == ""
        end,
      },
      settings = {
        type = "execute", order = 2, name = T("UI_ADDON_SETTINGS"),
        hidden = function()
          return not Options.has(name)
        end,
        func = function()
          EbonAPI:OpenOptions(name)
        end,
      },
      link = {
        type = "execute", order = 3,
        name = function()
          local latest = Version.available(name)

          return latest and format(L.UI_ADDON_DOWNLOAD, latest) or L.UI_ADDON_LINK
        end,
        desc = function()
          return EbonAPI:LinkTip()
        end,
        hidden = function()
          return not (EbonAPI:AddonLink(name) and EbonAPI:LinkMethod())
        end,
        func = function()
          EbonAPI:OpenLink(EbonAPI:AddonLink(name))
        end,
      },
    }, name, 4),
  }
end

function Settings.rebuildAddons()
  local args = Settings.tree.args.addons.args

  for key in pairs(args) do
    args[key] = nil
  end

  if Skins.value("page.addons") == "LIST" then
    args.list = {
      type = "description", order = 1, fontSize = "medium",
      name = function()
        return Settings.addons()
      end,
    }

    for index, name in ipairs(EbonAPI:AddonNames()) do
      args["minimap_" .. name] = {
        type = "group", inline = true, order = 1 + index, name = cardTitle(name), hidden = noMinimap(name),
        args = minimapControls({}, name, 1),
      }
    end

    return
  end

  local names = EbonAPI:AddonNames()

  if #names == 0 then
    args.none = noAddons()
  end

  for index, name in ipairs(names) do
    args["addon_" .. name] = addonCard(name, index)
  end
end

local function addonsChanged()
  Settings.rebuildAddons()

  if EbonAPI.Window then
    EbonAPI.Window.refresh()
  end
end

EbonAPI:On("ADDON_CONNECTED", addonsChanged)
EbonAPI:On("READY", addonsChanged)
EbonAPI:On("UPDATE_AVAILABLE", addonsChanged)

local problem = Options.register(NAME, Settings.tree)

if problem then
  error("EbonAPI: its own options are invalid: " .. problem)
end

-- The notice comes back each session while an installed module is off, until the player opens
-- the Modules page once.
local hint = nil
local openModules

local function markSeen()
  DB.shared().account.modulesSeen = true

  if hint and hint.onClick == openModules then
    Kit.dismiss(hint)
  end

  hint = nil
end

openModules = function()
  Window.open(NAME, "modules")
  markSeen()
end

local function hintModules()
  if DB.shared().account.modulesSeen or not Modules.anyDisabled() then
    return
  end

  hint = Kit.notify(NAME, L.UI_MODULES_HINT, { onClick = openModules })
end

local function pageShown(_, owner, key)
  if owner == NAME and key == "modules" then
    markSeen()
  end
end

EbonAPI:On("READY", hintModules)
EbonAPI:On("WINDOW_PAGE", pageShown)
