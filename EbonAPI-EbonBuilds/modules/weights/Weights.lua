EbonBuilds.Weights = {}

function EbonBuilds.Weights.Get(echoName)
    local weights = EbonBuilds.Build.GetActiveWeights()
    if not weights then return 0 end
    local w = weights[echoName]
    return type(w) == "number" and w or 0
end

function EbonBuilds.Weights.Set(echoName, value)
    if type(value) ~= "number" then return end
    local intVal = math.floor(value)
    if intVal < 0 then return end
    local weights = EbonBuilds.Build.GetActiveWeights()
    if not weights then return end
    if weights[echoName] == intVal then return end
    weights[echoName] = intVal
    if EbonBuilds.Automation and EbonBuilds.Automation.ResetPeakCache then
        EbonBuilds.Automation.ResetPeakCache()
    end
end
