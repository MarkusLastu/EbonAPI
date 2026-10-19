local _, ns = ...

local C = {
    GOLD  = "|cffFFD100",
    RED   = "|cffff5555",
    GREEN = "|cff19ff19",
    GREY  = "|cff888888",
    R     = "|r",
}
ns.C = C
local GOLD, RED, GREEN, GREY, R = C.GOLD, C.RED, C.GREEN, C.GREY, C.R

local L = {}

L.YES    = YES    or "Yes"
L.NO     = NO     or "No"
L.CANCEL = CANCEL or "Cancel"
L.DELETE = DELETE or "Delete"

function ns.ClassName(token)
    local names = LOCALIZED_CLASS_NAMES_MALE
    return (token and names and names[token]) or token or ns.L.UNKNOWN
end

L.PLURAL             = "s"

L.REROLL             = "Reroll (Orb: %s)"
L.REROLL_BUSY        = "Rerolling..."
L.REROLL_TITLE       = "Reroll with an Orb"
L.REROLL_BODY        = "Takes %s and forgets it again for a fresh draw."
L.REROLL_COST        = "Cost: " .. GOLD .. "%d Orb%s" .. R .. "   Held: " .. GOLD .. "%d" .. R

L.TOGGLE             = "Hunt"
L.HUNT               = "Hunt (%d)"
L.HUNT_MULT          = "Hunt (%d) x%d"
L.HUNT_STOP          = "Stop (%d/%d)"
L.HUNT_TITLE         = "Hunt for Echoes"
L.HUNT_RUNNING       = "Hunt in progress"
L.HUNT_PROGRESS      = "%d of %d orbs spent, %d per draw."
L.HUNT_CLICK_STOP    = "Click to stop."
L.HUNT_BODY          = "Rerolls until one of your %d armed Echo(es) is dealt."
L.HUNT_BODY_COST     = "Cost: " .. GOLD .. "%d orb(s)" .. R .. " per draw - %d draw(s) for "
                       .. GOLD .. "%d orb(s)" .. R .. "."
L.HUNT_BODY_MANUAL   = "The Echo it finds is never taken for you."
L.HUNT_BODY_HINT     = "The cost follows the game's own quality slider, read from your last orb spend."

L.RARITY_TITLE       = "Rarity sought"
L.RARITY_BODY        = "For each armed Echo, the lowest rarity the hunt will stop on."
L.RARITY_HINT        = "Most Echoes exist in several rarities. A hunt accepts them all unless "
                       .. "you say otherwise here."
L.RARITY_ANY         = "Any rarity"
L.RARITY_MIN         = "%s and better"

L.BUDGET             = "Orbs to spend: " .. GOLD .. "%d" .. R
L.BUDGET_DRAWS       = "Orbs to spend: " .. GOLD .. "%d" .. R .. "  " .. GREY .. "(%d draw%s at %d)" .. R

L.BUSY               = "A reroll is already in progress."
L.NO_CHOICE          = "No Echo choice on the table."
L.PICK_IN_FLIGHT     = "A pick is already in flight."
L.NONE_FORGETTABLE   = "None of these cards can be forgotten again."
L.CHARGES_UNKNOWN    = "Still waiting on your Orb count."
L.NOT_ENOUGH_ORBS    = "A draw costs %d orbs and you hold %d."
L.HUNT_RUNNING_ALREADY = "A hunt is already running."
L.NOTHING_ARMED      = "No Echo armed. Ctrl+click one in the Echoes journal."
L.HUNT_MARK          = "Ctrl+click: hunt this Echo"
L.HUNT_UNMARK        = "Ctrl+click: stop hunting"
L.AUTO_ACCEPT_ON     = "Turn Ebonhold's \"auto-accept loadout echoes\" off before hunting."
L.BUDGET_TOO_LOW     = "Budget too low: one draw costs %d orbs, raise the slider."

L.HUNT_STARTED       = "Hunt started: %d Echo(es) wanted, up to " .. GOLD .. "%d orb%s" .. R
                       .. " - %d draw%s at " .. GOLD .. "%d" .. R .. " each."
