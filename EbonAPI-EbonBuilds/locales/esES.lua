
local _, ns = ...
local L, C = {}, ns.C
local GOLD, RED, GREEN, GREY, R = C.GOLD, C.RED, C.GREEN, C.GREY, C.R

L.REROLL             = "Tirar (Orbe: %s)"
L.REROLL_BUSY        = "Tirando..."
L.REROLL_TITLE       = "Volver a tirar con un Orbe"
L.REROLL_BODY        = "Toma %s y lo olvida de nuevo para una nueva tirada."
L.REROLL_COST        = "Coste: " .. GOLD .. "%d Orbe%s" .. R .. "   Reserva: " .. GOLD .. "%d" .. R

L.TOGGLE             = "Caza"
L.HUNT               = "Cazar (%d)"
L.HUNT_MULT          = "Cazar (%d) x%d"
L.HUNT_STOP          = "Parar (%d/%d)"
L.HUNT_TITLE         = "Cazar Ecos"
L.HUNT_RUNNING       = "Caza en curso"
L.HUNT_PROGRESS      = "%d de %d orbes gastados, %d por tirada."
L.HUNT_CLICK_STOP    = "Haz clic para parar."
L.HUNT_BODY          = "Vuelve a tirar hasta que salga uno de tus %d Eco(s) marcados."
L.HUNT_BODY_COST     = "Coste: " .. GOLD .. "%d orbe(s)" .. R .. " por tirada - %d tirada(s) por "
                       .. GOLD .. "%d orbe(s)" .. R .. "."
L.HUNT_BODY_MANUAL   = "El Eco encontrado nunca se toma por ti."
L.HUNT_BODY_HINT     = "El coste sigue el deslizador de calidad del juego, leído de tu último gasto de orbe."

L.RARITY_TITLE       = "Rareza buscada"
L.RARITY_BODY        = "Para cada Eco marcado, la rareza mínima en la que la caza se detiene."
L.RARITY_HINT        = "La mayoría de los Ecos existen en varias rarezas. Una caza las acepta "
                       .. "todas mientras no decidas otra cosa aquí."
L.RARITY_ANY         = "Cualquier rareza"
L.RARITY_MIN         = "%s o mejor"

L.BUDGET             = "Orbes a gastar: " .. GOLD .. "%d" .. R
L.BUDGET_DRAWS       = "Orbes a gastar: " .. GOLD .. "%d" .. R .. "  " .. GREY .. "(%d tirada%s a %d)" .. R

L.BUSY               = "Ya hay una tirada en curso."
L.NO_CHOICE          = "No hay elección de Ecos en la mesa."
L.PICK_IN_FLIGHT     = "Ya hay una selección en curso."
L.NONE_FORGETTABLE   = "Ninguna de estas cartas puede olvidarse de nuevo."
L.CHARGES_UNKNOWN    = "Esperando tu recuento de Orbes."
L.NOT_ENOUGH_ORBS    = "Una tirada cuesta %d orbes y tienes %d."
L.HUNT_RUNNING_ALREADY = "Ya hay una caza en curso."
L.NOTHING_ARMED      = "Ningún Eco marcado. Ctrl+clic en uno del diario de Ecos."
L.HUNT_MARK          = "Ctrl+clic: cazar este Eco"
L.HUNT_UNMARK        = "Ctrl+clic: dejar de cazar"
L.AUTO_ACCEPT_ON     = "Desactiva \"auto-accept loadout echoes\" de Ebonhold antes de cazar."
L.BUDGET_TOO_LOW     = "Presupuesto muy bajo: una tirada cuesta %d orbes, sube el deslizador."

L.HUNT_STARTED       = "Caza iniciada: %d Eco(s) buscados, hasta " .. GOLD .. "%d orbe%s" .. R
                       .. " - %d tirada%s a " .. GOLD .. "%d" .. R .. " cada una."
