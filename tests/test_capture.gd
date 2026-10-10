extends Node
## Prueba de la captura en el mundo (Fase 2.8, bloque 6): fórmula, apuntar, lanzar,
## captura exitosa y fallida, y legendarios.
## Uso: godot --headless --path . tests/test_capture.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

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
	print("test_capture: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	# Fórmula.
	var bidoof := _species("bidoof")
	var full := CaptureRules.probability(bidoof, 1.0, CaptureRules.POKEBALL, false, false)
	var hurt := CaptureRules.probability(bidoof, 0.2, CaptureRules.POKEBALL, false, false)
	var stunned := CaptureRules.probability(bidoof, 0.0, CaptureRules.POKEBALL, true, false)
	var sneaky := CaptureRules.probability(bidoof, 1.0, CaptureRules.POKEBALL, false, true)
	var mewtwo := CaptureRules.probability(_species("mewtwo"), 1.0, CaptureRules.POKEBALL, false, false)
	print("  probabilidades: Bidoof sano %.2f, herido %.2f, aturdido %.2f, por sorpresa %.2f; Mewtwo sano %.3f" % [full, hurt, stunned, sneaky, mewtwo])
	_check(hurt > full, "con menos vida debe ser más fácil")
	_check(stunned > hurt, "aturdido debe ser más fácil")
	_check(sneaky > full, "por sorpresa debe ser más fácil")
	_check(mewtwo < 0.02, "un legendario sano debe ser muy difícil (%.3f)" % mewtwo)

	var navigation := _main.get_node("Navigation") as WorldNavigation
	while not navigation.is_baked:
		await get_tree().physics_frame
	_spawner.set_process(false)
	(_main.get_node("Legendaries") as Node).set_process(false)
	(_main.get_node("Ambushes") as Node).set_process(false)
	(_main.companion as Node).process_mode = Node.PROCESS_MODE_DISABLED
	_clear_wild()
	await _frames(10)

	# Apuntar: la cámara pasa al hombro y aparece el arco.
	var rig := _main.get_node("CameraRig") as CameraRig
	var arm := rig.get_node("Pitch/SpringArm") as SpringArm3D
	var normal_length := arm.spring_length
	Input.action_press("aim")
	await _frames(40)
	_check(rig.aiming and arm.spring_length < normal_length - 1.0, "al apuntar la cámara debe acercarse al hombro")
	var aim := _player.get_node("ThrowAim") as ThrowAim
	_check(aim.get_children().any(func(d: Node) -> bool: return (d as Sprite3D).visible), "al apuntar debe verse el arco de la trayectoria")
	# Lanzar: descuenta una ball y la ball vuela y cae al suelo sin atravesarlo.
	var balls_before := GameState.pokeballs
	var ball := aim.throw_ball()
	Input.action_release("aim")
	_check(ball != null and GameState.pokeballs == balls_before - 1, "lanzar debe descontar una Pokéball")
	var lowest_gap := INF
	for i in 90:
		await get_tree().physics_frame
		if not is_instance_valid(ball):
			break
		lowest_gap = minf(lowest_gap, ball.global_position.y - _world.surface_height_at(ball.global_position.x, ball.global_position.z))
	_check(lowest_gap > -0.3, "la Pokéball no debe atravesar el suelo (%.2f)" % lowest_gap)
	await _frames(240)

	# Captura exitosa: la ball toca al Pokémon, 3 sacudidas y entra al equipo.
	var party_before := GameState.party.size()
	var target := _spawner.spawn_species(bidoof, _ground(6.0), false, false)
	await _frames(5)
	var caught := [""]
	var handler := func(name: String, _shiny: bool, _location: String) -> void: caught[0] = name
	GameState.pokemon_caught.connect(handler)
	var hit_ball := _throw_at(target, 1)
	await _frames(int((CaptureRules.SHAKES * PokeballProjectile.SHAKE_TIME + 1.5) * 60))
	_check(caught[0] == bidoof.display_name, "debe avisar la captura de Bidoof")
	_check(GameState.party.size() == party_before + 1, "el capturado debe entrar al equipo")
	_check(not is_instance_valid(target), "el capturado sale del mundo")
	GameState.pokemon_caught.disconnect(handler)

	# Captura fallida: sale de la ball; el agresivo se enoja con Nate.
	var absol := _spawner.spawn_species(_species("absol"), _ground(7.0), false, false)
	absol.set_physics_process(false)
	await _frames(5)
	absol.set_physics_process(true)
	_throw_at(absol, 0)
	await _frames(int((PokeballProjectile.SHAKE_TIME + 1.5) * 60))
	_check(is_instance_valid(absol) and absol.visible, "si falla, el Pokémon debe salir de la ball")
	_check(is_instance_valid(absol) and absol.state in [PokemonActor.State.FIGHT, PokemonActor.State.CHASE], "el agresivo debe enojarse tras escapar (estado %d)" % (absol.state if is_instance_valid(absol) else -1))
	_clear_wild()
	await _frames(5)

	# Legendario: al capturarlo queda marcado y no reaparece sin la tirada.
	var legend := _spawner.spawn_species(_species("raikou"), _ground(8.0), false, false, true)
	await _frames(5)
	_throw_at(legend, 1)
	await _frames(int((CaptureRules.SHAKES * PokeballProjectile.SHAKE_TIME + 1.5) * 60))
	_check(GameState.legendary_caught.get("raikou", false), "capturar a Raikou debe marcarlo como capturado")

	# Mapa: se descubre al explorar y el mapa completo pausa el juego.
	var map_ui := _main.get_node("MapUi") as MapUi
	var explored_before := map_ui.data.explored_ratio()
	_player.global_position = Vector3(-120, _world.surface_height_at(-120, 30) + 0.5, 30)
	await _frames(60)
	_check(map_ui.data.explored_ratio() > explored_before, "explorar una zona nueva debe descubrirla en el mapa")
	map_ui.toggle_full_map()
	_check(get_tree().paused and (map_ui.get_node("Full") as Control).visible, "el mapa completo debe abrirse y pausar el juego")
	map_ui.toggle_full_map()
	_check(not get_tree().paused, "al cerrar el mapa el juego sigue")


## Lanza una ball directo al Pokémon con resultado forzado (1 captura, 0 falla).
func _throw_at(target: PokemonActor, result: int) -> PokeballProjectile:
	var ball := PokeballProjectile.create()
	ball.thrower = _player
	ball.forced_result = result
	_main.add_child(ball)
	var from := _player.global_position + Vector3.UP * 1.4
	ball.global_position = from
	var to := target.global_position + Vector3.UP * 0.5
	var flight := 0.5
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	ball.linear_velocity = (to - from) / flight + Vector3.UP * 0.5 * gravity * flight
	return ball


func _species(identifier: String) -> SpeciesData:
	return load("res://creatures/data/species/%s.tres" % identifier) as SpeciesData


## Punto en el suelo a distance m frente al jugador (hacia -Z).
func _ground(distance: float) -> Vector3:
	var x := _player.global_position.x
	var z := _player.global_position.z - distance
	return Vector3(x, _world.surface_height_at(x, z), z)


func _clear_wild() -> void:
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP) + get_tree().get_nodes_in_group(LegendaryManager.LEGENDARY_GROUP):
		node.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
