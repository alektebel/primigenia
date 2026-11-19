extends RefCounted
## Strings of the cell stage, [en, es]. Same patterns as ui/strings.gd (language from Game.settings, OS locale fallback).
## The sim returns ids (hint ids, goal ids, status words); this table turns them into text.

const Strings := preload("res://ui/strings.gd")
const CSim := preload("res://cell/colony_sim.gd")

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
	"key_help": ["1-6 phase · Space pause · F speed · L labels · Esc menu", "1-6 fase · Espacio pausa · F velocidad · L etiquetas · Esc menú"],
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
	# phase 5: threats
	"st_listo": ["ready", "listo"],
	"st_bloqueada": ["blocked", "bloqueada"],
	"st_secuestrada": ["hijacked", "secuestrada"],
	"st_oxidada": ["oxidised", "oxidada"],
	"fx_cortado": ["cut", "cortado"],
	"fx_secuestrado": ["hijacked", "secuestrado"],
	"fx_inyecta": ["injects DNA", "inyecta ADN"],
	"fx_lisis": ["lysis", "lisis"],
	"fx_engullida": ["swallowed", "engullida"],
	"fx_pinchos": ["spines!", "¡pinchos!"],
	"fx_grande": ["too big", "demasiado grande"],
	"fx_oxidada": ["oxidised", "oxidada"],
	"fx_need_rib": ["Needs a ribosome first", "Antes hace falta un ribosoma"],
	"genome": ["Genome", "Genoma"],
	"kind_phage": ["Phage", "Fago"],
	"kind_abx": ["Antibiotic", "Antibiótico"],
	"kind_ox": ["Oxidation", "Oxidación"],
	"kind_amoeba": ["Amoeba", "Ameba"],
	"w_phage": ["A phage is drifting in to your transporter · {0} s", "Un fago se acerca a tu transportador · {0} s"],
	"w_abx": ["An antibiotic tide is coming · {0} s", "Llega una marea de antibiótico · {0} s"],
	"w_ox": ["Oxidation wave from the glowing side · {0} s", "Oleada de oxidación por el lado brillante · {0} s"],
	"w_amoeba": ["An amoeba approaches · {0} s", "Se acerca una ameba · {0} s"],
	"hit_phage": ["The phage injects its DNA", "El fago inyecta su ADN"],
	"hit_abx": ["The antibiotic is inside", "El antibiótico ya está dentro"],
	"hit_ox": ["Free radicals hit the membrane", "Los radicales golpean la membrana"],
	"hit_amoeba": ["The amoeba bites the membrane", "La ameba muerde la membrana"],
	"settle_t": ["Counting damage · lowest membrane {0} %", "Contando daños · membrana mínima {0} %"],
	"next_t": ["Next threat: {0} in {1} s", "Próxima amenaza: {0} en {1} s"],
	"threats_card": ["Threats · survive each with the membrane at 60 % or more", "Amenazas · sobrevive a cada una con la membrana al 60 % o más"],
	"th_ok": ["survived", "superada"],
	"th_fail": ["failed, it will come back", "fallida, volverá"],
	"th_pend": ["pending", "pendiente"],
	"th_now": ["now", "ahora"],
	"counter_cas": ["counter: Cas (CRISPR)", "defensa: Cas (CRISPR)"],
	"counter_pump": ["counter: efflux pump", "defensa: bomba de expulsión"],
	"counter_cat": ["counter: catalase", "defensa: catalasa"],
	"counter_spn": ["counter: spines or size 3", "defensa: espinas o talla 3"],
	"has_it": ["ready", "preparada"],
	"lacks_it": ["missing", "falta"],
	"locked_5": ["Opens after the aggregation", "Se abre tras la agregación"],
	"locked_6": ["Opens when you survive the four threats", "Se abre al superar las cuatro amenazas"],
	"h_rib": ["Defence proteins are built by ribosomes. Create a ribosome first: each counter piece (Cas, pump, catalase, spines) needs a free one to start.",
		"Las proteínas de defensa las fabrican los ribosomas. Crea primero un ribosoma: cada pieza de defensa (Cas, bomba, catalasa, espinas) necesita uno libre para empezar."],
	"h_n_phage": ["Next: a phage. It injects DNA and hijacks a ribosome until the cell bursts. Create a Cas: it cuts the DNA and learns it.",
		"Próxima: un fago. Inyecta su ADN y secuestra un ribosoma hasta reventar la célula. Crea una Cas: corta el ADN y lo aprende."],
	"h_n_abx": ["Next: an antibiotic. It blocks your ribosomes and pricks the membrane. Put an efflux pump on the membrane: 1 ATP per molecule.",
		"Próxima: un antibiótico. Bloquea tus ribosomas y agujerea la membrana. Pon una bomba de expulsión en la membrana: 1 ATP por molécula."],
	"h_n_ox": ["Next: an oxidation wave. Make three catalases and keep your flippases repairing.",
		"Próxima: una oleada de oxidación. Fabrica tres catalasas y mantén las flipasas reparando."],
	"h_n_amoeba": ["Next: an amoeba. It cannot swallow you with 3 spines on the membrane, or at size 3 or more.",
		"Próxima: una ameba. No puede engullirte con 3 espinas en la membrana, ni con talla 3 o más."],
	"h_ready": ["Your defence for the next threat is ready. Watch the warning and keep ATP flowing.", "Tu defensa para la próxima amenaza está lista. Vigila el aviso y mantén el ATP fluyendo."],
	"h_w_phage": ["The phage lands on a transporter, injects DNA and a ribosome will be hijacked. Cas cuts it; the second time it cuts it before it arrives.",
		"El fago aterriza en un transportador, inyecta ADN y secuestrará un ribosoma. Cas lo corta; la segunda vez lo corta antes de que llegue."],
	"h_w_abx": ["The antibiotic blocks your {0}. The pump throws it out, one ATP per molecule. Without a pump the membrane gets holes.",
		"El antibiótico bloquea tus {0}. La bomba lo expulsa, un ATP por molécula. Sin bomba la membrana se llena de agujeros."],
	"h_w_ox": ["Radicals arrive from the glowing side. Each catalase neutralises 5 per second; what gets through breaks the membrane and tires enzymes.",
		"Los radicales llegan por el lado brillante. Cada catalasa neutraliza 5 por segundo; lo que pasa rompe la membrana y cansa a las enzimas."],
	"h_w_amoeba": ["The amoeba bites where it touches and swallows you if it holds on for 9 s. Spines or a bigger size make it let go.",
		"La ameba muerde donde toca y te engulle si aguanta 9 s. Las espinas o un tamaño mayor la hacen soltar."],
	"h_settle": ["Counting the damage. The threat is survived if the membrane never dropped under 60 %.", "Contando los daños. La amenaza se supera si la membrana no bajó del 60 %."],
	"h_threats_done": ["You survived the four threats. The colony stage is open: press 6.", "Has superado las cuatro amenazas. La colonia está abierta: pulsa 6."],
	"g_threats": ["Survive the four threats with the membrane at {0} % or more", "Sobrevive a las cuatro amenazas con la membrana al {0} % o más"],
	"d_threat": ["The last threat broke the membrane under 60 %: prepare its counter and it will come back.", "La última amenaza rompió la membrana por debajo del 60 %: prepara su defensa y volverá."],
	# phase 6: the colony
	"light": ["light", "luz"],
	"founder": ["Founder", "Fundadora"],
	"founder_role": ["Your cell from phase 5. Every block copies its sheet.", "Tu célula de la fase 5. Cada bloque copia su ficha."],
	"inherits": ["Inherits: {0} ATP/min, membrane {1} %", "Hereda: {0} ATP/min, membrana {1} %"],
	"cell_state": ["ATP {0} / 10 · membrane {1} %", "ATP {0} / 10 · membrana {1} %"],
	"tap_slot": ["Tap a free hex next to the colony", "Toca un hueco libre junto a la colonia"],
	"fx_no_atp": ["No ATP next door", "Sin ATP al lado"],
	"fx_no_locked": ["Coming soon", "Próximamente"],
	"fx_no_far": ["It must touch the colony", "Tiene que tocar la colonia"],
	"fx_no_taken": ["Occupied", "Ocupado"],
	"cw_warn": ["An amoeba comes from the marked side · {0} s", "Una ameba llega por el lado marcado · {0} s"],
	"cw_hit": ["The amoeba bites the front line", "La ameba muerde la primera línea"],
	"cw_arrived": ["You reached the light. Build up to {1} cells ({0} now)", "Has llegado a la luz. Monta hasta {1} células ({0} ahora)"],
	"cw_soon": ["You reached the light. Something is coming…", "Has llegado a la luz. Algo se acerca…"],
	"colony_card": ["Colony · place specialised cells around the founder", "Colonia · coloca células especializadas alrededor de la fundadora"],
	"cs_atp": ["Colony ATP", "ATP de la colonia"],
	"cs_cells": ["Cells", "Células"],
	"cs_speed": ["Speed", "Velocidad"],
	"cs_light": ["To the light", "Hacia la luz"],
	"cs_wave": ["Threat", "Amenaza"],
	"cw_wait": ["waiting", "espera"],
	"cw_warn_s": ["incoming", "viene"],
	"cw_hit_s": ["biting", "muerde"],
	"cw_ok": ["survived", "superada"],
	"g_colony": ["Colony of {0}, reach the light, survive the amoeba", "Colonia de {0}, llega a la luz y sobrevive a la ameba"],
	"ch_energy": ["The founder makes ATP alone, slowly. Put an energy cell next to it: it costs 5 ATP, taken from its neighbour, and then it makes more than the founder. Neighbours share their ATP.",
		"La fundadora fabrica ATP sola, despacio. Pon una célula de energía a su lado: cuesta 5 ATP, que salen de su vecina, y luego produce más que la fundadora. Las vecinas se reparten el ATP."],
	"ch_motile": ["Now a motile cell: its flagellum burns ATP to swim toward the light. Speed is thrust over the size of the colony.",
		"Ahora una célula móvil: su flagelo gasta ATP para nadar hacia la luz. La velocidad es el empuje entre el tamaño de la colonia."],
	"ch_grow": ["{0}/{1} cells. Each block costs ATP from a neighbour: if it says there is no ATP, wait for the energy cells to fill the colony.",
		"{0}/{1} células. Cada bloque cuesta ATP de una vecina: si dice que no hay ATP, espera a que las células de energía llenen la colonia."],
	"ch_swim": ["The colony swims toward the light ({0} %). More motile cells swim faster but burn more ATP.", "La colonia nada hacia la luz ({0} %). Más células móviles nadan más rápido pero gastan más ATP."],
	"ch_defense": ["You are at the light. An amoeba will come from one side and bite the front line: a defensive cell takes the bite and pricks it. Wait for the warning to see the side.",
		"Estás en la luz. Una ameba vendrá por un lado y morderá la primera línea: una célula defensiva aguanta el mordisco y la pincha. Espera al aviso para ver el lado."],
	"ch_wait": ["You are at the light with a defence. The amoeba comes soon: watch the marked side.", "Estás en la luz con defensa. La ameba llega pronto: vigila el lado marcado."],
	"ch_warn": ["The dotted cells are the front line. Put defensive cells there (right click removes a block, then place one) before the bites in {0} s.",
		"Las células con círculo punteado son la primera línea. Pon ahí células defensivas (clic derecho quita un bloque, luego coloca una) antes de los mordiscos en {0} s."],
	"ch_hit": ["Bites on the front line. A defensive cell absorbs it; two absorbed bites and the amoeba leaves.", "Mordiscos en la primera línea. Una célula defensiva lo absorbe; con dos mordiscos absorbidos la ameba se va."],
	"ch_fail": ["The colony lost cells. Rebuild up to {0}, put defence on the side of the warning and it will come back.", "La colonia perdió células. Reconstruye hasta {0}, pon defensa en el lado del aviso y volverá."],
	"ch_done": ["The colony survived.", "La colonia sobrevivió."],
	# carry-over card
	"leg_title": ["The colony becomes a creature", "La colonia se convierte en criatura"],
	"leg_body": ["This is what your cell hands to the creature. It is saved; the creature stage will read it.", "Esto es lo que tu célula le pasa a la criatura. Queda guardado; la etapa de criatura lo leerá."],
	"leg_diet": ["Starting diet", "Dieta inicial"],
	"leg_def": ["Starting part", "Parte inicial"],
	"leg_size": ["Starter size", "Tamaño inicial"],
	"leg_from": ["Metabolism: {0} % of your pieces handle waste", "Metabolismo: el {0} % de tus piezas gestiona residuos"],
	"leg_from_def": ["Defence: {0} spines or defensive cells, {1} plates (flippases and membrane)", "Defensa: {0} espinas o células defensivas, {1} placas (flipasas y membrana)"],
	"leg_diet_carronero": ["Scavenger", "Carroñero"],
	"leg_diet_cazador": ["Hunter", "Cazador"],
	"leg_diet_herbivoro": ["Herbivore", "Herbívoro"],
	"leg_def_espinas": ["Spines", "Espinas"],
	"leg_def_placas": ["Plates", "Placas"],
	"leg_def_ninguna": ["None", "Ninguna"],
	"leg_size_small": ["Small", "Pequeño"],
	"leg_size_medium": ["Medium", "Mediano"],
	"leg_size_large": ["Large", "Grande"],
	"leg_menu": ["Back to the menu", "Volver al menú"],
	"leg_stay": ["Keep looking", "Seguir mirando"],
	# aggregation sheet
	"agg_title": ["Aggregation: the colony begins", "Agregación: empieza la colonia"],
	"agg_body": ["This sheet is what you carry to the colony stage: your cell becomes a piece with these numbers.", "Esta ficha es lo que llevas a la etapa colonia: tu célula pasa a ser una pieza con estos números."],
	"agg_foot": ["Next: the threats (phase 5). Phages, antibiotics, oxidation and amoebae will test what you built.", "Siguiente: las amenazas (fase 5). Fagos, antibióticos, oxidación y amebas pondrán a prueba lo que has montado."],
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

static func block_name(kind: String) -> String:
	return CSim.BLOCKS[kind].n[0 if es() else 1]

static func block_role(kind: String) -> String:
	return CSim.BLOCKS[kind].role[0 if es() else 1]
