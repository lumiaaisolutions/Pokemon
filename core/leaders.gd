class_name Leaders
extends RefCounted
## Líderes de gimnasio y Alto Mando de las regiones (catálogo aprobado por Fernando el
## 2026-10-10, ver docs/sistemas/regiones.md). Cada región tiene 8 líderes al azar de
## Kanto a Teselia, sin repetirse entre regiones, y una Liga con 4 del Alto Mando real y
## un héroe no elegido como Campeón.
## Sprites: art/npcs/lider_<id>.png y alto_<id>.png (tools/build_leader_sheets.py); los que
## no tienen sprite de DS usan una clase de BW2 ("look") y su retrato oficial.

const T := PokemonTypes.Type
## Tipo -1: equipo mixto (Blue, Cynthia, Alder).
const MIXED := -1

## id -> {name, type, team (de débil a fuerte), themes (afinidad con el tema del pueblo), look opcional}.
## "portrait" (Alto Mando): archivo de origen en sprites/trainers/ de su retrato copiado a art/portraits/.
const GYM := {
	"brock": {"name": "Brock", "type": T.ROCK, "team": ["geodude", "onix", "rhyhorn", "omastar", "kabutops", "golem"], "themes": ["mining"]},
	"misty": {"name": "Misty", "type": T.WATER, "team": ["staryu", "psyduck", "goldeen", "horsea", "lapras", "starmie"], "themes": ["fishing"]},
	"ltsurge": {"name": "Lt. Surge", "type": T.ELECTRIC, "team": ["voltorb", "pikachu", "magnemite", "electabuzz", "electrode", "raichu"], "themes": ["commercial"]},
	"erika": {"name": "Erika", "type": T.GRASS, "team": ["tangela", "weepinbell", "gloom", "jumpluff", "victreebel", "vileplume"], "themes": ["farm"]},
	"janine": {"name": "Janine", "type": T.POISON, "team": ["zubat", "grimer", "ariados", "venomoth", "weezing", "crobat"], "themes": ["lumber"]},
	"koga": {"name": "Koga", "type": T.POISON, "team": ["koffing", "venonat", "muk", "forretress", "weezing", "crobat"], "themes": ["lumber"]},
	"sabrina": {"name": "Sabrina", "type": T.PSYCHIC, "team": ["abra", "mr-mime", "kadabra", "jynx", "espeon", "alakazam"], "themes": ["commercial"]},
	"blaine": {"name": "Blaine", "type": T.FIRE, "team": ["growlithe", "ponyta", "magmar", "rapidash", "ninetales", "arcanine"], "themes": ["oasis"]},
	"blue": {"name": "Blue", "type": MIXED, "team": ["pidgeotto", "exeggcute", "rhyhorn", "gyarados", "alakazam", "pidgeot"], "themes": ["commercial"]},
	"giovanni": {"name": "Giovanni", "type": T.GROUND, "team": ["dugtrio", "nidorino", "nidorina", "rhydon", "nidoking", "nidoqueen"], "themes": ["mining", "oasis"]},
	"falkner": {"name": "Falkner", "type": T.FLYING, "team": ["pidgey", "hoothoot", "pidgeotto", "noctowl", "dodrio", "pidgeot"], "themes": ["farm", "alpine"]},
	"bugsy": {"name": "Bugsy", "type": T.BUG, "team": ["caterpie", "metapod", "kakuna", "scyther", "heracross", "scizor"], "themes": ["lumber"]},
	"whitney": {"name": "Whitney", "type": T.NORMAL, "team": ["teddiursa", "clefairy", "girafarig", "miltank", "ursaring", "snorlax"], "themes": ["farm", "commercial"]},
	"morty": {"name": "Morty", "type": T.GHOST, "team": ["gastly", "misdreavus", "haunter", "dusclops", "mismagius", "gengar"], "themes": ["lumber"]},
	"chuck": {"name": "Chuck", "type": T.FIGHTING, "team": ["mankey", "machop", "primeape", "machoke", "poliwrath", "machamp"], "themes": ["mining", "fishing"]},
	"jasmine": {"name": "Jasmine", "type": T.STEEL, "team": ["magnemite", "skarmory", "magneton", "forretress", "scizor", "steelix"], "themes": ["fishing"]},
	"pryce": {"name": "Pryce", "type": T.ICE, "team": ["seel", "swinub", "dewgong", "piloswine", "lapras", "mamoswine"], "themes": ["alpine"]},
	"clair": {"name": "Clair", "type": T.DRAGON, "team": ["dratini", "horsea", "dragonair", "seadra", "kingdra", "dragonite"], "themes": ["alpine"]},
	"roxanne": {"name": "Roxanne", "type": T.ROCK, "team": ["geodude", "nosepass", "lileep", "anorith", "graveler", "probopass"], "themes": ["mining"]},
	"brawly": {"name": "Brawly", "type": T.FIGHTING, "team": ["machop", "makuhita", "meditite", "machoke", "medicham", "hariyama"], "themes": ["fishing"]},
	"wattson": {"name": "Wattson", "type": T.ELECTRIC, "team": ["voltorb", "electrike", "magnemite", "magneton", "manectric", "electrode"], "themes": ["commercial"]},
	"flannery": {"name": "Flannery", "type": T.FIRE, "team": ["numel", "slugma", "torkoal", "magcargo", "camerupt", "houndoom"], "themes": ["oasis"]},
	"norman": {"name": "Norman", "type": T.NORMAL, "team": ["zigzagoon", "spinda", "vigoroth", "linoone", "kangaskhan", "slaking"], "themes": ["farm"]},
	"winona": {"name": "Winona", "type": T.FLYING, "team": ["swablu", "tropius", "pelipper", "skarmory", "swellow", "altaria"], "themes": ["alpine", "farm"]},
	"wallace": {"name": "Wallace", "type": T.WATER, "team": ["luvdisc", "wailmer", "whiscash", "sealeo", "gyarados", "milotic"], "themes": ["fishing"]},
	"juan": {"name": "Juan", "type": T.WATER, "team": ["luvdisc", "whiscash", "sealeo", "crawdaunt", "kingdra", "milotic"], "themes": ["fishing", "commercial"]},
	"steven": {"name": "Steven", "type": T.STEEL, "team": ["skarmory", "claydol", "aggron", "cradily", "armaldo", "metagross"], "themes": ["mining"]},
	"roark": {"name": "Roark", "type": T.ROCK, "team": ["geodude", "onix", "cranidos", "bonsly", "rampardos", "rhyperior"], "themes": ["mining"]},
	"gardenia": {"name": "Gardenia", "type": T.GRASS, "team": ["cherubi", "turtwig", "roserade", "cherrim", "tangrowth", "torterra"], "themes": ["lumber", "farm"]},
	"maylene": {"name": "Maylene", "type": T.FIGHTING, "team": ["meditite", "machoke", "riolu", "medicham", "toxicroak", "lucario"], "themes": ["alpine", "mining"]},
	"crasherwake": {"name": "Crasher Wake", "type": T.WATER, "team": ["buizel", "psyduck", "quagsire", "gastrodon", "floatzel", "gyarados"], "themes": ["fishing"]},
	"fantina": {"name": "Fantina", "type": T.GHOST, "team": ["drifloon", "duskull", "haunter", "drifblim", "mismagius", "gengar"], "themes": ["lumber", "commercial"]},
	"byron": {"name": "Byron", "type": T.STEEL, "team": ["magnemite", "bronzor", "shieldon", "bronzong", "bastiodon", "steelix"], "themes": ["mining"]},
	"volkner": {"name": "Volkner", "type": T.ELECTRIC, "team": ["pachirisu", "jolteon", "raichu", "luxio", "electivire", "luxray"], "themes": ["commercial", "fishing"], "look": "guay_b"},
	"cynthia": {"name": "Cynthia", "type": MIXED, "team": ["gible", "spiritomb", "roserade", "lucario", "milotic", "garchomp"], "themes": ["commercial"]},
	"alder": {"name": "Alder", "type": MIXED, "team": ["accelgor", "escavalier", "druddigon", "bouffalant", "vanilluxe", "volcarona"], "themes": ["lumber", "oasis"]},
	"cilan": {"name": "Cilan", "type": T.GRASS, "team": ["lillipup", "pansage", "petilil", "cottonee", "simisage", "lilligant"], "themes": ["farm", "commercial"], "look": "dependiente"},
	"chili": {"name": "Chili", "type": T.FIRE, "team": ["lillipup", "pansear", "darumaka", "litwick", "simisear", "darmanitan"], "themes": ["oasis", "commercial"]},
	"cress": {"name": "Cress", "type": T.WATER, "team": ["lillipup", "panpour", "tympole", "frillish", "simipour", "seismitoad"], "themes": ["fishing", "commercial"]},
	"burgh": {"name": "Burgh", "type": T.BUG, "team": ["sewaddle", "dwebble", "whirlipede", "swadloon", "crustle", "leavanny"], "themes": ["lumber"]},
	"elesa": {"name": "Elesa", "type": T.ELECTRIC, "team": ["blitzle", "emolga", "joltik", "flaaffy", "zebstrika", "eelektross"], "themes": ["commercial"]},
	"clay": {"name": "Clay", "type": T.GROUND, "team": ["drilbur", "sandile", "palpitoad", "krokorok", "excadrill", "krookodile"], "themes": ["mining", "oasis"]},
	"skyla": {"name": "Skyla", "type": T.FLYING, "team": ["ducklett", "woobat", "tranquill", "swoobat", "swanna", "unfezant"], "themes": ["alpine", "fishing"]},
	"brycen": {"name": "Brycen", "type": T.ICE, "team": ["vanillite", "cubchoo", "cryogonal", "vanillish", "beartic", "vanilluxe"], "themes": ["alpine"]},
	"drayden": {"name": "Drayden", "type": T.DRAGON, "team": ["axew", "druddigon", "fraxure", "flygon", "altaria", "haxorus"], "themes": ["alpine", "mining"]},
	"iris": {"name": "Iris", "type": T.DRAGON, "team": ["axew", "fraxure", "druddigon", "lapras", "archeops", "haxorus"], "themes": ["lumber"]},
	"roxie": {"name": "Roxie", "type": T.POISON, "team": ["koffing", "trubbish", "venipede", "whirlipede", "garbodor", "scolipede"], "themes": ["commercial", "lumber"]},
	"marlon": {"name": "Marlon", "type": T.WATER, "team": ["frillish", "tirtouga", "mantine", "carracosta", "wailord", "jellicent"], "themes": ["fishing"]},
}

