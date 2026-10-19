local _, ns = ...

local CONSUME_DELAY = 0.4
local PICK_TIMEOUT = 8.0
local TICK = 0.1
local SETTLE_WINDOW = 1.0
local CHARGE_PROBE_INTERVAL = 3.0

local HUNT_CYCLE = 0.5
local DEFAULT_BUDGET = 10

local BUTTON_WIDTH = 190
local HUNT_BUTTON_WIDTH = 150
local SLIDER_WIDTH = 180
local RARITY_WIDTH = 28
local BUTTON_GAP = 8
local BUTTON_HEIGHT = 32
local BUTTON_Y = -8

local TOGGLE_X = 0.040
local TOGGLE_Y = 0.062

local QUALITY_COLORS = {}
for q, hex in pairs(EbonBuilds.Const.QUALITY_HEX) do QUALITY_COLORS[q] = "|cff" .. hex end

local L = ns.L
local R = ns.C.R

local function S(n)
  return n == 1 and "" or L.PLURAL
end

local PE = nil
local container = nil
local button = nil
local huntButton = nil
local slider = nil
local uiParent = nil
local orbHooksInstalled = false
local orbHookMissing = false

local state = "idle"
local pickSpellId = nil
local pickName = nil

local hunt = {
  armed  = false,
  active = false,
  budget = 0,
  spent  = 0,
  nextAt = 0,
}
ns.hunt = hunt

EbonBuilds.Reroll = EbonBuilds.Reroll or {}
function EbonBuilds.Reroll.IsHunting()
  return (hunt.armed or hunt.active) and true or false
end

local lastJudged = nil

local huntCycleInFlight = false

local orbMultiplier = 1
ns.selfCall = false

local function Multiplier()
  local n = orbMultiplier
  if type(n) ~= "number" or n < 1 then return 1 end
  return math.floor(n)
end

local FLOW = {
  ["REROLL.BUSY"] = L.BUSY,
  ["REROLL.NO_CHOICE"] = L.NO_CHOICE,
  ["REROLL.PICK_IN_FLIGHT"] = L.PICK_IN_FLIGHT,
  ["HUNT.RUNNING_ALREADY"] = L.HUNT_RUNNING_ALREADY,
}

local function PlainName(spellId)
  return GetSpellInfo(spellId) or L.THAT_ECHO
end

local function Blocked(code, a, b)
  local facts
  if code == "REROLL.NOT_ENOUGH_ORBS" then
    facts = { cost = a, charges = b }
  elseif code == "HUNT.BUDGET_TOO_LOW" then
    facts = { cost = a, budget = b }
  end
  return ns.api:Problem(code, facts)
end

local function Why(code, a, b)
  return FLOW[code] or ns.api:ProblemText(Blocked(code, a, b))
end

local function Refuse(code, a, b)
  if not FLOW[code] then ns.api:Report(Blocked(code, a, b)) end
end

local deadFor = nil

local Refresh

local Timer = EbonBuilds.Timer
local Arm, Cancel = Timer.Arm, Timer.Cancel

local stateTimer  = Timer.New("Hunt: pick then spend")
local probeTimer  = Timer.New("Hunt: orb count probe")
local huntTimer   = Timer.New("Hunt: cycle floor")
local unfoldTimer = Timer.New("Hunt: unfold")

local settleTimer = Timer.New("Hunt: orb offer settle")
local settleUntil = 0

local function SettleTick()
  if GetTime() >= settleUntil then return end
  Refresh()
  Arm(settleTimer, TICK, SettleTick)
end

local function ArmSettle()
  settleUntil = GetTime() + SETTLE_WINDOW
  Arm(settleTimer, TICK, SettleTick)
end

local function Orb()
  return PE and PE.OrbService
end

local function Svc()
  return PE and PE.PerkService
end

local function Charges()
  local orb = Orb()
  return (orb and orb.GetCharges and orb.GetCharges()) or 0
end

local function ChargesKnown()
  local orb = Orb()
  if not orb or not orb.IsStateKnown then return true end
  return orb.IsStateKnown()
end

local OnProbeExpired

local function ProbeCharges()
  if ChargesKnown() then
    Cancel(probeTimer)
    return
  end
  if probeTimer:IsShown() then return end
  local orb = Orb()
  if orb and orb.RequestCharges then orb.RequestCharges() end
  Arm(probeTimer, CHARGE_PROBE_INTERVAL, OnProbeExpired)
