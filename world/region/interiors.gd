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
	"mine": ["geodude", "roggenrola", "drilbur", "nosepass", "carbink", "rolycoly", "aron", "onix", "diglett"],
	"villain_base": ["koffing", "grimer", "zubat", "houndour", "murkrow", "sneasel", "purrloin", "trubbish", "stunky"],
	"distortion": ["gastly", "misdreavus", "sableye", "spiritomb", "porygon", "baltoy", "chimecho", "sigilyph", "dreepy", "drifloon"],
	"shipwreck": ["frillish", "tentacool", "shellder", "chinchou", "relicanth", "clamperl", "sandygast", "dhelmise", "pyukumuku"],
}
const HABITATS := {"cave": SpeciesData.Habitat.MOUNTAIN, "sewer": SpeciesData.Habitat.SWAMP, "victory_road": SpeciesData.Habitat.MOUNTAIN,
		"mine": SpeciesData.Habitat.MOUNTAIN, "shipwreck": SpeciesData.Habitat.SEA}
const FLOORS := {
	"center": Color(0.95, 0.85, 0.85), "mart": Color(0.85, 0.9, 0.95), "house": Color(0.75, 0.6, 0.45), "cabin": Color(0.6, 0.45, 0.3),
	"lab": Color(0.92, 0.92, 0.92), "gym": Color(0.6, 0.6, 0.65), "contest": Color(0.95, 0.8, 0.88), "league": Color(0.7, 0.68, 0.85),
	"cave": Color(0.4, 0.36, 0.32), "sewer": Color(0.35, 0.38, 0.35), "tower": Color(0.42, 0.38, 0.48), "mansion": Color(0.4, 0.3, 0.3),
	"power_plant": Color(0.55, 0.55, 0.5), "lab_ruins": Color(0.7, 0.7, 0.72), "victory_road": Color(0.45, 0.4, 0.36),
	"mine": Color(0.45, 0.38, 0.3), "villain_base": Color(0.25, 0.25, 0.3), "distortion": Color(0.35, 0.2, 0.45), "shipwreck": Color(0.35, 0.28, 0.22),
	"landmark": Color(0.85, 0.82, 0.78),
}
const DUNGEONS := ["cave", "sewer", "tower", "mansion", "power_plant", "lab_ruins", "victory_road", "mine", "villain_base", "distortion", "shipwreck"]
## Mazmorra real de varios pisos con jefe al final (mundo más lleno, acordado con
## Fernando 2026-10-10: "mazmorras y cuevas reales de varios pisos con tesoros y jefe").
## Por ahora solo la mina (ver _descend_mine, services.mine_boss_challenge); la gruta de
## cristal es otra cosa (sin pantalla de carga, se construye en el mundo abierto, no aquí).
const MINE_FLOORS := 3

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
		# Red de seguridad: si alguien cae bajo el piso (hueco de un modelo), vuelve a la entrada.
		elif player != null and current.has("spawn"):
			var spawn: Vector3 = current["spawn"]
			if player.global_position.y < spawn.y - 4.0:
				player.global_position = spawn
				player.velocity = Vector3.ZERO
				GameState.notice.emit("¡Cuidado! Volviste a la entrada.")
			var c := services.companion()
			if c != null and c.global_position.y < spawn.y - 4.0:
				c.global_position = spawn + Vector3(1.4, 0.2, 0.0)
				c.velocity = Vector3.ZERO


## Adentro: fondo oscuro sin cielo ni niebla, y menos luz del sol en mazmorras.
func _set_indoor_look(inside: bool, dungeon: bool) -> void:
	var environment_node := structures.world.get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node == null:
		return
	var environment := environment_node.environment
	environment.background_mode = Environment.BG_COLOR if inside else Environment.BG_SKY
	# Tono cálido tenue, nunca casi negro (auditoría 2026-10-11): aunque los muros ya
	# tapan el hueco de la entrada, cualquier rendija residual debe verse como penumbra
	# de interior, no como vacío.
	environment.background_color = Color(0.16, 0.13, 0.11)
	environment.fog_enabled = not inside
	# La ambiental del mundo toma el cielo (afuera se ve bien); adentro eso teñía de azul
	# hasta las superficies cerca del fondo (auditoría 2026-10-11): con el jugador dentro,
	# la ambiental usa un tono cálido fijo, acorde a la luz propia del interior.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if inside else Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.5, 0.44, 0.36)
	DayNight.interior_light = (0.35 if dungeon else 0.6) if inside else 1.0
	# Cámara: en salas con modelo real (techo de verdad, a veces de dos pisos como la
	# tienda y el Centro) se ajusta a la altura real del techo para no atravesarlo ni
	# quedar fuera del edificio; en las salas de piezas (sin techo, muros bajos estilo
	# HD-2D) y en mazmorras (a cielo abierto) se queda alta y lejana como antes.
	var rig := structures.world.get_parent().get_node_or_null("CameraRig") as CameraRig
	if rig != null and inside:
		rig.set("_zoom", current.get("cam_zoom", rig.zoom_max))
		rig.set("_pitch_deg", current.get("cam_pitch", 52.0))
		# Yaw de golpe (encontrado el 2026-10-11 al revisar las sondas): el jugador entra
		# siempre mirando hacia -Z (así se construyen _build_room y _build_dungeon: la
		# puerta/entrada queda en +Z y el cuarto se extiende hacia -Z), pero el yaw no se
		# reiniciaba y se quedaba con el de afuera, a veces mostrando una pared de frente en
		# vez del cuarto completo. rig.snap() (llamado justo después desde move_party_to) ya
		# fija posición y zoom de golpe; con esto también fija el yaw de golpe.
		rig.set("_yaw_deg", 0.0)


func _fade_to(alpha: float, seconds: float = 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished


## Entra a un interior. data es el edificio o el lugar; settlement puede ir vacío.
func enter(kind: String, settlement: Dictionary, data: Dictionary, return_point: Vector3) -> void:
	if busy or not current.is_empty():
		return
	busy = true
	AudioBus.play_sfx("door")
	await _fade_to(1.0)
	var root := Node3D.new()
	root.name = "Interior_%s" % kind
	root.position = ORIGIN
	add_child(root)
	current = {"kind": kind, "root": root, "return": return_point, "points": [], "actors": [], "place": data, "settlement": settlement, "floor": 1}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(data.get("x", 0)) + str(data.get("z", 0)) + kind) ^ structures.world.layout.seed
	var spawn: Vector3
	if kind in DUNGEONS:
		spawn = _build_dungeon(root, kind, data, rng)
	else:
		spawn = _build_room(root, kind, settlement, data, rng)
	current["spawn"] = spawn
	structures.world.interior_habitat = HABITATS.get(kind, SpeciesData.Habitat.MOUNTAIN)
	_set_indoor_look(true, kind in DUNGEONS)
	services.navigation_bake_interior(root)
	services.move_party_to(spawn)
	entered.emit(kind)
	await _fade_to(0.0)
	busy = false


