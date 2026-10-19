EbonAPI = EbonAPI or {}
EbonAPI.Alerts = {}

local Alerts = EbonAPI.Alerts
local Skins = EbonAPI.Skins
local Bricks = EbonAPI.Bricks
local Bus = EbonAPI.Bus
local Kit = EbonAPI.Kit
local Handle = EbonAPI.Handle
local Problems = EbonAPI.Problems
local Lib = EbonAPI.Lib
local L = EbonAPI.L

local ipairs, pcall, tostring, type, pairs = ipairs, pcall, tostring, type, pairs
local max, floor = math.max, math.floor
local format, sub = string.format, string.sub
local sort = table.sort

local S = Skins.value

local MAX_HELD = 20
local MAX_QUIET_MEMORY = 64
local ELLIPSIS = "..."

local pool = {}
local quiet = {}
local memory = {}
local memoryCount = 0
local held = {}
local waiting = false
local arrivals = 0

local function report(err)
  Lib.report(err, "EbonAPI")
end

local function stack()
  local y = S("kit.toast.top")

  for _, alert in ipairs(Alerts.shown()) do
    alert:ClearAllPoints()
    alert:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -S("kit.padding"), -y)
    y = y + alert:GetHeight() + S("kit.spacing")
  end
end

local function dismiss(alert)
  alert:Hide()
  alert:SetScript("OnUpdate", nil)

  if alert.kind == "quiet" and quiet[alert.addon] == alert then
    quiet[alert.addon] = nil
  end

  alert.problem = nil
  stack()
end

local function copy(alert)
  local problem = alert.problem

  if not problem then
    return
  end

  local text = Problems.copyText(Problems.entry(problem))

  local clip = rawget(_G, "CopyToClipboard")

  if type(clip) == "function" then
    clip(text)
  else
    Handle.CopyBox({ addonName = "EbonAPI" }, text, problem.addon)
  end
end

local function act(button, fn)
  button.onClick = function(self)
    local alert = self:GetParent()
    local ok, err = pcall(fn, alert)

    if not ok then
      report(err)
    end

    dismiss(alert)
  end
end