## Alto Mando real de Kanto a Teselia (Koga quedó como líder de gimnasio).
const ELITE := {
	"lorelei": {"name": "Lorelei", "type": T.ICE, "team": ["dewgong", "cloyster", "slowbro", "jynx", "lapras"], "look": "chica_c", "portrait": "lorelei-gen3"},
	"bruno": {"name": "Bruno", "type": T.FIGHTING, "team": ["hitmontop", "hitmonlee", "hitmonchan", "onix", "machamp"]},
	"agatha": {"name": "Agatha", "type": T.GHOST, "team": ["haunter", "golbat", "arbok", "mismagius", "gengar"], "look": "abuela", "portrait": "agatha-gen3"},
	"lance": {"name": "Lance", "type": T.DRAGON, "team": ["gyarados", "aerodactyl", "charizard", "kingdra", "dragonite"]},
	"will": {"name": "Will", "type": T.PSYCHIC, "team": ["xatu", "jynx", "exeggutor", "slowbro", "bronzong"]},
	"karen": {"name": "Karen", "type": T.DARK, "team": ["umbreon", "vileplume", "murkrow", "gengar", "houndoom"]},
	"sidney": {"name": "Sidney", "type": T.DARK, "team": ["mightyena", "shiftry", "cacturne", "crawdaunt", "absol"], "look": "motorista"},
	"phoebe": {"name": "Phoebe", "type": T.GHOST, "team": ["sableye", "banette", "dusclops", "froslass", "dusknoir"], "look": "chica_b", "portrait": "phoebe-gen3"},
	"glacia": {"name": "Glacia", "type": T.ICE, "team": ["sealeo", "glalie", "froslass", "weavile", "walrein"], "look": "dama_a"},
	"drake": {"name": "Drake", "type": T.DRAGON, "team": ["shelgon", "altaria", "flygon", "kingdra", "salamence"], "look": "marinero", "portrait": "drake-gen3"},
	"aaron": {"name": "Aaron", "type": T.BUG, "team": ["dustox", "beautifly", "vespiquen", "heracross", "drapion"], "look": "ornitologo"},
	"bertha": {"name": "Bertha", "type": T.GROUND, "team": ["whiscash", "gliscor", "hippowdon", "golem", "rhyperior"], "look": "abuela"},
	"flint": {"name": "Flint", "type": T.FIRE, "team": ["houndoom", "flareon", "rapidash", "magmortar", "infernape"]},
	"lucian": {"name": "Lucian", "type": T.PSYCHIC, "team": ["mr-mime", "girafarig", "medicham", "alakazam", "bronzong"], "look": "doctor"},
	"shauntal": {"name": "Shauntal", "type": T.GHOST, "team": ["cofagrigus", "jellicent", "golurk", "drifblim", "chandelure"]},
	"grimsley": {"name": "Grimsley", "type": T.DARK, "team": ["scrafty", "liepard", "krookodile", "bisharp", "honchkrow"], "look": "guay_a"},
	"caitlin": {"name": "Caitlin", "type": T.PSYCHIC, "team": ["musharna", "sigilyph", "reuniclus", "gothitelle", "metagross"]},
	"marshal": {"name": "Marshal", "type": T.FIGHTING, "team": ["throh", "sawk", "mienshao", "conkeldurr", "lucario"], "look": "karateka_b"},
}

