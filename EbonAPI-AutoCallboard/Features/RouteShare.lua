local Core = AutoCallboardCore
local RT = AutoCallboardRuntime

RT.routeSharePrefix = "ACBR"

local PREFIX = RT.routeSharePrefix
local START_DELAY = 5
local HELLO_DELAY = 3
local REPLY_MIN, REPLY_MAX = 1, 5
local WHO_COOLDOWN = 30
local AVAILABILITY_TTL = 600
local FETCH_TIMEOUT = 30
local PURGE_DELAY = 60
local HASHES_PER_MESSAGE = 15
local REQUEST_COOLDOWN = 10
local DIGEST_CHARS = 8

local share = {
  replies = {},
  availability = {},
  asked = {},
  fetching = {},
  recent = {},
  serial = 0,
}

RT.routeShare = share

local function MyName()
  return UnitName and UnitName("player") or ""
end

function RT.GetRouteLibrary()
  local state = RT.state

  if type(state.routeLibrary) ~= "table" then
    state.routeLibrary = {}
  end

  if type(state.routeLibrary.entries) ~= "table" then
    state.routeLibrary.entries = {}
  end

  return state.routeLibrary
end

function RT.ServerDay()
  if CalendarGetDate then
    local ok, _, month, day, year = pcall(CalendarGetDate)
    local number = ok and Core.dayNumber(year, month, day)

    if number then
      return number
    end
  end

  local now = date and date("*t")

  return now and Core.dayNumber(now.year, now.month, now.day) or 0
end

function RT.RouteShareDelay(low, high)
  return low + math.random() * (high - low)
end

local function RefreshLibrary()
  RT.RefreshRouteLibrary()
end

local function HeldRoutes(category)
  local held = {}

  for _, route in ipairs(RT.GetAccountProfile().savedRoutes or {}) do
    if Core.isRouteShared(route) and (category == nil or route.category == category) then
      held[Core.routeHash(route)] = route
    end
  end

  return held
end

function RT.RefreshHeldLibraryEntries()
  local library, today = RT.GetRouteLibrary(), RT.ServerDay()
  local changed = false

  for hash, route in pairs(HeldRoutes()) do
    if Core.mergeLibraryEntry(library, hash, Core.libraryEntryFromRoute(route, today), today) then
      changed = true
    end
  end

  if changed then
    RT.TouchState()
    RefreshLibrary()
  end

  return changed
end

local SAY_LABELS = { H = "hello", W = "availability request", N = "route announcement" }
local channelDown = false

local function Say(op, body)
  local sent, why = RT.api:Say(op, body or "")

  if sent then
    if channelDown then
      channelDown = false
      RT.api:Restore("ROUTESHARE.CHANNEL_DOWN")
    end
  elseif why == "full" and not channelDown then
    channelDown = true
    RT.api:Degrade(RT.api:Problem("ROUTESHARE.CHANNEL_DOWN", { what = SAY_LABELS[op] or "message", op = op }))
  end

  return sent
end

local function Reject(sender, reason, sample)
  RT.api:Reject("ROUTESHARE.MESSAGE_REJECTED", {
    sender = tostring(sender),
    reason = reason,
    sample = string.sub(tostring(sample or ""), 1, 60),
  })
end

local function Whisper(target, payload)
  if not target or target == "" then
    return false
  end

  return RT.api:Whisper(PREFIX, target, payload)
end

local function SendStream(target, op, id, data)
  return RT.api:WhisperStream(PREFIX, target, op, id, data)
end

local function Throttled(sender, kind, now)
  local key = sender .. ":" .. kind
  local last = share.recent[key]

  if last and now - last < REQUEST_COOLDOWN then
    return true
  end

  share.recent[key] = now

  return false
end

local function SendHello(now)
  if not Say("H", table.concat(Core.libraryDigests(RT.GetRouteLibrary()), ",")) then
    return false
  end

  share.helloSent = true
  share.served = false
  share.purgeAt = now + PURGE_DELAY

  return true
end

