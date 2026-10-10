class_name NpcLooks
extends RefCounted
## Aspecto de los NPC con las clases de BW2 (acordado con Fernando el 2026-10-10: los
## NPC no usan los sprites de los héroes). Hojas en art/npcs/ (tools/build_npc_sheets.py).
## Cada oficio tiene sus aspectos posibles; el género sale del aspecto (y con él el nombre).

const DIR := "res://art/npcs/"
## Aspecto -> género.
const GENDER := {
	"joven_a": "male", "joven_b": "male", "joven_c": "male", "joven_d": "male", "joven_e": "male", "joven_f": "male",
	"chica_a": "female", "chica_b": "female", "chica_c": "female", "colegial": "male", "pokefan": "male", "nino": "male",
	"abuela": "female", "abuelo_a": "male", "abuelo_b": "male", "karateka_a": "male", "karateka_b": "male",
	"doctor": "male", "enfermera": "female", "dama_a": "female", "dama_b": "female", "dama_sombrilla": "female",
	"obrero_a": "male", "obrero_b": "male", "musico_a": "male", "musico_b": "male", "musico_c": "male", "musica": "female",
	"dependiente": "male", "cientifica": "female", "ornitologo": "male", "marinero": "male", "guay_a": "male",
	"guay_b": "male", "guay_chica": "female", "medium": "female", "motorista": "male", "policia": "male", "mochilero": "male", "cientifico": "male", "hugh": "male", "prof_oak": "male", "prof_elm": "male", "prof_rowan": "male", "prof_kukui": "male", "prof_sada": "female", "prof_turo": "male",
}
## Oficio de los habitantes -> aspectos.
const ROLES := {
	"vecino": ["joven_a", "joven_c", "joven_d", "joven_e", "joven_f", "chica_a", "chica_b", "chica_c", "dama_a", "dama_b", "pokefan", "musico_a", "musica"],
	"vendedor": ["dependiente"],
	"enfermera": ["enfermera"],
	"investigador": ["cientifica", "doctor"],
	"entrenador": ["guay_a", "guay_b", "guay_chica", "karateka_a"],
	"coordinador": ["dama_sombrilla", "dama_b", "musico_c"],
	"niño": ["nino", "colegial", "joven_b"],
	"abuela": ["abuela", "abuelo_a", "abuelo_b"],
	"viajero": ["mochilero", "ornitologo", "joven_a", "chica_a", "marinero", "obrero_b"],
}
## Clase de entrenador de camino -> aspectos.
const CLASSES := {
	"Bichero": ["ornitologo", "colegial"], "Dominguera": ["chica_c", "dama_b"], "Pokéfan": ["pokefan"],
	"Montañero": ["obrero_b", "mochilero"], "Karateka": ["karateka_a", "karateka_b"], "Ruinamaníaco": ["abuelo_a", "mochilero"],
	"Nadadora": ["chica_b"], "Nadador": ["joven_d"], "Pescador": ["marinero"], "Esquiadora": ["chica_a"],
	"Médium": ["medium"], "Motorista": ["motorista"], "Joven": ["joven_b", "joven_c"], "Chica": ["chica_a", "chica_c"],
	"Entrenador Guay": ["guay_a", "guay_b"], "Entrenadora Guay": ["guay_chica"], "Dominguero": ["mochilero"], "Ornitólogo": ["ornitologo"],
}

static var _sheets := {}


static func pick(options: Array, rng: RandomNumberGenerator) -> String:
	return options[rng.randi() % options.size()]


static func for_role(role: String, rng: RandomNumberGenerator) -> String:
	return pick(ROLES.get(role, ROLES["vecino"]), rng)


static func for_class(trainer_class: String, rng: RandomNumberGenerator) -> String:
	return pick(CLASSES.get(trainer_class, ROLES["vecino"]), rng)


static func gender(look: String) -> String:
	return GENDER.get(look, "male")


static func sheet(look: String) -> Texture2D:
	if not _sheets.has(look):
		var path := DIR + look + ".png"
		_sheets[look] = load(path) as Texture2D if ResourceLoader.exists(path) else PlayerCharacters.sheet("nate_bw2")
	return _sheets[look]


## Retrato: el cuadro de frente.
static func portrait(look: String) -> Texture2D:
	var source := sheet(look)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(0, 0, source.get_width() / 3.0, source.get_height() / 8.0)
	return atlas
