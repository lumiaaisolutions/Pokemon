class_name GatherManager
extends Node3D
## Puntos de recolección del mundo: arbustos de bayas, árboles de bonguri, setas, rocas
## con minerales y conchas, según el hábitat. Brillan para que se vean; cerca de uno, el
## HUD muestra "[E] Recoger" y con "interact" se recogen de 1 a 3 objetos. Vuelven a
## crecer al día siguiente del juego. Se crean con cada zona cercana del mundo (siempre
## los mismos para la misma semilla) y se liberan con ella.

signal prompt_changed(text: String)

## Cada punto tiene contexto: las bayas crecen en arbustos, los bonguris en árboles, las
## setas al pie de un árbol de la zona, los minerales en rocas y las conchas en la orilla.
## Lo que se recoge desaparece de su arbusto/árbol/roca y vuelve a crecer al otro día.
const BASES := {"Arbusto de bayas": "res://art/world/b2w2/bush.png", "Árbol de bonguri": "res://art/world/b2w2/tree_round.png",
		"Roca con minerales": "res://art/world/b2w2/rock_brown.png"}
## Dónde van los frutos sobre la base (en metros, relativos a su pie).
const FRUIT_SPOTS := {"Arbusto de bayas": [Vector3(-0.35, 0.75, 0.15), Vector3(0.3, 0.95, 0.12), Vector3(0.05, 0.55, 0.2)],
		"Árbol de bonguri": [Vector3(-0.8, 2.6, 0.2), Vector3(0.7, 2.9, 0.2), Vector3(0.1, 3.3, 0.2)],
		"Roca con minerales": [Vector3(0.3, 0.55, 0.3)], "Setas": [Vector3(0.0, 0.15, 0.0), Vector3(0.35, 0.12, 0.2)],
		"Concha brillante": [Vector3(0.0, 0.08, 0.0)]}

## Intentos de punto por zona de 128 m.
const PER_CHUNK := 4
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
	_rng.randomize()
	_world.chunk_built.connect(_populate)
	var chunks := _world.near_chunks()
	for key: Vector2i in chunks:
		_populate(key, chunks[key])


## Puntos de una zona recién construida (deterministas por semilla y zona).
func _populate(key: Vector2i, root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ (_world.config.seed * 31 + 5)
	for i in PER_CHUNK:
		var x := (key.x + rng.randf()) * WorldBuilder.CHUNK
		var z := (key.y + rng.randf()) * WorldBuilder.CHUNK
		var pick := rng.randi()
		var habitat := _world.habitat_at(x, z)
		if not KINDS.has(habitat) or not _world.is_inside(x, z, 12.0):
			continue
		var on_beach := habitat == SpeciesData.Habitat.SEA
		var depth := _world.water_depth_at(x, z)
		if (not on_beach and depth > -0.3) or (on_beach and depth > -0.1):
			continue
		if not _world.settlement_at(x, z, 4.0).is_empty() or _world.distance_to_paths(x, z) < 3.0:
			continue
		var kinds: Array = KINDS[habitat]
		var kind: Array = kinds[pick % kinds.size()]
		var at := Vector3(x, _world.surface_height_at(x, z), z)
		if kind[0] == "Setas":
			# Al pie de un árbol cercano de la zona.
			var tree := _tree_near(root, Vector2(x, z), rng)
			if tree == null:
				continue
			var angle := rng.randf() * TAU
			var spot := tree.global_position + Vector3(cos(angle), 0, sin(angle)) * 0.9
			at = Vector3(spot.x, _world.surface_height_at(spot.x, spot.z), spot.z)
		elif kind[0] == "Concha brillante":
			# En la arena, junto al agua.
			if not _near_water(x, z):
				continue
		var id := "%d_%d_%d" % [key.x, key.y, i]
		_nodes.append(_make_node(kind, at, root, id))


func _tree_near(root: Node3D, point: Vector2, rng: RandomNumberGenerator) -> Node3D:
	var trees: Array[Node3D] = []
	for child in root.get_children():
		if child is StaticBody3D and String(child.name).begins_with("Tree"):
			trees.append(child)
	if trees.is_empty():
		return null
	trees.sort_custom(func(a: Node3D, b: Node3D) -> bool: return Vector2(a.global_position.x, a.global_position.z).distance_to(point) < Vector2(b.global_position.x, b.global_position.z).distance_to(point))
	return trees[mini(rng.randi() % 3, trees.size() - 1)]


func _near_water(x: float, z: float) -> bool:
	for i in 8:
		var angle := TAU * i / 8.0
		if _world.water_depth_at(x + cos(angle) * 2.5, z + sin(angle) * 2.5) > 0.15:
			return true
	return false


## Qué da este punto hoy (fijo por punto y día): es el mismo fruto que se ve en él.
func item_for(node: Node3D) -> String:
	var kind: Array = node.get_meta("kind")
	var table: Dictionary = kind[2]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [node.get_meta("id"), GameState.game_day()])
	var total := 0
	for id: String in table:
		total += int(table[id])
	var roll := rng.randi_range(1, total)
	for id: String in table:
		roll -= int(table[id])
		if roll <= 0:
			return id
	return table.keys()[0]


