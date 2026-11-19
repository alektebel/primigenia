extends RefCounted
## Strings of the cell stage, [en, es]. Same patterns as ui/strings.gd (language from Game.settings, OS locale fallback).
## The sim returns ids (hint ids, goal ids, status words); this table turns them into text.

const Strings := preload("res://ui/strings.gd")

const TABLE := {
	"title": ["Primigenia · cell stage", "Primigenia · fase célula"],
	"phase": ["Phase {0} · {1}", "Fase {0} · {1}"],
	"create": ["Create · tap a piece, then the cell", "Crear · toca una pieza y luego la célula"],
	"remove": ["Remove", "Quitar"],
	"demo": ["Build example", "Montar ejemplo"],
	"reset": ["Restart", "Reiniciar"],
	"speed1": ["Speed ×1", "Velocidad ×1"],
	"speed3": ["×3", "×3"],
	"labels": ["Labels", "Etiquetas"],
	"atp_cost": ["{0} ATP", "{0} ATP"],
	"s_free": ["Free ATP", "ATP libre"],
	"s_rate": ["ATP / min", "ATP / min"],
	"s_glu": ["Glucose / min", "Glucosa / min"],
	"s_mem": ["Membrane", "Membrana"],
	"s_tier": ["Size", "Talla"],
	"lines": ["Lines · average use and state", "Líneas · uso medio y estado"],
	"membrane": ["Membrane", "Membrana"],
	"mem_row": ["{0} transp. · {1} export. · {2} flippases", "{0} transp. · {1} export. · {2} flipasas"],
	"no_bottleneck": ["No serious bottlenecks.", "Sin cuellos de botella graves."],
	"note": ["Simplified: three glycolysis enzymes instead of ten, with the real balance (you invest 2 ATP, you get back 4). Product inhibition of hexokinase and the brake on lipid synthesis when energy is short are real; paying the membrane upkeep in ATP is a simplification. Prototype numbers.",
		"Simplificado: tres enzimas de glucólisis en lugar de diez, con el balance real (inviertes 2 ATP, recuperas 4). La inhibición de la hexoquinasa por su producto y el freno a la síntesis de lípidos cuando falta energía son reales; el mantenimiento de membrana en ATP es una simplificación. Cifras de prototipo."],
	"tap_membrane": ["Tap the membrane", "Toca la membrana"],
	"tap_inside": ["Tap inside the cell", "Toca dentro de la célula"],
	"paused": ["Paused", "En pausa"],
	"pause_title": ["Paused", "Pausa"],
	"resume": ["Resume", "Seguir"],
	"restart": ["Restart", "Reiniciar"],
	"main_menu": ["Main menu", "Menú principal"],
	"grew": ["The cell grows · size {0}", "La célula crece · talla {0}"],
	"key_help": ["1-4 phase · Space pause · F speed · L labels · Esc menu", "1-4 fase · Espacio pausa · F velocidad · L etiquetas · Esc menú"],
	# statuses (the sim's words)
	"st_trabaja": ["working", "trabaja"],
	"st_recibe": ["receiving", "recibe"],
	"st_sin entrada": ["no input", "sin entrada"],
	"st_atasco": ["jammed", "atasco"],
	"st_inhibida": ["inhibited", "inhibida"],
	"st_falta ATP": ["no ATP", "falta ATP"],
	"st_montando": ["building", "montando"],
	"fx_sin ATP": ["no ATP", "sin ATP"],
	"fx_fuga": ["leak", "fuga"],
	# hints
	"h_tr": ["There is glucose outside, but the membrane will not let it through. Create a transporter on the membrane: it costs 2 ATP.",
		"Fuera hay glucosa, pero la membrana no la deja pasar. Crea un transportador en la membrana: cuesta 2 ATP."],
	"h_hk": ["Glucose comes in... and slips out again. Create a hexokinase: it spends 2 ATP tagging it so it cannot leave.",
		"La glucosa entra… y se vuelve a escapar. Crea una hexoquinasa: gasta 2 ATP en marcarla y ya no puede salir."],
	"h_ald": ["The tagged glucose piles up and your ATP drops: for now you only invest. Create an aldolase to split it in two halves.",
		"La glucosa marcada se acumula y tu ATP baja: de momento solo inviertes. Crea una aldolasa para partirla en dos mitades."],
	"h_pk": ["You have loose halves now. Create a pyruvate kinase: it pulls 2 ATP out of each half.",
		"Ya tienes mitades sueltas. Crea una piruvato quinasa: saca 2 ATP de cada mitad."],
	"h_p1": ["The cycle holds: you invest 2 ATP, you get back 4. The dot on each enzyme says whether it works, waits or is jammed.",
		"El ciclo se sostiene: inviertes 2 ATP, recuperas 4. El punto de cada enzima dice si trabaja, espera o está atascada."],
	"h_ldh": ["Now pyruvate stays inside. When it piles up, pyruvate kinase jams. Create a lactate dehydrogenase.",
		"Ahora el piruvato se queda dentro. Cuando se acumula, la piruvato quinasa se atasca. Crea una lactato deshidrogenasa."],
	"h_ex": ["Lactate piles up too. Put an exporter on the membrane to push it out.",
		"El lactato también se acumula. Coloca un exportador en la membrana para sacarlo."],
	"h_p2": ["The chain flows, but each piece has its own pace. Look at each enzyme's use: the one at 100 % is your bottleneck.",
		"La cadena fluye, pero cada pieza tiene su ritmo. Mira el uso de cada enzima: la que está al 100 % es tu cuello de botella."],
	"h_syn": ["Free radicals oxidise your lipids and the damage spreads. Create a lipid synthase: it uses one half and 1 ATP per lipid.",
		"Los radicales libres oxidan tus lípidos y la oxidación se contagia. Crea una sintasa de lípidos: usa una mitad y 1 ATP por lípido."],
	"h_fl": ["New lipids do not know where to go. Put flippases on the membrane: each one repairs its green arc.",
		"Los lípidos nuevos no saben dónde ir. Coloca flipasas en la membrana: cada una repara su arco verde."],
	"h_p3": ["Every half that goes to lipids is ATP you do not earn. Another flippase, another synthase, or more kinases?",
		"Cada mitad que va a lípidos es ATP que no ganas. ¿Otra flipasa, otra sintasa o más quinasas?"],
	"h_t0": ["The lipids left over after repairs make the cell grow. Bigger means more room, but also more membrane, more radicals, shorter flippase arcs and more ATP upkeep.",
		"Los lípidos que sobran tras reparar hacen crecer la célula. Más grande es más sitio, pero también más membrana, más radicales, arcos de flipasa más cortos y más ATP de mantenimiento."],
	"h_tn": ["Size {0}. There is room to duplicate lines. Careful: membrane upkeep grows with size.",
		"Talla {0}. Hay sitio para duplicar líneas. Ojo: el mantenimiento de membrana sube con el tamaño."],
	"h_final": ["Final size. To join other cells you need a factory that makes at least {0} ATP per minute, sustained.",
		"Tamaño final. Para agregarte a otras células necesitas una fábrica que produzca al menos {0} ATP por minuto de forma sostenida."],
	# diagnoses
	"d_blackout": ["ATP blackout: the consumers run ahead of production.", "Apagón de ATP: los consumidores van por delante de la producción."],
	"d_membrane": ["The membrane breaks faster than you repair it: more flippases or more synthase.", "La membrana se rompe más rápido de lo que la reparas: más flipasas o más sintasa."],
	"d_hk": ["Tagged glucose piles up and slows hexokinase: you need more aldolase.", "La glucosa marcada se acumula y frena a la hexoquinasa: falta aldolasa."],
	"d_ald": ["Halves pile up: you need more pyruvate kinase.", "Se acumulan mitades: falta piruvato quinasa."],
	"d_pk": ["Pyruvate piles up: you need more lactate DH.", "Se acumula piruvato: falta lactato DH."],
	"d_ldh": ["Lactate piles up: you need more exporters.", "Se acumula lactato: faltan exportadores."],
	"d_syn": ["Lipids with nowhere to go: you need more flippases.", "Sobran lípidos sin destino: faltan flipasas."],
	"d_syn_low": ["Low energy: the cell brakes lipid synthesis until it has spare ATP.", "Poca energía: la célula frena la síntesis de lípidos hasta tener ATP de sobra."],
	"d_glu": ["Little glucose gets in: you need more transporters.", "Entra poca glucosa: faltan transportadores."],
	# goals
	"g_energy": ["Goal: make 40 ATP", "Objetivo: produce 40 ATP"],
	"g_waste": ["Goal: export 12 lactates", "Objetivo: exporta 12 lactatos"],
	"g_membrane": ["Goal: membrane at 95 % or more for 60 s, with flippases", "Objetivo: membrana al 95 % o más durante 60 s, con flipasas"],
	"g_grow": ["Size {0}/{1} · lipids to grow", "Talla {0}/{1} · lípidos para crecer"],
	"g_agg": ["Aggregation: sustain {0} ATP/min for {1} s (now {2})", "Agregación: sostén {0} ATP/min durante {1} s (ahora {2})"],
	"g_agg_done": ["Aggregation complete", "Agregación completada"],
	"g_done": ["Goal complete. On to phase {0}.", "Objetivo cumplido. Pasa a la fase {0}."],
	"g_done_last": ["Goal complete.", "Objetivo cumplido."],
	# aggregation sheet
	"agg_title": ["Aggregation: the colony begins", "Agregación: empieza la colonia"],
	"agg_body": ["This sheet is what you carry to the colony stage: your cell becomes a piece with these numbers.", "Esta ficha es lo que llevas a la etapa colonia: tu célula pasa a ser una pieza con estos números."],
	"agg_foot": ["Proteins and genome are not in the prototype yet.", "Proteínas y genoma aún no están en el prototipo."],
	"agg_go": ["Keep this cell", "Seguir con esta célula"],
	"agg_new": ["Start over", "Empezar de nuevo"],
	"s_atp": ["ATP production", "Producción de ATP"],
	"s_glu_proc": ["Glucose processed", "Glucosa procesada"],
	"s_atp_glu": ["ATP per glucose (gross)", "ATP por glucosa (bruto)"],
	"s_lip": ["Lipids made", "Lípidos fabricados"],
	"s_up": ["Membrane upkeep", "Mantenimiento de membrana"],
	"s_mem_int": ["Membrane integrity", "Integridad de membrana"],
	"s_size": ["Size", "Tamaño"],
	"s_pieces": ["Pieces", "Piezas"],
	"u_min": ["/min", " /min"],
	"u_atpmin": ["ATP/min", "ATP/min"],
	"u_pct": ["%", " %"],
	"u_radius": ["radius ×{0}", "radio ×{0}"],
}

static func es() -> bool:
	return Strings.language() == "es"

static func t(key: String, args: Array = []) -> String:
	var row: Array = TABLE.get(key, [])
	if row.is_empty():
		push_warning("missing cell string '%s'" % key)
		return key
	var s: String = row[1] if es() else row[0]
	for i in args.size():
		s = s.replace("{%d}" % i, str(args[i]))
	return s

static func status(st: String) -> String:
	return t("st_" + st) if TABLE.has("st_" + st) else st

static func fx_text(s: String) -> String:
	return t("fx_" + s) if TABLE.has("fx_" + s) else s

static func piece_name(sim_pieces: Dictionary, kind: String) -> String:
	return sim_pieces[kind].n[0 if es() else 1]  # the sim stores [es, en]

static func role(sim_pieces: Dictionary, kind: String) -> String:
	return sim_pieces[kind].role[0 if es() else 1]

## Number text with the language's decimal separator.
static func num(s: String) -> String:
	return s.replace(".", ",") if es() else s

static func phase_name(n: int, names: Array) -> String:
	return names[n][0 if es() else 1]
