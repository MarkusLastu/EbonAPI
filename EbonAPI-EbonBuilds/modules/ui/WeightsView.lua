EbonBuilds.WeightsView = {}

local L = EbonBuilds.L

local W = EbonBuilds.Widgets
local PADDING = 10
local GAP     = 4

local viewFrame

local function HeaderText()
    local build = EbonBuilds.Build.GetActive()
    if build then
        return string.format(L.ECHO_WEIGHTS_FOR, build.title or "")
    end
    return L.ECHO_WEIGHTS
end

local function BuildViewFrame(container)
    local f = W.Page(container, { padding = PADDING, spacing = GAP })
    f._header = f:Add("text", { size = "medium", width = f.spec.width - PADDING * 2, text = HeaderText })
    return f
end

local function RefreshHeader()
    if not viewFrame then return end
    viewFrame._header:Refresh()
end

function EbonBuilds.WeightsView.Mount(container)
    if not viewFrame then
        viewFrame = BuildViewFrame(container)
        EbonBuilds.Filters.Init(viewFrame)
        EbonBuilds.EchoTable.Init(viewFrame)
    end
    RefreshHeader()
    W.ShowPage(viewFrame)
    EbonBuilds.Filters.FocusSearch()
end

function EbonBuilds.WeightsView.Unmount()
    if viewFrame then viewFrame:Hide() end
end

function EbonBuilds.WeightsView.Init()
    if EbonBuilds.Build and EbonBuilds.Build.OnActiveChanged then
        EbonBuilds.Build.OnActiveChanged(RefreshHeader)
    end
end
