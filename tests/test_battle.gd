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
	# El rival no aparece por su cuenta durante esta prueba (se prueba en la sección 13).
	GameState.world_flags["rival_next_day"] = 99999
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
	for wait in 60:
		await get_tree().process_frame
		if not _battle.active:
			break
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

	# 3b. Horda (fase 5.8): 5 te rodean, pelean a la vez y al vencerlas hay premio extra.
	_main.companion.global_position = arena + Vector3(1.5, 0.5, 4)
	var horde_leader := _spawner.spawn_horde(_species("patrat"), arena + Vector3(0, 0, -6))
	await _frames(2)
	_check(horde_leader != null and horde_leader.has_meta("horde"), "spawn_horde crea una horda")
	if horde_leader != null:
		var members := _spawner.horde_members(int(horde_leader.get_meta("horde")))
		_check(members.size() == WildSpawner.HORDE_SIZE, "la horda tiene %d miembros (%d)" % [WildSpawner.HORDE_SIZE, members.size()])
		_player.global_position = arena + Vector3(0, 0.5, 2)
		var wins_before := _results.count("win")
		var money_before := GameState.money
		# Se acerca sola: el disparador de proximidad empieza el combate.
		for i in 40:
			await get_tree().physics_frame
			if _battle.active:
				break
		_check(_battle.active and _battle.horde_size == WildSpawner.HORDE_SIZE, "acercarse a la horda empieza el combate contra las 5 (activo %s, tamaño %d)" % [_battle.active, _battle.horde_size])
		var fighting := members.filter(func(m: PokemonActor) -> bool: return m.battle_center != Vector3.INF)
		_check(fighting.size() == WildSpawner.HORDE_SIZE, "todos los de la horda entran a la arena (%d)" % fighting.size())
		for k in WildSpawner.HORDE_SIZE:
			if not _battle.active:
				break
			var current := _battle.opponent
			current.receive_hit(current.hp + 100.0, _main.companion)
			# Espera cuadros de proceso (bajo carga caben varios pasos de física en uno).
			for wait in 60:
				await get_tree().process_frame
				if not _battle.active or _battle.opponent != current:
					break
			if k < WildSpawner.HORDE_SIZE - 1:
				_check(_battle.active and _battle.opponent != current, "tras debilitar a uno sigue el siguiente de la horda (%d)" % k)
		await _frames(10)
		_check(_results.count("win") == wins_before + 1, "vencer a toda la horda gana el combate")
		_check(GameState.money >= money_before + 150 * WildSpawner.HORDE_SIZE, "la horda da premio extra")
		_check(_battle.horde.is_empty(), "al terminar se limpia la horda")
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

	# 5. Captura dentro de la arena (Fase 4): carga de potencia, excelente y esquiva.
	_main.companion.global_position = arena + Vector3(1.5, 0.5, 4)
	var target := _spawner.spawn_species(_species("lillipup"), arena + Vector3(0, 0, -4), false, false)
	await _frames(2)
	_check(_battle.start(target), "debe empezar un combate para capturar")
	await _frames(5)
	var aim := _player.get_node("ThrowAim") as ThrowAim
	aim.locked = true
	await _frames(5)
	_check(not _main.companion.controlled, "al apuntar, tu Pokémon pelea solo y tú controlas a Nate")
	var health := _player.health
	_player.dodge(Vector3.RIGHT)
	_player.take_damage(4.0)
	_check(_player.health == health, "esquivando, Nate no recibe daño")
	await _frames(30)
	_check(not _player.is_dodging(), "la esquiva dura poco")
	aim.charging = true
	aim.charge = 0.5
	var slow := aim.throw_velocity().length()
	aim.charge = 1.0
	_check(aim.throw_velocity().length() > slow, "más carga lanza más lejos")
	aim.charge = 0.9
	var balls := GameState.item_count(GameState.selected_ball)
	var ball := aim.release_charge()
	_check(ball != null and is_equal_approx(ball.throw_bonus, ThrowAim.THROW_EXCELLENT_BONUS), "soltar en la zona dorada da lanzamiento excelente")
	_check(GameState.item_count(GameState.selected_ball) == balls - 1, "el lanzamiento gasta una ball")
	_check(not aim.charging and aim.charge == 0.0, "la carga se reinicia al lanzar")
	aim.locked = false
	_battle.finish("flee")
	_clear_wild()
	await _frames(5)

	# 6. Evolución sin niveles (Fase 5.5).
	var bulba := {"species": "bulbasaur", "shiny": false, "hp_ratio": 1.0, "wins": 3}
	GameState.party.append(bulba)
	var bulba_index := GameState.party.size() - 1
	_check(Evolution.ready_option(bulba).is_empty(), "Bulbasaur con 3 victorias aún no evoluciona (nivel 16 = 4)")
	bulba["wins"] = 4
	_check(Evolution.ready_option(bulba).get("to", "") == "ivysaur", "con 4 victorias puede evolucionar en Ivysaur")
	_check(Evolution.item_option({"species": "pikachu"}, "thunderstone").get("to", "") == "raichu", "Pikachu evoluciona con la Piedra Trueno")
	_check(Evolution.requirement_text({"species": "eevee", "bond": 2}, Evolution.options("eevee")[3]).begins_with("Vínculo"), "la amistad se pide como vínculo")
	var scene := EvolutionScene.play(_main, bulba_index, "ivysaur")
	await scene.finished
	_check(GameState.party[bulba_index]["species"] == "ivysaur", "tras la animación, Bulbasaur es Ivysaur")
	_check(int(GameState.dex_entry("ivysaur").get("caught", 0)) >= 1, "la evolución se registra en la Pokédex")

	# 7. Misiones de megapiedras.
	GameState.party.append({"species": "charmander", "shiny": false, "hp_ratio": 1.0})
	MegaMissions.update()
	var charizard := MegaMissions.all().filter(func(m: Dictionary) -> bool: return m["species"] == "charizard")
	_check(not charizard.is_empty(), "un Charmander en el equipo abre la misión de megapiedra de Charizard")
	if not charizard.is_empty():
		var mission: Dictionary = charizard[0]
		mission["kind"] = "alpha"
		GameState.world_flags["alpha_beaten:charizard"] = true
		MegaMissions.update()
		_check(mission["done"] and GameState.item_count("stone-" + String(mission["mega"])) > 0, "vencer a su Alfa entrega la megapiedra")

	# 8. Misión de fotografía del día.
	var photo := _main.get_node("Photo") as PhotoMode
	_spawner.spawn_species(_species("patrat"), arena + Vector3(0, 0, -6), false, false)
	await _frames(2)
	var mission := photo.mission()
	_check(not mission.is_empty(), "debe haber una misión de fotografía con un salvaje cerca")
	if not mission.is_empty():
		var money := GameState.money
		var subjects: Array[String] = [String(mission["species"])]
		photo._check_mission(subjects)
		_check(mission["done"] and GameState.money == money + PhotoMode.REWARD_MONEY, "fotografiar a la especie pedida da el premio")
	_clear_wild()

	# 9. Entrenadores en los caminos (Fase 5.6).
	var trainers := _main.get_node("RouteTrainers") as RouteTrainers
	_check(trainers.spots.size() >= 5, "debe haber entrenadores a lo largo de los caminos (%d)" % trainers.spots.size())
	if not trainers.spots.is_empty():
		var spot: Dictionary = trainers.spots[0]
		for candidate: Dictionary in trainers.spots:
			if _world.is_near_loaded(Vector3((candidate["pos"] as Vector2).x, 0, (candidate["pos"] as Vector2).y)):
				spot = candidate
				break
		var team := trainers.team_for(spot)
		_check((team["team"] as Array).size() >= 2, "el entrenador lleva al menos 2 Pokémon")
		var spot_pos := Vector3((spot["pos"] as Vector2).x, 0, (spot["pos"] as Vector2).y)
		# Primero detrás de él (fuera de su vista) para que aparezca.
		var behind := spot_pos - (spot["facing"] as Vector3) * 6.0
		_player.global_position = Vector3(behind.x, _world.surface_height_at(behind.x, behind.z) + 0.5, behind.z)
		await _frames(40)
		var trainer: Dictionary = {}
		for t: Dictionary in trainers.active_trainers():
			if t["spot"] == spot:
				trainer = t
		_check(not trainer.is_empty(), "el entrenador aparece al acercarte")
		if not trainer.is_empty():
			# Delante de él, en su campo de visión.
			var front: Vector3 = (trainer["node"] as Node3D).global_position + (spot["facing"] as Vector3) * 7.0
			_main.companion.global_position = front + Vector3(1.0, 1.0, 0)
			_player.global_position = front + Vector3(0, 0.5, 0)
			_player.velocity = Vector3.ZERO
			var started := false
			for i in 400:
				await get_tree().physics_frame
				if _battle.active:
					started = true
					break
			_check(started and not _battle.trainer.is_empty(), "al verte, el entrenador se acerca y empieza el combate (estado %s)" % trainer["state"])
			if started:
				var money := GameState.money
				var count := (_battle.trainer["team"] as Array).size()
				for round in count:
					var foe := _battle.opponent
					if foe == null or not is_instance_valid(foe):
						break
					foe.receive_hit(foe.hp + 100.0, _main.companion)
					await _frames(12)
				await _frames(10)
				_check(_results.has("trainer_win"), "vencer a todo su equipo gana el combate")
				_check(GameState.money > money, "el entrenador paga al perder")
				_check(trainers.beaten_today(spot), "queda vencido por hoy (revancha mañana)")
				await _frames(30)
				_check(not _battle.active and trainer["state"] != "approach", "vencido, no vuelve a retarte hoy")

	# 10. Un viajero con ganas de pelear te ve, se acerca y te reta.
	var npcs := _main.get_node("TownNPCs") as TownNPCs
	var walker: Dictionary = {}
	for i in 600:
		await get_tree().physics_frame
		if not npcs.travelers().is_empty():
			walker = npcs.travelers()[0]
			break
	_check(not walker.is_empty(), "debe aparecer un viajero en los caminos")
	# A veces el jugador cae en el agua (nadando no te retan) o el viajero ya pasó de largo:
	# se prueba con hasta 3 viajeros.
	var challenged := false
	var tried := 0
	while not walker.is_empty() and not challenged and tried < 3:
		tried += 1
		if walker["pet"] == null:
			walker["pet"] = npcs._make_pet(RandomNumberGenerator.new())
		walker["mood"] = true
		var node: Node3D = walker["node"]
		var sprite := node.get_node("Sprite") as DirectionalSprite
		_main.companion.global_position = node.global_position + sprite.facing_world * 7.0 + Vector3(1, 1, 0)
		_player.global_position = node.global_position + sprite.facing_world * 7.0 + Vector3.UP * 0.5
		_player.velocity = Vector3.ZERO
		for i in 400:
			await get_tree().physics_frame
			if _battle.active:
				challenged = String(_battle.trainer.get("name", "")).contains(String(walker["name"]))
				break
		if _battle.active:
			_battle.finish("flee")
		await _frames(10)
		if not challenged:
			var others := npcs.travelers().filter(func(t: Dictionary) -> bool: return t != walker and not t.get("mood_used", false))
			walker = others[0] if not others.is_empty() else {}
	_check(challenged, "el viajero te ve, se acerca y te reta (%d intentos)" % tried)

	# 11. Héroes: equipo que crece con las medallas, IA lista y reto.
	var heroes := _main.get_node("Heroes") as Heroes
	var expected := PlayerCharacters.LIST.size() - (1 if PlayerCharacters.LIST.any(func(e: Dictionary) -> bool: return e["id"] == GameState.character_id) else 0)
	_check(heroes.roster().size() == expected and not heroes.roster().has(GameState.character_id), "los héroes son todos menos tu personaje (%d)" % heroes.roster().size())
	var hero_id: String = heroes.roster()[0]
	var early := Heroes.team_for(hero_id, 0)
	var late := Heroes.team_for(hero_id, 8)
	_check(early.size() == 2 and late.size() == 6, "el equipo crece de 2 a 6 con las medallas")
	_check(early[0].evolution_stage <= late[0].evolution_stage, "sin medallas usan formas menos evolucionadas")
	_check(not heroes.rumored_today().is_empty(), "el Rotom tiene rumores de héroes hoy")
	var spot := heroes.location(hero_id)
	GameState.play_time = (12.0 - GameState.START_HOUR) * 60.0 + GameState.game_day() * GameState.DAY_SECONDS
	_player.global_position = Vector3(float(spot["x"]), _world.surface_height_at(float(spot["x"]), float(spot["z"])) + 10.0, float(spot["z"]) + 12.0)
	_world.ensure_area(_player.global_position)
	await _frames(60)
	var found: Dictionary = {}
	for h: Dictionary in heroes.active_heroes():
		if h["id"] == hero_id:
			found = h
	_check(not found.is_empty(), "el héroe aparece en su lugar del día")
	if not found.is_empty():
		_main.companion.global_position = _player.global_position + Vector3(1, 0, 0)
		await _frames(30)
		heroes._challenge(found)
		await _frames(5)
		_check(_battle.active and _battle.trainer.get("smart", false), "el héroe reta con IA lista")
		if _battle.active:
			var foe := _battle.opponent
			foe.hp = foe.hp_max * 0.2
			await _frames(5)
			_check(foe.hp > foe.hp_max * 0.2, "el héroe usa pociones cuando su Pokémon está bajo")
			_battle.finish("flee")
		await _frames(10)

	# 12. Profesor: 1 o 2 viajes por semana y la asistente marca dónde está.
	var professor := _main.get_node("Professor") as Professor
	var trips := 0
	for d in 7:
		trips += 1 if Professor.traveling(d) else 0
	_check(trips >= 1 and trips <= 2, "el profesor viaja 1 o 2 días por semana (%d)" % trips)
	var trip_day := -1
	for d in 14:
		if Professor.traveling(d):
			trip_day = d
			break
	_check(trip_day >= 0 and not professor.trip_place(trip_day).is_empty(), "en su día de viaje tiene un lugar de investigación")
	GameState.play_time = (10.0 - GameState.START_HOUR) * 60.0 + trip_day * GameState.DAY_SECONDS
	GameState.world_flags.erase("waypoint")
	professor.talk_assistant(_world.structures.services)
	await _frames(2)
	_check(GameState.world_flags.has("waypoint"), "la asistente marca en el mapa dónde está el profesor")
	var dialog_box := get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	if dialog_box != null:
		dialog_box.close()

	# 13. Rival: aparece tras una medalla nueva, se acerca y te reta.
	var hugh := _main.get_node("Rival") as Rival
	_player.global_position = arena + Vector3(0, 0.5, 6)
	_main.companion.global_position = arena + Vector3(1.5, 0.5, 4)
	await _frames(20)
	GameState.world_flags["rival_badges"] = -1
	var rival_fight := false
	for i in 900:
		await get_tree().physics_frame
		var box := get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
		if box != null and box.is_open() and DialogBox.blocking:
			box.advance()
			box.advance()
		if _battle.active and String(_battle.trainer.get("id", "")) == "rival":
			rival_fight = true
			break
	_check(rival_fight, "tras una medalla el rival te busca y te reta")
	if _battle.active:
		_battle.finish("flee")
	await _frames(10)
	_check(not hugh.busy(), "el rival se va al terminar")

	# 14. Perder la racha al desmayarte.
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