L.HUNT_SPENT         = " " .. GREY .. "(%d orb%s spent)" .. R
L.HUNT_FOUND         = GREEN .. "Found:" .. R .. " %s " .. GREY .. "- yours to pick." .. R
L.HUNT_BUDGET_DONE   = "Budget spent, hunt finished."
L.HUNT_NO_ORBS       = RED .. "Not enough orbs left (%d per draw), hunt finished." .. R
L.HUNT_STOPPED       = "Hunt stopped."
L.HUNT_INTERRUPTED   = RED .. "Hunt interrupted." .. R
L.HUNT_BEFORE_SPEND  = RED .. "Hunt interrupted before the spend." .. R
L.HUNT_WENT_PERMANENT = RED .. "Hunt stopped: the Echo taken came back permanent." .. R
L.HUNT_SPEND_FAILED  = RED .. "Hunt stopped: the spend failed." .. R

L.LIVE_TITLE         = "Hunt: |cffffffff%d/%d|r orb%s spent"
L.LIVE_WANTED        = GREY .. "Looking for:" .. R .. " %s"
L.LIVE_WANTED_MIN    = "%s (%s+)"

L.PICK_TIMED_OUT     = "The pick timed out - no orb was spent."
L.WENT_PERMANENT     = RED .. "%s came back permanent, so it cannot be forgotten - no orb was "
                       .. "spent. It is yours to keep." .. R
L.THAT_ECHO          = "That Echo"
L.NO_PERK_SYSTEM     = "Project Ebonhold's perk system was not found - the panel stays hidden."
L.NO_JOURNAL         = "ProjectEbonhold's Echo journal was not found - Echoes cannot be marked for a hunt."

L.GUARD_BODY         = "Holds the automatic pick off, so a draw is yours to hunt on."
L.GUARD_ON           = "On. Click to turn it off."
L.GUARD_OFF          = "Off. Click to turn it on."
L.HUNT_STOPPED_CLICK = "Hunt stopped: you took a card yourself."

L.ALL                = "All"
L.UNTITLED           = "Untitled"
L.UNKNOWN            = "Unknown"
L.SAVE               = "Save"
L.EXPORT             = "Export"
L.IMPORT             = "Import"
L.RELOAD             = "Reload"
L.NEXT               = "Next"
L.PREVIOUS           = "Previous"
L.BACK               = "Back"
L.REMOVE             = "Remove"
L.RANDOM             = "Random"
L.TITLE_LABEL        = "Title:"
L.DESCRIPTION_LABEL  = "Description:"
L.LOCKED_ECHOES      = "Locked Echoes:"
L.BUILD_META         = "by %s | %s | %s"
L.SPEC_N             = "Spec %d"
L.LOCKED             = "Locked"
L.BANNED             = "Banned"

L.FAMILY = {
    Tank          = "Tank",
    Survivability = "Survivability",
    Healer        = "Healer",
    Caster        = "Caster",
    Melee         = "Melee",
    Ranged        = "Ranged",
    ["No family"] = "No family",
}
L.FAMILY_LONG = {
    Tank          = "Tank",
    Survivability = "Survivability",
    Healer        = "Healer",
    Caster        = "Caster DPS",
    Melee         = "Melee DPS",
    Ranged        = "Ranged DPS",
}

L.ACTION = {
    Select            = "Select",
    ["Select (Locked)"] = "Select (Locked)",
    Banish            = "Banish",
    Reroll            = "Reroll",
    Freeze            = "Freeze",
}

L.SPEC = {
    WARRIOR     = { "Arms", "Fury", "Protection" },
    PALADIN     = { "Holy", "Protection", "Retribution" },
    HUNTER      = { "Beast Mastery", "Marksmanship", "Survival" },
    ROGUE       = { "Assassination", "Combat", "Subtlety" },
    PRIEST      = { "Discipline", "Holy", "Shadow" },
    DEATHKNIGHT = { "Blood", "Frost", "Unholy" },
    SHAMAN      = { "Elemental", "Enhancement", "Restoration" },
    MAGE        = { "Arcane", "Fire", "Frost" },
    WARLOCK     = { "Affliction", "Demonology", "Destruction" },
    DRUID       = { "Balance", "Feral", "Restoration" },
}

L.SAVED_BUILDS       = "Saved Builds"
L.PLAYER_BUILDS      = "Player Builds"
L.IMPORT_BUILD       = "Import Build"
L.NEW_BUILD_BUTTON   = "+ New Build"
L.WELCOME_TITLE      = "No Builds Yet"
L.WELCOME_BODY       = "Create your first build or browse public builds."
L.MINIMAP_TIP        = "Click to open configuration"