## Sale del interior hacia point (la puerta de donde vino u otro lugar).
func exit_to(point: Vector3) -> void:
	if busy or current.is_empty():
		return
	busy = true
	AudioBus.play_sfx("door")
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
	if current.get("kind", "") == "mart":
		# La sala (y con ella el ladrón, los clientes y el ambiente de la tienda) se libera
		# abajo; sin esto, MartServices se quedaba con referencias a nodos ya liberados
		# (bug encontrado el 2026-10-11: "Trying to assign invalid previously freed
		# instance" cada cuadro al revisar al ladrón).
		services.mart.reset_room()
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


## Igual que _point pero público: MartServices y CenterServices construyen estantes,
## mostradores y puntos del segundo piso desde fuera de Interiors, y así el punto se
## limpia solo al salir (como cualquier otro de la sala).
func room_point(local: Vector3, prompt: String, action: Callable, radius: float = 2.2) -> void:
	_point(local, prompt, action, radius)


## Como _marker, pero utilizable desde MartServices/CenterServices.
func room_marker(local: Vector3, texture: Texture2D, size_m: float = 0.42) -> Sprite3D:
	return _marker(current["root"], local, texture, size_m)


## NPC humano del mundo (nunca de frente) en una posición de la sala actual, usable desde
## MartServices/CenterServices.
func room_npc(local: Vector3, trainer_id: String) -> Sprite3D:
	return _npc(current["root"], local, trainer_id)


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
	# Con modelo de B2W2, los muebles de cajas no hacen falta (el modelo ya los trae).
	if _modeled:
		return
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
## Interiores con modelos originales de B2W2 (art/models/b2w2_int/, acordado con Fernando
## el 2026-10-10). tools/fix_dae.py los deja listos para Godot.
const INTERIOR_MODELS := {
	"center": ["center"], "mart": ["mall"], "lab": ["lab_fennel"],
	"house": ["house_floccesy5", "house_humilau7", "house_mistralton3", "house_accumula2", "house_alder", "house_black", "house_route5", "house_route13", "house_player"], "cabin": ["house_hugh"],
	"gym": ["gym_aspertia", "gym_castelia", "gym_mistralton", "gym_icirrus", "gym_humilau", "gym_nacrene"],
	"league": ["e4_room2", "e4_room4", "e4_room1"], "contest": ["school_striaton"], "daycare": ["daycare"],
}
const INTERIOR_DIR := "res://art/models/b2w2_int/"
var _modeled := false
## Pruebas: fuerza una carpeta de modelo.
var force_model := ""


