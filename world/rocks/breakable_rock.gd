class_name BreakableRock
extends StaticBody3D
## Roca rompible (fase 5.8, decisiones de Fernando 2026-10-10). En 3D de pocas caras con
## textura pixel y grietas marcadas, distinta de las rocas decorativas (que son sprites).
## - Pequeña: la rompe cualquier compañero atacándola (teclas 1-4 de sus movimientos; ver
##   PokemonActor.command_move). La coloca BreakableRocks y reaparece a los 3 días.
## - Grande: tapa bocas de cuevas, cuevas chicas y túneles; solo la rompe un compañero de
##   tipo Lucha, Roca, Tierra o Acero, o que sepa Golpe Roca. Rota, queda abierta para
##   siempre en esa región (world_flags["boulders"]).

signal broken(rock: BreakableRock)

const GROUP := &"breakable_rocks"
const STRONG_TYPES := [PokemonTypes.Type.FIGHTING, PokemonTypes.Type.ROCK, PokemonTypes.Type.GROUND, PokemonTypes.Type.STEEL]
const SMASH_MOVE := "rock-smash"
const SMALL_SIZE := Vector3(1.0, 0.75, 0.9)
const BIG_SIZE := Vector3(3.6, 3.2, 3.0)

var big := false
var rock_id := ""
var _done := false
var _warned := 0.0

static var _textures := {}


## Crea una roca en at (pies) dentro de parent. id fija su forma. Si parent aún no está en
## el árbol, at es relativo a parent.
static func create(parent: Node3D, at: Vector3, id: String, is_big: bool) -> BreakableRock:
	var rock := BreakableRock.new()
	rock.name = ("Boulder_" if is_big else "CrackedRock_") + id.replace(":", "_")
	rock.big = is_big
	rock.rock_id = id
	rock.collision_layer = WorldBuilder.LAYER_OBSTACLES | (WorldBuilder.LAYER_CAMERA if is_big else 0)
	parent.add_child(rock)
	if parent.is_inside_tree():
		rock.global_position = at
	else:
		rock.position = at
	rock._build()
	return rock


## ¿Ya se rompió esta roca grande? (para no reconstruirla)
static func boulder_broken(id: String) -> bool:
	return bool((GameState.world_flags.get("boulders", {}) as Dictionary).get(id, false))


## ¿Puede attacker romper una roca grande?
static func strong_enough(attacker: PokemonActor) -> bool:
	if attacker == null or attacker.species == null:
		return false
	for type in attacker.species.types:
		if STRONG_TYPES.has(type):
			return true
	return attacker.moves.has(SMASH_MOVE) or (attacker.party_entry.get("unlocked", []) as Array).has(SMASH_MOVE)


func _ready() -> void:
	add_to_group(GROUP)


func is_broken() -> bool:
	return _done


func _process(delta: float) -> void:
	_warned = maxf(_warned - delta, 0.0)


## Golpe de un movimiento del compañero (lo llama PokemonActor._apply_move_hit).
func take_move_hit(attacker: PokemonActor, _move_id: String) -> void:
	if _done:
		return
	if big and not strong_enough(attacker):
		PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.8, PixelBurst.Kind.DUST, 0.6)
		_wobble(0.05)
		if _warned <= 0.0:
			_warned = 4.0
			GameState.notice.emit("La roca es demasiado dura. Necesitas un compañero de tipo Lucha, Roca, Tierra o Acero, o que sepa Golpe Roca.")
		return
	smash()


## Se rompe: pedazos, polvo, temblor; las grandes quedan rotas para siempre.
func smash() -> void:
	if _done:
		return
	_done = true
	if big:
		if not GameState.world_flags.has("boulders"):
			GameState.world_flags["boulders"] = {}
		GameState.world_flags["boulders"][rock_id] = true
	var size := BIG_SIZE if big else SMALL_SIZE
	PixelBurst.spawn(get_parent(), global_position + Vector3.UP * size.y * 0.5, PixelBurst.Kind.ROCK, 1.6 if big else 0.9)
	PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.3, PixelBurst.Kind.DUST, 1.4 if big else 0.7)
	AudioBus.play_sfx("hit_super")
	var rig := get_tree().get_first_node_in_group(CameraRig.CAMERA_GROUP) as CameraRig
	if rig != null:
		rig.shake(0.6 if big else 0.25)
	_debris(size)
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
	var mesh := get_node_or_null("Mesh") as Node3D
	if mesh != null:
		var tween := mesh.create_tween()
		tween.tween_property(mesh, "scale", Vector3(1.15, 0.1, 1.15), 0.18)
		tween.tween_callback(mesh.hide)
	broken.emit(self)


## Rota desde antes (al cargar la zona): sin efectos ni premio.
func smash_silently() -> void:
	_done = true
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
	var mesh := get_node_or_null("Mesh") as Node3D
	if mesh != null:
		mesh.hide()


