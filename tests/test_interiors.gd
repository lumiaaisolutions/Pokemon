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
	elif kind == "center":
		_check(_has_look(root, "enfermera"), "el Centro debe tener a la enfermera humana en el mostrador")
		_check(_has_pet(root, "chansey") or _has_pet(root, "blissey"), "el Centro debe tener a un Chansey o Blissey de mascota, con su hoja de caminar de mundo")

	if kind in ["mart", "center"]:
		await _check_stairs(kind, interiors)

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
	var map := _player.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, spawn, target, true)
	var reached_height := 0.0
	for point: Vector3 in path:
		reached_height = maxf(reached_height, point.y - spawn.y)
	_check(not path.is_empty() and reached_height >= ceiling_y - 1.6,
			"%s: la navegación horneada de la sala (misma colisión que las escaleras) debe llegar al segundo piso (subió %.1f de %.1f m, %d puntos)" % [kind, reached_height, ceiling_y, path.size()])


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