## Pone el modelo de la sala (centrado, piso en y = 0) con colisión. Devuelve su planta
## (ancho, fondo) en metros, o Vector2.ZERO si no hay modelo.
func _model_room(root: Node3D, kind: String, rng: RandomNumberGenerator, wall_color: Color) -> Vector2:
	var options: Array = INTERIOR_MODELS.get(kind, [])
	if options.is_empty():
		return Vector2.ZERO
	var folder: String = options[rng.randi() % options.size()]
	if force_model != "":
		folder = force_model
	var path := INTERIOR_DIR + folder + "/model.dae"
	if not ResourceLoader.exists(path):
		return Vector2.ZERO
	var scene := load(path) as PackedScene
	if scene == null:
		return Vector2.ZERO
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * BuildingModels.SCALE
	var box := AABB()
	var first := true
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	for node in meshes:
		var mesh := node as MeshInstance3D
		BuildingModels._fix_materials(mesh)
		var local := BuildingModels._local_transform(mesh, model) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	# El piso real: la superficie horizontal más grande (la caja del modelo incluye
	# paredes y zonas negras; usarla dejaba la entrada fuera del cuarto).
	var floor_rect := _floor_rect(model, meshes)
	if floor_rect.size == Vector3.ZERO:
		floor_rect = AABB(box.position * BuildingModels.SCALE, box.size * BuildingModels.SCALE)
	# Techo real sobre ese piso (los modelos de B2W2 son edificios de verdad, algunos de
	# dos pisos como la tienda y el Centro): sin esto la cámara alta y lejana de las salas
	# de piezas atravesaba el techo o el piso de arriba y se veía un amasijo de triángulos.
	var ceiling_info := _ceiling_info(model, meshes, floor_rect)
	var ceiling: float = ceiling_info["height"]
	var center := floor_rect.get_center()
	model.position = Vector3(-center.x, -floor_rect.position.y, -center.z)
	root.add_child(model)
	# Colisión: la geometría del modelo (paredes y muebles) como obstáculo, y un piso plano.
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var shape := mesh.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var body := StaticBody3D.new()
		body.collision_layer = WorldBuilder.LAYER_OBSTACLES
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		mesh.add_child(body)
	var size := Vector2(floor_rect.size.x, floor_rect.size.z)
	# Muros en todo el contorno: los modelos de la DS dejan abierto el lado de la entrada
	# y zonas negras (se ve el vacío de fuera). Antes eran solo colisión; ahora también
	# tapan la vista con un color parecido al de sus paredes (no hay textura real a mano).
	# El de la entrada va a la misma altura que los otros tres (si se dejaba bajo, con
	# pitch normal se veía un hueco negro grande arriba, reportado en la auditoría del
	# 2026-10-11): se tapa completo y se le pinta encima el hueco de la puerta para que
	# siga leyéndose como entrada, no como muro ciego.
	var half := size * 0.5
	var wall_height := maxf(ceiling + 1.5, 4.0)
	var wall_material := _material(wall_color)
	var walls := [[Vector3(size.x + 2.0, wall_height, 1.0), Vector3(0, wall_height * 0.5 - 0.3, -half.y - 0.5), false],
			[Vector3(size.x + 2.0, wall_height, 1.0), Vector3(0, wall_height * 0.5 - 0.3, half.y + 0.5), true],
			[Vector3(1.0, wall_height, size.y + 2.0), Vector3(-half.x - 0.5, wall_height * 0.5 - 0.3, 0), false],
			[Vector3(1.0, wall_height, size.y + 2.0), Vector3(half.x + 0.5, wall_height * 0.5 - 0.3, 0), false]]
	for wall: Array in walls:
		var fence := StaticBody3D.new()
		fence.collision_layer = WorldBuilder.LAYER_OBSTACLES
		var wall_shape := BoxShape3D.new()
		wall_shape.size = wall[0]
		var wall_collision := CollisionShape3D.new()
		wall_collision.shape = wall_shape
		wall_collision.position = wall[1]
		fence.add_child(wall_collision)
		root.add_child(fence)
		var wall_mesh := MeshInstance3D.new()
		var wall_box := BoxMesh.new()
		var is_entrance: bool = wall[2]
		wall_box.size = wall[0]
		wall_mesh.mesh = wall_box
		wall_mesh.material_override = wall_material
		wall_mesh.position = wall[1]
		root.add_child(wall_mesh)
		if is_entrance:
			# Hueco de puerta pintado: rectángulo oscuro centrado en el muro de entrada,
			# del piso hasta la altura de una puerta, para que se note dónde se entra/sale
			# (el tapete rojo de _exit_mark marca lo mismo a nivel de piso).
			var door_mesh := MeshInstance3D.new()
			var door_plane := BoxMesh.new()
			var door_height := minf(wall_height * 0.75, 2.4)
			door_plane.size = Vector3(2.4, door_height, 0.1)
			door_mesh.mesh = door_plane
			door_mesh.material_override = _material(wall_color.darkened(0.6))
			var inward := 1.0 if (wall[1] as Vector3).z > 0.0 else -1.0
			door_mesh.position = Vector3(0, door_height * 0.5 - 0.3, (wall[1] as Vector3).z - inward * 0.46)
			root.add_child(door_mesh)
	var ground := StaticBody3D.new()
	ground.collision_layer = WorldBuilder.LAYER_TERRAIN
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(size.x + 4.0, 1.0, size.y + 4.0)
	var floor_collision := CollisionShape3D.new()
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.5
	ground.add_child(floor_collision)
	root.add_child(ground)
	# Faldón del piso (mismo tono del muro, más oscuro): cubre cualquier rendija de vacío
	# que se asome bajo el modelo en los bordes.
	var apron := MeshInstance3D.new()
	var apron_mesh := BoxMesh.new()
	apron_mesh.size = Vector3(size.x + 6.0, 0.4, size.y + 6.0)
	apron.mesh = apron_mesh
	apron.material_override = _material(wall_color.darkened(0.3))
	apron.position.y = -0.3
	root.add_child(apron)
	# Cámara que cabe bajo el techo real (si no, se metía dentro del modelo o del piso de
	# arriba) y lámparas de techo propias: los modelos de B2W2 no traen luces, solo
	# geometría y texturas.
	var vertical := clampf(ceiling - 1.2 - 0.6, 0.8, 7.0)
	var horizontal := clampf(minf(size.x, size.y) * 0.45, 2.5, 9.0)
	current["cam_pitch"] = clampf(rad_to_deg(atan2(vertical, horizontal)), 14.0, 60.0)
	current["cam_zoom"] = clampf(sqrt(vertical * vertical + horizontal * horizontal), 3.0, 11.0)
	_ceiling_lamps(root, size, ceiling)
	# Segundo piso (tienda y Centro, acordado con Fernando el 2026-10-10): si el techo
	# detectado es en realidad la planta de arriba (losa ancha real, no el techo final del
	# edificio), se guarda su desplazamiento en el espacio de la sala (mismo origen que la
	# puerta y los puntos del piso de bajo) para que MartServices/CenterServices puedan
	# poner ahí el segundo mostrador, la zona de descanso o el club de combate.
	current["size"] = size
	var upper_rect: AABB = ceiling_info["rect"]
	if kind in ["mart", "center"] and upper_rect.size.x > 0.0:
		current["ceiling_y"] = ceiling
		current["upper_offset"] = Vector3(upper_rect.get_center().x - center.x, ceiling, upper_rect.get_center().z - center.z)
		current["upper_size"] = Vector2(upper_rect.size.x, upper_rect.size.z)
	return size


## Salida visible: tapete rojo brillante y flecha que sube y baja.
func _exit_mark(root: Node3D, door: Vector3) -> void:
	var mat := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.4, 1.6)
	mat.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.2, 0.25)
	material.emission_enabled = true
	material.emission = Color(0.85, 0.2, 0.25)
	material.emission_energy_multiplier = 0.4
	mat.material_override = material
	mat.position = door + Vector3(0, 0.04, 0.3)
	root.add_child(mat)
	var arrow := Label3D.new()
	arrow.text = "▼ SALIDA"
	arrow.font_size = 48
	arrow.outline_size = 12
	arrow.modulate = Color(1.0, 0.9, 0.4)
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.no_depth_test = true
	arrow.position = door + Vector3(0, 1.6, 0.3)
	root.add_child(arrow)
	var tween := arrow.create_tween().set_loops()
	tween.tween_property(arrow, "position:y", door.y + 1.9, 0.6)
	tween.tween_property(arrow, "position:y", door.y + 1.6, 0.6)


