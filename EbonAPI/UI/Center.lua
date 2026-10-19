EbonAPI = EbonAPI or {}
EbonAPI.Center = {}

local Center = EbonAPI.Center
local Settings = EbonAPI.Settings
local Problems = EbonAPI.Problems
local Palette = EbonAPI.Palette
local Handle = EbonAPI.Handle
local L = EbonAPI.L

local api = setmetatable({ addonName = "EbonAPI" }, { __index = Handle })

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local format, sub, gsub, match, date = string.format, string.sub, string.gsub, string.match, date
local concat, sort = table.concat, table.sort

local PAGE = "problems"
local ALL = "*"
local CURRENT = "current"
local SEP = "\031"
local UNCODED = "EBONAPI.UNCODED"
local CUT = 90
local CLASSES = { "refus", "rejet", "echec", "partiel", "panne", "bug", "reparation" }
local COLORS = { bug = "danger", echec = "danger", panne = "danger", partiel = "caution", reparation = "caution" }

Center.filter = { addon = ALL, class = ALL, version = CURRENT }
Center.current = nil
Center.details = false

local built = false
local dirty = false

local function pick(count, one, many)
  return format(count == 1 and L[one] or L[many], count)
end

local function cut(text)
  if #text <= CUT then
    return text
  end

  return (gsub(sub(text, 1, CUT), "[\192-\255][\128-\191]*$", "")) .. "..."
end

local function className(class)
  return L["CENTER_CLASS_" .. string.upper(tostring(class))] or tostring(class)
end

