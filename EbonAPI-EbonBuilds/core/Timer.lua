local _, ns = ...

local Timer = {}
ns.Timer = Timer

local function OnUpdate(f, elapsed)
    f.left = f.left - elapsed
    if f.left > 0 then return end
    f:Hide()
    local fn = f.fn
    f.fn = nil
    if fn then ns.api:Guard(f.name, fn) end
end

function Timer.New(name)
    local f = CreateFrame("Frame")
    f:Hide()
    f.name = name
    f.left = 0
    f:SetScript("OnUpdate", OnUpdate)
    if ns.api then ns.api:Track(name, f) end
    return f
end

function Timer.Arm(t, delay, fn)
    t.left, t.fn = delay or 0, fn
    t:Show()
end

function Timer.Cancel(t)
    t.fn = nil
    t:Hide()
end

function Timer.IsArmed(t)
    return t:IsShown() and true or false
end
