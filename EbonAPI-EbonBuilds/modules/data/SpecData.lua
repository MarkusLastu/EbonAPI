local NAMES = EbonBuilds.L.SPEC

local ICONS = {
    WARRIOR     = { "Interface\\Icons\\Ability_Rogue_Eviscerate",
                    "Interface\\Icons\\Ability_Warrior_InnerRage",
                    "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
    PALADIN     = { "Interface\\Icons\\Spell_Holy_HolyBolt",
                    "Interface\\Icons\\Spell_Holy_DevotionAura",
                    "Interface\\Icons\\Spell_Holy_AuraOfLight" },
    HUNTER      = { "Interface\\Icons\\Ability_Hunter_BeastTaming",
                    "Interface\\Icons\\Ability_Marksmanship",
                    "Interface\\Icons\\Ability_Hunter_SwiftStrike" },
    ROGUE       = { "Interface\\Icons\\Ability_Rogue_DeadlyBrew",
                    "Interface\\Icons\\Ability_BackStab",
                    "Interface\\Icons\\Ability_Stealth" },
    PRIEST      = { "Interface\\Icons\\Spell_Holy_WordFortitude",
                    "Interface\\Icons\\Spell_Holy_GuardianSpirit",
                    "Interface\\Icons\\Spell_Shadow_ShadowWordPain" },
    DEATHKNIGHT = { "Interface\\Icons\\Spell_Deathknight_BloodPresence",
                    "Interface\\Icons\\Spell_Deathknight_FrostPresence",
                    "Interface\\Icons\\Spell_Deathknight_UnholyPresence" },
    SHAMAN      = { "Interface\\Icons\\Spell_Nature_Lightning",
                    "Interface\\Icons\\Spell_Nature_LightningShield",
                    "Interface\\Icons\\Spell_Nature_MagicImmunity" },
    MAGE        = { "Interface\\Icons\\Spell_Holy_MagicalSentry",
                    "Interface\\Icons\\Spell_Fire_FireBolt02",
                    "Interface\\Icons\\Spell_Frost_FrostBolt02" },
    WARLOCK     = { "Interface\\Icons\\Spell_Shadow_DeathCoil",
                    "Interface\\Icons\\Spell_Shadow_Metamorphosis",
                    "Interface\\Icons\\Spell_Shadow_RainOfFire" },
    DRUID       = { "Interface\\Icons\\Spell_Nature_StarFall",
                    "Interface\\Icons\\Ability_Racial_BearForm",
                    "Interface\\Icons\\Spell_Nature_HealingTouch" },
}

EbonBuilds.SpecData = {}
for class, icons in pairs(ICONS) do
    local names = NAMES[class] or {}
    local specs = {}
    for i = 1, 3 do
        specs[i] = { name = names[i] or ("Spec " .. i), icon = icons[i] }
    end
    EbonBuilds.SpecData[class] = specs
end
