local ADDON_NAME = ...
local NS = SkillTreeAutoLoad

local Update = {}
NS.Update = Update

Update.URL = "https://github.com/Siphelis/SkillTreeAutoLoad/releases/latest"

function Update.GetAvailable()
    if not NS.api then return nil end
    return NS.api:AvailableUpdate()
end

local function OnUpdateAvailable(_, name)
    if name == "SkillTreeAutoLoad" then NS.UI.RefreshUpdateNotice() end
end

function Update.Init()
    if not NS.api then return end

    NS.api:Version(GetAddOnMetadata(ADDON_NAME, "Version"), Update.URL)
    NS.api:On("UPDATE_AVAILABLE", OnUpdateAvailable)
end