## Tamaño del equipo del líder por región (la 1.ª empieza con 3; sube con tus medallas).
const TEAM_BY_REGION := [3, 4, 4, 5, 6, 6]
## Desde qué región megaevolucionan líderes y Alto Mando (diseño: "megas desde la tercera").
const MEGA_FROM_REGION := 2


static func info(id: String) -> Dictionary:
	return GYM.get(id, ELITE.get(id, {}))


static func name_of(id: String) -> String:
	return String(info(id).get("name", id.capitalize()))


## Aspecto (hoja en art/npcs/): el sprite propio o la clase de BW2 provisional.
static func look(id: String) -> String:
	var data := info(id)
	if data.has("look"):
		return data["look"]
	return ("lider_" if GYM.has(id) else "alto_") + id


static func sheet(id: String) -> Texture2D:
	return NpcLooks.sheet(look(id))


## Retrato oficial para la caja de diálogo (art/portraits/<id>.png, copiados de los
## sprites de entrenador de Showdown; los héroes también, para el Campeón).
static func portrait(id: String) -> Texture2D:
	var path := "res://art/portraits/%s.png" % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func type_name(id: String) -> String:
	var type := int(info(id).get("type", MIXED))
	return "mixto" if type == MIXED else MenuStyle.TYPE_NAMES[type]


