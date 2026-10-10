extends Node
## Prueba del viaje por regiones (acordado con Fernando el 2026-10-10): 6 regiones con
## líderes sin repetir, Liga (4 del Alto Mando + héroe Campeón), Pokédex regional y
## legendarios repartidos; 8 gimnasios con su líder; la vida de los líderes (gimnasio,
## entrenamiento, casa, viajes y combate amistoso); medalla solo en el gimnasio; la Liga
## en orden; el Boleto del profesor; la taquilla y el cambio de región con su estado.
## Uso: godot --headless --path . tests/test_regions.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder
var _services: TownServices
var _battle: BattleManager
var _results: Array[String] = []


func _ready() -> void:
	BattleManager.enabled = true
	GameState.party.clear()
	GameState.box.clear()
	GameState.world_flags = {"rival_next_day": 99999}
	GameState.regions = []
	GameState.region_index = 0
	GameState.money = 1000
	GameState.play_time = 0.0
	_data_checks()
	await _load_main()
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_regions: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _load_main() -> void:
	if _main != null:
		_main.queue_free()
		await _frames(3)
	_main = MAIN_SCENE.instantiate() as Node3D
	_main.set("starter_ceremony", false)
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_world = _main.get_node("World") as WorldBuilder
	_services = _world.structures.services
	_battle = _main.get_node("Battle") as BattleManager
	_battle.ended.connect(func(result: String) -> void: _results.append(result))
	var navigation := _main.get_node("Navigation") as WorldNavigation
	while not navigation.is_baked:
		await get_tree().physics_frame
	for node_name in ["Spawner", "Legendaries", "Ambushes", "Events", "Heroes", "Rival", "RouteTrainers", "TownNPCs"]:
		(_main.get_node(node_name) as Node).set_process(false)
	await _frames(10)


## Datos de las regiones (sin mundo).
func _data_checks() -> void:
	Regions.ensure()
	_check(GameState.regions.size() == Regions.COUNT, "hay 6 regiones")
	var leaders := {}
	var legendaries := {}
	var champions := {}
	var names := {}
	var chains := {}
	for i in GameState.regions.size():
		var region: Dictionary = GameState.regions[i]
		names[region["name"]] = true
		_check((region["leaders"] as Array).size() == 8, "región %d: 8 líderes" % i)
		for id: String in region["leaders"]:
			_check(not leaders.has(id), "el líder %s no se repite entre regiones" % id)
			leaders[id] = true
		var elite: Array = region["elite"]
		_check(elite.size() == 4 and elite.duplicate().filter(func(e: String) -> bool: return elite.count(e) == 1).size() == 4, "región %d: 4 del Alto Mando distintos" % i)
		_check(region["champion"] != GameState.character_id and Heroes.TEAMS.has(region["champion"]), "región %d: el Campeón es un héroe no elegido" % i)
		champions[region["champion"]] = true
		for id: String in region["legendaries"]:
			_check(not legendaries.has(id), "el legendario %s está en una sola región" % id)
			legendaries[id] = true
		for chain in region["chains"]:
			chains[int(chain)] = true
		_check(region["transport"] in ["boat", "plane"], "región %d: barco o avión" % i)
		_check(region["unlocked"] == (i == 0), "solo la primera región empieza abierta")
	_check(names.size() == Regions.COUNT, "los nombres de las regiones no se repiten")
	_check(champions.size() == Regions.COUNT, "los Campeones no se repiten")
	_check(leaders.size() == 48 and leaders.size() == Leaders.GYM.size(), "se usan los 48 líderes del catálogo")
	# Cada línea evolutiva vive en alguna región; cada Pokédex regional tiene ~250 especies.
	var missing := 0
	for species: SpeciesData in WildSpawner.ALL_SPECIES.species:
		if species.spawn_weight > 0.0 and not species.is_legendary and not species.is_mythical and not chains.has(species.evolution_chain):
			missing += 1
	_check(missing == 0, "todas las especies están en alguna región (%d sin región)" % missing)
	var allowed := 0
	for species: SpeciesData in WildSpawner.ALL_SPECIES.species:
		if species.spawn_weight > 0.0 and not species.is_legendary and Regions.allows(species):
			allowed += 1
	_check(allowed >= 200 and allowed <= 320, "Pokédex regional de 200 a 320 especies (%d)" % allowed)
	# Equipos y sprites de todos.
	for id: String in Leaders.GYM:
		_check(Leaders.gym_team(id, 5, 8).size() == 6, "el equipo de %s existe completo" % id)
		_check(ResourceLoader.exists(NpcLooks.DIR + Leaders.look(id) + ".png"), "%s tiene hoja de sprite" % id)
		_check(Leaders.portrait(id) != null, "%s tiene retrato" % id)
	for id: String in Leaders.ELITE:
		_check(Leaders.elite_team(id).size() == 5, "el equipo del Alto Mando %s existe completo" % id)
		_check(ResourceLoader.exists(NpcLooks.DIR + Leaders.look(id) + ".png"), "%s tiene hoja de sprite" % id)
		_check(Leaders.portrait(id) != null, "%s tiene retrato" % id)
	_check(Leaders.gym_team("brock", 0, 0).size() == 3 and Leaders.gym_team("brock", 4, 0).size() == 6, "el equipo del líder crece por región")


