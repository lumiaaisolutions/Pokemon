extends Node
## Prueba de las Fases 2 y 2.5 sobre world/main.tscn: navegación, compañero, aparición
## por hábitat, temperamentos, persecución con área, territorio, shiny, tamaños y legendarios.
## Uso: godot --headless --path . tests/test_creatures.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")
const POOL := preload("res://creatures/data/basic_pool.tres")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder
var _spawner: WildSpawner


func _ready() -> void:
	_main = MAIN_SCENE.instantiate() as Node3D
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_world = _main.get_node("World") as WorldBuilder
	_spawner = _main.get_node("Spawner") as WildSpawner
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_creatures: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	var navigation := _main.get_node("Navigation") as WorldNavigation
	var waited := 0
	while not navigation.is_baked and waited < 1800:
		await get_tree().physics_frame
		waited += 1
	_check(navigation.is_baked, "la navegación no terminó de hornearse en 30 s")
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
	print("  compañero %s a %.1f m del jugador" % [companion.species.display_name, gap])
	_check(gap < 4.5, "el compañero debe seguir al jugador (quedó a %.1f m)" % gap)

	# Aparición por hábitat: 60 intentos repartidos por el mundo.
	_spawner.set_process(false)
	(_main.get_node("Legendaries") as LegendaryManager).set_process(false)
	_clear_wild()
	var checked := 0
	var spots: Array[Vector3] = [Vector3(0, 0, -20), Vector3(-150, 0, 20), Vector3(20, 0, -150), Vector3(70, 0, 40), Vector3(-165, 0, 95), Vector3(100, 0, 150)]
	for spot in spots:
		_player.global_position = Vector3(spot.x, _world.surface_height_at(spot.x, spot.z) + 0.5, spot.z)
		for i in 10:
			var actor := _spawner.spawn_one()
			if actor == null:
				continue
			checked += 1
			_check_habitat_rules(actor)
	print("  apariciones revisadas: %d" % checked)
	_check(checked >= 20, "muy pocas apariciones en 60 intentos (%d)" % checked)
	_clear_wild()
	await _frames(2)

	# Tamaños por altura y shiny.
	var wailord := _spawner.spawn_species(_species("wailord"), Vector3(0, 0, 0), false, false)
	var joltik := _spawner.spawn_species(_species("joltik"), Vector3(0, 0, 0), true, false)
	await _frames(2)
	_check(is_equal_approx((wailord.get_node("Sprite") as Sprite3D).pixel_size, PokemonActor.PIXEL_SIZE * 3.0), "Wailord debe dibujarse ×3")
	_check(is_equal_approx((joltik.get_node("Sprite") as Sprite3D).pixel_size, PokemonActor.PIXEL_SIZE), "Joltik debe dibujarse ×1")
	_check((joltik.get_node("Sprite") as Sprite3D).texture == _species("joltik").overworld_sheet_shiny, "un shiny debe usar su hoja variocolor")
	_check(joltik.has_node("ShinySparkles"), "un shiny debe tener destello")
	_check(is_equal_approx(WildSpawner.SHINY_CHANCE, 0.02), "la probabilidad de shiny debe ser 2 %")
	_clear_wild()
	await _frames(2)

	# Temperamentos con el jugador quieto en un claro.
	_player.global_position = Vector3(0, _world.surface_height_at(0, 0) + 0.5, 0)
	await _frames(20)
	await _check_temperament("absol", 7.0, "agresivo", func(start: float, end: float, contact: bool) -> bool: return contact)
	await _check_temperament("pidgeot", 6.0, "tímido", func(start: float, end: float, contact: bool) -> bool: return end > start + 4.0)
	await _check_temperament("ampharos", 7.0, "curioso", func(start: float, end: float, contact: bool) -> bool: return end < start - 2.0 and end > PokemonActor.CONTACT_RADIUS)
	await _check_temperament("venusaur", 7.0, "deambula", func(start: float, end: float, contact: bool) -> bool: return not contact and end > 3.0)
	await _check_temperament("aggron", 12.0, "territorial fuera de su zona", func(start: float, end: float, contact: bool) -> bool: return not contact and end > 8.0)

	# Persecución con área: si el jugador sale del área, el perseguidor se rinde.
	var chaser := _spawner.spawn_species(_species("absol"), _ground(6.0, 0.0), false, false)
	await _frames(30)
	_check(chaser.state == PokemonActor.State.CHASE, "el agresivo debe empezar a perseguir")
	_check((chaser.get_node("ChaseRing") as Decal).visible, "al perseguir se muestra el área en el suelo")
	var leash := chaser.chase_leash()
	_check(leash >= 12.0 and leash <= 35.0, "el área de persecución debe estar entre 12 y 35 m (%.1f)" % leash)
	_player.global_position = chaser.chase_origin + Vector3(0, 0, -(leash + 6.0))
	_player.global_position.y = _world.surface_height_at(_player.global_position.x, _player.global_position.z) + 0.5
	await _frames(10)
	_check(chaser.state == PokemonActor.State.RETURN, "fuera del área debe rendirse y regresar (estado %d)" % chaser.state)
	_clear_wild()
	await _frames(2)

	# Territorial: entra a su zona y lo persigue.
	_player.global_position = Vector3(0, _world.surface_height_at(0, 0) + 0.5, 0)
	var guard := _spawner.spawn_species(_species("aggron"), _ground(4.0, 0.0), false, false)
	await _frames(30)
	_check(guard.state == PokemonActor.State.CHASE, "el territorial debe perseguir si el jugador entra a su zona")
	_clear_wild()
	await _frames(2)

	# Legendarios: uno solo por lugar, y uno capturado no reaparece sin la tirada.
	var legendaries := _main.get_node("Legendaries") as LegendaryManager
	_check(legendaries.spots.size() >= 90, "todos los legendarios deben tener lugar (%d)" % legendaries.spots.size())
	var spot: Vector3 = legendaries.spots["groudon"]
	_player.global_position = spot + Vector3(30, 1, 0)
	legendaries.set_process(true)
	await _frames(5)
	var groudons := get_tree().get_nodes_in_group(LegendaryManager.LEGENDARY_GROUP).filter(func(a: PokemonActor) -> bool: return a.species.identifier == "groudon")
	_check(groudons.size() == 1, "debe haber exactamente un Groudon (%d)" % groudons.size())
	await _frames(5)
	_check(get_tree().get_nodes_in_group(LegendaryManager.LEGENDARY_GROUP).filter(func(a: PokemonActor) -> bool: return a.species.identifier == "groudon").size() == 1, "no debe duplicarse")
	GameState.mark_legendary_caught("groudon")
	_check(not GameState.is_legendary_available("groudon"), "un legendario capturado no reaparece sin la tirada del 2 %")