## Rectángulo del piso (en metros, coordenadas del modelo ya escalado): agrupa los
## triángulos que miran hacia arriba por altura y toma la altura con más área.
func _floor_rect(model: Node3D, meshes: Array) -> AABB:
	var by_height := {}
	var rects := {}
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var xform := model.transform * BuildingModels._local_transform(mesh_instance, model)
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for t in range(0, count - 2, 3):
				var a := xform * vertices[indices[t] if not indices.is_empty() else t]
				var b := xform * vertices[indices[t + 1] if not indices.is_empty() else t + 1]
				var c := xform * vertices[indices[t + 2] if not indices.is_empty() else t + 2]
				var normal := (b - a).cross(c - a)
				var area := normal.length() * 0.5
				if area < 0.01 or absf(normal.normalized().y) < 0.95:
					continue
				var level := snappedf((a.y + b.y + c.y) / 3.0, 0.2)
				by_height[level] = float(by_height.get(level, 0.0)) + area
				var tri := AABB(a, Vector3.ZERO).expand(b).expand(c)
				rects[level] = (rects[level] as AABB).merge(tri) if rects.has(level) else tri
	if by_height.is_empty():
		return AABB()
	# Algunos modelos traen un fondo decorativo enorme muy lejos de la sala (terreno,
	# montañas) que por su tamaño ganaría cualquier comparación de área: se descarta
	# primero quedándose con el grupo de alturas más poblado (donde están el piso, los
	# muebles y los escalones) y aislando lo que esté muy lejos de ese grupo.
	var levels: Array = by_height.keys()
	levels.sort()
	var main_levels := _main_height_cluster(levels)
	var max_area := 0.0
	for level: float in main_levels:
		max_area = maxf(max_area, by_height[level])
	if max_area <= 0.0:
		return AABB()
	# El piso real casi siempre queda cerca de la altura 0 del modelo (es el origen que
	# usó quien lo hizo). Entre los niveles anchos (al menos 15 % del área del más grande
	# del grupo, para admitir el verdadero piso aunque no sea el mayor) se toma el más
	# cercano a 0.
	var best_level: float = main_levels[0]
	var best_distance := INF
	for level: float in main_levels:
		if float(by_height[level]) < max_area * 0.15:
			continue
		if absf(level) < best_distance:
			best_distance = absf(level)
			best_level = level
	return rects[best_level]


## De una lista de alturas ya ordenada, el grupo con más alturas distintas seguidas sin
## un salto grande (10 m) entre una y la siguiente. Los muebles, escalones y pisos de un
## edificio real quedan cerca entre sí; un plano de fondo aislado queda del otro lado de
## un salto así.
func _main_height_cluster(levels: Array) -> Array:
	if levels.size() <= 1:
		return levels
	var groups: Array = [[levels[0]]]
	for i in range(1, levels.size()):
		if float(levels[i]) - float(levels[i - 1]) > 10.0:
			groups.append([])
		(groups[groups.size() - 1] as Array).append(levels[i])
	var best: Array = groups[0]
	for group: Array in groups:
		if group.size() > best.size():
			best = group
	return best


## Altura del techo sobre floor_rect (metros) y, si lo hay, el rectángulo del piso de
## arriba (metros, mismo espacio sin desplazar que floor_rect): el primer nivel
## horizontal ancho por encima de la cabeza. Los modelos de B2W2 traen edificios de dos
## pisos, como la tienda y el Centro (segundo piso con mostrador propio y zona de
## descanso, acordado con Fernando el 2026-10-10), con el piso de arriba haciendo de
## techo del de abajo: ese mismo nivel es la planta del segundo piso. Si no encuentra uno
## claro (sala abierta o con un solo trozo de techo pequeño), un valor generoso para no
## limitar de más la cámara y sin rectángulo de piso de arriba.
const DEFAULT_CEILING := 6.0
func _ceiling_info(model: Node3D, meshes: Array, floor_rect: AABB) -> Dictionary:
	var floor_level := floor_rect.position.y
	var floor_area := floor_rect.size.x * floor_rect.size.z
	if floor_area <= 0.0:
		return {"height": DEFAULT_CEILING, "rect": AABB()}
	var by_height := {}
	var rects := {}
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var xform := model.transform * BuildingModels._local_transform(mesh_instance, model)
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for t in range(0, count - 2, 3):
				var a := xform * vertices[indices[t] if not indices.is_empty() else t]
				var b := xform * vertices[indices[t + 1] if not indices.is_empty() else t + 1]
				var c := xform * vertices[indices[t + 2] if not indices.is_empty() else t + 2]
				var normal := (b - a).cross(c - a)
				var area := normal.length() * 0.5
				if area < 0.01 or absf(normal.normalized().y) < 0.95:
					continue
				var level := snappedf((a.y + b.y + c.y) / 3.0, 0.2)
				# Más alto que cualquier mueble (mostradores, estantes, mesas): esos suman
				# área entre varios y antes se confundían con un techo bajo.
				if level <= floor_level + 1.8:
					continue
				by_height[level] = float(by_height.get(level, 0.0)) + area
				var tri := AABB(a, Vector3.ZERO).expand(b).expand(c)
				rects[level] = (rects[level] as AABB).merge(tri) if rects.has(level) else tri
	var levels: Array = by_height.keys()
	levels.sort()
	for level: float in levels:
		var r: AABB = rects[level]
		# Debe cubrir casi todo el piso en ambos lados (una sola losa ancha), no varios
		# muebles sueltos a la misma altura que por separado suman bastante área.
		if r.size.x * r.size.z >= floor_area * 0.2 and r.size.x >= floor_rect.size.x * 0.5 and r.size.z >= floor_rect.size.z * 0.5:
			return {"height": level - floor_level, "rect": r}
	return {"height": DEFAULT_CEILING, "rect": AABB()}


## Lámparas de techo cálidas: los modelos de B2W2 solo traen geometría y texturas, sin
## luces propias; sin esto el interior depende del sol (que de noche casi no ilumina).
func _ceiling_lamps(root: Node3D, size: Vector2, ceiling: float) -> void:
	var height := clampf(ceiling - 0.4, 1.6, 5.5)
	var cols := clampi(int(size.x / 7.0) + 1, 1, 4)
	var rows := clampi(int(size.y / 7.0) + 1, 1, 4)
	var range_m := maxf(size.x, size.y) / maxf(cols, rows) * 0.9 + 3.0
	for cx in cols:
		for cz in rows:
			var x := (cx + 0.5) / cols * size.x - size.x * 0.5
			var z := (cz + 0.5) / rows * size.y - size.y * 0.5
			_light(root, Vector3(x, height, z), Color(1.0, 0.92, 0.78), range_m, 1.5)


func _room_shell(root: Node3D, size: Vector2, floor_color: Color, wall_color: Color) -> void:
	_block(root, Vector3(size.x + 2, 1.0, size.y + 2), Vector3(0, -0.5, 0), floor_color, true, 0.0, WorldBuilder.LAYER_TERRAIN)
	_block(root, Vector3(size.x + 2, WALL_H, 1), Vector3(0, WALL_H * 0.5, -size.y * 0.5 - 0.5), wall_color)
	# El muro del lado de la entrada (hacia la cámara) es bajo para no tapar la sala.
	_block(root, Vector3(size.x + 2, 0.7, 1), Vector3(0, 0.35, size.y * 0.5 + 0.5), wall_color)
	_block(root, Vector3(1, WALL_H, size.y + 2), Vector3(-size.x * 0.5 - 0.5, WALL_H * 0.5, 0), wall_color)
	_block(root, Vector3(1, WALL_H, size.y + 2), Vector3(size.x * 0.5 + 0.5, WALL_H * 0.5, 0), wall_color)
	_light(root, Vector3(0, 4.5, 0), Color(1.0, 0.95, 0.85), maxf(size.x, size.y) * 1.2, 1.6)


