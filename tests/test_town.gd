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
	# Combate en arena apagado: esta prueba revisa las peleas en el mundo (ver test_battle).
	BattleManager.enabled = false
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
	for node_name in ["Spawner", "Legendaries", "Ambushes", "Events", "Migrations"]:
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

	# Física de los edificios: ningún lado se atraviesa caminando (solo se entra por la
	# puerta con "Entrar"); reportado por Fernando el 2026-10-10 ("puedo atravesar
	# paredes"). Recorre los edificios con modelo del pueblo inicial y empuja al jugador
	# contra cada lado que no es la puerta.
	await _check_building_walls()
	await _check_furniture_physics()
	_player.respawn_at(start + Vector3.UP * 0.5)
	await _frames(5)

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
	# Una ficha fija (Pikachu, con movimientos de varios tipos): el compañero al azar
	# podía tener una lista tan corta que ya no hubiera nada que enseñar.
	var entry: Dictionary = {"species": "pikachu", "shiny": false, "hp_ratio": 1.0}
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

	# Gimnasio: guía, 2 entrenadores y el líder de la región.
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
		# El combate por la medalla (contra el líder, de 9 a 15 h) se prueba en test_regions.
		_check(_has_point("Hablar con el guía") and _has_point("Retar al entrenador del gimnasio"), "el gimnasio tiene guía y entrenadores")
		_check(_world.structures.leader_of(gym_city) != "", "el gimnasio tiene líder de la región")
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

	# Migraciones (fase 5.8): aviso, paso por el cielo en V y aterrizaje de un día, aunque
	# la especie sea de fuera de la región.
	var migrations := _main.get_node("Migrations") as Migrations
	var outsider: SpeciesData = null
	for id in ["swablu", "pidove", "starly", "wingull", "butterfree", "delibird", "murkrow"]:
		if not Regions.allows(_species(id)):
			outsider = _species(id)
			break
	var migrant_species: SpeciesData = outsider if outsider != null else _species("swablu")
	# Un punto en tierra firme, lejos del agua (junto al agua salen Pokémon de agua).
	var land_point := _world.start_position() + Vector3(0, 0, 200)
	for attempt in 40:
		var candidate := _world.start_position() + Vector3(cos(attempt * 0.7), 0, sin(attempt * 0.7)) * (160.0 + attempt * 8.0)
		var dry := true
		for k in 8:
			var probe := candidate + Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0)) * 60.0
			if _world.water_depth_at(probe.x, probe.z) > -0.5 or _world.water_depth_at(candidate.x, candidate.z) > -0.5:
				dry = false
				break
		if dry:
			land_point = candidate
			break
	var day_now := GameState.game_day()
	var fly_hour := GameState.clock_hour() + 1.0
	var migration := migrations.start_migration(migrant_species, land_point, fly_hour)
	_check(not migration.is_empty() and migrations.current() == migration, "empieza la migración de hoy")
	var next_day := int(GameState.world_flags["events"].get("migration_next", 0))
	_check(next_day >= day_now + Migrations.DAYS_MIN and next_day <= day_now + Migrations.DAYS_MAX, "la siguiente migración es en 2–3 días (%d)" % (next_day - day_now))
	_check(migrations.species_at(land_point) == null, "antes de su hora la bandada no ha aterrizado")
	GameState.play_time += 61.0
	_check(migrations.landed(), "a su hora la bandada aterriza")
	migrations.fly_over()
	_check(migrations.flock() != null and migrations.flock().get_child_count() == Migrations.FLOCK_SIZE, "la bandada cruza el cielo en V (%d)" % (migrations.flock().get_child_count() if migrations.flock() != null else 0))
	if migrations.flock() != null:
		_check(migrations.flock().global_position.y > _player.global_position.y + 5.0, "la bandada va por el cielo")
		var rig := _main.get_node("CameraRig") as CameraRig
		migrations._move_flock(Migrations.SKY_LOOK_AT + 0.1)
		_check(rig.looking_at_sky(), "al acercarse la bandada la cámara mira al cielo")
		rig.look_at_sky(0.0)
		migrations._move_flock(Migrations.FLOCK_SECONDS + 1.0)
		_check(migrations.flock() == null, "la bandada se va del cielo tras pasar")
	_check(migrations.species_at(land_point + Vector3(20, 0, 0)) != null and migrations.species_at(land_point + Vector3(20, 0, 0)).identifier == migrant_species.identifier, "donde aterrizó sale esa especie%s" % (" (de fuera de la región)" if outsider != null else ""))
	_check(migrations.species_at(land_point + Vector3(400, 0, 0)) == null, "lejos del aterrizaje no aplica")
	_player.global_position = Vector3(land_point.x, _world.surface_height_at(land_point.x, land_point.z) + 0.5, land_point.z)
	var migrant_hits := 0
	var spawn_total := 0
	for i in 30:
		var spawned := spawner.spawn_one()
		if spawned != null:
			spawn_total += 1
		if spawned != null and spawned.species.identifier == migrant_species.identifier:
			migrant_hits += 1
		for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
			node.queue_free()
		await _frames(1)
	_check(spawn_total > 0 and migrant_hits >= spawn_total * 0.5, "donde aterrizó la bandada salen sobre todo de esa especie (%d/%d)" % [migrant_hits, spawn_total])
	GameState.play_time += GameState.DAY_SECONDS
	_check(migrations.current().is_empty() and migrations.species_at(land_point) == null, "al día siguiente la bandada ya se fue")

	# Habitantes con rutina: de día en el pueblo, de noche en casa.
	_player.respawn_at(_world.start_position() + Vector3.UP * 0.5)
	var npcs := _main.get_node("TownNPCs") as TownNPCs
	npcs.set_process(true)
	GameState.play_time = float(GameState.game_day()) * 1440.0 + (12.0 - GameState.START_HOUR) * 60.0
	await _frames(90)
	_check(npcs.all_npcs().size() >= 3, "el pueblo inicial tiene habitantes (%d)" % npcs.all_npcs().size())
	var probe := {"wake": 8.0, "sleep": 21.0, "work": Vector2(1, 1)}
	_check(TownNPCs.goal_for(probe, 12.0, false) == "work" and TownNPCs.goal_for(probe, 19.0, false) == "plaza" and TownNPCs.goal_for(probe, 23.0, false) == "home", "la rutina cambia con la hora")
	_check(TownNPCs.goal_for(probe, 12.0, true) == "home", "con tormenta se van a casa")

	# Burbujas: charla entre dos vecinos cercanos, y nunca hay más de 3 a la vez.
	var visible_npcs: Array = npcs.all_npcs().filter(func(n: Dictionary) -> bool: return (n["node"] as Node3D).visible)
	_check(visible_npcs.size() >= 2, "hacen falta 2 vecinos visibles para probar la charla (%d)" % visible_npcs.size())
	if visible_npcs.size() >= 2:
		var chatter_a: Dictionary = visible_npcs[0]
		var chatter_b: Dictionary = visible_npcs[1]
		npcs.force_chat(chatter_a, chatter_b)
		await _frames(5)
		var bubble_a := (chatter_a["node"] as Node3D).get_node_or_null("Bubble")
		var bubble_b := (chatter_b["node"] as Node3D).get_node_or_null("Bubble")
		_check(bubble_a != null or bubble_b != null, "aparece una burbuja de charla entre dos vecinos cercanos")
		# Cupo: forzar burbujas en todos los vecinos nunca pasa de 3 a la vez.
		for extra: Dictionary in visible_npcs:
			SpeechBubbles.say(extra["node"], "¡Hola!", 3.0, "extra:%d" % (extra["node"] as Node3D).get_instance_id())
		await _frames(2)
		_check(SpeechBubbles.active_count() <= SpeechBubbles.MAX_ACTIVE, "nunca hay más de %d burbujas a la vez (%d)" % [SpeechBubbles.MAX_ACTIVE, SpeechBubbles.active_count()])
		await _frames(180)

	GameState.play_time = float(GameState.game_day()) * 1440.0 + (23.5 - GameState.START_HOUR) * 60.0
	for i in 3600:
		await get_tree().physics_frame
		if npcs.visible_npcs().is_empty():
			break
	_check(npcs.visible_npcs().is_empty(), "de noche todos los habitantes están en casa (%d afuera)" % npcs.visible_npcs().size())
	_check(npcs.all_npcs().any(func(n: Dictionary) -> bool: return n.has("pet")), "algunos habitantes tienen su Pokémon")
	# Viajeros: en un camino lejos de los pueblos aparecen y de noche acampan.
	var road_spot := Vector2.INF
	for road: PackedVector2Array in _world.layout.roads:
		for point in road:
			if _world.settlement_at(point.x, point.y, 200.0).is_empty():
				road_spot = point
				break
		if road_spot != Vector2.INF:
			break
	if road_spot != Vector2.INF:
		_world.ensure_area(Vector3(road_spot.x, 0, road_spot.y))
		_player.respawn_at(Vector3(road_spot.x, _world.height_at(road_spot.x, road_spot.y) + 0.5, road_spot.y))
		await _frames(150)
		_check(not npcs.travelers().is_empty(), "en los caminos hay viajeros")
		if not npcs.travelers().is_empty():
			_check(npcs.travelers()[0]["camp"] != null, "de noche los viajeros acampan")
	var mart: Dictionary = _world.structures.nearest_building("mart", start)
	var mart_town: Dictionary = _world.layout.settlements[0]
	_services.enter_interior("mart", mart_town, mart)
	await _frames(30)
	_check(not _services.interiors.is_inside(), "la tienda está cerrada de noche")
	GameState.play_time = float(GameState.game_day() + 1) * 1440.0 + (10.0 - GameState.START_HOUR) * 60.0

	# Acertijo de las ruinas: el orden de la inscripción despierta las piedras.
	var ruins: Dictionary = _world.layout.places_of("ruins")[0]
	var order := _services.ruin_order(ruins)
	var wrong: int = order[1]
	_services.ruin_stone(ruins, wrong)
	for symbol: int in order:
		_services.ruin_stone(ruins, symbol)
	_check(GameState.world_flags.get("ruin_solved:%d" % int(ruins["id"]), false), "tocar las piedras en orden resuelve el acertijo")

	# Comerciante, huerto y profesor.
	var merchant: Dictionary = _world.layout.places_of("merchant")[0]
	_check(_services.merchant_stock(merchant).size() == 5, "el comerciante vende 5 cosas raras al día")
	var farm: Dictionary = _world.layout.places_of("berry_farm")[0]
	var berries := GameState.item_count("oran-berry")
	_services.harvest(farm, 0)
	var after := GameState.item_count("oran-berry")
	_services.harvest(farm, 0)
	_check(after > berries and GameState.item_count("oran-berry") == after, "cada fila del huerto se cosecha una vez al día")
	GameState.bag.erase("bicycle")
	GameState.add_item("helix-fossil", 1)
	# La medalla ya no sale del gimnasio en esta prueba (el combate se prueba en test_regions).
	if _services.badges().is_empty():
		_services.badges().append(String(_world.layout.settlements[0]["name"]))
	_services.talk_professor()
	_check(GameState.item_count("bicycle") == 1, "el profesor regala la bicicleta")
	_check(GameState.world_flags.get("ride_license", false), "con una medalla el profesor da la Licencia de Montura")
	var revived := GameState.party.any(func(e: Dictionary) -> bool: return e["species"] == "omanyte") or GameState.box.any(func(e: Dictionary) -> bool: return e["species"] == "omanyte")
	_check(revived and GameState.item_count("helix-fossil") == 0, "el profesor revive el Fósil Hélix")
	# El profesor habla en la caja de diálogo (no con avisos sueltos): se cierra como lo
	# haría el jugador, si no se queda "bloqueando" el movimiento para el resto de la prueba.
	var professor_dialog := get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	_check(professor_dialog != null and professor_dialog.is_open(), "el profesor habla en la caja de diálogo")
	if professor_dialog != null:
		professor_dialog.close()

	# Mina: mazmorra con tesoros.
	var mine: Dictionary = _world.layout.places_of("mine")[0]
	_services.enter_interior("mine", {}, mine)
	await _wait_interior(true)
	_check(_services.interiors.is_inside() and _services.interiors.current["kind"] == "mine", "se entra a la mina")
	_services.interiors.exit_to(_services.interiors.current["return"])
	await _wait_interior(false)

	# Bicicleta, montura y vuelo. Lejos del aro de macetones y bancas de la plaza (física
	# de mobiliario, 2026-10-10): si no, "move_back" podía chocar con uno a los pocos
	# metros y la prueba de velocidad leía 0.
	var plaza0 := Vector2(float(_world.layout.settlements[0]["x"]), float(_world.layout.settlements[0]["z"]))
	var away0 := (Vector2(start.x, start.z) - plaza0)
	away0 = away0.normalized() if away0.length() > 0.1 else Vector2(0, 1)
	var bike_spot := start + Vector3(away0.x, 0, away0.y) * 15.0
	_player.respawn_at(Vector3(bike_spot.x, _world.height_at(bike_spot.x, bike_spot.z) + 0.5, bike_spot.z))
	await _frames(20)
	GameState.add_item("bicycle", 1)
	GameState.world_flags["ride_license"] = true
	GameState.world_flags["fly_license"] = true
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