end

function OnProbeExpired()
  if ChargesKnown() then Refresh() else ProbeCharges() end
end

local function ColoredName(spellId, quality)
  local name = GetSpellInfo(spellId) or ("Echo " .. tostring(spellId))
  return (QUALITY_COLORS[quality or 0] or "|cffFFFFFF") .. name .. "|r"
end

local function QualityName(q)
  local name = _G["ITEM_QUALITY" .. (q + 1) .. "_DESC"] or tostring(q)
  return (QUALITY_COLORS[q] or "") .. name .. R
end

local function Wanted(spellId)
  local wl = ns.Wishlist
  return (wl and wl.Has(spellId)) and true or false
end

local function WantedCount()
  local wl = ns.Wishlist
  return (wl and wl.Count()) or 0
end

local function AutoAcceptOn()
  local svc = EbonAPI.Ebonhold.OptionsService()
  if not svc or not svc.GetSetting then return false end
  local value = ns.api:Guard("HUNT.AUTO_ACCEPT_READ", svc.GetSetting, svc, "autoAcceptLoadoutEchoes")
  return value and true or false
end

local function FindWanted(choices)
  if not choices or WantedCount() == 0 then return nil end
  for i = 1, #choices do
    local c = choices[i]
    if c.spellId and Wanted(c.spellId) then return c end
  end
  return nil
end

local function IsPermanent(spellId)
  local svc = Svc()
  local locked = svc and svc.GetLockedPerks and svc.GetLockedPerks()
  if not locked then return false end
  for _, p in ipairs(locked) do
    if p.spellId == spellId then return true end
  end
  return false
end

local function OwnedStacks(spellId)
  local svc = Svc()
  local granted = svc and svc.GetGrantedPerks and svc.GetGrantedPerks()
  local name = GetSpellInfo(spellId)
  if not granted or not name or not granted[name] then return 0, nil end

  local owned, maxStack = 0, nil
  for _, entry in ipairs(granted[name]) do
    if entry.spellId == spellId then
      owned = owned + 1
      maxStack = entry.maxStack or maxStack
    end
  end
  return owned, maxStack
end

local function ChooseSacrifice(choices)
  if not choices then return nil end

  local best, bestScore
  for _, c in ipairs(choices) do
    local spellId = c.spellId
    local eligible = spellId and not Wanted(spellId) and not IsPermanent(spellId)
    if eligible then
      local owned, maxStack = OwnedStacks(spellId)
      eligible = not (maxStack and owned >= maxStack)
    end
    if eligible then
      local score = c.quality or 0
      if c.isGuaranteed then score = score + 1000 end
      if c.isFrozen then score = score + 500 end
      if c.isCarried then score = score + 250 end
      if not bestScore or score < bestScore then
        best, bestScore = c, score
      end
    end
  end
  return best
end

local function CanReroll()
  if not PE or not Orb() or not Svc() then return nil, "REROLL.NO_ORB_SERVICE" end
  if state ~= "idle" then return nil, "REROLL.BUSY" end

  local svc = Svc()
  local choices = svc.GetCurrentChoice and svc.GetCurrentChoice()
  if not choices or #choices == 0 then return nil, "REROLL.NO_CHOICE" end

  if PE.Perks and PE.Perks.pendingSelectSpellId then
    return nil, "REROLL.PICK_IN_FLIGHT"
  end

  local pick = ChooseSacrifice(choices)
  if not pick then
    return nil, "REROLL.NONE_FORGETTABLE", true
  end

  if not ChargesKnown() then return nil, "REROLL.CHARGES_UNKNOWN" end
  local cost = Multiplier()
  if Charges() < cost then
    return nil, "REROLL.NOT_ENOUGH_ORBS", false, cost, Charges()
  end

  return pick
end

local MARK_OPEN  = "|cffffff00>> |r"
local MARK_CLOSE = " |cffffff00<<|r"
local CARD_GAP   = "    "

local liveLine = nil
local liveWanted = nil
local cardParts = {}

local function CardsLine(choices, markedId)
  if not choices then return "" end
  local n = #choices
  for i = 1, n do
    local c = choices[i]
    local text = ColoredName(c.spellId, c.quality)
    if c.spellId == markedId or Wanted(c.spellId) then
      text = MARK_OPEN .. text .. MARK_CLOSE
    end
    cardParts[i] = text
  end
  return table.concat(cardParts, CARD_GAP, 1, n)
