local _, ns = ...

ns.api:Problems("EB", {
  ["MATRIX.REPAIRED"] = { class = "reparation", key = "field" },
  ["MATRIX.REJECTED"] = { class = "rejet", key = "reason" },
  ["PROFILE.REJECTED"] = { class = "rejet", key = "reason" },
  ["PROFILE.SEND_FAILED"] = { class = "echec" },
  ["RATING.NO_RUN_DATA"] = { class = "partiel" },
})

EbonAPI.Locale.register(ns.NAME, {
  enUS = {
    PROBLEM_MATRIX_REPAIRED = "the saved matrix part \"{field}\" was malformed and has been reset; what it held is lost. Your own builds come back at the next refresh from the server; imported compositions must be imported again",
    PROBLEM_MATRIX_REJECTED = "the matrix refused a build or composition ({reason}: {sample}). It was not added to the matrix",
    PROBLEM_PROFILE_REJECTED = "a profile entry from {sender} could not be used ({reason}: {sample}). It was left out of the matrix",
    PROBLEM_PROFILE_SEND_FAILED = "your echo ban lists for {class} could not be sent to the other players. They will not see them until a send succeeds; change a build or reload the interface to try again",
    PROBLEM_RATING_NO_RUN_DATA = "the echoes of the current run are not known yet, so the ratings are computed for the class only and not for the run. They will follow the run as soon as the data arrives",
  },
  frFR = {
    PROBLEM_MATRIX_REPAIRED = "la partie \"{field}\" de la matrice enregistrée était abîmée et a été remise à zéro ; son contenu est perdu. Vos propres builds reviennent au prochain rafraîchissement depuis le serveur ; les compositions importées doivent être importées de nouveau",
    PROBLEM_MATRIX_REJECTED = "la matrice a refusé un build ou une composition ({reason} : {sample}). Il n'a pas été ajouté à la matrice",
    PROBLEM_PROFILE_REJECTED = "une entrée de profil de {sender} n'a pas pu être utilisée ({reason} : {sample}). Elle a été laissée hors de la matrice",
    PROBLEM_PROFILE_SEND_FAILED = "vos listes d'échos bannis pour {class} n'ont pas pu être envoyées aux autres joueurs. Ils ne les verront pas tant qu'un envoi n'aura pas réussi ; modifiez un build ou rechargez l'interface pour réessayer",
    PROBLEM_RATING_NO_RUN_DATA = "les échos de la run en cours ne sont pas encore connus : les notes sont calculées pour la classe seulement, pas pour la run. Elles suivront la run dès que les données arriveront",
  },
  deDE = {
    PROBLEM_MATRIX_REPAIRED = "der Teil \"{field}\" der gespeicherten Matrix war beschädigt und wurde zurückgesetzt; sein Inhalt ist verloren. Ihre eigenen Builds kommen bei der nächsten Aktualisierung vom Server zurück; importierte Zusammenstellungen müssen erneut importiert werden",
    PROBLEM_MATRIX_REJECTED = "die Matrix hat ein Build oder eine Zusammenstellung abgelehnt ({reason}: {sample}). Es wurde nicht zur Matrix hinzugefügt",
    PROBLEM_PROFILE_REJECTED = "ein Profileintrag von {sender} konnte nicht verwendet werden ({reason}: {sample}). Er wurde aus der Matrix herausgelassen",
    PROBLEM_PROFILE_SEND_FAILED = "die Echo-Sperrlisten für {class} konnten nicht an die anderen Spieler gesendet werden. Sie sehen sie erst nach einem erfolgreichen Senden; ändern Sie ein Build oder laden Sie die Oberfläche neu, um es erneut zu versuchen",
    PROBLEM_RATING_NO_RUN_DATA = "die Echos des laufenden Durchgangs sind noch nicht bekannt, daher werden die Bewertungen nur für die Klasse berechnet und nicht für den Durchgang. Sie folgen dem Durchgang, sobald die Daten eintreffen",
  },
  esES = {
    PROBLEM_MATRIX_REPAIRED = "la parte \"{field}\" de la matriz guardada estaba dañada y se ha restablecido; su contenido se ha perdido. Sus propios builds vuelven en la próxima actualización desde el servidor; las composiciones importadas deben importarse de nuevo",
    PROBLEM_MATRIX_REJECTED = "la matriz rechazó un build o una composición ({reason}: {sample}). No se añadió a la matriz",
    PROBLEM_PROFILE_REJECTED = "una entrada de perfil de {sender} no se pudo usar ({reason}: {sample}). Se dejó fuera de la matriz",
    PROBLEM_PROFILE_SEND_FAILED = "sus listas de ecos vetados para {class} no se pudieron enviar a los demás jugadores. No las verán hasta que un envío tenga éxito; cambie un build o recargue la interfaz para reintentarlo",
    PROBLEM_RATING_NO_RUN_DATA = "los ecos de la partida en curso aún no se conocen, así que las puntuaciones se calculan solo para la clase y no para la partida. Seguirán a la partida en cuanto lleguen los datos",
  },
})
