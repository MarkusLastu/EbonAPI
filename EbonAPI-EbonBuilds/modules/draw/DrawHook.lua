local _, ns = ...

local DrawHook = {}
ns.DrawHook = DrawHook

local takers   = {}
local after    = { Show = {}, Hide = {}, UpdateSinglePerk = {}, ResetSelection = {} }
local original = {}
local installed = false

local function RunAfter(name, ...)
    local list = after[name]
    for i = 1, #list do
        ns.api:Guard("Draw.After." .. name, list[i], ...)
    end
end

function DrawHook.ShowNative(...)
    ns.api:Guard("PerkUI.Show", original.Show, ...)
    RunAfter("Show", ...)
end

local function Show(...)
    local choices = ...
    for i = 1, #takers do
        local kept = ns.api:Guard("Draw.Take", takers[i], choices)
        if kept then
            RunAfter("Show", ...)
            return
        end
    end
    DrawHook.ShowNative(...)
end

local function Wrap(ui, name)
    local orig = ui[name]
    original[name] = orig
    ui[name] = function(...)
        local a, b = ns.api:Guard("PerkUI." .. name, orig, ...)
        RunAfter(name, ...)
        return a, b
    end
end

function DrawHook.Install()
    if installed then return true end
    local ui = EbonAPI.Ebonhold.PerkUI()
    if not (ui and ui.Show) then return false end
    installed = true
    original.Show = ui.Show
    ui.Show = Show
    for name in pairs(after) do
        if name ~= "Show" and ui[name] then Wrap(ui, name) end
    end
    return true
end

function DrawHook.Take(fn)
    takers[#takers + 1] = fn
end

function DrawHook.After(name, fn)
    local list = after[name]
    if list then list[#list + 1] = fn end
end
