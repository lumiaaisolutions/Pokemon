class_name Structures
extends Node3D
## Edificios de los pueblos y ciudades (Centro Pokémon, Tienda, Gimnasio, Sala de
## Concursos, Laboratorio, casas, cabañas, carpas, torres y alcantarillas) y los lugares
## especiales de la región (ruinas, cuevas, santuarios, torre, mansión, central, barco
## hundido, faro, laboratorio en ruinas, árbol gigante, Liga, ruinas flotantes,
## portales, Zona Safari, guardería, aguas termales, zonas Alfa y fuentes), hechos con
## piezas simples de colores. También lleva los puntos de interacción del mundo: cerca de
## uno, el HUD muestra la acción y "interact" la ejecuta (ver Interiors y TownServices).

signal prompt_changed(text: String)

const INTERACT_RADIUS := 2.6
const VIEW_DISTANCE := 520.0
const PLACE_NAMES := {
	"ruins": "Ruinas Antiguas", "cave": "Cueva", "sanctuary": "Santuario", "tower": "Torre Espectral", "mansion": "Mansión Abandonada",
	"power_plant": "Central Eléctrica", "shipwreck": "Barco Hundido", "lighthouse": "Faro", "lab_ruins": "Laboratorio en Ruinas",
	"giant_tree": "Árbol Milenario", "league": "Liga Pokémon", "floating_ruins": "Ruinas Flotantes", "portal": "Portal",
	"safari": "Zona Safari", "daycare": "Guardería Pokémon", "hot_spring": "Aguas Termales", "alpha": "Territorio Alfa",
	"fountain": "Fuente Sanadora", "volcano": "Volcán", "victory_road": "Calle Victoria",
	"ranch": "Rancho", "berry_farm": "Huerto de Bayas", "mine": "Mina Abandonada", "grotto": "Gruta de Cristal",
	"villain_base": "Base Secreta", "merchant": "Comerciante Viajero", "oasis": "Oasis",
}
const BUILDING_NAMES := {
	"center": "Centro Pokémon", "mart": "Tienda Pokémon", "gym": "Gimnasio", "contest": "Sala de Concursos", "lab": "Laboratorio",
	"house": "Casa", "cabin": "Cabaña", "tent": "Carpa", "tower_small": "Torre del Reloj", "manhole": "Alcantarilla",
}
const HOUSE_WALLS := [Color(0.93, 0.88, 0.78), Color(0.85, 0.9, 0.95), Color(0.95, 0.85, 0.8), Color(0.88, 0.93, 0.82), Color(0.96, 0.93, 0.85), Color(0.86, 0.8, 0.72)]
const HOUSE_ROOFS := [Color(0.75, 0.3, 0.25), Color(0.3, 0.45, 0.7), Color(0.35, 0.55, 0.35), Color(0.55, 0.4, 0.3), Color(0.6, 0.35, 0.55), Color(0.4, 0.4, 0.45)]

var world: WorldBuilder
var services: TownServices
## Puntos de interacción: {"pos": Vector3, "radius", "prompt", "action": Callable}.
var _points: Array[Dictionary] = []
var _nearest: Dictionary = {}
var _materials := {}
var _player: Node3D
var _door_cooldown := 0.0


func build(builder: WorldBuilder) -> void:
	world = builder
	services = TownServices.new()
	services.name = "Services"
	services.structures = self
	add_child(services)
	var buildings := Node3D.new()
	buildings.name = "Buildings"
	add_child(buildings)
	for settlement: Dictionary in world.layout.settlements:
		for building: Dictionary in settlement["buildings"]:
			buildings.add_child(_building(settlement, building))
		# Identidad del pueblo: monumento, plaza y objetos de su tema.
		TownIdentity.decorate(self, buildings, settlement)
	var landmarks := Node3D.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	for place: Dictionary in world.layout.places:
		var node := _place(place)
		if node != null:
			landmarks.add_child(node)


# --- Interacción --------------------------------------------------------------------

func add_point(pos: Vector3, prompt: String, action: Callable, radius: float = INTERACT_RADIUS, inward: Vector3 = Vector3.ZERO) -> Dictionary:
	var point := {"pos": pos, "radius": radius, "prompt": prompt, "action": action, "inward": inward}
	_points.append(point)
	return point


func remove_point(point: Dictionary) -> void:
	_points.erase(point)
	if _nearest == point:
		_nearest = {}
		prompt_changed.emit("")


func points() -> Array[Dictionary]:
	return _points


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			_player = world.get_node_or_null("../Player") as Node3D
		if _player == null:
			return
	var best: Dictionary = {}
	var best_distance := INF
	var walking := not (_player is Player) or (_player as Player).mode == Player.Mode.WALK
	var swimming := _player is Player and (_player as Player).mode in [Player.Mode.SWIM, Player.Mode.DIVE]
	if walking or swimming:
		for point in _points:
			if swimming and not point.get("any_mode", false):
				continue
			var distance := (point["pos"] as Vector3).distance_to(_player.global_position)
			if distance < float(point["radius"]) and distance < best_distance:
				best_distance = distance
				best = point
	if best != _nearest:
		_nearest = best
		prompt_changed.emit("" if best.is_empty() else InputHints.label("interact", best["prompt"]))
	# Puertas: también se entra caminando hacia ellas (como en los juegos).
	_door_cooldown = maxf(_door_cooldown - _delta, 0.0)
	if not best.is_empty() and walking and _door_cooldown <= 0.0 and (best["inward"] as Vector3) != Vector3.ZERO and _player is Player:
		var velocity := (_player as Player).velocity
		velocity.y = 0.0
		if velocity.length() > 1.0 and velocity.normalized().dot(best["inward"]) > 0.7 and best_distance < 1.4:
			_door_cooldown = 2.5
			print("[Interacción] Puerta: ", best["prompt"])
			(best["action"] as Callable).call()


