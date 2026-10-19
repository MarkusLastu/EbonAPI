local _, ns = ...

local EchoStars = {}
ns.EchoStars = EchoStars

local L = ns.L
local Stars = ns.Stars
local Rating = ns.Rating

local TIP_SIZE, TIP_GAP = 12, 1
local CARD_SIZE, CARD_GAP, CARD_DROP = 14, 2, -12

local SPACER = "|TInterface\\AddOns\\ProjectEbonhold\\modules\\collections\\Interface\\Common\\spacer:" .. TIP_SIZE .. ":" .. Stars.Width(TIP_SIZE, TIP_GAP) .. "|t"

local tipRow = nil
local decorated = false
local interest = nil
local lines = setmetatable({}, { __mode = "k" })

local function Forget()
    if decorated then
        decorated = false
        if tipRow then Stars.Set(tipRow, nil) end
    end
end

local function PartnerLine(partners)
    local line = lines[partners]
    if line then return line end
    local names = {}
    for i = 1, #partners do
        names[i] = GetSpellInfo(partners[i]) or tostring(partners[i])
    end
    line = string.format(L.GOES_WITH, table.concat(names, ", "))
    lines[partners] = line
    return line
end

local function Decorate(button)
    if decorated then return end
    local spellId = button.spellId
    if not spellId or not GameTooltip:IsOwned(button) then return end
    local hint = ns.Wishlist.Hint(button)
    local stars = Rating.Stars(spellId, true)
    if not hint and not stars then return end
    decorated = true

    if hint then GameTooltip:AddLine(hint, 0.4, 0.4, 0.4) end
    if stars then
        interest = interest or string.format(L.INTEREST_FOR, ns.ClassName(ns.Build.PlayerClassToken()))
        GameTooltip:AddDoubleLine(interest, SPACER, 1, 0.82, 0.1, 1, 1, 1)
        if not tipRow then tipRow = Stars.Create(GameTooltip, TIP_SIZE, TIP_GAP, "ARTWORK") end
        Stars.Place(tipRow, "CENTER", _G["GameTooltipTextRight" .. GameTooltip:NumLines()], "CENTER", 0, 0)
        Stars.Set(tipRow, stars)

        local partners = Rating.Partners(spellId)
        if partners then GameTooltip:AddLine(PartnerLine(partners), 0.5, 0.75, 1, true) end
    end
    GameTooltip:Show()
end

local function OnJournalButton(button)
    ns.api:Guard("echo_stars", Decorate, button)
end

local cards, cardCount = {}, -1

local function DecorateCards()
    local root = EbonAPI.Ebonhold.PerkFrame()
    if not root or not root:IsShown() then return end
    local n = root:GetNumChildren()
    if n ~= cardCount then
        cardCount = n
        cards = { root:GetChildren() }
    end
    for i = 1, #cards do
        local f = cards[i]
        local row = f._ebStars
        if f.inUse and f._spellId and f.iconFrame then
            if not row then
                local host = CreateFrame("Frame", nil, f.iconFrame)
                host:SetFrameLevel(f.iconFrame:GetFrameLevel() + 6)
                host:SetAllPoints(f.iconFrame)
                row = Stars.Create(host, CARD_SIZE, CARD_GAP, "OVERLAY")
                Stars.Place(row, "TOP", host, "BOTTOM", 0, CARD_DROP)
                f._ebStars = row
            end
            Stars.Set(row, Rating.Stars(f._spellId, true))
        elseif row then
            Stars.Set(row, nil)
        end
    end
end

function EchoStars.Init()
    hooksecurefunc(GameTooltip, "SetOwner", Forget)
    ns.OnJournalEnter = OnJournalButton
    ns.OnJournalClick = OnJournalButton
    ns.DrawHook.After("Show", DecorateCards)
    ns.DrawHook.After("UpdateSinglePerk", DecorateCards)
end
