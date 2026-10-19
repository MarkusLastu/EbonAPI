local _, ns = ...

ns.api:Problems("EB", {
  ["AUTOMATION.BANISH_REFUSED"] = { class = "echec" },
  ["AUTOMATION.REROLL_REFUSED"] = { class = "echec" },
  ["AUTOMATION.FREEZE_REFUSED"] = { class = "echec" },
  ["AUTOMATION.CHOICE_UNKNOWN"] = { class = "partiel", key = "spellId" },
  ["AUTOMATION.OFFER_UNKNOWN"] = { class = "echec" },
  ["AUTOMATION.PERK_UI_MISSING"] = { class = "panne" },
})

EbonAPI.Locale.register(ns.NAME, {
  enUS = {
    PROBLEM_AUTOMATION_BANISH_REFUSED = "the game refused to banish the echo {echo}, so the automation did not banish it ({left} banishes left). The offer was left as it is",
    PROBLEM_AUTOMATION_REROLL_REFUSED = "the game refused the reroll asked by the automation ({left} rerolls left). The offer was left as it is",
    PROBLEM_AUTOMATION_FREEZE_REFUSED = "the game refused to freeze the echo {echo}, so the automation did not freeze it ({left} freezes left). The offer was left as it is",
    PROBLEM_AUTOMATION_CHOICE_UNKNOWN = "the offered echo {spellId} could not be scored ({detail}), so the automation ignored it for this offer",
    PROBLEM_AUTOMATION_OFFER_UNKNOWN = "none of the {offered} offered echoes could be scored, so the automation did not act on this offer. Choose an echo yourself",
    PROBLEM_AUTOMATION_PERK_UI_MISSING = "the echo selection window of the game is not available, so the automation is stopped. It starts again by itself as soon as the window appears",
  },
  frFR = {
    PROBLEM_AUTOMATION_BANISH_REFUSED = "le jeu a refusé de bannir l'écho {echo}, l'automatisation ne l'a donc pas banni ({left} bannissements restants). L'offre est restée telle quelle",
    PROBLEM_AUTOMATION_REROLL_REFUSED = "le jeu a refusé le relancement demandé par l'automatisation ({left} relancements restants). L'offre est restée telle quelle",
    PROBLEM_AUTOMATION_FREEZE_REFUSED = "le jeu a refusé de geler l'écho {echo}, l'automatisation ne l'a donc pas gelé ({left} gels restants). L'offre est restée telle quelle",
    PROBLEM_AUTOMATION_CHOICE_UNKNOWN = "l'écho proposé {spellId} n'a pas pu être noté ({detail}) : l'automatisation l'a ignoré pour cette offre",
    PROBLEM_AUTOMATION_OFFER_UNKNOWN = "aucun des {offered} échos proposés n'a pu être noté : l'automatisation n'a pas agi sur cette offre. Choisissez un écho vous-même",
    PROBLEM_AUTOMATION_PERK_UI_MISSING = "la fenêtre de choix des échos du jeu n'est pas disponible : l'automatisation est arrêtée. Elle repart d'elle-même dès que la fenêtre apparaît",
  },
  deDE = {
    PROBLEM_AUTOMATION_BANISH_REFUSED = "das Spiel hat das Verbannen des Echos {echo} abgelehnt, die Automatisierung hat es daher nicht verbannt (noch {left} Verbannungen). Das Angebot blieb unverändert",
    PROBLEM_AUTOMATION_REROLL_REFUSED = "das Spiel hat das von der Automatisierung gewünschte Neuwürfeln abgelehnt (noch {left} Neuwürfe). Das Angebot blieb unverändert",
    PROBLEM_AUTOMATION_FREEZE_REFUSED = "das Spiel hat das Einfrieren des Echos {echo} abgelehnt, die Automatisierung hat es daher nicht eingefroren (noch {left} Einfrierungen). Das Angebot blieb unverändert",
    PROBLEM_AUTOMATION_CHOICE_UNKNOWN = "das angebotene Echo {spellId} konnte nicht bewertet werden ({detail}), die Automatisierung hat es für dieses Angebot ignoriert",
    PROBLEM_AUTOMATION_OFFER_UNKNOWN = "keines der {offered} angebotenen Echos konnte bewertet werden, die Automatisierung hat bei diesem Angebot nicht gehandelt. Wählen Sie selbst ein Echo",
    PROBLEM_AUTOMATION_PERK_UI_MISSING = "das Echo-Auswahlfenster des Spiels ist nicht verfügbar, die Automatisierung ist daher angehalten. Sie startet von selbst neu, sobald das Fenster erscheint",
  },
  esES = {
    PROBLEM_AUTOMATION_BANISH_REFUSED = "el juego rechazó desterrar el eco {echo}, así que la automatización no lo desterró (quedan {left} destierros). La oferta se dejó como estaba",
    PROBLEM_AUTOMATION_REROLL_REFUSED = "el juego rechazó el reroll pedido por la automatización (quedan {left} rerolls). La oferta se dejó como estaba",
    PROBLEM_AUTOMATION_FREEZE_REFUSED = "el juego rechazó congelar el eco {echo}, así que la automatización no lo congeló (quedan {left} congelaciones). La oferta se dejó como estaba",
    PROBLEM_AUTOMATION_CHOICE_UNKNOWN = "el eco ofrecido {spellId} no se pudo puntuar ({detail}), así que la automatización lo ignoró en esta oferta",
    PROBLEM_AUTOMATION_OFFER_UNKNOWN = "ninguno de los {offered} ecos ofrecidos se pudo puntuar, así que la automatización no actuó en esta oferta. Elija un eco usted mismo",
    PROBLEM_AUTOMATION_PERK_UI_MISSING = "la ventana de elección de ecos del juego no está disponible, así que la automatización está detenida. Se reanuda sola en cuanto aparezca la ventana",
  },
})
