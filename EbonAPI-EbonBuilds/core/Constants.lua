local folder, ns = ...
EbonBuilds = ns

ns.NAME = "EbonBuilds"
ns.FOLDER = folder
ns.api = EbonAPI and EbonAPI:NewAddon(ns.NAME, 2, 1, { icon = "Spell_Shadow_SoulGem" }) or nil

local Const = {}
EbonBuilds.Const = Const

Const.QUALITY_RGB = {
    [0] = { 1.0, 1.0, 1.0 },
    [1] = { 30/255, 1.0, 0.0 },
    [2] = { 0.0, 112/255, 221/255 },
    [3] = { 163/255, 53/255, 238/255 },
    [4] = { 1.0, 128/255, 0.0 },
}

Const.QUALITY_HEX = {
    [0] = "ffffff", [1] = "19ff19", [2] = "0066ff", [3] = "cc66ff", [4] = "ff8000",
}

local QUALITY_FALLBACK = { [0] = "Common", "Uncommon", "Rare", "Epic", "Legendary" }
Const.QUALITY_NAME = {}
for q = 0, 4 do
    Const.QUALITY_NAME[q] = _G["ITEM_QUALITY" .. (q + 1) .. "_DESC"] or QUALITY_FALLBACK[q]
end

Const.CLASS_RGB = {
    WARRIOR     = { 0.78, 0.61, 0.43 },
    PALADIN     = { 0.96, 0.55, 0.73 },
    HUNTER      = { 0.67, 0.83, 0.45 },
    ROGUE       = { 1.0,  0.96, 0.41 },
    PRIEST      = { 1.0,  1.0,  1.0  },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    SHAMAN      = { 0.0,  0.44, 0.87 },
    MAGE        = { 0.41, 0.8,  0.94 },
    WARLOCK     = { 0.58, 0.51, 0.79 },
    DRUID       = { 1.0,  0.49, 0.04 },
}

Const.CLASS_BITS = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16,
    DEATHKNIGHT = 32, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024,
}

Const.CLASS_TEXTURE = "Interface\\TargetingFrame\\UI-Classes-Circles"

Const.SAVED_SLOTS = 10

Const.BUILD_LOCKED_SLOTS = 6

Const.FAMILY_MAP = {
    Tank = "Tank", Survivability = "Survivability", Healer = "Healer",
    Caster = "Caster", ["Caster DPS"] = "Caster",
    Melee  = "Melee",  ["Melee DPS"]  = "Melee",
    Ranged = "Ranged", ["Ranged DPS"] = "Ranged",
    None   = "No family",
}

Const.FAMILIES = { "Tank", "Survivability", "Healer", "Caster", "Melee", "Ranged", "No family" }
