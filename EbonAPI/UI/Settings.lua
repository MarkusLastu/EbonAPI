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
local L = EbonAPI.L

local ipairs = ipairs
local format, concat = string.format, table.concat

local ALL = "*"
local NAME = EbonAPI.name

local shown = nil
local perfTarget = ALL
local traceKind = ALL
local debugTarget = NAME

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
    local version = GetAddOnMetadata and GetAddOnMetadata(name, "Version")
    local latest = Version.available(name)
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
          type = "description", order = 5, fontSize = "medium",
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
  local version = metadata(name, "Version")

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