end

local function WantedLine()
  local wl = ns.Wishlist
  if not wl or wl.Count() == 0 then return nil end
  local rows = wl.Armed()
  local names = {}
  for i = 1, #rows do
    local row = rows[i]
    if row.floor ~= row.qualities[1] then
      names[i] = string.format(L.LIVE_WANTED_MIN, row.name, QualityName(row.floor))
    else
      names[i] = row.name
    end
  end
  return string.format(L.LIVE_WANTED, table.concat(names, ", "))
end

local function Live(title, line)
  liveLine = line
  local toast = EbonBuilds.Toast
  if toast and toast.ShowLive and toast.ShowLive(title, line, liveWanted) then return end
  ns.api:Notify(title)
end

local function LiveTitle()
  return string.format(L.LIVE_TITLE, hunt.spent, hunt.budget, S(hunt.budget))
end

local function HuntStop(reason, clearList, line)
  if not hunt.active then return end
  hunt.active = false
  hunt.budget = 0
  huntCycleInFlight = false
  lastJudged = nil

  local spent = hunt.spent
  hunt.spent = 0

  Cancel(huntTimer)

  if clearList and ns.Wishlist then ns.Wishlist.Clear() end
  if reason then
    Live(reason .. string.format(L.HUNT_SPENT, spent, S(spent)), line or liveLine)
  end
  Refresh()
end

local function FailHuntCycle(reason, detail)
  if not huntCycleInFlight then return end
  huntCycleInFlight = false
  HuntStop(reason, false, detail)
end

local function Fail(problem, huntReason)
  if problem then ns.api:Report(problem) end
  FailHuntCycle(huntReason)
end

local function Abort(problem)
  state = "idle"
  pickSpellId, pickName = nil, nil
  Cancel(stateTimer)
  Fail(problem, L.HUNT_INTERRUPTED)
  Refresh()
end

local function OnPickTimeout()
  Abort(ns.api:Problem("REROLL.PICK_TIMED_OUT", { echo = PlainName(pickSpellId), seconds = PICK_TIMEOUT }))
end

local function Spend()
  local orb, spellId = Orb(), pickSpellId
  state = "idle"
  pickSpellId, pickName = nil, nil

  if not orb or not spellId then
    Fail(ns.api:Problem("REROLL.NO_PICK_TO_SPEND"), L.HUNT_BEFORE_SPEND)
    return
  end

  if IsPermanent(spellId) then
    Fail(ns.api:Problem("REROLL.WENT_PERMANENT", { echo = PlainName(spellId) }), L.HUNT_WENT_PERMANENT)
    return
  end

  local cost = Multiplier()
  if Charges() < cost then
    Fail(ns.api:Problem("REROLL.SPEND_SHORT_ORBS", { echo = PlainName(spellId), cost = cost, charges = Charges() }),
      string.format(L.HUNT_NO_ORBS, cost))
    return
  end

  ns.selfCall = true
  local sent, problem = EbonAPI.Ebonhold.ConfirmSpend(spellId, cost)
  ns.selfCall = false

  if not sent then
    Fail(problem, L.HUNT_SPEND_FAILED)
    return
  end

  if huntCycleInFlight then
    huntCycleInFlight = false
    hunt.spent = hunt.spent + cost
    Live(LiveTitle(), CardsLine(lastJudged, spellId))
  end

end

local function SpendOrb()
  Spend()
  Refresh()
end

local function Reroll()
  local pick, code, _, a, b = CanReroll()
  if not pick then
    Refuse(code, a, b)
    return false
  end

  pickSpellId = pick.spellId
  pickName = ColoredName(pick.spellId, pick.quality)
  state = "picking"
  Arm(stateTimer, PICK_TIMEOUT, OnPickTimeout)

  ns.selfCall = true
  local sent, problem = EbonAPI.Ebonhold.SelectPerk(pick.spellId)
  ns.selfCall = false

  if not sent then
    Abort(problem)
    return false
  end
  Refresh()
  return true
end

local budgetWanted = DEFAULT_BUDGET

