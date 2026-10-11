class_name MountainPasses
extends Node3D
## Desfiladeros del mundo abierto (plan de pulido, decisión "Túneles" 2026-10-10): 4-6
## atajos de 40-80 m que cortan una cresta de montaña, cañón o meseta junto a un camino
## existente. El talle del terreno (piso bajo y parejo, paredes empinadas de roca a los
## lados) ya está en RegionLayout.height_at/_carve_pass; esta clase pone lo que no es
## terreno cuando se carga la zona de cada desfiladero (ver RegionLayout.passes):
## - Pasto (matas 3D) a lo largo del piso.
## - A veces un cofre 3D (mitad de los desfiladeros, fijo por su id).
## - Pokémon de roca propios de la zona (no solo los que ya salen por el bioma).
## - La roca grande que tapa la boca más baja (id estable "pass:<n>", igual que las
##   cuevas chicas): mientras no se rompe, un bloqueo físico (StaticBody3D invisible, de
##   piso a bien arriba del techo de vuelo) cierra el corredor entero, a pie o volando;
##   rota, el bloqueo se quita para siempre (persistido en world_flags["boulders"], como
##   cualquier roca grande) y se vuelve a hornear la navegación de esa zona.

const GRASS_TUFTS_PER_PASS := 16
const CHEST_CHANCE := 0.5
const SPAWN_PER_PASS := 2
const ROCK_POOL := ["geodude", "roggenrola", "onix", "nosepass", "rolycoly", "larvitar", "binacle", "rockruff", "shuckle"]
const CHEST_LOOT := ["ultra-ball", "full-heal", "hyper-potion", "star-piece", "rare-candy", "hard-stone"]
## Techo del bloqueo: de un poco bajo el piso hasta bien arriba del techo de vuelo del
## jugador (Player.FLY_CEILING = 260), para que tampoco se sobrevuele mientras la roca
## tapa el paso.
const BLOCK_BOTTOM := -6.0
const BLOCK_TOP := 306.0

@export var world_path: NodePath
@export var navigation_path: NodePath = NodePath("../Navigation")

var _world: WorldBuilder
var _rng := RandomNumberGenerator.new()
## Desfiladero (su id) -> zona (Vector2i) donde está construido ahora.
var _built := {}
## Desfiladero (su id) -> punto de interacción del cofre (para quitarlo si se libera la zona).
var _points := {}


func _ready() -> void:
	add_to_group(&"mountain_passes")
	_rng.randomize()
	_world = get_node(world_path) as WorldBuilder
	_world.chunk_built.connect(_on_chunk_built)
	_world.chunk_freed.connect(_on_chunk_freed)
	var chunks := _world.near_chunks()
	for key: Vector2i in chunks:
		_on_chunk_built(key, chunks[key])


func _on_chunk_built(key: Vector2i, root: Node3D) -> void:
	for entry: Dictionary in _world.layout.passes:
		var id: String = entry["id"]
		if _built.has(id) or _world._chunk_key(float(entry["mid_x"]), float(entry["mid_z"])) != key:
			continue
		_build(key, root, entry)


func _on_chunk_freed(key: Vector2i) -> void:
	for id: String in _built.keys():
		if _built[id] != key:
			continue
		_built.erase(id)
		if _points.has(id):
			_world.structures.remove_point(_points[id])
			_points.erase(id)


func _build(key: Vector2i, root: Node3D, entry: Dictionary) -> void:
	var id: String = entry["id"]
	_built[id] = key
	var a := Vector2(float(entry["ax"]), float(entry["az"]))
	var b := Vector2(float(entry["bx"]), float(entry["bz"]))
	var node := Node3D.new()
	node.name = "Pass_" + id.replace(":", "_")
	root.add_child(node)
	if not BreakableRock.boulder_broken(id):
		_build_block(node, entry, a, b, key)
	_scatter_grass(node, a, b)
	_maybe_chest(node, entry, a, b)
	_maybe_spawn(entry, a, b)


## La roca grande (ver BreakableRock) y el bloqueo invisible que cierra todo el corredor
## (de piso a techo de vuelo) mientras no se rompe.
func _build_block(node: Node3D, entry: Dictionary, a: Vector2, b: Vector2, key: Vector2i) -> void:
	var id: String = entry["id"]
	var dir := (b - a).normalized()
	var rock_xz := RegionLayout.pass_rock_point(entry)
	var rock_at := Vector3(rock_xz.x, _world.surface_height_at(rock_xz.x, rock_xz.y), rock_xz.y)
	var rock := BreakableRock.create(node, rock_at, id, true)
	var blocker := StaticBody3D.new()
	blocker.name = "PassBlock"
	blocker.collision_layer = WorldBuilder.LAYER_OBSTACLES | WorldBuilder.LAYER_CAMERA
	var width := (RegionLayout.PASS_WIDTH + RegionLayout.PASS_WALL_BAND) * 2.0 + 1.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, BLOCK_TOP - BLOCK_BOTTOM, 3.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = (BLOCK_TOP + BLOCK_BOTTOM) * 0.5
	blocker.add_child(collision)
	blocker.rotation.y = atan2(dir.x, dir.y)
	node.add_child(blocker)
	blocker.global_position = rock_at
	rock.broken.connect(_on_pass_broken.bind(id, blocker, key))
	_rebake(key, node.get_parent() as Node3D)


