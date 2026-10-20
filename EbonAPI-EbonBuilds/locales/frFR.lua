
local _, ns = ...
local L, C = {}, ns.C
local GOLD, RED, GREEN, GREY, R = C.GOLD, C.RED, C.GREEN, C.GREY, C.R

L.REROLL             = "Relancer (Orbe : %s)"
L.REROLL_BUSY        = "Relance..."
L.REROLL_TITLE       = "Relancer avec une Orbe"
L.REROLL_BODY        = "Prend %s et l'oublie à nouveau pour un nouveau tirage."
L.REROLL_COST        = "Coût : " .. GOLD .. "%d Orbe%s" .. R .. "   En réserve : " .. GOLD .. "%d" .. R

L.TOGGLE             = "Chasse"
L.HUNT               = "Chasser (%d)"
L.HUNT_MULT          = "Chasser (%d) x%d"
L.HUNT_STOP          = "Arrêter (%d/%d)"
L.HUNT_TITLE         = "Chasser des Échos"
L.HUNT_RUNNING       = "Chasse en cours"
L.HUNT_PROGRESS      = "%d orbes dépensées sur %d, %d par tirage."
L.HUNT_CLICK_STOP    = "Cliquez pour arrêter."
L.HUNT_BODY          = "Relance jusqu'à ce qu'un de vos %d Écho(s) armé(s) sorte."
L.HUNT_BODY_COST     = "Coût : " .. GOLD .. "%d orbe(s)" .. R .. " par tirage - %d tirage(s) pour "
                       .. GOLD .. "%d orbe(s)" .. R .. "."
L.HUNT_BODY_MANUAL   = "L'Écho trouvé n'est jamais pris à votre place."
L.HUNT_BODY_HINT     = "Le coût suit le curseur de qualité du jeu, lu sur votre dernière dépense d'orbe."

L.RARITY_TITLE       = "Rareté recherchée"
L.RARITY_BODY        = "Pour chaque Écho armé, la rareté minimale sur laquelle la chasse s'arrête."
L.RARITY_HINT        = "La plupart des Échos existent en plusieurs raretés. Une chasse les accepte "
                       .. "toutes tant que vous n'en décidez pas autrement ici."
L.RARITY_ANY         = "Toutes les raretés"
L.RARITY_MIN         = "%s et mieux"

L.BUDGET             = "Orbes à dépenser : " .. GOLD .. "%d" .. R
L.BUDGET_DRAWS       = "Orbes à dépenser : " .. GOLD .. "%d" .. R .. "  " .. GREY .. "(%d tirage%s à %d)" .. R

L.BUSY               = "Une relance est déjà en cours."
L.NO_CHOICE          = "Aucun choix d'Écho sur la table."
L.PICK_IN_FLIGHT     = "Une sélection est déjà en cours."
L.NONE_FORGETTABLE   = "Aucune de ces cartes ne peut être oubliée à nouveau."
L.CHARGES_UNKNOWN    = "En attente de votre nombre d'Orbes."
L.NOT_ENOUGH_ORBS    = "Un tirage coûte %d orbes et vous en avez %d."
L.HUNT_RUNNING_ALREADY = "Une chasse est déjà en cours."
L.NOTHING_ARMED      = "Aucun Écho armé. Ctrl+clic sur un Écho dans le journal."
L.HUNT_MARK          = "Ctrl+clic : chasser cet Écho"
L.HUNT_UNMARK        = "Ctrl+clic : ne plus chasser"
L.AUTO_ACCEPT_ON     = "Désactivez \"auto-accept loadout echoes\" d'Ebonhold avant de chasser."
L.BUDGET_TOO_LOW     = "Budget trop bas : un tirage coûte %d orbes, montez le curseur."

L.HUNT_STARTED       = "Chasse lancée : %d Écho(s) voulu(s), jusqu'à " .. GOLD .. "%d orbe%s" .. R
                       .. " - %d tirage%s à " .. GOLD .. "%d" .. R .. " chacun."
