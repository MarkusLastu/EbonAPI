EbonBuilds.BuildTabs = {}

local W = EbonBuilds.Widgets

local CONTENT_INSET = 6
local FOOTER_GAP    = 6
local BUTTON_WIDTH  = 90

local viewFrame
local tabs
local contentArea
local state = { context = nil }

function EbonBuilds.BuildTabs.OnBuildSaved()
    state.context = { mode = "edit", build = EbonBuilds.Build.GetActive() }
end

local PANES = {
    overview   = EbonBuilds.BuildForm,
    echoes     = EbonBuilds.WeightsView,
    bonus      = EbonBuilds.BonusView,
    automation = EbonBuilds.SettingsView,
}

local function ShowPane(id)
    for key, pane in pairs(PANES) do
        if key ~= id then pane.Unmount() end
    end
    if id == "overview" then
        EbonBuilds.BuildForm.Mount(contentArea, state.context)
    else
        PANES[id].Mount(contentArea)
    end
end

local function BuildViewFrame(container)
    local width = EbonBuilds.MainWindow.VIEW_WIDTH
    local f = W.Page(container, { spacing = 0 })

    tabs = W.Tabs(f, {
        { "overview",   "TAB_OVERVIEW" },
        { "echoes",     "TAB_ECHOES" },
        { "bonus",      "TAB_BONUS" },
        { "automation", "TAB_AUTOMATION" },
    }, ShowPane)

    contentArea = f:Add("bar", {
        frame = "SMALL", layout = "VERTICAL", spacing = 0, padding = CONTENT_INSET, width = width, height = 1,
    })

    local footer = f:Add("bar", { spacing = FOOTER_GAP })
    W.Kit("button", footer, {
        key = "EXPORT", width = BUTTON_WIDTH,
        onClick = function()
            local build = EbonBuilds.Build.GetActive()
            if build then
                EbonBuilds.ExportImport.ShowExportDialog(build)
            end
        end,
    })
    W.Gap(footer, width - BUTTON_WIDTH * 3 - FOOTER_GAP * 3, 1)
    W.Kit("button", footer, {
        key = "CANCEL", width = BUTTON_WIDTH,
        onClick = function() EbonBuilds.BuildForm.Cancel() end,
    })
    W.Kit("button", footer, {
        key = "SAVE", width = BUTTON_WIDTH,
        onClick = function() EbonBuilds.BuildForm.Save() end,
    })

    contentArea.spec.height = f.spec.height - tabs:GetHeight() - footer:GetHeight() - FOOTER_GAP
    contentArea:SetHeight(contentArea.spec.height)
    f:Layout()
    return f
end

function EbonBuilds.BuildTabs.ContentWidth()
    return EbonBuilds.MainWindow.VIEW_WIDTH - CONTENT_INSET * 2
end

local view = {}

function view.Show(container, context)
    viewFrame = viewFrame or BuildViewFrame(container)
    state.context = context or { mode = "create" }
    W.ShowPage(viewFrame)
    tabs:Select("overview")
end

function view.Hide()
    EbonBuilds.Draft.isEditing = false
    EbonBuilds.Draft.weights = nil
    EbonBuilds.Draft.wizardPrefill = nil
    for _, pane in pairs(PANES) do pane.Unmount() end
    if viewFrame then viewFrame:Hide() end
end

function EbonBuilds.BuildTabs.Init()
    EbonBuilds.ViewRouter.Register("buildTabs", view)
end