## Personaje (NPC) con la primera celda de su hoja de entrenador (aspecto de BW2 o,
## para los héroes, su propia hoja). Nunca sprites de frente/batalla en el mundo.
func _npc(root: Node3D, at: Vector3, trainer_id: String = "") -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.position = at
	# Aspectos de BW2 (NpcLooks); los héroes no se usan como figurantes.
	var own := NpcLooks.GENDER.has(trainer_id) or trainer_id.begins_with("lider_") or trainer_id.begins_with("alto_")
	var sheet := NpcLooks.sheet(trainer_id) if own else PlayerCharacters.sheet(trainer_id)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 0, sheet.get_width() / 3.0, sheet.get_height() / 8.0)
	sprite.texture = atlas
	sprite.pixel_size = 0.057
	sprite.offset.y = atlas.region.size.y * 0.5
	root.add_child(sprite)
	return sprite


## Pokémon de interior solo como mascota de alguien (el Kecleon de la tienda, el
## Chansey/Blissey del Centro): su hoja de caminar de mundo, nunca su sprite de frente.
func _pokemon_pet(root: Node3D, at: Vector3, species_id: String) -> void:
	var species := MenuStyle.species(species_id)
	if species == null or species.overworld_sheet == null:
		return
	var sprite := DirectionalSprite.new()
	sprite.position = at
	root.add_child(sprite)
	sprite.setup(species.overworld_sheet, 2, 4, PokemonActor.PIXEL_SIZE * species.size_scale * 32.0 / species.overworld_cell, species.foot_offset_px)


## Ícono flotante sobre un estante o mueble (objeto real a la venta, premio de la
## ruleta...): billboard que siempre mira a la cámara, como el de los tesoros de mazmorra.
func _marker(root: Node3D, at: Vector3, texture: Texture2D, size_m: float = 0.42) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = size_m / maxf(texture.get_width(), 1.0)
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.position = at
	root.add_child(sprite)
	return sprite


## Punto del segundo piso (tienda y Centro): local + el desplazamiento real del piso de
## arriba detectado por _model_room(). Vector3.INF si esta sala no tiene uno (modelo sin
## segundo piso claro): quien llama debe comprobarlo con has_upper_floor() antes de usarlo.
func has_upper_floor() -> bool:
	return current.has("upper_offset")


func upper_point(local: Vector3) -> Vector3:
	if not has_upper_floor():
		return Vector3.INF
	return (current["upper_offset"] as Vector3) + local


func upper_size() -> Vector2:
	return current.get("upper_size", Vector2.ZERO)