func _run() -> void:
	# 1. Ocho gimnasios con líderes de la región, uno por pueblo y por afinidad.
	var region := Regions.current()
	var gyms: Array = (_main.get_node("GymLeaders") as GymLeaders).gyms()
	_check(gyms.size() == 8, "la región tiene 8 gimnasios (%d)" % gyms.size())
	var used := {}
	for entry: Dictionary in gyms:
		_check((region["leaders"] as Array).has(entry["id"]) and not used.has(entry["id"]), "cada gimnasio tiene un líder distinto de la región")
		used[entry["id"]] = true

	# 2. Los Pokémon salvajes son de la Pokédex regional.
	var spawner := _main.get_node("Spawner") as WildSpawner
	var foreign := 0
	for i in 200:
		var species := spawner.pick_species(SpeciesData.Habitat.MEADOW, 0)
		if species != null and not Regions.allows(species):
			foreign += 1
	_check(foreign == 0, "los salvajes salen de la Pokédex regional (%d de fuera)" % foreign)

	# 3. Rutina del líder del pueblo inicial: gimnasio, entrenamiento y casa.
	var leaders := _main.get_node("GymLeaders") as GymLeaders
	var home_town: Dictionary = _world.layout.settlements[0]
	var leader_id := _world.structures.leader_of(home_town)
	_check(leader_id != "", "el pueblo inicial tiene gimnasio con líder")
	var day := 0
	while GymLeaders.traveling(leader_id, day):
		day += 1
	_check(GymLeaders.status(leader_id, 10.0, day) == "gym" and GymLeaders.status(leader_id, 16.0, day) == "training" and GymLeaders.status(leader_id, 22.0, day) == "home",
			"rutina del líder: gimnasio, entrenamiento y casa")
	var trips := 0
	for d in 7:
		trips += 1 if GymLeaders.traveling(leader_id, d) else 0
	_check(trips == 1, "el líder viaja 1 día por semana (%d)" % trips)

	# 4. Entrenando a las 16 h: aparece fuera, con su Pokémon, y acepta un combate amistoso.
	_set_time(day, 16.0)
	var spot := leaders.training_spot(home_town, leader_id)
	# En tierra firme junto a su lugar (los de agua entrenan en la orilla).
	var stand := spot
	for k in 16:
		var at := spot + Vector2.from_angle(TAU * k / 16.0) * 4.0
		if _world.height_at(at.x, at.y) > _world.layout.sea_level + 1.0 and not (_world.habitat_at(at.x, at.y) in [SpeciesData.Habitat.FRESHWATER, SpeciesData.Habitat.SEA]):
			stand = at
			break
	_player.global_position = Vector3(stand.x, _world.surface_height_at(stand.x, stand.y) + 0.5, stand.y)
	await _frames(30)
	_ensure_companion_out()
	await _frames(60)
	var outside: Dictionary = {}
	for leader: Dictionary in leaders.active_leaders():
		if leader["id"] == leader_id:
			outside = leader
	_check(not outside.is_empty() and (outside["node"] as Node3D).visible, "el líder entrena fuera del gimnasio a las 16 h")
	if not outside.is_empty():
		var node_at := (outside["node"] as Node3D).global_position
		_check(Vector2(node_at.x, node_at.z).distance_to(spot) < 6.0, "está en su lugar de entrenamiento (a %.1f m)" % Vector2(node_at.x, node_at.z).distance_to(spot))
		var money := GameState.money
		_check(leaders.friendly_battle(outside), "acepta un combate amistoso fuera del gimnasio")
		await _win_battle()
		_check(_results.has("trainer_win") and GameState.money > money, "el amistoso da dinero")
		_check(_services.badges().is_empty(), "el amistoso no da medalla")
		_check(leaders.friendly_done_today(leader_id), "solo un amistoso por día")
	_check(not _services.leader_in_gym(home_town), "a las 16 h el líder no está en el gimnasio")
	_check(leaders.mark_on_map(leader_id).contains("entrenar") and not leaders.map_marks().is_empty(), "el guía dice dónde entrena y lo marca en el mapa")

	# 5. Medalla: en el gimnasio a las 10 h, contra su equipo canónico.
	_set_time(day + 1 if not GymLeaders.traveling(leader_id, day + 1) else day + 2, 10.0)
	var gym: Dictionary = (home_town["buildings"] as Array).filter(func(b: Dictionary) -> bool: return b["kind"] == "gym")[0]
	_player.global_position = Vector3(float(gym["x"]), float(home_town["height"]) + 1.0, float(gym["z"]))
	await _frames(5)
	_services.enter_interior("gym", home_town, gym)
	await _wait_interior(true)
	_check(_has_point("Hablar con el líder"), "de 9 a 15 h el líder está en el gimnasio")
	_check(_has_point("Retar al entrenador del gimnasio") and _has_point("Hablar con el guía"), "el gimnasio tiene 2 entrenadores y un guía")
	await _frames(20)
	await _near_arena(Interiors.ORIGIN + Vector3(0, 0.3, 2))
	_results.clear()
	_services.gym_challenge(home_town, Interiors.ORIGIN + Vector3(0, 0.3, -2))
	await _frames(5)
	_check(_battle.active and (_battle.trainer["team"] as Array).size() == 3, "el líder pelea con 3 Pokémon en la primera región")
	if _battle.active:
		var canon: Array = Leaders.info(leader_id)["team"]
		_check((_battle.trainer["team"] as Array).all(func(s: SpeciesData) -> bool: return canon.has(s.identifier)), "el líder usa su equipo canónico")
	await _win_battle()
	_check(_services.badges().has(home_town["name"]), "al vencer al líder se gana la medalla")
	_services.interiors.exit_to(_services.interiors.current["return"])
	await _wait_interior(false)

	# 6. Liga: con 8 medallas, Alto Mando en orden y Campeón (héroe no elegido).
	for entry: Dictionary in gyms:
		if not _services.badges().has(entry["settlement"]["name"]):
			_services.badges().append(entry["settlement"]["name"])
	var leagues := _world.layout.places_of("league")
	_check(not leagues.is_empty(), "la región tiene Liga")
	if not leagues.is_empty():
		var league: Dictionary = leagues[0]
		# Directo al interior (teletransportarse lejos cae sobre terreno sin cargar).
		_services.enter_interior("league", {}, league)
		await _wait_interior(true)
		_check(_has_point("Hablar con Alto Mando") and _has_point("Hablar con Campeón"), "la Liga tiene al Alto Mando y al Campeón")
		await _frames(20)
		await _near_arena(Interiors.ORIGIN + Vector3(0, 0.3, 3))
		_services.league_challenge(2, Interiors.ORIGIN + Vector3(0, 0.3, -1))
		await _frames(5)
		_check(not _battle.active, "no se puede saltar al Alto Mando")
		for slot in 5:
			await _near_arena(Interiors.ORIGIN + Vector3(0, 0.3, 3))
			_services.league_challenge(slot, Interiors.ORIGIN + Vector3(0, 0.3, -1))
			await _frames(5)
			_check(_battle.active, "empieza el combate %d de la Liga" % (slot + 1))
			if slot == 4:
				_check(String(_battle.trainer.get("id", "")).begins_with("champion:") and (_battle.trainer["team"] as Array).size() == 6, "el Campeón es el héroe con 6 Pokémon")
			await _win_battle()
		_check(GameState.world_flags.get("champion", false), "al vencer al Campeón eres Campeón de la región")
		_services.interiors.exit_to(_services.interiors.current["return"])
		await _wait_interior(false)

	# 7. Boleto: con las misiones del Rotom, el profesor abre la siguiente región.
	_check(not Regions.progress()["complete"], "sin misiones del Rotom aún no se completa")
	GameState.path_progress["concursos"] = 5
	GameState.path_progress["investigacion"] = 6
	_check(Regions.progress()["complete"], "8 medallas + Liga + 11 misiones completan la región")
	_services.talk_professor()
	_check(Regions.ticket_given() and GameState.regions[1]["unlocked"], "el profesor da el Boleto y abre la siguiente región")
	var terminal := _main.get_node("TravelTerminal") as TravelTerminal
	await _frames(5)
	_check(terminal.booth_position != Vector3.INF and Vector2(terminal.booth_position.x, terminal.booth_position.z).distance_to(Vector2(float(home_town["x"]), float(home_town["z"]))) < 40.0,
			"la taquilla está en el pueblo inicial")
	var destinations := terminal.destinations()
	_check(destinations.size() == 1 and destinations[0] == 1, "desde la taquilla se puede ir a la región abierta")

	# 8. Cambio de región: estado propio de cada una; licencias y equipo viajan contigo.
	GameState.world_flags["ride_license"] = true
	var seed_before := GameState.world_seed
	var leaders_before := region["leaders"] as Array
	Regions.switch_to(1)
	_check(GameState.world_seed == int(GameState.regions[1]["seed"]) and GameState.world_seed != seed_before, "la región nueva tiene su semilla")
	_check(Regions.badges() == 0 and Regions.total_badges() == 8, "las medallas son por región (total 8)")
	_check(GameState.world_flags.get("ride_license", false), "la licencia de montura viaja contigo")
	_check(GameState.professor == String(GameState.regions[1]["professor"]), "cada región tiene su profesor")
	await _load_main()
	var gyms_b: Array = (_main.get_node("GymLeaders") as GymLeaders).gyms()
	_check(gyms_b.size() == 8 and gyms_b.all(func(e: Dictionary) -> bool: return not leaders_before.has(e["id"])), "la región nueva tiene 8 gimnasios con otros líderes")
	await _frames(120)
	_check(GameState.world_flags.get("arrived", false), "al llegar a la región nueva se da la bienvenida")
	Regions.switch_to(0)
	_check(Regions.badges() == 8 and GameState.world_flags.get("champion", false), "al volver, la región guarda sus medallas y la Liga")