local function SendEntries(target, category, buckets)
  local parts = {}

  for _, item in ipairs(Core.libraryEntriesIn(RT.GetRouteLibrary(), category, buckets)) do
    parts[#(parts) + 1] = Core.serializeLibraryEntry(item.hash, item.entry)
  end

  if #(parts) > 0 then
    SendStream(target, "E", nil, table.concat(parts, ";"))
  end
end

local function OnHello(sender, payload, now)
  local theirs = {}

  for digest in string.gmatch(payload, "[^,]+") do
    theirs[#(theirs) + 1] = digest
  end

  if #(theirs) ~= Core.routeCategoryCount() then
    Reject(sender, "version", payload)
    return
  end

  local mine = Core.libraryDigests(RT.GetRouteLibrary())
  local differing = {}

  for category = 1, #(mine) do
    if mine[category] ~= theirs[category] then
      differing[#(differing) + 1] = category
    end
  end

  if #(differing) == 0 then
    share.replies[sender] = nil
    return
  end

  share.replies[sender] = { at = now + RT.RouteShareDelay(REPLY_MIN, REPLY_MAX), categories = differing }
end

local function OnBuckets(sender, payload)
  local category, digests = string.match(payload, "^(%d+):(.+)$")
  category = tonumber(category)

  if not Core.isRouteCategory(category) or #(digests or "") ~= Core.ROUTE_LIBRARY_BUCKETS * DIGEST_CHARS then
    Reject(sender, "buckets", payload)
    return
  end

  if share.helloSent and not share.served then
    share.served = true
    Say("S")
  end

  local mine = Core.libraryBucketDigests(RT.GetRouteLibrary(), category)
  local wanted, list = {}, {}

  for bucket = 0, Core.ROUTE_LIBRARY_BUCKETS - 1 do
    local theirs = string.sub(digests, bucket * DIGEST_CHARS + 1, (bucket + 1) * DIGEST_CHARS)

    if theirs ~= mine[bucket + 1] then
      wanted[bucket] = true
      list[#(list) + 1] = string.format("%x", bucket)
    end
  end

  if #(list) == 0 then
    return
  end

  Whisper(sender, "R:" .. category .. ":" .. table.concat(list))
  SendEntries(sender, category, wanted)
end

local function OnRequest(sender, payload, now)
  local category, list = string.match(payload, "^(%d+):(%x+)$")
  category = tonumber(category)

  if not Core.isRouteCategory(category) or Throttled(sender, "R" .. category, now) then
    return
  end

  local buckets = {}

  for digit in string.gmatch(list, "%x") do
    buckets[tonumber(digit, 16)] = true
  end

  SendEntries(sender, category, buckets)
end

local function MergeEntries(texts, sender)
  local items = {}

  for _, text in ipairs(texts) do
    local hash, entry = Core.parseLibraryEntry(text)

    if hash then
      items[#(items) + 1] = { hash = hash, entry = entry }
    else
      Reject(sender, "entry", text)
    end
  end

  local changed = Core.mergeLibraryEntries(RT.GetRouteLibrary(), items, RT.ServerDay())

  if changed > 0 then
    RT.TouchState()
    RefreshLibrary()
  end

  return changed
end

local function OnEntries(data, sender)
  local texts = {}

  for text in string.gmatch(data, "[^;]+") do
    texts[#(texts) + 1] = text
  end

  MergeEntries(texts, sender)
end

local function OnWho(sender, payload, now)
  local category = tonumber(payload)

  if not Core.isRouteCategory(category) or Throttled(sender, "W" .. category, now) then
    return
  end

  local hashes = {}

  for hash in pairs(HeldRoutes(category)) do
    hashes[#(hashes) + 1] = hash
  end

  table.sort(hashes)

  for i = 1, #(hashes), HASHES_PER_MESSAGE do
    Whisper(sender, "A:" .. category .. ":" .. table.concat(hashes, "", i, math.min(i + HASHES_PER_MESSAGE - 1, #(hashes))))
  end
end

local function OnAvailable(sender, payload, now)
  local list = string.match(payload, "^%d+:(.+)$") or ""

  for i = 1, #(list), Core.ROUTE_HASH_LENGTH do
    local hash = Core.sanitizeRouteHash(string.sub(list, i, i + Core.ROUTE_HASH_LENGTH - 1))

    if hash then
      share.availability[hash] = share.availability[hash] or {}
      share.availability[hash][sender] = now + AVAILABILITY_TTL
    else
      Reject(sender, "hash", string.sub(list, i, i + Core.ROUTE_HASH_LENGTH - 1))
    end
  end

  RefreshLibrary()
end

function RT.RouteHolders(hash, now)
  now = now or GetTime()

  local holders = {}

  for name, expires in pairs(share.availability[hash] or {}) do
    if expires > now then
      holders[#(holders) + 1] = name
    end
  end

  table.sort(holders, function(a, b)
    return share.availability[hash][a] > share.availability[hash][b]
  end)

  return holders
end

function RT.IsRouteAvailable(hash)
  local now = GetTime()

  for _, expires in pairs(share.availability[hash] or {}) do
    if expires > now then
      return true
    end
  end

  return false
end

function RT.RequestRouteAvailability(category, force)
  local now = GetTime()

  if not Core.isRouteCategory(category) then
    return false
  end

  if not force and share.asked[category] and now - share.asked[category] < WHO_COOLDOWN then
    return false
  end

  if not Say("W", tostring(category)) then
    return false
  end

  share.asked[category] = now

  local entries = RT.GetRouteLibrary().entries

  for hash in pairs(share.availability) do
    if entries[hash] and entries[hash].category == category then
      share.availability[hash] = nil
    end
  end

  RefreshLibrary()

  return true
end

local function EntryName(hash)
  local entry = RT.GetRouteLibrary().entries[hash]

  return entry and entry.name or tostring(hash)
end

function RT.FetchLibraryRoute(hash)
  hash = Core.sanitizeRouteHash(hash)

  if not hash then
    return false
  end

  if Core.findRouteByHash(RT.GetAccountProfile(), hash, RT.GetRouteLibrary().entries[hash]) then
    RT.api:Report(RT.api:Problem("ROUTESHARE.ALREADY_OWNED", { route = EntryName(hash), hash = hash }))
    return false
  end

  local fetch = share.fetching[hash]

  fetch = fetch or { tried = {} }

  local holder

  for _, name in ipairs(RT.RouteHolders(hash)) do
    if not fetch.tried[name] then
      holder = name
      break
    end
  end

  if not holder then
    local tried = 0

    for _ in pairs(fetch.tried) do
      tried = tried + 1
    end

    share.fetching[hash] = nil
    RT.api:Report(RT.api:Problem("ROUTESHARE.NO_HOLDER", { route = EntryName(hash), hash = hash, tried = tried }))
    return false
  end

  fetch.tried[holder] = true
  fetch.holder = holder
  fetch.at = GetTime()
  share.fetching[hash] = fetch

  if not Whisper(holder, "G:" .. hash) then
    share.fetching[hash] = nil
    RT.api:Report(RT.api:Problem("ROUTESHARE.REQUEST_NOT_SENT", { route = EntryName(hash), hash = hash, holder = holder }))
    return false
  end

  return true
end

function RT.ImportLibraryRoute(code, hash)
  local fetch = share.fetching[hash]

  share.fetching[hash] = nil

  local holder = fetch and fetch.holder or "?"
  local route, cause = Core.decodeRoute(code)
  local profile = RT.GetAccountProfile()

  if not route then
    RT.api:Report(RT.api:Problem("ROUTESHARE.CODE_INVALID",
      { route = EntryName(hash), hash = hash, holder = holder, reason = "decode" }, cause))
    return nil
  end

  if Core.codeHash(code) ~= hash then
    RT.api:Report(RT.api:Problem("ROUTESHARE.CODE_INVALID",
      { route = EntryName(hash), hash = hash, holder = holder, reason = "hash" }))
    return nil
  end

  if Core.findRouteByHash(profile, hash, { category = route.category, steps = #(route.steps) }) then
    RT.api:Report(RT.api:Problem("ROUTESHARE.ALREADY_OWNED", { route = route.name, hash = hash }))
    return nil
  end

  local nextProfile, entry, err = Core.createRoute(profile, route.steps, route.name, route.category,
    { difficulty = route.difficulty, shared = true, sharedHash = hash })

  if err == "full" then
    RT.api:Report(RT.api:Problem("RECORDER.ROUTES_FULL", { max = Core.MAX_SAVED_ROUTES, category = route.category }))
    return nil
  end

  if not entry then
    local reason = type(err) == "table" and err.code or err

    RT.api:Report(RT.api:Problem("ROUTESHARE.IMPORT_FAILED",
      { route = route.name, hash = hash, reason = tostring(reason) }))
    return nil
  end

  RT.SaveAccountProfile(nextProfile)

  local saved = Core.findRoute(nextProfile, entry.id)
  local today = RT.ServerDay()

  Core.mergeLibraryEntry(RT.GetRouteLibrary(), hash, Core.libraryEntryFromRoute(saved, today), today)
  RT.TouchState()

  RT.RefreshRouteWindow()

  RefreshLibrary()

  return saved
end

local function OnGet(sender, payload, now)
  local hash = Core.sanitizeRouteHash(payload)

  if not hash then
    Reject(sender, "bad_hash", payload)
    return
  end

  if Throttled(sender, "G" .. hash, now) then
    return
  end

  local route = HeldRoutes()[hash]
  local code = route and Core.encodeRoute(route)
  local why

  if not route then
    why = "not_held"
  elseif not code then
    why = "encode_failed"
  elseif Core.codeHash(code) ~= hash then
    why = "hash_changed"
  elseif not SendStream(sender, "C", hash, code) then
    why = "stream_failed"
  end

  if why then
    Reject(sender, why, hash)
    Whisper(sender, "X:" .. hash)
  end
end

local function OnCode(sender, hash, code)
  local fetch = share.fetching[hash]

  if not fetch or fetch.holder ~= sender then
    Reject(sender, "unsolicited", hash)
    return
  end

  RT.ImportLibraryRoute(code, hash)
end

local function OnMissing(sender, payload)
  local hash = Core.sanitizeRouteHash(payload)

  if not hash then
    return
  end

  if share.availability[hash] then
    share.availability[hash][sender] = nil
  end

  local fetch = share.fetching[hash]

  if fetch and fetch.holder == sender then
    RT.FetchLibraryRoute(hash)
  end

  RefreshLibrary()
end

function RT.SyncSharedRoutes()
  local profile = RT.GetAccountProfile()
  local library, today
  local nextProfile, announced = profile, false

  for _, route in ipairs(profile.savedRoutes or {}) do
    if Core.routeNeedsAnnounce(route) then
      library, today = library or RT.GetRouteLibrary(), today or RT.ServerDay()

      local hash = Core.routeHash(route)
      local entry = Core.libraryEntryFromRoute(route, today)

      if Core.mergeLibraryEntry(library, hash, entry, today) then
        RefreshLibrary()
      end

      if Say("N", Core.serializeLibraryEntry(hash, entry)) then
        nextProfile = (Core.routeContainer.update(nextProfile, route.id, { sharedHash = hash }))
        announced = true
      end
    end
  end

  if announced then
    RT.SaveAccountProfile(nextProfile)
    RT.TouchState()
  end

  return announced
end

function RT.ShareRoute(id, shared)
  local nextProfile, ok = Core.setRouteShared(RT.GetAccountProfile(), id, shared)

  if not ok then
    return false
  end

  RT.SaveAccountProfile(nextProfile)

  if shared then
    RT.SyncSharedRoutes()
  end

  RT.TouchState()
  RefreshLibrary()
  RT.RefreshRouteWindow()

  return true
end

local function OnPeerOffline(_, name)
  share.replies[name] = nil

  for hash, holders in pairs(share.availability) do
    holders[name] = nil

    local fetch = share.fetching[hash]

    if fetch and fetch.holder == name then
      RT.FetchLibraryRoute(hash)
    end
  end

  RefreshLibrary()
end

local function OnChannelHello(sender, body)
  OnHello(sender, body, GetTime())
end

local function OnChannelServed(sender)
  share.replies[sender] = nil
end

local function OnChannelNew(sender, body)
  MergeEntries({ body }, sender)
end

local function OnChannelWho(sender, body)
  OnWho(sender, body, GetTime())
end

local function OnWhisper(sender, text, distribution)
  if distribution ~= "WHISPER" or sender == MyName() then
    return
  end

  local op, rest = string.match(text, "^(%a):(.*)$")
  local now = GetTime()

  if op == "B" then
    OnBuckets(sender, rest)
  elseif op == "R" then
    OnRequest(sender, rest, now)
  elseif op == "A" then
    OnAvailable(sender, rest, now)
  elseif op == "G" then
    OnGet(sender, rest, now)
  elseif op == "X" then
    OnMissing(sender, rest)
  end
end

local function OnEntriesStream(sender, body)
  OnEntries(body, sender)
end

local function OnCodeStream(sender, body, id)
  OnCode(sender, id, body)
end

local function OnCodePart(sender, id)
  local fetch = share.fetching[id]

  if fetch and fetch.holder == sender then
    fetch.at = GetTime()
  end
end

function RT.InitRouteShare()
  local api = RT.api

  api:OnChannel("H", OnChannelHello)
  api:OnChannel("S", OnChannelServed)
  api:OnChannel("N", OnChannelNew)
  api:OnChannel("W", OnChannelWho)
  api:OnWhisper(PREFIX, OnWhisper)
  api:OnWhisperStream(PREFIX, "E", OnEntriesStream)
  api:OnWhisperStream(PREFIX, "C", OnCodeStream, OnCodePart)
  api:On("PEER_OFFLINE", OnPeerOffline)
end

local function Expire(now)
  for key, at in pairs(share.recent) do
    if now - at > REQUEST_COOLDOWN then
      share.recent[key] = nil
    end
  end

  for hash, holders in pairs(share.availability) do
    for name, expires in pairs(holders) do
      if expires <= now then
        holders[name] = nil
      end
    end

    if next(holders) == nil then
      share.availability[hash] = nil
    end
  end

  for hash, fetch in pairs(share.fetching) do
    if now - fetch.at > FETCH_TIMEOUT then
      share.fetching[hash] = nil
      RT.api:Report(RT.api:Problem("ROUTESHARE.FETCH_TIMEOUT",
        { route = EntryName(hash), hash = hash, holder = fetch.holder or "?", seconds = FETCH_TIMEOUT }))
    end
  end
end

function RT.ProcessRouteShare(now)
  now = now or GetTime()

  if not share.startAt then
    share.startAt = now + START_DELAY
    RT.RefreshHeldLibraryEntries()
  end

  if now < share.startAt then
    return 1
  end

  RT.SyncSharedRoutes()

  if RT.api:IsChannelJoined() and not share.helloSent then
    share.helloAt = share.helloAt or now + HELLO_DELAY

    if now >= share.helloAt and SendHello(now) then
      share.helloAt = nil
    end
  end

  for sender, reply in pairs(share.replies) do
    if now >= reply.at then
      share.replies[sender] = nil

      for _, category in ipairs(reply.categories) do
        Whisper(sender, "B:" .. category .. ":" .. table.concat(Core.libraryBucketDigests(RT.GetRouteLibrary(), category)))
      end
    end
  end

  if share.purgeAt and now >= share.purgeAt then
    share.purgeAt = nil

    local held = {}

    for hash in pairs(HeldRoutes()) do
      held[hash] = true
    end

    if Core.purgeRouteLibrary(RT.GetRouteLibrary(), RT.ServerDay(), held) > 0 then
      RT.TouchState()
      RefreshLibrary()
    end
  end

  Expire(now)

  return 1
end
