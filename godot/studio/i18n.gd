extends RefCounted
## es/en strings. Spanish is the source text, as in web/studio/i18n.js.

var lang := "es"
var parts: RefCounted

const EN := {
	"Modo": "Mode", "Construir": "Build", "Pintar": "Paint", "Probar": "Test", "Deshacer": "Undo", "Rehacer": "Redo",
	"Pieza": "Part", "Piel": "Skin", "Dibujo": "Pattern", "Colores": "Colours", "Escama": "Scales", "Brillo": "Gloss",
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
