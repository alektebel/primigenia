extends RefCounted
## es/en strings. Spanish is the source text, as in web/studio/i18n.js.

var lang := "es"
var parts: RefCounted

const EN := {
	"Jugar con esta criatura": "Play with this creature", "Jugar": "Play", "No se pudo guardar": "Could not save", "Modo": "Mode", "Construir": "Build", "Pintar": "Paint", "Probar": "Test", "Deshacer": "Undo", "Rehacer": "Redo",
	"Pieza": "Part", "Más": "More", "Piel": "Skin", "Dibujo": "Pattern", "Colores": "Colours", "Escama": "Scales", "Brillo": "Gloss", "Biología": "Biology", "Contrasombreado": "Countershading", "Tamaño del dibujo": "Pattern size", "Contraste del dibujo": "Pattern contrast", "Rosetas": "Rosettes", "Actuación": "Actuation", "Automática": "Automatic", "músculo": "muscle", "hidráulica": "hydraulic",
	"Sin patas: esqueleto hidrostático, avanza por ondas de músculo": "no legs: hydrostatic skeleton, moves by waves of muscle", "Placas duras: músculo dentro de un exoesqueleto": "hard plates: muscle inside an exoskeleton", "Muchas patas finas: patas hidráulicas a presión": "many thin legs: pressurised hydraulic legs", "Patas gruesas: músculo sobre esqueleto interno": "thick legs: muscle on an internal skeleton",
	"Esqueleto": "Skeleton", "esqueleto interno": "endoskeleton", "exoesqueleto": "exoskeleton", "esqueleto hidrostático": "hydrostatic skeleton", "tendón elástico": "elastic tendon", "resorte": "spring-latch", "hidrostato": "muscular hydrostat", "peristáltica": "peristaltic", "pies ambulacrales": "tube feet", "cilios": "cilia",
	"tipo de actuación": "type of actuation", "tipos de actuación": "types of actuation", "metabolismo": "metabolism",
	"Patas con hueso: esqueleto interno": "bony legs: endoskeleton", "Placas duras: exoesqueleto": "hard plates: exoskeleton", "Ocho o más patas finas: exoesqueleto de artrópodo": "eight or more thin legs: arthropod exoskeleton", "Sin patas: esqueleto hidrostático": "no legs: hydrostatic skeleton", "Una placa suelta: esqueleto interno": "a lone plate: endoskeleton",
	"Cuerpo hidrostático: pies ambulacrales": "hydrostatic body: tube feet", "Pie de resorte: mecanismo de cierre elástico": "spring foot: elastic latch", "Ocho o más patas finas: presión hidráulica": "eight or more thin legs: hydraulic pressure", "Patas largas y finas: tendones elásticos": "long thin legs: elastic tendons", "Patas con segmentos duros: músculo dentro del exoesqueleto": "segmented legs: muscle inside the exoskeleton", "Patas gruesas: músculo sobre hueso": "thick legs: muscle on bone",
	"Maza: golpe de resorte (como la galera)": "club: spring strike (like the mantis shrimp)", "Brazo sin hueso: hidrostato muscular": "boneless arm: muscular hydrostat", "Brazo con articulaciones: músculo": "jointed arm: muscle", "Cola: ondas del cuerpo": "tail: body waves", "Cola: músculo del tronco": "tail: trunk muscle", "Lengua balística: hidrostato o resorte": "ballistic tongue: hydrostat or spring", "Trompa blanda: hidrostato muscular": "soft trunk: muscular hydrostat", "Probóscide: presión hidráulica": "proboscis: hydraulic pressure", "Garra excavadora: músculo": "digging claw: muscle",
	"Pareja (ambos lados)": "Pair (both sides)", "Solo derecha": "Right only", "Solo izquierda": "Left only", "Pupila: según su vida": "Pupil: by way of life", "Pupila redonda": "Round pupil", "Pupila en rendija": "Slit pupil", "Pupila horizontal": "Horizontal pupil",
	"Combinaciones": "Palettes", "Acciones": "Actions", "Giro": "Rotation", "Inclinación": "Tilt", "Tamaño": "Size",
	"Largo": "Length", "Curva": "Curve", "Grosor": "Thickness", "Quitar pieza": "Remove part", "Ponle nombre": "Name your creature",
	"liso": "plain", "rayas": "stripes", "manchas": "spots", "veteado": "marbled",
	"Color base": "Base colour", "Color del dibujo": "Pattern colour", "Color del vientre": "Belly colour",
	"Bocas": "Mouths", "Sentidos": "Senses", "Patas": "Legs", "Brazos": "Arms", "Armas": "Weapons", "Alas": "Wings",
	"Aletas": "Fins", "Excavar": "Digging claws", "Detalles": "Details",
	"Guardar y compartir": "Save and share", "Guardar": "Save", "Cargar": "Load", "Importar JSON": "Import JSON", "Exportar JSON": "Export JSON",
	"Nueva": "New", "Diseño cargado": "Design loaded", "Genoma no válido": "Invalid genome", "Guardado": "Saved",
	"Añadir vértebra": "Add vertebra", "Quitar vértebra": "Remove vertebra", "Columna": "Spine", "Criatura": "Creature",
	"Menú": "Menu", "Guarda con Ctrl+S; Jugar usa la última criatura guardada": "Save with Ctrl+S; Play uses the last saved creature",
	"Capacidades": "Abilities", "Velocidad": "Speed", "Mordisco": "Bite", "Canto": "Song", "Salud": "Health",
	"Sin boca no puede comer ni cantar": "Without a mouth it cannot eat or sing", "Sin ojos va a ciegas": "Without eyes it goes blind",
	"Sin patas se arrastra": "Without legs it drags itself", "Al azar": "Random", "Copiar genoma": "Copy genome", "Genoma copiado": "Genome copied",
	"Regiones": "Regions", "Añadir región": "Add region", "Duplicar": "Duplicate", "Eliminar": "Delete", "Forma": "Shape", "Superficie": "Surface",
	"Cuernos": "Horns", "Placas": "Plates", "Filamentos": "Tendrils", "Torso": "Torso", "Cuello": "Neck", "Cola": "Tail",
	"Posición": "Position", "Cobertura": "Coverage", "Ángulo": "Angle", "Cantidad": "Count", "Curvatura": "Curvature", "Ramas": "Branches",
	"Espejo": "Mirror", "Semilla": "Seed", "Nueva variante": "New variant", "Detalles artísticos; no cambian las capacidades.": "Artistic details; they do not change abilities.",
	"Músculo": "Muscle", "Hidráulico": "Hydraulic", "Exoesqueleto": "Exoskeleton", "Hidrostático": "Hydrostatic", "límite": "limit",
	"Este cuerpo no puede llevar esa actuación": "This body cannot carry that actuation",
	"Necesita exoesqueleto: añade placas": "Needs an exoskeleton: add plates", "Necesita esqueleto interno: quita las placas": "Needs an internal skeleton: remove the plates",
	"Rueda sobre una pieza para escalarla · arrastra una articulación o las flechas de la columna · clic en una pata para elegir su actuador": "Scroll over a part to scale it · drag a joint or the spine arrows · click a limb to choose its actuator",
	"Morder": "Bite", "Cantar": "Sing", "Correr": "Run", "Andar": "Walk",
	"Reproducir": "Play", "Parar": "Stop", "Animación": "Animation",
	"Toca una pieza de la criatura para ajustarla. Arrástrala fuera del cuerpo para quitarla.": "Tap a part on the creature to adjust it. Drag it outside the body to remove it.",
	"Pasa el cursor por el cuerpo para ver la columna · arrastra una vértebra para esculpir · rueda sobre ella para engordar": "Hover over the body to see the spine · drag a vertebra to sculpt · scroll over it to thicken",
	"Arrastra para girar la cámara": "Drag to orbit the camera",
	"Tu criatura camina sola: nada está animado a mano": "Your creature walks on its own: motion comes from its parts",
	"Suelta para colocar": "Release to place", "Llévala hasta el cuerpo de la criatura": "Bring it onto the creature's body",
	"Suelta fuera del cuerpo para quitar la pieza": "Release outside the body to remove the part", "Toca el cuerpo para colocar": "Click the body to place",
	"Arrastra la cuenta verde para girar la pieza.": "Drag the green handle to rotate the part.",
	"Piezas en pareja: se reflejan a ambos lados": "Parts off the midline are mirrored on both sides",
	"Cosmético": "Cosmetic", "Idioma": "Language", "Nombre": "Name", "Sin piezas": "No part selected",
	"Mover": "Move", "Girar": "Rotate", "Inclinar": "Tilt", "Archivo": "File", "Guardados": "Saved designs",
	"Se conserva sin migrar: ": "Preserved without conversion: ",
	"migration.body": "Body sliders, head proportions and slots were approximated as spine nodes and surface parts; the original is preserved.",
	"migration.motion": "Legacy stride and arm length do not transfer exactly; motion now derives from placed parts.",
	"migration.levels": "Legacy levels were approximated as size; no gameplay level is granted.",
	"migration.projection": "Legacy DNA and abilities remain in the original only. This design is cosmetic until C validation.",
}
const ES := {
	"migration.body": "El cuerpo, la cabeza y las ranuras se aproximaron con nodos y piezas; se conserva el original.",
	"migration.motion": "El paso y largo de brazos antiguos no se trasladan exactamente; el movimiento depende de las piezas.",
	"migration.levels": "Los niveles se aproximaron como tamaño; no otorgan nivel de juego.",
	"migration.projection": "ADN y capacidades antiguas se conservan solo en el original. Diseño cosmético hasta validar en C.",
}
const CATEGORY_ES := {"mouths": "Bocas", "senses": "Sentidos", "legs": "Patas", "arms": "Brazos", "weapons": "Armas",
	"wings": "Alas", "fins": "Aletas", "digging_claws": "Excavar", "details": "Detalles"}

func tr_(s: String) -> String:
	if s.begins_with("migration.extra:"):
		return ("Preserved without conversion: " if lang == "en" else "Se conserva sin migrar: ") + s.substr(16)
	if lang == "en":
		return EN.get(s, s)
	return ES.get(s, s)

func category(id: String) -> String:
	return tr_(CATEGORY_ES.get(id, id))

func part_name(id: String) -> String:
	return parts.display_name(id, lang) if parts and parts.has(id) else id
