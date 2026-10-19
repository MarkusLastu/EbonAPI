
local _, ns = ...
local L, C = {}, ns.C
local GOLD, RED, GREEN, GREY, R = C.GOLD, C.RED, C.GREEN, C.GREY, C.R

L.PLURAL             = ""

L.REROLL             = "Neu ziehen (Kugel: %s)"
L.REROLL_BUSY        = "Ziehe neu..."
L.REROLL_TITLE       = "Mit einer Kugel neu ziehen"
L.REROLL_BODY        = "Nimmt %s und vergisst es wieder für einen neuen Zug."
L.REROLL_COST        = "Kosten: " .. GOLD .. "%d Kugel(n)%s" .. R .. "   Vorrat: " .. GOLD .. "%d" .. R

L.TOGGLE             = "Jagd"
L.HUNT               = "Jagen (%d)"
L.HUNT_MULT          = "Jagen (%d) x%d"
L.HUNT_STOP          = "Stopp (%d/%d)"
L.HUNT_TITLE         = "Nach Echos jagen"
L.HUNT_RUNNING       = "Jagd läuft"
L.HUNT_PROGRESS      = "%d von %d Kugeln ausgegeben, %d pro Zug."
L.HUNT_CLICK_STOP    = "Zum Stoppen klicken."
L.HUNT_BODY          = "Zieht neu, bis eines Eurer %d vorgemerkten Echo(s) erscheint."
L.HUNT_BODY_COST     = "Kosten: " .. GOLD .. "%d Kugel(n)" .. R .. " pro Zug - %d Zug/Züge für "
                       .. GOLD .. "%d Kugel(n)" .. R .. "."
L.HUNT_BODY_MANUAL   = "Das gefundene Echo wird nie für Euch genommen."
L.HUNT_BODY_HINT     = "Die Kosten folgen dem Qualitätsregler des Spiels, gelesen von Eurer letzten Kugelausgabe."

L.RARITY_TITLE       = "Gesuchte Qualität"
L.RARITY_BODY        = "Für jedes vorgemerkte Echo die niedrigste Qualität, bei der die Jagd anhält."
L.RARITY_HINT        = "Die meisten Echos gibt es in mehreren Qualitäten. Eine Jagd nimmt sie alle "
                       .. "an, solange Ihr hier nichts anderes bestimmt."
L.RARITY_ANY         = "Jede Qualität"
L.RARITY_MIN         = "%s und besser"

L.BUDGET             = "Kugeln zum Ausgeben: " .. GOLD .. "%d" .. R
L.BUDGET_DRAWS       = "Kugeln zum Ausgeben: " .. GOLD .. "%d" .. R .. "  " .. GREY
                       .. "(%d Zug/Züge%s zu je %d)" .. R

L.BUSY               = "Es läuft bereits ein neuer Zug."
L.NO_CHOICE          = "Keine Echo-Auswahl auf dem Tisch."
L.PICK_IN_FLIGHT     = "Eine Auswahl ist bereits unterwegs."
L.NONE_FORGETTABLE   = "Keine dieser Karten kann erneut vergessen werden."
L.CHARGES_UNKNOWN    = "Warte noch auf Euren Kugelstand."
L.NOT_ENOUGH_ORBS    = "Ein Zug kostet %d Kugeln, Ihr habt %d."
L.HUNT_RUNNING_ALREADY = "Es läuft bereits eine Jagd."
L.NOTHING_ARMED      = "Kein Echo vorgemerkt. Strg+Klick auf eines im Echo-Journal."
L.HUNT_MARK          = "Strg+Klick: dieses Echo jagen"
L.HUNT_UNMARK        = "Strg+Klick: nicht mehr jagen"
L.AUTO_ACCEPT_ON     = "Schaltet Ebonholds \"auto-accept loadout echoes\" vor der Jagd aus."
L.BUDGET_TOO_LOW     = "Budget zu niedrig: ein Zug kostet %d Kugeln, erhöht den Regler."

L.HUNT_STARTED       = "Jagd gestartet: %d Echo(s) gesucht, bis zu " .. GOLD .. "%d Kugel(n)%s" .. R
                       .. " - %d Zug/Züge%s zu je " .. GOLD .. "%d" .. R .. "."
