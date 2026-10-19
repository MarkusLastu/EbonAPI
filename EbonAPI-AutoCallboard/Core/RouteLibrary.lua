local Core = AutoCallboardCore or {}
AutoCallboardCore = Core

local type, tonumber, tostring, pairs, ipairs = type, tonumber, tostring, pairs, ipairs
local string, table, math = string, table, math

local RT = AutoCallboardRuntime

local function Problem(name, facts, cause)
  return RT.api:Problem(name, facts, cause)
end

local function Sample(value)
  return string.sub(tostring(value), 1, 60)
end

Core.ROUTE_LIBRARY_TTL_DAYS = 180
Core.ROUTE_LIBRARY_BUCKETS = 16
Core.MAX_LIBRARY_ENTRIES = 10000

local FACTIONS = { Horde = "H", Alliance = "A" }
local FACTION_CODES = { H = "Horde", A = "Alliance" }
local DIGEST_MOD = 281474976710656

local shelf = setmetatable({}, { __mode = "k" })

local function Shelf(entries)
  if type(entries) ~= "table" then
    return nil
  end

  local slot = shelf[entries]

  if not slot then
    slot = {}
    shelf[entries] = slot
  end

  return slot
end

local function Disturb(entries, total)
  local slot = Shelf(entries)

  if not slot then
    return
  end

  slot.total = total
  slot.counts = nil
  slot.digests = nil
  slot.buckets = nil
end

function Core.dayNumber(year, month, day)
  year, month, day = tonumber(year), tonumber(month), tonumber(day)

  if not year or not month or not day or year < 1 or month < 1 or month > 12 or day < 1 or day > 31 then
    return nil
  end

  if month <= 2 then
    year = year - 1
  end

  local era = math.floor(year / 400)
  local yearOfEra = year - era * 400
  local shifted = (month + 9) % 12
  local dayOfYear = math.floor((153 * shifted + 2) / 5) + day - 1
  local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear

  return era * 146097 + dayOfEra - 719468
end

function Core.copyLibraryEntry(entry)
  if type(entry) ~= "table" or not Core.isRouteCategory(entry.category) then
    return nil
  end

  local steps = tonumber(entry.steps) or 0
  local day = tonumber(entry.day) or 0

  return {
    category = tonumber(entry.category),
    name = Core.sanitizeSelectionName(entry.name, ""),
    faction = FACTIONS[entry.faction] and entry.faction or nil,
    steps = math.max(0, math.min(Core.MAX_ROUTE_STEPS, math.floor(steps))),
    day = math.max(0, math.floor(day)),
  }
end

function Core.copyRouteLibrary(library)
  local copy = { entries = {} }
  local entries = type(library) == "table" and library.entries
  local count, before = 0, 0

  if type(entries) == "table" then
    for hash, entry in pairs(entries) do
      local cleanHash = Core.sanitizeRouteHash(hash)
      local cleanEntry = cleanHash and Core.copyLibraryEntry(entry)

      before = before + 1

      if cleanEntry and count < Core.MAX_LIBRARY_ENTRIES then
        copy.entries[cleanHash] = cleanEntry
        count = count + 1
      end
    end
  end

  if count < before then
    RT.api:Repaired("LIBRARY.REPAIRED", { field = "entries", before = before, after = count })
  end

  Shelf(copy.entries).total = count

  return copy
end

function Core.libraryEntryFromRoute(route, day)
  return Core.copyLibraryEntry({
    category = route and route.category,
    name = route and route.name,
    faction = Core.routeFaction(route),
    steps = route and route.steps and #(route.steps) or 0,
    day = day,
  })
end

local function Expired(entry, today)
  return today ~= nil and entry.day ~= nil and today - entry.day > Core.ROUTE_LIBRARY_TTL_DAYS
end

local function CountEntries(entries)
  local slot = Shelf(entries)

  if slot and slot.total then
    return slot.total
  end

  local count = 0

  for _ in pairs(entries) do
    count = count + 1
  end

  if slot then
    slot.total = count
  end

  return count
