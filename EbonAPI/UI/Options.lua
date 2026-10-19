EbonAPI = EbonAPI or {}
EbonAPI.Options = {}

local Options = EbonAPI.Options
local Lib = EbonAPI.Lib
local Handle = EbonAPI.Handle

local type, pairs, ipairs, tostring, error, pcall = type, pairs, ipairs, tostring, error, pcall
local format, lower, find, concat = string.format, string.lower, string.find, table.concat
local sort = table.sort

local TYPES = {
  color = true, description = true, execute = true, group = true, header = true,
  input = true, range = true, select = true, toggle = true,
}

local TYPE_LIST = "color, description, execute, group, header, input, range, select, toggle"

local VALUED = { color = true, input = true, range = true, select = true, toggle = true }

local WIDTHS = { half = true, normal = true, double = true, full = true }

local INHERITED = { handler = true, get = true, set = true, func = true, disabled = true, hidden = true }

local METHODS = { get = true, set = true, func = true, disabled = true, hidden = true, values = true }

local DEFAULT_ORDER = 100

Options.TYPES = TYPES
Options.DEFAULT_ORDER = DEFAULT_ORDER

local trees = {}

local function callable(value)
  local kind = type(value)

  return kind == "function" or kind == "string"
end

local function check(option, path, seen, has)
  local where = path == "" and "the options table" or format('option "%s"', path)

  if type(option) ~= "table" then
    return where .. " must be a table, got " .. type(option)
  end

  if seen[option] then
    return where .. " contains itself"
  end

  local kind = option.type

  if not TYPES[kind] then
    return format('%s has an unknown type "%s" (known: %s)', where, tostring(kind), TYPE_LIST)
  end

  local name = option.name

  if type(name) ~= "string" and type(name) ~= "function" then
    return where .. " needs a name (string or function), got " .. type(name)
  end

  if option.desc ~= nil and type(option.desc) ~= "string" and type(option.desc) ~= "function" then
    return where .. " desc must be a string or a function, got " .. type(option.desc)
  end

  if option.order ~= nil and type(option.order) ~= "number" and type(option.order) ~= "function" then
    return where .. " order must be a number or a function, got " .. type(option.order)
  end

  if option.width ~= nil and not WIDTHS[option.width] and type(option.width) ~= "number" then
    return where .. ' width must be "half", "normal", "double", "full" or a number, got ' .. tostring(option.width)
  end

  if option.handler ~= nil and type(option.handler) ~= "table" then
    return where .. " handler must be a table, got " .. type(option.handler)
  end

  for field in pairs(METHODS) do
    local value = option[field]

    if value ~= nil and not callable(value) then
      local boolean = (field == "disabled" or field == "hidden") and type(value) == "boolean"
      local list = field == "values" and type(value) == "table"

      if not boolean and not list then
        return format("%s %s must be a function or a method name, got %s", where, field, type(value))
      end
    end
  end

  local inherited = {}

  for field in pairs(INHERITED) do
    inherited[field] = has[field] or option[field] ~= nil
  end

  if VALUED[kind] and not (inherited.get and inherited.set) then
    return format("%s (%s) needs get and set, on itself or on a parent group", where, kind)
  end

  if kind == "group" then
    if type(option.args) ~= "table" then
      return where .. " (group) needs an args table"
    end

    seen[option] = true

    for key, child in pairs(option.args) do
      if type(key) ~= "string" then
        return where .. " has a key of type " .. type(key) .. " in args, keys must be strings"
      end

      local problem = check(child, path == "" and key or (path .. "." .. key), seen, inherited)

      if problem then
        return problem
      end
    end

    seen[option] = nil
  elseif kind == "range" then
    if type(option.min) ~= "number" or type(option.max) ~= "number" or option.min >= option.max then
      return where .. " (range) needs numeric min and max, with min below max"
    end

    if option.step ~= nil and (type(option.step) ~= "number" or option.step <= 0) then
      return where .. " (range) step must be a positive number"
    end

    for _, field in ipairs({ "softMin", "softMax" }) do
      if option[field] ~= nil and type(option[field]) ~= "number" then
        return format("%s (range) %s must be a number", where, field)
      end
    end
  elseif kind == "select" then
    if option.values == nil then
      return where .. " (select) needs values (table, function or method name)"
    end

    if option.sorting ~= nil and type(option.sorting) ~= "table" and type(option.sorting) ~= "function" then
      return where .. " (select) sorting must be a table or a function, got " .. type(option.sorting)
    end
  elseif kind == "execute" then
    if not inherited.func then
      return where .. " (execute) needs a func, on itself or on a parent group"
    end
  end

  return nil
end

function Options.check(root)
  if type(root) ~= "table" or root.type ~= "group" then
    return 'the options table must be a group (type = "group")'
  end

  return check(root, "", {}, {})
end

function Options.register(owner, root)
  local problem = Options.check(root)

  if problem then
    return problem
  end

  trees[owner] = root
  EbonAPI:Emit("OPTIONS_CHANGED", owner)

  return nil
end

function Options.tree(owner)
  return trees[owner]
end

function Options.has(owner)
  return trees[owner] ~= nil
end