L.HUNT_SPENT         = " " .. GREY .. "(dépense : %d orbe%s)" .. R
L.HUNT_FOUND         = GREEN .. "Trouvé :" .. R .. " %s " .. GREY .. "- à vous de le prendre." .. R
L.HUNT_BUDGET_DONE   = "Budget dépensé, chasse terminée."
L.HUNT_NO_ORBS       = RED .. "Plus assez d'orbes (%d par tirage), chasse terminée." .. R
L.HUNT_STOPPED       = "Chasse arrêtée."
L.HUNT_INTERRUPTED   = RED .. "Chasse interrompue." .. R
L.HUNT_BEFORE_SPEND  = RED .. "Chasse interrompue avant la dépense." .. R
L.HUNT_WENT_PERMANENT = RED .. "Chasse arrêtée : l'Écho pris est revenu permanent." .. R
L.HUNT_SPEND_FAILED  = RED .. "Chasse arrêtée : la dépense a échoué." .. R

L.LIVE_TITLE         = "Chasse : dépense |cffffffff%d/%d|r orbe%s"
L.LIVE_WANTED        = GREY .. "Recherché :" .. R .. " %s"
L.LIVE_WANTED_MIN    = "%s (%s+)"

L.PICK_TIMED_OUT     = "La sélection a expiré - aucune orbe dépensée."
L.WENT_PERMANENT     = RED .. "%s est revenu permanent, il ne peut donc plus être oublié - aucune "
                       .. "orbe dépensée. Il est à vous." .. R
L.THAT_ECHO          = "Cet Écho"
L.NO_PERK_SYSTEM     = "Le système de perks de Project Ebonhold est introuvable - le panneau reste caché."
L.NO_JOURNAL         = "Le journal des Échos de ProjectEbonhold est introuvable - impossible de marquer des Échos pour une chasse."

L.GUARD_BODY         = "Retient la sélection automatique, pour que le tirage soit à vous."
L.GUARD_ON           = "Actif. Cliquez pour désactiver."
L.GUARD_OFF          = "Inactif. Cliquez pour activer."
L.HUNT_STOPPED_CLICK = "Chasse arrêtée : vous avez pris une carte vous-même."


L.ALL                = "Tous"
L.UNTITLED           = "Sans titre"
L.UNKNOWN            = "Inconnu"
L.SAVE               = "Enregistrer"
L.EXPORT             = "Exporter"
L.IMPORT             = "Importer"
L.RELOAD             = "Actualiser"
L.NEXT               = "Suivant"
L.PREVIOUS           = "Précédent"
L.BACK               = "Retour"
L.REMOVE             = "Retirer"
L.RANDOM             = "Au hasard"
L.TITLE_LABEL        = "Titre :"
L.DESCRIPTION_LABEL  = "Description :"
L.LOCKED_ECHOES      = "Échos verrouillés :"
L.BUILD_META         = "par %s | %s | %s"
L.SPEC_N             = "Spé %d"
L.LOCKED             = "Verrouillé"
L.BANNED             = "Banni"

L.FAMILY = {
    Tank          = "Tank",
    Survivability = "Survie",
    Healer        = "Soigneur",
    Caster        = "Lanceur de sorts",
    Melee         = "Mêlée",
    Ranged        = "Distance",
    ["No family"] = "Sans famille",
}
L.FAMILY_LONG = {
    Tank          = "Tank",
    Survivability = "Survie",
    Healer        = "Soigneur",
    Caster        = "DPS lanceur de sorts",
    Melee         = "DPS mêlée",
    Ranged        = "DPS distance",
}
L.ACTION = {
    Select              = "Prendre",
    ["Select (Locked)"] = "Prendre (verrouillé)",
    Banish              = "Bannir",
    Reroll              = "Relancer",
    Freeze              = "Geler",
}
L.SPEC = {
    WARRIOR     = { "Armes", "Fureur", "Protection" },
    PALADIN     = { "Sacré", "Protection", "Vindicte" },
    HUNTER      = { "Maîtrise des bêtes", "Précision", "Survie" },
    ROGUE       = { "Assassinat", "Combat", "Finesse" },
    PRIEST      = { "Discipline", "Sacré", "Ombre" },
    DEATHKNIGHT = { "Sang", "Givre", "Impie" },
    SHAMAN      = { "Élémentaire", "Amélioration", "Restauration" },
    MAGE        = { "Arcanes", "Feu", "Givre" },
    WARLOCK     = { "Affliction", "Démonologie", "Destruction" },
    DRUID       = { "Équilibre", "Combat farouche", "Restauration" },
}

