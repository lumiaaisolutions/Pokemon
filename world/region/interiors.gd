class_name Interiors
extends Node3D
## Interiores con transición (fundido a negro): Centro Pokémon, Tienda, casas, cabañas,
## laboratorio, gimnasio, sala de concursos y Liga (salas), y mazmorras generadas con la
## semilla del lugar: cuevas (las que van por pares te sacan en la otra), alcantarillas,
## torre, mansión, central, laboratorio en ruinas y Calle Victoria (pasillos en una
## cuadrícula de celdas, con Pokémon propios y tesoros). Se construyen lejos del mapa
## (x ≥ WorldBuilder.INTERIOR_X) con el suelo en y = 0; el mundo responde ahí suelo plano,
## sin agua y el hábitat del interior. Al salir se libera todo.

signal entered(kind: String)
signal exited

const ORIGIN := Vector3(20000.0, 0.0, 0.0)
const CELL := 7.0
## Muros bajos y sin choque con la cámara: desde arriba se ve todo el interior (HD-2D).
const WALL_H := 2.6
const ROCK_H := 3.4
## Pokémon de cada mazmorra (los que no existan en el juego se ignoran).
const POOLS := {
	"cave": ["zubat", "geodude", "onix", "machop", "diglett", "woobat", "roggenrola", "aron", "sableye", "noibat", "larvitar", "gible", "cubone", "paras"],
	"sewer": ["rattata", "grimer", "koffing", "trubbish", "ekans", "zubat", "magnemite", "venonat", "skrelp"],
	"tower": ["gastly", "haunter", "misdreavus", "duskull", "shuppet", "litwick", "sandygast", "phantump", "drifloon"],
	"mansion": ["gastly", "litwick", "honedge", "pumpkaboo", "rotom", "misdreavus", "sableye", "yamask"],
	"power_plant": ["magnemite", "voltorb", "electabuzz", "pikachu", "elekid", "rotom", "tynamo", "joltik", "pichu"],
	"lab_ruins": ["porygon", "abra", "ditto", "natu", "solosis", "beldum", "elgyem", "grimer"],
	"victory_road": ["machoke", "graveler", "onix", "golbat", "marowak", "rhyhorn", "sandslash", "lairon", "boldore", "tyranitar"],
}
const HABITATS := {"cave": SpeciesData.Habitat.MOUNTAIN, "sewer": SpeciesData.Habitat.SWAMP, "victory_road": SpeciesData.Habitat.MOUNTAIN}
const FLOORS := {
	"center": Color(0.95, 0.85, 0.85), "mart": Color(0.85, 0.9, 0.95), "house": Color(0.75, 0.6, 0.45), "cabin": Color(0.6, 0.45, 0.3),
	"lab": Color(0.92, 0.92, 0.92), "gym": Color(0.6, 0.6, 0.65), "contest": Color(0.95, 0.8, 0.88), "league": Color(0.7, 0.68, 0.85),
	"cave": Color(0.4, 0.36, 0.32), "sewer": Color(0.35, 0.38, 0.35), "tower": Color(0.42, 0.38, 0.48), "mansion": Color(0.4, 0.3, 0.3),
	"power_plant": Color(0.55, 0.55, 0.5), "lab_ruins": Color(0.7, 0.7, 0.72), "victory_road": Color(0.45, 0.4, 0.36),
}
const DUNGEONS := ["cave", "sewer", "tower", "mansion", "power_plant", "lab_ruins", "victory_road"]

var structures: Structures
var services: TownServices
## Interior actual: {"kind", "root", "return", "points", "actors", "place", "settlement", "building"}.
var current: Dictionary = {}
var busy := false
var _fade: ColorRect
var _materials := {}


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func is_inside() -> bool:
	return not current.is_empty()


func _process(_delta: float) -> void:
	# Si el jugador salió por otro medio (desmayo, carga), se limpia el interior.
	if not current.is_empty() and not busy:
		var player := services.player()
		if player != null and player.global_position.x < WorldBuilder.INTERIOR_X:
			_cleanup()


