class_name Evolution
extends RefCounted
## Evolución sin niveles (Fase 5.5). El método oficial (creatures/data/evolutions.json,
## generado con tools/build_evolutions.py desde PokeAPI) se traduce así:
## - Nivel oficial -> victorias en combate con ese Pokémon (nivel / 5, mínimo 2).
## - Piedra u objeto -> usarlo desde la Mochila (se gasta).
## - Amistad -> vínculo 5. Intercambio -> vínculo 7. Otros (lugar, movimiento…) ->
##   vínculo 4 y 6 victorias.
## - De día o de noche, si el oficial lo pide (día de 6:00 a 18:00).
## Al cumplirse, la ficha del Pokémon muestra "Evolucionar"; nunca evoluciona solo.

const PATH := "res://creatures/data/evolutions.json"
const FRIENDSHIP_BOND := 5
const TRADE_BOND := 7
const OTHER_BOND := 4
const OTHER_WINS := 6

static var _data := {}


static func options(identifier: String) -> Array:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data.get(identifier, [])


static func wins_needed(level: int) -> int:
	return maxi(2, ceili(level / 5.0))


static func _time_ok(option: Dictionary) -> bool:
	var time := String(option.get("time", ""))
	if time == "":
		return true
	var hour := GameState.clock_hour()
	var day := hour >= 6.0 and hour < 18.0
	return day if time == "day" else not day


## ¿Se cumple esta opción (sin objeto)?
static func met(entry: Dictionary, option: Dictionary) -> bool:
	var wins := int(entry.get("wins", 0))
	var bond := int(entry.get("bond", 1))
	var ok := false
	match String(option.get("method", "")):
		"level":
			ok = wins >= wins_needed(int(option.get("level", 10)))
		"friendship":
			ok = bond >= FRIENDSHIP_BOND
		"trade":
			ok = bond >= TRADE_BOND
		"other":
			ok = bond >= OTHER_BOND and wins >= OTHER_WINS
	return ok and _time_ok(option)


## Primera evolución lista (sin objeto) o {}.
static func ready_option(entry: Dictionary) -> Dictionary:
	for option: Dictionary in options(entry["species"]):
		if option.get("method", "") != "item" and met(entry, option):
			return option
	return {}


## Evolución con ese objeto o {}.
static func item_option(entry: Dictionary, item_id: String) -> Dictionary:
	for option: Dictionary in options(entry["species"]):
		if option.get("method", "") == "item" and option.get("item", "") == item_id:
			return option
	return {}


## Texto del requisito ("Victorias 3/4", "Vínculo 2/5", "Usa Piedra Trueno"…).
static func requirement_text(entry: Dictionary, option: Dictionary) -> String:
	var wins := int(entry.get("wins", 0))
	var bond := int(entry.get("bond", 1))
	var text := ""
	match String(option.get("method", "")):
		"level":
			text = "Victorias %d/%d" % [mini(wins, wins_needed(int(option["level"]))), wins_needed(int(option["level"]))]
		"item":
			text = "Usa %s" % Items.display_name(option.get("item", ""))
		"friendship":
			text = "Vínculo %d/%d" % [mini(bond, FRIENDSHIP_BOND), FRIENDSHIP_BOND]
		"trade":
			text = "Vínculo %d/%d" % [mini(bond, TRADE_BOND), TRADE_BOND]
		_:
			text = "Vínculo %d/%d y victorias %d/%d" % [mini(bond, OTHER_BOND), OTHER_BOND, mini(wins, OTHER_WINS), OTHER_WINS]
	match String(option.get("time", "")):
		"day":
			text += " · de día"
		"night":
			text += " · de noche"
	return text


## Cambia la especie del Pokémon del equipo (sin animación; la usa EvolutionScene).
static func apply(index: int, to: String, main: Node) -> void:
	var entry: Dictionary = GameState.party[index]
	entry["species"] = to
	entry["hp_ratio"] = 1.0
	# Conserva sus movimientos y suma los iniciales de la nueva especie.
	if entry.has("moves"):
		var unlocked: Array = entry.get("unlocked", [])
		for id in Moves.starting_moves(to):
			if not unlocked.has(id):
				unlocked.append(id)
		entry["unlocked"] = unlocked
	GameState.dex_entry(to)["seen"] = maxi(int(GameState.dex_entry(to)["seen"]), 1)
	GameState.dex_count(to, "caught")
	Achievements.add("evolutions")
	if main != null and index == GameState.companion_index and main.has_method("refresh_companion"):
		main.call("refresh_companion")