L.HUNT_SPENT         = " " .. GREY .. "(%d Kugel(n)%s ausgegeben)" .. R
L.HUNT_FOUND         = GREEN .. "Gefunden:" .. R .. " %s " .. GREY .. "- Eure Wahl." .. R
L.HUNT_BUDGET_DONE   = "Budget ausgegeben, Jagd beendet."
L.HUNT_NO_ORBS       = RED .. "Nicht genug Kugeln übrig (%d pro Zug), Jagd beendet." .. R
L.HUNT_STOPPED       = "Jagd gestoppt."
L.HUNT_INTERRUPTED   = RED .. "Jagd unterbrochen." .. R
L.HUNT_BEFORE_SPEND  = RED .. "Jagd vor der Ausgabe unterbrochen." .. R
L.HUNT_WENT_PERMANENT = RED .. "Jagd gestoppt: das genommene Echo kam permanent zurück." .. R
L.HUNT_SPEND_FAILED  = RED .. "Jagd gestoppt: die Ausgabe schlug fehl." .. R

L.LIVE_TITLE         = "Jagd: |cffffffff%d/%d|r Kugel(n)%s ausgegeben"
L.LIVE_WANTED        = GREY .. "Gesucht:" .. R .. " %s"
L.LIVE_WANTED_MIN    = "%s (%s+)"

L.PICK_TIMED_OUT     = "Die Auswahl lief ab - keine Kugel ausgegeben."
L.WENT_PERMANENT     = RED .. "%s kam permanent zurück und kann nicht vergessen werden - keine "
                       .. "Kugel ausgegeben. Es gehört Euch." .. R
L.THAT_ECHO          = "Dieses Echo"
L.NO_PERK_SYSTEM     = "Project Ebonholds Perk-System wurde nicht gefunden - das Panel bleibt verborgen."
L.NO_JOURNAL         = "Das Echo-Journal von ProjectEbonhold wurde nicht gefunden - Echos können nicht für eine Jagd markiert werden."

L.GUARD_BODY         = "Hält die Auswahl-Automatik zurück, damit der Zug Euch gehört."
L.GUARD_ON           = "An. Zum Ausschalten klicken."
L.GUARD_OFF          = "Aus. Zum Einschalten klicken."
L.HUNT_STOPPED_CLICK = "Jagd gestoppt: Ihr habt selbst eine Karte genommen."


L.ALL                = "Alle"
L.UNTITLED           = "Unbenannt"
L.UNKNOWN            = "Unbekannt"
L.SAVE               = "Speichern"
L.EXPORT             = "Exportieren"
L.IMPORT             = "Importieren"
L.RELOAD             = "Neu laden"
L.NEXT               = "Weiter"
L.PREVIOUS           = "Zurück"
L.BACK               = "Zurück"
L.REMOVE             = "Entfernen"
L.RANDOM             = "Zufällig"
L.TITLE_LABEL        = "Titel:"
L.DESCRIPTION_LABEL  = "Beschreibung:"
L.LOCKED_ECHOES      = "Gesperrte Echos:"
L.BUILD_META         = "von %s | %s | %s"
L.SPEC_N             = "Spez. %d"
L.LOCKED             = "Gesperrt"
L.BANNED             = "Verbannt"

L.FAMILY = {
    Tank          = "Tank",
    Survivability = "Überleben",
    Healer        = "Heiler",
    Caster        = "Zauberwirker",
    Melee         = "Nahkampf",
    Ranged        = "Fernkampf",
    ["No family"] = "Keine Familie",
}
L.FAMILY_LONG = {
    Tank          = "Tank",
    Survivability = "Überleben",
    Healer        = "Heiler",
    Caster        = "Zauber-DPS",
    Melee         = "Nahkampf-DPS",
    Ranged        = "Fernkampf-DPS",
}
L.ACTION = {
    Select              = "Wählen",
    ["Select (Locked)"] = "Wählen (gesperrt)",
    Banish              = "Verbannen",
    Reroll              = "Neu ziehen",
    Freeze              = "Einfrieren",
}
L.SPEC = {
    WARRIOR     = { "Waffen", "Furor", "Schutz" },
    PALADIN     = { "Heilig", "Schutz", "Vergeltung" },
    HUNTER      = { "Tierherrschaft", "Treffsicherheit", "Überleben" },
    ROGUE       = { "Meucheln", "Kampf", "Täuschung" },
    PRIEST      = { "Disziplin", "Heilig", "Schatten" },
    DEATHKNIGHT = { "Blut", "Frost", "Unheilig" },
    SHAMAN      = { "Elementar", "Verstärkung", "Wiederherstellung" },
    MAGE        = { "Arkan", "Feuer", "Frost" },
    WARLOCK     = { "Gebrechen", "Dämonologie", "Zerstörung" },
    DRUID       = { "Gleichgewicht", "Wilder Kampf", "Wiederherstellung" },
}