L.SAVED_BUILDS       = "Builds enregistrés"
L.PLAYER_BUILDS      = "Builds des joueurs"
L.IMPORT_BUILD       = "Importer un build"
L.NEW_BUILD_BUTTON   = "+ Nouveau build"
L.WELCOME_TITLE      = "Aucun build pour l'instant"
L.WELCOME_BODY       = "Créez votre premier build ou parcourez les builds publics."
L.MINIMAP_TIP        = "Cliquer pour ouvrir la configuration"

L.SETTINGS_TITLE     = "Réglages d'EbonBuilds"
L.SETTINGS_DELAY     = "Délai d'action :"
L.SETTINGS_DELAY_HINT = "Des valeurs très basses peuvent perturber l'addon."
L.SETTINGS_TOAST     = "Durée du bandeau :"


L.TAB_OVERVIEW       = "Aperçu"
L.TAB_ECHOES         = "Échos"
L.TAB_BONUS          = "Bonus"
L.TAB_AUTOMATION     = "Automatisation"
L.TAB_STATS          = "Stats"
L.TAB_MISSING        = "Manquants"
L.TAB_LOGBOOK        = "Journal"

L.FORM_HEADER        = "Build"
L.FORM_CLASS         = "Classe :"
L.FORM_SPEC          = "Spé :"
L.FORM_DESCRIPTION_HINT = "Expliquez ici la stratégie du build. Les onglets Échos et Bonus servent à régler les poids."
L.INSERT_LINK_BUTTON = "+ Lien d'Écho"
L.INSERT_LINK_BODY   = "Insère dans la description une référence cliquable à un Écho."
L.INSERT_LINK_HINT1  = "Pour régler les poids et les bonus de ce build,"
L.INSERT_LINK_HINT2  = "utilisez les onglets Échos et Bonus après l'enregistrement."

L.BONUS_HEADER       = "Bonus"
L.BONUS_QUALITY      = "Bonus de rareté :"
L.BONUS_FAMILY       = "Bonus de famille :"
L.BONUS_NOVELTY      = "Bonus de nouveauté :"
L.BONUS_MODE_HINT    = "+ ajoute la valeur, |cff19ff19x|r la multiplie. En mode |cff19ff19x|r, moins de 1 réduit la note."
L.BONUS_NOVELTY_HINT = "Les Échos encore jamais obtenus reçoivent ce bonus."
L.BONUS_VALUE        = "Valeur :"

L.ECHO_WEIGHTS       = "Poids des Échos"
L.ECHO_WEIGHTS_FOR   = "Poids des Échos - %s"
L.COL_NAME           = "Nom"
L.COL_WEIGHT         = "Poids"
L.ALL_FAMILIES       = "Toutes les familles"
L.FAMILIES_N         = "Familles (%d)"
L.SHOW_ALL_CLASSES   = "Toutes les classes"
L.PICK_ECHO          = "Choisir un Écho"

