extends Node
## Prueba del combate en arena (Fase 3): empezar contra un salvaje, mundo en pausa,
## huir saliendo del círculo, ganar con recompensas (racha, investigación, vínculo),
## cambiar de Pokémon con espera y megaevolucionar con la Piedra Llave.
## Uso: godot --headless --path . tests/test_battle.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder
var _spawner: WildSpawner
var _battle: BattleManager
var _results: Array[String] = []


func _ready() -> void:
	BattleManager.enabled = true
	_main = MAIN_SCENE.instantiate() as Node3D
	_main.set("starter_ceremony", false)
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_world = _main.get_node("World") as WorldBuilder
	_spawner = _main.get_node("Spawner") as WildSpawner
	_battle = _main.get_node("Battle") as BattleManager
	_battle.ended.connect(func(result: String) -> void: _results.append(result))
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_battle: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	# Datos: el fragmento existe y fabrica MT.
	_check(Items.exists(BattleManager.FRAGMENT), "el Fragmento místico debe existir en el catálogo")
	_check(Items.recipes().any(func(r: Dictionary) -> bool: return String(r["result"]).begins_with("tm-") and r["needs"].has(BattleManager.FRAGMENT)), "debe haber recetas de MT con fragmentos")

	var navigation := _main.get_node("Navigation") as WorldNavigation
	while not navigation.is_baked:
		await get_tree().physics_frame
	_spawner.set_process(false)
	(_main.get_node("Legendaries") as Node).set_process(false)
	(_main.get_node("Ambushes") as Node).set_process(false)
	_clear_wild()
	# Equipo: el compañero al azar más un Lucario para cambiar y megaevolucionar.
	GameState.party.append({"species": "lucario", "shiny": false, "hp_ratio": 1.0})
	var lucario_index := GameState.party.size() - 1
	var arena := _find_clearing()
	_player.global_position = arena + Vector3(0, 0.5, 6)
	var companion: PokemonActor = _main.companion
	companion.global_position = arena + Vector3(1.5, 0.5, 4)
	await _frames(10)

	# 1. Empezar el combate.
	var wild := _spawner.spawn_species(_species("lillipup"), arena + Vector3(0, 0, -4), false, false)
	await _frames(2)
	_check(_battle.can_start(wild), "debe poder empezar contra un salvaje cercano")
	_check(_battle.start(wild), "start() debe empezar el combate")
	await _frames(5)
	_check(_battle.active and _battle.opponent == wild, "el combate queda activo contra el salvaje")
	_check(_main.companion.controlled, "tu Pokémon queda bajo tu control")
	_check(_spawner.process_mode == Node.PROCESS_MODE_DISABLED or not _spawner.is_processing(), "el mundo queda en pausa (sin aparecer salvajes)")
	_check(not _battle.can_start(wild), "no se empieza otro combate mientras hay uno")

	# 2. Huir: tu Pokémon sale del círculo.
	_main.companion.global_position = _battle.center + Vector3(BattleManager.ARENA_RADIUS + 4.0, 0.5, 0)
	await _frames(5)
	_check(not _battle.active and _results.has("flee"), "salir del círculo debe terminar el combate huyendo")
	_check(is_instance_valid(wild) and not _battle.can_start(wild), "el salvaje del que huiste te ignora un rato")
	if is_instance_valid(wild):
		wild.queue_free()
	await _frames(5)

	# 3. Ganar: el rival queda debilitado.
	var streak_before := BattleManager.streak()
	var entry: Dictionary = GameState.party[GameState.companion_index]
	var bond_before := float(entry.get("bond_xp", 0.0))
	_main.companion.global_position = arena + Vector3(1.5, 0.5, 4)
	var rival := _spawner.spawn_species(_species("patrat"), arena + Vector3(0, 0, -4), false, false)
	await _frames(2)
	_check(_battle.start(rival), "debe empezar un segundo combate")
	await _frames(5)
	var battles_before := int(GameState.dex_entry("patrat").get("battles", 0))
	rival.receive_hit(rival.hp + 100.0, _main.companion)
	await _frames(10)
	_check(_results.has("win"), "debilitar al rival debe ganar el combate")
	_check(BattleManager.streak() == streak_before + 1, "la racha de victorias sube (%d -> %d)" % [streak_before, BattleManager.streak()])
	_check(int(GameState.dex_entry("patrat").get("battles", 0)) == battles_before + 1, "la investigación cuenta la victoria")
	_check(float(GameState.party[GameState.companion_index].get("bond_xp", 0.0)) >= bond_before + 3.0, "el vínculo sube al ganar")
	_check(_main.companion.battle_center == Vector3.INF, "al terminar, tu Pokémon queda libre de la arena")
	_clear_wild()
	await _frames(5)

	# 4. Cambiar de Pokémon (con espera) y megaevolucionar.
	_main.companion.global_position = arena + Vector3(1.5, 0.5, 4)
	var third := _spawner.spawn_species(_species("lillipup"), arena + Vector3(0, 0, -4), false, false)
	await _frames(2)
	_check(_battle.start(third), "debe empezar un tercer combate")
	await _frames(5)
	_check(_battle.switch_to(lucario_index), "cambiar a Lucario dentro del combate")
	await _frames(5)
	_check(_main.companion.species.identifier == "lucario", "el compañero ahora es Lucario")
	_check(not _battle.switch_ready(), "tras cambiar hay espera")
	_check(_battle.available_mega() == null, "sin Piedra Llave no hay mega")
	GameState.add_item("key-stone", 1)
	GameState.add_item("stone-lucario-mega", 1)
	_check(_battle.available_mega() != null, "con Piedra Llave y Lucarita sí hay mega")
	await _battle.try_mega()
	await _frames(5)
	_check(_main.companion.mega != null, "Lucario megaevolucionó")
	_check(_battle.available_mega() == null, "solo una mega por combate")
	_battle.finish("flee")
	await _frames(5)
	_check(_main.companion.mega == null, "al terminar el combate vuelve a su forma normal")

	# 5. Perder la racha al desmayarte.
	BattleManager.reset_streak()
	_check(BattleManager.streak() == 0, "la racha se reinicia")


func _species(identifier: String) -> SpeciesData:
	return load("res://creatures/data/species/%s.tres" % identifier) as SpeciesData


## Un claro cerca del inicio (igual que test_fights).
func _find_clearing() -> Vector3:
	var o := _world.start_position()
	var trees := get_tree().get_nodes_in_group(WorldBuilder.TREES_GROUP)
	for ring in range(4, 20):
		for k in 24:
			var angle := TAU * k / 24.0
			var x := o.x + cos(angle) * ring * 12.0
			var z := o.z + sin(angle) * ring * 12.0
			var p := Vector3(x, _world.surface_height_at(x, z), z)
			if not _world.is_near_loaded(p) or not _world._dry_land(x, z, 16.0) or not _world.settlement_at(x, z, 20.0).is_empty():
				continue
			if _world.distance_to_paths(x, z) < 8.0 or not _world.structures.place_at(x, z, 30.0).is_empty():
				continue
			var flat := true
			for j in 8:
				var a := TAU * j / 8.0
				if absf(_world.surface_height_at(x + cos(a) * 14.0, z + sin(a) * 14.0) - p.y) > 1.2:
					flat = false
			if not flat or trees.any(func(t: Node3D) -> bool: return t.global_position.distance_to(p) < 16.0):
				continue
			return p
	return o


func _clear_wild() -> void:
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		node.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
