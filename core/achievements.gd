class_name Achievements
extends RefCounted
## Logros por hitos sobre las estadísticas de la partida (GameState.stats). Al cumplir
## uno se avisa en pantalla y queda en GameState.achievements.

## [id, nombre, descripción, estadística, meta]
const LIST := [
	["first_capture", "Primer amigo", "Captura tu primer Pokémon salvaje.", "captures", 1],
	["captures_25", "Coleccionista", "Captura 25 Pokémon.", "captures", 25],
	["captures_100", "Maestro de las Pokéballs", "Captura 100 Pokémon.", "captures", 100],
	["first_shiny", "¡Brilla!", "Captura tu primer Pokémon shiny.", "shinies", 1],
	["walker_1k", "Caminante", "Recorre 1 km.", "distance", 1000.0],
	["walker_10k", "Trotamundos", "Recorre 10 km.", "distance", 10000.0],
	["defeat_10", "Buen equipo", "Tu compañero debilita a 10 salvajes.", "defeated", 10],
	["gather_50", "Recolector", "Recoge 50 objetos en el mundo.", "gathered", 50],
	["activities_5", "Ocupado", "Cumple 5 actividades del Rotom Móvil.", "activities", 5],
	["behind_10", "Sigiloso", "Captura 10 Pokémon por la espalda.", "behind", 10],
	["survivor", "Siempre de pie", "Recupérate de 5 desmayos sin ir al Centro Pokémon.", "recoveries", 5],
	["first_evolution", "¿Eh?", "Haz evolucionar a un Pokémon.", "evolutions", 1],
	["first_mega", "Más allá de la evolución", "Megaevoluciona por primera vez.", "megas", 1],
	["win_streak_10", "Imparable", "Gana 10 combates seguidos sin desmayarte.", "best_streak", 10],
	["trainers_10", "Retador", "Vence a 10 entrenadores en los caminos.", "trainers", 10],
	["photos_25", "Fotógrafo", "Saca 25 fotos.", "photos", 25],
	["mega_stones_3", "Coleccionista de megapiedras", "Consigue 3 megapiedras.", "mega_stones", 3],
	["guardians_4", "Cazador de guardianes", "Vence a 4 guardianes de bioma.", "guardians", 4],
	["villain_leaders_3", "Némesis", "Vence al líder del equipo villano en 3 regiones.", "villain_leaders", 3],
]


## Suma amount a la estadística y desbloquea los logros que alcance.
static func add(stat: String, amount: float = 1.0) -> void:
	GameState.stats[stat] = float(GameState.stats.get(stat, 0.0)) + amount
	for entry: Array in LIST:
		if entry[3] == stat and not GameState.achievements.has(entry[0]) and float(GameState.stats[stat]) >= float(entry[4]):
			GameState.achievements[entry[0]] = GameState.game_day() + 1
			GameState.notice.emit("¡Logro desbloqueado! %s: %s" % [entry[1], entry[2]])