## Física de los edificios (2026-10-10): camina al jugador contra cada lado de todos los
## edificios con modelo del pueblo inicial (izquierda, derecha y atrás; la puerta, en
## to_center, se entra a propósito con "Entrar" y no se prueba aquí) y comprueba que se
## queda afuera, no atraviesa hacia el interior.
func _check_building_walls() -> void:
	var settlement: Dictionary = _world.layout.settlements[0]
	var by: float = float(settlement["height"]) - 0.05 + 1.0
	# Movimiento manual: Player._physics_process ya llama a move_and_slide() según el
	# input de cámara; se apaga para empujarlo directo contra cada pared sin que el
	# input (vacío) lo frene primero.
	_player.set_physics_process(false)
	for building: Dictionary in settlement["buildings"]:
		var kind: String = building["kind"]
		if not BuildingModels.has_kind(kind):
			continue
		var bx := float(building["x"])
		var bz := float(building["z"])
		var model := BuildingModels.instance(kind, int(building["color"]) + int(absf(bx)))
		if model.is_empty():
			continue
		var size: Vector3 = model["size"]
		var to_center := Vector2(float(settlement["x"]) - bx, float(settlement["z"]) - bz)
		if to_center.length() < 0.1:
			to_center = Vector2(0, 1)
		to_center = to_center.normalized()
		var side_axis := Vector2(to_center.y, -to_center.x)
		var hx := size.x * 0.97 * 0.5
		var hz := size.z * 0.97 * 0.5
		var sides: Array = [["izquierda", -side_axis, hx], ["derecha", side_axis, hx], ["atrás", -to_center, hz]]
		for side_def: Array in sides:
			var axis: Vector2 = side_def[1]
			var half: float = side_def[2]
			var start_xz := Vector2(bx, bz) + axis * (half + 6.0)
			_player.velocity = Vector3.ZERO
			_player.global_position = Vector3(start_xz.x, by, start_xz.y)
			await _frames(3)
			for i in 150:
				_player.velocity = Vector3(-axis.x, 0, -axis.y) * 6.0
				_player.move_and_slide()
				await get_tree().physics_frame
			# offset: qué tan lejos del centro, sobre este eje, se quedó el jugador; si la
			# pared frena, debe quedar en >= mitad del edificio (más el radio del cuerpo).
			var final_xz := Vector2(_player.global_position.x, _player.global_position.z)
			var offset := (final_xz - Vector2(bx, bz)).dot(axis)
			_check(offset > half - 0.1, "%s de %s: no debe atravesar la pared de %s (quedó a %.2f m del centro, mitad %.2f m)" % [kind, settlement["name"], side_def[0], offset, half])
	_player.set_physics_process(true)