end

local function MergeInto(library, hash, entry, today, count)
  local rawHash, rawEntry = hash, entry
  hash = Core.sanitizeRouteHash(hash)
  entry = Core.copyLibraryEntry(entry)

  if not hash then
    RT.api:Reject("LIBRARY.REJECTED", { reason = "hash", sample = Sample(rawHash) })

    return nil, count
  end

  if not entry then
    RT.api:Reject("LIBRARY.REJECTED", { reason = "entry", sample = Sample(rawHash) .. " " .. Sample(rawEntry) })

    return nil, count
  end

  if type(library) ~= "table" or Expired(entry, today) then
    return nil, count
  end

  if today and entry.day > today then
    entry.day = today
  end

  library.entries = library.entries or {}

  local existing = library.entries[hash]

  if existing then
    if entry.day > existing.day then
      existing.day = entry.day
      return "refreshed", count
    end

    return nil, count
  end

  count = count or CountEntries(library.entries)

  if count >= Core.MAX_LIBRARY_ENTRIES then
    return nil, count, Problem("LIBRARY.FULL", { entries = count, limit = Core.MAX_LIBRARY_ENTRIES })
  end

  library.entries[hash] = entry
  Disturb(library.entries, count + 1)

  return "added", count + 1
end

function Core.mergeLibraryEntry(library, hash, entry, today)
  local result, _, problem = MergeInto(library, hash, entry, today)

  if problem then
    RT.api:Report(problem)
  end

  return result
end

function Core.mergeLibraryEntries(library, items, today)
  local changed, count, full = 0, nil, nil

  for _, item in ipairs(items or {}) do
    local result, problem

    result, count, problem = MergeInto(library, item.hash, item.entry, today, count)
    full = full or problem

    if result then
      changed = changed + 1
    end
  end

  if full then
    RT.api:Report(full)
  end

  return changed
end

function Core.purgeRouteLibrary(library, today, held)
  local removed = 0

  if type(library) ~= "table" or type(library.entries) ~= "table" or not today then
    return removed
  end

  local kept = 0

  for hash, entry in pairs(library.entries) do
    if (held and held[hash]) or entry.day > today then
      entry.day = today
      kept = kept + 1
    elseif Expired(entry, today) then
      library.entries[hash] = nil
      removed = removed + 1
    else
      kept = kept + 1
    end
  end

  Disturb(library.entries, kept)

  return removed
end

function Core.libraryBucket(hash)
  local digit = Core.ROUTE_CODE_DIGIT[string.sub(tostring(hash), 1, 1)] or 0

  return digit % Core.ROUTE_LIBRARY_BUCKETS
end

local function DigestChars(value, count)
  local alphabet = Core.ROUTE_CODE_ALPHABET
  local out = {}

  for i = 1, count do
    local digit = value % 64
    out[i] = string.sub(alphabet, digit + 1, digit + 1)
    value = (value - digit) / 64
  end

  return table.concat(out)
end

local function SumDigests(library, slotOf, count)
  local first, second = {}, {}

  for slot = 1, count do
    first[slot], second[slot] = 0, 0
  end

  for hash, entry in pairs(type(library) == "table" and library.entries or {}) do
    local slot = slotOf(hash, entry)

    if slot then
      local a, b = Core.routeHashParts(hash)
      first[slot] = (first[slot] + (a or 0)) % DIGEST_MOD
      second[slot] = (second[slot] + (b or 0)) % DIGEST_MOD
    end
  end

  local digests = {}

  for slot = 1, count do
    digests[slot] = DigestChars(first[slot] % 16777216, 4) .. DigestChars(second[slot] % 16777216, 4)
  end

  return digests
end

function Core.libraryDigests(library)
  local slot = Shelf(type(library) == "table" and library.entries)

  if slot and slot.digests then
    return slot.digests
  end

  local digests = SumDigests(library, function(_, entry)
    return entry.category
  end, Core.routeCategoryCount())

  if slot then
    slot.digests = digests
  end

  return digests
