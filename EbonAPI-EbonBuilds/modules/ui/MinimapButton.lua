EbonBuilds.MinimapButton = {}

function EbonBuilds.MinimapButton.Init()
    EbonBuilds.api:MinimapButton({
        angle  = EbonAPIEbonBuildsDB.minimapAngle,
        text   = EbonBuilds.NAME,
        tipKey = "MINIMAP_TIP",
        onClick = function(_, mouseButton)
            if mouseButton == "LeftButton" then
                EbonBuilds.MainWindow.Toggle()
            end
        end,
    })
end