local function factsText(facts)
  local keys = {}

  for key in pairs(facts or {}) do
    keys[#keys + 1] = tostring(key)
  end

  sort(keys)

  for index, key in ipairs(keys) do
    keys[index] = key .. "=" .. tostring(facts[key])
  end

  return concat(keys, ", ")
end

local function isCurrent(entry)
  local seen = entry.versions and entry.versions.addon
  local now = rawget(_G, "GetAddOnMetadata") and GetAddOnMetadata(entry.addon, "Version")

  return seen == nil or now == nil or seen == now
end

function Center.entries()
  local journal = Problems.journal()
  local filter = Center.filter
  local list = {}

  if journal then
    for _, entry in pairs(journal.entries) do
      if Problems.option(entry.addon, "center")
        and (filter.addon == ALL or entry.addon == filter.addon)
        and (filter.class == ALL or entry.class == filter.class)
        and (filter.version ~= CURRENT or isCurrent(entry)) then
        list[#list + 1] = entry
      end
    end
  end

  sort(list, function(a, b)
    local x, y = a.last or 0, b.last or 0

    if x ~= y then
      return x > y
    end

    return Problems.keyOf(a) < Problems.keyOf(b)
  end)

  return list
end

function Center.copyAllText()
  local parts = {}

  for index, entry in ipairs(Center.entries()) do
    parts[index] = Problems.copyText(entry)
  end

  return concat(parts, "\n\n")
end

function Center.copy(text)
  local clip = rawget(_G, "CopyToClipboard")

  if type(clip) == "function" then
    clip(text)
  else
    api:CopyBox(text, L.CENTER_TITLE)
  end
end

local function counters()
  local journal = Problems.journal()

  if not journal then
    return L.CENTER_NONE
  end

  local refusals, rejects, foreign, uncoded = 0, 0, 0, 0
  local example, latest = nil, -1
  local lines = {}

  for key, item in pairs(journal.refusals) do
    if Problems.option(Problems.addonOf(key), "center") then
      refusals = refusals + item.n
    end
  end

  for key, item in pairs(journal.rejects) do
    if Problems.option(Problems.addonOf(key), "center") then
      rejects = rejects + item.n
    end

    if Problems.option(Problems.addonOf(key), "center") and (item.last or 0) > latest then
      latest = item.last or 0
      local addon, code = match(key, "^(.-)" .. SEP .. "(.-)" .. SEP)

      example = format("%s %s %s", tostring(addon), tostring(code), factsText(item.example))
    end
  end

  for _, entry in pairs(journal.entries) do
    if entry.code == UNCODED and Problems.option(entry.addon, "center") then
      uncoded = uncoded + 1
    end
  end

  local names = {}

  for name, item in pairs(journal.foreign) do
    foreign = foreign + item.n
    names[#names + 1] = name
  end

  sort(names)

  lines[1] = pick(refusals, "CENTER_REFUSALS_ONE", "CENTER_REFUSALS")
  lines[2] = pick(rejects, "CENTER_REJECTS_ONE", "CENTER_REJECTS")

  if example then
    lines[#lines + 1] = "  " .. format(L.CENTER_REJECT_LAST, cut(example))
  end

  lines[#lines + 1] = pick(foreign, "CENTER_FOREIGN_ONE", "CENTER_FOREIGN")

  for _, name in ipairs(names) do
    lines[#lines + 1] = format("  %s: %d", name, journal.foreign[name].n)
  end

  lines[#lines + 1] = pick(uncoded, "CENTER_UNCODED_ONE", "CENTER_UNCODED")

  return concat(lines, "\n")
end

local function addonValues()
  local values = { [ALL] = L.CENTER_ALL }
  local journal = Problems.journal()

  for _, entry in pairs(journal and journal.entries or {}) do
    if Problems.option(entry.addon, "center") then
      values[entry.addon] = entry.addon
    end
  end

  return values
end

local function classValues()
  local values = { [ALL] = L.CENTER_ALL }

  for _, class in ipairs(CLASSES) do
    values[class] = className(class)
  end

  return values
end

local function filterOption(order, key, field, values)
  return {
    type = "select", order = order, name = function()
      return L[key]
    end,
    values = values,
    get = function()
      return Center.filter[field]
    end,
    set = function(_, value)
      Center.filter[field] = value
      Center.rebuild()
      Center.refresh()
    end,
  }
end

local function sheetEntry()
  local current = Center.current
  local journal = current and Problems.journal()

  return journal and journal.entries[current.key]
end

local function stamp(time)
  return time and date("%Y-%m-%d %H:%M:%S", time) or "?"
end

local function detailsText(entry)
  local lines = { format("%s (%s)", tostring(entry.code), tostring(entry.class)) }

  if entry.facts and next(entry.facts) then
    lines[#lines + 1] = L.CENTER_SHEET_FACTS .. ": " .. factsText(entry.facts)
  end

  if entry.cause and entry.cause.facts and next(entry.cause.facts) then
    lines[#lines + 1] = tostring(entry.cause.code) .. ": " .. factsText(entry.cause.facts)
  end

  if entry.stack and entry.stack ~= "" then
    lines[#lines + 1] = L.CENTER_SHEET_STACK .. ":\n" .. tostring(entry.stack)
  end

  return (gsub(concat(lines, "\n"), "|", "||"))
end

local function sheet(entry)
  local args, order = {}, 0

  local function add(key, node)
    order = order + 1
    node.order = order
    args[key] = node
  end

  local function line(key, text)
    add(key, { type = "description", fontSize = "medium", name = text })
  end

  line("what", function()
    return Palette.code(COLORS[entry.class] or "muted") .. Problems.text(entry) .. "|r"
  end)

  if entry.cause then
    line("cause", function()
      return format(L.CENTER_SHEET_CAUSE, Problems.text(entry.cause))
    end)
  end

  line("origin", function()
    local text = format(L.CENTER_SHEET_ORIGIN, tostring(entry.addon), tostring(entry.versions and entry.versions.addon or "?"))

    if entry.where then
      text = text .. "\n" .. format(L.CENTER_SHEET_WHERE, tostring(entry.where))
    end

    return text
  end)

  line("count", function()
    local first, last = entry.first or entry.at, entry.last or entry.at

    if (entry.count or 1) == 1 then
      return format(L.CENTER_SHEET_ONCE, stamp(last))
    end

    return format(L.CENTER_SHEET_COUNT, entry.count, stamp(first), stamp(last))
  end)

  if entry.neighbors and #entry.neighbors > 0 then
    line("neighbors", function()
      local names = {}

      for index, name in ipairs(entry.neighbors) do
        names[index] = "  " .. tostring(name)
      end

      return L.CENTER_SHEET_NEIGHBORS .. ":\n" .. gsub(concat(names, "\n"), "|", "||")
    end)
  end

  add("toggle", {
    type = "execute", name = function()
      return Center.details and L.CENTER_SHEET_HIDE or L.CENTER_SHEET_DETAILS
    end,
    func = function()
      Center.details = not Center.details
      Center.rebuild()
      Center.refresh()
    end,
  })

  if Center.details then
    line("details", function()
      return detailsText(entry)
    end)
  end

  add("copy", {
    type = "execute", name = function()
      return L.CENTER_SHEET_COPY
    end,
    func = function()
      Center.copy(Problems.copyText(sheetEntry() or entry))
    end,
  })

  add("close", {
    type = "execute", name = function()
      return L.CENTER_SHEET_CLOSE
    end,
    func = function()
      Center.current, Center.details = nil, false
      Center.rebuild()
      Center.refresh()
    end,
  })

  return { type = "group", inline = true, order = 0, name = function()
    return L.CENTER_TITLE
  end, args = args }
end

function Center.select(addon, key)
  Center.current = { addon = addon, key = key }
  Center.details = false
  Center.rebuild()
  Center.refresh()
end

local function row(entry, order)
  local key = Problems.keyOf(entry)

  return {
    type = "execute", order = order,
    name = function()
      local color = Palette.code(COLORS[entry.class] or "muted")

      return format("%s%s|r  %s  x%d  %s", color, cut(Problems.text(entry)), className(entry.class), entry.count or 1,
        entry.last and date("%Y-%m-%d %H:%M", entry.last) or "?")
    end,
    func = function()
      Center.select(entry.addon, key)
    end,
  }
end

function Center.rebuild()
  local args = Settings.tree.args[PAGE].args
  local groups, order, sizes = {}, {}, {}

  for key in pairs(args) do
    args[key] = nil
  end

  local picked = sheetEntry()

  if picked then
    args.sheet = sheet(picked)
  else
    Center.current = nil
  end

  args.counts = {
    type = "description", order = 1, fontSize = "medium",
    name = counters,
  }

  args.filters = {
    type = "group", inline = true, order = 2, name = function()
      return L.CENTER_FILTERS
    end,
    args = {
      addon = filterOption(1, "CENTER_FILTER_ADDON", "addon", addonValues),
      class = filterOption(2, "CENTER_FILTER_CLASS", "class", classValues),
      version = filterOption(3, "CENTER_FILTER_VERSION", "version", function()
        return { [CURRENT] = L.CENTER_VERSION_CURRENT, [ALL] = L.CENTER_VERSION_ALL }
      end),
      copy = {
        type = "execute", order = 4, name = function()
          return L.CENTER_COPY_ALL
        end,
        func = function()
          Center.copy(Center.copyAllText())
        end,
      },
      clear = {
        type = "execute", order = 5, name = function()
          return L.CENTER_CLEAR
        end,
        func = function()
          api:Confirm(L.CENTER_CLEAR_CONFIRM, function()
            Problems.clear()
            Center.changed()
          end)
        end,
      },
    },
  }

  for _, entry in ipairs(Center.entries()) do
    local group = groups[entry.addon]

    if not group then
      group = { type = "group", inline = true, order = 2 + #order + 1, name = entry.addon, args = {} }
      groups[entry.addon] = group
      sizes[entry.addon] = 0
      order[#order + 1] = entry.addon
      args["addon_" .. entry.addon] = group
    end

    local count = sizes[entry.addon] + 1

    sizes[entry.addon] = count
    group.args["entry_" .. count] = row(entry, count)
  end

  if #order == 0 then
    args.empty = { type = "description", order = 3, name = function()
      return L.CENTER_EMPTY
    end }
  end

  built, dirty = true, false
end

function Center.refresh()
  if EbonAPI.Window then
    EbonAPI.Window.refresh()
  end
end

local function onPage()
  local Window = EbonAPI.Window

  if not Window or not Window.selected then
    return false
  end

  local owner, key = Window.selected()

  return owner == "EbonAPI" and key == PAGE
end

function Center.ensure()
  if (dirty or not built) and onPage() then
    Center.rebuild()
  end
end

function Center.changed()
  if not built then
    return
  end

  local Window = EbonAPI.Window

  if Window and Window.isShown() and onPage() then
    Center.rebuild()
    Center.refresh()
  else
    dirty = true
  end
end

EbonAPI:On("PROBLEM", Center.changed)
EbonAPI:On("PROBLEM_CLOSED", Center.changed)
function Center.onOpen(_, addon, key)
  Center.request(addon, key)
  Center.rebuild()

  if EbonAPI.Window then
    EbonAPI.Window.open("EbonAPI", PAGE)
  end
end

function Center.request(addon, key)
  Center.details = false

  if key then
    Center.current = { addon = addon, key = key }
  else
    Center.current = nil
    Center.filter.addon = addon or ALL
  end
end

if Problems.opened then
  Center.request(Problems.opened.addon, Problems.opened.key)
end

EbonAPI:On("PROBLEM_OPEN", Center.onOpen)
