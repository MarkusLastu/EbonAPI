local RT = AutoCallboardRuntime

RT.updateUrl = "https://github.com/Siphelis/autocallboard/releases/latest"
RT.licenseUrl = "https://github.com/Siphelis/autocallboard/blob/main/LICENSE"

local function RefreshNotice()
  RT.RefreshUpdateNotice()
end

function RT.GetAvailableUpdate()
  return RT.api:AvailableUpdate()
end

function RT.OpenUpdatePage()
  if RT.OpenLink(RT.updateUrl) then
    return true
  end

  RT.api:Report(RT.api:Problem("UPDATE.OPEN_LINK_FAILED", { url = RT.updateUrl }))
  RT.ShowAddonHelp("about")

  return false
end

local function OnUpdateAvailable(_, name)
  if name == "AutoCallboard" and RT.api:IsReady() then
    RefreshNotice()
  end
end

function RT.InitVersionWatch()
  RT.api:Version(RT.GetAddonVersion(), RT.updateUrl)
  RT.api:On("UPDATE_AVAILABLE", OnUpdateAvailable)
  RT.api:On("READY", RefreshNotice)
end
