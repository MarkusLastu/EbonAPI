local OnAddonLoaded

OnAddonLoaded = function(addonName)
    if addonName ~= EbonBuilds.FOLDER then return end
    EbonBuilds.Events.Off("ADDON_LOADED", OnAddonLoaded)

    if not EbonAPI.Ebonhold.IsPresent() then
        return
    end

    EbonAPIEbonBuildsDB = EbonAPIEbonBuildsDB or {
        builds        = {},
        minimapAngle  = 220,
        globalSettings = {
            evalDelay     = 2,
            toastDuration = 3,
        },
    }
    EbonAPIEbonBuildsDB.minimapAngle = EbonAPIEbonBuildsDB.minimapAngle or 220
    EbonAPIEbonBuildsDB.globalSettings = EbonAPIEbonBuildsDB.globalSettings or {}
    EbonAPIEbonBuildsDB.globalSettings.evalDelay     = EbonAPIEbonBuildsDB.globalSettings.evalDelay     or 2
    EbonAPIEbonBuildsDB.globalSettings.toastDuration = EbonAPIEbonBuildsDB.globalSettings.toastDuration or 3

    EbonAPIEbonBuildsCharDB = EbonAPIEbonBuildsCharDB or {
        activeBuildId = nil,
    }

    local steps = {
        { "Build.Migrate",        function() EbonBuilds.Build.Migrate()        end },
        { "Options",              function() EbonBuilds.MainWindow.RegisterOptions() end },
        { "Session",              function() EbonBuilds.Session.Init()         end },
        { "SessionHistory",       function() EbonBuilds.SessionHistory.Init()  end },
        { "Protocol",             function() EbonBuilds.Protocol.Init()        end },
        { "Matrix",               function() EbonBuilds.Matrix.Init()          end },
        { "Profiles",             function() EbonBuilds.Profiles.Init()        end },
        { "Toast",                function() EbonBuilds.Toast.Init()           end },
        { "MinimapButton",        function() EbonBuilds.MinimapButton.Init()   end },
        { "Automation",           function() EbonBuilds.Automation.Init()      end },
        { "EchoStars",            function() EbonBuilds.EchoStars.Init()       end },
        { "Sync",                 function() EbonBuilds.Sync.Init()            end },
    }

    for i = 1, #steps do
        EbonBuilds.api:Guard("Init." .. steps[i][1], steps[i][2])
    end
end

EbonBuilds.Events.On("ADDON_LOADED", OnAddonLoaded, "Boot")
