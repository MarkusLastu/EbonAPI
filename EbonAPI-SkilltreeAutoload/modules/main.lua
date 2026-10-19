local ADDON_NAME = ...
local NS = SkillTreeAutoLoad

local function Step(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        NS.api:Report(NS.api:Problem("INIT.STEP_FAILED", { part = name, detail = tostring(err) }))
    end
    return ok
end

local function Unavailable(missing)
    NS.api:Degrade(NS.api:Problem("IMPORT.UNAVAILABLE", { missing = missing }))
end

-- The module loads on demand after the login: the sticky READY event stands in for PLAYER_LOGIN.
local function Login()
    Step("Data", NS.Data.Init)
    Step("Update", NS.Update.Init)
    if not EbonAPI.Ebonhold.SkillTreeFrame() then
        Unavailable("ProjectEbonhold")
        return
    end
    Step("Bridge", NS.Bridge.Init)
    Step("UI", NS.UI.Init)
    if not NS.Core.CanActivate() then
        Unavailable("the activation functions of ProjectEbonhold")
    end
end

local function Prewarm()
    if NS.UI and NS.UI.Prewarm then Step("Prewarm", NS.UI.Prewarm) end
end

local frame = CreateFrame("Frame")
NS.api:Track("Events", frame)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON_NAME then Step("Data", NS.Data.Init) end
        return
    end

    Prewarm()
end)

NS.api:On("READY", Login)
NS.api:On("READY", Prewarm)
