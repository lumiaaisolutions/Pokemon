class_name TravelScene
extends Node3D
## Viaje entre regiones en 3D (pedido de Fernando, 2026-10-10: "en 3D con el estilo que
## ya conoces, que no se vea como lienzo, estilo BW2"). Modelos originales de B2W2
## (art/models/b2w2_travel/): el Ferry cruza el mar con su estela entre islas, o el avión
## de la región (de carga o de pasajeros) vuela entre nubes pixel art sobre el mar. La
## cámara gira alrededor como en las escenas de B2W2. Al terminar carga la región nueva.
## Se entra con TravelScene.go(boat, plane_model, destino); el estado de la región ya cambió.

const SCENE := "res://ui/travel/travel_scene.tscn"
const MAIN_SCENE := "res://world/main.tscn"
const ROOT := "res://art/models/b2w2_travel/"
const DURATION := 6.0
const MODEL_SCALE := 0.08

static var boat := true
static var plane_model := "plane2"
static var destination := ""

var _vehicle: Node3D
var _camera: Camera3D
var _time := 0.0
var _clouds: Array[Node3D] = []
var _wake: Array[MeshInstance3D] = []
var _title: Label
var _fade: ColorRect
var _leaving := false
var _rng := RandomNumberGenerator.new()


static func go(tree: SceneTree, by_boat: bool, plane: String, to_name: String) -> void:
	boat = by_boat
	plane_model = plane
	destination = to_name
	tree.change_scene_to_file(SCENE)


func _ready() -> void:
	_rng.seed = hash(destination)
	# Luz de mediodía (el tinte global del día lo usa el agua).
	RenderingServer.global_shader_parameter_set("time_tint", Color.WHITE)
	_environment()
	if boat:
		_build_sea(0.0)
		_build_islands(0.0, 7)
		_vehicle = _model("ferry1", 0.0)
	else:
		_build_sea(-160.0)
		_build_islands(-160.0, 10)
		_build_clouds()
		_vehicle = _model(plane_model, 0.0)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 4000.0
	add_child(_camera)
	_build_ui()
	AudioBus.play_sfx("save")


func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.36, 0.6, 0.95)
	sky_material.sky_horizon_color = Color(0.78, 0.88, 0.98)
	sky_material.ground_horizon_color = Color(0.7, 0.82, 0.95)
	sky_material.ground_bottom_color = Color(0.3, 0.5, 0.75)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.88, 0.97)
	env.fog_density = 0.0012
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)


## Mar con el agua del juego (textura de B2W2 y su shader).
func _build_sea(level: float) -> void:
	var config := load("res://world/world_config.tres") as WorldConfig
	var material := ShaderMaterial.new()
	material.shader = load("res://world/terrain/water_pixel.gdshader")
	material.set_shader_parameter("water_tex", config.water_texture)
	material.set_shader_parameter("px_per_meter", 1.0 / config.pixel_size)
	material.set_shader_parameter("alpha", 1.0)
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	sea.mesh = plane
	sea.material_override = material
	sea.position.y = level
	add_child(sea)


## Islas: cono de arena con copa de pasto y pinos pixel art.
func _build_islands(level: float, count: int) -> void:
	var sand := _textured(load("res://art/world/b2w2/beach_sand.png"))
	var grass := _textured(load("res://art/world/b2w2/grass.png"))
	var pine := load("res://art/world/b2w2/pine.png") as Texture2D
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(side * _rng.randf_range(70.0, 220.0), level, -i * 140.0 - _rng.randf_range(40.0, 120.0))
		var radius := _rng.randf_range(18.0, 45.0)
		var base := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = radius * 0.8
		cone.bottom_radius = radius
		cone.height = 4.0
		base.mesh = cone
		base.material_override = sand
		base.position = at + Vector3(0, 1.0, 0)
		add_child(base)
		var top := MeshInstance3D.new()
		var hill := CylinderMesh.new()
		hill.top_radius = radius * 0.35
		hill.bottom_radius = radius * 0.72
		hill.height = _rng.randf_range(6.0, 16.0)
		top.mesh = hill
		top.material_override = grass
		top.position = at + Vector3(0, 3.0 + hill.height * 0.5, 0)
		add_child(top)
		for k in _rng.randi_range(3, 7):
			var tree := Sprite3D.new()
			tree.texture = pine
			tree.pixel_size = 0.12
			tree.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			tree.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			tree.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			tree.shaded = false
			var spot := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, radius * 0.6)
			tree.position = at + Vector3(spot.x, 3.0 + pine.get_height() * 0.06, spot.y)
			add_child(tree)