func _refresh_fruit(node: Node3D) -> void:
	var texture := Items.icon(item_for(node))
	for child in node.get_node("Fruit").get_children():
		if child is Sprite3D:
			(child as Sprite3D).texture = texture


func _make_node(kind: Array, at: Vector3, parent: Node3D, id: String) -> Node3D:
	var node := Node3D.new()
	node.name = "Gather_%s" % id
	node.set_meta("kind", kind)
	node.set_meta("id", id)
	node.set_meta("regrow_day", int((GameState.world_flags.get("gather", {}) as Dictionary).get(id, -1)))
	parent.add_child(node)
	node.global_position = at
	# Base: arbusto, árbol o roca (estilo B2W2).
	if BASES.has(kind[0]):
		var base := Sprite3D.new()
		base.name = "Base"
		base.texture = load(BASES[kind[0]])
		base.pixel_size = _world.config.pixel_size * (1.4 if kind[0] == "Árbol de bonguri" else 1.0)
		base.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		base.layers = 2
		SpriteMaterials.apply(base)
		base.material_override = SpriteMaterials.for_texture(base.texture, Color.WHITE, 0.0, kind[0] != "Roca con minerales")
		node.add_child(base)
	# Frutos (íconos pequeños sobre la base).
	var fruit := Node3D.new()
	fruit.name = "Fruit"
	node.add_child(fruit)
	for spot: Vector3 in FRUIT_SPOTS.get(kind[0], [Vector3(0, 0.1, 0)]):
		var sprite := Sprite3D.new()
		sprite.texture = Items.icon(item_for(node))
		sprite.pixel_size = 0.022 if kind[0] in ["Arbusto de bayas", "Árbol de bonguri"] else 0.03
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.layers = 2
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.position = spot
		fruit.add_child(sprite)
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
	fruit.add_child(sparkle)
	return node


func _process(_delta: float) -> void:
	var day := GameState.game_day()
	var alive: Array[Node3D] = []
	for n in _nodes:
		if is_instance_valid(n) and not (n as Node3D).is_queued_for_deletion():
			alive.append(n)
	_nodes = alive
	var best: Node3D
	var best_distance := PICK_RADIUS
	for node in _nodes:
		var available := int(node.get_meta("regrow_day")) <= day
		var fruit := node.get_node("Fruit") as Node3D
		if fruit.visible != available:
			fruit.visible = available
			if available:
				_refresh_fruit(node)
		if not available or _player.mode != Player.Mode.WALK:
			continue
		var distance := node.global_position.distance_to(_player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	if best != _nearest:
		_nearest = best
		prompt_changed.emit("" if best == null else InputHints.label("interact", "Recoger: %s (%s)" % [Items.display_name(item_for(best)), String((best.get_meta("kind") as Array)[0]).to_lower()]))


func _unhandled_input(event: InputEvent) -> void:
	if _nearest != null and event.is_action_pressed("interact") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		collect(_nearest)


## Recoge un punto: de 1 a 3 objetos de su tabla; vuelve a crecer al día siguiente.
func collect(node: Node3D) -> Dictionary:
	var kind: Array = node.get_meta("kind")
	var picked := item_for(node)
	var amount := _rng.randi_range(int(kind[3]), int(kind[4]))
	GameState.add_item(picked, amount)
	GameState.gathered.emit(picked, amount)
	PixelBurst.spawn(get_parent(), node.global_position + Vector3.UP * 0.4, PixelBurst.Kind.LEAVES if kind[1] != "hard-stone" else PixelBurst.Kind.ROCK, 0.6)
	node.set_meta("regrow_day", GameState.game_day() + 1)
	(node.get_node("Fruit") as Node3D).visible = false
	if not GameState.world_flags.has("gather"):
		GameState.world_flags["gather"] = {}
	GameState.world_flags["gather"][node.get_meta("id")] = GameState.game_day() + 1
	_nearest = null
	prompt_changed.emit("")
	GameState.notice.emit("+%d %s" % [amount, Items.display_name(picked)])
	return {picked: amount}


## Puntos de recolección (para pruebas y para el mapa).
func nodes() -> Array[Node3D]:
	return _nodes
