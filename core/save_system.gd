extends Node
## Guardado y carga de la partida: 3 ranuras manuales (1 a 3) y el autoguardado
## (ranura 0, cada AUTOSAVE_SECONDS y al entrar a un Centro Pokémon). Cada ranura es
## un JSON en user://save_N.json con el estado de GameState y la posición del jugador.

const AUTOSAVE_SECONDS := 300.0
const SLOTS := 3
const VERSION := 1

## Posición del jugador a restaurar al cargar (la usa la escena principal).
var pending_position := Vector3.INF


func slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Resumen de la ranura para mostrarla (o {} si está vacía).
func slot_info(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if not data is Dictionary:
		return {}
	var dex: Dictionary = data.get("dex", {})
	var caught := 0
	for id: String in dex:
		caught += 1 if int(dex[id].get("caught", 0)) > 0 else 0
	return {"name": data.get("player_name", "?"), "character": data.get("character_id", ""),
			"play_time": float(data.get("play_time", 0.0)), "caught": caught, "saved_at": data.get("saved_at", ""),
			"companion": (data.get("party", [{}]) as Array)[int(data.get("companion_index", 0))].get("species", "") if not (data.get("party", []) as Array).is_empty() else ""}


func save_slot(slot: int, main: Node) -> bool:
	if main != null and main.has_method("sync_companion_to_party"):
		main.sync_companion_to_party()
	var player := main.get_node_or_null("Player") as Node3D if main != null else null
	var position := player.global_position if player != null else Vector3.ZERO
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"character_id": GameState.character_id, "player_name": GameState.player_name,
		"gender": GameState.gender, "difficulty": GameState.difficulty,
		"play_time": GameState.play_time, "money": GameState.money,
		"party": GameState.party, "box": GameState.box, "companion_index": GameState.companion_index,
		"bag": GameState.bag, "selected_ball": GameState.selected_ball,
		"dex": GameState.dex, "legendary_caught": GameState.legendary_caught,
		"tips_seen": GameState.tips_seen, "rewards_claimed": GameState.rewards_claimed,
		"respawn_point": [GameState.respawn_point.x, GameState.respawn_point.y, GameState.respawn_point.z],
		"position": [position.x, position.y, position.z],
	}
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


## Carga la ranura en GameState y deja la posición pendiente para la escena principal.
func load_slot(slot: int) -> bool:
	if not has_slot(slot):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if not data is Dictionary:
		return false
	GameState.character_id = data.get("character_id", PlayerCharacters.DEFAULT_ID)
	GameState.player_name = data.get("player_name", "Nate")
	GameState.gender = data.get("gender", "male")
	GameState.difficulty = int(data.get("difficulty", 1))
	GameState.play_time = float(data.get("play_time", 0.0))
	GameState.money = int(data.get("money", 3000))
	GameState.party.assign(data.get("party", []))
	GameState.box.assign(data.get("box", []))
	GameState.companion_index = int(data.get("companion_index", 0))
	GameState.bag = data.get("bag", {})
	for id: String in GameState.bag.keys():
		GameState.bag[id] = int(GameState.bag[id])
	GameState.selected_ball = data.get("selected_ball", "poke-ball")
	GameState.dex = data.get("dex", {})
	GameState.legendary_caught = data.get("legendary_caught", {})
	GameState.tips_seen = data.get("tips_seen", {})
	GameState.rewards_claimed = data.get("rewards_claimed", {})
	var respawn: Array = data.get("respawn_point", [0, 1, 0])
	GameState.respawn_point = Vector3(respawn[0], respawn[1], respawn[2])
	var pos: Array = data.get("position", [0, 1, 0])
	pending_position = Vector3(pos[0], pos[1], pos[2])
	return true
