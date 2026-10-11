extends Node
## Prueba de las rocas rompibles (fase 5.8, decisiones de Fernando 2026-10-10): hay rocas
## pequeñas en el campo; el compañero las rompe atacándolas (teclas 1-4), sueltan un
## premio y vuelven a los 3 días; las grandes solo las rompe un compañero de tipo Lucha,
## Roca, Tierra o Acero (o que sepa Golpe Roca) y quedan rotas para siempre; una boca de
## cada par de cuevas está tapada y se abre al romper su roca.
## Uso: godot --headless --path . tests/test_rocks.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")
const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder
var _rocks: BreakableRocks


func _ready() -> void:
	BattleManager.enabled = false
	GameState.party = [{"species": "bidoof", "shiny": false, "hp_ratio": 1.0}]
	GameState.companion_index = 0
	GameState.world_flags = {}
	_main = MAIN_SCENE.instantiate() as Node3D
	_main.set("starter_ceremony", false)
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_world = _main.get_node("World") as WorldBuilder
	_rocks = _main.get_node("BreakableRocks") as BreakableRocks
	var navigation := _main.get_node("Navigation") as WorldNavigation
	while not navigation.is_baked:
		await get_tree().physics_frame
	for node_name in ["Spawner", "Legendaries", "Ambushes", "Events", "Migrations"]:
		(_main.get_node(node_name) as Node).set_process(false)
	await _frames(10)
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_rocks: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	# 1. Hay rocas pequeñas en las zonas cargadas, en 3D y con colisión.
	var small: Array = get_tree().get_nodes_in_group(BreakableRock.GROUP).filter(func(r: BreakableRock) -> bool: return not r.big and not r.is_broken())
	_check(small.size() >= 3, "hay rocas pequeñas en el campo (%d)" % small.size())
	if small.is_empty():
		return
	var rock: BreakableRock = small[0]
	_check(rock.get_node_or_null("Mesh") is MeshInstance3D, "la roca es un modelo 3D")
	_check(rock.collision_layer & WorldBuilder.LAYER_OBSTACLES != 0, "la roca es sólida")

	# 2. El compañero la rompe con un ataque (tecla de movimiento) y da premio.
	var companion: PokemonActor = _main.companion
	_check(companion != null, "hay compañero")
	if companion == null:
		return
	var slot := -1
	for i in companion.moves.size():
		if Moves.effect(companion.moves[i]) == "damage":
			slot = i
			break
	_check(slot >= 0, "el compañero tiene un ataque que golpea")
	_player.global_position = rock.global_position + Vector3(3, 0.5, 0)
	companion.global_position = rock.global_position + Vector3(4, 0.5, 0)
	await _frames(5)
	var bag_before := _bag_total()
	var wild_before := get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP).size()
	var message := companion.command_move(slot, Moves.Style.NORMAL) if slot >= 0 else "sin ataque"
	_check(message == "", "la orden de ataque va contra la roca (%s)" % message)
	for i in 120:
		await get_tree().process_frame
		if rock.is_broken():
			break
	_check(rock.is_broken(), "el ataque del compañero rompe la roca pequeña")
	await _frames(5)
	var flags: Dictionary = GameState.world_flags.get("rocks", {})
	_check(int(flags.get(rock.rock_id, -1)) == GameState.game_day(), "se recuerda el día en que se rompió")

	# 3. Premios: en 200 rocas salen todos los tipos con la mezcla equilibrada.
	var counts := {}
	for i in 200:
		var kind := _rocks.reward(rock.global_position)
		counts[kind] = int(counts.get(kind, 0)) + 1
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		node.queue_free()
	_check(int(counts.get("mineral", 0)) > 80 and int(counts.get("mineral", 0)) < 140, "los minerales son el premio más común (%s)" % str(counts))
	_check(counts.has("pokemon") and counts.has("stone") and counts.has("nothing"), "también salen Pokémon escondidos, piedras y a veces nada (%s)" % str(counts))

	# 4. Reaparece a los 3 días (no antes).
	GameState.play_time += GameState.DAY_SECONDS * 2.0
	_rocks._check = 0.0
	for i in 3:
		await get_tree().process_frame
	_check(rock.is_broken(), "a los 2 días sigue rota")
	GameState.play_time += GameState.DAY_SECONDS * 1.1
	_rocks._check = 0.0
	for i in 3:
		await get_tree().process_frame
	_check(not rock.is_broken(), "a los 3 días vuelve a su lugar")

	# 5. Rocas grandes: solo un compañero fuerte (tipo o Golpe Roca).
	var weak := _actor("bidoof")
	var strong := _actor("machop")
	var smasher := _actor("bidoof")
	smasher.moves.assign(["rock-smash"])
	_check(not BreakableRock.strong_enough(weak), "un Bidoof sin Golpe Roca no rompe rocas grandes")
	_check(BreakableRock.strong_enough(strong), "un Machop (Lucha) sí")
	_check(BreakableRock.strong_enough(smasher), "uno que sabe Golpe Roca también")
	var boulder := BreakableRock.create(_main, _player.global_position + Vector3(0, 0, -6), "prueba:roca", true)
	boulder.take_move_hit(weak, "tackle")
	_check(not boulder.is_broken(), "el golpe de un compañero débil no rompe la roca grande")
	boulder.take_move_hit(strong, "karate-chop")
	_check(boulder.is_broken() and BreakableRock.boulder_broken("prueba:roca"), "el de Lucha la rompe y queda rota para siempre")
	for actor in [weak, strong, smasher]:
		actor.free()

	# 6. Cuevas en par: una boca de cada par está tapada.
	var caves: Array = _world.layout.places.filter(func(p: Dictionary) -> bool: return p["kind"] == "cave")
	if caves.size() >= 2:
		var blocked := caves.filter(func(p: Dictionary) -> bool: return bool(p.get("blocked", false)))
		_check(blocked.size() == caves.size() / 2, "una boca de cada par de cuevas está tapada (%d de %d)" % [blocked.size(), caves.size()])
	# Cuevas chicas: la mitad tapadas (por su id).
	var blocking := 0
	for i in 40:
		if PointsOfInterest.is_blocking_cave({"kind": "small_cave", "id": "%d_%d" % [i, i * 3]}):
			blocking += 1
	_check(blocking > 8 and blocking < 32, "más o menos la mitad de las cuevas chicas están tapadas (%d/40)" % blocking)


func _actor(id: String) -> PokemonActor:
	var actor := ACTOR_SCENE.instantiate() as PokemonActor
	actor.species = MenuStyle.species(id)
	return actor


func _bag_total() -> int:
	var total := 0
	for id: String in GameState.bag:
		total += int(GameState.bag[id])
	return total


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
