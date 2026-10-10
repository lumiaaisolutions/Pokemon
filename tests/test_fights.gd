extends Node
## Prueba de las peleas en el mundo (Fase 2.8, bloque 5): tabla de tipos, rivalidades
## entre salvajes, aturdido y humo, ataques al jugador, defensa y guardia del compañero.
## Uso: godot --headless --path . tests/test_fights.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")
const T := PokemonTypes.Type

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder
var _spawner: WildSpawner


func _ready() -> void:
	# Combate en arena apagado: esta prueba revisa las peleas en el mundo (ver test_battle).
	BattleManager.enabled = false
	_main = MAIN_SCENE.instantiate() as Node3D
	# Sin ceremonia del inicial: compañero al azar (la ceremonia se prueba en test_starter).
	_main.set("starter_ceremony", false)
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_world = _main.get_node("World") as WorldBuilder
	_spawner = _main.get_node("Spawner") as WildSpawner
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_fights: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	# Tabla de tipos oficial.
	_check(TypeChart.effectiveness(T.FIRE, [T.GRASS]) == 2.0, "Fuego contra Planta es ×2")
	_check(TypeChart.effectiveness(T.WATER, [T.FIRE, T.ROCK]) == 4.0, "Agua contra Fuego/Roca es ×4")
	_check(TypeChart.effectiveness(T.ELECTRIC, [T.GROUND]) == 0.0, "Eléctrico contra Tierra es ×0")
	_check(TypeChart.effectiveness(T.GRASS, [T.FIRE, T.FLYING]) == 0.25, "Planta contra Fuego/Volador es ×0.25")
	_check(TypeChart.effectiveness(T.NORMAL, [T.GHOST]) == 0.0, "Normal contra Fantasma es ×0")
	_check(TypeChart.effectiveness(T.FAIRY, [T.DRAGON]) == 2.0, "Hada contra Dragón es ×2")

	var navigation := _main.get_node("Navigation") as WorldNavigation
	while not navigation.is_baked:
		await get_tree().physics_frame
	_spawner.set_process(false)
	(_main.get_node("Legendaries") as Node).set_process(false)
	(_main.get_node("Ambushes") as Node).set_process(false)
	_clear_wild()
	var companion: PokemonActor = _main.companion
	# El compañero queda lejos para las pruebas entre salvajes.
	companion.process_mode = Node.PROCESS_MODE_DISABLED
	companion.global_position = Vector3(0, -50, 0)
	await _frames(5)

	# Enemigos clásicos: Zangoose contra Seviper pelean hasta que uno cae.
	var arena := _find_clearing()
	_player.global_position = arena + Vector3(0, 0.5, 25)
	var zangoose := _spawner.spawn_species(_species("zangoose"), arena, false, false)
	var seviper := _spawner.spawn_species(_species("seviper"), arena + Vector3(4, 0, 0), false, false)
	var fallen: Array[PokemonActor] = []
	zangoose.stunned.connect(func(a: PokemonActor) -> void: fallen.append(a))
	seviper.stunned.connect(func(a: PokemonActor) -> void: fallen.append(a))
	var bar_seen := false
	for i in 1500:
		await get_tree().physics_frame
		if is_instance_valid(zangoose) and (zangoose.get_node("HealthBar") as Node3D).visible:
			bar_seen = true
		if is_instance_valid(seviper) and (seviper.get_node("HealthBar") as Node3D).visible:
			bar_seen = true
		if not fallen.is_empty():
			break
	_check(not fallen.is_empty(), "Zangoose y Seviper deben pelear hasta que uno quede debilitado")
	_check(bar_seen, "en la pelea debe verse la barra de vida")
	if not fallen.is_empty():
		var loser := fallen[0]
		var winner := seviper if loser == zangoose else zangoose
		_check(loser.has_node("DizzyStars"), "el debilitado debe tener estrellitas")
		_check(winner.hp < winner.hp_max, "el ganador queda herido")
		await _frames(int((PokemonActor.STUN_TIME + 0.5) * 60))
		_check(not is_instance_valid(loser), "tras %.0f s aturdido, sin captura, debe desaparecer en humo" % PokemonActor.STUN_TIME)
	_clear_wild()
	await _frames(2)

	# El agresivo ataca al más débil; el tímido no inicia peleas.
	var absol := _spawner.spawn_species(_species("absol"), arena, false, false)
	var bidoof := _spawner.spawn_species(_species("bidoof"), arena + Vector3(5, 0, 0), false, false)
	await _frames(150)
	_check(absol.state == PokemonActor.State.FIGHT and absol.fight_target == bidoof, "el agresivo debe atacar al más débil (estado %d)" % absol.state)
	_clear_wild()
	await _frames(2)
	var pidgeot := _spawner.spawn_species(_species("pidgeot"), arena, false, false)
	_spawner.spawn_species(_species("bidoof"), arena + Vector3(5, 0, 0), false, false)
	await _frames(240)
	_check(pidgeot.state != PokemonActor.State.FIGHT, "el tímido no debe iniciar peleas")
	_clear_wild()
	await _frames(2)

	# Un agresivo ataca al jugador y le quita vida.
	companion.process_mode = Node.PROCESS_MODE_DISABLED
	_player.global_position = arena + Vector3(0, 0.5, 0)
	_player.heal(100.0)
	await _frames(10)
	_spawner.spawn_species(_species("absol"), arena + Vector3(5, 0, 0), false, false)
	await _frames(300)
	_check(_player.health < _player.config.health_max, "el salvaje agresivo debe quitarle vida al jugador")
	_clear_wild()
	await _frames(2)

	# El compañero defiende: se interpone y pelea con quien persigue a Nate.
	_player.heal(100.0)
	companion.process_mode = Node.PROCESS_MODE_INHERIT
	companion.global_position = arena + Vector3(1.5, 0.5, 1.5)
	companion.recover(1.0)
	await _frames(20)
	var chaser := _spawner.spawn_species(_species("absol"), arena + Vector3(7, 0, 0), false, false)
	var defended := false
	for i in 300:
		await get_tree().physics_frame
		if companion.state == PokemonActor.State.FIGHT and companion.fight_target == chaser:
			defended = true
			break
	_check(defended, "el compañero debe pelear con el salvaje que persigue a Nate")
	_clear_wild()
	await _frames(2)

	# Guardia con Nate desmayado: como máximo 2 salvajes peleando con el compañero.
	companion.recover(1.0)
	companion.hp_max = 100000.0
	companion.recover(1.0)
	var saved_duration := _player.config.downed_duration
	_player.config.downed_duration = 600.0
	_player.take_damage(1000.0)
	await _frames(5)
	for k in 4:
		_spawner.spawn_species(_species("absol"), arena + Vector3(4.0 * cos(k * 1.6), 0, 4.0 * sin(k * 1.6)), false, false)
	var max_attackers := 0
	for i in 600:
		await get_tree().physics_frame
		max_attackers = maxi(max_attackers, companion.attackers_count())
	_check(companion.controlled, "con Nate desmayado, el jugador controla al compañero")
	var rig := _main.get_node("CameraRig") as CameraRig
	_check(rig.get("_target") == companion, "con Nate desmayado, la cámara sigue al compañero")
	# Ataque especial y golpe físico controlados contra el salvaje más cercano.
	var nearest := companion._nearest_wild(PokemonActor.CONTROL_TARGET_RADIUS)
	_check(nearest != null, "debe haber un salvaje cerca del compañero")
	if nearest != null:
		var hp_before := nearest.hp
		# Quieto mientras vuela el proyectil (se prueba el ataque, no la puntería).
		nearest.set_physics_process(false)
		# El primer movimiento de daño de sus 4 (teclas 1-4).
		var slot := 0
		for i in companion.moves.size():
			if Moves.is_damaging(companion.moves[i]):
				slot = i
				break
		var action: String = MoveInput.ACTIONS[slot]
		Input.action_press(action)
		await _frames(2)
		Input.action_release(action)
		await _frames(90)
		# Si el salvaje al azar es inmune al tipo del movimiento (×0), no hay daño que medir.
		var move_type: int = Moves.get_move(companion.moves[slot])["type"]
		var immune := is_instance_valid(nearest) and TypeChart.effectiveness(move_type, nearest.species.types) == 0.0
		_check(immune or not is_instance_valid(nearest) or nearest.hp < hp_before, "el ataque especial controlado debe dañar al salvaje")
		if is_instance_valid(nearest):
			nearest.set_physics_process(true)
	# Esquivar: impulso invulnerable.
	Input.action_press("dodge")
	await _frames(2)
	Input.action_release("dodge")
	_check(companion.is_dashing(), "al esquivar, el compañero hace un impulso")
	_check(max_attackers <= PokemonActor.GUARD_MAX_ATTACKERS, "nunca más de 2 salvajes contra el compañero (hubo %d)" % max_attackers)
	_check(_player.mode == Player.Mode.DOWNED and _player.health > 0.0, "Nate sigue desmayado recuperándose")

	# Si el compañero cae protegiéndolo: desmayo definitivo y reaparición.
	var blacked := [false]
	_player.blacked_out.connect(func() -> void: blacked[0] = true)
	companion.hp_max = 50.0
	await _frames(30)
	companion.receive_hit(100000.0, null)
	_clear_wild()
	await _frames(240)
	_check(blacked[0], "si cae el compañero con Nate desmayado, es desmayo definitivo")
	_check(_player.mode == Player.Mode.WALK and _player.global_position.distance_to(GameState.respawn_point) < 3.0, "Nate reaparece en el punto de inicio")
	_check(not companion.controlled and rig.get("_target") == _player, "tras el desmayo la cámara vuelve a Nate")
	_player.config.downed_duration = saved_duration

	# Emboscadas: un Bicho agresivo cae sobre Nate al pasar bajo su árbol.
	companion.process_mode = Node.PROCESS_MODE_DISABLED
	_clear_wild()
	await _frames(5)
	var ambushes := _main.get_node("Ambushes") as AmbushManager
	var trees := _trees_near(_player.global_position, 300.0)
	_check(trees.size() >= 2, "debe haber árboles cerca para las emboscadas")
	if trees.size() >= 2:
		var bug := ambushes.place(_species("pinsir"), trees[0], false)
		_check(bug.perched and bug.global_position.y > trees[0].global_position.y + 1.0, "el Bicho debe quedar colgado en lo alto del árbol")
		_player.heal(100.0)
		_player.global_position = trees[0].global_position + Vector3(1.0, 0.5, 0.0)
		var warned := false
		for i in 60:
			await get_tree().physics_frame
			if is_instance_valid(bug) and (bug.get_node("Exclamation") as Sprite3D).visible:
				warned = true
		await _frames(30)
		_check(warned, "antes de caer debe mostrar el signo de exclamación")
		_check(is_instance_valid(bug) and not bug.perched, "el Bicho agresivo debe caer al pasar Nate debajo")
		var hit_or_fight := _player.health < _player.config.health_max or (is_instance_valid(bug) and bug.state in [PokemonActor.State.FIGHT, PokemonActor.State.CHASE])
		_check(hit_or_fight, "al caer debe golpear a Nate o perseguirlo (vida %.1f, estado %d, modo %d, distancia %.1f)" % [_player.health, bug.state if is_instance_valid(bug) else -1, _player.mode, bug.global_position.distance_to(_player.global_position) if is_instance_valid(bug) else -1.0])
		_clear_wild()
		await _frames(5)

		# Un ave tímida solo observa y sale volando si Nate se acerca.
		var bird := ambushes.place(_species("pidgeot"), trees[1], true)
		_player.global_position = trees[1].global_position + Vector3(6.0, 0.5, 0.0)
		await _frames(90)
		_check(is_instance_valid(bird) and bird.perched, "el ave tímida debe quedarse observando desde la copa")
		_player.global_position = trees[1].global_position + Vector3(2.0, 0.5, 0.0)
		await _frames(30)
		_check(not is_instance_valid(bird), "el ave tímida debe salir volando si Nate se acerca")


## Árboles cargados ordenados por cercanía a point (hasta radius).
func _trees_near(point: Vector3, radius: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for body: Node3D in get_tree().get_nodes_in_group(WorldBuilder.TREES_GROUP):
		if body.global_position.distance_to(point) < radius:
			found.append(body)
	found.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(point) < b.global_position.distance_to(point))
	return found


func _species(identifier: String) -> SpeciesData:
	return load("res://creatures/data/species/%s.tres" % identifier) as SpeciesData


## Un claro cerca del inicio: tierra firme y plana, sin árboles, edificios ni caminos
## en 16 m, dentro de las zonas cargadas.
func _find_clearing() -> Vector3:
	var o := _world.start_position()
	var trees := get_tree().get_nodes_in_group(WorldBuilder.TREES_GROUP)
	for ring in range(4, 20):
		for k in 24:
			var angle := TAU * k / 24.0
			var x := o.x + cos(angle) * ring * 12.0
			var z := o.z + sin(angle) * ring * 12.0
			var p := _ground(x, z)
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


## Punto en el suelo, en tierra firme.
func _ground(x: float, z: float) -> Vector3:
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