## Vuelve a aparecer (rocas pequeñas, a los 3 días).
func restore() -> void:
	_done = false
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", false)
	var mesh := get_node_or_null("Mesh") as Node3D
	if mesh != null:
		mesh.scale = Vector3.ONE
		mesh.show()


func _wobble(amount: float) -> void:
	var mesh := get_node_or_null("Mesh") as Node3D
	if mesh == null:
		return
	var tween := mesh.create_tween()
	for i in 4:
		tween.tween_property(mesh, "position:x", amount * (1.0 if i % 2 == 0 else -1.0), 0.04)
	tween.tween_property(mesh, "position:x", 0.0, 0.04)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(rock_id)
	var size := BIG_SIZE if big else SMALL_SIZE
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = rock_mesh(size, rng)
	mesh.material_override = _material(big)
	add_child(mesh)
	var shape := CylinderShape3D.new()
	shape.radius = maxf(size.x, size.z) * 0.45
	shape.height = size.y
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = size.y * 0.5
	add_child(collision)


## Roca de pocas caras: un octaedro subdividido con los vértices movidos al azar, caras planas.
static func rock_mesh(size: Vector3, rng: RandomNumberGenerator) -> ArrayMesh:
	var top := Vector3.UP
	var ring: Array[Vector3] = []
	var sides := 7
	for i in sides:
		var angle := TAU * i / sides + rng.randf_range(-0.2, 0.2)
		ring.append(Vector3(cos(angle), rng.randf_range(0.35, 0.6), sin(angle)) * rng.randf_range(0.85, 1.1))
	var low: Array[Vector3] = []
	for i in sides:
		var angle := TAU * (i + 0.5) / sides + rng.randf_range(-0.15, 0.15)
		low.append(Vector3(cos(angle) * rng.randf_range(0.95, 1.15), rng.randf_range(0.0, 0.12), sin(angle) * rng.randf_range(0.95, 1.15)))
	top = Vector3(rng.randf_range(-0.2, 0.2), 1.0, rng.randf_range(-0.2, 0.2))
	var scale := Vector3(size.x * 0.5, size.y, size.z * 0.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		for v: Vector3 in [a, b, c]:
			st.set_uv(Vector2(v.x + v.z, v.y))
			st.add_vertex(v * scale)
	for i in sides:
		var j := (i + 1) % sides
		tri.call(top, ring[i], ring[j])
		tri.call(ring[i], low[i], ring[j])
		tri.call(ring[j], low[i], low[j])
		tri.call(Vector3(low[i].x * 0.6, -0.05, low[i].z * 0.6), low[j], low[i])
	st.generate_normals()
	return st.commit()


static func _material(is_big: bool) -> StandardMaterial3D:
	var key := "big" if is_big else "small"
	if not _textures.has(key):
		_textures[key] = _crack_texture(is_big)
	var material := StandardMaterial3D.new()
	material.albedo_texture = _textures[key]
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * (0.55 if is_big else 0.9)
	material.roughness = 1.0
	return material


## Textura pixel de 24×24: piedra con motas y grietas oscuras en zigzag.
static func _crack_texture(is_big: bool) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 if is_big else 777
	var base := Color(0.5, 0.46, 0.43) if is_big else Color(0.7, 0.62, 0.5)
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var shade := rng.randf_range(-0.06, 0.06) + (0.05 if (x / 4 + y / 4) % 2 == 0 else 0.0)
			image.set_pixel(x, y, Color(base.r + shade, base.g + shade, base.b + shade))
	var crack := base.darkened(0.65)
	for line in (4 if is_big else 3):
		var x := rng.randi_range(2, 21)
		var y := 0
		while y < 24:
			image.set_pixel(clampi(x, 0, 23), y, crack)
			if rng.randf() < 0.5:
				x += 1 if rng.randf() < 0.5 else -1
				image.set_pixel(clampi(x, 0, 23), y, crack)
			y += 1
	return ImageTexture.create_from_image(image)


func _debris(size: Vector3) -> void:
	var material := _material(big)
	for i in (10 if big else 6):
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s := randf_range(0.12, 0.3) * (2.2 if big else 1.0)
		box.size = Vector3(s, s * 0.8, s)
		piece.mesh = box
		piece.material_override = material
		get_parent().add_child(piece)
		piece.global_position = global_position + Vector3(randf_range(-0.3, 0.3) * size.x, size.y * randf_range(0.3, 0.8), randf_range(-0.3, 0.3) * size.z)
		var out := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * size.x * randf_range(0.6, 1.2)
		var end := piece.global_position + out
		end.y = global_position.y + 0.05
		var tween := piece.create_tween()
		tween.tween_property(piece, "global_position", end, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(piece, "rotation", Vector3(randf() * 4, randf() * 4, randf() * 4), 0.45)
		tween.tween_interval(1.2)
		tween.tween_property(piece, "scale", Vector3.ZERO, 0.4)
		tween.tween_callback(piece.queue_free)