L.AUTOMATION_HEADER  = "Automatisation"
L.BANISH_PROTECTION  = "Protection contre le bannissement :"
L.BANISH_PROTECTION_HINT = "Les familles cochées ne sont jamais bannies."
L.ALL_PROTECTED      = "|cffff0000Toutes les familles sont protégées. Il en faut au moins une non protégée pour que le bannissement fonctionne.|r"
L.BAN_NOTE           = "Un Écho banni d'une famille protégée passe en dernier, sans être exclu du choix. Si tout ce qui est proposé est banni, la règle de repli s'applique."
L.ECHO_BAN           = "Échos bannis :"
L.ECHO_BAN_HINT      = "Les Échos listés ici sont bannis en priorité, quelle que soit leur note."
L.ADD_ECHO           = "Ajouter"
L.NO_BANNED          = "Aucun Écho banni."
L.ALL_BANNED_LABEL   = "Si tout est banni et qu'il ne reste plus de charges :"
L.HIGHEST_SCORE      = "Meilleure note"
L.SCORE_SOURCE       = "Source de la note :"
L.COMMUNITY_MATRIX   = "Matrice commune"
L.MANUAL_WEIGHTS     = "Poids manuels"
L.THRESHOLDS         = "Seuils d'automatisation :"
L.PEAK               = "Pic : %s = %d"
L.PEAK_EMPTY         = "Pic : (aucun Écho)"
L.PEAK_NOTE          = "La meilleure note possible pour cette classe, bonus compris. Tous les seuils "
                       .. "d'automatisation sont des pourcentages de cette valeur. Figé au début du run."
L.SCALE_MATRIX       = "Échelle : note commune, de -5,00 à +3,00"
L.SCALE_MATRIX_NOTE  = "Un Écho gardé par tous atteint +3, un Écho refusé par tous -5, un Écho "
                       .. "ordinaire tourne autour de +1. L'échelle est absolue : les seuils ci-dessous "
                       .. "se lisent tels quels et ne bougent pas avec votre build."
L.MATRIX_BLURB       = "Les Échos sont notés d'après ce que les autres joueurs ont vraiment joué et "
                       .. "refusé, sur une échelle absolue de -5 à +3, plus vos propres poids (voir "
                       .. "Influence des poids). Les seuils ci-dessous sont des notes."
L.WEIGHTS_BLURB      = "Les Échos sont notés d'après les poids de l'onglet Échos, plus les bonus de "
                       .. "l'onglet Bonus. Les seuils ci-dessous sont des pourcentages du Pic. La "
                       .. "matrice commune n'est pas consultée."

L.T_BANISH_PCT       = "Bannir sous %"
L.T_BANISH_PCT_HINT  = "Quand la note d'un Écho proposé passe sous ce seuil, l'addon essaie de le bannir. Les familles protégées sont épargnées."
L.T_REROLL_PCT       = "Relancer sous %"
L.T_REROLL_PCT_HINT  = "L'addon additionne les notes des Échos proposés, ramenées à trois cartes. Si le total passe sous ce seuil, il relance."
L.T_GUARD_PCT        = "Garde de relance %"
L.T_GUARD_PCT_HINT   = "Empêche la relance dès qu'un seul Écho proposé dépasse ce seuil, quelle que soit la somme."
L.T_FREEZE_PCT       = "Geler au-dessus %"
L.T_FREEZE_PCT_HINT  = "Se déclenche quand au moins deux Échos proposés dépassent ce seuil. Le moins bien noté est gelé, le meilleur est pris ensuite."
L.T_BANISH           = "Bannir sous"
L.T_BANISH_HINT      = "Bannit un Écho proposé dont la note commune passe sous ce seuil. Un bannissement doit être un consensus : à 0, tout Écho que personne n'a gardé serait visé."
L.T_REROLL           = "Relancer sous"
L.T_REROLL_HINT      = "Relance quand le MEILLEUR Écho proposé est sous ce seuil. Sur une échelle absolue, additionner la main ne veut rien dire : seule compte la présence d'un Écho qui vaut la peine."
L.T_GUARD            = "Garde de relance au-dessus"
L.T_GUARD_HINT       = "Empêche la relance dès qu'un seul Écho proposé atteint cette note. Laissez-la au niveau du seuil de relance ou en dessous, sinon les deux règles se contredisent."
L.T_FREEZE           = "Geler au-dessus"
L.T_FREEZE_HINT      = "Se déclenche quand au moins deux Échos proposés dépassent cette note. Le moins bon est gelé, le meilleur est pris tout de suite."
L.T_WEIGHT           = "Influence des poids"
L.T_WEIGHT_HINT      = "Vos poids s'ajoutent à chaque note : le meilleur Écho de votre build ajoute cette valeur, un Écho à moitié moins de poids ajoute la moitié. Les Échos que la communauté note plus près que cet écart sont départagés par vos poids."