## Adentro: fondo oscuro sin cielo ni niebla, y menos luz del sol en mazmorras.
func _set_indoor_look(inside: bool, dungeon: bool) -> void:
	var environment_node := structures.world.get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node == null:
		return
	var environment := environment_node.environment
	environment.background_mode = Environment.BG_COLOR if inside else Environment.BG_SKY
	environment.background_color = Color(0.03, 0.03, 0.05)
	environment.fog_enabled = not inside
	DayNight.interior_light = (0.35 if dungeon else 0.85) if inside else 1.0


func _fade_to(alpha: float, seconds: float = 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished


## Entra a un interior. data es el edificio o el lugar; settlement puede ir vacío.
func enter(kind: String, settlement: Dictionary, data: Dictionary, return_point: Vector3) -> void:
	if busy or not current.is_empty():
		return
	busy = true
	await _fade_to(1.0)
	var root := Node3D.new()
	root.name = "Interior_%s" % kind
	root.position = ORIGIN
	add_child(root)
	current = {"kind": kind, "root": root, "return": return_point, "points": [], "actors": [], "place": data, "settlement": settlement}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(data.get("x", 0)) + str(data.get("z", 0)) + kind) ^ structures.world.layout.seed
	var spawn: Vector3
	if kind in DUNGEONS:
		spawn = _build_dungeon(root, kind, data, rng)
	else:
		spawn = _build_room(root, kind, settlement, data, rng)
	structures.world.interior_habitat = HABITATS.get(kind, SpeciesData.Habitat.MOUNTAIN)
	_set_indoor_look(true, kind in DUNGEONS)
	services.navigation_bake_interior(root)
	services.move_party_to(spawn)
	entered.emit(kind)
	GameState.notice.emit(_title(kind, settlement, data))
	await _fade_to(0.0)
	busy = false


## Sale del interior hacia point (la puerta de donde vino u otro lugar).
func exit_to(point: Vector3) -> void:
	if busy or current.is_empty():
		return
	busy = true
	await _fade_to(1.0)
	_cleanup()
	structures.world.ensure_area(point)
	services.move_party_to(point)
	exited.emit()
	await _fade_to(0.0)
	busy = false


func _cleanup() -> void:
	if current.is_empty():
		return
	for point: Dictionary in current["points"]:
		structures.remove_point(point)
	for actor in current["actors"]:
		if is_instance_valid(actor):
			(actor as Node).queue_free()
	services.end_trial()
	services.navigation_free_interior()
	_set_indoor_look(false, false)
	(current["root"] as Node).queue_free()
	current = {}


func current_title() -> String:
	if current.is_empty():
		return ""
	return _title(current["kind"], current["settlement"], current["place"])


func _title(kind: String, settlement: Dictionary, data: Dictionary) -> String:
	var where: String = settlement.get("name", "")
	if kind in Structures.BUILDING_NAMES:
		return "%s%s" % [Structures.BUILDING_NAMES[kind], (" de " + where) if where != "" else ""]
	return Structures.place_title(data)


func _point(pos: Vector3, prompt: String, action: Callable, radius: float = 2.2) -> void:
	(current["points"] as Array).append(structures.add_point(ORIGIN + pos, prompt, action, radius))


# --- Piezas ----------------------------------------------------------------------------

func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s:%.2f" % [color.to_html(), emission]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		if emission > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = emission
		_materials[key] = material
	return _materials[key]


func _block(parent: Node3D, size: Vector3, center: Vector3, color: Color, solid: bool = true, emission: float = 0.0, layer: int = WorldBuilder.LAYER_OBSTACLES) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, emission)
	instance.position = center
	parent.add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = layer
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		body.position = center
		parent.add_child(body)


func _light(parent: Node3D, at: Vector3, color: Color, range_m: float, energy: float = 1.4) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.omni_range = range_m
	light.light_energy = energy
	parent.add_child(light)


## Sala rectangular: piso con colisión, 4 paredes y luz.
func _room_shell(root: Node3D, size: Vector2, floor_color: Color, wall_color: Color) -> void:
	_block(root, Vector3(size.x + 2, 1.0, size.y + 2), Vector3(0, -0.5, 0), floor_color, true, 0.0, WorldBuilder.LAYER_TERRAIN)
	_block(root, Vector3(size.x + 2, WALL_H, 1), Vector3(0, WALL_H * 0.5, -size.y * 0.5 - 0.5), wall_color)
	_block(root, Vector3(size.x + 2, WALL_H, 1), Vector3(0, WALL_H * 0.5, size.y * 0.5 + 0.5), wall_color)
	_block(root, Vector3(1, WALL_H, size.y + 2), Vector3(-size.x * 0.5 - 0.5, WALL_H * 0.5, 0), wall_color)
	_block(root, Vector3(1, WALL_H, size.y + 2), Vector3(size.x * 0.5 + 0.5, WALL_H * 0.5, 0), wall_color)
	_light(root, Vector3(0, 4.5, 0), Color(1.0, 0.95, 0.85), maxf(size.x, size.y) * 1.2, 1.6)