func _unhandled_input(event: InputEvent) -> void:
	if not _nearest.is_empty() and event.is_action_pressed("interact") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		var action: Callable = _nearest["action"]
		print("[Interacción] ", _nearest["prompt"])
		action.call()


## Ejecuta el punto más cercano a pos (pruebas).
func interact_near(pos: Vector3, radius: float = INTERACT_RADIUS) -> bool:
	for point in _points:
		if (point["pos"] as Vector3).distance_to(pos) < radius:
			(point["action"] as Callable).call()
			return true
	return false


# --- Consultas ---------------------------------------------------------------------------

## Lugar especial que contiene (x, z) con un margen, o {}.
func place_at(x: float, z: float, margin: float = 0.0) -> Dictionary:
	for place: Dictionary in world.layout.places:
		if Vector2(x - float(place["x"]), z - float(place["z"])).length() < float(place["radius"]) + margin:
			return place
	return {}


static func place_title(place: Dictionary) -> String:
	return place.get("name", PLACE_NAMES.get(place["kind"], place["kind"]))


func place_by_id(id: int) -> Dictionary:
	for place: Dictionary in world.layout.places:
		if int(place["id"]) == id:
			return place
	return {}


## Puerta de entrada de un edificio de un tipo en el asentamiento más cercano a pos.
func nearest_building(kind: String, pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for settlement: Dictionary in world.layout.settlements:
		for building: Dictionary in settlement["buildings"]:
			if building["kind"] != kind:
				continue
			var d := Vector2(float(building["x"]) - pos.x, float(building["z"]) - pos.z).length()
			if d < best_d:
				best_d = d
				best = building
	return best


# --- Piezas ---------------------------------------------------------------------------

func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s:%.2f" % [color.to_html(), emission]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials[key] = material
	return material


func _box(parent: Node3D, size: Vector3, center: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	instance.material_override = _material(color, emission)
	instance.visibility_range_end = VIEW_DISTANCE
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, radius: float, height: float, center: Vector3, color: Color, top_radius: float = -1.0, segments: int = 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	instance.material_override = _material(color)
	instance.visibility_range_end = VIEW_DISTANCE
	parent.add_child(instance)
	return instance


## Techo a dos aguas: la cumbrera va a lo largo de X.
func _roof(parent: Node3D, width: float, depth: float, height: float, base_y: float, color: Color) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(depth + 0.6, height, width + 0.6)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(0, base_y + height * 0.5, 0)
	instance.rotation.y = PI * 0.5
	instance.material_override = _material(color)
	instance.visibility_range_end = VIEW_DISTANCE
	parent.add_child(instance)
	return instance


func _collider(parent: Node3D, size: Vector3, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WorldBuilder.LAYER_OBSTACLES | WorldBuilder.LAYER_CAMERA
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	body.add_child(collision)
	parent.add_child(body)
	return body


## Bloqueo solo para la cámara, del tamaño completo del modelo (techos y aleros
## incluidos), para que nunca se meta dentro de un edificio.
func _camera_blocker(parent: Node3D, size: Vector3, center: Vector3) -> void:
	var body := _collider(parent, size, center)
	body.collision_layer = WorldBuilder.LAYER_CAMERA


func _sign(parent: Node3D, text: String, at: Vector3, color: Color = Color.WHITE) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.pixel_size = 0.012
	label.font_size = 48
	label.outline_size = 12
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.visibility_range_end = 60.0
	parent.add_child(label)
	return label


func _base_height(x: float, z: float, radius: float) -> float:
	return world.ground_base_height(x, z, radius)


# --- Edificios -----------------------------------------------------------------------------

func _building(settlement: Dictionary, building: Dictionary) -> Node3D:
	var kind: String = building["kind"]
	var root := Node3D.new()
	root.name = "%s_%s_%d" % [kind.capitalize().replace(" ", ""), settlement["name"].replace(" ", ""), (settlement["buildings"] as Array).find(building)]
	var x := float(building["x"])
	var z := float(building["z"])
	var to_center := Vector2(float(settlement["x"]) - x, float(settlement["z"]) - z)
	if to_center.length() < 0.1:
		to_center = Vector2(0, 1)
	to_center = to_center.normalized()
	var w := float(building["w"])
	var d := float(building["d"])
	root.position = Vector3(x, float(settlement["height"]) - 0.05, z)
	root.rotation.y = atan2(to_center.x, to_center.y)
	var walls: Color = HOUSE_WALLS[int(building["color"]) % HOUSE_WALLS.size()]
	var roof: Color = HOUSE_ROOFS[int(building["color"]) % HOUSE_ROOFS.size()]
	var wall_h := 4.0
	match kind:
		"center":
			walls = Color(0.97, 0.94, 0.88)
			roof = Color(0.86, 0.22, 0.22)
			wall_h = 5.0
		"mart":
			walls = Color(0.95, 0.95, 0.92)
			roof = Color(0.22, 0.42, 0.85)
		"gym":
			walls = Color(0.78, 0.78, 0.8)
			roof = AttackProjectile.TYPE_COLORS.get(_gym_type(settlement), Color(0.5, 0.5, 0.55))
			wall_h = 7.0
		"contest":
			walls = Color(0.98, 0.95, 0.97)
			roof = Color(0.92, 0.5, 0.7)
			wall_h = 6.0
		"lab":
			walls = Color(0.96, 0.96, 0.96)
			roof = Color(0.45, 0.5, 0.55)
		"cabin":
			walls = Color(0.55, 0.38, 0.24)
			roof = Color(0.35, 0.25, 0.18)
			wall_h = 3.2
		"tower_small":
			walls = Color(0.82, 0.78, 0.7)
			roof = Color(0.45, 0.3, 0.25)
			wall_h = 14.0
	var door_world := root.position + Vector3(to_center.x, 0, to_center.y) * (d * 0.5 + 1.2)
	if kind == "manhole":
		_cylinder(root, 0.9, 0.08, Vector3(0, 0.05, 0), Color(0.25, 0.25, 0.28), -1.0, 16)
		_cylinder(root, 0.7, 0.1, Vector3(0, 0.07, 0), Color(0.35, 0.35, 0.38), -1.0, 16)
		add_point(root.position + Vector3.UP * 0.5, "Bajar a la alcantarilla", services.enter_interior.bind("sewer", settlement, building), 2.0)
		return root
	if kind == "tent":
		var tent := PrismMesh.new()
		tent.size = Vector3(w, 2.6, d)
		var instance := MeshInstance3D.new()
		instance.mesh = tent
		instance.position.y = 1.3
		instance.material_override = _material(roof.lightened(0.2))
		root.add_child(instance)
		_collider(root, Vector3(w * 0.8, 2.4, d), Vector3(0, 1.2, 0))
		add_point(door_world + Vector3.UP * 0.5, "Descansar en la carpa (hasta la mañana)", services.rest.bind(door_world), 2.4)
		return root
	var inward := -Vector3(to_center.x, 0, to_center.y)
	# Modelo de B2W2 si existe para este tipo de edificio.
	var model := BuildingModels.instance(kind, int(building["color"]) + int(absf(x)))
	if not model.is_empty():
		var size: Vector3 = model["size"]
		root.add_child(model["node"])
		_box(root, Vector3(size.x + 0.6, 3.0, size.z + 0.6), Vector3(0, -1.53, 0), Color(0.62, 0.6, 0.57))
		_collider(root, Vector3(size.x * 0.9, size.y, size.z * 0.82), Vector3(0, size.y * 0.5, -size.z * 0.06))
		_camera_blocker(root, size * 1.06 + Vector3(0, 0.5, 0), Vector3(0, size.y * 0.5, 0))
		door_world = root.position + Vector3(to_center.x, 0, to_center.y) * (size.z * 0.5 + 0.9)
		var model_title: String = BUILDING_NAMES[kind]
		if kind == "gym":
			model_title = "Gimnasio de %s (tipo %s)" % [settlement["name"], MenuStyle.TYPE_NAMES[_gym_type(settlement)]]
		if kind in ["mart", "gym", "contest", "lab"]:
			_sign(root, model_title, Vector3(0, size.y + 0.8, size.z * 0.5))
		_decorate(root, kind, size, settlement, building)
		if kind in ["center", "mart", "lab", "house", "cabin", "contest", "gym"]:
			add_point(door_world + Vector3.UP * 0.5, "Entrar: %s" % model_title, services.enter_interior.bind(kind, settlement, building), INTERACT_RADIUS, inward)
		return root
	# Cimiento (cubre desniveles) y cuerpo.
	_box(root, Vector3(w + 0.6, 3.0, d + 0.6), Vector3(0, -1.3, 0), Color(0.6, 0.58, 0.55))
	_box(root, Vector3(w, wall_h, d), Vector3(0, wall_h * 0.5, 0), walls)
	_collider(root, Vector3(w, wall_h + 2.0, d), Vector3(0, wall_h * 0.5, 0))
	if kind == "tower_small":
		_cylinder(root, w * 0.45, 3.0, Vector3(0, wall_h + 1.5, 0), roof, 0.0, 8)
		_cylinder(root, 1.2, 0.2, Vector3(0, wall_h - 2.0, d * 0.5 + 0.05), Color(0.98, 0.98, 0.9)).rotation.x = PI * 0.5
	elif kind in ["center", "gym", "contest"]:
		# Techo plano con borde y un emblema.
		_box(root, Vector3(w + 0.8, 0.8, d + 0.8), Vector3(0, wall_h + 0.4, 0), roof)
		if kind == "center":
			_box(root, Vector3(w * 0.6, 1.6, 0.3), Vector3(0, wall_h + 1.6, d * 0.5 - 0.6), roof)
			_cylinder(root, 0.8, 0.2, Vector3(0, wall_h + 1.6, d * 0.5 - 0.35), Color(0.98, 0.98, 0.98), -1.0, 16).rotation.x = PI * 0.5
	else:
		_roof(root, w, d, 2.4 if kind != "cabin" else 1.8, wall_h, roof)
	# Puerta, ventanas y letrero.
	var door_color := Color(0.35, 0.6, 0.85, 0.85) if kind in ["center", "mart", "lab", "contest"] else Color(0.4, 0.26, 0.16)
	_box(root, Vector3(1.6 if kind != "gym" else 3.0, 2.4, 0.15), Vector3(0, 1.2, d * 0.5 + 0.05), door_color)
	for side: float in [-1.0, 1.0]:
		if w > 6.0:
			_box(root, Vector3(1.2, 1.0, 0.12), Vector3(side * w * 0.3, 2.4, d * 0.5 + 0.05), Color(0.55, 0.75, 0.9), 0.15)
	if kind == "mart":
		_box(root, Vector3(w * 0.9, 0.7, 0.3), Vector3(0, wall_h - 0.6, d * 0.5 + 0.15), Color(0.22, 0.42, 0.85))
	var title: String = BUILDING_NAMES[kind]
	if kind == "gym":
		title = "Gimnasio de %s (tipo %s)" % [settlement["name"], MenuStyle.TYPE_NAMES[_gym_type(settlement)]]
	if kind in ["center", "mart", "gym", "contest", "lab"]:
		_sign(root, title, Vector3(0, wall_h + 1.0 if kind != "center" else wall_h + 3.0, d * 0.5 + 0.4))
	var prompt := "Entrar: %s" % title
	match kind:
		"center", "mart", "lab", "house", "cabin", "contest", "gym":
			add_point(door_world + Vector3.UP * 0.5, prompt, services.enter_interior.bind(kind, settlement, building), INTERACT_RADIUS, inward)
		"tower_small":
			add_point(door_world + Vector3.UP * 0.5, "Subir a la torre (vista del mapa)", services.reveal_area.bind(root.position, 600.0))
	return root


## Decoración alrededor de un edificio (estilo B2W2): flores a los lados de la puerta,
## arbustos en las esquinas, farol junto a la entrada, cerca de jardín en las casas y
## buzón. Todo fijo por la semilla.
func _decorate(root: Node3D, kind: String, size: Vector3, settlement: Dictionary, building: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([float(building["x"]), float(building["z"]), world.layout.seed])
	var front := size.z * 0.5
	var flowers: Array = [load("res://art/world/b2w2/flowers_yellow.png"), load("res://art/world/b2w2/flower_bush_pink.png"), load("res://art/world/b2w2/lavender.png")]
	var bush: Texture2D = load("res://art/world/b2w2/bush.png")
	# Flores a los lados de la puerta.
	for side: float in [-1.0, 1.0]:
		var texture: Texture2D = flowers[rng.randi() % flowers.size()]
		for i in 3:
			_decor_sprite(root, texture, Vector3(side * (1.4 + i * 0.7), 0.0, front + 0.6))
	# Arbustos en las esquinas.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		if rng.randf() < 0.7:
			_decor_sprite(root, bush, Vector3(corner.x * (size.x * 0.5 + 0.8), 0.0, corner.y * (size.z * 0.5 + 0.5)))
	# Farol junto a la entrada (modelo de B2W2 si está).
	var lamp := BuildingModels.instance("lamp", rng.randi())
	if not lamp.is_empty() and kind in ["center", "mart", "gym", "lab", "contest", "house"]:
		var node: Node3D = lamp["node"]
		node.position = Vector3(2.6 if rng.randf() < 0.5 else -2.6, 0.0, front + 1.6)
		root.add_child(node)
		_collider(root, Vector3(0.4, 3.0, 0.4), node.position + Vector3(0, 1.5, 0))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.55)
		# Suave: antes la pared blanca del Centro se veía encendida de noche.
		light.omni_range = 5.0
		light.omni_attenuation = 1.6
		light.light_specular = 0.0
		light.light_energy = 0.0
		light.position = node.position + Vector3(0, (lamp["size"] as Vector3).y, 0)
		light.add_to_group(&"night_lights")
		root.add_child(light)
	# Casas: cerca de jardín al frente y buzón.
	if kind in ["house", "cabin"]:
		var fence := BuildingModels.instance("fence", 0)
		if not fence.is_empty():
			var fence_size: Vector3 = fence["size"]
			var steps := int((size.x + 3.0) / maxf(fence_size.x, 0.5))
			for i in steps:
				var fx := -size.x * 0.5 - 1.5 + (i + 0.5) * fence_size.x
				if absf(fx) < 1.4:
					continue # Hueco del camino a la puerta.
				var piece := BuildingModels.instance("fence", 0)
				var piece_node: Node3D = piece["node"]
				piece_node.position = Vector3(fx, 0.0, front + 2.6)
				root.add_child(piece_node)
				# Las cercas no se atraviesan.
				_collider(root, Vector3(fence_size.x, maxf(fence_size.y, 1.0), maxf(fence_size.z, 0.35)), Vector3(fx, maxf(fence_size.y, 1.0) * 0.5, front + 2.6))
		_box(root, Vector3(0.12, 1.0, 0.12), Vector3(1.8, 0.5, front + 2.2), Color(0.45, 0.3, 0.2))
		_collider(root, Vector3(0.5, 1.3, 0.4), Vector3(1.8, 0.65, front + 2.2))
		_box(root, Vector3(0.5, 0.35, 0.35), Vector3(1.8, 1.1, front + 2.2), [Color(0.85, 0.25, 0.25), Color(0.25, 0.45, 0.85)][rng.randi() % 2])


func _decor_sprite(root: Node3D, texture: Texture2D, at: Vector3) -> void:
	if texture == null:
		return
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = world.config.pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.layers = WorldBuilder.VISUAL_LAYER_SPRITES
	SpriteMaterials.apply(sprite)
	sprite.material_override = SpriteMaterials.for_texture(texture)
	sprite.position = at
	sprite.visibility_range_end = 160.0
	root.add_child(sprite)


## Tipo del gimnasio de una ciudad (fijo por semilla y nombre).
func _gym_type(settlement: Dictionary) -> int:
	return absi(hash(String(settlement["name"]) + str(world.layout.seed))) % 18


func gym_type(settlement: Dictionary) -> int:
	return _gym_type(settlement)


# --- Lugares especiales ---------------------------------------------------------------

func _place(place: Dictionary) -> Node3D:
	var kind: String = place["kind"]
	var x := float(place["x"])
	var z := float(place["z"])
	var root := Node3D.new()
	root.name = "%s_%d" % [kind, int(place["id"])]
	var y := _base_height(x, z, 3.0)
	root.position = Vector3(x, y, z)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(place["id"]) * 7919 + world.layout.seed
	var stone := Color(0.62, 0.6, 0.56)
	var title := place_title(place)
	# Modelo de B2W2 del lugar (torre, mansión, faro, ruinas, santuario, invernadero).
	if kind in ["tower", "mansion", "lighthouse", "ruins", "sanctuary", "berry_farm"]:
		var model := BuildingModels.instance(kind, int(place["id"]))
		if not model.is_empty():
			var size: Vector3 = model["size"]
			var node: Node3D = model["node"]
			node.position.z = -10.0 if kind == "berry_farm" else 0.0
			root.add_child(node)
			_box(root, Vector3(size.x + 0.6, 3.0, size.z + 0.6), Vector3(0, -1.53, node.position.z), stone.darkened(0.2))
			_collider(root, Vector3(size.x * 0.9, size.y, size.z * 0.85), Vector3(0, size.y * 0.5, node.position.z))
			_camera_blocker(root, size * 1.06 + Vector3(0, 0.5, 0), Vector3(0, size.y * 0.5, node.position.z))
			match kind:
				"tower", "mansion":
					for i in (18 if kind == "tower" else 6):
						_box(root, Vector3(0.7, 1.0, 0.25), Vector3(rng.randf_range(-16.0, 16.0), 0.5, rng.randf_range(size.z * 0.5 + 3.0, size.z * 0.5 + 14.0)), Color(0.55, 0.55, 0.58))
					add_point(root.position + Vector3(0, 0.5, size.z * 0.5 + 1.2), "Entrar: %s" % title, services.enter_interior.bind(kind, {}, place), INTERACT_RADIUS, Vector3(0, 0, -1))
					return root
				"lighthouse":
					var beacon := OmniLight3D.new()
					beacon.position = Vector3(0, size.y - 1.0, 0)
					beacon.omni_range = 40.0
					beacon.light_color = Color(1.0, 0.92, 0.6)
					root.add_child(beacon)
					return root
				"ruins":
					add_point(root.position + Vector3(0, 1, size.z * 0.5 + 1.2), "Leer las inscripciones", services.read_ruins.bind(place))
					for i in 3:
						var angle := TAU * i / 3.0 + 0.5
						var at := Vector3(cos(angle) * (size.x * 0.5 + 3.0), 0.0, sin(angle) * (size.z * 0.5 + 3.0))
						_box(root, Vector3(0.9, 1.0, 0.9), at + Vector3(0, 0.5, 0), [Color(1.0, 0.8, 0.3), Color(0.6, 0.7, 1.0), Color(1.0, 1.0, 0.85)][i], 0.35)
						add_point(root.position + at + Vector3.UP * 0.5, "Tocar la piedra del %s" % TownServices.RUIN_SYMBOLS[i], services.ruin_stone.bind(place, i), 1.6)
					return root
				"sanctuary":
					return root
		# Si no hay modelo, se arma con piezas (abajo).
	match kind:
		"ruins":
			_box(root, Vector3(14, 0.6, 14), Vector3(0, 0.0, 0), stone.darkened(0.15))
			for i in 8:
				var angle := TAU * i / 8.0
				var height := rng.randf_range(1.0, 5.0)
				_box(root, Vector3(1.2, height, 1.2), Vector3(cos(angle) * 6.0, height * 0.5, sin(angle) * 6.0), stone)
				_collider(root, Vector3(1.2, height, 1.2), Vector3(cos(angle) * 6.0, height * 0.5, sin(angle) * 6.0))
			_box(root, Vector3(3, 2.2, 0.6), Vector3(0, 1.1, 0), stone.darkened(0.3))
			add_point(root.position + Vector3(0, 1, 1.2), "Leer las inscripciones", services.read_ruins.bind(place))
			# Acertijo: tres piedras con símbolos; tocarlas en el orden de la inscripción.
			for i in 3:
				var angle := TAU * i / 3.0 + 0.5
				var at := Vector3(cos(angle) * 3.5, 0.0, sin(angle) * 3.5)
				_box(root, Vector3(0.9, 1.0, 0.9), at + Vector3(0, 0.5, 0), [Color(1.0, 0.8, 0.3), Color(0.6, 0.7, 1.0), Color(1.0, 1.0, 0.85)][i], 0.35)
				add_point(root.position + at + Vector3.UP * 0.5, "Tocar la piedra del %s" % TownServices.RUIN_SYMBOLS[i], services.ruin_stone.bind(place, i), 1.6)
		"cave", "victory_road":
			_box(root, Vector3(9, 6, 4), Vector3(0, 3, 0), Color(0.42, 0.38, 0.34))
			_box(root, Vector3(3.4, 3.4, 0.4), Vector3(0, 1.7, 2.05), Color(0.05, 0.04, 0.04))
			_collider(root, Vector3(9, 6, 4), Vector3(0, 3, 0))
			add_point(root.position + Vector3(0, 0.5, 3.4), "Entrar: %s" % title, services.enter_interior.bind(kind, {}, place))
		"sanctuary":
			_cylinder(root, 6.0, 0.5, Vector3(0, 0.1, 0), stone, -1.0, 20)
			for i in 6:
				var angle := TAU * i / 6.0
				_box(root, Vector3(0.8, 3.2, 0.8), Vector3(cos(angle) * 5.0, 1.6, sin(angle) * 5.0), stone.lightened(0.1))
			_box(root, Vector3(1.6, 1.0, 1.0), Vector3(0, 0.8, 0), Color(0.75, 0.7, 0.9), 0.3)
		"tower", "mansion", "power_plant", "lab_ruins":
			var size: Vector3 = {"tower": Vector3(10, 26, 10), "mansion": Vector3(22, 9, 14), "power_plant": Vector3(24, 10, 16), "lab_ruins": Vector3(16, 6, 12)}[kind]
			var color: Color = {"tower": Color(0.5, 0.45, 0.55), "mansion": Color(0.4, 0.33, 0.35), "power_plant": Color(0.62, 0.62, 0.55), "lab_ruins": Color(0.75, 0.75, 0.78)}[kind]
			_box(root, Vector3(size.x + 0.6, 3.0, size.z + 0.6), Vector3(0, -1.3, 0), stone.darkened(0.2))
			_box(root, size, Vector3(0, size.y * 0.5, 0), color)
			_collider(root, size + Vector3(0, 2, 0), Vector3(0, size.y * 0.5, 0))
			if kind == "mansion":
				_roof(root, size.x, size.z, 4.0, size.y, Color(0.25, 0.2, 0.25))
			elif kind == "tower":
				_cylinder(root, size.x * 0.6, 6.0, Vector3(0, size.y + 3.0, 0), color.darkened(0.3), 0.0, 6)
				# Cementerio alrededor de la torre.
				for i in 18:
					var gx := rng.randf_range(-16.0, 16.0)
					var gz := rng.randf_range(8.0, 22.0)
					_box(root, Vector3(0.7, 1.0, 0.25), Vector3(gx, 0.5, gz), Color(0.55, 0.55, 0.58))
			elif kind == "power_plant":
				_cylinder(root, 1.4, 8.0, Vector3(size.x * 0.3, size.y + 4.0, 0), Color(0.55, 0.52, 0.5))
				_box(root, Vector3(2, 1, 0.2), Vector3(0, size.y - 1.5, size.z * 0.5 + 0.1), Color(1.0, 0.85, 0.2), 0.8)
			_box(root, Vector3(2.4, 3, 0.2), Vector3(0, 1.5, size.z * 0.5 + 0.1), Color(0.12, 0.1, 0.12))
			add_point(root.position + Vector3(0, 0.5, size.z * 0.5 + 1.4), "Entrar: %s" % title, services.enter_interior.bind(kind, {}, place))
		"shipwreck":
			root.position.y = world.layout.sea_level - 1.2
			var hull := _box(root, Vector3(6, 4, 20), Vector3(0, 1.5, 0), Color(0.4, 0.28, 0.18))
			hull.rotation = Vector3(0.15, 0.4, 0.3)
			var mast := _cylinder(root, 0.3, 10.0, Vector3(0, 6, 2), Color(0.35, 0.25, 0.16))
			mast.rotation.z = 0.35
			# Se explora nadando o buceando junto al casco.
			var dive_point := add_point(Vector3(x, world.layout.sea_level - 0.5, z + 7.0), "Explorar el barco hundido", services.enter_interior.bind("shipwreck", {}, place), 4.0)
			dive_point["any_mode"] = true
		"lighthouse":
			_cylinder(root, 3.0, 2.0, Vector3(0, 0.0, 0), stone)
			for i in 5:
				_cylinder(root, 2.4 - i * 0.15, 3.0, Vector3(0, 1.5 + i * 3.0, 0), Color(0.95, 0.95, 0.95) if i % 2 == 0 else Color(0.85, 0.2, 0.2), 2.4 - (i + 1) * 0.15)
			_cylinder(root, 1.4, 2.0, Vector3(0, 17.0, 0), Color(1.0, 0.95, 0.6), -1.0, 12).material_override = _material(Color(1.0, 0.95, 0.6), 2.0)
			var light := OmniLight3D.new()
			light.position = Vector3(0, 17.5, 0)
			light.omni_range = 40.0
			light.light_color = Color(1.0, 0.92, 0.6)
			root.add_child(light)
			_collider(root, Vector3(4.6, 18, 4.6), Vector3(0, 9, 0))
		"giant_tree":
			var texture: Texture2D = world.config.forest.tree_textures[0] if not world.config.forest.tree_textures.is_empty() else null
			if texture != null:
				root.add_child(world._obstacle("GiantTree", texture, 7.0, 0.4, Vector3(0, -0.3, 0), Color(0.9, 1.05, 0.9)))
			add_point(root.position + Vector3(0, 0.5, 4.5), "Tocar el Árbol Milenario", services.giant_tree.bind(place))
		"league":
			_box(root, Vector3(40, 3, 30), Vector3(0, -1.0, 0), stone.lightened(0.1))
			_box(root, Vector3(34, 14, 24), Vector3(0, 7, 0), Color(0.88, 0.86, 0.95))
			_collider(root, Vector3(34, 16, 24), Vector3(0, 7, 0))
			_cylinder(root, 8.0, 10.0, Vector3(0, 19, 0), Color(0.75, 0.68, 0.3), 2.0, 8)
			_box(root, Vector3(4, 5, 0.2), Vector3(0, 2.5, 12.1), Color(0.2, 0.25, 0.5))
			_sign(root, "LIGA POKÉMON", Vector3(0, 15, 12.6), Color(1.0, 0.9, 0.5))
			add_point(root.position + Vector3(0, 0.5, 13.5), "Entrar a la Liga Pokémon", services.enter_interior.bind("league", {}, place))
		"floating_ruins":
			for i in 7:
				var offset := Vector3(rng.randf_range(-12, 12), 38.0 + rng.randf_range(-4, 8), rng.randf_range(-12, 12))
				var size := Vector3(rng.randf_range(3, 7), rng.randf_range(1.5, 3), rng.randf_range(3, 7))
				_box(root, size, offset, stone.lightened(0.15))
				var body := _collider(root, size, offset)
				body.collision_layer = WorldBuilder.LAYER_TERRAIN
			_box(root, Vector3(1.2, 1.2, 1.2), Vector3(0, 48, 0), Color(0.6, 0.9, 1.0), 2.0)
			add_point(root.position + Vector3(0, 47.5, 0), "Tomar el fragmento de cielo", services.sky_shard.bind(place), 3.5)
		"portal":
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 2.2
			torus.outer_radius = 2.8
			ring.mesh = torus
			ring.rotation.x = PI * 0.5
			ring.position.y = 3.0
			ring.material_override = _material(Color(0.7, 0.4, 1.0), 2.5)
			root.add_child(ring)
			_cylinder(root, 2.2, 0.05, Vector3(0, 3.0, 0), Color(0.5, 0.2, 0.9, 0.55), -1.0, 20).rotation.x = PI * 0.5
			add_point(root.position + Vector3(0, 1.0, 0), "Cruzar el portal", services.enter_interior.bind("distortion", {}, place), 3.0)
		"safari":
			for i in 24:
				var angle := TAU * i / 24.0
				_box(root, Vector3(0.3, 1.4, 4.0), Vector3(cos(angle) * 16.0, 0.7, sin(angle) * 16.0), Color(0.55, 0.4, 0.25)).rotation.y = -angle
			_box(root, Vector3(6, 4, 4), Vector3(0, 2, 18), Color(0.4, 0.62, 0.35))
			_sign(root, "ZONA SAFARI", Vector3(0, 5, 20), Color(0.9, 1.0, 0.7))
			add_point(root.position + Vector3(0, 0.5, 20.5), "Entrar a la Zona Safari ($500)", services.safari.bind(place))
		"daycare":
			_box(root, Vector3(10, 4, 8), Vector3(0, 2, 0), Color(0.98, 0.9, 0.75))
			_roof(root, 10, 8, 2.4, 4.0, Color(0.9, 0.55, 0.3))
			_collider(root, Vector3(10, 6, 8), Vector3(0, 2, 0))
			_sign(root, "GUARDERÍA", Vector3(0, 7.5, 4.4), Color(1.0, 0.85, 0.6))
			add_point(root.position + Vector3(0, 0.5, 5.4), "Hablar con la guardería", services.daycare.bind(place))
		"hot_spring", "fountain":
			var level := y + 0.25
			if kind == "fountain":
				_cylinder(root, 3.2, 0.8, Vector3(0, 0.4, 0), stone, -1.0, 16)
				_cylinder(root, 0.4, 2.4, Vector3(0, 1.2, 0), stone.lightened(0.1))
				level = y + 0.75
			else:
				for i in 10:
					var angle := TAU * i / 10.0
					_box(root, Vector3(1.4, 0.9, 1.4), Vector3(cos(angle) * 5.4, 0.3, sin(angle) * 5.4), Color(0.45, 0.42, 0.4))
			var water := world._water_disc("Water", Vector2.ZERO, 5.0 if kind == "hot_spring" else 2.9, 0.0, world._water_fresh, 20)
			water.position = Vector3(0, level - y, 0)
			root.add_child(water)
			root.add_child(_steam(Color(1, 1, 1, 0.5) if kind == "hot_spring" else Color(0.7, 0.9, 1.0, 0.6)))
			services.add_healing_spot(Vector3(x, level, z), 6.0 if kind == "hot_spring" else 4.0, title)
		"alpha":
			for i in 4:
				var angle := TAU * i / 4.0 + 0.4
				var post := _box(root, Vector3(0.6, 3.0, 0.6), Vector3(cos(angle) * 9.0, 1.5, sin(angle) * 9.0), Color(0.5, 0.15, 0.15))
				post.material_override = _material(Color(0.75, 0.15, 0.15), 0.4)
		"ranch":
			for i in 28:
				var angle := TAU * i / 28.0
				_box(root, Vector3(0.25, 1.2, 3.6), Vector3(cos(angle) * 16.0, 0.6, sin(angle) * 16.0), Color(0.95, 0.95, 0.92)).rotation.y = -angle
			_box(root, Vector3(9, 5, 7), Vector3(0, 2.5, -10), Color(0.75, 0.2, 0.18))
			_roof(root, 9, 7, 2.5, 5.0, Color(0.3, 0.25, 0.22)).position.z = -10
			_collider(root, Vector3(9, 6, 7), Vector3(0, 2.5, -10))
			_sign(root, "RANCHO", Vector3(0, 8.2, -6.4), Color(1.0, 0.95, 0.8))
			add_point(root.position + Vector3(0, 0.5, -5.6), "Comprar Leche Mu-mu ($500)", services.buy_milk)
		"berry_farm":
			for row in 4:
				for col in 6:
					var at := Vector3(-7.5 + col * 3.0, 0, -6 + row * 4.0)
					_cylinder(root, 0.7, 1.0, at + Vector3(0, 0.5, 0), Color(0.25, 0.55, 0.25), 0.4, 8)
					_box(root, Vector3(0.25, 0.25, 0.25), at + Vector3(0.3, 0.9, 0.2), [Color(0.3, 0.4, 1.0), Color(1.0, 0.5, 0.7), Color(1.0, 0.3, 0.3), Color(1.0, 0.9, 0.3)][(row + col) % 4], 0.3)
			_sign(root, "HUERTO DE BAYAS", Vector3(0, 2.6, 9.5), Color(0.9, 1.0, 0.8))
			for row in 4:
				add_point(root.position + Vector3(0, 0.5, -6 + row * 4.0 + 1.6), "Cosechar bayas (fila %d)" % (row + 1), services.harvest.bind(place, row), 3.2)
		"mine":
			_box(root, Vector3(8, 5, 4), Vector3(0, 2.5, 0), Color(0.4, 0.33, 0.28))
			_box(root, Vector3(3.6, 3.6, 0.3), Vector3(0, 1.8, 2.05), Color(0.05, 0.04, 0.04))
			for side: float in [-1.0, 1.0]:
				_box(root, Vector3(0.4, 4.0, 0.4), Vector3(side * 2.0, 2.0, 2.3), Color(0.5, 0.35, 0.2))
			_box(root, Vector3(4.6, 0.4, 0.4), Vector3(0, 4.0, 2.3), Color(0.5, 0.35, 0.2))
			_collider(root, Vector3(8, 5, 4), Vector3(0, 2.5, 0))
			add_point(root.position + Vector3(0, 0.5, 3.6), "Entrar: %s" % title, services.enter_interior.bind("mine", {}, place))
		"grotto":
			# Gruta poco profunda sin pantalla de carga: paredes y techo de roca con cristales.
			var rock := Color(0.38, 0.36, 0.42)
			_box(root, Vector3(1.5, 4.0, 12.0), Vector3(-5.0, 2.0, 0), rock)
			_box(root, Vector3(1.5, 4.0, 12.0), Vector3(5.0, 2.0, 0), rock)
			_box(root, Vector3(11.5, 1.5, 1.5), Vector3(0, 2.0, -5.5), rock)
			_box(root, Vector3(11.5, 1.2, 12.0), Vector3(0, 4.4, 0), rock)
			for side: float in [-1.0, 1.0]:
				_collider(root, Vector3(1.5, 4.0, 12.0), Vector3(side * 5.0, 2.0, 0))
			_collider(root, Vector3(11.5, 4.0, 1.5), Vector3(0, 2.0, -5.5))
			for i in 6:
				var crystal := _box(root, Vector3(0.4, rng.randf_range(0.6, 1.4), 0.4), Vector3(rng.randf_range(-3.8, 3.8), 0.5, rng.randf_range(-4.5, 3.0)), [Color(0.6, 0.85, 1.0), Color(0.85, 0.6, 1.0)][i % 2], 1.5)
				crystal.rotation.z = rng.randf_range(-0.4, 0.4)
			var glow := OmniLight3D.new()
			glow.light_color = Color(0.7, 0.8, 1.0)
			glow.omni_range = 7.0
			glow.position = Vector3(0, 2.0, -1.0)
			root.add_child(glow)
		"villain_base":
			_box(root, Vector3(16, 3, 12), Vector3(0, -1.2, 0), stone.darkened(0.3))
			_box(root, Vector3(14, 6, 10), Vector3(0, 3, 0), Color(0.22, 0.22, 0.26))
			_collider(root, Vector3(14, 8, 10), Vector3(0, 3, 0))
			_box(root, Vector3(2.4, 3, 0.2), Vector3(0, 1.5, 5.1), Color(0.6, 0.1, 0.1), 0.6)
			_sign(root, GameState.villain_team.to_upper() if GameState.villain_team != "" else "PROHIBIDO EL PASO", Vector3(0, 7.2, 5.4), Color(1.0, 0.4, 0.4))
			add_point(root.position + Vector3(0, 0.5, 6.4), "Infiltrarse en la base", services.enter_interior.bind("villain_base", {}, place))
		"merchant":
			_box(root, Vector3(3.0, 1.2, 1.8), Vector3(0, 0.9, 0), Color(0.6, 0.42, 0.25))
			_box(root, Vector3(3.4, 0.15, 2.2), Vector3(0, 2.6, 0), Color(0.9, 0.3, 0.3))
			for side: float in [-1.0, 1.0]:
				_cylinder(root, 0.4, 0.15, Vector3(side * 1.2, 0.4, 1.0), Color(0.3, 0.2, 0.12)).rotation.x = PI * 0.5
			_collider(root, Vector3(3.0, 2.0, 1.8), Vector3(0, 1.0, 0))
			add_point(root.position + Vector3(0, 0.5, 2.0), "Ver lo que vende el comerciante", services.open_merchant.bind(place))
		"oasis":
			for i in 7:
				var angle := TAU * i / 7.0 + rng.randf_range(-0.2, 0.2)
				var px := cos(angle) * rng.randf_range(16.0, 22.0)
				var pz := sin(angle) * rng.randf_range(16.0, 22.0)
				var base := world.ground_base_height(x + px, z + pz, 1.0)
				root.add_child(world._obstacle("Palm%d" % i, PropArt.texture("palm"), 1.0, 0.4, Vector3(px, base - y - 0.1, pz), Color.WHITE))
		"volcano":
			var top := Vector3(0, world.layout.base_height(x, z) - y + 2.0, 0)
			var smoke := _steam(Color(0.35, 0.32, 0.3, 0.7))
			smoke.position = top
			smoke.scale = Vector3.ONE * 6.0
			root.add_child(smoke)
	return root


func _steam(color: Color) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "Steam"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.9
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	quad.material = material
	particles.mesh = quad
	particles.amount = 14
	particles.lifetime = 3.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 2.0
	particles.direction = Vector3.UP
	particles.gravity = Vector3(0, 0.6, 0)
	particles.initial_velocity_min = 0.3
	particles.initial_velocity_max = 0.8
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.2
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(color.r, color.g, color.b, 0), color, Color(color.r, color.g, color.b, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	particles.color_ramp = fade
	particles.visibility_range_end = VIEW_DISTANCE
	return particles