L.HUNT_SPENT         = " " .. GREY .. "(gasto: %d orbe%s)" .. R
L.HUNT_FOUND         = GREEN .. "Encontrado:" .. R .. " %s " .. GREY .. "- tuyo para elegir." .. R
L.HUNT_BUDGET_DONE   = "Presupuesto gastado, caza terminada."
L.HUNT_NO_ORBS       = RED .. "No quedan orbes suficientes (%d por tirada), caza terminada." .. R
L.HUNT_STOPPED       = "Caza detenida."
L.HUNT_INTERRUPTED   = RED .. "Caza interrumpida." .. R
L.HUNT_BEFORE_SPEND  = RED .. "Caza interrumpida antes del gasto." .. R
L.HUNT_WENT_PERMANENT = RED .. "Caza detenida: el Eco tomado volvió permanente." .. R
L.HUNT_SPEND_FAILED  = RED .. "Caza detenida: el gasto falló." .. R

L.LIVE_TITLE         = "Caza: gasto |cffffffff%d/%d|r orbe%s"
L.LIVE_WANTED        = GREY .. "Buscando:" .. R .. " %s"
L.LIVE_WANTED_MIN    = "%s (%s+)"

L.PICK_TIMED_OUT     = "La selección expiró - no se gastó ningún orbe."
L.WENT_PERMANENT     = RED .. "%s volvió permanente, así que no puede olvidarse - no se gastó "
                       .. "ningún orbe. Es tuyo." .. R
L.THAT_ECHO          = "Ese Eco"
L.NO_PERK_SYSTEM     = "No se encontró el sistema de perks de Project Ebonhold - el panel permanece oculto."
L.NO_JOURNAL         = "No se encontró el diario de Ecos de ProjectEbonhold - no se pueden marcar Ecos para una caza."

L.GUARD_BODY         = "Retiene la selección automática, para que la tirada sea tuya."
L.GUARD_ON           = "Activo. Haz clic para desactivar."
L.GUARD_OFF          = "Inactivo. Haz clic para activar."
L.HUNT_STOPPED_CLICK = "Caza detenida: tomaste una carta tú mismo."


L.ALL                = "Todos"
L.UNTITLED           = "Sin título"
L.UNKNOWN            = "Desconocido"
L.SAVE               = "Guardar"
L.EXPORT             = "Exportar"
L.IMPORT             = "Importar"
L.RELOAD             = "Recargar"
L.NEXT               = "Siguiente"
L.PREVIOUS           = "Anterior"
L.BACK               = "Atrás"
L.REMOVE             = "Quitar"
L.RANDOM             = "Al azar"
L.TITLE_LABEL        = "Título:"
L.DESCRIPTION_LABEL  = "Descripción:"
L.LOCKED_ECHOES      = "Ecos bloqueados:"
L.BUILD_META         = "por %s | %s | %s"
L.SPEC_N             = "Espec. %d"
L.LOCKED             = "Bloqueado"
L.BANNED             = "Desterrado"

L.FAMILY = {
    Tank          = "Tanque",
    Survivability = "Supervivencia",
    Healer        = "Sanador",
    Caster        = "Lanzador",
    Melee         = "Cuerpo a cuerpo",
    Ranged        = "A distancia",
    ["No family"] = "Sin familia",
}
L.FAMILY_LONG = {
    Tank          = "Tanque",
    Survivability = "Supervivencia",
    Healer        = "Sanador",
    Caster        = "DPS lanzador",
    Melee         = "DPS cuerpo a cuerpo",
    Ranged        = "DPS a distancia",
}
L.ACTION = {
    Select              = "Elegir",
    ["Select (Locked)"] = "Elegir (bloqueado)",
    Banish              = "Desterrar",
    Reroll              = "Volver a tirar",
    Freeze              = "Congelar",
}
L.SPEC = {
    WARRIOR     = { "Armas", "Furia", "Protección" },
    PALADIN     = { "Sagrado", "Protección", "Reprensión" },
    HUNTER      = { "Dominio de bestias", "Puntería", "Supervivencia" },
    ROGUE       = { "Asesinato", "Combate", "Sutileza" },
    PRIEST      = { "Disciplina", "Sagrado", "Sombra" },
    DEATHKNIGHT = { "Sangre", "Escarcha", "Profano" },
    SHAMAN      = { "Elemental", "Mejora", "Restauración" },
    MAGE        = { "Arcano", "Fuego", "Escarcha" },
    WARLOCK     = { "Aflicción", "Demonología", "Destrucción" },
    DRUID       = { "Equilibrio", "Combate feral", "Restauración" },
}