local function build()
  local alert = CreateFrame("Frame", nil, UIParent)

  alert:SetFrameStrata("FULLSCREEN_DIALOG")
  Bricks.frame(alert, "small", "bg", "danger")
  alert.icon = alert:CreateTexture(nil, "ARTWORK")
  Kit.trim(alert.icon)
  alert.title = Bricks.text(alert, "small", "heading")
  alert.title:SetJustifyH("LEFT")
  alert.text = Bricks.text(alert, "normal", "text")
  alert.text:SetJustifyH("LEFT")
  alert.view = Bricks.create("button", alert)
  alert.copy = Bricks.create("button", alert)
  alert.close = Bricks.create("button", alert)
  alert.view:SetLabel(L.ALERT_VIEW)
  alert.view:Fit(max(alert.view:TextWidth(), 0))
  alert.copy:SetLabel(L.ALERT_COPY)
  alert.copy:Fit(max(alert.copy:TextWidth(), 0))
  alert.close:SetLabel("x")
  alert.close:Fit(S("widgets.button.height"))
  act(alert.view, function(self)
    Problems.open(self.problem.addon, Problems.keyOf(self.problem))
  end)
  act(alert.copy, copy)
  act(alert.close, function() end)
  alert:Hide()
  pool[#pool + 1] = alert

  return alert
end

local function frame()
  for _, alert in ipairs(pool) do
    if not alert:IsShown() then
      return alert
    end
  end

  return build()
end

local function fit(alert, text, width)
  local line = alert.title:GetStringHeight() or 0
  local field = alert.text

  field:SetWidth(width)
  field:SetText(text)

  if line <= 0 then
    return
  end

  local guard = 0

  while (field:GetStringHeight() or 0) > line * 2 + 1 and #text > 1 and guard < 40 do
    text = sub(text, 1, floor(#text * 0.85)) .. ELLIPSIS
    field:SetText(text)
    guard = guard + 1
  end
end

local function expire(alert)
  local left = (alert.expires or 0) - GetTime()
  local fade = S("kit.toast.fade")

  if left <= 0 then
    dismiss(alert)
  elseif left < fade then
    alert:SetAlpha(left / fade)
  end
end

local function render(alert)
  local problem = alert.problem
  local pad = S("kit.padding")
  local gap = S("kit.gap")
  local iconSize = S("kit.toast.icon")
  local width = S("kit.problem.alert.width")
  local left = pad
  local icon = EbonAPI:AddonIcon(problem.addon)
  local quietKind = alert.kind == "quiet"

  Bricks.paint(alert, "SetBackdropBorderColor", quietKind and "caution" or "danger")

  if icon then
    alert.icon:SetTexture(icon)
    alert.icon:SetWidth(iconSize)
    alert.icon:SetHeight(iconSize)
    alert.icon:ClearAllPoints()
    alert.icon:SetPoint("TOPLEFT", alert, "TOPLEFT", pad, -pad)
    alert.icon:Show()
    left = pad * 2 + iconSize
  else
    alert.icon:Hide()
  end

  local closeSize = alert.close:GetWidth() or 0
  local title = problem.addon

  if alert.n > 1 then
    title = title .. " \195\151" .. alert.n
  end

  alert.title:SetWidth(width - left - pad * 2 - closeSize)
  alert.title:SetText(title)
  alert.title:ClearAllPoints()
  alert.title:SetPoint("TOPLEFT", alert, "TOPLEFT", left, -pad)
  alert.close:ClearAllPoints()
  alert.close:SetPoint("TOPRIGHT", alert, "TOPRIGHT", -pad, -pad)
  alert.text:ClearAllPoints()
  alert.text:SetPoint("TOPLEFT", alert.title, "BOTTOMLEFT", 0, -gap)

  local text = Problems.text(problem)

  if quietKind and alert.n > 1 then
    text = format(L.ALERT_INTERNAL_ERRORS, alert.n)
  end

  fit(alert, text, width - left - pad)
  alert.view:ClearAllPoints()
  alert.view:SetPoint("TOPLEFT", alert.text, "BOTTOMLEFT", 0, -gap)
  alert.copy:ClearAllPoints()
  alert.copy:SetPoint("LEFT", alert.view, "RIGHT", gap, 0)

  if quietKind then
    alert.copy:Hide()
  else
    alert.copy:Show()
  end

  alert:SetWidth(width)

  local body = (alert.title:GetStringHeight() or 0) + gap + (alert.text:GetStringHeight() or 0)

  alert:SetHeight(pad * 2 + max(iconSize, body) + gap + (alert.view:GetHeight() or 0))
end

local function open(problem, kind)
  local alert = frame()

  arrivals = arrivals + 1
  alert.kind = kind
  alert.addon = problem.addon
  alert.ekey = Problems.keyOf(problem)
  alert.problem = problem
  alert.n = 1
  alert.arrival = arrivals
  alert:SetAlpha(1)

  if kind == "quiet" then
    alert.expires = GetTime() + S("kit.problem.discreet.duration")
    alert:SetScript("OnUpdate", expire)
    quiet[problem.addon] = alert
  end

  render(alert)
  alert:Show()
  stack()

  return alert
end

local function again(alert, problem)
  alert.problem = problem
  alert.n = alert.n + 1

  if alert.kind == "quiet" then
    alert.expires = GetTime() + S("kit.problem.discreet.duration")
    alert:SetAlpha(1)
  end

  render(alert)
  stack()
end

local function block(problem)
  local ekey = Problems.keyOf(problem)
  local oldest, count = nil, 0

  for _, alert in ipairs(pool) do
    if alert:IsShown() and alert.kind == "block" then
      if alert.ekey == ekey then
        return again(alert, problem)
      end

      count = count + 1

      if not oldest or alert.arrival < oldest.arrival then
        oldest = alert
      end
    end
  end

  if count >= S("kit.problem.alert.max") then
    dismiss(oldest)
  end

  open(problem, "block")
end

local function forget(now, window)
  for key, at in pairs(memory) do
    if now - at >= window then
      memory[key] = nil
      memoryCount = memoryCount - 1
    end
  end
end

local function soft(problem)
  local now = GetTime()
  local ekey = Problems.keyOf(problem)
  local window = S("kit.problem.discreet.quiet")
  local shown = quiet[problem.addon]

  if shown then
    if memory[ekey] == nil then
      memoryCount = memoryCount + 1
    end

    memory[ekey] = now

    return again(shown, problem)
  end

  local last = memory[ekey]

  if last and now - last < window then
    return
  end

  if last == nil then
    if memoryCount >= MAX_QUIET_MEMORY then
      forget(now, window)
    end

    memoryCount = memoryCount + 1
  end

  memory[ekey] = now
  open(problem, "quiet")
end

local function deliver(problem, kind)
  if kind == "block" then
    block(problem)
  else
    soft(problem)
  end
end

local flush

local function wait()
  if not waiting then
    waiting = true
    Bus.on("PLAYER_REGEN_ENABLED", flush, Alerts)
  end
end

flush = function()
  if InCombatLockdown and InCombatLockdown() then
    return
  end

  waiting = false
  Bus.off("PLAYER_REGEN_ENABLED", flush, Alerts)

  local list = held

  held = {}

  for i = 1, #list, 2 do
    local ok, err = pcall(deliver, list[i], list[i + 1])

    if not ok then
      report(err)
    end
  end
end

function Alerts.show(problem, kind)
  if kind == "quiet" and InCombatLockdown and InCombatLockdown() then
    if #held < MAX_HELD * 2 then
      held[#held + 1], held[#held + 2] = problem, kind
      wait()
    end

    return
  end

  deliver(problem, kind)
end

function Alerts.shown()
  local list = {}

  for _, alert in ipairs(pool) do
    if alert:IsShown() then
      list[#list + 1] = alert
    end
  end

  sort(list, function(a, b)
    return a.arrival < b.arrival
  end)

  return list
end

local ready = false

function Alerts.ready()
  return ready
end

local function flushEarly()
  Bus.offCore("PLAYER_LOGIN", flushEarly)
  ready = true
  Problems.flushEarly()
end

Bus.onCore("PLAYER_LOGIN", flushEarly)
