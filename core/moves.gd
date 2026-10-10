class_name Moves
extends RefCounted
## Movimientos (creatures/data/moves.json) y listas oficiales por especie
## (learnsets.json), sin niveles: cada Pokémon lleva 4 movimientos de su lista, en
## cualquier mezcla de físicos y especiales; desbloquea el resto usándolos y con la
## investigación de su especie. Cada movimiento tiene 3 rangos de dominio (por usos) y
## se lanza en estilo Normal, Fuerte (más daño, más espera) o Ágil (menos daño, sale
## rápido). Sin PP: cada uno tiene su tiempo de espera.

const MOVES_PATH := "res://creatures/data/moves.json"
const LEARNSETS_PATH := "res://creatures/data/learnsets.json"
## Usos para subir de rango de dominio (1 → 2 → 3).
const RANK_USES := [0, 20, 60]
const RANK_POWER := [1.0, 1.15, 1.3]
const RANK_COOLDOWN := [1.0, 0.85, 0.7]
## Usos de movimientos para desbloquear el siguiente de su lista.
const UNLOCK_EVERY := 15
enum Style { NORMAL, STRONG, AGILE }
const STYLE_POWER := [1.0, 1.35, 0.75]
const STYLE_COOLDOWN := [1.0, 1.6, 0.55]
const STYLE_NAMES := ["Normal", "Fuerte", "Ágil"]
## Movimientos que curan al entrenador además de al Pokémon ("tu Pokémon te cura").
const HEAL_TRAINER := ["wish", "aromatherapy", "heal-pulse", "life-dew", "floral-healing", "healing-wish", "lunar-blessing",
		"jungle-healing", "heal-bell", "pollen-puff", "lunar-dance", "softboiled", "milk-drink"]

static var _moves := {}
static var _learnsets := {}


static func _ensure() -> void:
	if _moves.is_empty():
		_moves = JSON.parse_string(FileAccess.get_file_as_string(MOVES_PATH))
		_learnsets = JSON.parse_string(FileAccess.get_file_as_string(LEARNSETS_PATH))


static func get_move(id: String) -> Dictionary:
	_ensure()
	return _moves.get(id, {"name": id, "type": 0, "power": 40, "accuracy": 100, "class": "physical", "category": "damage"})


static func learnset(identifier: String) -> Dictionary:
	_ensure()
	return _learnsets.get(identifier, {"level": [], "other": []})


## Lista completa de la especie: primero por nivel (en orden) y luego MT y tutor.
static func all_for(identifier: String) -> Array[String]:
	var result: Array[String] = []
	var data := learnset(identifier)
	for pair: Array in data["level"]:
		result.append(pair[1])
	for id: String in data["other"]:
		result.append(id)
	return result


## Los 4 movimientos con que empieza: los primeros de su lista por nivel, con al menos
## uno que haga daño.
static func starting_moves(identifier: String) -> Array[String]:
	var level: Array[String] = []
	for pair: Array in learnset(identifier)["level"]:
		level.append(pair[1])
	var result: Array[String] = []
	for id in level:
		if result.size() >= 4:
			break
		result.append(id)
	if not result.any(func(id: String) -> bool: return is_damaging(id)):
		for id in level + all_for(identifier):
			if is_damaging(id):
				if result.size() >= 4:
					result[3] = id
				else:
					result.append(id)
				break
	if result.is_empty():
		result.append("tackle")
	return result


## Prepara la ficha de un Pokémon del equipo: movimientos, desbloqueados y dominio.
static func ensure_entry(entry: Dictionary) -> void:
	if not entry.has("moves"):
		entry["moves"] = starting_moves(entry["species"])
		entry["unlocked"] = (entry["moves"] as Array).duplicate()
		entry["mastery"] = {}
		entry["move_uses"] = 0


static func is_damaging(id: String) -> bool:
	var move := get_move(id)
	return move["class"] != "status"


static func rank(entry: Dictionary, id: String) -> int:
	var uses := int((entry.get("mastery", {}) as Dictionary).get(id, 0))
	return 3 if uses >= RANK_USES[2] else (2 if uses >= RANK_USES[1] else 1)


## Siguiente movimiento por desbloquear de su lista por nivel ("" si no queda).
static func next_unlock(entry: Dictionary) -> String:
	var unlocked: Array = entry.get("unlocked", [])
	for pair: Array in learnset(entry["species"])["level"]:
		if not unlocked.has(pair[1]):
			return pair[1]
	for id: String in learnset(entry["species"])["other"]:
		if not unlocked.has(id):
			return id
	return ""