L.DELETE_BUILD_CONFIRM = "Supprimer le build « %s » ?\n\nCette action est définitive."
L.AUTOMATION_ON      = "Automatisation : OUI"
L.AUTOMATION_OFF     = "Automatisation : NON"
L.EDIT_BUILD         = "Modifier"
L.STATS_TITLE        = "Statistiques du build"
L.STATS_QUALITY      = "Répartition des raretés :"
L.STAT_ECHOES_SEEN   = "Échos vus"
L.STAT_RUNS_COMPLETED = "Runs terminés"
L.STAT_RUNS_RESET    = "Runs recommencés"
L.STAT_PICKS         = "Choix"
L.STAT_REROLLS       = "Relances utilisées"
L.STAT_BANISHES      = "Bannissements utilisés"
L.STAT_FREEZES       = "Gels utilisés"
L.REQUESTING_DATA    = "Demande des données..."

L.ALL_CLASSES        = "Toutes les classes"
L.PAGE               = "Page %d sur %d"
L.WAIT_SECONDS       = "Attendre %ds"
L.PLAYER_BUILDS_SUB  = "Les builds enregistrés par les autres joueurs, récupérés automatiquement."
L.PLAYER_BUILDS_NONE = "Aucun build aux échos tous verrouillés pour l'instant. Cliquez sur Actualiser pour les demander."
L.RECEIVED_ECHOES    = "%d échos"
L.FAMILY_COUNT       = "%s (%d)"
L.DETAIL_LOCKED_UNKNOWN = "Ce joueur n'a pas transmis ses échos verrouillés."
L.ADD_TO_WISHLIST      = "Ajouter à ma wishlist"
L.WISHLIST_OTHER_CLASS = "Une wishlist est toujours pour votre propre classe."
L.WISHLIST_NAME_PROMPT = "Nom de la nouvelle wishlist :"
L.WISHLIST_DEFAULT_NAME = "%s %d échos"
L.WISHLIST_CREATED     = "Wishlist « %s » créée."

L.INTEREST_FOR       = "Intérêt pour %s"
L.GOES_WITH          = "Va bien avec : %s"
L.SAVED_SUBTITLE     = "%d build(s) -- emplacement %d actif, %d débloqué(s) sur %d"
L.SAVED_NONE         = "Aucun build reçu du serveur.\nOuvrez la fenêtre des Échos du jeu."

L.DELETE_SESSION_CONFIRM = "Supprimer cette session et tout son journal ?"
L.CLEAR_SESSIONS_CONFIRM = "Supprimer tout l'historique des sessions ? C'est définitif."
L.CARD_ACTIVE        = "|cff44ff44[En cours]|r  Niveau %d"
L.CARD_LEVEL         = "Niveau %d"
L.CARD_ASHES         = "Cendres d'âme : %s"
L.LOG_NO_DETAIL      = GREY .. "Le détail des choix n'est pas conservé pour cette session." .. R
L.LOG_DECISIONS      = "%d décision(s) : %s"
L.LOG_CHARGES_END    = "Charges en fin de run  B:%d R:%d G:%d"
L.SCORE              = "Note : %s"
L.EXPORT_SESSION_TITLE = "Export de session"
L.NO_SESSION_SELECTED = "Aucune session sélectionnée."
L.EXPORT_SESSION_HEADER = "Session : niveau %d | Durée : %s | Cendres d'âme : %s"
L.EXPORT_NO_DETAIL   = "Détail des choix non conservé. %d décision(s)."
L.EXPORT_CHARGES_END = "  charges en fin de run  B:%d R:%d G:%d"
L.LOGBOOK_HINT       = GREY .. "Cliquez sur une session pour voir son journal" .. R
L.CLEAR_ALL          = "Tout effacer"
L.LOGBOOK_HEADER     = GREY .. "Heure     Action      Écho 1          Écho 2          Écho 3          Écho 4          Charges" .. R

