EbonAPI = EbonAPI or {}
EbonAPI.SavesData = {}

-- Pure logic of the "saves" widget, without any frame: model check, text folding, search, natural order,
-- filter / sort / groups / budget cursor (arrange), neighbour for the keyboard, short texts.

local SavesData = EbonAPI.SavesData

local type, pairs, ipairs, tostring, tonumber = type, pairs, ipairs, tostring, tonumber
local floor = math.floor
local format, gsub, lower, sub, find, len = string.format, string.gsub, string.lower, string.sub, string.find,
  string.len
local sort = table.sort

local STATES = { active = true, ready = true, step = true, short = true, blocked = true, error = true }
local SORTS = { name = true, pct = true, cost = true }

-- Latin accents (two-byte UTF-8 sequences starting with 0xC3) folded to plain letters.
local FOLD = {}

for letters, base in pairs({
  ["\195\128\195\129\195\130\195\131\195\132\195\133\195\160\195\161\195\162\195\163\195\164\195\165"] = "a",
  ["\195\135\195\167"] = "c",
  ["\195\136\195\137\195\138\195\139\195\168\195\169\195\170\195\171"] = "e",
  ["\195\140\195\141\195\142\195\143\195\172\195\173\195\174\195\175"] = "i",
  ["\195\145\195\177"] = "n",
  ["\195\146\195\147\195\148\195\149\195\150\195\152\195\178\195\179\195\180\195\181\195\182\195\184"] = "o",
  ["\195\153\195\154\195\155\195\156\195\185\195\186\195\187\195\188"] = "u",
  ["\195\157\195\189\195\191"] = "y",
}) do
  for index = 1, len(letters), 2 do
    FOLD[sub(letters, index, index + 1)] = base
  end
end

FOLD["\195\134"], FOLD["\195\166"], FOLD["\195\159"] = "ae", "ae", "ss"

local function lowerAscii(letter)
  return lower(letter)
end

-- Lower case and accents folded, by replacing UTF-8 bytes (no locale dependency).
function SavesData.fold(text)
  text = gsub(tostring(text or ""), "\195[\128-\191]", FOLD)
  text = gsub(text, "\197[\146\147]", "oe")
  text = gsub(text, "[A-Z]", lowerAscii)

  return text
end

local fold = SavesData.fold

-- Every word of the query must be a substring of "name group", accents and case ignored.
function SavesData.matches(item, groupName, query)
  query = fold(query or "")

  if not find(query, "%S") then
    return true
  end

  local hay = fold((item.name or "") .. " " .. (groupName or ""))

  for word in query:gmatch("%S+") do
    if not find(hay, word, 1, true) then
      return false
    end
  end

  return true
end

