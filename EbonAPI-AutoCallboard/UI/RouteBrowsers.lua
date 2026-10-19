local Core = AutoCallboardCore
local Skin = AutoCallboardSkin
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime

local categoryGroups = {}

local function CategoryGroups()
  for category = 1, Core.routeCategoryCount() do
    local group = categoryGroups[category] or { id = category }

    group.name = Core.routeCategoryName(category)
    categoryGroups[category] = group
  end

  return categoryGroups
end

local function OpenCategoryField(field)
  return function()
    local entry = RT.EnsureCharacterState()

    return entry and entry[field] or nil
  end, function(value)
    local entry = RT.EnsureCharacterState()

    if entry then
      entry[field] = value
    end
  end
end

local function BrowserWindow(name, titleKey, point, relativePoint, x)
  return function(width, height, buttons)
    if not RT.routeWindow then
      RT.CreateRouteWindow()
    end

    local window = Skin.Window(name, {
      width = width,
      height = height,
      titleKey = titleKey,
      buttons = buttons,
      point = { point, RT.routeWindow, relativePoint, x, 0 },
    })

    RT.routeWindow:HookScript("OnHide", function()
      window:Hide()
      end)

    return window
  end
end

local function AccountProfile()
  return RT.GetAccountProfile()
end

local function RouteTooltip(row, route)
  EbonAPI.Bricks.tip(row, route.name or "")
  GameTooltip:AddLine(string.format(L.ROUTES_ROW_STEPS, #(route.steps)), 1, 1, 1)

  local playable, faction = Core.canPlayRoute(route, RT.PlayerFaction())

  if not playable then
    GameTooltip:AddLine(string.format(L.ROUTE_WRONG_FACTION, Core.factionLabel(faction)), 1, 0.4, 0.4)
  end

  if not RT.CanEditRoutes() then
    GameTooltip:AddLine(L.ROUTES_ROW_LOCKED, 1, 0.4, 0.4)
  elseif RT.GetActiveRouteId() == route.id then
    GameTooltip:AddLine(L.LISTS_ROW_LEFT_CLICK_UNLOAD, 0.8, 0.8, 0.8)
  else
    GameTooltip:AddLine(L.LISTS_ROW_LEFT_CLICK_LOAD, 0.8, 0.8, 0.8)
  end

  GameTooltip:Show()
end

local getOpenRoutes, setOpenRoutes = OpenCategoryField("openRouteCategory")

local routesBrowser = RT.BuildBrowser({
  names = {
    groupPanel = "AutoCallboardRoutesPanel",
    band = "AutoCallboardRoutesBand",
    row = "AutoCallboardRoutesRow",
  },
  emptyKey = "ROUTES_BROWSER_EMPTY",
  maxGroups = function() return Core.routeCategoryCount() end,
  groups = CategoryGroups,
  getOpen = getOpenRoutes,
  setOpen = setOpenRoutes,
  groupEntries = function(category) return Core.routesInCategory(AccountProfile(), category) end,
  count = function(category) return Core.routeCount(AccountProfile(), category) end,
  rowText = function(route) return Core.routeTitle(route) end,
  rowState = function(route)
    return RT.GetActiveRouteId() == route.id, not RT.CanEditRoutes()
  end,
  rowTooltip = RouteTooltip,
  onRowClick = function(row, route, mouseButton)
    if mouseButton == "RightButton" then
      RT.ShowRouteMenu(row, route)
    else
      RT.ToggleLoadedRoute(route.id)
    end
  end,
  canDrag = function() return RT.CanEditRoutes() end,
  entryGroup = function(route) return route.category end,
  dropRefused = function(category) return Core.routesFull(AccountProfile(), category) end,
  moveEntry = function(id, category, beforeId)
    if not RT.CanEditRoutes() then
      RT.api:Report(RT.api:Problem("RECORDER.EDIT_LOCKED", { what = "move" }))
      return false
    end

    local nextProfile, ok, err = Core.moveRouteTo(AccountProfile(), id, category, beforeId)

    if err == "full" then
      RT.api:Report(RT.api:Problem("RECORDER.ROUTES_FULL", { max = Core.MAX_SAVED_ROUTES, category = category }))
    elseif not ok then
      RT.api:Report(RT.api:Problem("ROUTEBROWSER.MOVE_REFUSED", { route = id, category = category, reason = "unknown_route" }))
    end

    if ok then
      RT.SaveAccountProfile(nextProfile)
      RT.RefreshRouteWindow()
    end

    return ok
  end,
  bandLines = function(category)
    return {
      { string.format(L.ROUTES_CATEGORY_COUNT, Core.routeCount(AccountProfile(), category)), 1, 1, 1 },
      { L.ROUTES_CATEGORY_OPEN_TOOLTIP, 0.8, 0.8, 0.8 },
      { L.ROUTES_CATEGORY_DROP_TOOLTIP, 0.8, 0.8, 0.8 },
    }
  end,
  createWindow = BrowserWindow("AutoCallboardRoutesWindow", "ROUTES_BROWSER_TITLE", "TOPRIGHT", "TOPLEFT", -8),
})

local function LibraryItems(category)
  local items = {}

  for _, item in ipairs(Core.libraryEntriesIn(RT.GetRouteLibrary(), category)) do
    items[#(items) + 1] = { id = item.hash, name = item.entry.name, hash = item.hash, entry = item.entry }
  end

  return items
end

local function Owned(item)
  if item.owned == nil then
    item.owned = Core.findRouteByHash(AccountProfile(), item.hash, item.entry) ~= nil
  end

  return item.owned
end

local function LibraryState(item)
  if Owned(item) then
    return "owned"
  end

  return RT.IsRouteAvailable(item.hash) and "available" or "unavailable"
end

local function RequestFetch(item)
  Skin.Dialog({
    title = L.LIBRARY_FETCH_TITLE,
    body = string.format(L.LIBRARY_FETCH_BODY, item.entry.name, Core.routeCategoryName(item.entry.category)),
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function()
      RT.FetchLibraryRoute(item.hash)
      end,
  })
end

local getOpenLibrary, setOpenLibrary = OpenCategoryField("openLibraryCategory")
local libraryCounts = {}

local libraryBrowser = RT.BuildBrowser({
  names = {
    groupPanel = "AutoCallboardLibraryPanel",
    band = "AutoCallboardLibraryBand",
    row = "AutoCallboardLibraryRow",
  },
  emptyKey = "LIBRARY_EMPTY",
  maxGroups = function() return Core.routeCategoryCount() end,
  groups = CategoryGroups,
  getOpen = getOpenLibrary,
  setOpen = setOpenLibrary,
  groupEntries = LibraryItems,
  beforeRefresh = function() libraryCounts = Core.libraryCounts(RT.GetRouteLibrary()) end,
  count = function(category) return libraryCounts[category] or 0 end,
  rowText = function(item)
    local text = Core.factionIcon(item.entry.faction) .. string.format(L.LIBRARY_ENTRY_LINE,
      item.entry.name, tostring(item.entry.steps))

    if Owned(item) then
      text = text .. L.LIBRARY_ENTRY_OWNED
    end

    return text
  end,
  rowState = function(item)
    return false, LibraryState(item) ~= "available"
  end,
  rowTooltip = function(row, item)
    local state = LibraryState(item)

    EbonAPI.Bricks.tip(row, item.entry.name or "")
    GameTooltip:AddLine(state == "available" and L.LIBRARY_ROW_HINT
      or state == "owned" and L.LIBRARY_ROW_OWNED
      or L.LIBRARY_ROW_UNAVAILABLE, 1, 1, 1)
    GameTooltip:Show()
  end,
  onRowClick = function(_, item, mouseButton)
    if mouseButton ~= "RightButton" and LibraryState(item) == "available" then
      RequestFetch(item)
    end
  end,
  entryGroup = function(item) return item.entry.category end,
  bandLines = function(category)
    return {
      { string.format(L.ROUTES_CATEGORY_COUNT, Core.libraryCount(RT.GetRouteLibrary(), category)), 1, 1, 1 },
      { L.ROUTES_CATEGORY_OPEN_TOOLTIP, 0.8, 0.8, 0.8 },
    }
  end,
  onOpenGroup = function(category) RT.RequestRouteAvailability(category) end,
  createWindow = BrowserWindow("AutoCallboardLibraryWindow", "LIBRARY_WINDOW_TITLE", "TOPLEFT", "TOPRIGHT", 8),
})

local function RefreshIfShown(browser)
  if browser.IsShown() then
    browser.Refresh()
  end
end

RT.routesBrowser = routesBrowser
RT.libraryBrowser = libraryBrowser
RT.ToggleRoutesWindow = routesBrowser.Toggle

function RT.ToggleLibraryWindow()
  if not libraryBrowser.IsShown() then
    RT.RefreshHeldLibraryEntries()
  end

  libraryBrowser.Toggle()
end

function RT.RefreshRouteLibrary()
  RefreshIfShown(libraryBrowser)
end

function RT.RefreshRouteBrowsers()
  RefreshIfShown(routesBrowser)
  RefreshIfShown(libraryBrowser)
end