## Equipo del líder: los más fuertes de su lista según la región y tus medallas ahí.
static func gym_team(id: String, region: int, badges: int) -> Array[SpeciesData]:
	var names: Array = info(id).get("team", [])
	var size := clampi(TEAM_BY_REGION[clampi(region, 0, TEAM_BY_REGION.size() - 1)] + badges / 4, 3, names.size())
	return _species(names.slice(names.size() - size))


static func elite_team(id: String) -> Array[SpeciesData]:
	return _species(info(id).get("team", []))


static func _species(names: Array) -> Array[SpeciesData]:
	var team: Array[SpeciesData] = []
	for name: String in names:
		var species := MenuStyle.species(name)
		if species != null:
			team.append(species)
	return team


## Mega del último Pokémon del equipo si tiene (desde la región MEGA_FROM_REGION).
static func mega_for(team: Array[SpeciesData], region: int) -> String:
	if region < MEGA_FROM_REGION or team.is_empty():
		return ""
	var catalog := MegaCatalog.load_catalog()
	for i in range(team.size() - 1, -1, -1):
		for suffix in ["-mega", "-mega-x"]:
			var mega := catalog.find(team[i].identifier + suffix)
			if mega != null:
				return team[i].identifier + suffix
	return ""


## Entrenadores del gimnasio (2 por gimnasio): clase de BW2 y 2–3 Pokémon del tipo del líder.
static func gym_trainer_team(id: String, region: int, rng: RandomNumberGenerator) -> Array[SpeciesData]:
	var names: Array = info(id).get("team", [])
	var count := clampi(2 + region / 2, 2, 3)
	var pool: Array = names.slice(0, maxi(names.size() - 2, 2))
	var picked: Array = []
	for i in count:
		picked.append(pool[rng.randi() % pool.size()])
	return _species(picked)