L.SAVED_BUILDS       = "Gespeicherte Builds"
L.PLAYER_BUILDS      = "Spieler-Builds"
L.IMPORT_BUILD       = "Build importieren"
L.NEW_BUILD_BUTTON   = "+ Neuer Build"
L.WELCOME_TITLE      = "Noch keine Builds"
L.WELCOME_BODY       = "Erstellt Euren ersten Build oder durchsucht die öffentlichen Builds."
L.MINIMAP_TIP        = "Klicken, um die Konfiguration zu öffnen"

L.SETTINGS_TITLE     = "EbonBuilds-Einstellungen"
L.SETTINGS_DELAY     = "Aktionsverzögerung:"
L.SETTINGS_DELAY_HINT = "Sehr niedrige Werte können das Addon stören."
L.SETTINGS_TOAST     = "Anzeigedauer des Banners:"


L.TAB_OVERVIEW       = "Übersicht"
L.TAB_ECHOES         = "Echos"
L.TAB_BONUS          = "Bonus"
L.TAB_AUTOMATION     = "Automatik"
L.TAB_STATS          = "Statistik"
L.TAB_MISSING        = "Fehlend"
L.TAB_LOGBOOK        = "Logbuch"

L.FORM_HEADER        = "Build"
L.FORM_CLASS         = "Klasse:"
L.FORM_SPEC          = "Spez.:"
L.FORM_DESCRIPTION_HINT = "Beschreibt hier die Strategie des Builds. Die Reiter Echos und Bonus legen die Gewichte fest."
L.INSERT_LINK_BUTTON = "+ Echo-Link"
L.INSERT_LINK_BODY   = "Fügt einen anklickbaren Verweis auf ein Echo in die Beschreibung ein."
L.INSERT_LINK_HINT1  = "Um Gewichte und Boni dieses Builds einzustellen,"
L.INSERT_LINK_HINT2  = "nutzt nach dem Speichern die Reiter Echos und Bonus."

L.BONUS_HEADER       = "Bonus"
L.BONUS_QUALITY      = "Seltenheitsbonus:"
L.BONUS_FAMILY       = "Familienbonus:"
L.BONUS_NOVELTY      = "Neuheitsbonus:"
L.BONUS_MODE_HINT    = "+ addiert den Wert, |cff19ff19x|r multipliziert. Im |cff19ff19x|r-Modus senkt ein Wert unter 1 die Note."
L.BONUS_NOVELTY_HINT = "Echos, die Ihr noch nie erhalten habt, bekommen diesen Bonus."
L.BONUS_VALUE        = "Wert:"

L.ECHO_WEIGHTS       = "Echo-Gewichte"
L.ECHO_WEIGHTS_FOR   = "Echo-Gewichte - %s"
L.COL_NAME           = "Name"
L.COL_WEIGHT         = "Gewicht"
L.ALL_FAMILIES       = "Alle Familien"
L.FAMILIES_N         = "Familien (%d)"
L.SHOW_ALL_CLASSES   = "Alle Klassen zeigen"
L.PICK_ECHO          = "Echo wählen"