L.TOAST_AUTOMATION   = "Automatisation : %s"
L.TOAST_CHARGES      = GREY .. "Bannir : %d    Relancer : %d    Geler : %d" .. R

L.WIZARD_HEADER      = "Assistant de build"
L.WIZARD_STEP        = "Étape %d/%d"
L.CREATE_BUILD       = "Créer le build"
L.NEW_BUILD_TITLE    = "Nouveau build"
L.WEIGHT_WANT        = "Je le veux"
L.WEIGHT_GOOD        = "Bien"
L.WEIGHT_OK          = "Correct"
L.WEIGHT_MEH         = "Bof"
L.WIZARD_S0_TITLE    = "Comment voulez-vous créer votre build ?"
L.WIZARD_S0_DESC     = "Choisissez le mode qui vous convient."
L.WIZARD_MODE        = "Mode assistant"
L.WIZARD_MODE_DESC   = "Découvrez l'addon pas à pas. L'éditeur s'ouvre à la fin."
L.PRO_MODE           = "Mode expert"
L.PRO_MODE_DESC      = "Allez directement à l'éditeur, avec tous les réglages à la main."
L.WIZARD_S1_TITLE    = "Choisissez vos %d Échos verrouillés"
L.WIZARD_S2_TITLE    = "Puissance adaptative détectée !"
L.WIZARD_S2_DESC     = "La Puissance adaptative donne un bonus aux Échos que vous n'avez pas encore pris."
L.WIZARD_S2_HINT     = "Conseillé : 30 points"
L.WIZARD_S3_TITLE    = "Choisissez vos familles"
L.WIZARD_DEFAULTS_HINT = "Les valeurs par défaut conviennent à la plupart des builds. Ne changez que si c'est vraiment utile."
L.WIZARD_FAMILY_NONE = GREY .. "Aucune" .. R
L.WIZARD_FAMILY_SECONDARY = "Secondaire +10"
L.WIZARD_FAMILY_PRIMARY = "Principale +20"
L.WIZARD_S4_TITLE    = "Notez chaque rareté"
L.WIZARD_S5_TITLE    = "Quels Échos comptent le plus ?"
L.WIZARD_S5_DESC     = "Ajoutez des Échos et dites à quel point vous les voulez."
L.ADD_ECHO_BUTTON    = "+ Ajouter un Écho"
L.WIZARD_S5_EMPTY    = "Aucun Écho ajouté. Cliquez sur « + Ajouter un Écho » pour commencer."
L.WIZARD_S6_TITLE    = "Nommez et décrivez votre build"
L.WIZARD_S6_DESC     = "Vous pouvez insérer des liens d'objets, de sorts et d'Échos dans la description."
L.WIZARD_S6_HINT     = "Listez les objets, stratégies et affixes qui vont bien avec ce build. Maj+clic sur un objet pour insérer son lien."

L.EXPORT_BUILD_TITLE = "Exporter le build"
L.IMPORT_HINT        = "Collez une chaîne de build EbonBuilds, ou une chaîne EBH1 exportée depuis le Journal "
                       .. "des Échos (onglet Loadouts), puis cliquez sur Importer."
L.IMPORTED_BUILD     = "Build importé"
L.EBH1_IMPORTED      = "build « %s » importé (%s, %d écho(s))."
L.EBH1_KNOWN         = "le build « %s » est déjà importé."

L.SYNC_REQUESTING    = "Demande de synchronisation..."

L.BANLIST_PURGED     = "%d entrée(s) de liste de bans supprimée(s)."

EbonAPI.Locale.register(ns.NAME, { frFR = L })
