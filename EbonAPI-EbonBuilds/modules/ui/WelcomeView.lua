EbonBuilds.WelcomeView = {}

local W = EbonBuilds.Widgets

local ICON          = "Interface\\Icons\\INV_Misc_Book_09"
local ICON_SIZE     = 64
local BUTTON_WIDTH  = 140
local BUTTON_HEIGHT = 28
local TOP           = 120

local page

local function Build(container)
    local width = EbonBuilds.MainWindow.VIEW_WIDTH
    page = W.Page(container, { spacing = 0 })
    W.Gap(page, width, TOP)
    W.Centered(page, width, ICON_SIZE):Add("icon", { icon = ICON, size = ICON_SIZE })
    W.Gap(page, width, 16)
    page:Add("text", { key = "WELCOME_TITLE", size = "large", width = width }).text:SetJustifyH("CENTER")
    W.Gap(page, width, 8)
    page:Add("text", { key = "WELCOME_BODY", size = "medium", width = width }).text:SetJustifyH("CENTER")
    W.Gap(page, width, 24)
    W.Kit("button", W.Centered(page, width, BUTTON_WIDTH), {
        key = "NEW_BUILD_BUTTON", width = BUTTON_WIDTH, height = BUTTON_HEIGHT,
        onClick = function() EbonBuilds.ViewRouter.Show("buildWizard") end,
    })
    W.Gap(page, width, 8)
    W.Kit("button", W.Centered(page, width, BUTTON_WIDTH), {
        key = "PLAYER_BUILDS", width = BUTTON_WIDTH, height = BUTTON_HEIGHT,
        onClick = function() EbonBuilds.ViewRouter.Show("publicBuilds") end,
    })
end

function EbonBuilds.WelcomeView.Mount(container)
    if not page then Build(container) end
    W.ShowPage(page)
end

function EbonBuilds.WelcomeView.Unmount()
    if page then page:Hide() end
end