L.AUTOMATION_HEADER  = "Automatik"
L.BANISH_PROTECTION  = "Schutz vor Verbannung:"
L.BANISH_PROTECTION_HINT = "Angehakte Familien werden nie verbannt."
L.ALL_PROTECTED      = "|cffff0000Alle Familien sind geschützt. Mindestens eine muss ungeschützt sein, damit Verbannen funktioniert.|r"
L.BAN_NOTE           = "Verbannte Echos aus geschützten Familien kommen zuletzt, werden aber nicht ausgeschlossen. Ist alles Angebotene verbannt, greift die Ersatzregel."
L.ECHO_BAN           = "Verbannte Echos:"
L.ECHO_BAN_HINT      = "Hier gelistete Echos werden zuerst verbannt, unabhängig von ihrer Note."
L.ADD_ECHO           = "Hinzufügen"
L.NO_BANNED          = "Keine Echos verbannt."
L.ALL_BANNED_LABEL   = "Wenn alles verbannt ist und keine Ladungen übrig sind:"
L.HIGHEST_SCORE      = "Beste Note"
L.SCORE_SOURCE       = "Quelle der Note:"
L.COMMUNITY_MATRIX   = "Gemeinschaftsmatrix"
L.MANUAL_WEIGHTS     = "Eigene Gewichte"
L.THRESHOLDS         = "Automatik-Schwellen:"
L.PEAK               = "Spitze: %s = %d"
L.PEAK_EMPTY         = "Spitze: (keine Echos)"
L.PEAK_NOTE          = "Die beste mögliche Note für diese Klasse, alle Boni eingerechnet. Alle "
                       .. "Automatik-Schwellen sind Prozente dieses Werts. Wird zu Beginn des Laufs festgelegt."
L.SCALE_MATRIX       = "Skala: Gemeinschaftsnote, -5,00 bis +3,00"
L.SCALE_MATRIX_NOTE  = "Ein von allen behaltenes Echo erreicht +3, ein von allen abgelehntes -5, ein "
                       .. "gewöhnliches liegt um +1. Die Skala ist absolut: Die Schwellen unten gelten "
                       .. "so, wie sie sind, und wandern nicht mit Eurem Build."
L.MATRIX_BLURB       = "Echos werden danach bewertet, was andere Spieler wirklich gespielt und "
                       .. "abgelehnt haben, auf einer absoluten Skala von -5 bis +3, dazu Eure eigenen "
                       .. "Gewichte (siehe Einfluss der Gewichte). Die Schwellen unten sind Noten."
L.WEIGHTS_BLURB      = "Echos werden nach den Gewichten im Reiter Echos bewertet, dazu die Boni im "
                       .. "Reiter Bonus. Die Schwellen unten sind Prozente der Spitze. Die "
                       .. "Gemeinschaftsmatrix wird nicht befragt."

L.T_BANISH_PCT       = "Verbannen unter %"
L.T_BANISH_PCT_HINT  = "Fällt die Note eines angebotenen Echos unter diese Schwelle, versucht das Addon es zu verbannen. Geschützte Familien werden übersprungen."
L.T_REROLL_PCT       = "Neu ziehen unter %"
L.T_REROLL_PCT_HINT  = "Das Addon addiert die Noten der angebotenen Echos, umgerechnet auf drei Karten. Liegt die Summe unter dieser Schwelle, zieht es neu."
L.T_GUARD_PCT        = "Neuzieh-Sperre %"
L.T_GUARD_PCT_HINT   = "Verhindert das Neuziehen, sobald ein einzelnes angebotenes Echo diese Schwelle übersteigt, egal wie hoch die Summe ist."
L.T_FREEZE_PCT       = "Einfrieren über %"
L.T_FREEZE_PCT_HINT  = "Greift, wenn mindestens zwei angebotene Echos diese Schwelle übersteigen. Das schwächere wird eingefroren, das beste danach gewählt."
L.T_BANISH           = "Verbannen unter"
L.T_BANISH_HINT      = "Verbannt ein angebotenes Echo, dessen Gemeinschaftsnote unter diese Schwelle fällt. Ein Bann braucht Einigkeit: Bei 0 träfe es jedes Echo, das zufällig niemand behalten hat."
L.T_REROLL           = "Neu ziehen unter"
L.T_REROLL_HINT      = "Zieht neu, wenn das BESTE angebotene Echo unter dieser Schwelle liegt. Auf einer absoluten Skala sagt die Summe nichts aus -- es zählt nur, ob sich etwas lohnt."
L.T_GUARD            = "Neuzieh-Sperre über"
L.T_GUARD_HINT       = "Verhindert das Neuziehen, sobald ein einzelnes angebotenes Echo diese Note erreicht. Nicht über die Neuzieh-Schwelle setzen, sonst widersprechen sich die beiden Regeln."
L.T_FREEZE           = "Einfrieren über"
L.T_FREEZE_HINT      = "Greift, wenn mindestens zwei angebotene Echos über dieser Note liegen. Das schwächere wird eingefroren, das bessere sofort gewählt."
L.T_WEIGHT           = "Einfluss der Gewichte"
L.T_WEIGHT_HINT      = "Eure Gewichte kommen zu jeder Note hinzu: Das beste Echo Eures Builds addiert diesen Wert, eines mit halbem Gewicht die Hälfte. Echos, die die Gemeinschaft enger als diesen Abstand bewertet, entscheiden Eure Gewichte."