L.SAVED_BUILDS       = "Builds guardados"
L.PLAYER_BUILDS      = "Builds de jugadores"
L.IMPORT_BUILD       = "Importar build"
L.NEW_BUILD_BUTTON   = "+ Nuevo build"
L.WELCOME_TITLE      = "Todavía no hay builds"
L.WELCOME_BODY       = "Crea tu primer build o explora los builds públicos."
L.MINIMAP_TIP        = "Haz clic para abrir la configuración"

L.SETTINGS_TITLE     = "Ajustes de EbonBuilds"
L.SETTINGS_DELAY     = "Retraso de acción:"
L.SETTINGS_DELAY_HINT = "Valores muy bajos pueden causar problemas al addon."
L.SETTINGS_TOAST     = "Duración del aviso:"


L.TAB_OVERVIEW       = "Resumen"
L.TAB_ECHOES         = "Ecos"
L.TAB_BONUS          = "Bonus"
L.TAB_AUTOMATION     = "Automatización"
L.TAB_STATS          = "Estadísticas"
L.TAB_MISSING        = "Faltan"
L.TAB_LOGBOOK        = "Diario"

L.FORM_HEADER        = "Build"
L.FORM_CLASS         = "Clase:"
L.FORM_SPEC          = "Espec.:"
L.FORM_DESCRIPTION_HINT = "Explica aquí la estrategia del build. Las pestañas Ecos y Bonus sirven para ajustar los pesos."
L.INSERT_LINK_BUTTON = "+ Enlace de Eco"
L.INSERT_LINK_BODY   = "Inserta en la descripción una referencia a un Eco en la que se puede hacer clic."
L.INSERT_LINK_HINT1  = "Para ajustar los pesos y bonus de este build,"
L.INSERT_LINK_HINT2  = "usa las pestañas Ecos y Bonus después de guardar."

L.BONUS_HEADER       = "Bonus"
L.BONUS_QUALITY      = "Bonus de rareza:"
L.BONUS_FAMILY       = "Bonus de familia:"
L.BONUS_NOVELTY      = "Bonus de novedad:"
L.BONUS_MODE_HINT    = "+ suma el valor, |cff19ff19x|r lo multiplica. En modo |cff19ff19x|r, menos de 1 reduce la nota."
L.BONUS_NOVELTY_HINT = "Los Ecos que nunca has obtenido reciben este bonus."
L.BONUS_VALUE        = "Valor:"

L.ECHO_WEIGHTS       = "Pesos de los Ecos"
L.ECHO_WEIGHTS_FOR   = "Pesos de los Ecos - %s"
L.COL_NAME           = "Nombre"
L.COL_WEIGHT         = "Peso"
L.ALL_FAMILIES       = "Todas las familias"
L.FAMILIES_N         = "Familias (%d)"
L.SHOW_ALL_CLASSES   = "Todas las clases"
L.PICK_ECHO          = "Elegir un Eco"