local function CanHunt()
  if hunt.active then return nil, "HUNT.RUNNING_ALREADY" end
  if WantedCount() == 0 then return nil, "HUNT.NOTHING_ARMED" end
  if AutoAcceptOn() then return nil, "HUNT.AUTO_ACCEPT_ON" end
  if not ChargesKnown() then return nil, "REROLL.CHARGES_UNKNOWN" end

  local cost = Multiplier()
  if Charges() < cost then
    return nil, "REROLL.NOT_ENOUGH_ORBS", cost, Charges()
  end
  if math.min(budgetWanted, Charges()) < cost then
    return nil, "HUNT.BUDGET_TOO_LOW", cost, math.min(budgetWanted, Charges())
  end
  return true
end

local function HuntBegin()
  hunt.active = true
  hunt.budget = math.min(budgetWanted, Charges())
  hunt.spent  = 0
  hunt.nextAt = 0
  lastJudged = nil
  huntCycleInFlight = false

  local cost  = Multiplier()
  local draws = math.floor(hunt.budget / cost)
  liveWanted = WantedLine()
  Live(LiveTitle(), string.format(L.HUNT_STARTED, WantedCount(),
    hunt.budget, S(hunt.budget), draws, S(draws), cost))

  Refresh()
end

local function HuntStart()
  local ok, code, a, b = CanHunt()
  if not ok then
    Refuse(code, a, b)
    return
  end

  HuntBegin()
end

local function ToggleHunt()
  if hunt.active then
    HuntStop(L.HUNT_STOPPED, false)
  else
    HuntStart()
  end
end

local function ToggleGuard()
  hunt.armed = not hunt.armed
  Refresh()
end

local function Unfold()
  local parent, choose = EbonAPI.Ebonhold.PerkFrame(), _G.PerkChooseButton
  if parent and parent.perksHidden and choose and choose:IsShown() then
    choose:Click()
  end
end

local function HuntTick(choices)
  if not hunt.active then return end
  if state ~= "idle" then return end
  if not choices or #choices == 0 then return end
  if choices == lastJudged then return end

  local now = GetTime()
  if now < hunt.nextAt then
    Arm(huntTimer, hunt.nextAt - now, Refresh)
    return
  end

  lastJudged = choices

  local found = FindWanted(choices)
  if found then
    HuntStop(string.format(L.HUNT_FOUND, ColoredName(found.spellId, found.quality)), true,
      CardsLine(choices))
    Arm(unfoldTimer, 0, Unfold)
    return
  end

  local cost = Multiplier()

  if hunt.spent + cost > hunt.budget then
    HuntStop(L.HUNT_BUDGET_DONE, false, CardsLine(choices))
    return
  end
  if Charges() < cost then
    ns.api:Report(ns.api:Problem("HUNT.NO_ORBS_LEFT", { cost = cost, charges = Charges(), spent = hunt.spent }))
    HuntStop(string.format(L.HUNT_NO_ORBS, cost), false, CardsLine(choices))
    return
  end

  local pick, code, _, a, b = CanReroll()
  if not pick then
    deadFor = choices
    Refuse(code, a, b)
    HuntStop(L.HUNT_STOPPED, false, CardsLine(choices))
    return
  end

  hunt.nextAt = GetTime() + HUNT_CYCLE
  huntCycleInFlight = true
  Reroll()
end

local function InstallPerkHooks()
  local draw = EbonBuilds.DrawHook
  draw.Install()

  draw.After("Show", function()
    ArmSettle()
    Refresh()
  end)

  draw.After("Hide", Refresh)

  draw.After("UpdateSinglePerk", Refresh)

  draw.After("ResetSelection", function()
    if state == "picking" and not (PE.Perks and PE.Perks.pendingSelectSpellId) then
      Abort(nil)
    end
  end)
end

local function InstallOrbHooks()
  if orbHooksInstalled then return end
  local orb = Orb()
  if not orb then return end
  if not orb.ClearOffer then
    if not orbHookMissing then
      orbHookMissing = true
      ns.api:Degrade(ns.api:Problem("HUNT.NO_ORB_HOOK"))
    end
    return
  end
  if orbHookMissing then
    orbHookMissing = false
    ns.api:Restore("HUNT.NO_ORB_HOOK")
  end
  orbHooksInstalled = true

  local originalClearOffer = orb.ClearOffer
  orb.ClearOffer = function(...)
    originalClearOffer(...)
    if state == "picking" then
      state = "consuming"
      Arm(stateTimer, CONSUME_DELAY, SpendOrb)
    elseif hunt.active then
      HuntStop(L.HUNT_STOPPED_CLICK, false)
    end
    Refresh()
  end

  local originalConfirmSpend = orb.ConfirmSpend
  if originalConfirmSpend then
    orb.ConfirmSpend = function(spellId, count, ...)
      if not ns.selfCall and type(count) == "number" and count >= 1 then
        orbMultiplier = math.floor(count)
      end
      return originalConfirmSpend(spellId, count, ...)
    end
  end