L.DELETE_BUILD_CONFIRM = "Build \"%s\" löschen?\n\nDas lässt sich nicht rückgängig machen."
L.AUTOMATION_ON      = "Automatik: AN"
L.AUTOMATION_OFF     = "Automatik: AUS"
L.EDIT_BUILD         = "Bearbeiten"
L.STATS_TITLE        = "Build-Statistik"
L.STATS_QUALITY      = "Verteilung der Seltenheit:"
L.STAT_ECHOES_SEEN   = "Gesehene Echos"
L.STAT_RUNS_COMPLETED = "Abgeschlossene Läufe"
L.STAT_RUNS_RESET    = "Neu begonnene Läufe"
L.STAT_PICKS         = "Wahlen"
L.STAT_REROLLS       = "Neuziehungen"
L.STAT_BANISHES      = "Verbannungen"
L.STAT_FREEZES       = "Einfrierungen"
L.REQUESTING_DATA    = "Daten werden angefragt..."

L.ALL_CLASSES        = "Alle Klassen"
L.PAGE               = "Seite %d von %d"
L.WAIT_SECONDS       = "Warten %ds"
L.PLAYER_BUILDS_SUB  = "Builds, die andere Spieler auf dem Server gespeichert haben, automatisch gesammelt."
L.PLAYER_BUILDS_NONE = "Noch kein Build, dessen Echos alle gesperrt sind. Klickt auf Neu laden, um sie anzufordern."
L.RECEIVED_ECHOES    = "%d Echos"
L.FAMILY_COUNT       = "%s (%d)"
L.DETAIL_LOCKED_UNKNOWN = "Dieser Spieler hat seine gesperrten Echos nicht übermittelt."
L.ADD_TO_WISHLIST      = "Zu meiner Wishlist hinzufügen"
L.WISHLIST_OTHER_CLASS = "Eine Wishlist gilt immer für eure eigene Klasse."
L.WISHLIST_NAME_PROMPT = "Name der neuen Wishlist:"
L.WISHLIST_DEFAULT_NAME = "%s %d Echos"
L.WISHLIST_CREATED     = "Wishlist \"%s\" erstellt."

L.INTEREST_FOR       = "Nutzen für %s"
L.GOES_WITH          = "Passt gut zu: %s"
L.SAVED_SUBTITLE     = "%d Build(s) -- Platz %d aktiv, %d von %d freigeschaltet"
L.SAVED_NONE         = "Noch kein Build vom Server erhalten.\nÖffnet das Echo-Fenster des Spiels."

L.DELETE_SESSION_CONFIRM = "Diese Sitzung und ihr ganzes Logbuch löschen?"
L.CLEAR_SESSIONS_CONFIRM = "Den gesamten Sitzungsverlauf löschen? Das lässt sich nicht rückgängig machen."
L.CARD_ACTIVE        = "|cff44ff44[Aktiv]|r  Stufe %d"
L.CARD_LEVEL         = "Stufe %d"
L.CARD_ASHES         = "Seelenasche: %s"
L.LOG_NO_DETAIL      = GREY .. "Für diese Sitzung sind keine Einzelheiten der Wahlen gespeichert." .. R
L.LOG_DECISIONS      = "%d Entscheidung(en): %s"
L.LOG_CHARGES_END    = "Ladungen am Laufende  V:%d N:%d E:%d"
L.SCORE              = "Note: %s"
L.EXPORT_SESSION_TITLE = "Sitzungsexport"
L.NO_SESSION_SELECTED = "Keine Sitzung ausgewählt."
L.EXPORT_SESSION_HEADER = "Sitzung: Stufe %d | Dauer: %s | Seelenasche: %s"
L.EXPORT_NO_DETAIL   = "Einzelheiten nicht gespeichert. %d Entscheidung(en)."
L.EXPORT_CHARGES_END = "  Ladungen am Laufende  V:%d N:%d E:%d"
L.LOGBOOK_HINT       = GREY .. "Klickt auf eine Sitzung, um ihr Logbuch zu sehen" .. R
L.CLEAR_ALL          = "Alles löschen"
L.LOGBOOK_HEADER     = GREY .. "Zeit      Aktion      Echo 1          Echo 2          Echo 3          Echo 4          Ladungen" .. R