L.AUTOMATION_HEADER  = "Automatización"
L.BANISH_PROTECTION  = "Protección contra destierro:"
L.BANISH_PROTECTION_HINT = "Las familias marcadas nunca se destierran."
L.ALL_PROTECTED      = "|cffff0000Todas las familias están protegidas. Debe quedar al menos una sin proteger para que el destierro funcione.|r"
L.BAN_NOTE           = "Un Eco desterrado de una familia protegida pasa al final, pero no queda excluido. Si todo lo ofrecido está desterrado, se aplica la regla de reserva."
L.ECHO_BAN           = "Ecos desterrados:"
L.ECHO_BAN_HINT      = "Los Ecos de esta lista se destierran primero, sea cual sea su nota."
L.ADD_ECHO           = "Añadir"
L.NO_BANNED          = "Ningún Eco desterrado."
L.ALL_BANNED_LABEL   = "Si todo está desterrado y no quedan cargas:"
L.HIGHEST_SCORE      = "Mejor nota"
L.SCORE_SOURCE       = "Origen de la nota:"
L.COMMUNITY_MATRIX   = "Matriz común"
L.MANUAL_WEIGHTS     = "Pesos manuales"
L.THRESHOLDS         = "Umbrales de automatización:"
L.PEAK               = "Pico: %s = %d"
L.PEAK_EMPTY         = "Pico: (ningún Eco)"
L.PEAK_NOTE          = "La mejor nota posible para esta clase, con todos los bonus. Todos los "
                       .. "umbrales de automatización son porcentajes de este valor. Se fija al empezar la partida."
L.SCALE_MATRIX       = "Escala: nota común, de -5,00 a +3,00"
L.SCALE_MATRIX_NOTE  = "Un Eco que todos conservan llega a +3, uno que todos rechazan a -5, uno "
                       .. "corriente ronda +1. La escala es absoluta: los umbrales de abajo se leen "
                       .. "tal cual y no se mueven con tu build."
L.MATRIX_BLURB       = "Los Ecos se valoran según lo que otros jugadores han jugado y rechazado de "
                       .. "verdad, en una escala absoluta de -5 a +3, más tus propios pesos (ver "
                       .. "Influencia de los pesos). Los umbrales de abajo son notas."
L.WEIGHTS_BLURB      = "Los Ecos se valoran según los pesos de la pestaña Ecos, más los bonus de la "
                       .. "pestaña Bonus. Los umbrales de abajo son porcentajes del Pico. La matriz "
                       .. "común no se consulta."

L.T_BANISH_PCT       = "Desterrar bajo %"
L.T_BANISH_PCT_HINT  = "Cuando la nota de un Eco ofrecido baja de este umbral, el addon intenta desterrarlo. Las familias protegidas se omiten."
L.T_REROLL_PCT       = "Volver a tirar bajo %"
L.T_REROLL_PCT_HINT  = "El addon suma las notas de los Ecos ofrecidos, ajustadas a tres cartas. Si el total baja de este umbral, vuelve a tirar."
L.T_GUARD_PCT        = "Bloqueo de tirada %"
L.T_GUARD_PCT_HINT   = "Impide volver a tirar en cuanto un solo Eco ofrecido supera este umbral, sea cual sea la suma."
L.T_FREEZE_PCT       = "Congelar sobre %"
L.T_FREEZE_PCT_HINT  = "Se activa cuando al menos dos Ecos ofrecidos superan este umbral. El más flojo se congela y después se elige el mejor."
L.T_BANISH           = "Desterrar bajo"
L.T_BANISH_HINT      = "Destierra un Eco ofrecido cuya nota común baje de este umbral. Un destierro debe ser un consenso: con 0, caería cualquier Eco que nadie haya conservado."
L.T_REROLL           = "Volver a tirar bajo"
L.T_REROLL_HINT      = "Vuelve a tirar cuando el MEJOR Eco ofrecido está bajo este umbral. En una escala absoluta, sumar la mano no significa nada: solo importa si hay algo que valga la pena."
L.T_GUARD            = "Bloqueo de tirada sobre"
L.T_GUARD_HINT       = "Impide volver a tirar en cuanto un solo Eco ofrecido alcanza esta nota. No lo pongas por encima del umbral de tirada, o las dos reglas se contradicen."
L.T_FREEZE           = "Congelar sobre"
L.T_FREEZE_HINT      = "Se activa cuando al menos dos Ecos ofrecidos superan esta nota. El peor se congela y el mejor se elige al momento."
L.T_WEIGHT           = "Influencia de los pesos"
L.T_WEIGHT_HINT      = "Tus pesos se suman a cada nota: el mejor Eco de tu build suma este valor, uno con la mitad de peso suma la mitad. Los Ecos que la comunidad valora más cerca que esta distancia los deciden tus pesos."

