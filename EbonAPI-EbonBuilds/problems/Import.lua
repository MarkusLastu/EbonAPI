local _, ns = ...

ns.api:Problems("EB", {
  ["IMPORT.EMPTY"] = { class = "refus" },
  ["IMPORT.NOT_A_BUILD"] = { class = "refus" },
  ["IMPORT.EBH1_BAD_CLASS"] = { class = "refus" },
  ["IMPORT.EBH1_NO_ECHOES"] = { class = "refus" },
  ["IMPORT.EBH1_MATRIX_MISSING"] = { class = "echec" },
  ["SYNC.PROFILE_REJECTED"] = { class = "rejet", key = "reason" },
  ["SYNC.REQUEST_NOT_SENT"] = { class = "refus" },
})

EbonAPI.Locale.register(ns.NAME, {
  enUS = {
    PROBLEM_IMPORT_EMPTY = "nothing to import: the import field is empty. Paste an EbonBuilds build string or an EBH1 composition, then import again",
    PROBLEM_IMPORT_NOT_A_BUILD = "this text is not an EbonBuilds build: it could not be decoded ({reason}, {length} characters). Nothing was imported; copy the whole string again, without cutting its start or end",
    PROBLEM_IMPORT_EBH1_BAD_CLASS = "this EBH1 composition names the class \"{class}\", which is not a known class. Nothing was learned; check the class written after the echo list",
    PROBLEM_IMPORT_EBH1_NO_ECHOES = "this EBH1 composition contains no readable echo ({tokens} entries checked, none shaped like id.quality.stacks). Nothing was learned; copy the whole composition again",
    PROBLEM_IMPORT_EBH1_MATRIX_MISSING = "the composition matrix is not available, so this EBH1 composition could not be learned. Nothing was saved; reload the interface and try again",
    PROBLEM_SYNC_PROFILE_REJECTED = "a profile received from another player was rejected ({reason}, slot {slot}). It was not merged; sample: {sample}",
    PROBLEM_SYNC_REQUEST_NOT_SENT = "the sync request was not sent: the common channel is not joined yet, or an announcement was just made. Try again in a few seconds",
  },
  frFR = {
    PROBLEM_IMPORT_EMPTY = "rien à importer : le champ d'import est vide. Collez une chaîne de build EbonBuilds ou une composition EBH1, puis importez de nouveau",
    PROBLEM_IMPORT_NOT_A_BUILD = "ce texte n'est pas un build EbonBuilds : il n'a pas pu être décodé ({reason}, {length} caractères). Rien n'a été importé ; copiez de nouveau la chaîne entière, sans couper son début ni sa fin",
    PROBLEM_IMPORT_EBH1_BAD_CLASS = "cette composition EBH1 indique la classe « {class} », qui n'est pas une classe connue. Rien n'a été appris ; vérifiez la classe écrite après la liste des échos",
    PROBLEM_IMPORT_EBH1_NO_ECHOES = "cette composition EBH1 ne contient aucun écho lisible ({tokens} entrées examinées, aucune de la forme id.qualité.cumuls). Rien n'a été appris ; copiez de nouveau la composition entière",
    PROBLEM_IMPORT_EBH1_MATRIX_MISSING = "la matrice des compositions n'est pas disponible : cette composition EBH1 n'a pas pu être apprise. Rien n'a été enregistré ; rechargez l'interface et recommencez",
    PROBLEM_SYNC_PROFILE_REJECTED = "un profil reçu d'un autre joueur a été rejeté ({reason}, emplacement {slot}). Il n'a pas été fusionné ; extrait : {sample}",
    PROBLEM_SYNC_REQUEST_NOT_SENT = "la demande de synchronisation n'a pas été envoyée : le canal commun n'est pas encore rejoint, ou une annonce vient d'être faite. Réessayez dans quelques secondes",
  },
  deDE = {
    PROBLEM_IMPORT_EMPTY = "nichts zu importieren: das Importfeld ist leer. Fügen Sie eine EbonBuilds-Build-Zeichenfolge oder eine EBH1-Zusammenstellung ein und importieren Sie erneut",
    PROBLEM_IMPORT_NOT_A_BUILD = "dieser Text ist kein EbonBuilds-Build: er konnte nicht dekodiert werden ({reason}, {length} Zeichen). Es wurde nichts importiert; kopieren Sie die gesamte Zeichenfolge erneut, ohne Anfang oder Ende abzuschneiden",
    PROBLEM_IMPORT_EBH1_BAD_CLASS = "diese EBH1-Zusammenstellung nennt die Klasse \"{class}\", die nicht bekannt ist. Es wurde nichts gelernt; prüfen Sie die Klasse nach der Echo-Liste",
    PROBLEM_IMPORT_EBH1_NO_ECHOES = "diese EBH1-Zusammenstellung enthält kein lesbares Echo ({tokens} Einträge geprüft, keiner in der Form id.qualität.stapel). Es wurde nichts gelernt; kopieren Sie die gesamte Zusammenstellung erneut",
    PROBLEM_IMPORT_EBH1_MATRIX_MISSING = "die Zusammenstellungsmatrix ist nicht verfügbar, daher konnte diese EBH1-Zusammenstellung nicht gelernt werden. Es wurde nichts gespeichert; laden Sie die Oberfläche neu und versuchen Sie es erneut",
    PROBLEM_SYNC_PROFILE_REJECTED = "ein von einem anderen Spieler empfangenes Profil wurde abgelehnt ({reason}, Platz {slot}). Es wurde nicht zusammengeführt; Auszug: {sample}",
    PROBLEM_SYNC_REQUEST_NOT_SENT = "die Synchronisierungsanfrage wurde nicht gesendet: der gemeinsame Kanal ist noch nicht betreten, oder soeben wurde eine Ankündigung gemacht. Versuchen Sie es in einigen Sekunden erneut",
  },
  esES = {
    PROBLEM_IMPORT_EMPTY = "nada que importar: el campo de importación está vacío. Pegue una cadena de build de EbonBuilds o una composición EBH1 e importe de nuevo",
    PROBLEM_IMPORT_NOT_A_BUILD = "este texto no es un build de EbonBuilds: no se pudo decodificar ({reason}, {length} caracteres). No se importó nada; copie de nuevo la cadena completa, sin cortar su inicio ni su final",
    PROBLEM_IMPORT_EBH1_BAD_CLASS = "esta composición EBH1 indica la clase \"{class}\", que no es una clase conocida. No se aprendió nada; compruebe la clase escrita después de la lista de ecos",
    PROBLEM_IMPORT_EBH1_NO_ECHOES = "esta composición EBH1 no contiene ningún eco legible ({tokens} entradas revisadas, ninguna con la forma id.calidad.acumulaciones). No se aprendió nada; copie de nuevo la composición completa",
    PROBLEM_IMPORT_EBH1_MATRIX_MISSING = "la matriz de composiciones no está disponible, así que no se pudo aprender esta composición EBH1. No se guardó nada; recargue la interfaz e inténtelo de nuevo",
    PROBLEM_SYNC_PROFILE_REJECTED = "un perfil recibido de otro jugador fue rechazado ({reason}, ranura {slot}). No se fusionó; muestra: {sample}",
    PROBLEM_SYNC_REQUEST_NOT_SENT = "la solicitud de sincronización no se envió: el canal común aún no se ha unido, o se acaba de hacer un anuncio. Inténtelo de nuevo en unos segundos",
  },
})