L.TOAST_AUTOMATION   = "Automatik: %s"
L.TOAST_CHARGES      = GREY .. "Verbannen: %d    Neu ziehen: %d    Einfrieren: %d" .. R

L.WIZARD_HEADER      = "Build-Assistent"
L.WIZARD_STEP        = "Schritt %d/%d"
L.CREATE_BUILD       = "Build erstellen"
L.NEW_BUILD_TITLE    = "Neuer Build"
L.WEIGHT_WANT        = "Will ich"
L.WEIGHT_GOOD        = "Gut"
L.WEIGHT_OK          = "Okay"
L.WEIGHT_MEH         = "Naja"
L.WIZARD_S0_TITLE    = "Wie wollt Ihr Euren Build erstellen?"
L.WIZARD_S0_DESC     = "Wählt den Modus, der zu Euch passt."
L.WIZARD_MODE        = "Assistent"
L.WIZARD_MODE_DESC   = "Lernt das Addon Schritt für Schritt kennen. Am Ende öffnet sich der Editor."
L.PRO_MODE           = "Profi-Modus"
L.PRO_MODE_DESC      = "Direkt zum Editor, mit voller Kontrolle über alle Einstellungen."
L.WIZARD_S1_TITLE    = "Wählt Eure %d gesperrten Echos"
L.WIZARD_S2_TITLE    = "Adaptive Macht erkannt!"
L.WIZARD_S2_DESC     = "Adaptive Macht gibt einen Bonus auf Echos, die Ihr noch nicht gewählt habt."
L.WIZARD_S2_HINT     = "Empfohlen: 30 Punkte"
L.WIZARD_S3_TITLE    = "Wählt Eure Familien"
L.WIZARD_DEFAULTS_HINT = "Die Standardwerte passen für die meisten Builds. Ändert sie nur, wenn es wirklich nötig ist."
L.WIZARD_FAMILY_NONE = GREY .. "Keine" .. R
L.WIZARD_FAMILY_SECONDARY = "Neben +10"
L.WIZARD_FAMILY_PRIMARY = "Haupt +20"
L.WIZARD_S4_TITLE    = "Bewertet jede Seltenheit"
L.WIZARD_S5_TITLE    = "Welche Echos zählen am meisten?"
L.WIZARD_S5_DESC     = "Fügt Echos hinzu und sagt, wie sehr Ihr sie wollt."
L.ADD_ECHO_BUTTON    = "+ Echo hinzufügen"
L.WIZARD_S5_EMPTY    = "Noch keine Echos. Klickt auf \"+ Echo hinzufügen\", um zu beginnen."
L.WIZARD_S6_TITLE    = "Benennt und beschreibt Euren Build"
L.WIZARD_S6_DESC     = "In der Beschreibung könnt Ihr Gegenstände, Zauber und Echos verlinken."
L.WIZARD_S6_HINT     = "Nennt Gegenstände, Strategien und Affixe, die gut zu diesem Build passen. Umschalt+Klick auf einen Gegenstand fügt seinen Link ein."

L.EXPORT_BUILD_TITLE = "Build exportieren"
L.IMPORT_HINT        = "Fügt eine EbonBuilds-Buildzeichenkette ein oder eine EBH1-Zusammenstellung "
                       .. "aus dem Echo-Fenster des Spiels, dann klickt auf Importieren."
L.EBH1_LEARNED       = "Zusammenstellung %s(%s) gelernt -- %d Echo(s)."
L.EBH1_KNOWN         = "Zusammenstellung %sschon bekannt."

L.SYNC_REQUESTING    = "Abgleich wird angefragt..."

L.BANLIST_PURGED     = "%d Eintrag/Einträge der Bannliste gelöscht."

EbonAPI.Locale.register(ns.NAME, { deDE = L })
