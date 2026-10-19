local RT = AutoCallboardRuntime

RT.api:Problems("ACB", {
  ["BUILDS.SWITCH_BLOCKED_COMBAT"] = { class = "refus" },
  ["BUILDS.SWITCH_SEND_FAILED"] = { class = "echec", key = "slot" },
  ["ETERNALS.ETERNAL_ITEM_MISSING"] = { class = "echec" },
  ["ETERNALS.QUEST_GONE"] = { class = "echec" },
  ["ETERNALS.SEQUENCE_TIMEOUT"] = { class = "echec" },
  ["ETERNALS.NOT_ENOUGH_CRYSTALS"] = { class = "refus" },
  ["ETERNALS.BIND_KEY_MISSING"] = { class = "refus" },
  ["ETERNALS.UNKNOWN_COMMAND"] = { class = "refus" },
})

EbonAPI.Locale.register("AutoCallboard", {
  enUS = {
    PROBLEM_BUILDS_SWITCH_BLOCKED_COMBAT = "the build in slot {slot} cannot be switched while you are in combat. Nothing was changed; try again once combat has ended",
    PROBLEM_BUILDS_SWITCH_SEND_FAILED = "the request to switch to the build in slot {slot} could not be sent to the server. The active build was not changed; try again in a moment",
    PROBLEM_ETERNALS_ETERNAL_ITEM_MISSING = "the Eternal item \"{item}\" is not in your bags any more. The conversion was stopped; put the item back in your bags and start again",
    PROBLEM_ETERNALS_QUEST_GONE = "the quest for \"{item}\" is no longer in your quest log. The conversion was stopped; accept the quest again to start over",
    PROBLEM_ETERNALS_SEQUENCE_TIMEOUT = "the conversion of \"{item}\" did not finish within {seconds} seconds. It was stopped; start it again",
    PROBLEM_ETERNALS_NOT_ENOUGH_CRYSTALS = "the conversion of \"{item}\" needs {required} crystals and you only have {count}. Nothing was converted; gather more crystals first",
    PROBLEM_ETERNALS_BIND_KEY_MISSING = "the command \"{input}\" gives no key to bind. Nothing was bound; type the command followed by the key, for example bind F5",
    PROBLEM_ETERNALS_UNKNOWN_COMMAND = "the command \"{input}\" is not known. Nothing was done; the only command available is bind followed by a key",
    ETERNALS_BIND_DONE = "%s",
    },
  frFR = {
    PROBLEM_BUILDS_SWITCH_BLOCKED_COMBAT = "le build de l'emplacement {slot} ne peut pas être changé pendant un combat. Rien n'a été modifié ; réessayez quand le combat sera terminé",
    PROBLEM_BUILDS_SWITCH_SEND_FAILED = "la demande de changement vers le build de l'emplacement {slot} n'a pas pu être envoyée au serveur. Le build actif n'a pas changé ; réessayez dans un instant",
    PROBLEM_ETERNALS_ETERNAL_ITEM_MISSING = "l'objet éternel \"{item}\" n'est plus dans vos sacs. La conversion a été arrêtée ; remettez l'objet dans vos sacs puis recommencez",
    PROBLEM_ETERNALS_QUEST_GONE = "la quête de \"{item}\" n'est plus dans votre journal de quêtes. La conversion a été arrêtée ; acceptez de nouveau la quête pour recommencer",
    PROBLEM_ETERNALS_SEQUENCE_TIMEOUT = "la conversion de \"{item}\" ne s'est pas terminée en {seconds} secondes. Elle a été arrêtée ; relancez-la",
    PROBLEM_ETERNALS_NOT_ENOUGH_CRYSTALS = "la conversion de \"{item}\" demande {required} cristaux et vous n'en avez que {count}. Rien n'a été converti ; rassemblez d'abord plus de cristaux",
    PROBLEM_ETERNALS_BIND_KEY_MISSING = "la commande \"{input}\" ne donne aucune touche à lier. Rien n'a été lié ; saisissez la commande suivie de la touche, par exemple bind F5",
    PROBLEM_ETERNALS_UNKNOWN_COMMAND = "la commande \"{input}\" est inconnue. Rien n'a été fait ; la seule commande disponible est bind suivie d'une touche",
    ETERNALS_BIND_DONE = "%s",
    },
  deDE = {
    PROBLEM_BUILDS_SWITCH_BLOCKED_COMBAT = "der Build auf Platz {slot} kann im Kampf nicht gewechselt werden. Es wurde nichts geändert; versuchen Sie es nach dem Kampf erneut",
    PROBLEM_BUILDS_SWITCH_SEND_FAILED = "die Anfrage zum Wechsel auf den Build auf Platz {slot} konnte nicht an den Server gesendet werden. Der aktive Build wurde nicht geändert; versuchen Sie es gleich noch einmal",
    PROBLEM_ETERNALS_ETERNAL_ITEM_MISSING = "der ewige Gegenstand \"{item}\" befindet sich nicht mehr in Ihren Taschen. Die Umwandlung wurde abgebrochen; legen Sie den Gegenstand zurück in Ihre Taschen und beginnen Sie neu",
    PROBLEM_ETERNALS_QUEST_GONE = "die Quest für \"{item}\" ist nicht mehr in Ihrem Questlog. Die Umwandlung wurde abgebrochen; nehmen Sie die Quest erneut an, um neu zu beginnen",
    PROBLEM_ETERNALS_SEQUENCE_TIMEOUT = "die Umwandlung von \"{item}\" wurde nicht innerhalb von {seconds} Sekunden abgeschlossen. Sie wurde abgebrochen; starten Sie sie erneut",
    PROBLEM_ETERNALS_NOT_ENOUGH_CRYSTALS = "für die Umwandlung von \"{item}\" werden {required} Kristalle benötigt, Sie haben nur {count}. Es wurde nichts umgewandelt; sammeln Sie zuerst mehr Kristalle",
    PROBLEM_ETERNALS_BIND_KEY_MISSING = "der Befehl \"{input}\" nennt keine Taste zum Belegen. Es wurde nichts belegt; geben Sie den Befehl mit einer Taste ein, zum Beispiel bind F5",
    PROBLEM_ETERNALS_UNKNOWN_COMMAND = "der Befehl \"{input}\" ist unbekannt. Es wurde nichts getan; der einzige verfügbare Befehl ist bind gefolgt von einer Taste",
    ETERNALS_BIND_DONE = "%s",
    },
  esES = {
    PROBLEM_BUILDS_SWITCH_BLOCKED_COMBAT = "la build de la ranura {slot} no se puede cambiar durante el combate. No se ha modificado nada; inténtelo de nuevo cuando termine el combate",
    PROBLEM_BUILDS_SWITCH_SEND_FAILED = "la solicitud de cambio a la build de la ranura {slot} no se pudo enviar al servidor. La build activa no ha cambiado; inténtelo de nuevo en un momento",
    PROBLEM_ETERNALS_ETERNAL_ITEM_MISSING = "el objeto eterno \"{item}\" ya no está en sus bolsas. La conversión se ha detenido; vuelva a colocar el objeto en sus bolsas y empiece de nuevo",
    PROBLEM_ETERNALS_QUEST_GONE = "la misión de \"{item}\" ya no está en su registro de misiones. La conversión se ha detenido; acepte la misión de nuevo para empezar otra vez",
    PROBLEM_ETERNALS_SEQUENCE_TIMEOUT = "la conversión de \"{item}\" no terminó en {seconds} segundos. Se ha detenido; inícielo de nuevo",
    PROBLEM_ETERNALS_NOT_ENOUGH_CRYSTALS = "la conversión de \"{item}\" necesita {required} cristales y usted solo tiene {count}. No se ha convertido nada; reúna más cristales primero",
    PROBLEM_ETERNALS_BIND_KEY_MISSING = "el comando \"{input}\" no indica ninguna tecla que asignar. No se ha asignado nada; escriba el comando seguido de la tecla, por ejemplo bind F5",
    PROBLEM_ETERNALS_UNKNOWN_COMMAND = "el comando \"{input}\" no se conoce. No se ha hecho nada; el único comando disponible es bind seguido de una tecla",
    ETERNALS_BIND_DONE = "%s",
    },
})
