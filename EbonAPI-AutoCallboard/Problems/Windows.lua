local RT = AutoCallboardRuntime

RT.api:Problems("ACB", {
  ["ROUTEWINDOW.DRAFT_EMPTY"] = { class = "refus" },
  ["ROUTEWINDOW.ROUTES_FULL"] = { class = "refus", key = "category" },
  ["ROUTEWINDOW.ROUTE_MISSING"] = { class = "echec", key = "route" },
  ["ROUTEWINDOW.CHANGE_REFUSED"] = { class = "echec", key = "action" },
  ["ROUTEWINDOW.EDIT_LOCKED"] = { class = "refus" },
  ["ROUTEWINDOW.PLAYBACK_REFUSED"] = { class = "refus" },
  ["CONTROL.SUMMON_ON_COOLDOWN"] = { class = "refus" },
  ["CONTROL.SUMMON_UNUSABLE"] = { class = "refus" },
})

EbonAPI.Locale.register("AutoCallboard", {
  enUS = {
    PROBLEM_ROUTEWINDOW_DRAFT_EMPTY = "the route was not saved because the recording holds no step. Nothing was changed; record at least one step, then save again",
    PROBLEM_ROUTEWINDOW_ROUTES_FULL = "the route could not go into the category \"{category}\" because it already holds {limit} routes. The route stays where it was; delete a route from that category or choose another one",
    PROBLEM_ROUTEWINDOW_ROUTE_MISSING = "the route \"{route}\" no longer exists, so the change was not made. The list is refreshed; choose a route that is still there",
    PROBLEM_ROUTEWINDOW_CHANGE_REFUSED = "the change to the route \"{route}\" was refused and nothing was modified. Check that the route is still in the list and try again",
    PROBLEM_ROUTEWINDOW_EDIT_LOCKED = "the route \"{route}\" cannot be changed or loaded while a route is being played. Nothing was changed; stop the playback first",
    PROBLEM_ROUTEWINDOW_PLAYBACK_REFUSED = "the route \"{route}\" was not played because a recording is in progress. The recording continues; stop it, then start the playback again",
    PROBLEM_CONTROL_SUMMON_ON_COOLDOWN = "the Callboard cannot be summoned yet: its spell is recovering for another {cooldown} seconds. No summon was attempted; click the button again once the recovery is over",
    PROBLEM_CONTROL_SUMMON_UNUSABLE = "the spell \"{spell}\" cannot be cast right now, and \"{target}\" is not available to target. No summon was made; move to a place where the spell can be cast, then click the button again",
  },
  frFR = {
    PROBLEM_ROUTEWINDOW_DRAFT_EMPTY = "le parcours n'a pas été enregistré car l'enregistrement ne contient aucune étape. Rien n'a été modifié ; enregistrez au moins une étape, puis recommencez",
    PROBLEM_ROUTEWINDOW_ROUTES_FULL = "le parcours n'a pas pu aller dans la catégorie « {category} » car elle contient déjà {limit} parcours. Le parcours reste où il était ; supprimez un parcours de cette catégorie ou choisissez-en une autre",
    PROBLEM_ROUTEWINDOW_ROUTE_MISSING = "le parcours « {route} » n'existe plus, donc la modification n'a pas été faite. La liste est actualisée ; choisissez un parcours encore présent",
    PROBLEM_ROUTEWINDOW_CHANGE_REFUSED = "la modification du parcours « {route} » a été refusée et rien n'a été changé. Vérifiez que le parcours est toujours dans la liste, puis réessayez",
    PROBLEM_ROUTEWINDOW_EDIT_LOCKED = "le parcours « {route} » ne peut pas être modifié ni chargé pendant la lecture d'un parcours. Rien n'a été changé ; arrêtez d'abord la lecture",
    PROBLEM_ROUTEWINDOW_PLAYBACK_REFUSED = "le parcours « {route} » n'a pas été lu car un enregistrement est en cours. L'enregistrement continue ; arrêtez-le, puis relancez la lecture",
    PROBLEM_CONTROL_SUMMON_ON_COOLDOWN = "le tableau ne peut pas encore être invoqué : son sort récupère encore pendant {cooldown} secondes. Aucune invocation n'a été tentée ; cliquez de nouveau sur le bouton une fois la récupération terminée",
    PROBLEM_CONTROL_SUMMON_UNUSABLE = "le sort « {spell} » ne peut pas être lancé pour le moment, et « {target} » n'est pas disponible comme cible. Aucune invocation n'a été faite ; rendez-vous à un endroit où le sort peut être lancé, puis cliquez de nouveau sur le bouton",
  },
  deDE = {
    PROBLEM_ROUTEWINDOW_DRAFT_EMPTY = "die Route wurde nicht gespeichert, weil die Aufnahme keinen Schritt enthält. Es wurde nichts geändert; nehmen Sie mindestens einen Schritt auf und speichern Sie dann erneut",
    PROBLEM_ROUTEWINDOW_ROUTES_FULL = "die Route konnte nicht in die Kategorie \"{category}\" verschoben werden, weil sie bereits {limit} Routen enthält. Die Route bleibt, wo sie war; löschen Sie eine Route aus dieser Kategorie oder wählen Sie eine andere",
    PROBLEM_ROUTEWINDOW_ROUTE_MISSING = "die Route \"{route}\" existiert nicht mehr, daher wurde die Änderung nicht vorgenommen. Die Liste wurde aktualisiert; wählen Sie eine noch vorhandene Route",
    PROBLEM_ROUTEWINDOW_CHANGE_REFUSED = "die Änderung der Route \"{route}\" wurde abgelehnt und nichts wurde verändert. Prüfen Sie, ob die Route noch in der Liste steht, und versuchen Sie es erneut",
    PROBLEM_ROUTEWINDOW_EDIT_LOCKED = "die Route \"{route}\" kann während der Wiedergabe einer Route weder geändert noch geladen werden. Es wurde nichts geändert; beenden Sie zuerst die Wiedergabe",
    PROBLEM_ROUTEWINDOW_PLAYBACK_REFUSED = "die Route \"{route}\" wurde nicht abgespielt, weil gerade eine Aufnahme läuft. Die Aufnahme läuft weiter; beenden Sie sie und starten Sie die Wiedergabe dann erneut",
    PROBLEM_CONTROL_SUMMON_ON_COOLDOWN = "die Auftragstafel kann noch nicht beschworen werden: ihr Zauber ist noch {cooldown} Sekunden in der Abklingzeit. Es wurde keine Beschwörung versucht; klicken Sie nach der Abklingzeit erneut auf die Schaltfläche",
    PROBLEM_CONTROL_SUMMON_UNUSABLE = "der Zauber \"{spell}\" kann im Moment nicht gewirkt werden, und \"{target}\" ist als Ziel nicht verfügbar. Es wurde nichts beschworen; begeben Sie sich an einen Ort, an dem der Zauber gewirkt werden kann, und klicken Sie dann erneut auf die Schaltfläche",
  },
  esES = {
    PROBLEM_ROUTEWINDOW_DRAFT_EMPTY = "la ruta no se guardó porque la grabación no contiene ningún paso. No se cambió nada; grabe al menos un paso y vuelva a guardar",
    PROBLEM_ROUTEWINDOW_ROUTES_FULL = "la ruta no pudo pasar a la categoría \"{category}\" porque ya contiene {limit} rutas. La ruta se queda donde estaba; elimine una ruta de esa categoría o elija otra",
    PROBLEM_ROUTEWINDOW_ROUTE_MISSING = "la ruta \"{route}\" ya no existe, así que no se hizo el cambio. La lista se ha actualizado; elija una ruta que siga presente",
    PROBLEM_ROUTEWINDOW_CHANGE_REFUSED = "se rechazó el cambio de la ruta \"{route}\" y no se modificó nada. Compruebe que la ruta sigue en la lista e inténtelo de nuevo",
    PROBLEM_ROUTEWINDOW_EDIT_LOCKED = "la ruta \"{route}\" no se puede modificar ni cargar mientras se reproduce una ruta. No se cambió nada; detenga primero la reproducción",
    PROBLEM_ROUTEWINDOW_PLAYBACK_REFUSED = "la ruta \"{route}\" no se reprodujo porque hay una grabación en curso. La grabación continúa; deténgala y vuelva a iniciar la reproducción",
    PROBLEM_CONTROL_SUMMON_ON_COOLDOWN = "el tablón aún no se puede invocar: su hechizo se está recuperando durante {cooldown} segundos más. No se intentó ninguna invocación; haga clic de nuevo en el botón cuando termine la recuperación",
    PROBLEM_CONTROL_SUMMON_UNUSABLE = "el hechizo \"{spell}\" no se puede lanzar ahora y \"{target}\" no está disponible como objetivo. No se hizo ninguna invocación; vaya a un lugar donde se pueda lanzar el hechizo y haga clic de nuevo en el botón",
  },
})
