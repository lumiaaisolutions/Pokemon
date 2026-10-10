extends Node
## Prueba de la fase del mundo grande: pueblos y estructuras con interacción, interiores
## (Centro Pokémon, Tienda, mazmorras y cuevas por pares), tienda y MT, gimnasio,
## guardería, lugares que curan, clima y estaciones, eventos del mundo, bicicleta,
## montura y vuelo, opciones nuevas y el mapa de la región.
## Uso: godot --headless --path . tests/test_town.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder
var _services: TownServices


func _ready() -> void:
	GameState.party.clear()
	GameState.box.clear()
	GameState.bag = Items.starting_bag()
	GameState.world_flags = {}
	GameState.money = 50000
	_main = MAIN_SCENE.instantiate() as Node3D
	_main.set("starter_ceremony", false)
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_world = _main.get_node("World") as WorldBuilder
	_services = _world.structures.services
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_town: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	var navigation := _main.get_node("Navigation") as WorldNavigation
	while not navigation.is_baked:
		await get_tree().physics_frame
	for node_name in ["Spawner", "Legendaries", "Ambushes", "Events"]:
		(_main.get_node(node_name) as Node).set_process(false)
	await _frames(10)
	var start := _world.start_position()

	# Pueblo inicial: Centro Pokémon con su puerta interactiva y el nombre del lugar.
	var hud := _main.get_node("Hud") as Hud
	await _frames(40)
	_check(hud.location_text() == _world.layout.settlements[0]["name"], "el HUD debe mostrar el nombre del pueblo (%s)" % hud.location_text())
	var center: Dictionary = _world.structures.nearest_building("center", start)
	_check(not center.is_empty(), "el pueblo inicial debe tener Centro Pokémon")
	var door := _door_point("Entrar: Centro Pokémon")
	_check(door != Vector3.INF, "el Centro Pokémon debe tener puerta interactiva")

	# Entrar al Centro: interior lejos del mapa, suelo plano y punto para curar.
	var companion := _main.get("companion") as PokemonActor
	_player.global_position = door
	await _frames(5)
	_check(_world.structures.interact_near(door), "debe poder interactuarse con la puerta")
	await _wait_interior(true)
	var interiors := _services.interiors
	_check(interiors.is_inside() and _player.global_position.x > WorldBuilder.INTERIOR_X, "al entrar debe pasar al interior")
	await _frames(30)
	_check(_player.is_on_floor() and absf(_player.global_position.y) < 0.6, "en el interior debe quedar sobre el piso (y=%.2f)" % _player.global_position.y)
	_check(_has_point("Curar a tu equipo") and _has_point("Usar el PC (Caja)"), "el Centro debe tener mostrador y PC")
	_player.take_damage(4.0)
	if not GameState.party.is_empty():
		GameState.party[0]["hp_ratio"] = 0.3
	_services.heal_everyone()
	_check(is_equal_approx(_player.health, _player.config.health_max) and float(GameState.party[0]["hp_ratio"]) == 1.0, "el Centro cura al jugador y a su equipo")
	_check(hud.location_text().begins_with("Centro Pokémon"), "en el interior el lugar es el Centro (%s)" % hud.location_text())
	interiors.exit_to(interiors.current["return"])
	await _wait_interior(false)
	_check(_player.global_position.distance_to(door) < 2.0, "al salir debe volver a la puerta")
	_check(_world.is_near_loaded(_player.global_position), "afuera las zonas siguen cargadas")

	# Tienda y MT.
	var money := GameState.money
	var balls := GameState.item_count("poke-ball")
	_check(ShopUI.buy("poke-ball", 10) and GameState.item_count("poke-ball") == balls + 10 and GameState.money == money - 2000, "comprar 10 Poké Balls cuesta $2000")
	_check(ShopUI.sell("poke-ball", 2) and GameState.money == money - 2000 + 200, "vender a mitad de precio")
	var tms := ShopUI.stock().filter(func(id: String) -> bool: return id.begins_with("tm-"))
	_check(tms.size() == ShopUI.TM_PER_DAY, "la tienda vende %d MT por día" % ShopUI.TM_PER_DAY)
	var entry: Dictionary = GameState.party[GameState.companion_index]
	Moves.ensure_entry(entry)
	var before: int = (entry["unlocked"] as Array).size()
	var learned := ""
	for type in 18:
		learned = Moves.teach_type(entry, type)
		if learned != "":
			break
	_check(learned != "" and (entry["unlocked"] as Array).size() == before + 1, "una MT desbloquea un movimiento de su tipo")

	# Mazmorra: una cueva con pareja sale en la otra boca.
	var cave := {}
	for place: Dictionary in _world.layout.places_of("cave"):
		if place.has("exit"):
			cave = place
			break
	_check(not cave.is_empty(), "debe haber una cueva con pareja")
	if not cave.is_empty():
		_player.global_position = Vector3(float(cave["x"]), _world.height_at(float(cave["x"]), float(cave["z"])) + 4.0, float(cave["z"]) + 4.0)
		await _frames(5)
		_services.enter_interior("cave", {}, cave)
		await _wait_interior(true)
		_check(interiors.current["kind"] == "cave", "la cueva es una mazmorra")
		_check((interiors.current["actors"] as Array).size() >= 1, "la cueva tiene Pokémon propios")
		_check(_has_point("Salida al otro lado"), "la cueva con pareja tiene salida al otro lado")
		var exit := {}
		for point: Dictionary in interiors.current["points"]:
			if point["prompt"] == "Salida al otro lado":
				exit = point
		(exit["action"] as Callable).call()
		await _wait_interior(false)
		var other := _world.structures.place_by_id(int(cave["exit"]))
		_check(Vector2(_player.global_position.x - float(other["x"]), _player.global_position.z - float(other["z"])).length() < 12.0, "al salir debe quedar en la cueva pareja")

	# Gimnasio: el líder saca Pokémon de su tipo, no se capturan; al vencerlos, medalla.
	var gym_city: Dictionary = {}
	for settlement: Dictionary in _world.layout.settlements:
		if (settlement["buildings"] as Array).any(func(b: Dictionary) -> bool: return b["kind"] == "gym"):
			gym_city = settlement
			break
	_check(not gym_city.is_empty(), "debe haber al menos una ciudad con gimnasio")
	if not gym_city.is_empty():
		var gym: Dictionary = (gym_city["buildings"] as Array).filter(func(b: Dictionary) -> bool: return b["kind"] == "gym")[0]
		_player.global_position = Vector3(float(gym["x"]), float(gym_city["height"]) + 1.0, float(gym["z"]))
		await _frames(5)
		_services.enter_interior("gym", gym_city, gym)
		await _wait_interior(true)
		_check(_has_point("Retar al líder"), "el gimnasio tiene líder")
		_services.gym_challenge(gym_city, Interiors.ORIGIN + Vector3(0, 0.3, -2))
		var type := _world.structures.gym_type(gym_city)
		for round in 3:
			var trainer: PokemonActor = await _trainer_actor()
			_check(trainer != null and trainer.species.types.has(type), "ronda %d: el líder saca un Pokémon de su tipo" % (round + 1))
			if trainer == null:
				break
			trainer.hp = 0.0
			trainer.receive_hit(999.0, _player)
			await _frames(120)
		_check(_services.badges().has(gym_city["name"]) and int(GameState.path_progress.get("gimnasios", 0)) == 1, "al vencer al líder se gana la medalla")
		interiors.exit_to(interiors.current["return"])
		await _wait_interior(false)

	# Guardería: deja un Pokémon y gana puntos por día.
	GameState.party.append({"species": "rattata", "shiny": false, "hp_ratio": 1.0})
	var daycare: Dictionary = _world.layout.places_of("daycare")[0]
	var size_before := GameState.party.size()
	_services.daycare(daycare)
	_check(GameState.party.size() == size_before - 1 and GameState.world_flags.has("daycare"), "la guardería se queda con un Pokémon")
	GameState.play_time += 1440.0 * 2.0
	_services.daycare(daycare)
	var back: Dictionary = GameState.party[-1]
	_check(int(back.get("training_free", 0)) >= 4, "tras 2 días gana Puntos de Entrenamiento (%d)" % int(back.get("training_free", 0)))

	# Lugar que cura (aguas termales o fuente).
	var spot: Dictionary = _services.healing_spots()[0]
	_player.global_position = spot["pos"] + Vector3.UP * 0.5
	await _frames(5)
	_player.respawn_at(spot["pos"] + Vector3.UP * 0.5)
	_player.take_damage(6.0)
	var hurt := _player.health
	await _frames(60)
	_check(_player.health > hurt, "en %s se recupera vida" % spot["title"])

	# Clima por bioma y estaciones.
	var a := Weather.weather_for(RegionLayout.Biome.DESERT, 1000.0, 7)
	_check(a == Weather.weather_for(RegionLayout.Biome.DESERT, 1000.0, 7), "el clima es determinista por semilla y hora")
	var kinds := {}
	for slot in 300:
		kinds[Weather.weather_for(RegionLayout.Biome.TUNDRA, slot * 120.0 + 30.0 * 1440.0, 7)] = true
	_check(kinds.has(Weather.Kind.SNOW) and not kinds.has(Weather.Kind.SAND), "en la tundra nieva y no hay tormentas de arena")
	_check(Weather.season_name(0) == "Primavera" and Weather.season_name(21) == "Invierno", "estaciones de 7 días")
	var weather := _main.get_node("Weather") as Weather
	Weather.current = Weather.Kind.RAIN
	_check(weather.type_factor([PokemonTypes.Type.WATER]) > 2.0 and weather.type_factor([PokemonTypes.Type.FIRE]) < 1.0, "con lluvia salen más Agua y menos Fuego")

	# Eventos: brote masivo.
	var events := _main.get_node("Events") as WorldEvents
	var spawner := _main.get_node("Spawner") as WildSpawner
	var outbreak_point := _world.start_position() + Vector3(60, 0, 0)
	events.start_outbreak(_species("bidoof"), outbreak_point)
	var hits := 0
	for i in 40:
		var picked := spawner.special_pick(outbreak_point + Vector3(10, 0, 0))
		if picked != null and picked.identifier == "bidoof":
			hits += 1
	_check(hits > 15, "en un brote masivo sale mucho esa especie (%d/40)" % hits)
	_check(events.outbreak_species_at(outbreak_point + Vector3(500, 0, 0)) == null, "fuera del brote no aplica")

	# Bicicleta, montura y vuelo.
	_player.respawn_at(_world.start_position() + Vector3.UP * 0.5)
	await _frames(20)
	GameState.add_item("bicycle", 1)
	(_main.get("companion") as PokemonActor).process_mode = Node.PROCESS_MODE_DISABLED
	_main.set("companion_state", 1)
	var bike_message: String = _main.call("toggle_ride")
	_check(bike_message == "¡Vas en bicicleta!" and _player.ride == Player.Ride.BIKE, "con bicicleta se monta en ella (%s, modo %d)" % [bike_message, _player.mode])
	Input.action_press("move_back")
	await _frames(60)
	var bike_speed := _player.get_ground_speed()
	Input.action_release("move_back")
	_check(bike_speed > _player.config.run_speed + 1.0, "en bicicleta va más rápido que corriendo (%.1f m/s)" % bike_speed)
	_main.call("toggle_ride")
	_check(_player.ride == Player.Ride.NONE, "se baja de la bicicleta")
	var old := _main.get("companion") as PokemonActor
	old.queue_free()
	_main.call("_create_companion", _species("charizard"), false, _player.global_position + Vector3(1.5, 0.3, 0.0))
	var flyer := _main.get("companion") as PokemonActor
	await _frames(10)
	_main.call("toggle_ride")
	_check(_player.ride == Player.Ride.MOUNT and flyer.ridden_by == _player, "monta a Charizard")
	await _frames(10)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(2)
	_check(_player.ride == Player.Ride.FLY, "al saltar montado en un volador, despega")
	var ground_y := _player.global_position.y
	Input.action_press("jump")
	await _frames(120)
	Input.action_release("jump")
	_check(_player.global_position.y > ground_y + 8.0, "volando sube al mantener saltar (%.1f m)" % (_player.global_position.y - ground_y))
	_check(_main.call("toggle_ride").begins_with("Baja primero"), "en lo alto no se puede bajar")
	Input.action_press("dive")
	for i in 600:
		await get_tree().physics_frame
		if _player.ride == Player.Ride.MOUNT:
			break
	Input.action_release("dive")
	_check(_player.ride == Player.Ride.MOUNT, "al bajar hasta el suelo aterriza montado")
	_main.call("toggle_ride")
	_check(_player.ride == Player.Ride.NONE and flyer.ridden_by == null, "se baja del compañero")

	# Opciones nuevas.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	GameOptions.remap("jump", key)
	_check(InputMap.action_has_event("jump", key), "reasignar un botón cambia el Input Map")
	GameOptions.reset_remaps()
	_check(not InputMap.action_has_event("jump", key), "restablecer devuelve los botones originales")
	var filter := ColorFilter.ensure(get_tree().root)
	await _frames(2)
	filter.set_mode(2)
	_check(filter.get_mode() == 2, "el filtro de daltonismo cambia de modo")
	filter.set_mode(0)
	_check(GameOptions.notice_seconds("hola") > 1.0, "la duración del aviso depende de la velocidad del texto")

	# Mapa de la región.
	var map_ui := _main.get_node("MapUi") as MapUi
	map_ui.data.wait()
	_check(map_ui.data.is_ready and map_ui.data.map_texture.get_width() == 512, "el mapa de la región es de 512 px (8 m/px)")


func _door_point(prompt: String) -> Vector3:
	var best := Vector3.INF
	var start := _world.start_position()
	for point: Dictionary in _world.structures.points():
		if point["prompt"] == prompt and (best == Vector3.INF or (point["pos"] as Vector3).distance_to(start) < best.distance_to(start)):
			best = point["pos"]
	return best


func _has_point(prefix: String) -> bool:
	for point: Dictionary in _world.structures.points():
		if (point["prompt"] as String).begins_with(prefix) and (point["pos"] as Vector3).x > WorldBuilder.INTERIOR_X:
			return true
	return false


func _trainer_actor() -> PokemonActor:
	for i in 60:
		for node in get_tree().get_nodes_in_group(&"trainer_pokemon"):
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				return node as PokemonActor
		await get_tree().physics_frame
	return null


func _wait_interior(inside: bool) -> void:
	var interiors := _services.interiors
	for i in 240:
		await get_tree().physics_frame
		if not interiors.busy and interiors.is_inside() == inside:
			return


func _species(identifier: String) -> SpeciesData:
	return load("res://creatures/data/species/%s.tres" % identifier) as SpeciesData


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