## Desbloquea el siguiente movimiento; devuelve su id ("" si no hay).
static func unlock_next(entry: Dictionary) -> String:
	ensure_entry(entry)
	var id := next_unlock(entry)
	if id != "":
		(entry["unlocked"] as Array).append(id)
	return id


## MT: desbloquea un movimiento de tipo type de la lista de la especie (primero los de
## MT y tutor, luego los de nivel). Devuelve su id o "".
static func teach_type(entry: Dictionary, type: int) -> String:
	ensure_entry(entry)
	var unlocked: Array = entry["unlocked"]
	var data := learnset(entry["species"])
	var options: Array[String] = []
	for id: String in data["other"]:
		if not unlocked.has(id) and int(get_move(id)["type"]) == type:
			options.append(id)
	if options.is_empty():
		for pair: Array in data["level"]:
			if not unlocked.has(pair[1]) and int(get_move(pair[1])["type"]) == type:
				options.append(pair[1])
	if options.is_empty():
		return ""
	options.sort_custom(func(a: String, b: String) -> bool: return int(get_move(a)["power"]) > int(get_move(b)["power"]))
	unlocked.append(options[0])
	return options[0]


## Registra un uso (dominio y desbloqueo por uso). Devuelve el movimiento recién
## desbloqueado o "".
static func register_use(entry: Dictionary, id: String) -> String:
	ensure_entry(entry)
	var mastery: Dictionary = entry["mastery"]
	var before := rank(entry, id)
	mastery[id] = int(mastery.get(id, 0)) + 1
	if rank(entry, id) > before:
		GameState.notice.emit("¡%s dominó %s! (rango %d)" % [MenuStyle.species(entry["species"]).display_name, get_move(id)["name"], rank(entry, id)])
	entry["move_uses"] = int(entry.get("move_uses", 0)) + 1
	if int(entry["move_uses"]) % UNLOCK_EVERY == 0:
		var learned := unlock_next(entry)
		if learned != "":
			GameState.notice.emit("¡%s puede aprender %s! Equípalo en el menú (Equipo)." % [MenuStyle.species(entry["species"]).display_name, get_move(learned)["name"]])
			return learned
	return ""


## Espera (s) del movimiento según su potencia, el dominio y el estilo.
static func cooldown(id: String, move_rank: int, style: Style) -> float:
	var move := get_move(id)
	var base := 4.0 if move["class"] == "status" else clampf(0.6 + float(move["power"]) / 55.0, 0.8, 3.6)
	return base * RANK_COOLDOWN[move_rank - 1] * STYLE_COOLDOWN[style]


## Daño de un movimiento con las estadísticas equilibradas (sin niveles):
## 6 × potencia/60 × ataque/defensa × STAB × efectividad × dominio × estilo × azar.
static func damage(attacker: SpeciesData, defender: SpeciesData, id: String, move_rank: int, style: Style, rng: RandomNumberGenerator, training: Dictionary = {}) -> float:
	var move := get_move(id)
	var physical: bool = move["class"] == "physical"
	var attack := MenuStyle.effective_stat(attacker.attack if physical else attacker.sp_attack) + float(training.get("attack" if physical else "sp_attack", 0))
	var defense := MenuStyle.effective_stat(defender.defense if physical else defender.sp_defense)
	var power := float(move["power"]) if int(move["power"]) > 0 else 60.0
	var type: int = int(move["type"])
	var stab := 1.5 if attacker.types.has(type) else 1.0
	var effectiveness := TypeChart.effectiveness(type, defender.types)
	return 6.0 * (power / 60.0) * (attack / maxf(defense, 1.0)) * stab * effectiveness * RANK_POWER[move_rank - 1] * STYLE_POWER[style] * rng.randf_range(0.85, 1.0)


## Qué hace un movimiento de estado: "heal_trainer", "heal_self", "buff", "stun" u "other".
static func effect(id: String) -> String:
	var move := get_move(id)
	if HEAL_TRAINER.has(id):
		return "heal_trainer"
	if move["class"] != "status":
		return "damage"
	match move["category"]:
		"heal":
			return "heal_self"
		"buff", "damage_raise":
			return "buff"
		"ailment", "swagger":
			return "stun" if [1, 2, 3, 6].has(int(move["ailment"])) else "other"
	return "other"


static func type_name(id: String) -> String:
	return MenuStyle.TYPE_NAMES[int(get_move(id)["type"])]


static func class_name_es(id: String) -> String:
	return {"physical": "Físico", "special": "Especial", "status": "Estado"}.get(get_move(id)["class"], "?")