L.DELETE_BUILD_CONFIRM = "¿Borrar el build \"%s\"?\n\nNo se puede deshacer."
L.AUTOMATION_ON      = "Automatización: SÍ"
L.AUTOMATION_OFF     = "Automatización: NO"
L.EDIT_BUILD         = "Editar"
L.STATS_TITLE        = "Estadísticas del build"
L.STATS_QUALITY      = "Reparto de rarezas:"
L.STAT_ECHOES_SEEN   = "Ecos vistos"
L.STAT_RUNS_COMPLETED = "Partidas terminadas"
L.STAT_RUNS_RESET    = "Partidas reiniciadas"
L.STAT_PICKS         = "Elecciones"
L.STAT_REROLLS       = "Tiradas usadas"
L.STAT_BANISHES      = "Destierros usados"
L.STAT_FREEZES       = "Congelaciones usadas"
L.REQUESTING_DATA    = "Pidiendo datos..."

L.ALL_CLASSES        = "Todas las clases"
L.PAGE               = "Página %d de %d"
L.WAIT_SECONDS       = "Espera %ds"
L.PLAYER_BUILDS_SUB  = "Los builds que otros jugadores guardaron en el servidor, recogidos automáticamente."
L.PLAYER_BUILDS_NONE = "Aún no hay ningún build con todos sus ecos bloqueados. Pulsa Recargar para pedirlos."
L.RECEIVED_ECHOES    = "%d ecos"
L.FAMILY_COUNT       = "%s (%d)"
L.DETAIL_LOCKED_UNKNOWN = "Este jugador no ha enviado sus ecos bloqueados."
L.ADD_TO_WISHLIST      = "Añadir a mi wishlist"
L.WISHLIST_OTHER_CLASS = "Una wishlist es siempre para tu propia clase."
L.WISHLIST_NAME_PROMPT = "Nombre de la nueva wishlist:"
L.WISHLIST_DEFAULT_NAME = "%s %d ecos"
L.WISHLIST_CREATED     = "Wishlist \"%s\" creada."

L.INTEREST_FOR       = "Interés para %s"
L.GOES_WITH          = "Combina bien con: %s"
L.SAVED_SUBTITLE     = "%d build(s) -- ranura %d activa, %d de %d desbloqueada(s)"
L.SAVED_NONE         = "Aún no se ha recibido ningún build del servidor.\nAbre la ventana de Ecos del juego."

L.DELETE_SESSION_CONFIRM = "¿Borrar esta sesión y todo su diario?"
L.CLEAR_SESSIONS_CONFIRM = "¿Borrar todo el historial de sesiones? No se puede deshacer."
L.CARD_ACTIVE        = "|cff44ff44[Activa]|r  Nivel %d"
L.CARD_LEVEL         = "Nivel %d"
L.CARD_ASHES         = "Cenizas de alma: %s"
L.LOG_NO_DETAIL      = GREY .. "No se guarda el detalle de las elecciones de esta sesión." .. R
L.LOG_DECISIONS      = "%d decisión(es): %s"
L.LOG_CHARGES_END    = "Cargas al final  D:%d T:%d C:%d"
L.SCORE              = "Nota: %s"
L.EXPORT_SESSION_TITLE = "Exportar sesión"
L.NO_SESSION_SELECTED = "Ninguna sesión seleccionada."
L.EXPORT_SESSION_HEADER = "Sesión: nivel %d | Duración: %s | Cenizas de alma: %s"
L.EXPORT_NO_DETAIL   = "Detalle no guardado. %d decisión(es)."
L.EXPORT_CHARGES_END = "  cargas al final  D:%d T:%d C:%d"
L.LOGBOOK_HINT       = GREY .. "Haz clic en una sesión para ver su diario" .. R
L.CLEAR_ALL          = "Borrar todo"
L.LOGBOOK_HEADER     = GREY .. "Hora      Acción      Eco 1           Eco 2           Eco 3           Eco 4           Cargas" .. R

