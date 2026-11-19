extends RefCounted
## Every visible string of the diegetic UI, in English and Spanish (docs/godot/UI-DIEGETIC.md section 10).
## `Strings.t("key")` or `Strings.t("learned", ["Pounce"])` (the `{0}` slot). Language: Game.settings["language"] ("en", "es"),
## by default the OS language when it is Spanish. Creature and move names are data and are not translated.

const TABLE := {
	# modes (ring)
	"befriend": ["Befriend", "Amistad"],
	"attack": ["Attack", "Atacar"],
	"observe": ["Observe", "Observar"],
	"intimidate": ["Intimidate", "Intimidar"],
	"eat": ["Eat", "Comer"],
	"remains": ["remains", "restos"],
	"cousin_gen": ["cousin · gen {0}", "primo · gen {0}"],
	# move names that are not creature data
	"guard": ["Guard", "Guardia"],
	"dodge": ["Dodge", "Esquiva"],
	"gift": ["Gift", "Regalo"],
	# menu
	"menu": ["Menu", "Menú"],
	"resume": ["Resume", "Seguir"],
	"journal": ["Journal", "Diario"],
	"family_tree": ["Family tree", "Árbol familiar"],
	"loadout": ["Loadout", "Movimientos"],
	"settings": ["Settings", "Ajustes"],
	"keys": ["Keys", "Teclas"],
	"save": ["Save", "Guardar"],
	"load": ["Load", "Cargar"],
	"main_menu": ["Main menu", "Menú principal"],
	"at_nest": ["at the nest", "en el nido"],
	"at_the_nest": ["At the nest", "En el nido"],
	"later": ["a later page", "más adelante"],
	"close_hint": ["Esc to close", "Esc para cerrar"],
	"show_hints": ["Show the hints again", "Ver las pistas otra vez"],
	# settings
	"language": ["Language", "Idioma"],
	"size_signs": ["Size of the signs", "Tamaño de los signos"],
	"names_signs": ["Names on signs", "Nombres en los signos"],
	"numbers": ["Numbers", "Números"],
	"outlines": ["Stronger outlines", "Contornos más fuertes"],
	"less_motion": ["Less motion", "Menos movimiento"],
	"minimap": ["Round map", "Mapa redondo"],
	"renderer": ["Renderer (restart)", "Render (al reiniciar)"],
	"r_auto": ["Auto", "Auto"],
	"r_high": ["High", "Alto"],
	"r_compat": ["Compatible", "Compatible"],
	"on_hover": ["On hover", "Al pasar"],
	"always": ["Always", "Siempre"],
	"off": ["Off", "No"],
	"on": ["On", "Sí"],
	"master": ["Sound", "Sonido"],
	"music": ["Music", "Música"],
	"sfx": ["Effects", "Efectos"],
	"ambience": ["Ambience", "Ambiente"],
	"mute": ["Mute all", "Silenciar"],
	"english": ["English", "English"],
	"spanish": ["Español", "Español"],
	# whispers and moments
	"learned": ["Learned: {0}", "Aprendido: {0}"],
	"back_at_nest": ["Back at the nest", "De vuelta en el nido"],
	"cannot_digest": ["Your body cannot digest meat", "Tu cuerpo no digiere carne"],
	"wont_listen": ["It will not listen until it is calm", "No te escuchará hasta que se calme"],
	"only_nest": ["Only at the nest", "Solo en el nido"],
	"saved": ["Game saved", "Partida guardada"],
	"loaded": ["Game loaded", "Partida cargada"],
	"bonded": ["{0}: a bond is made", "{0}: un vínculo"],
	"bond_broken": ["The bond is broken", "El vínculo se rompe"],
	"alliance": ["{0}: an alliance", "{0}: una alianza"],
	"dominated": ["{0}: dominated", "{0}: dominada"],
	"trace_of_life": ["A new trace of life", "Un nuevo rastro de vida"],
	"species_resolved": ["Species resolved", "Especies resueltas"],
	"bones_left": ["Nothing left but bones", "Solo quedan huesos"],
	"no_gift": ["You have nothing to give", "No tienes nada que dar"],
	"calms": ["It calms down", "Se calma"],
	"insult": ["That was an insult", "Eso fue un insulto"],
	"heckled": ["A rival heckles you off", "Un rival te abuchea"],
	"seen": ["Seen! Keep still", "¡Te ha visto! Quieto"],
	"full": ["Full", "Lleno"],
	# hints
	"hint_walk": ["Click the ground to walk", "Haz clic en el suelo para caminar"],
	"hint_look": ["Drag to look around, wheel to zoom", "Arrastra para mirar, rueda para acercar"],
	"hint_select": ["Click a creature to choose it", "Haz clic en una criatura para elegirla"],
	"hint_ring": ["Click a side of the ring to choose how to meet it", "Haz clic en un lado del anillo para elegir cómo acercarte"],
	"hint_keys": ["Keys 1 to 4 use the moves", "Las teclas 1 a 4 usan los movimientos"],
	"hint_fight": ["Space guards, Q and E dodge", "Espacio guarda, Q y E esquivan"],
	"hint_eat": ["Choose Eat on the remains", "Elige Comer en los restos"],
	"hint_nest": ["L changes your moves at the nest", "L cambia tus movimientos en el nido"],
	"hint_f1": ["F1 shows every key", "F1 muestra todas las teclas"],
	"keys_title": ["Keys", "Teclas"],
	# journal / tree stubs
	"fossil": ["Fossil", "Fósil"],
	"bones": ["Bones", "Huesos"],
	"nest_edit": ["Edit creature", "Editar criatura"],
	"part_found": ["Discovered: {0}", "Descubierto: {0}"],
	"journal_title": ["Journal", "Diario"],
	"tree_title": ["Family tree", "Árbol familiar"],
	"journal_total": ["DNA earned", "ADN ganado"],
	"journal_stub": ["The pages are not written yet", "Las páginas aún no están escritas"],
	# loadout
	"loadout_title": ["At the nest", "En el nido"],
	"loadout_far": ["Only at the nest, never in a fight", "Solo en el nido, nunca en una pelea"],
	"empty_slot": ["empty", "vacío"],
	"role_basic": ["Basic", "Básico"],
	"role_engage": ["Engage", "Acometida"],
	"role_poke": ["Poke", "Hostigar"],
	"role_control": ["Control", "Control"],
	"role_defence": ["Defence", "Defensa"],
	"role_signature": ["Signature", "Insignia"],
	"move_bite": ["quick, makes it bleed", "rápido, la hace sangrar"],
	"move_charge": ["leaps in, stuns", "se lanza, aturde"],
	"move_spit": ["from range, slows", "a distancia, ralentiza"],
	"move_tail_strike": ["sweeps, slows", "barre, ralentiza"],
	"move_unknown": ["not learned yet", "aún sin aprender"],
	"slot_hint": ["1-4 put it in a slot", "1-4 lo pone en un hueco"],
	# diet / relationship (journal)
	"diet_herb": ["Herbivore", "Herbívoro"],
	"diet_carn": ["Carnivore", "Carnívoro"],
	"diet_omni": ["Omnivore", "Omnívoro"],
	"rel_stranger": ["Stranger", "Desconocido"],
	"rel_neutral": ["Neutral", "Neutral"],
	"rel_trusted": ["Trusted", "De confianza"],
	"rel_ally": ["Ally", "Aliado"],
	"hungry": ["Hungry", "Hambre"],
}

static func language() -> String:
	var tree = Engine.get_main_loop()
	var lang := ""
	if tree is SceneTree and (tree as SceneTree).root.has_node("Game"):
		lang = str((tree as SceneTree).root.get_node("Game").settings.get("language", ""))
	if lang == "":
		lang = "es" if OS.get_locale_language() == "es" else "en"
	return lang if lang in ["en", "es"] else "en"

static func t(key: String, args: Array = []) -> String:
	var row: Array = TABLE.get(key, [])
	if row.is_empty():
		push_warning("missing string '%s'" % key)
		return key
	var s: String = row[1] if language() == "es" else row[0]
	for i in args.size():
		s = s.replace("{%d}" % i, str(args[i]))
	return s

static func has(key: String) -> bool:
	return TABLE.has(key)