L.SETTINGS_TITLE     = "EbonBuilds Settings"
L.SETTINGS_DELAY     = "Action delay:"
L.SETTINGS_DELAY_HINT = "Very low values may cause the addon to malfunction."
L.SETTINGS_TOAST     = "Toast duration:"


L.TAB_OVERVIEW       = "Overview"
L.TAB_ECHOES         = "Echoes"
L.TAB_BONUS          = "Bonus"
L.TAB_AUTOMATION     = "Automation"
L.TAB_STATS          = "Stats"
L.TAB_MISSING        = "Missing"
L.TAB_LOGBOOK        = "Logbook"

L.FORM_HEADER        = "Build"
L.FORM_CLASS         = "Class:"
L.FORM_SPEC          = "Spec:"
L.FORM_DESCRIPTION_HINT = "Explain your build strategy here. Use the Echoes and Bonus tabs to configure weights."
L.INSERT_LINK_BUTTON = "+ Insert Echo Link"
L.INSERT_LINK_BODY   = "Inserts a clickable echo reference into the description."
L.INSERT_LINK_HINT1  = "To configure echo weights and bonuses for this build,"
L.INSERT_LINK_HINT2  = "use the Echoes and Bonus tabs after saving."

L.BONUS_HEADER       = "Bonus"
L.BONUS_QUALITY      = "Quality Bonus:"
L.BONUS_FAMILY       = "Family Bonus:"
L.BONUS_NOVELTY      = "Novelty Bonus:"
L.BONUS_MODE_HINT    = "Use + to add the value, |cff19ff19x|r to multiply. Below 1 in |cff19ff19x|r mode reduces the score."
L.BONUS_NOVELTY_HINT = "Unique echoes (seen for the first time) gain this bonus."
L.BONUS_VALUE        = "Value:"

L.ECHO_WEIGHTS       = "Echo Weights"
L.ECHO_WEIGHTS_FOR   = "Echo Weights - %s"
L.COL_NAME           = "Name"
L.COL_WEIGHT         = "Weight"
L.ALL_FAMILIES       = "All families"
L.FAMILIES_N         = "Families (%d)"
L.SHOW_ALL_CLASSES   = "Show all classes"
L.PICK_ECHO          = "Pick an Echo"

L.AUTOMATION_HEADER  = "Automation"
L.BANISH_PROTECTION  = "Banish Protection:"
L.BANISH_PROTECTION_HINT = "Checked families are protected from banish."
L.ALL_PROTECTED      = "|cffff0000All families are protected. At least one must be unprotected for banish to work.|r"
L.BAN_NOTE           = "Banned echoes with protected families are deprioritized, not excluded from selection. If all offered are banned, the fallback are applied."
L.ECHO_BAN           = "Echo Ban:"
L.ECHO_BAN_HINT      = "Echoes listed here get max banish priority and ignore scores."
L.ADD_ECHO           = "Add Echo"
L.NO_BANNED          = "No echoes banned."
L.ALL_BANNED_LABEL   = "When all offered are banned and no charges left:"
L.HIGHEST_SCORE      = "Highest Score"
L.SCORE_SOURCE       = "Score Source:"
L.COMMUNITY_MATRIX   = "Community matrix"
L.MANUAL_WEIGHTS     = "Manual weights"
L.THRESHOLDS         = "Automation Thresholds:"
L.PEAK               = "Peak: %s = %d"
L.PEAK_EMPTY         = "Peak: (no echoes)"
L.PEAK_NOTE          = "The highest echo score for this class after all bonuses are applied. All "
                       .. "automation thresholds are percentages of this value. Locked at run start."
L.SCALE_MATRIX       = "Scale: community note, -5.00 to +3.00"
L.SCALE_MATRIX_NOTE  = "An echo kept by everyone reaches +3, one refused by everyone -5, an ordinary "
                       .. "one sits near +1. The scale is absolute, so the thresholds below are read "
                       .. "directly and do not move with your build."
L.MATRIX_BLURB       = "Echoes are rated from what other players actually ran and refused, on an "
                       .. "absolute -5..+3 scale, plus your own weights (see Weight influence). "
                       .. "Thresholds below are notes."