func _on_pass_broken(_rock: BreakableRock, id: String, blocker: StaticBody3D, key: Vector2i) -> void:
	if is_instance_valid(blocker):
		blocker.queue_free()
	GameState.notice.emit("¡El desfiladero quedó abierto! Ya se puede cruzar.")
	_rebake(key, _world.near_chunks().get(key) as Node3D)


## Vuelve a hornear la navegación de la zona (ver WorldNavigation._bake_chunk): hace falta
## tanto al construir (para que la roca y el bloqueo queden tallados en el camino horneado
## justo al cargar la zona) como al romperla (para que quede transitable).
func _rebake(key: Vector2i, root: Node3D) -> void:
	if root == null:
		return
	var nav := get_node_or_null(navigation_path) as WorldNavigation
	if nav != null:
		nav._bake_chunk(key, root)


## Matas de pasto 3D a lo largo del piso (decisión "Túneles": "algo de pasto").
func _scatter_grass(node: Node3D, a: Vector2, b: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(a) ^ hash(b) ^ 91
	var side := (b - a).normalized().orthogonal()
	for i in GRASS_TUFTS_PER_PASS:
		var t := rng.randf_range(0.08, 0.92)
		var offset := rng.randf_range(-RegionLayout.PASS_WIDTH * 0.75, RegionLayout.PASS_WIDTH * 0.75)
		var p := a.lerp(b, t) + side * offset
		var texture := PropArt.texture(["tuft_green", "tuft_light"][rng.randi() % 2])
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = PropModels3D.foliage_mesh(texture, _world.config.pixel_size)
		mesh_instance.material_override = FoliageMaterials.for_texture(texture, Color.WHITE, true, false)
		mesh_instance.position = Vector3(p.x, _world.surface_height_at(p.x, p.y) - 0.04, p.y)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(mesh_instance)


## La mitad de los desfiladeros (fijo por su id) tiene un cofre 3D, lejos de la boca tapada.
func _maybe_chest(node: Node3D, entry: Dictionary, a: Vector2, b: Vector2) -> void:
	var id: String = entry["id"]
	if absi(hash(id + ":chest")) % 100 >= int(CHEST_CHANCE * 100):
		return
	var t := 0.6 if String(entry["rock_end"]) == "a" else 0.4
	var p := a.lerp(b, t)
	var at := Vector3(p.x, _world.surface_height_at(p.x, p.y), p.y)
	var anchor := Node3D.new()
	anchor.name = "ChestAnchor"
	node.add_child(anchor)
	anchor.global_position = at
	var chest := Chest3D.build(anchor, Vector3.ZERO, Chest3D.tier_for(id))
	var flag_key := "pass_chest:%s" % id
	var action := func() -> void:
		if bool(GameState.world_flags.get(flag_key, false)):
			GameState.notice.emit("El cofre del desfiladero está vacío.")
			return
		GameState.world_flags[flag_key] = true
		Chest3D.open(chest)
		var item: String = CHEST_LOOT[_rng.randi() % CHEST_LOOT.size()]
		GameState.add_item(item, 1)
		AudioBus.play_jingle("me_item")
		GameState.notice.emit("Encontraste %s en el cofre del desfiladero." % Items.display_name(item))
	_points[id] = _world.structures.add_point(at + Vector3(0, 0.5, 0.8), "Abrir el cofre", action, 2.6)


## Pokémon de roca propios del desfiladero (además de los que ya salen por el bioma): 1-2
## por día, repartidos por el corredor.
func _maybe_spawn(entry: Dictionary, a: Vector2, b: Vector2) -> void:
	var id: String = entry["id"]
	var day_key := "pass_spawn_day:%s" % id
	if int(GameState.world_flags.get(day_key, -1)) == GameState.game_day():
		return
	GameState.world_flags[day_key] = GameState.game_day()
	var spawner := get_parent().get_node_or_null("Spawner") as WildSpawner
	if spawner == null:
		return
	var pool: Array[SpeciesData] = []
	for sid: String in ROCK_POOL:
		var species := MenuStyle.species(sid)
		if species != null and Regions.allows(species):
			pool.append(species)
	if pool.is_empty():
		return
	for i in SPAWN_PER_PASS:
		var t := _rng.randf_range(0.15, 0.85)
		var p := a.lerp(b, t) + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
		var species: SpeciesData = pool[_rng.randi() % pool.size()]
		spawner.spawn_species(species, Vector3(p.x, _world.surface_height_at(p.x, p.y), p.y), _rng.randf() < spawner.shiny_chance(), false)