## Personaje (NPC) con la primera celda de una hoja de entrenador o el sprite de un Pokémon.
func _npc(root: Node3D, at: Vector3, trainer_id: String = "", pokemon: String = "") -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.position = at
	if pokemon != "":
		var species := MenuStyle.species(pokemon)
		sprite.texture = MenuStyle.front_sprite(species) if species != null else null
		sprite.pixel_size = 0.03
		sprite.offset.y = 40
	else:
		var sheet := PlayerCharacters.sheet(trainer_id)
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0, 0, sheet.get_width() / 3.0, sheet.get_height() / 8.0)
		sprite.texture = atlas
		sprite.pixel_size = 0.057
		sprite.offset.y = atlas.region.size.y * 0.5
	root.add_child(sprite)
	return sprite


## Salas de edificios. Devuelve el punto de aparición (relativo al mundo).
func _build_room(root: Node3D, kind: String, settlement: Dictionary, building: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var size: Vector2 = {"center": Vector2(18, 14), "mart": Vector2(14, 11), "house": Vector2(10, 9), "cabin": Vector2(8, 7),
			"lab": Vector2(16, 12), "gym": Vector2(26, 30), "contest": Vector2(22, 18), "league": Vector2(30, 36)}.get(kind, Vector2(12, 10))
	var wall := Color(0.95, 0.93, 0.88)
	if kind in ["gym", "league"]:
		wall = Color(0.55, 0.55, 0.62)
	elif kind == "cabin":
		wall = Color(0.5, 0.36, 0.24)
	_room_shell(root, size, FLOORS.get(kind, Color(0.7, 0.7, 0.7)), wall)
	var door := Vector3(0, 0, size.y * 0.5 - 1.0)
	_block(root, Vector3(2.4, 0.05, 1.4), door + Vector3(0, 0.02, 0.2), Color(0.6, 0.2, 0.2), false)
	_point(door + Vector3.UP * 0.5, "Salir", func() -> void: exit_to(current["return"]), 1.8)
	var back := -size.y * 0.5 + 2.0
	match kind:
		"center":
			_block(root, Vector3(8, 1.1, 1.2), Vector3(0, 0.55, back + 1.0), Color(0.9, 0.4, 0.45))
			_npc(root, Vector3(0, 0, back), "", "chansey" if rng.randf() < 0.5 else "audino")
			_point(Vector3(0, 0.5, back + 2.4), "Curar a tu equipo", services.heal_at_center.bind(current["return"]))
			_block(root, Vector3(1.4, 1.6, 1.0), Vector3(size.x * 0.5 - 1.5, 0.8, back), Color(0.3, 0.35, 0.45), true, 0.2)
			_point(Vector3(size.x * 0.5 - 1.5, 0.5, back + 1.6), "Usar el PC (Caja)", services.open_menu_tab.bind("Caja"))
		"mart":
			_block(root, Vector3(5, 1.1, 1.2), Vector3(-3, 0.55, back + 1.0), Color(0.3, 0.5, 0.85))
			_npc(root, Vector3(-3, 0, back), "", "kecleon")
			_point(Vector3(-3, 0.5, back + 2.4), "Comprar y vender", services.open_shop)
			for i in 3:
				_block(root, Vector3(1.0, 2.0, 6.0), Vector3(1.5 + i * 2.2, 1.0, 0.5), Color(0.75, 0.6, 0.45))
		"house", "cabin":
			_block(root, Vector3(2.0, 0.6, 3.0), Vector3(size.x * 0.5 - 1.6, 0.3, back + 0.6), Color(0.85, 0.85, 0.95))
			_point(Vector3(size.x * 0.5 - 1.6, 0.5, back + 2.4), "Dormir (hasta la mañana)", services.rest.bind(current["return"]))
			_block(root, Vector3(2.0, 0.9, 1.4), Vector3(-1.5, 0.45, 0), Color(0.55, 0.38, 0.25))
			var resident: String = PlayerCharacters.LIST[rng.randi() % PlayerCharacters.LIST.size()]["id"]
			_npc(root, Vector3(-3.4, 0, -0.5), resident)
			_point(Vector3(-3.4, 0.5, 0.8), "Hablar", services.talk_resident.bind(settlement, building))
		"lab":
			for i in 3:
				_block(root, Vector3(3.0, 1.0, 1.2), Vector3(-5 + i * 5, 0.5, back + 1.5), Color(0.85, 0.88, 0.92))
			_npc(root, Vector3(0, 0, back + 3.2), "red" if GameState.gender == "female" else "leaf")
			_point(Vector3(0, 0.5, back + 4.5), "Hablar con el Prof. %s" % GameState.professor, services.talk_professor)
		"gym", "league":
			_block(root, Vector3(size.x - 6, 0.05, size.y - 10), Vector3(0, 0.03, -1), Color(0.75, 0.75, 0.55), false)
			var leader_at := Vector3(0, 0, back + 1.0)
			var leader_id: String = PlayerCharacters.LIST[rng.randi() % PlayerCharacters.LIST.size()]["id"]
			_npc(root, leader_at, leader_id)
			if kind == "gym":
				var type := structures.gym_type(settlement)
				_point(leader_at + Vector3(0, 0.5, 1.6), "Retar al líder (tipo %s)" % MenuStyle.TYPE_NAMES[type], services.gym_challenge.bind(settlement, ORIGIN + Vector3(0, 0, -2)))
			else:
				_point(leader_at + Vector3(0, 0.5, 1.6), "Retar al Alto Mando y al Campeón", services.league_challenge.bind(ORIGIN + Vector3(0, 0, -2)))
			_light(root, Vector3(0, 4.5, -8), Color(1, 1, 1), 30.0, 1.5)
		"contest":
			_block(root, Vector3(12, 0.8, 5), Vector3(0, 0.4, back + 2.0), Color(0.85, 0.55, 0.7))
			_npc(root, Vector3(6, 0, back + 6.0), "may")
			_point(Vector3(6, 0.5, back + 7.4), "Participar en el concurso", services.contest.bind(settlement))
	return ORIGIN + door + Vector3(0, 0.3, -1.5)


## Mazmorra en una cuadrícula: pasillos tallados con un recorrido al azar desde la
## entrada (sur) hasta la salida (norte), con salas y ramas extra.
func _build_dungeon(root: Node3D, kind: String, place: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var cols := 9
	var rows := 12 if kind != "victory_road" else 18
	var open := {}
	var cell := Vector2i(cols / 2, rows - 1)
	open[cell] = true
	var exit_cell := Vector2i(rng.randi_range(1, cols - 2), 0)
	var guard := 0
	while cell != exit_cell and guard < 600:
		guard += 1
		var options: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
		if kind == "sewer":
			options = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
		var step: Vector2i = options[rng.randi() % options.size()]
		if cell.y == 0:
			step = Vector2i(signi(exit_cell.x - cell.x), 0)
		var next := cell + step
		if next.x < 0 or next.x >= cols or next.y < 0 or next.y >= rows:
			continue
		cell = next
		open[cell] = true
	# Ramas y salas.
	var keys: Array = open.keys()
	for i in 6:
		var from: Vector2i = keys[rng.randi() % keys.size()]
		for j in rng.randi_range(2, 4):
			from += [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi() % 4]
			if from.x >= 0 and from.x < cols and from.y >= 0 and from.y < rows:
				open[from] = true
	var width := cols * CELL
	var depth := rows * CELL
	var floor_color: Color = FLOORS.get(kind, Color(0.4, 0.4, 0.4))
	var wall_color := floor_color.darkened(0.25)
	_block(root, Vector3(width + CELL * 2, 1.0, depth + CELL * 2), Vector3(0, -0.5, 0), floor_color, true, 0.0, WorldBuilder.LAYER_TERRAIN)
	var to_local := func(c: Vector2i) -> Vector3: return Vector3((c.x + 0.5) * CELL - width * 0.5, 0, (c.y + 0.5) * CELL - depth * 0.5)
	for x in range(-1, cols + 1):
		for y in range(-1, rows + 1):
			var c := Vector2i(x, y)
			if not open.has(c):
				var h := ROCK_H + (rng.randf() * 1.2 if kind in ["cave", "victory_road"] else 0.0)
				_block(root, Vector3(CELL, h, CELL), to_local.call(c) + Vector3(0, h * 0.5, 0), wall_color)
	# Luces a lo largo del recorrido.
	var light_color: Color = {"sewer": Color(0.6, 1.0, 0.6), "tower": Color(0.7, 0.6, 1.0), "mansion": Color(1.0, 0.7, 0.5),
			"power_plant": Color(1.0, 0.95, 0.6), "lab_ruins": Color(0.7, 0.9, 1.0)}.get(kind, Color(1.0, 0.85, 0.6))
	var index := 0
	for c: Vector2i in open:
		index += 1
		if index % 3 == 0:
			_light(root, to_local.call(c) + Vector3(0, 3.5, 0), light_color, 14.0, 1.2)
	if kind == "sewer":
		for c: Vector2i in open:
			if rng.randf() < 0.4:
				_block(root, Vector3(1.6, 0.05, CELL), to_local.call(c) + Vector3(0, 0.02, 0), Color(0.3, 0.45, 0.3), false)
	# Entrada (sur) y salida (norte).
	var entrance: Vector3 = to_local.call(Vector2i(cols / 2, rows - 1))
	_block(root, Vector3(2.4, 0.05, 1.4), entrance + Vector3(0, 0.02, CELL * 0.35), Color(0.8, 0.75, 0.4), false, 0.5)
	_point(entrance + Vector3(0, 0.5, CELL * 0.35), "Salir", func() -> void: exit_to(current["return"]), 1.8)
	var far_exit := _far_exit(kind, place)
	var exit_local: Vector3 = to_local.call(exit_cell)
	_block(root, Vector3(2.4, 0.05, 1.4), exit_local + Vector3(0, 0.02, -CELL * 0.35), Color(0.4, 0.75, 0.9), false, 0.5)
	if far_exit != Vector3.INF:
		var label := "Salida al otro lado" if kind != "victory_road" else "Salir frente a la Liga Pokémon"
		_point(exit_local + Vector3(0, 0.5, -CELL * 0.35), label, func() -> void: exit_to(far_exit), 1.8)
	else:
		_point(exit_local + Vector3(0, 0.5, -CELL * 0.35), "Salir", func() -> void: exit_to(current["return"]), 1.8)
	# Tesoros (uno por día del juego) y Pokémon propios.
	var cells: Array = open.keys()
	for i in 2:
		var c: Vector2i = cells[rng.randi() % cells.size()]
		var at: Vector3 = to_local.call(c) + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
		services.place_treasure(self, root, at, "%s:%d:%d" % [kind, int(place.get("id", 0)), i], rng)
	var pool: Array[SpeciesData] = []
	for id: String in POOLS.get(kind, []):
		var species := MenuStyle.species(id)
		if species != null:
			pool.append(species)
	if not pool.is_empty():
		for i in rng.randi_range(4, 7):
			var c: Vector2i = cells[rng.randi() % cells.size()]
			if c.y >= rows - 2:
				continue
			var actor := services.spawn_wild(pool[rng.randi() % pool.size()], ORIGIN + to_local.call(c) + Vector3(0, 0.3, 0))
			if actor != null:
				(current["actors"] as Array).append(actor)
	return ORIGIN + entrance + Vector3(0, 0.3, -1.0)


## Adónde sale la otra boca: la cueva pareja o la Liga (Calle Victoria).
func _far_exit(kind: String, place: Dictionary) -> Vector3:
	var target: Dictionary = {}
	if kind == "victory_road":
		var leagues := structures.world.layout.places_of("league")
		if not leagues.is_empty():
			var league: Dictionary = leagues[0]
			var x := float(league["x"])
			var z := float(league["z"]) + 17.0
			return Vector3(x, structures.world.height_at(x, z) + 0.5, z)
	elif place.has("exit"):
		target = structures.place_by_id(int(place["exit"]))
	if target.is_empty():
		return Vector3.INF
	var tx := float(target["x"])
	var tz := float(target["z"]) + 4.5
	return Vector3(tx, structures.world.height_at(tx, tz) + 0.5, tz)
