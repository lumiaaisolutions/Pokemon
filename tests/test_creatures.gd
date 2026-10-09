extends Node
## Prueba de la Fase 2 sobre world/main.tscn: navegación, compañero, spawner e IA.
## Uso: godot --headless --path . tests/test_creatures.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")
const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")
const POOL := preload("res://creatures/data/basic_pool.tres")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _biome: BiomeBuilder
var _spawner: WildSpawner


func _ready() -> void:
	_main = MAIN_SCENE.instantiate() as Node3D
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_biome = _main.get_node("Pradera") as BiomeBuilder
	_spawner = _main.get_node("Spawner") as WildSpawner
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_creatures: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	var navigation := _main.get_node("Navigation") as WorldNavigation
	var waited := 0
	while not navigation.is_baked and waited < 1200:
		await get_tree().physics_frame
		waited += 1
	_check(navigation.is_baked, "la navegación no terminó de hornearse en 20 s")
	_check(navigation.navigation_mesh.get_polygon_count() > 100, "la malla de navegación está casi vacía")
	await _frames(10)

	# Compañero: un básico del grupo que sigue al jugador.
	var companion: PokemonActor = _main.companion
	_check(companion != null and POOL.species.has(companion.species), "el compañero debe ser un básico del grupo de iniciales")
	Input.action_press("move_forward")
	await _frames(180)
	Input.action_release("move_forward")
	await _frames(180)
	var gap := companion.global_position.distance_to(_player.global_position)
	print("  compañero %s a %.1f m del jugador tras recorrer %.1f m" % [companion.species.display_name, gap, _player.global_position.length()])
	_check(gap < 4.5, "el compañero debe seguir al jugador (quedó a %.1f m)" % gap)

	# Spawner: los salvajes aparecen dentro de la hierba alta.
	_spawner.set_process(false)
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		node.queue_free()
	await _frames(2)
	var in_grass := 0
	for i in 8:
		var actor := _spawner.spawn_one()
		if actor != null and _biome.is_in_tall_grass(actor.position):
			in_grass += 1
	_check(in_grass == 8, "los salvajes deben aparecer dentro de la hierba alta (%d de 8)" % in_grass)
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		node.queue_free()
	await _frames(2)

	# IA por temperamento, con el jugador quieto en un claro.
	_player.global_position = Vector3(0, _biome.surface_height_at(0, 0) + 0.5, 0)
	await _frames(20)
	await _check_temperament("absol", 7.0, "agresivo", func(start: float, end: float, contact: bool) -> bool: return contact)
	await _check_temperament("pidgeot", 6.0, "tímido", func(start: float, end: float, contact: bool) -> bool: return end > start + 4.0)
	await _check_temperament("ampharos", 7.0, "curioso", func(start: float, end: float, contact: bool) -> bool: return end < start - 2.0 and end > PokemonActor.CONTACT_RADIUS)
	await _check_temperament("venusaur", 7.0, "deambula", func(start: float, end: float, contact: bool) -> bool: return not contact and end > 3.0)


## Coloca un salvaje a distance m del jugador, espera 3 s y evalúa el criterio.
func _check_temperament(identifier: String, distance: float, label: String, passes: Callable) -> void:
	var actor := ACTOR_SCENE.instantiate() as PokemonActor
	actor.species = load("res://creatures/data/species/%s.tres" % identifier)
	actor.role = PokemonActor.Role.WILD
	actor.player = _player
	var x := distance
	actor.position = Vector3(x, _biome.surface_height_at(x, 0) + 0.3, 0)
	var contacted := [false]
	actor.contact_with_player.connect(func(_a: PokemonActor) -> void: contacted[0] = true)
	_main.add_child(actor)
	await _frames(5)
	var start := actor.global_position.distance_to(_player.global_position)
	await _frames(180)
	var end := actor.global_position.distance_to(_player.global_position)
	print("  %s (%s): %.1f m -> %.1f m, contacto=%s" % [label, identifier, start, end, contacted[0]])
	_check(passes.call(start, end, contacted[0]), "temperamento %s (%s): de %.1f m a %.1f m, contacto=%s" % [label, identifier, start, end, contacted[0]])
	actor.queue_free()
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