## Física del mobiliario (2026-10-10, "todo el mobiliario" sólido): el primer macetón de
## la plaza del pueblo inicial (ver TownIdentity.decorate, i = 0) no se atraviesa
## caminando, y al saltar sobre él el jugador queda parado encima.
func _check_furniture_physics() -> void:
	var settlement: Dictionary = _world.layout.settlements[0]
	var angle := TAU * 0.0 / 6.0 + 0.3
	var pot_xz := Vector2(float(settlement["x"]), float(settlement["z"])) + Vector2(cos(angle), sin(angle)) * 6.5
	# Misma base que usa TownIdentity.decorate para los macetones (no surface_height_at:
	# la plaza usa la altura del asentamiento, que puede diferir un poco del terreno real).
	var ground_y := float(settlement["height"]) - 0.05
	var dir := (Vector2(float(settlement["x"]), float(settlement["z"])) - pot_xz).normalized()
	var start_xz := pot_xz - dir * 4.0
	_player.set_physics_process(false)
	# Caminando derecho hacia él no debe atravesarlo.
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(start_xz.x, ground_y + 0.5, start_xz.y)
	await _frames(3)
	for i in 90:
		_player.velocity = Vector3(dir.x, 0, dir.y) * 5.0
		_player.move_and_slide()
		await get_tree().physics_frame
	var blocked := Vector2(_player.global_position.x, _player.global_position.z).distance_to(pot_xz)
	_check(blocked > 0.8, "el macetón de la plaza no debe atravesarse caminando (quedó a %.2f m del centro)" % blocked)
	# Saltando sobre él debe quedar parado encima (y por arriba de su base). El salto solo
	# está por arriba de los 1.1 m del macetón entre ~0.2 y ~0.55 s de vuelo (con
	# jump_velocity=7.5 y gravity=20); a 3 m/s y despegando 2 m antes del centro, el
	# jugador pasa por encima del borde cercano ya arriba de esa altura y aterriza dentro.
	var jump_xz := pot_xz - dir * 2.0
	_player.global_position = Vector3(jump_xz.x, ground_y + 0.5, jump_xz.y)
	_player.velocity = Vector3(dir.x, 0, dir.y) * 3.0
	_player.velocity.y = _player.config.jump_velocity
	_player.move_and_slide()
	await get_tree().physics_frame
	# Al aterrizar (arriba del macetón o, si falla, de vuelta en el suelo) se detiene ahí:
	# si no, seguiría caminando y se bajaría por el otro lado antes de medir el resultado.
	var landed := false
	for i in 110:
		if landed:
			_player.velocity = Vector3.ZERO
		elif _player.is_on_floor():
			landed = true
			_player.velocity = Vector3.ZERO
		else:
			_player.velocity.x = dir.x * 3.0
			_player.velocity.z = dir.y * 3.0
			_player.velocity.y -= _player.config.gravity * get_physics_process_delta_time()
		_player.move_and_slide()
		await get_tree().physics_frame
	_check(_player.is_on_floor() and _player.global_position.y > ground_y + 0.8, "al saltar sobre el macetón debe quedar encima (y=%.2f, suelo=%.2f)" % [_player.global_position.y, ground_y])
	_player.set_physics_process(true)


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