L.TOAST_AUTOMATION   = "Automatización: %s"
L.TOAST_CHARGES      = GREY .. "Desterrar: %d    Tirar: %d    Congelar: %d" .. R

L.WIZARD_HEADER      = "Asistente de build"
L.WIZARD_STEP        = "Paso %d/%d"
L.CREATE_BUILD       = "Crear build"
L.NEW_BUILD_TITLE    = "Nuevo build"
L.WEIGHT_WANT        = "Lo quiero"
L.WEIGHT_GOOD        = "Bueno"
L.WEIGHT_OK          = "Aceptable"
L.WEIGHT_MEH         = "Regular"
L.WIZARD_S0_TITLE    = "¿Cómo quieres crear tu build?"
L.WIZARD_S0_DESC     = "Elige el modo que mejor te venga."
L.WIZARD_MODE        = "Modo asistente"
L.WIZARD_MODE_DESC   = "Descubre el addon paso a paso. El editor se abre al final."
L.PRO_MODE           = "Modo experto"
L.PRO_MODE_DESC      = "Ve directo al editor, con control total de todos los ajustes."
L.WIZARD_S1_TITLE    = "Elige tus %d Ecos bloqueados"
L.WIZARD_S2_TITLE    = "¡Poder adaptativo detectado!"
L.WIZARD_S2_DESC     = "El Poder adaptativo da un bonus a los Ecos que aún no has elegido."
L.WIZARD_S2_HINT     = "Recomendado: 30 puntos"
L.WIZARD_S3_TITLE    = "Elige tus familias"
L.WIZARD_DEFAULTS_HINT = "Los valores por defecto sirven para la mayoría de los builds. Cámbialos solo si de verdad hace falta."
L.WIZARD_FAMILY_NONE = GREY .. "Ninguna" .. R
L.WIZARD_FAMILY_SECONDARY = "Secundaria +10"
L.WIZARD_FAMILY_PRIMARY = "Principal +20"
L.WIZARD_S4_TITLE    = "Valora cada rareza"
L.WIZARD_S5_TITLE    = "¿Qué Ecos importan más?"
L.WIZARD_S5_DESC     = "Añade Ecos y di cuánto los quieres."
L.ADD_ECHO_BUTTON    = "+ Añadir Eco"
L.WIZARD_S5_EMPTY    = "Aún no hay Ecos. Haz clic en \"+ Añadir Eco\" para empezar."
L.WIZARD_S6_TITLE    = "Pon nombre y describe tu build"
L.WIZARD_S6_DESC     = "Puedes enlazar objetos, hechizos y Ecos en la descripción."
L.WIZARD_S6_HINT     = "Indica objetos, estrategias y afijos que vayan bien con este build. Mayús+clic en un objeto inserta su enlace."

L.EXPORT_BUILD_TITLE = "Exportar build"
L.IMPORT_HINT        = "Pega una cadena de build de EbonBuilds, o una cadena EBH1 exportada del Diario de "
                       .. "Ecos (pestaña Loadouts), y haz clic en Importar."
L.IMPORTED_BUILD     = "Build importado"
L.EBH1_IMPORTED      = "build \"%s\" importado (%s, %d eco(s))."
L.EBH1_KNOWN         = "el build \"%s\" ya estaba importado."

L.SYNC_REQUESTING    = "Pidiendo sincronización..."

L.BANLIST_PURGED     = "%d entrada(s) de la lista de destierros borrada(s)."

EbonAPI.Locale.register(ns.NAME, { esES = L })
