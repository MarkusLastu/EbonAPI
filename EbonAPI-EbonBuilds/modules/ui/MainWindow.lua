EbonBuilds.MainWindow = {}

local L = EbonBuilds.L

local WINDOW_WIDTH  = 800
local WINDOW_HEIGHT = 550
local PADDING       = 12
local LEFT_WIDTH    = 200
local COLUMN_GAP    = 6
local MENU_GAP      = 4
local GEAR_ICON     = "Interface\\Icons\\Trade_Engineering"

EbonBuilds.MainWindow.VIEW_WIDTH = WINDOW_WIDTH - PADDING * 2 - LEFT_WIDTH - COLUMN_GAP
EbonBuilds.MainWindow.HEIGHT     = WINDOW_HEIGHT

local function Settings()
    return EbonAPIEbonBuildsDB.globalSettings
end

function EbonBuilds.MainWindow.RegisterOptions()
    EbonBuilds.api:Options({
        type = "group",
        name = EbonBuilds.NAME,
        get = function(info) return Settings()[info[#info]] end,
        set = function(info, value) Settings()[info[#info]] = value end,
        args = {
            evalDelay = {
                type = "range", order = 1, min = 0.1, max = 3, step = 0.1,
                name = function() return L.SETTINGS_DELAY end,
                desc = function() return L.SETTINGS_DELAY_HINT end,
            },
            toastDuration = {
                type = "range", order = 2, min = 0.1, max = 3, step = 0.1,
                name = function() return L.SETTINGS_TOAST end,
            },
        },
    })
end

local function StartPoint()
    local pos = EbonAPIEbonBuildsDB.windowPos
    if pos and pos.point then
        return { pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0 }
    end
    return nil
end

local function BuildFrame()
    local frame = EbonBuilds.api:Window("main", {
        text    = EbonBuilds.NAME,
        width   = WINDOW_WIDTH,
        height  = WINDOW_HEIGHT,
        layout  = "HORIZONTAL",
        spacing = COLUMN_GAP,
        padding = PADDING,
        point   = StartPoint(),
        buttons = {
            {
                icon = GEAR_ICON, key = "SETTINGS_TITLE", tip = function() end,
                onClick = function() EbonBuilds.api:OpenOptions() end,
            },
        },
    })

    frame:HookScript("OnHide", function()
        if EbonBuilds.SessionHistory and EbonBuilds.SessionHistory.Hide then
            EbonBuilds.SessionHistory.Hide()
        end
    end)

    return frame
end

local function Build()
    if EbonBuilds.MainWindow._frame then return end

    local frame  = BuildFrame()
    local height = WINDOW_HEIGHT - frame.head:GetHeight() - PADDING
    local left   = frame:Add("bar", { layout = "VERTICAL", spacing = MENU_GAP, width = LEFT_WIDTH, height = height })
    local right  = frame:Add("bar", { layout = "VERTICAL", spacing = 0, width = EbonBuilds.MainWindow.VIEW_WIDTH, height = height })

    EbonBuilds.MainWindow._frame = frame

    EbonBuilds.ViewRouter.SetContainer(right)
    EbonBuilds.BuildList.Init(left)
    EbonBuilds.WeightsView.Init()
    EbonBuilds.BuildForm.Init()
    EbonBuilds.BuildTabs.Init()
    EbonBuilds.BuildOverview.Init()
    EbonBuilds.SavedBuildsView.Init()
    EbonBuilds.BuildWizard.Init()

    EbonBuilds.ViewRouter.Register("welcome", {
        Show = function(container, _)
            EbonBuilds.WelcomeView.Mount(container)
        end,
        Hide = function()
            EbonBuilds.WelcomeView.Unmount()
        end,
    })

    EbonBuilds.ViewRouter.Register("publicBuilds", {
        Show = function(container, _)
            EbonBuilds.PublicBuildsView.Mount(container)
        end,
        Hide = function()
            EbonBuilds.PublicBuildsView.Unmount()
        end,
    })
end

function EbonBuilds.MainWindow._ShowInitialView()
    local active = EbonBuilds.Build.GetActive()
    if active then
        EbonBuilds.ViewRouter.Show("buildOverview", { build = active })
    else
        EbonBuilds.ViewRouter.Show("welcome")
    end
end

_G["SLASH_" .. EbonBuilds.NAME .. "1"] = "/ebb"
_G["SLASH_" .. EbonBuilds.NAME .. "2"] = "/ebonbuilds"
SlashCmdList[EbonBuilds.NAME] = function(input)
    EbonBuilds.MainWindow.Toggle()
end

function EbonBuilds.MainWindow.Toggle()
    Build()
    local frame = EbonBuilds.MainWindow._frame
    if frame:IsShown() then
        frame:Close()
    else
        EbonBuilds.MainWindow._ShowInitialView()
        frame:Show()
    end
end
