local L = AutoCallboardLocale
local RT = AutoCallboardRuntime

local SECTIONS = { "about", "callboard", "routes", "builds", "display" }
local TAB_KEYS = {
  "HELP_TAB_ABOUT",
  "HELP_TAB_CALLBOARD",
  "HELP_TAB_ROUTES",
  "HELP_TAB_BUILDS",
  "HELP_TAB_DISPLAY",
}

local MARKERS = { ["# "] = "heading", ["! "] = "note" }

local LINKS = {
  update = function()
    return RT.updateUrl
  end,
  license = function()
    return RT.licenseUrl
  end,
}

local DYNAMIC = {
  targetName = function()
    return RT.state and RT.state.targetName
  end,
  version = function()
    return RT.GetAddonVersion()
  end,
  latest = function()
    return (RT.GetAvailableUpdate())
  end,
  ebonapiGeneral = function()
    return EbonAPI.Locale.get("EbonAPI").UI_GENERAL
  end,
  ebonapiAppearance = function()
    return EbonAPI.Locale.get("EbonAPI").UI_APPEARANCE
  end,
}

local function Resolve(text, plain)
  local missing = false
  local resolved = string.gsub(text, "{([%w_]+)}", function(key)
    local dynamic = DYNAMIC[key]
    local value

    if dynamic then
      value = dynamic()
    else
      value = L[key]
    end

    if value == nil or value == "" then
      if dynamic then missing = true end
      return "{" .. key .. "}"
    end

    value = tostring(value)

    if plain then
      return value
    end

    return EbonAPI.Palette.code("heading") .. value .. "|r"
    end)

  return resolved, missing
end

local function ParseLine(line)
  local target, rest = string.match(line, "^@(%a+) (.+)$")

  if target then
    return "link", rest, target
  end

  target, rest = string.match(line, "^%[(%a+)%] (.+)$")

  if target then
    return "button", rest, target
  end

  local style = MARKERS[string.sub(line, 1, 2)]

  if style then
    return style, string.sub(line, 3)
  end

  return "body", line
end

local function LineOptions(args, order, line)
  local style, source, target = ParseLine(line)
  local plain = style ~= "body" and style ~= "note"

  local function Text()
    return (Resolve(source, plain))
  end

  local function Missing()
    local _, missing = Resolve(source, plain)
    return missing
  end

  if not target then
    args["line" .. order] = {
      type = style == "heading" and "header" or "description",
      order = order,
      name = Text,
      hidden = Missing,
    }
    return
  end

  local url = LINKS[target] or function() return nil end

  args["line" .. order] = {
    type = "execute",
    order = order,
    name = Text,
    desc = function() return RT.LinkTip() end,
    func = function() RT.OpenLink(url()) end,
    hidden = function() return Missing() or not (url() and RT.LinkMethod()) end,
  }
  args["text" .. order] = {
    type = "description",
    order = order,
    name = function()
      local address = url()
      return address and (Text() .. " " .. address) or Text()
    end,
    hidden = function() return Missing() or (url() and RT.LinkMethod()) and true or false end,
  }
end

function RT.HelpOptions()
  local sections = L.HELP_SECTIONS or {}
  local args = {}

  for index, name in ipairs(SECTIONS) do
    local lines = {}

    for order, line in ipairs(sections[name] or {}) do
      if line ~= "" then
        LineOptions(lines, order, line)
      end
    end

    args[name] = {
      type = "group",
      inline = true,
      order = index,
      name = function() return L[TAB_KEYS[index]] end,
      args = lines,
    }
  end

  return args
end

function RT.ShowAddonHelp()
  RT.ShowSettings("help")
end

function RT.HelpSections()
  return SECTIONS
end