func _check_habitat_rules(actor: PokemonActor) -> void:
	var p := actor.global_position
	var species := actor.species
	var habitat := _world.habitat_at(p.x, p.z)
	var is_water_type := species.types.has(PokemonTypes.Type.WATER)
	_check(species.habitats.has(habitat), "%s apareció fuera de su hábitat (%d en %s)" % [species.display_name, habitat, p])
	_check(species.spawn_weight > 0.0, "%s no debería aparecer (peso 0)" % species.display_name)
	if actor.swimming:
		_check(species.swims and _world.water_depth_at(p.x, p.z) > 0.6, "%s nada fuera del agua" % species.display_name)
	elif is_water_type:
		_check(_world.water_depth_at(p.x, p.z) < 0.0, "%s (Agua) apareció dentro del agua sin nadar" % species.display_name)
	else:
		_check(_world.is_in_tall_grass(p), "%s apareció fuera de la hierba alta" % species.display_name)


## Coloca un salvaje a distance m del jugador, espera 3 s y evalúa el criterio.
func _check_temperament(identifier: String, distance: float, label: String, passes: Callable) -> void:
	var actor := _spawner.spawn_species(_species(identifier), _ground(distance, 0.0), false, false)
	var contacted := [false]
	actor.contact_with_player.connect(func(_a: PokemonActor) -> void: contacted[0] = true)
	await _frames(5)
	var start := actor.global_position.distance_to(_player.global_position)
	await _frames(180)
	var end := actor.global_position.distance_to(_player.global_position)
	print("  %s (%s): %.1f m -> %.1f m, contacto=%s" % [label, identifier, start, end, contacted[0]])
	_check(passes.call(start, end, contacted[0]), "temperamento %s (%s): de %.1f m a %.1f m, contacto=%s" % [label, identifier, start, end, contacted[0]])
	actor.queue_free()
	await _frames(2)


func _species(identifier: String) -> SpeciesData:
	return load("res://creatures/data/species/%s.tres" % identifier) as SpeciesData


## Punto en el suelo a (dx, dz) del jugador.
func _ground(dx: float, dz: float) -> Vector3:
	var x := _player.global_position.x + dx
	var z := _player.global_position.z + dz
	return Vector3(x, _world.surface_height_at(x, z), z)


func _clear_wild() -> void:
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		node.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
