EbonBuilds.ViewRouter = {}

local views       = {}
local currentName = nil
local container   = nil
local onChange    = nil

function EbonBuilds.ViewRouter.OnChange(fn)
    onChange = fn
end

function EbonBuilds.ViewRouter.SetContainer(frame)
    container = frame
end

function EbonBuilds.ViewRouter.Register(name, view)
    views[name] = view
end

function EbonBuilds.ViewRouter.Show(name, context)
    if not container then return end
    local view = views[name]
    if not view then return end

    if currentName and currentName ~= name then
        local prev = views[currentName]
        if prev and prev.Hide then prev.Hide() end
    end
    currentName = name
    view.Show(container, context)
    if onChange then onChange(name) end
end

function EbonBuilds.ViewRouter.Current()
    return currentName
end