-- Splits a text into chunks of digits and of non digits.
local function chunks(text)
  local list = {}
  local position, size = 1, len(text)

  while position <= size do
    local digits = find(text, "^%d", position) ~= nil
    local first, last = find(text, digits and "^%d+" or "^%D+", position)

    list[#list + 1] = { digits, sub(text, first, last) }
    position = last + 1
  end

  return list
end

-- Natural order, case and accents ignored: -1, 0 or 1.
function SavesData.compareNames(a, b)
  local left, right = chunks(fold(a)), chunks(fold(b))

  for index = 1, #left do
    local x, y = left[index], right[index]

    if not y then
      return 1
    end

    if x[1] and y[1] then
      local p, q = x[2]:gsub("^0+(%d)", "%1"), y[2]:gsub("^0+(%d)", "%1")

      if len(p) ~= len(q) then
        return len(p) < len(q) and -1 or 1
      elseif p ~= q then
        return p < q and -1 or 1
      end
    elseif x[2] ~= y[2] then
      if x[1] ~= y[1] then
        return x[1] and -1 or 1
      end

      return x[2] < y[2] and -1 or 1
    end
  end

  return #right > #left and -1 or 0
end

-- "20,3 M", "111 k", "950".
function SavesData.compact(n)
  n = floor((tonumber(n) or 0) + 0.5)

  if n >= 1000000 then
    local text = format("%.1f", n / 1000000)

    text = gsub(text, "%.0$", "")
    text = gsub(text, "%.", ",")

    return text .. " M"
  elseif n >= 1000 then
    return floor(n / 1000 + 0.5) .. " k"
  end

  return tostring(n)
end

-- Words longer than 7 characters are cut to 6 followed by an ellipsis (UTF-8 safe).
function SavesData.shortName(name)
  name = tostring(name or "")

  return (gsub(name, "%S+", function(word)
    local starts = {}

    for index in word:gmatch("()[%z\1-\127\194-\244]") do
      starts[#starts + 1] = index
    end

    if #starts <= 7 then
      return word
    end

    return sub(word, 1, starts[7] - 1) .. "\226\128\166"
  end))
end

function SavesData.counter(shown, total)
  return format("%d/%d", shown or 0, total or 0)
end

-- Returns true, or false and a message.
function SavesData.check(model)
  if type(model) ~= "table" or type(model.groups) ~= "table" then
    return false, "model.groups must be a table"
  end

  local seen = {}

  for g, group in ipairs(model.groups) do
    if type(group) ~= "table" or type(group.items) ~= "table" then
      return false, format("group %d: items must be a table", g)
    end

    for _, item in ipairs(group.items) do
      local id = item.id

      if id == nil or id == "" then
        return false, format("group %d: an item has no id", g)
      elseif seen[id] then
        return false, format("duplicate item id %s", tostring(id))
      elseif not STATES[item.state] then
        return false, format("item %s: unknown state %s", tostring(id), tostring(item.state))
      end

      seen[id] = true

      for _, field in ipairs({ "owned", "now" }) do
        local value = item[field]

        if (value ~= nil or field == "owned")
            and (type(value) ~= "number" or value ~= value or value < 0 or value > 1) then
          return false, format("item %s: %s must be a number from 0 to 1, got %s", tostring(id), field, tostring(value))
        end
      end
    end
  end

  return true
end

-- Filter, sort, groups, fold and budget cursor. See the contract, section 7.
function SavesData.arrange(model, state)
  state = state or {}

  local query = state.query or ""
  local searching = find(fold(query), "%S") ~= nil
  local mode = SORTS[state.sort] and state.sort or "name"
  local list, total = {}, 0

  for _, group in ipairs(model.groups or {}) do
    for _, item in ipairs(group.items or {}) do
      total = total + 1

      if SavesData.matches(item, group.name, query) then
        list[#list + 1] = { item = item, group = group, rank = total }
      end
    end
  end

  local compare = SavesData.compareNames

  sort(list, function(a, b)
    local x, y = a.item, b.item

    if mode == "pct" then
      local p, q = x.owned or 0, y.owned or 0

      if p ~= q then
        return p > q
      end
    elseif mode == "cost" then
      local p, q = x.need or 0, y.need or 0

      if p ~= q then
        return p < q
      end
    end

    local order = compare(x.name or "", y.name or "")

    if order ~= 0 then
      return order < 0
    end

    return a.rank < b.rank
  end)

  local blocks = {}

  if state.grouped then
    local byGroup = {}

    for _, group in ipairs(model.groups or {}) do
      local block = { group = { id = group.id, name = group.name }, items = {}, shut = false }

      byGroup[group] = block
      blocks[#blocks + 1] = block
    end

    for _, entry in ipairs(list) do
      local items = byGroup[entry.group].items

      items[#items + 1] = entry.item
    end

    local kept = {}

    for _, block in ipairs(blocks) do
      if #block.items > 0 or (not searching and block.group.id ~= "") then
        block.shut = (not searching and state.fold and state.fold[block.group.id]) and true or false
        kept[#kept + 1] = block
      end
    end

    blocks = kept
  else
    local items = {}

    for _, entry in ipairs(list) do
      items[#items + 1] = entry.item
    end

    blocks[1] = { items = items, shut = false }
  end

  local ids = {}

  for _, block in ipairs(blocks) do
    if not block.shut then
      for _, item in ipairs(block.items) do
        ids[#ids + 1] = item.id
      end
    end
  end

  local cursorBefore

  if not state.grouped and mode == "cost" and model.balance ~= nil and #list > 0 then
    cursorBefore = "end"

    for _, entry in ipairs(list) do
      if (entry.item.need or 0) > model.balance then
        cursorBefore = entry.item.id
        break
      end
    end
  end

  return { blocks = blocks, ids = ids, cursorBefore = cursorBefore, count = #list, total = total }
end

-- The id next to `selected` in `ids`, bounded (no wrap). Nothing selected: the first (delta >= 0) or the last.
function SavesData.neighbor(ids, selected, delta)
  local size = #ids

  if size == 0 then
    return nil
  end

  local at

  for index = 1, size do
    if ids[index] == selected then
      at = index
      break
    end
  end

  if not at then
    return (delta or 0) >= 0 and ids[1] or ids[size]
  end

  local target = at + (delta or 0)

  return ids[target < 1 and 1 or target > size and size or target]
end