func _textured(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.12
	material.roughness = 1.0
	return material


## Nubes pixel art (generadas) a varias alturas alrededor del avión.
func _build_clouds() -> void:
	var texture := _cloud_texture()
	for i in 70:
		var cloud := Sprite3D.new()
		cloud.texture = texture
		cloud.pixel_size = _rng.randf_range(0.35, 0.8)
		cloud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cloud.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		cloud.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		cloud.shaded = false
		cloud.position = Vector3(_rng.randf_range(-160, 160), _rng.randf_range(-30, 18), -_rng.randf_range(-60, 900))
		add_child(cloud)
		_clouds.append(cloud)


func _cloud_texture() -> ImageTexture:
	var image := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	var blobs := [Vector3(16, 20, 10), Vector3(30, 14, 13), Vector3(45, 19, 10), Vector3(24, 22, 9), Vector3(38, 22, 9)]
	for y in 32:
		for x in 64:
			for b: Vector3 in blobs:
				if Vector2(x - b.x, (y - b.y) * 1.2).length() <= b.z:
					image.set_pixel(x, y, Color(1, 1, 1) if y < b.y + 2 else Color(0.84, 0.9, 0.98))
					break
	return ImageTexture.create_from_image(image)


## Modelo de B2W2 a escala del mundo, con píxel nítido (como los edificios).
func _model(name: String, height: float) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var path := ROOT + name + "/model.dae"
	if not ResourceLoader.exists(path):
		return holder
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.scale = Vector3.ONE * MODEL_SCALE
	holder.add_child(node)
	var box := AABB()
	var first := true
	for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		BuildingModels._fix_materials(mesh)
		# La sombra pintada del modelo (para el suelo) no va en el aire ni en el mar: se
		# oculta solo esa parte (el avión es una sola malla con varias superficies).
		_hide_shadow_surfaces(mesh)
		var local := BuildingModels._local_transform(mesh, node) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	var center := box.get_center()
	node.position = Vector3(-center.x, -box.position.y, -center.z) * MODEL_SCALE
	# Los aviones de B2W2 tienen la nariz hacia +Z: se giran para avanzar de frente.
	if name.begins_with("plane"):
		var pivot := Node3D.new()
		holder.remove_child(node)
		pivot.add_child(node)
		pivot.rotation.y = PI
		holder.add_child(pivot)
	holder.position.y = height
	holder.set_meta("length", box.size.z * MODEL_SCALE)
	return holder


func _hide_shadow_surfaces(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	var hidden := StandardMaterial3D.new()
	hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hidden.albedo_color = Color(0, 0, 0, 0)
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(surface) as BaseMaterial3D
		var texture := material.albedo_texture if material != null else null
		var file := texture.resource_path.get_file() if texture != null else ""
		if file.contains("shadow") or file.contains("kage"):
			mesh.set_surface_override_material(surface, hidden)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_title = UiKit.label(("Rumbo a la %s…" if boat else "Volando a la %s…") % destination, 40, Color.WHITE, true)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(-450, 60)
	_title.size = Vector2(900, 60)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_color_override("font_outline_color", Color(0.12, 0.2, 0.4))
	_title.add_theme_constant_override("outline_size", 12)
	layer.add_child(_title)
	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _process(delta: float) -> void:
	_time += delta
	var t := _time
	# El vehículo avanza hacia -Z; el barco se mece y el avión se ladea.
	var speed := 9.0 if boat else 45.0
	_vehicle.position.z = -t * speed
	if boat:
		_vehicle.position.y = sin(t * 1.6) * 0.15
		_vehicle.rotation.z = sin(t * 1.1) * 0.03
		_vehicle.rotation.x = sin(t * 1.6 + 0.5) * 0.02
		_update_wake(delta)
	else:
		_vehicle.position.y = sin(t * 0.9) * 1.5
		_vehicle.rotation.z = sin(t * 0.6) * 0.12
		# Las nubes que quedan atrás vuelven adelante.
		for cloud in _clouds:
			if cloud.position.z > _vehicle.position.z + 80.0:
				cloud.position.z -= 960.0
	# Cámara: de atrás a un costado, girando alrededor como en B2W2.
	var length: float = _vehicle.get_meta("length", 10.0)
	var distance := length * (1.8 if boat else 1.5)
	var angle := lerpf(-0.35, 1.25, clampf(t / DURATION, 0.0, 1.0))
	var target := _vehicle.position + Vector3(0, length * 0.15, 0)
	_camera.position = target + Vector3(sin(angle) * distance, length * (0.55 if boat else 0.3), cos(angle) * distance)
	_camera.look_at(target, Vector3.UP)
	# Fundido de entrada y salida.
	_fade.color.a = clampf(1.0 - t / 0.6, 0.0, 1.0) if t < DURATION - 0.8 else clampf((t - (DURATION - 0.8)) / 0.8, 0.0, 1.0)
	_title.modulate.a = clampf(t / 0.8, 0.0, 1.0)
	if t >= DURATION and not _leaving:
		_leaving = true
		get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


## Estela del barco: manchas de espuma que nacen en la popa y se abren y desvanecen.
func _update_wake(_delta: float) -> void:
	if _wake.size() < 40 and Engine.get_process_frames() % 3 == 0:
		var foam := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		foam.mesh = quad
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.95, 0.98, 1.0, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		foam.material_override = material
		foam.rotation.x = -PI * 0.5
		var length: float = _vehicle.get_meta("length", 10.0)
		foam.position = _vehicle.position + Vector3(_rng.randf_range(-1.5, 1.5), 0.06, length * 0.5)
		foam.set_meta("born", _time)
		add_child(foam)
		_wake.append(foam)
	for foam in _wake.duplicate():
		var age := _time - float(foam.get_meta("born"))
		foam.scale = Vector3.ONE * (1.0 + age * 1.5)
		(foam.material_override as StandardMaterial3D).albedo_color.a = maxf(0.8 - age * 0.35, 0.0)
		if age > 2.4:
			_wake.erase(foam)
			foam.queue_free()