## Salas de edificios. Devuelve el punto de aparición (relativo al mundo).
func _build_room(root: Node3D, kind: String, settlement: Dictionary, building: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var size: Vector2 = {"center": Vector2(18, 14), "mart": Vector2(14, 11), "house": Vector2(10, 9), "cabin": Vector2(8, 7),
			"lab": Vector2(16, 12), "gym": Vector2(26, 30), "contest": Vector2(22, 18), "league": Vector2(30, 36),
			"landmark": Vector2(16, 13)}.get(kind, Vector2(12, 10))
	var wall := Color(0.95, 0.93, 0.88)
	if kind in ["gym", "league"]:
		wall = Color(0.55, 0.55, 0.62)
	elif kind == "cabin":
		wall = Color(0.5, 0.36, 0.24)
	_modeled = false
	var model_size := _model_room(root, kind, rng, wall)
	if model_size != Vector2.ZERO:
		size = model_size
		_modeled = true
	else:
		_room_shell(root, size, FLOORS.get(kind, Color(0.7, 0.7, 0.7)), wall)
	var door := Vector3(0, 0, size.y * 0.5 - (2.2 if _modeled else 1.0))
	# Puerta local (MartServices la usa para los clientes que entran y salen de verdad por
	# ahí; ver "shelves" más abajo, donde cada estante se registra para que caminen a uno).
	current["door"] = door
	current["shelves"] = [] as Array[Vector3]
	_block(root, Vector3(2.4, 0.05, 1.4), door + Vector3(0, 0.02, 0.2), Color(0.6, 0.2, 0.2), false)
	_exit_mark(root, door)
	# Salir con E o caminando hacia la salida (como al entrar).
	(current["points"] as Array).append(structures.add_point(ORIGIN + door + Vector3.UP * 0.5, "Salir", func() -> void: exit_to(current["return"]), 2.0, Vector3(0, 0, 1)))
	var back := -size.y * 0.5 + 2.0
	match kind:
		"center":
			_block(root, Vector3(8, 1.1, 1.2), Vector3(0, 0.55, back + 1.0), Color(0.9, 0.4, 0.45))
			# La enfermera (humana) atiende el mostrador; un Chansey o Blissey la ayuda
			# junto a la máquina, de mascota, con su hoja de caminar de mundo (nunca de frente).
			# Curación clásica animada (entregas el equipo y las Balls se encienden una a
			# una), más la revisión de vínculo y salud, el recordador y el café, todo
			# acordado con Fernando el 2026-10-10.
			_npc(root, Vector3(0, 0, back), NpcLooks.for_role("enfermera", rng))
			_pokemon_pet(root, Vector3(1.6, 0, back + 0.6), "chansey" if rng.randf() < 0.5 else "blissey")
			_point(Vector3(0, 0.5, back + 2.4), "Curar a tu equipo", services.center_services.animated_heal.bind(current["return"]))
			_point(Vector3(1.6, 0.5, back + 2.4), "Hablar con la enfermera (vínculo y salud)", services.center_services.checkup)
			_block(root, Vector3(1.4, 1.6, 1.0), Vector3(size.x * 0.5 - 1.5, 0.8, back), Color(0.3, 0.35, 0.45), true, 0.2)
			_point(Vector3(size.x * 0.5 - 1.5, 0.5, back + 1.6), "Usar el PC (Caja)", services.open_menu_tab.bind("Caja"))
			_point(Vector3(size.x * 0.5 - 3.0, 0.5, back + 1.6), "Recordador de movimientos", services.center_services.move_reminder)
			var trade_x := clampf(-size.x * 0.5 + 2.0, -6.0, -1.5)
			_npc(root, Vector3(trade_x, 0, back + 1.0), "cientifica")
			_point(Vector3(trade_x, 0.5, back + 2.2), "Mostrador de intercambios del día", services.center_services.trade_counter, 1.8)
			# Café y zona de descanso: la máquina de bebidas y un entrenador que platica o
			# acepta un combate amistoso mientras su equipo descansa.
			var cafe_at := Vector3(0, 0, back + size.y * 0.45)
			_point(cafe_at + Vector3(0, 0.5, 0), "Café ($%d)" % CenterServices.CAFE_PRICE, services.center_services.cafe, 1.8)
			var rest_look := NpcLooks.pick(["joven_a", "chica_a", "dama_a", "guay_a"], rng)
			var rest_at := Vector3(2.4, 0, back + size.y * 0.45)
			_npc(root, rest_at, rest_look)
			_point(rest_at + Vector3(0, 0.5, 1.2), "Hablar con el entrenador que descansa", services.center_services.resting_trainer.bind(rest_look), 1.8)
			# Sala de entrenamiento con muñecos y taquilla de excursiones.
			var train_at := Vector3(-2.6, 0, back + size.y * 0.6)
			_point(train_at, "Sala de entrenamiento (muñecos)", services.center_services.training_room, 1.8)
			var excursion_at := Vector3(2.8, 0, back + size.y * 0.65)
			_npc(root, excursion_at, "marinero")
			_point(excursion_at + Vector3(0, 0.5, 1.2), "Taquilla de excursiones ($%d)" % CenterServices.EXCURSION_PRICE, services.center_services.excursion_desk, 1.8)
			# Cabina de fotos (queda en la Ficha) y tablón de la región.
			_point(Vector3(-size.x * 0.5 + 1.6, 0.5, back + size.y * 0.3), "Cabina de fotos con tu compañero", services.center_services.photo_booth, 1.6)
			_point(Vector3(size.x * 0.5 - 1.6, 0.5, back + size.y * 0.3), "Tablón de la región", services.center_services.region_board.bind(settlement), 1.6)
			# Visita ocasional: el líder de la ciudad, un héroe no elegido que hoy anda por
			# aquí (Heroes.location) o el rival, curando a su equipo; con quien se puede
			# platicar o pedir un combate amistoso (completando la simplificación anotada
			# en docs/decisiones_sin_preguntar.md).
			var visitor := services.center_services.maybe_visitor(settlement)
			if not visitor.is_empty():
				var visitor_at := Vector3(-1.2, 0, back + size.y * 0.2)
				_npc(root, visitor_at, visitor["sprite_id"])
				var verb: String = {"leader": "al líder", "hero": "a", "rival": "al rival"}.get(visitor["kind"], "a")
				_point(visitor_at + Vector3(0, 0.5, 1.2), "Hablar con %s %s" % [verb, visitor["name"]], services.center_services.talk_visitor.bind(visitor), 1.8)
			# Segundo piso real del modelo: club de combate (retos amistosos con tabla de
			# récords de racha) y más zona de descanso.
			if has_upper_floor():
				var up_size := upper_size()
				var club_at := upper_point(Vector3(0, 0, -minf(up_size.y, 10.0) * 0.1))
				var ref_look := NpcLooks.pick(["karateka_a", "karateka_b"], rng)
				_npc(root, club_at, ref_look)
				_point(club_at + Vector3(0, 0.5, 1.4), "Club de combate (retos amistosos)", services.center_services.combat_club, 1.8)
				_point(upper_point(Vector3(0, 0, minf(up_size.y, 10.0) * 0.3)), "Zona de descanso de arriba.",
						func() -> void: GameState.notice.emit("Te sientas un momento en la zona de descanso de arriba."), 1.8)
		"mart":
			_block(root, Vector3(5, 1.1, 1.2), Vector3(-3, 0.55, back + 1.0), Color(0.3, 0.5, 0.85))
			# El dependiente general (humano) atiende el mostrador de abajo; el Kecleon es
			# su mascota, no vende. Todas las funciones nuevas (tarjeta de puntos, tablón,
			# estantes, niño, pedidos, bebidas, regalos, ladrón...) viven en MartServices.
			_npc(root, Vector3(-3, 0, back), NpcLooks.for_role("vendedor", rng))
			_pokemon_pet(root, Vector3(-1.4, 0, back + 0.6), "kecleon")
			_point(Vector3(-3, 0.5, back + 2.4), "Comprar y vender", services.mart.open_counter.bind(settlement, "general"))
			_point(Vector3(1.4, 0.5, back + 2.4), "Tablón de anuncios", services.mart.open_board.bind(settlement))
			_point(Vector3(2.9, 0.5, back + 2.4), "Mostrador de regalos", services.mart.gift_counter)
			_point(Vector3(4.4, 0.5, back + 2.4), "Pedidos por encargo", services.mart.open_orders.bind(settlement))
			var drink_x := clampf(size.x * 0.5 - 1.2, 2.0, 6.0)
			_point(Vector3(drink_x, 0.5, back + size.y * 0.35), "Máquina de bebidas ($%d)" % MartServices.DRINK_PRICE, services.mart.drink_machine, 1.8)
			var kid_at := Vector3(-drink_x, 0, back + size.y * 0.35)
			_npc(root, kid_at, "nino")
			_point(kid_at + Vector3(0, 0.5, 1.2), "Hablar con el niño", services.mart.kid_corner.bind(settlement), 1.8)
			# Estantes con objetos reales (ícono flotante; al acercarte dice qué es y su
			# precio y lo compras ahí): repartidos por las dos paredes laterales.
			var shelf_x := clampf(size.x * 0.5 - 1.0, 2.0, 6.5)
			var shelf_depths := [back + size.y * 0.55, back + size.y * 0.75]
			var shown_shelves: Array = MartServices.GENERAL_SHELVES.slice(0, 4)
			for i in shown_shelves.size():
				var z: float = shelf_depths[i / 2]
				if z > size.y * 0.5 - 1.8:
					continue
				var side := -1.0 if i % 2 == 0 else 1.0
				services.mart.place_shelf(Vector3(side * shelf_x, 0, z), settlement, shown_shelves[i])
			# Dependiente de la ciudad (MT, Balls especiales y comida regional) y sus
			# estantes, en el segundo piso real del modelo (mostrador propio y zona de
			# descanso, acordado con Fernando el 2026-10-10).
			if has_upper_floor():
				var up_size := upper_size()
				var counter_up := upper_point(Vector3(0, 0, -minf(up_size.y, 10.0) * 0.2))
				_npc(root, counter_up, NpcLooks.for_role("vendedor", rng))
				_point(counter_up + Vector3(0, 0.5, 1.4), "Comprar: MT, Balls especiales y comida de la ciudad", services.mart.open_counter.bind(settlement, "city"), 1.8)
				var up_shelf_x := clampf(up_size.x * 0.5 - 1.0, 1.6, 6.0)
				var up_shown: Array = MartServices.CITY_SHELVES.slice(0, 2)
				for i in up_shown.size():
					var side := -1.0 if i == 0 else 1.0
					services.mart.place_shelf(upper_point(Vector3(side * up_shelf_x, 0, minf(up_size.y, 10.0) * 0.15)), settlement, up_shown[i])
				_point(upper_point(Vector3(0, 0, minf(up_size.y, 10.0) * 0.3)), "Zona de descanso: aquí los clientes toman un respiro.",
						func() -> void: GameState.notice.emit("Te sientas un momento en la zona de descanso de arriba."), 1.8)
			services.mart.start_ambient(root)
			services.mart.maybe_spawn_thief(settlement, root, Vector3(shelf_x * 0.6, 0, back + size.y * 0.6), door)
		"house", "cabin":
			_block(root, Vector3(2.0, 0.6, 3.0), Vector3(size.x * 0.5 - 1.6, 0.3, back + 0.6), Color(0.85, 0.85, 0.95))
			_point(Vector3(size.x * 0.5 - 1.6, 0.5, back + 2.4), "Dormir (hasta la mañana)", services.rest.bind(current["return"]))
			_block(root, Vector3(2.0, 0.9, 1.4), Vector3(-1.5, 0.45, 0), Color(0.55, 0.38, 0.25))
			var resident := NpcLooks.for_role("vecino", rng)
			_npc(root, Vector3(-3.4, 0, -0.5), resident)
			_point(Vector3(-3.4, 0.5, 0.8), "Hablar", services.talk_resident.bind(settlement, building, resident))
			# En las ciudades, algunas casas son de tutores de movimientos.
			if settlement.get("kind", "") == "city" and int(building.get("color", 0)) % 2 == 0:
				_npc(root, Vector3(2.6, 0, -1.5), "abuelo_a")
				_point(Vector3(2.6, 0.5, -0.2), "Tutor de movimientos ($%d)" % TownServices.TUTOR_PRICE, services.tutor)
		"lab":
			for i in 3:
				_block(root, Vector3(3.0, 1.0, 1.2), Vector3(-5 + i * 5, 0.5, back + 1.5), Color(0.85, 0.88, 0.92))
			# El profesor (de 8 a 19 h, si no salió de viaje) y su asistente (siempre).
			var professor := services.main().get_node_or_null("Professor") as Professor
			if professor == null or professor.in_lab():
				_npc(root, Vector3(0, 0, back + 3.2), Professor.look())
				_point(Vector3(0, 0.5, back + 4.5), "Hablar con el Prof. %s" % GameState.professor, services.talk_professor)
			_npc(root, Vector3(5.0, 0, back + 4.0), "doctor")
			if professor != null:
				_point(Vector3(5.0, 0.5, back + 5.3), "Hablar con la asistente", professor.talk_assistant.bind(services))
		"gym":
			_block(root, Vector3(size.x - 6, 0.05, size.y - 10), Vector3(0, 0.03, -1), Color(0.75, 0.75, 0.55), false)
			# El líder de la región al fondo y 2 entrenadores del gimnasio a los lados.
			var arena := ORIGIN + Vector3(0, 0.3, -2)
			var leader_at := Vector3(0, 0, back + 1.0)
			var leader := structures.leader_of(settlement)
			# El líder solo está de 9 a 15 h (y no el día que viaja); si no, el guía dice dónde anda.
			if services.leader_in_gym(settlement):
				_npc(root, leader_at, Leaders.look(leader))
				_point(leader_at + Vector3(0, 0.5, 1.6), "Hablar con el líder %s (tipo %s)" % [Leaders.name_of(leader), Leaders.type_name(leader)],
						services.talk_leader.bind(settlement, arena))
			var guide_at := Vector3(-3.0, 0, size.y * 0.5 - (4.0 if _modeled else 3.0))
			_npc(root, guide_at, "joven_c")
			_point(guide_at + Vector3(0, 0.5, 1.2), "Hablar con el guía del gimnasio", services.ask_leader.bind(settlement), 1.8)
			for slot in 2:
				var look := NpcLooks.pick(["guay_a", "guay_b", "guay_chica", "karateka_a"], rng)
				var at := Vector3(-4.5 if slot == 0 else 4.5, 0, back + size.y * 0.42)
				_npc(root, at, look)
				_point(at + Vector3(0, 0.5, 1.4), "Retar al entrenador del gimnasio", services.gym_trainer_challenge.bind(settlement, slot, look, arena))
			_light(root, Vector3(0, 4.5, -8), Color(1, 1, 1), 30.0, 1.5)
		"league":
			_block(root, Vector3(size.x - 6, 0.05, size.y - 10), Vector3(0, 0.03, -1), Color(0.75, 0.75, 0.55), false)
			# Alto Mando (4) en semicírculo y el Campeón (héroe no elegido) al fondo; en orden.
			services.reset_league()
			var arena := ORIGIN + Vector3(0, 0.3, -1)
			var members := services.league_members()
			for slot in members.size():
				var id: String = members[slot]
				var at := Vector3(0, 0, back + 0.5)
				if slot < members.size() - 1:
					at = Vector3(-7.5 + slot * 5.0, 0, back + 4.5 + absf(slot - 1.5) * 1.6)
				var champion := id.begins_with("hero:")
				_npc(root, at, id.trim_prefix("hero:") if champion else Leaders.look(id))
				var title := ("Campeón " + String(PlayerCharacters.find(id.trim_prefix("hero:"))["name"])) if champion else ("Alto Mando " + Leaders.name_of(id))
				_point(at + Vector3(0, 0.5, 1.5), "Hablar con %s" % title, services.league_talk.bind(slot, arena), 1.8)
			_light(root, Vector3(0, 4.5, -8), Color(1, 1, 1), 30.0, 1.5)
		"contest":
			_block(root, Vector3(12, 0.8, 5), Vector3(0, 0.4, back + 2.0), Color(0.85, 0.55, 0.7))
			_npc(root, Vector3(6, 0, back + 6.0), "guay_chica")
			_point(Vector3(6, 0.5, back + 7.4), "Participar en el concurso", services.contest.bind(settlement))
		"landmark":
			# Edificio único por tema (pueblos ×2 con identidad, 2026-10-11): 3 exhibidores
			# (pedestal + vitrina) o, en el casino, máquinas tragamonedas; un encargado y un
			# solo punto de interacción (ver TownServices.landmark_visit).
			var sub: String = building.get("sub_kind", "library")
			var is_casino := sub == "casino"
			for i in 3:
				var at := Vector3(-4.0 + i * 4.0, 0, back + 2.2)
				if is_casino:
					_block(root, Vector3(1.1, 1.3, 0.8), at + Vector3(0, 0.65, 0), Color(0.3, 0.2, 0.35), true, 0.3)
				else:
					_block(root, Vector3(1.0, 0.9, 1.0), at + Vector3(0, 0.45, 0), Color(0.75, 0.72, 0.65))
					_block(root, Vector3(0.8, 0.6, 0.8), at + Vector3(0, 1.05, 0), Color(0.6, 0.75, 0.85, 0.5), false, 0.1)
			var clerk_look := NpcLooks.for_role("vendedor" if is_casino else "investigador", rng)
			_npc(root, Vector3(0, 0, back), clerk_look)
			_point(Vector3(0, 0.5, back + 1.6), "Jugar en la máquina ($%d)" % TownServices.CASINO_PRICE if is_casino else "Ver los exhibidores",
					services.landmark_visit.bind(settlement, building), 2.0)
	# Las mazmorras sí usan bloques: se apaga el modo modelo al terminar la sala.
	_modeled = false
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
			"power_plant": Color(1.0, 0.95, 0.6), "lab_ruins": Color(0.7, 0.9, 1.0), "villain_base": Color(1.0, 0.3, 0.3),
			"distortion": Color(0.8, 0.3, 1.0), "shipwreck": Color(0.4, 0.7, 1.0)}.get(kind, Color(1.0, 0.85, 0.6))
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
	var floor: int = current.get("floor", 1)
	if kind == "villain_base":
		_point(exit_local + Vector3(0, 0.5, -CELL * 0.35 + 1.5), "Enfrentar al líder del %s" % GameState.villain_team, services.villain_confront.bind(ORIGIN + exit_local + Vector3(0, 0.3, 2.5)), 2.0)
	elif kind == "mine" and floor < MINE_FLOORS:
		# Mazmorra de varios pisos (mundo más lleno, 2026-10-11): bajar regenera la mina
		# con otro recorrido (mismo cuarto, otro piso) hasta llegar al fondo.
		_point(exit_local + Vector3(0, 0.5, -CELL * 0.35), "Bajar al piso %d de la mina" % (floor + 1), _descend_mine, 1.8)
		far_exit = Vector3.INF
	elif kind == "mine" and floor >= MINE_FLOORS and not services.mine_boss_done(place):
		_point(exit_local + Vector3(0, 0.5, -CELL * 0.35), "Enfrentar al guardián de la mina", services.mine_boss_challenge.bind(place, ORIGIN + exit_local + Vector3(0, 0.3, -2.5)), 2.0)
		far_exit = Vector3.INF
	if far_exit != Vector3.INF:
		var label: String = {"victory_road": "Salir frente a la Liga Pokémon", "distortion": "Salir por el otro portal"}.get(kind, "Salida al otro lado")
		_point(exit_local + Vector3(0, 0.5, -CELL * 0.35), label, func() -> void: exit_to(far_exit), 1.8)
	elif kind != "villain_base" and not (kind == "mine" and (floor < MINE_FLOORS or not services.mine_boss_done(place))):
		_point(exit_local + Vector3(0, 0.5, -CELL * 0.35), "Salir", func() -> void: exit_to(current["return"]), 1.8)
	# Tesoros (uno por día del juego y por piso) y Pokémon propios.
	var cells: Array = open.keys()
	for i in 2:
		var c: Vector2i = cells[rng.randi() % cells.size()]
		var at: Vector3 = to_local.call(c) + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
		services.place_treasure(self, root, at, "%s:%d:%d:f%d" % [kind, int(place.get("id", 0)), i, floor], rng)
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


