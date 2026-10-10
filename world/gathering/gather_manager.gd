class_name GatherManager
extends Node3D
## Puntos de recolección del mundo: arbustos de bayas, árboles de bonguri, setas, rocas
## con minerales y conchas, según el hábitat. Brillan para que se vean; cerca de uno, el
## HUD muestra "[E] Recoger" y con "interact" se recogen de 1 a 3 objetos. Vuelven a
## crecer al día siguiente del juego.

signal prompt_changed(text: String)

const PER_HABITAT := 22
const PICK_RADIUS := 2.2
## Tipo de punto por hábitat: [nombre, ícono, tabla de objetos {id: peso}, mín., máx.]
const KINDS := {
	SpeciesData.Habitat.MEADOW: [["Arbusto de bayas", "oran-berry", {"oran-berry": 60, "pecha-berry": 20, "cheri-berry": 15, "sitrus-berry": 5}, 1, 3]],
	SpeciesData.Habitat.FRESHWATER: [["Arbusto de bayas", "oran-berry", {"oran-berry": 55, "pecha-berry": 25, "sitrus-berry": 20}, 1, 3]],
	SpeciesData.Habitat.FOREST: [["Árbol de bonguri", "red-apricorn", {"red-apricorn": 40, "blu-apricorn": 35, "ylw-apricorn": 25}, 1, 2],
			["Setas", "tinymushroom", {"tinymushroom": 85, "big-mushroom": 15}, 1, 2]],
	SpeciesData.Habitat.SWAMP: [["Setas", "tinymushroom", {"tinymushroom": 70, "big-mushroom": 30}, 1, 2]],
	SpeciesData.Habitat.MOUNTAIN: [["Roca con minerales", "hard-stone", {"hard-stone": 60, "red-shard": 15, "blue-shard": 15, "star-piece": 5, "nugget": 5}, 1, 2]],
	SpeciesData.Habitat.SEA: [["Concha brillante", "pearl", {"pearl": 80, "big-pearl": 20}, 1, 1]],
}

@export var world_path: NodePath
@export var player_path: NodePath

var _world: WorldBuilder
var _player: Player
var _nodes: Array[Node3D] = []
var _nearest: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_world = get_node(world_path) as WorldBuilder
	_player = get_node(player_path) as Player
	_rng.seed = _world.config.seed * 31 + 5
	_place_all()


func _place_all() -> void:
	var half := _world.config.size * 0.5 - 12.0
	var counts := {}
	for attempt in PER_HABITAT * KINDS.size() * 6:
		var x := _rng.randf_range(-half, half)
		var z := _rng.randf_range(-half, half)
		var habitat := _world.habitat_at(x, z)
		if not KINDS.has(habitat) or counts.get(habitat, 0) >= PER_HABITAT:
			continue
		var on_beach := habitat == SpeciesData.Habitat.SEA
		if not on_beach and _world.water_depth_at(x, z) > -0.3:
			continue
		if on_beach and _world.water_depth_at(x, z) > -0.1:
			continue
		if Vector2(x, z).length() < 10.0:
			continue
		var kinds: Array = KINDS[habitat]
		var kind: Array = kinds[_rng.randi() % kinds.size()]
		counts[habitat] = counts.get(habitat, 0) + 1
		_nodes.append(_make_node(kind, Vector3(x, _world.surface_height_at(x, z), z)))


func _make_node(kind: Array, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "Gather%d" % _nodes.size()
	node.set_meta("kind", kind)
	node.set_meta("regrow_day", -1)
	add_child(node)
	node.global_position = at
	var sprite := Sprite3D.new()
	sprite.name = "Sprite"
	sprite.texture = Items.icon(kind[1])
	sprite.pixel_size = 0.045
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.layers = 2
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SpriteMaterials.apply(sprite)
	node.add_child(sprite)
	var sparkle := CPUParticles3D.new()
	sparkle.name = "Sparkle"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.12
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(1.0, 1.0, 0.75)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = material
	sparkle.mesh = quad
	sparkle.amount = 3
	sparkle.lifetime = 1.4
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkle.emission_sphere_radius = 0.5
	sparkle.gravity = Vector3(0, 0.4, 0)
	sparkle.initial_velocity_max = 0.2
	sparkle.position.y = 0.6
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 0.8, 1), Color(1, 1, 1, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	sparkle.color_ramp = fade
	sparkle.layers = 2
	node.add_child(sparkle)
	return node


func _process(_delta: float) -> void:
	var day := GameState.game_day()
	var best: Node3D
	var best_distance := PICK_RADIUS
	for node in _nodes:
		var available := int(node.get_meta("regrow_day")) <= day
		if node.visible != available:
			node.visible = available
		if not available or _player.mode != Player.Mode.WALK:
			continue
		var distance := node.global_position.distance_to(_player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	if best != _nearest:
		_nearest = best
		prompt_changed.emit("" if best == null else InputHints.label("interact", "Recoger: %s" % (best.get_meta("kind") as Array)[0]))


func _unhandled_input(event: InputEvent) -> void:
	if _nearest != null and event.is_action_pressed("interact") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		collect(_nearest)


## Recoge un punto: de 1 a 3 objetos de su tabla; vuelve a crecer al día siguiente.
func collect(node: Node3D) -> Dictionary:
	var kind: Array = node.get_meta("kind")
	var table: Dictionary = kind[2]
	var total := 0
	for id: String in table:
		total += int(table[id])
	var roll := _rng.randi_range(1, total)
	var picked: String = table.keys()[0]
	for id: String in table:
		roll -= int(table[id])
		if roll <= 0:
			picked = id
			break
	var amount := _rng.randi_range(int(kind[3]), int(kind[4]))
	GameState.add_item(picked, amount)
	GameState.gathered.emit(picked, amount)
	PixelBurst.spawn(get_parent(), node.global_position + Vector3.UP * 0.4, PixelBurst.Kind.LEAVES if kind[1] != "hard-stone" else PixelBurst.Kind.ROCK, 0.6)
	node.set_meta("regrow_day", GameState.game_day() + 1)
	node.visible = false
	_nearest = null
	prompt_changed.emit("")
	GameState.notice.emit("+%d %s" % [amount, Items.display_name(picked)])
	return {picked: amount}


## Puntos de recolección (para pruebas y para el mapa).
func nodes() -> Array[Node3D]:
	return _nodes