end

function Core.libraryBucketDigests(library, category)
  local slot = Shelf(type(library) == "table" and library.entries)

  if slot then
    slot.buckets = slot.buckets or {}

    if slot.buckets[category] then
      return slot.buckets[category]
    end
  end

  local digests = SumDigests(library, function(hash, entry)
    if entry.category == category then
      return Core.libraryBucket(hash) + 1
    end
  end, Core.ROUTE_LIBRARY_BUCKETS)

  if slot then
    slot.buckets[category] = digests
  end

  return digests
end

function Core.libraryEntriesIn(library, category, buckets)
  local list = {}

  for hash, entry in pairs(type(library) == "table" and library.entries or {}) do
    if entry.category == category and (buckets == nil or buckets[Core.libraryBucket(hash)]) then
      list[#(list) + 1] = { hash = hash, entry = entry, key = string.lower(entry.name) }
    end
  end

  table.sort(list, function(a, b)
    if a.key ~= b.key then
      return a.key < b.key
    end

    return a.hash < b.hash
  end)

  return list
end

function Core.libraryCounts(library)
  local slot = Shelf(type(library) == "table" and library.entries)

  if slot and slot.counts then
    return slot.counts
  end

  local counts = {}

  for category = 1, Core.routeCategoryCount() do
    counts[category] = 0
  end

  for _, entry in pairs(type(library) == "table" and library.entries or {}) do
    if counts[entry.category] then
      counts[entry.category] = counts[entry.category] + 1
    end
  end

  if slot then
    slot.counts = counts
  end

  return counts
end

function Core.libraryCount(library, category)
  local entries = type(library) == "table" and library.entries

  if category == nil then
    return entries and CountEntries(entries) or 0
  end

  if Core.isRouteCategory(category) then
    return Core.libraryCounts(library)[category] or 0
  end

  local count = 0

  for _, entry in pairs(entries or {}) do
    if entry.category == category then
      count = count + 1
    end
  end

  return count
end

local function Escape(text)
  return (string.gsub(tostring(text or ""), "[%%;,:|\r\n]", function(char)
    return string.format("%%%02X", string.byte(char))
  end))
end

local function Unescape(text)
  return (string.gsub(tostring(text or ""), "%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

function Core.serializeLibraryEntry(hash, entry)
  local rawHash = hash
  entry = Core.copyLibraryEntry(entry)
  hash = Core.sanitizeRouteHash(hash)

  if not hash then
    RT.api:Reject("LIBRARY.REJECTED", { reason = "hash", sample = Sample(rawHash) })
    return nil
  end

  if not entry then
    RT.api:Reject("LIBRARY.REJECTED", { reason = "entry", sample = Sample(rawHash) })
    return nil
  end

  return table.concat({
    hash,
    tostring(entry.category),
    FACTIONS[entry.faction] or "-",
    tostring(entry.steps),
    tostring(entry.day),
    Escape(entry.name),
  }, ",")
end

function Core.parseLibraryEntry(text)
  if type(text) ~= "string" then
    RT.api:Reject("LIBRARY.REJECTED", { reason = "format", sample = Sample(text) })
    return nil
  end

  local hash, category, faction, steps, day, name = string.match(text, "^([^,]+),(%d+),([HA%-]),(%d+),(%d+),(.*)$")

  if not hash then
    RT.api:Reject("LIBRARY.REJECTED", { reason = "format", sample = Sample(text) })
    return nil
  end

  hash = Core.sanitizeRouteHash(hash)

  if not hash then
    RT.api:Reject("LIBRARY.REJECTED", { reason = "hash", sample = Sample(text) })
    return nil
  end

  local entry = Core.copyLibraryEntry({
    category = category,
    faction = FACTION_CODES[faction],
    steps = steps,
    day = day,
    name = Unescape(name),
  })

  if not entry then
    RT.api:Reject("LIBRARY.REJECTED", { reason = "category", sample = Sample(text) })
    return nil
  end

  return hash, entry
end
