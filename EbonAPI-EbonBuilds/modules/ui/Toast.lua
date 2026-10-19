EbonBuilds.Toast = {}

local L = EbonBuilds.L

local TOAST_W   = 520
local TOAST_PAD = 8
local TOAST_GAP = 4
local TOAST_TOP = 20
local TEXT_W    = TOAST_W - TOAST_PAD * 2
local ACTION_COLORS = {
    Banish = "|cffff4444", Reroll = "|cff44aaff",
    Freeze = "|cff44ccff", Select  = "|cff44ff44",
}
local function GetToastDuration()
    return (EbonAPIEbonBuildsDB.globalSettings and EbonAPIEbonBuildsDB.globalSettings.toastDuration) or 3
end
local QUALITY_HEX = EbonBuilds.Const.QUALITY_HEX

local queue   = {}
local frame
local elapsed = 0
local hovered = false
local shown   = { header = "", echo = "", footer = "" }

local function GetCharges()
    local rd = EbonAPI.State.GetRun()
    local banRemain    = (rd and rd.remainingBanishes) or 0
    local totalRerolls = (rd and rd.totalRerolls) or 0
    local usedRerolls  = (rd and rd.usedRerolls) or 0
    local totalFreezes = (rd and rd.totalFreezes) or 0
    local usedFreezes  = (rd and rd.usedFreezes) or 0
    return banRemain, totalRerolls - usedRerolls, totalFreezes - usedFreezes
end

local FormatScore = EbonBuilds.Widgets.FormatScore

local function Display(title, line, footer)
    shown.header, shown.echo, shown.footer = title or "", line or "", footer or ""
    frame:Refresh()
    frame:Show()
    elapsed = 0
end

local function ShowNext()
    if #queue == 0 then
        frame:Hide()
        return
    end

    local entry = table.remove(queue, 1)
    local colorKey = entry.action:match("^(%a+)") or entry.action
    local ac = ACTION_COLORS[colorKey] or "|cffffffff"

    local parts = {}
    for i, ch in ipairs(entry.choices) do
        if i > 1 then
            parts[#parts + 1] = "    "
        end
        local hex = QUALITY_HEX[ch.quality] or "ffffff"
        local isTarget = (ch.index == entry.targetIndex)
        if isTarget then
            parts[#parts + 1] = "|cffffff00>> |r"
        end
        parts[#parts + 1] = string.format("|cff%s%s (%s)|r", hex, ch.name, FormatScore(ch.score))
        if isTarget then
            parts[#parts + 1] = " |cffffff00<<|r"
        end
    end

    Display(ac .. string.format(L.TOAST_AUTOMATION, L.ACTION[entry.action] or entry.action) .. "|r",
        table.concat(parts), string.format(L.TOAST_CHARGES, GetCharges()))
    hovered = false
end

local function DismissCurrent()
    frame:Hide()
    ShowNext()
end

function EbonBuilds.Toast.ShowAutomationResult(scored, action, targetIndex)
    local entry = { action = action, targetIndex = targetIndex, choices = {} }
    for _, s in ipairs(scored) do
        entry.choices[#entry.choices + 1] = {
            index   = s.index,
            name    = s.name,
            quality = s.quality,
            score   = s.score,
        }
    end
    table.insert(queue, entry)
    if not frame:IsShown() then ShowNext() end
end

function EbonBuilds.Toast.ShowLive(title, line, footer)
    if not frame then return false end
    Display(title, line, footer)
    return true
end

local function Line(f, key, size, color)
    local line = f:Add("text", {
        size = size, color = color, width = TEXT_W,
        text = function() return shown[key] end,
        hidden = function() return shown[key] == "" end,
    })
    line.text:SetJustifyH("CENTER")
end

local function BuildFrame()
    local f = EbonBuilds.Widgets.Kit("bar", UIParent, {
        frame = "SMALL", layout = "VERTICAL", spacing = TOAST_GAP, padding = TOAST_PAD, width = TOAST_W,
    })
    if EbonBuilds.api then EbonBuilds.api:Track("Toast", f) end
    f:SetPoint("TOP", UIParent, "TOP", 0, -TOAST_TOP)
    f:SetFrameStrata("TOOLTIP")
    f:Hide()

    f:EnableMouse(true)
    f:SetScript("OnMouseDown", function() DismissCurrent() end)

    f:SetScript("OnEnter", function() hovered = true end)
    f:SetScript("OnLeave", function() hovered = false; elapsed = 0 end)

    Line(f, "header", "medium", "heading")
    Line(f, "echo")
    Line(f, "footer")

    f:SetScript("OnUpdate", function(self, dt)
        if hovered then
            elapsed = 0
            return
        end
        elapsed = elapsed + dt
        if elapsed >= GetToastDuration() then
            DismissCurrent()
        end
    end)

    return f
end

function EbonBuilds.Toast.Init()
    frame = BuildFrame()
end