## Baja al siguiente piso de la mina (mazmorra de varios pisos, 2026-10-11): se regenera
## el mismo cuarto con otro recorrido (reseedeado con el número de piso) sin salir del
## interior ni volver a cargar la pantalla de fundido.
func _descend_mine() -> void:
	if current.is_empty() or current["kind"] != "mine" or busy:
		return
	busy = true
	current["floor"] = int(current.get("floor", 1)) + 1
	for point: Dictionary in current["points"]:
		structures.remove_point(point)
	current["points"] = []
	for actor in current["actors"]:
		if is_instance_valid(actor):
			(actor as Node).queue_free()
	current["actors"] = []
	var root: Node3D = current["root"]
	for child in root.get_children():
		child.queue_free()
	services.navigation_free_interior()
	await get_tree().process_frame
	var place: Dictionary = current["place"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(place.get("x", 0)) + str(place.get("z", 0)) + "mine") ^ structures.world.layout.seed ^ (int(current["floor"]) * 104729)
	var spawn := _build_dungeon(root, "mine", place, rng)
	current["spawn"] = spawn
	services.navigation_bake_interior(root)
	services.move_party_to(spawn)
	GameState.notice.emit("Bajas al piso %d de la mina." % int(current["floor"]))
	busy = false


## Adónde sale la otra boca: la cueva pareja o la Liga (Calle Victoria).
func _far_exit(kind: String, place: Dictionary) -> Vector3:
	var target: Dictionary = {}
	if kind == "distortion":
		for other: Dictionary in structures.world.layout.places_of("portal"):
			if other["id"] != place.get("id", -1):
				target = other
				break
		if not target.is_empty():
			var px := float(target["x"]) + 3.5
			var pz := float(target["z"])
			return Vector3(px, structures.world.height_at(px, pz) + 0.5, pz)
		return Vector3.INF
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