end

local TOGGLE_BUTTONS = { "PerkHideButton", "PerkChooseButton" }
local togglesHooked = 0

local function InstallToggleHooks()
  if togglesHooked >= #TOGGLE_BUTTONS then return end
  for i = 1, #TOGGLE_BUTTONS do
    local b = _G[TOGGLE_BUTTONS[i]]
    if b and not b._eorHooked and b.HookScript then
      b._eorHooked = true
      togglesHooked = togglesHooked + 1
      b:HookScript("OnClick", Refresh)
    end
  end
end

local function RerollTip(add)
  add(L.REROLL_TITLE, "title")

  local pick, code, _, a, b = CanReroll()
  if pick then
    local cost = Multiplier()
    add(string.format(L.REROLL_BODY, ColoredName(pick.spellId, pick.quality)), "text", true)
    add(string.format(L.REROLL_COST, cost, S(cost), Charges()))
  else
    add(Why(code, a, b), "error", true)
  end
end

local function HuntTip(add)
  local cost = Multiplier()

  if hunt.active then
    add(L.HUNT_RUNNING, "title")
    add(string.format(L.HUNT_PROGRESS, hunt.spent, hunt.budget, cost))
    add(L.HUNT_CLICK_STOP, "muted")
    return
  end

  add(L.HUNT_TITLE, "title")
  local ok, code, a, b = CanHunt()
  if ok then
    local budget = math.min(budgetWanted, Charges())
    local draws  = math.floor(budget / cost)
    add(string.format(L.HUNT_BODY, WantedCount()), "text", true)
    add(string.format(L.HUNT_BODY_COST, cost, draws, budget), "text", true)
    add(L.HUNT_BODY_MANUAL, "muted", true)
    if cost == 1 then
      add(L.HUNT_BODY_HINT, "faint", true)
    end
  else
    add(Why(code, a, b), "error", true)
  end
end

local rarityButton = nil

local function QualityRGB(q)
  local const = EbonBuilds and EbonBuilds.Const
  local rgb = const and const.QUALITY_RGB and const.QUALITY_RGB[q]
  if rgb then return rgb[1], rgb[2], rgb[3] end
  return 1, 1, 1
end

local function OpenFloorMenu(row)
  local items = { { text = row.name, title = true } }
  for i = 1, #row.qualities do
    local q = row.qualities[i]
    items[#items + 1] = {
      text = (i == 1) and L.RARITY_ANY or string.format(L.RARITY_MIN, QualityName(q)),
      checked = row.floor == q,
      onClick = function() ns.Wishlist.SetFloor(row.key, q) end,
    }
  end
  EbonBuilds.api:OpenMenu(items)
end

local function OpenRarityMenu()
  local wl = ns.Wishlist
  if not wl then return end
  local rows = wl.Armed()
  local items = {}
  for i = 1, #rows do
    local row = rows[i]
    items[i] = { text = row.name, onClick = function() OpenFloorMenu(row) end }
  end
  if #items == 0 then items[1] = { key = "NOTHING_ARMED", disabled = true } end
  EbonBuilds.api:OpenMenu(items)
end

local function RarityTip(add)
  add(L.RARITY_TITLE, "title")
  if WantedCount() == 0 then
    add(L.NOTHING_ARMED, "error", true)
  else
    add(L.RARITY_BODY, "text", true)
    add(L.RARITY_HINT, "muted", true)
  end
end

local function MakeButton(parent, label, width, onClick, tip)
  local b = EbonBuilds.Widgets.Kit("button", parent, {
    text = function(self) return self._label end,
    width = width, height = BUTTON_HEIGHT,
    onClick = function(self) onClick(self) end,
  })
  b._label = label
  b:Refresh()
  EbonBuilds.Widgets.Tip(b, function(add)
    Refresh()
    tip(add)
  end)
  return b