function Options.owners()
  local list = {}

  for owner in pairs(trees) do
    if owner ~= "EbonAPI" then
      list[#list + 1] = owner
    end
  end

  sort(list, function(a, b)
    return lower(a) < lower(b)
  end)

  if trees.EbonAPI then
    table.insert(list, 1, "EbonAPI")
  end

  return list
end

function Options.node(owner, option, parent, key)
  local path = {}

  if parent then
    for index = 1, #parent.path do
      path[index] = parent.path[index]
    end

    path[#path + 1] = key
  end

  return { owner = owner, option = option, parent = parent, key = key, path = path }
end

function Options.root(owner)
  local root = trees[owner]

  return root and Options.node(owner, root)
end

function Options.child(node, key)
  local args = node.option.args
  local option = args and args[key]

  return option and Options.node(node.owner, option, node, key)
end

local function lookup(node, field)
  if not INHERITED[field] then
    return node.option[field]
  end

  local at = node

  while at do
    local value = at.option[field]

    if value ~= nil then
      return value
    end

    at = at.parent
  end

  return nil
end

function Options.info(node)
  local info = {}

  for index = 1, #node.path do
    info[index] = node.path[index]
  end

  info.options = trees[node.owner]
  info.option = node.option
  info.type = node.option.type
  info.arg = node.option.arg
  info.handler = lookup(node, "handler")
  info.uiType = "dialog"
  info.uiName = node.owner
  info.appName = node.owner

  return info
end

function Options.call(node, field, ...)
  local value = lookup(node, field)

  if type(value) == "function" then
    return value(Options.info(node), ...)
  end

  if type(value) == "string" and METHODS[field] then
    local handler = lookup(node, "handler")
    local method = handler and handler[value]

    if type(method) ~= "function" then
      error(format('EbonAPI: %s: %s: method "%s" not found on its handler',
        node.owner, #node.path > 0 and format('option "%s"', concat(node.path, ".")) or "the options table", value))
    end

    return method(handler, Options.info(node), ...)
  end

  return value
end

local function settle(node, field, ok, ...)
  if ok then
    return ...
  end

  local path = concat(node.path, ".")

  EbonAPI.Kit.fail("EBONAPI.KIT.CALLBACK_FAILED", (...), node.owner,
    { element = path ~= "" and path or node.owner, callback = field, addon = node.owner })
end

local function guarded(node, field)
  return settle(node, field, pcall(Options.call, node, field))
end

function Options.name(node)
  local name = guarded(node, "name")

  return type(name) == "string" and name or tostring(name or "")
end

function Options.desc(node)
  local desc = Options.call(node, "desc")

  return type(desc) == "string" and desc ~= "" and desc or nil
end

local function covered(node, field)
  local at = node

  while at do
    if at.option[field] ~= nil and guarded(at, field) then
      return true
    end

    at = at.parent
  end

  return false
end

function Options.isHidden(node)
  return covered(node, "hidden")
end

function Options.isDisabled(node)
  return covered(node, "disabled")
end

function Options.order(node)
  local order = guarded(node, "order")

  return type(order) == "number" and order or DEFAULT_ORDER
end

function Options.children(node)
  local list = {}
  local args = node.option.args

  if not args then
    return list
  end

  for key, option in pairs(args) do
    local child = Options.node(node.owner, option, node, key)

    if not (option.hidden ~= nil and guarded(child, "hidden")) then
      child.sortOrder = Options.order(child)
      child.sortName = lower(Options.name(child))
      list[#list + 1] = child
    end
  end

  sort(list, function(a, b)
    if a.sortOrder ~= b.sortOrder then
      return a.sortOrder < b.sortOrder
    end

    if a.sortName ~= b.sortName then
      return a.sortName < b.sortName
    end

    return a.key < b.key
  end)

  return list
end

function Options.values(node)
  local values = Options.call(node, "values")
  local list = {}

  if type(values) ~= "table" then
    return list
  end

  local sorting = node.option.sorting

  if type(sorting) == "function" then
    sorting = sorting(Options.info(node))
  end

  local listed = {}

  if type(sorting) == "table" then
    for _, key in ipairs(sorting) do
      if values[key] ~= nil and not listed[key] then
        listed[key] = true
        list[#list + 1] = { key = key, text = tostring(values[key]) }
      end
    end
  end

  local rest = {}

  for key, text in pairs(values) do
    if not listed[key] then
      rest[#rest + 1] = { key = key, text = tostring(text) }
    end
  end

  sort(rest, function(a, b)
    local first, second = lower(a.text), lower(b.text)

    if first ~= second then
      return first < second
    end

    return tostring(a.key) < tostring(b.key)
  end)

  for _, entry in ipairs(rest) do
    list[#list + 1] = entry
  end

  return list
end

function Options.get(node)
  return settle(node, "get", pcall(Options.call, node, "get"))
end

function Options.set(node, ...)
  return settle(node, "set", pcall(Options.call, node, "set", ...))
end

function Options.run(node)
  return settle(node, "func", pcall(Options.call, node, "func"))
end

local function walk(node, needle, found)
  for _, child in ipairs(Options.children(node)) do
    local kind = child.option.type

    if kind == "group" then
      walk(child, needle, found)
    elseif kind ~= "header" and kind ~= "description" then
      if find(lower(Options.name(child)), needle, 1, true) then
        found[#found + 1] = child
      end
    end
  end
end

function Options.search(text)
  local found = {}
  local needle = lower(Lib.trim(text or ""))

  if needle == "" then
    return found
  end

  for _, owner in ipairs(Options.owners()) do
    local ok, err = pcall(walk, Options.root(owner), needle, found)

    if not ok then
      Lib.report(err)
    end
  end

  return found
end

function Handle:Options(options)
  local problem = Options.register(self.addonName, options)

  if problem then
    error("EbonAPI: " .. self.addonName .. ": " .. problem, 2)
  end

  return options
end

function Handle:RefreshOptions()
  EbonAPI:Emit("OPTIONS_CHANGED", self.addonName)
end