## El compañero fuera y el jugador caminando (para poder pelear).
func _ensure_companion_out() -> void:
	if int(_main.get("companion_state")) != 0:
		_main.call("_send_out_companion")
		await _frames(40)
	var c: PokemonActor = _main.companion
	if c != null:
		c.global_position = _player.global_position + Vector3(1.0, 0.3, 1.0)


## Frente a la arena del interior, con el compañero al lado (como al hablar con el líder).
func _near_arena(at: Vector3) -> void:
	_player.global_position = at
	await _ensure_companion_out()
	await _frames(5)


func _set_time(day: int, hour: float) -> void:
	GameState.play_time = day * GameState.DAY_SECONDS + (hour - GameState.START_HOUR) * 60.0


## Vence a todo el equipo del entrenador del combate actual.
func _win_battle() -> void:
	for i in 12:
		if not _battle.active:
			break
		var foe := _battle.opponent
		if foe != null and is_instance_valid(foe):
			foe.receive_hit(foe.hp + 9999.0, _main.companion)
		await _frames(15)
	await _frames(20)


func _has_point(prefix: String) -> bool:
	for point: Dictionary in _world.structures.points():
		if (point["prompt"] as String).begins_with(prefix) and (point["pos"] as Vector3).x > WorldBuilder.INTERIOR_X:
			return true
	return false


func _wait_interior(inside: bool) -> void:
	var interiors := _services.interiors
	for i in 240:
		await get_tree().physics_frame
		if not interiors.busy and interiors.is_inside() == inside:
			return


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