end

local function MakeSlider(parent)
  local s
  local function Relabel(value)
    local cost = Multiplier()
    if cost > 1 then
      local draws = math.floor(value / cost)
      s._title = string.format(L.BUDGET_DRAWS, value, draws, S(draws), cost)
    else
      s._title = string.format(L.BUDGET, value)
    end
    s:SetTitle(s._title)
    s._lblValue, s._lblCost = value, cost
  end

  s = EbonBuilds.Widgets.Kit("range", parent, {
    width = SLIDER_WIDTH, min = 1, max = math.max(1, DEFAULT_BUDGET), step = 1,
    value = DEFAULT_BUDGET,
    text = function(self) return self._title or "" end,
    onChange = function(_, value)
      value = math.floor(value + 0.5)
      budgetWanted = value
      Relabel(value)
      Refresh()
    end,
  })
  s._relabel = Relabel
  if s.low then s.low:Hide() end
  if s.high then s.high:Hide() end

  Relabel(DEFAULT_BUDGET)
  return s
end

local function SetEnabled(w, on)
  if w._eorEnabled == on then return end
  w._eorEnabled = on
  w:SetDisabledState(not on)
end

local function SetShown(f, on)
  if f._eorShown == on then return end
  f._eorShown = on
  if on then f:Show() else f:Hide() end
end

local function Anchor(panel, parent)
  uiParent = parent
  panel:SetParent(parent)
  panel:SetFrameLevel(parent:GetFrameLevel() + 20)
  panel:ClearAllPoints()
  panel:SetPoint("TOP", parent, "BOTTOM", 0, BUTTON_Y)
end

local function EnsureUI(parent)
  if container then return container end

  container = EbonBuilds.Widgets.Kit("bar", parent, { spacing = BUTTON_GAP })
  Anchor(container, parent)

  button = MakeButton(container, "Reroll (Orb)", BUTTON_WIDTH, Reroll, RerollTip)
  huntButton = MakeButton(container, "Chercher", HUNT_BUTTON_WIDTH, ToggleHunt, HuntTip)
  rarityButton = MakeButton(container, "", RARITY_WIDTH, OpenRarityMenu, RarityTip)
  local swatch = rarityButton:CreateTexture(nil, "OVERLAY")
  swatch:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  swatch:SetWidth(RARITY_WIDTH - 14)
  swatch:SetHeight(BUTTON_HEIGHT - 18)
  swatch:SetPoint("CENTER")
  rarityButton.swatch = swatch

  slider = MakeSlider(container)

  SetShown(container, false)
  return container
end

local function RefreshSliderBounds()
  local maxOrbs = math.max(1, Charges())
  if slider._eorMax == maxOrbs then return end
  slider._eorMax = maxOrbs
  slider:SetRange(1, maxOrbs, 1)
  if budgetWanted > maxOrbs then
    budgetWanted = maxOrbs
    slider:SetValue(maxOrbs)
  else
    slider:SetValue(budgetWanted)
  end
  slider._relabel(budgetWanted)
end

local function RefreshSliderLabel()
  if not slider or not slider._relabel then return end
  local value = budgetWanted
  if slider._lblValue == value and slider._lblCost == Multiplier() then return end
  slider._relabel(value)
end

local function RefreshRarity()
  if not rarityButton then return end
  local wl = ns.Wishlist
  local n = (wl and wl.Count()) or 0
  local floor = (n > 0 and wl.CommonFloor()) or nil

  if rarityButton._floor == floor and rarityButton._armed == n then return end
  rarityButton._floor, rarityButton._armed = floor, n

  if floor then
    rarityButton.swatch:SetVertexColor(QualityRGB(floor))
  else
    rarityButton.swatch:SetVertexColor(0.55, 0.55, 0.55)
  end
end

local function SetButtonText(b, label)
  b._label = label
  b:SetLabel(label)
end

local function SetLabel(b, enabled)
  local charges = ChargesKnown() and Charges() or nil
  if b._enabled == enabled and b._state == state and b._charges == charges then return end
  b._enabled, b._state, b._charges = enabled, state, charges

  if state ~= "idle" then
    SetButtonText(b, L.REROLL_BUSY, enabled)
  else
    SetButtonText(b, string.format(L.REROLL, charges or "?"), enabled)
  end
