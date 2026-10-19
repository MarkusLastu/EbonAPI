local _, ns = ...

local Events = {}
ns.Events = Events

local frame = CreateFrame("Frame")
if ns.api then ns.api:Track("Events", frame) end

local handlers = {}

local function IsInternal(event)
    return event:sub(1, 3) == "EB_"
end

local function Dispatch(event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        ns.api:Guard(event, list[i], ...)
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    Dispatch(event, ...)
end)

function Events.On(event, fn, name)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        if not IsInternal(event) then frame:RegisterEvent(event) end
    end
    list[#list + 1] = fn
    if ns.api then ns.api:TrackFunction(name or event, fn) end
end

function Events.Off(event, fn)
    local list = handlers[event]
    if not list then return end
    local kept = {}
    for i = 1, #list do
        if list[i] ~= fn then kept[#kept + 1] = list[i] end
    end
    if #kept == 0 then
        handlers[event] = nil
        if not IsInternal(event) then frame:UnregisterEvent(event) end
    else
        handlers[event] = kept
    end
end

function Events.Fire(event, ...)
    Dispatch(event, ...)
end
