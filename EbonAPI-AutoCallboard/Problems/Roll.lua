local RT = AutoCallboardRuntime

RT.api:Problems("ACB", {
  ["ROLL.SELECT_FAILED"] = { class = "echec", key = "questId" },
  ["ROLL.REROLL_UNAFFORDABLE"] = { class = "refus" },
  ["ROLL.REROLL_FAILED"] = { class = "echec" },
  ["ROLL.REROLL_CONTROL_MISSING"] = { class = "echec" },
  ["ROLL.ABANDON_HOOK_FAILED"] = { class = "panne" },
  ["INSTANCE.MAP_UNAVAILABLE"] = { class = "partiel" },
})

EbonAPI.Locale.register("AutoCallboard", {
  enUS = {
    PROBLEM_ROLL_SELECT_FAILED = "the quest \"{title}\" was found in slot {slot} but could not be selected: {cause}. The board button could not be clicked either; the roll is paused, select the quest yourself on the board",
    PROBLEM_ROLL_REROLL_UNAFFORDABLE = "the roll stopped because you cannot afford another reroll: it costs {cost} and you have {gold}. Nothing was rerolled; earn the gold, then start the roll again",
    PROBLEM_ROLL_REROLL_FAILED = "the reroll request failed inside ProjectEbonhold ({detail}). No reroll took place and the roll is stopped; start it again, and update ProjectEbonhold if it keeps failing",
    PROBLEM_ROLL_REROLL_CONTROL_MISSING = "the roll cannot reroll: ProjectEbonhold's objectives service is not available and the board's Reroll button could not be clicked. The roll is stopped; open the objectives board and reroll by hand, and update ProjectEbonhold if it persists",
    PROBLEM_ROLL_ABANDON_HOOK_FAILED = "the link to the game's quest abandoning could not be set up. Abandoned quests will not leave the roll; reload the interface to try again",
    PROBLEM_INSTANCE_MAP_UNAVAILABLE = "the game gave no map name for this instance after {attempts} attempts, so its quest cannot be targeted automatically. Choose the quest yourself in the list, or leave and re-enter the instance to try again",
  },
  frFR = {
    PROBLEM_ROLL_SELECT_FAILED = "la quête « {title} » a été trouvée dans l'emplacement {slot} mais n'a pas pu être choisie : {cause}. Le bouton du tableau n'a pas pu être cliqué non plus ; le roll est en pause, choisissez la quête vous-même sur le tableau",
    PROBLEM_ROLL_REROLL_UNAFFORDABLE = "le roll s'est arrêté car vous ne pouvez pas payer un nouveau reroll : il coûte {cost} et vous avez {gold}. Rien n'a été relancé ; gagnez l'or nécessaire, puis relancez le roll",
    PROBLEM_ROLL_REROLL_FAILED = "la demande de reroll a échoué dans ProjectEbonhold ({detail}). Aucun reroll n'a eu lieu et le roll est arrêté ; relancez-le, et mettez ProjectEbonhold à jour si cela persiste",
    PROBLEM_ROLL_REROLL_CONTROL_MISSING = "le roll ne peut pas relancer : le service d'objectifs de ProjectEbonhold n'est pas disponible et le bouton Reroll du tableau n'a pas pu être cliqué. Le roll est arrêté ; ouvrez le tableau des objectifs et relancez à la main, et mettez ProjectEbonhold à jour si cela persiste",
    PROBLEM_ROLL_ABANDON_HOOK_FAILED = "le lien avec l'abandon de quête du jeu n'a pas pu être établi. Les quêtes abandonnées ne sortiront pas du roll ; rechargez l'interface pour réessayer",
    PROBLEM_INSTANCE_MAP_UNAVAILABLE = "le jeu n'a donné aucun nom de carte pour cette instance après {attempts} essais, donc sa quête ne peut pas être ciblée automatiquement. Choisissez la quête vous-même dans la liste, ou sortez de l'instance et rentrez-y pour réessayer",
  },
  deDE = {
    PROBLEM_ROLL_SELECT_FAILED = "die Quest \"{title}\" wurde in Platz {slot} gefunden, konnte aber nicht gewählt werden: {cause}. Die Schaltfläche der Tafel konnte ebenfalls nicht angeklickt werden; der Roll ist pausiert, wählen Sie die Quest selbst auf der Tafel",
    PROBLEM_ROLL_REROLL_UNAFFORDABLE = "der Roll wurde angehalten, weil Sie sich keinen weiteren Reroll leisten können: er kostet {cost} und Sie haben {gold}. Es wurde nichts neu gewürfelt; verdienen Sie das Gold und starten Sie den Roll erneut",
    PROBLEM_ROLL_REROLL_FAILED = "die Reroll-Anfrage ist in ProjectEbonhold fehlgeschlagen ({detail}). Es fand kein Reroll statt und der Roll ist angehalten; starten Sie ihn erneut und aktualisieren Sie ProjectEbonhold, falls es weiter fehlschlägt",
    PROBLEM_ROLL_REROLL_CONTROL_MISSING = "der Roll kann keinen Reroll auslösen: der Zieldienst von ProjectEbonhold ist nicht verfügbar und die Reroll-Schaltfläche der Tafel konnte nicht angeklickt werden. Der Roll ist angehalten; öffnen Sie die Zieltafel und würfeln Sie von Hand neu, und aktualisieren Sie ProjectEbonhold, falls es bestehen bleibt",
    PROBLEM_ROLL_ABANDON_HOOK_FAILED = "die Verbindung zum Aufgeben von Quests im Spiel konnte nicht hergestellt werden. Aufgegebene Quests verlassen den Roll nicht; laden Sie die Oberfläche neu, um es erneut zu versuchen",
    PROBLEM_INSTANCE_MAP_UNAVAILABLE = "das Spiel hat nach {attempts} Versuchen keinen Kartennamen für diese Instanz geliefert, daher kann ihre Quest nicht automatisch gewählt werden. Wählen Sie die Quest selbst in der Liste, oder verlassen Sie die Instanz und betreten Sie sie erneut",
  },
  esES = {
    PROBLEM_ROLL_SELECT_FAILED = "la misión \"{title}\" se encontró en la casilla {slot} pero no se pudo elegir: {cause}. Tampoco se pudo pulsar el botón del tablón; el roll está en pausa, elija usted mismo la misión en el tablón",
    PROBLEM_ROLL_REROLL_UNAFFORDABLE = "el roll se detuvo porque no puede pagar otro reroll: cuesta {cost} y usted tiene {gold}. No se relanzó nada; consiga el oro y vuelva a iniciar el roll",
    PROBLEM_ROLL_REROLL_FAILED = "la petición de reroll falló dentro de ProjectEbonhold ({detail}). No hubo ningún reroll y el roll está detenido; vuelva a iniciarlo y actualice ProjectEbonhold si sigue fallando",
    PROBLEM_ROLL_REROLL_CONTROL_MISSING = "el roll no puede relanzar: el servicio de objetivos de ProjectEbonhold no está disponible y no se pudo pulsar el botón Reroll del tablón. El roll está detenido; abra el tablón de objetivos y relance a mano, y actualice ProjectEbonhold si persiste",
    PROBLEM_ROLL_ABANDON_HOOK_FAILED = "no se pudo establecer el enlace con el abandono de misiones del juego. Las misiones abandonadas no saldrán del roll; recargue la interfaz para volver a intentarlo",
    PROBLEM_INSTANCE_MAP_UNAVAILABLE = "el juego no dio ningún nombre de mapa para esta instancia tras {attempts} intentos, así que su misión no se puede elegir automáticamente. Elija usted mismo la misión en la lista, o salga de la instancia y vuelva a entrar",
  },
})