L.WEIGHTS_BLURB      = "Echoes are rated from the weights you set on the Echoes tab, plus the "
                       .. "bonuses on the Bonus tab. Thresholds below are percentages of the Peak "
                       .. "score. The community matrix is not consulted."

L.T_BANISH_PCT       = "Auto-banish %"
L.T_BANISH_PCT_HINT  = "When an offered echo's individual score falls below this threshold, the addon will try to banish it. Echoes from protected families are skipped."
L.T_REROLL_PCT       = "Auto-reroll %"
L.T_REROLL_PCT_HINT  = "The addon sums the scores of the offered echoes, normalised to a three-card offer. If the total is below this threshold, a reroll is triggered."
L.T_GUARD_PCT        = "Reroll guard %"
L.T_GUARD_PCT_HINT   = "Blocks reroll if any single offered echo scores above this threshold, regardless of the sum."
L.T_FREEZE_PCT       = "Auto-freeze %"
L.T_FREEZE_PCT_HINT  = "Triggers when at least two offered echoes score above this threshold. The lowest-scored among them gets frozen, and the highest will be picked afterwards."
L.T_BANISH           = "Auto-banish below"
L.T_BANISH_HINT      = "Banish an offered echo whose community note falls below this. A ban is a consensus, not a shrug: at 0 every echo nobody happens to keep would qualify."
L.T_REROLL           = "Auto-reroll below"
L.T_REROLL_HINT      = "Reroll when the BEST echo on offer is below this. On an absolute scale, summing the hand says nothing -- what matters is whether anything is worth taking."
L.T_GUARD            = "Reroll guard above"
L.T_GUARD_HINT       = "Blocks reroll if any single offered echo reaches this note. Leave at or below the reroll threshold; above it, the two rules contradict each other."
L.T_FREEZE           = "Auto-freeze above"
L.T_FREEZE_HINT      = "Triggers when at least two offered echoes are above this note. The lower of them is frozen, the higher picked now."
L.T_WEIGHT           = "Weight influence"
L.T_WEIGHT_HINT      = "Your weights are added to every note: the best echo of your build adds this much, one weighted at half of it adds half. Echoes the community rates closer than this are decided by your weights."

L.DELETE_BUILD_CONFIRM = "Delete build \"%s\"?\n\nThis action cannot be undone."
L.AUTOMATION_ON      = "Automation: ON"
L.AUTOMATION_OFF     = "Automation: OFF"
L.EDIT_BUILD         = "Edit Build"
L.STATS_TITLE        = "Build Statistics"
L.STATS_QUALITY      = "Quality Distribution:"
L.STAT_ECHOES_SEEN   = "Echoes Seen"
L.STAT_RUNS_COMPLETED = "Runs Completed"
L.STAT_RUNS_RESET    = "Runs Reset"
L.STAT_PICKS         = "Picks"
L.STAT_REROLLS       = "Rerolls Used"
L.STAT_BANISHES      = "Banishes Used"
L.STAT_FREEZES       = "Freezes Used"
L.REQUESTING_DATA    = "Requesting data..."

L.ALL_CLASSES        = "All Classes"
L.PAGE               = "Page %d of %d"
L.WAIT_SECONDS       = "Wait %ds"
L.PLAYER_BUILDS_SUB  = "Builds other players saved on the server, gathered automatically."
L.PLAYER_BUILDS_NONE = "No build with all its echoes locked yet. Press Reload to ask the other players."
L.RECEIVED_ECHOES    = "%d echoes"
L.FAMILY_COUNT       = "%s (%d)"
L.DETAIL_LOCKED_UNKNOWN = "This player did not send which echoes are locked."
L.ADD_TO_WISHLIST      = "Add to my wishlist"
L.WISHLIST_OTHER_CLASS = "A wishlist is always for your own class."
L.WISHLIST_NAME_PROMPT = "Name of the new wishlist:"
L.WISHLIST_DEFAULT_NAME = "%s %d echoes"
L.WISHLIST_CREATED     = "Wishlist \"%s\" created."

L.INTEREST_FOR       = "Interest for %s"
L.GOES_WITH          = "Goes well with: %s"
L.SAVED_SUBTITLE     = "%d build(s) -- slot %d active, %d unlocked of %d"
L.SAVED_NONE         = "No build received from the server.\nOpen the game's Echoes window."

