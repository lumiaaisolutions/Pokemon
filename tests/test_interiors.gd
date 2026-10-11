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
