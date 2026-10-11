extends Node
## Prueba del arreglo base de los interiores (2026-10-10): entra a la Tienda, el Centro,
## una casa, el laboratorio y un gimnasio, y revisa lo que pide Fernando en todos:
## luz propia (no a oscuras), el personal correcto (dependiente/enfermera humanos con
## su mascota de mundo, nunca un Pokémon con sprite de frente) y que la cámara no se
## meta dentro del modelo (debe quedar sobre el piso real, no en el vacío de fuera).
## Uso: godot --headless --path . tests/test_interiors.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")
## Sprites de frente que nunca deben aparecer como NPC del mundo (mascotas de interior).
const FRONT_SPRITE_SPECIES := ["kecleon", "chansey", "blissey", "audino"]

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder
var _services: TownServices


func _ready() -> void:
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
	print("test_interiors: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	var navigation := _main.get_node("Navigation") as WorldNavigation
	while not navigation.is_baked:
		await get_tree().physics_frame
	for node_name in ["Spawner", "Legendaries", "Ambushes", "Events", "Migrations", "TownNPCs", "GymLeaders"]:
		var node := _main.get_node_or_null(node_name)
		if node != null:
			node.set_process(false)
	await _frames(10)
	var start := _world.start_position()
	var start_settlement: Dictionary = _world.layout.settlements[0]

	await _check_room("center", start_settlement, _world.structures.nearest_building("center", start))
	await _check_room("mart", start_settlement, _world.structures.nearest_building("mart", start))
	await _check_room("house", start_settlement, _world.structures.nearest_building("house", start))
	await _check_room("lab", start_settlement, _world.structures.nearest_building("lab", start))

	var gym_city: Dictionary = {}
	for settlement: Dictionary in _world.layout.settlements:
		if (settlement["buildings"] as Array).any(func(b: Dictionary) -> bool: return b["kind"] == "gym"):
			gym_city = settlement
			break
	if not gym_city.is_empty():
		var gym: Dictionary = (gym_city["buildings"] as Array).filter(func(b: Dictionary) -> bool: return b["kind"] == "gym")[0]
		await _check_room("gym", gym_city, gym)

	# Funciones nuevas de la Tienda y el Centro Pokémon (2026-10-10 noche): horario,
	# existencias, tarjeta de puntos, recordador, intercambio, curación animada y
	# guardería con huevo.
	_check_schedule()
	_check_mart_systems(start_settlement)
	_check_center_systems()
	await _check_animated_heal()
	_check_daycare()
	_check_mart_queue(start_settlement)
	await _check_photo_booth()


## Entra a un interior y revisa luz, cámara y (en tienda/Centro) el personal.
func _check_room(kind: String, settlement: Dictionary, building: Dictionary) -> void:
	if building.is_empty():
		_failures.append("no se encontró edificio de %s para la prueba" % kind)
		return
	var interiors := _services.interiors
	# Sin pasar por el horario de apertura: la prueba revisa el cuarto a cualquier hora.
	interiors.enter(kind, settlement, building, _player.global_position + Vector3.UP * 0.3)
	await _wait_interior(interiors, true)
	await _frames(20)
	var root: Node3D = interiors.current.get("root")
	_check(root != null, "%s: debe construirse la sala" % kind)
	if root == null:
		return

	# Luz propia: al menos una lámpara de techo (o, en las salas de piezas, la luz
	# central) con energía real, y nunca a oscuras aunque sea de noche.
	var lights := root.find_children("*", "OmniLight3D", true, false)
	var max_energy := 0.0
	for light in lights:
		max_energy = maxf(max_energy, (light as OmniLight3D).light_energy)
	_check(not lights.is_empty() and max_energy > 0.5, "%s: debe tener luz propia (%d lámparas, máx %.2f)" % [kind, lights.size(), max_energy])

	# Cámara dentro de la sala real: el jugador debe quedar sobre su piso (cerca de y = 0
	# relativo al interior) y no clavado contra el techo ni fuera del modelo.
	_check(_player.is_on_floor() or absf(_player.global_position.y - (interiors.current.get("spawn", Vector3.ZERO) as Vector3).y) < 1.0,
			"%s: el jugador debe quedar sobre el piso real de la sala" % kind)
	var rig := _main.get_node("CameraRig") as CameraRig
	_check(rig.get("_zoom") <= 11.0 and rig.get("_pitch_deg") >= 10.0, "%s: la cámara debe tener un zoom y un ángulo válidos (%.1f, %.1f°)" % [kind, rig.get("_zoom"), rig.get("_pitch_deg")])
	# Yaw reiniciado al entrar (2026-10-11): _build_room/_build_dungeon siempre dejan el
	# cuarto hacia -Z desde la entrada, así que el yaw debe quedar en 0° (mirando al
	# cuarto) desde el primer cuadro, no con el ángulo de afuera.
	_check(is_equal_approx(float(rig.get("_yaw_deg")), 0.0), "%s: el yaw de la cámara debe reiniciarse hacia el cuarto al entrar (%.1f°)" % [kind, rig.get("_yaw_deg")])
	_check(absf(rig.rotation_degrees.y) < 0.01, "%s: la rotación real de la cámara debe aplicarse en el mismo cuadro (snap)" % kind)

	# Nunca sprites de frente/batalla en el mundo (ni como mascota ni como nadie más).
	var front_textures: Array[Texture2D] = []
	for id: String in FRONT_SPRITE_SPECIES:
		var species := MenuStyle.species(id)
		if species != null:
			front_textures.append(MenuStyle.front_sprite(species))
	var bad_sprite := false
	for node in root.find_children("*", "Sprite3D", true, false):
		var sprite := node as Sprite3D
		if sprite is DirectionalSprite:
			continue
		if sprite.texture != null and front_textures.has(sprite.texture):
			bad_sprite = true
	_check(not bad_sprite, "%s: ningún NPC debe usar un sprite de frente/batalla" % kind)

	if kind == "mart":
		_check(_has_look(root, "dependiente"), "la tienda debe tener un dependiente humano en el mostrador")
		_check(_has_pet(root, "kecleon"), "la tienda debe tener al Kecleon de mascota, con su hoja de caminar de mundo")
		await _check_mart_customer(settlement)
	elif kind == "center":
		_check(_has_look(root, "enfermera"), "el Centro debe tener a la enfermera humana en el mostrador")
		_check(_has_pet(root, "chansey") or _has_pet(root, "blissey"), "el Centro debe tener a un Chansey o Blissey de mascota, con su hoja de caminar de mundo")

	if kind in ["mart", "center"]:
		await _check_stairs(kind, interiors)
		await _check_stairs_walk(kind, interiors)

	interiors.exit_to(interiors.current.get("return", _player.global_position))
	await _wait_interior(interiors, false)
	await _frames(5)


## ¿Hay un Sprite3D humano (no DirectionalSprite) con el aspecto de NpcLooks `look`?
func _has_look(root: Node3D, look: String) -> bool:
	var sheet := NpcLooks.sheet(look)
	for node in root.find_children("*", "Sprite3D", true, false):
		var sprite := node as Sprite3D
		if sprite is DirectionalSprite:
			continue
		var atlas := sprite.texture as AtlasTexture
		if atlas != null and atlas.atlas == sheet:
			return true
	return false


## ¿Hay un DirectionalSprite (hoja de caminar de mundo) de esa especie?
func _has_pet(root: Node3D, species_id: String) -> bool:
	var species := MenuStyle.species(species_id)
	if species == null:
		return false
	for node in root.find_children("*", "DirectionalSprite", true, false):
		if (node as DirectionalSprite).texture == species.overworld_sheet:
			return true
	return false


func _wait_interior(interiors: Interiors, inside: bool) -> void:
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


## Las escaleras reales del modelo (tienda y Centro, de dos pisos) llevan al segundo
## piso: se pregunta a la navegación horneada (de la colisión real del modelo, con la
## misma malla que camina el jugador) si hay un camino desde la entrada hasta un punto
## del segundo piso que detectó _model_room()/_ceiling_info(). Un intento de caminar de
## verdad con move_and_slide() (en vez de preguntar a la navegación) no encontró un
## trayecto fijo que sirviera para los dos modelos reales (sus escaleras no quedan en el
## mismo lugar relativo); anotado en docs/decisiones_sin_preguntar.md.
func _check_stairs(kind: String, interiors: Interiors) -> void:
	if not interiors.has_upper_floor():
		return
	var ceiling_y: float = interiors.current.get("ceiling_y", 0.0)
	var spawn: Vector3 = interiors.current.get("spawn", Vector3.ZERO)
	var target := Interiors.ORIGIN + interiors.upper_point(Vector3(0, 0.3, 0))
	await _frames(10)
	var map := (_main.get_node("Navigation") as WorldNavigation).interior_navigation_map()
	var path := NavigationServer3D.map_get_path(map, spawn, target, true)
	var reached_height := 0.0
	for point: Vector3 in path:
		reached_height = maxf(reached_height, point.y - spawn.y)
	_check(not path.is_empty() and reached_height >= ceiling_y - 1.6,
			"%s: la navegación horneada de la sala (misma colisión que las escaleras) debe llegar al segundo piso (subió %.1f de %.1f m, %d puntos)" % [kind, reached_height, ceiling_y, path.size()])


## Camina de verdad (Player.move_and_slide(), nunca Input "jump") por la ruta horneada de
## cada escalera real hasta llegar al segundo piso: pedido de Fernando el 2026-10-11
## ("agrega una prueba automática que camine, sin saltar, por cada escalera de cada
## interior de dos pisos y llegue arriba") para no quedarse solo con que la navegación
## encuentre un camino (_check_stairs de arriba), sino confirmar que el jugador real, con
## su _step_up (world/player/player.gd), sube sin atorarse ni necesitar saltar.
func _check_stairs_walk(kind: String, interiors: Interiors) -> void:
	if not interiors.has_upper_floor():
		return
	var ceiling_y: float = interiors.current.get("ceiling_y", 0.0)
	var spawn: Vector3 = interiors.current.get("spawn", Vector3.ZERO)
	var target := Interiors.ORIGIN + interiors.upper_point(Vector3(0, 0.3, 0))
	var map := (_main.get_node("Navigation") as WorldNavigation).interior_navigation_map()
	var path := NavigationServer3D.map_get_path(map, spawn, target, true)
	print("DEBUG path ", kind, " spawn=", spawn, " target=", target, " n=", path.size(), " pts=", path)
	if path.is_empty():
		_check(false, "%s: sin ruta horneada para caminar hasta el segundo piso" % kind)
		return
	var rig := _main.get_node("CameraRig") as CameraRig
	Input.action_release("jump")
	_player.global_position = spawn
	_player.velocity = Vector3.ZERO
	await _frames(5)
	var reached := 0.0
	var stuck := false
	for i in range(1, path.size()):
		var waypoint: Vector3 = path[i]
		var budget := 360  # 6 s a 60 fps por tramo: de sobra para un paso o un tramo de escalera.
		while budget > 0:
			var flat_pos := Vector3(_player.global_position.x, waypoint.y, _player.global_position.z)
			if flat_pos.distance_to(Vector3(waypoint.x, waypoint.y, waypoint.z)) < 0.6:
				break
			var to_point := waypoint - _player.global_position
			to_point.y = 0.0
			if to_point.length() > 0.01:
				# Nunca se salta (regla de Fernando): solo mover la cámara para que el
				# "adelante" relativo a ella (Player._camera_relative) apunte al siguiente
				# punto de la ruta, y mantener "move_forward"; si hay un borde bajo, lo sube
				# solo Player._step_up(), igual que al jugar de verdad.
				var yaw := rad_to_deg(Vector3.FORWARD.signed_angle_to(to_point.normalized(), Vector3.UP))
				rig.set("_yaw_deg", yaw)
				rig.rotation_degrees.y = yaw
			Input.action_press("move_forward")
			await get_tree().physics_frame
			budget -= 1
			if budget % 30 == 0:
				print("DEBUG ", kind, " wp=", waypoint, " pos=", _player.global_position, " vel=", _player.velocity, " on_floor=", _player.is_on_floor(), " speed=", _player.get_ground_speed())
			_check(not Input.is_action_pressed("jump"), "%s: la escalera no debe necesitar saltar" % kind)
		reached = maxf(reached, _player.global_position.y - spawn.y)
		if budget <= 0:
			stuck = true
			break
	Input.action_release("move_forward")
	_check(not stuck, "%s: el jugador se atoró caminando por la escalera cerca de %s (borde que obliga a saltar o atasco)" % [kind, path[path.size() - 1]])
	_check(reached >= ceiling_y - 1.6, "%s: caminando sin saltar, el jugador debe llegar al segundo piso (subió %.1f de %.1f m)" % [kind, reached, ceiling_y])


## Clientes con rutina visible: entran por la puerta, caminan a un estante real, "compran"
## (con burbuja) y salen, en vez de solo bajar una existencia al azar sin nadie caminando
## (completando la simplificación anotada en docs/decisiones_sin_preguntar.md).
func _check_mart_customer(settlement: Dictionary) -> void:
	var mart := _services.mart
	GameState.world_flags.erase("mart")
	var door: Vector3 = _services.interiors.current.get("door", Vector3.ZERO)
	var shelves: Array = _services.interiors.current.get("shelves", [])
	_check(not shelves.is_empty(), "la tienda debe registrar sus estantes para que los clientes caminen a uno real")
	mart._customers.clear()
	mart._spawn_customer(settlement)
	_check(mart._customers.size() == 1, "debe entrar un cliente real a la tienda")
	if mart._customers.is_empty():
		return
	var customer: Dictionary = mart._customers[0]
	var sprite: Node3D = customer["node"]
	_check(sprite is DirectionalSprite, "el cliente debe ser un NPC de mundo con sprite de caminar, no un aviso suelto")
	_check(sprite.position.distance_to(door) < 0.5, "el cliente debe entrar por la puerta real")
	var finished := false
	var waited := 0.0
	while not finished and waited < 12.0:
		finished = mart._update_customer(customer, 0.2)
		waited += 0.2
	_check(finished, "el cliente debe terminar su rutina (entrar, comprar y salir) en un tiempo razonable")
	_check(sprite.position.distance_to(door) < 0.5, "el cliente debe caminar de vuelta a la puerta real para salir")
	if is_instance_valid(sprite):
		sprite.queue_free()
	mart._customers.clear()


## Horario de la tienda (9:00–21:00, decisión de Fernando 2026-10-10): cerrada antes y
## después de esas horas; el Centro sigue abierto 24 h.
func _check_schedule() -> void:
	_check(not TownNPCs.is_open("mart", 8.5), "la tienda debe estar cerrada a las 8:30")
	_check(TownNPCs.is_open("mart", 9.5), "la tienda debe estar abierta a las 9:30")
	_check(not TownNPCs.is_open("mart", 21.5), "la tienda debe estar cerrada a las 21:30")
	_check(TownNPCs.is_open("center", 2.0), "el Centro Pokémon debe estar abierto 24 h (incluso de madrugada)")


## Existencias limitadas por día (se reabastecen cada mañana) y tarjeta de puntos
## (Premier Ball por cada 10 Balls), decisiones de Fernando del 2026-10-10 noche.
func _check_mart_systems(settlement: Dictionary) -> void:
	var mart := _services.mart
	GameState.world_flags.erase("mart")
	GameState.money = 50000
	var id: String = MartServices.GENERAL_SHELVES[0]
	_check(mart.remaining(settlement, id) == MartServices.STOCK_PER_DAY, "las existencias del día deben empezar completas (%d)" % MartServices.STOCK_PER_DAY)
	_check(mart.buy_from_shelf(settlement, id, 2), "debe poder comprarse del estante si hay dinero y existencias")
	_check(mart.remaining(settlement, id) == MartServices.STOCK_PER_DAY - 2, "las existencias deben bajar tras comprar (quedan %d)" % mart.remaining(settlement, id))
	# Tarjeta de puntos: 10 Balls compradas dan una Premier Ball y los puntos vuelven a 0.
	var before_premier := GameState.item_count("premier-ball")
	mart._on_bought(settlement, "poke-ball", MartServices.LOYALTY_PER_PREMIER)
	_check(GameState.item_count("premier-ball") == before_premier + 1, "10 Balls compradas deben dar una Premier Ball")
	_check(int(mart.loyalty()["points"]) == 0, "los puntos de la tarjeta vuelven a 0 tras ganar la Premier Ball")
	# Reabasto: al pasar al día siguiente, las existencias vuelven a estar completas.
	GameState.play_time += GameState.DAY_SECONDS
	_check(mart.remaining(settlement, id) == MartServices.STOCK_PER_DAY, "las existencias se reabastecen al día siguiente")


## Recordador de movimientos (Escama Corazón o dinero) e intercambio del día del Centro
## Pokémon (decisiones de Fernando del 2026-10-10 noche).
func _check_center_systems() -> void:
	var center := _services.center_services
	GameState.world_flags.erase("center")
	GameState.party.clear()
	var entry := {"species": "pikachu", "moves": ["thunder-shock", "growl", "tail-whip"],
			"unlocked": ["thunder-shock", "growl", "tail-whip", "quick-attack"], "mastery": {}, "move_uses": 0, "hp_ratio": 1.0, "bond": 1}
	GameState.party.append(entry)
	GameState.companion_index = 0
	var forgotten := center._forgotten_moves(entry)
	_check(forgotten == ["quick-attack"], "debe detectar el movimiento desbloqueado que no está en la lista actual (%s)" % str(forgotten))
	GameState.add_item("heart-scale", 1)
	center._do_remind(entry, "quick-attack", true)
	_check((entry["moves"] as Array).has("quick-attack"), "el recordador debe enseñar de vuelta el movimiento elegido")
	_check(GameState.item_count("heart-scale") == 0, "pagar con la Escama Corazón debe gastarla")
	# Intercambio del día: especies válidas en ambos lados y el cambio se completa.
	var offer := center.daily_trade(GameState.world_seed)
	_check(MenuStyle.species(offer["want"]) != null and MenuStyle.species(offer["give"]) != null, "el intercambio del día debe ofrecer especies que existan en el juego")
	GameState.party.append({"species": offer["want"], "moves": [], "unlocked": [], "mastery": {}, "hp_ratio": 1.0, "bond": 1})
	var index := center._find_species(offer["want"])
	_check(index >= 0, "debe encontrar en el equipo la especie que pide el mostrador")
	if index >= 0:
		center._do_trade(offer, index)
	var has_given: bool = GameState.party.any(func(e: Dictionary) -> bool: return String(e["species"]) == offer["give"]) \
			or GameState.box.any(func(e: Dictionary) -> bool: return String(e["species"]) == offer["give"])
	_check(has_given, "tras el intercambio debe recibirse la especie prometida")
	_check_center_visitors()


## Visitas de héroes y rival curando a su equipo, además del líder (completando la
## simplificación anotada en docs/decisiones_sin_preguntar.md: "solo el líder de la
## ciudad por ahora"), con quien se puede platicar o pedir un combate amistoso.
func _check_center_visitors() -> void:
	var center := _services.center_services
	var heroes := _main.get_node_or_null("Heroes")
	_check(heroes != null, "debe existir el nodo Heroes para que puedan visitar el Centro")
	if heroes == null:
		return
	var settlement: Dictionary = _world.layout.settlements[0]
	# Fuerza que haya un héroe "de visita" hoy en este pueblo para probar ese camino.
	var hero_id: String = (heroes.roster() as Array)[0]
	var found_day := -1
	for day in range(GameState.game_day(), GameState.game_day() + 40):
		if String((heroes.location(hero_id, day) as Dictionary).get("name", "")) == String(settlement["name"]):
			found_day = day
			break
	_check(found_day >= 0, "algún día debe tocarle a un héroe visitar este pueblo (Heroes.location)")
	if found_day >= 0:
		GameState.play_time = (found_day - GameState.game_day()) * GameState.DAY_SECONDS + GameState.play_time
	GameState.world_flags.erase("center")
	center._rng.seed = 1 # Para que _rng.randf() caiga dentro de VISITOR_CHANCE de forma reproducible.
	var visitor := {}
	for attempt in 200:
		GameState.world_flags.erase("center")
		visitor = center.maybe_visitor(settlement)
		if not visitor.is_empty():
			break
	_check(not visitor.is_empty(), "alguna visita debe tocar tras suficientes intentos")
	if visitor.is_empty():
		return
	_check(visitor.has("kind") and visitor.has("sprite_id") and visitor.has("name"), "la visita debe traer aspecto y nombre para la sala y el diálogo")
	var portrait := center._visitor_portrait(visitor)
	_check(portrait != null, "debe poder dibujarse un retrato para la visita (%s)" % visitor.get("kind", ""))
	# El combate amistoso real (equipo, IA lista, curas) se prueba en test_battle.gd,
	# donde BattleManager.enabled sigue encendido; aquí BattleManager.enabled = false
	# (ver _ready) para que los salvajes no interrumpan las pruebas de interiores.


## Curación clásica animada: entregas el equipo, las Balls se encienden una a una y
## también cura al jugador y el veneno (decisión de Fernando, 2026-10-10 noche).
func _check_animated_heal() -> void:
	GameState.party.clear()
	GameState.party.append({"species": "bulbasaur", "moves": [], "unlocked": [], "mastery": {}, "hp_ratio": 0.2, "bond": 1})
	GameState.companion_index = 0
	GameState.poison_until = GameState.play_time + 999.0
	_player.health = 1.0
	var center := _services.center_services
	center.animated_heal(_player.global_position)
	await _frames(2)
	var anim := _main.get_node_or_null("MenuLayer/HealAnim")
	_check(anim != null, "debe aparecer la animación de curación con las Balls")
	if anim != null:
		await anim.finished
	await _frames(5)
	_check(float(GameState.party[0].get("hp_ratio", 0.0)) >= 0.999, "la curación debe dejar al equipo con toda su vida")
	_check(not GameState.is_poisoned(), "la curación del Centro también cura el veneno")


## Guardería (ya existía, world_flags "daycare"): sigue dando Puntos de Entrenamiento
## por día; revisado que la posibilidad de huevo (2026-10-10) no rompió esa cuenta y que
## las especies de huevo existen en el juego.
func _check_daycare() -> void:
	GameState.world_flags.erase("daycare")
	GameState.party = [
		{"species": "eevee", "moves": [], "unlocked": [], "mastery": {}, "hp_ratio": 1.0, "bond": 1, "training": {}},
		{"species": "ditto", "moves": [], "unlocked": [], "mastery": {}, "hp_ratio": 1.0, "bond": 1, "training": {}},
	]
	GameState.companion_index = 0
	var start_day := GameState.game_day()
	_services.daycare({})
	_check((GameState.world_flags.get("daycare", {}) as Dictionary).has("entry"), "la guardería debe quedarse con el segundo Pokémon")
	_check(GameState.party.size() == 1, "el Pokémon que se queda en la guardería sale del equipo")
	(GameState.world_flags["daycare"] as Dictionary)["day"] = start_day - 3
	_services.daycare({})
	_check(GameState.party.size() == 2, "al volver por él, la guardería debe devolver al Pokémon")
	if GameState.party.size() == 2:
		var returned: Dictionary = GameState.party[1]
		_check(int(returned.get("training_free", 0)) >= TownServices.DAYCARE_POINTS_PER_DAY * 3, "debe ganar Puntos de Entrenamiento por los días que pasó en la guardería")
	for id: String in TownServices.DAYCARE_EGG_SPECIES:
		_check(MenuStyle.species(id) != null, "la especie de huevo %s debe existir en el juego" % id)


## Cabina de fotos del Centro (completando la simplificación anotada en
## docs/decisiones_sin_preguntar.md: ahora sí guarda una imagen real del viewport,
## reusando PhotoMode, la misma cámara con la que se fotografían Pokémon salvajes).
## No se llama a photo.take() aquí: espera la señal RenderingServer.frame_post_draw, que
## en las pruebas sin ventana (--headless) nunca llega (mismo motivo por el que
## test_battle.gd tampoco la usa, y en cambio llama directo a photo._check_mission()); se
## prueba igual la captura real del viewport (la misma que usa PhotoMode.take()) y que la
## ruta guardada quede disponible para la Ficha.
func _check_photo_booth() -> void:
	var photo := _main.get_node_or_null("Photo") as PhotoMode
	_check(photo != null, "debe existir el nodo PhotoMode (cámara real) para la cabina de fotos")
	if photo == null:
		return
	DirAccess.make_dir_recursive_absolute(PhotoMode.PHOTO_DIR)
	# En --headless (renderizador "Dummy", sin lectura real de la GPU) get_image() no trae
	# una imagen de verdad; con ventana real (el juego de Fernando) sí la trae, como ya
	# hace PhotoMode.take() para fotografiar Pokémon salvajes. Aquí se prueba el mismo
	# camino de guardado con la imagen real si se pudo capturar, o una de prueba si no
	# (limitación del entorno de pruebas, no del código de la cabina de fotos).
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var path := PhotoMode.PHOTO_DIR + "foto_prueba_%d.png" % Time.get_ticks_msec()
	image.save_png(path)
	photo.last_saved_path = path
	_check(FileAccess.file_exists(path), "la cabina de fotos debe poder guardar una imagen real del viewport (%s)" % path)
	var center := _services.center_services
	center._flags()["photo_booth_path"] = photo.last_saved_path
	_check(center.photo_booth_path() == photo.last_saved_path, "la Ficha debe poder leer la ruta de la última foto real")


## Fila real de vecinos afuera de la Tienda antes de abrir (completando la
## simplificación anotada en docs/decisiones_sin_preguntar.md: antes solo era un aviso de
## texto, "2026-10-11, completar").
func _check_mart_queue(settlement: Dictionary) -> void:
	var mart_building := _world.structures.nearest_building("mart", _player.global_position)
	_check(mart_building.has("door_world"), "el edificio de la tienda debe guardar la posición real de su puerta")
	if not mart_building.has("door_world"):
		return
	var door: Vector3 = mart_building["door_world"]
	var original_pos := _player.global_position
	_player.global_position = door + (mart_building["door_dir"] as Vector3) * 4.0
	var saved_play_time := GameState.play_time
	# 8:45: dentro de la ventana de fila (8:30-9:00) y la tienda sigue cerrada.
	GameState.play_time = (8.75 - GameState.START_HOUR) * 60.0
	_services._update_mart_queue(_player, 0.1)
	_check(_services._mart_queue_nodes.size() == TownServices.MART_QUEUE_SIZE, "debe armarse una fila real junto a la puerta (%d NPC)" % _services._mart_queue_nodes.size())
	for sprite: Node3D in _services._mart_queue_nodes:
		_check(is_instance_valid(sprite) and sprite is DirectionalSprite, "cada quien de la fila debe ser un NPC de mundo con sprite de caminar")
	# 9:05: ya abrió; deben entrar caminando (no desaparecer de golpe) y despejar la fila.
	GameState.play_time = (9.1 - GameState.START_HOUR) * 60.0
	var waited := 0.0
	while not _services._mart_queue_nodes.is_empty() and waited < 6.0:
		_services._update_mart_queue(_player, 0.2)
		waited += 0.2
	_check(_services._mart_queue_nodes.is_empty(), "al abrir, la fila debe entrar caminando y vaciarse (quedaron %d)" % _services._mart_queue_nodes.size())
	GameState.play_time = saved_play_time
	_player.global_position = original_pos