L.DELETE_SESSION_CONFIRM = "Delete this session and all its logs?"
L.CLEAR_SESSIONS_CONFIRM = "Delete all session history? This cannot be undone."
L.CARD_ACTIVE        = "|cff44ff44[Active]|r  Level %d"
L.CARD_LEVEL         = "Level %d"
L.CARD_ASHES         = "Soul Ashes: %s"
L.LOG_NO_DETAIL      = GREY .. "Choice detail not kept for this session." .. R
L.LOG_DECISIONS      = "%d decision(s): %s"
L.LOG_CHARGES_END    = "Charges at end of run  B:%d R:%d F:%d"
L.SCORE              = "Score: %s"
L.EXPORT_SESSION_TITLE = "Session Export"
L.NO_SESSION_SELECTED = "No session selected."
L.EXPORT_SESSION_HEADER = "Session: Level %d | Duration: %s | Soul Ashes: %s"
L.EXPORT_NO_DETAIL   = "Choice detail not kept. %d decision(s)."
L.EXPORT_CHARGES_END = "  charges at end of run  B:%d R:%d F:%d"
L.LOGBOOK_HINT       = GREY .. "Click a session to view its logs" .. R
L.CLEAR_ALL          = "Clear All"
L.LOGBOOK_HEADER     = GREY .. "Time      Action      Echo 1          Echo 2          Echo 3          Echo 4          Charges" .. R

L.TOAST_AUTOMATION   = "Automation: %s"
L.TOAST_CHARGES      = GREY .. "Ban: %d    Reroll: %d    Freeze: %d" .. R

L.WIZARD_HEADER      = "Build Wizard"
L.WIZARD_STEP        = "Step %d/%d"
L.CREATE_BUILD       = "Create Build"
L.NEW_BUILD_TITLE    = "New Build"
L.WEIGHT_WANT        = "Want it"
L.WEIGHT_GOOD        = "Good"
L.WEIGHT_OK          = "OK"
L.WEIGHT_MEH         = "Mehh"
L.WIZARD_S0_TITLE    = "How would you like to create your build?"
L.WIZARD_S0_DESC     = "Choose the mode that fits your style."
L.WIZARD_MODE        = "Wizard Mode"
L.WIZARD_MODE_DESC   = "Learn how the addon works with a guided setup. Takes you to the editor at the end."
L.PRO_MODE           = "Pro Mode"
L.PRO_MODE_DESC      = "Go straight to the editor with full manual control over all settings."
L.WIZARD_S1_TITLE    = "Select your %d locked echoes"
L.WIZARD_S2_TITLE    = "Adaptive Power detected!"
L.WIZARD_S2_DESC     = "Adaptive Power gains bonus for echoes you haven't picked yet."
L.WIZARD_S2_HINT     = "Suggested: 30 points"
L.WIZARD_S3_TITLE    = "Choose your families"
L.WIZARD_DEFAULTS_HINT = "Defaults are good for most builds. Change only if you really need to."
L.WIZARD_FAMILY_NONE = GREY .. "None" .. R
L.WIZARD_FAMILY_SECONDARY = "Secondary +10"
L.WIZARD_FAMILY_PRIMARY = "Primary +20"
L.WIZARD_S4_TITLE    = "Rate each quality tier"
L.WIZARD_S5_TITLE    = "Which echoes matter most?"
L.WIZARD_S5_DESC     = "Add echoes and rate how much you want them."
L.ADD_ECHO_BUTTON    = "+ Add Echo"
L.WIZARD_S5_EMPTY    = "No echoes added yet. Click \"+ Add Echo\" to start."
L.WIZARD_S6_TITLE    = "Name and describe your build"
L.WIZARD_S6_DESC     = "You can link items, spells, and echoes in the description."
L.WIZARD_S6_HINT     = "List important items, strategies, and affixes that work well with this build. You can shift-click items to link them."

L.EXPORT_BUILD_TITLE = "Export Build"
L.IMPORT_HINT        = "Paste an EbonBuilds build string, or an EBH1 composition copied from the "
                       .. "game's Echoes window, then click Import."
L.EBH1_LEARNED       = "composition %s(%s) learned -- %d echo(es)."
L.EBH1_KNOWN         = "composition %salready known."

L.SYNC_REQUESTING    = "Requesting sync..."

L.BANLIST_PURGED     = "%d ban-list entry(ies) purged."

ns.L = EbonAPI.Locale.register(ns.NAME, { enUS = L })
