EbonBuilds.BuildList = {}

local L = EbonBuilds.L
local W = EbonBuilds.Widgets

local MENU_ROW = 24

local menu
local scroll
local menuItems = {}
local cards     = {}

local function Open(entry)
    EbonBuilds.Build.SetActive(entry.build.id)
    EbonBuilds.ViewRouter.Show("buildOverview", { build = entry.build })
end

local CARD_STYLE = { small = true, onOpen = Open }

local function Entry(build, activeId)
    local specs = EbonBuilds.SpecData and EbonBuilds.SpecData[build.class]
    return {
        build     = build,
        class     = build.class,
        title     = build.title or L.UNTITLED,
        spec      = specs and specs[build.spec or 1],
        lockedIds = build.lockedEchoes or {},
        active    = build.id == activeId,
    }
end

local function Render()
    local builds   = EbonBuilds.Build.List()
    local activeId = EbonAPIEbonBuildsCharDB.activeBuildId
    local content  = scroll._content
    for i = 1, #builds do
        if not cards[i] then cards[i] = EbonBuilds.BuildDetail.Card(content, content.spec.width, CARD_STYLE) end
        EbonBuilds.BuildDetail.FillCard(cards[i], Entry(builds[i], activeId))
        cards[i]:Show()
    end
    for i = #builds + 1, #cards do cards[i]:Hide() end
    content:Layout()
end

EbonBuilds.BuildList.Refresh = Render

local function Reselect()
    menu:Select(menuItems[EbonBuilds.ViewRouter.Current()])
end

local function MenuItem(key, view, action)
    local item = {
        key = key,
        onClick = function(_, mouse)
            if mouse == "LeftButton" then action() end
            Reselect()
        end,
    }
    if view then menuItems[view] = item end
    return item
end

local function ShowView(name)
    return function() EbonBuilds.ViewRouter.Show(name) end
end

local function CreateMenu(column)
    local items = {
        MenuItem("SAVED_BUILDS",     "savedBuilds",  ShowView("savedBuilds")),
        MenuItem("PLAYER_BUILDS",    "publicBuilds", ShowView("publicBuilds")),
        MenuItem("NEW_BUILD_BUTTON", "buildWizard",  ShowView("buildWizard")),
    }
    return column:Add("list", {
        width = column.spec.width, height = #items * MENU_ROW, rowHeight = MENU_ROW, items = items,
    })
end

function EbonBuilds.BuildList.Init(column)
    menu = CreateMenu(column)
    EbonBuilds.ViewRouter.OnChange(Reselect)
    local height = column.spec.height - menu.spec.height - (column.spec.spacing or 0)
    scroll = W.Scroll(column, { layout = "VERTICAL", width = column.spec.width, height = height })
    W.ScrollSize(scroll, column.spec.width, height)

    Render()

    if EbonBuilds.Build and EbonBuilds.Build.OnActiveChanged then
        EbonBuilds.Build.OnActiveChanged(Render)
    end
end