end

local function SetHuntLabel(b, enabled)
  local cost, count = Multiplier(), WantedCount()
  if b._enabled == enabled and b._active == hunt.active and b._spent == hunt.spent
      and b._budget == hunt.budget and b._count == count and b._cost == cost then
    return
  end
  b._enabled, b._active, b._spent = enabled, hunt.active, hunt.spent
  b._budget, b._count, b._cost = hunt.budget, count, cost

  if hunt.active then
    SetButtonText(b, string.format(L.HUNT_STOP, hunt.spent, hunt.budget), enabled)
  elseif cost > 1 then
    SetButtonText(b, string.format(L.HUNT_MULT, count, cost), enabled)
  else
    SetButtonText(b, string.format(L.HUNT, count), enabled)
  end
end

local toggle = nil

local function GuardTip(add)
  add(L.TOGGLE, "title")
  add(L.GUARD_BODY, "text", true)
  add(hunt.armed and L.GUARD_ON or L.GUARD_OFF, "muted", true)
end

local function PaintToggle(on)
  if not toggle or toggle._on == on then return end
  toggle._on = on
  toggle:Refresh()
end

local function BuildToggle(root)
  if toggle or not root or not PE then return end

  local t = EbonBuilds.Widgets.Kit("toggle", root, {
    key = "TOGGLE",
    get = function() return hunt.armed end,
    onChange = ToggleGuard,
  })
  t:SetFrameLevel(root:GetFrameLevel() + 10)
  t:SetPoint("TOPRIGHT", root, "TOPRIGHT",
    -root:GetWidth() * TOGGLE_X, -root:GetHeight() * TOGGLE_Y)
  EbonBuilds.Widgets.Tip(t, GuardTip)

  toggle = t
  toggle._on = hunt.armed
end

local function Evaluate()
  PaintToggle(hunt.armed)

  local parent = EbonAPI.Ebonhold.PerkFrame()
  if not parent then
    if container then SetShown(container, false) end
    return
  end

  InstallOrbHooks()
  InstallToggleHooks()

  local svc = Svc()
  local orb = Orb()
  local choices = svc and svc.GetCurrentChoice and svc.GetCurrentChoice()
  local offerPending = orb and orb.IsOfferPending and orb.IsOfferPending() or false

  if offerPending then
    Cancel(settleTimer)
    ProbeCharges()
    HuntTick(choices)
  end

  local relevant = parent:IsShown()
      and not parent.perksHidden
      and choices and #choices > 0
      and offerPending

  if not relevant then
    if container then SetShown(container, false) end
    return
  end

  local panel = EnsureUI(parent)
  if uiParent ~= parent then Anchor(panel, parent) end

  RefreshSliderBounds()
  RefreshSliderLabel()

  local pick, code, impossible = CanReroll()
  if impossible then
    if deadFor ~= choices then
      deadFor = choices
      Refuse(code)
    end
    SetShown(panel, false)
    return
  end

  local canReroll = (pick ~= nil) and not hunt.active
  SetEnabled(button, canReroll)
  SetLabel(button, canReroll)

  local canHunt = hunt.active or (CanHunt() ~= nil)
  SetEnabled(huntButton, canHunt)
  SetHuntLabel(huntButton, canHunt)

  SetEnabled(rarityButton, WantedCount() > 0)
  RefreshRarity()

  SetEnabled(slider, not hunt.active)

  SetShown(panel, true)
end

local refreshing = false
function Refresh()
  if refreshing then return end
  refreshing = true
  ns.api:Guard("REROLL.REFRESH", Evaluate)
  refreshing = false
end

local function OnWishlistChanged()
  if hunt.active then liveWanted = WantedLine() end
  Refresh()
end

local function Boot()
  if not EbonAPI.Ebonhold.IsPresent() then return end

  PE = EbonAPI.Ebonhold.Raw()
  local ui = PE and PE.PerkUI
  if not PE or not PE.PerkService or not ui
      or not ui.Show or not ui.Hide or not ui.ResetSelection then
    PE = nil
    ns.api:Degrade(ns.api:Problem("HUNT.NO_PERK_SYSTEM"))
    return
  end

  InstallPerkHooks()

  ns.OnWishlistChanged = OnWishlistChanged

  ns.OnJournalFound = BuildToggle
end

ns.api:On("READY", Boot)
