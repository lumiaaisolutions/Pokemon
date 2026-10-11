class_name FishingMinigame
extends Node3D
## Minijuego de pesca con la Caña (campamento, comida y hambre; acordado con Fernando
## el 2026-10-10): se lanza el anzuelo, se espera a que "muerda" (aviso "¡!") y hay que
## apretar Interactuar a tiempo; si se logra sale Pescado Crudo y, a veces, un Pokémon
## de agua que pelea. Animado (decisión de Fernando, 2026-10-10): Nate saca la caña, el
## sedal vuela al agua, el corcho flota con ondas y se hunde al picar; al sacar, el pez
## salta del agua hacia Nate o el Pokémon sale donde estaba el corcho.

enum State { CAST, WAIT, BITE, DONE }

const WAIT_MIN := 1.5
const WAIT_MAX := 4.0
const BITE_WINDOW := 1.1
const CAST_SECONDS := 0.45
## Probabilidad de que salga un Pokémon de agua en vez del pescado (más con la Caña Buena).
const POKEMON_CHANCE := 0.28

var main: Node
var player: Player
var rod_tier: int = 1

var state: State = State.CAST
var _timer: float = 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _world: WorldBuilder
var _rod: Node3D
var _bobber: Node3D
var _line: MeshInstance3D
var _line_material: StandardMaterial3D
var _target := Vector3.ZERO
var _water_y := 0.0
var _ripple_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	_world = main.get_node_or_null("World") as WorldBuilder if main != null else null
	_find_water_spot()
	_build_rod()
	_build_bobber()
	state = State.CAST
	_timer = CAST_SECONDS
	AudioBus.play_sfx("ui_select")


## El agua frente a Nate (según hacia dónde mira), entre 2.5 y 7 m.
func _find_water_spot() -> void:
	var facing := Vector3.FORWARD
	var sprite := player.get_node_or_null("Sprite") as DirectionalSprite if player != null else null
	if sprite != null:
		facing = sprite.facing_world
	var origin := player.global_position if player != null else Vector3.ZERO
	_target = origin + facing * 4.0
	if _world != null:
		for k in 24:
			var distance := 2.5 + (k % 8) * 0.6
			var dir := facing.rotated(Vector3.UP, (k / 8) * 0.5 * (1.0 if k % 2 == 0 else -1.0))
			var at := origin + dir * distance
			if _world.water_depth_at(at.x, at.z) > 0.3:
				_target = at
				break
		_water_y = _world.water_level_at(_target.x, _target.z)
	else:
		_water_y = origin.y
	_target.y = _water_y


func _hand() -> Vector3:
	var facing := (Vector3(_target.x, 0, _target.z) - Vector3(player.global_position.x, 0, player.global_position.z)).normalized()
	return player.global_position + Vector3.UP * 1.0 + facing * 0.3


func _tip() -> Vector3:
	var facing := (Vector3(_target.x, 0, _target.z) - Vector3(player.global_position.x, 0, player.global_position.z)).normalized()
	return player.global_position + Vector3.UP * 2.1 + facing * 1.5


## Caña de dos tramos (mango de madera y vara gris) y el sedal.
func _build_rod() -> void:
	_rod = Node3D.new()
	add_child(_rod)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.28, 0.16)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.7, 0.72, 0.78) if rod_tier > 1 else Color(0.82, 0.68, 0.45)
	var hand := _hand()
	var tip := _tip()
	var mid := hand.lerp(tip, 0.3)
	_rod.add_child(Camp._stick(hand, mid, 0.04, wood))
	_rod.add_child(Camp._stick(mid, tip, 0.02, metal))
	_line = MeshInstance3D.new()
	_line.mesh = ImmediateMesh.new()
	_line.top_level = true
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = Color(0.95, 0.95, 0.95)
	add_child(_line)


## Corcho rojo y blanco.
func _build_bobber() -> void:
	_bobber = Node3D.new()
	add_child(_bobber)
	for half in [0, 1]:
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.13
		sphere.height = 0.26
		sphere.radial_segments = 8
		sphere.rings = 4
		sphere.is_hemisphere = true
		mesh.mesh = sphere
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.9, 0.15, 0.15) if half == 0 else Color(0.98, 0.98, 0.98)
		material.roughness = 1.0
		mesh.material_override = material
		if half == 1:
			mesh.rotation.x = PI
		_bobber.add_child(mesh)
	_bobber.global_position = _tip()


func _draw_line(to: Vector3) -> void:
	var mesh := _line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)
	var tip := _tip()
	var points := 8
	for i in points:
		var a := tip.lerp(to, float(i) / points) - Vector3.UP * sin(float(i) / points * PI) * 0.3
		var b := tip.lerp(to, float(i + 1) / points) - Vector3.UP * sin(float(i + 1) / points * PI) * 0.3
		mesh.surface_add_vertex(a)
		mesh.surface_add_vertex(b)
	mesh.surface_end()


func _ripple(size: float) -> void:
	var ring := Sprite3D.new()
	ring.texture = PixelShapes.get_texture("ring", Color(0.85, 0.95, 1.0))
	ring.pixel_size = 0.02
	ring.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ring.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	ring.shaded = false
	ring.rotation.x = -PI * 0.5
	add_child(ring)
	ring.global_position = Vector3(_target.x, _water_y + 0.03, _target.z)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * size, 0.8)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.8)
	tween.tween_callback(ring.queue_free)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	_time += delta
	match state:
		State.CAST:
			_timer -= delta
			var t := clampf(1.0 - _timer / CAST_SECONDS, 0.0, 1.0)
			_bobber.global_position = _tip().lerp(_target, t) + Vector3.UP * sin(t * PI) * 1.5
			if _timer <= 0.0:
				state = State.WAIT
				_timer = _rng.randf_range(WAIT_MIN, WAIT_MAX)
				PixelBurst.spawn(get_parent(), _target + Vector3.UP * 0.1, PixelBurst.Kind.SPLASH, 0.5)
				_ripple(2.5)
				GameState.notice.emit("Lanzas el anzuelo al agua...")
		State.WAIT:
			_timer -= delta
			_bobber.global_position = _target + Vector3.UP * (0.05 + sin(_time * 2.5) * 0.03)
			_ripple_timer -= delta
			if _ripple_timer <= 0.0:
				_ripple_timer = 1.4
				_ripple(1.6)
			if _timer <= 0.0:
				state = State.BITE
				_timer = BITE_WINDOW
				GameState.notice.emit("¡¡!! (%s para jalar)" % InputHints.hint("interact"))
				AudioBus.play_sfx("ui_select", 1.3)
				_exclaim()
		State.BITE:
			_timer -= delta
			# El corcho se hunde a tirones con salpicaduras.
			_bobber.global_position = _target + Vector3.UP * (-0.12 + absf(sin(_time * 14.0)) * 0.1)
			if fmod(_time, 0.3) < delta:
				PixelBurst.spawn(get_parent(), _target + Vector3.UP * 0.1, PixelBurst.Kind.SPLASH, 0.35)
				_ripple(1.2)
			if Input.is_action_just_pressed("interact"):
				_catch()
			elif _timer <= 0.0:
				GameState.notice.emit("Se escapó la pesca...")
				_end()
	if state != State.DONE and is_instance_valid(_bobber):
		_draw_line(_bobber.global_position)


func _exclaim() -> void:
	var label := Label3D.new()
	label.text = "¡!"
	label.font_size = 64
	label.pixel_size = 0.01
	label.outline_size = 12
	label.modulate = Color(1.0, 0.85, 0.2)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	label.global_position = _target + Vector3.UP * 1.0
	var tween := label.create_tween()
	tween.tween_interval(BITE_WINDOW)
	tween.tween_callback(label.queue_free)


func _catch() -> void:
	AudioBus.play_sfx("ui_decide")
	state = State.DONE
	PixelBurst.spawn(get_parent(), _target + Vector3.UP * 0.2, PixelBurst.Kind.SPLASH, 1.2)
	if _rng.randf() < POKEMON_CHANCE * (1.4 if rod_tier > 1 else 1.0):
		var species := _pick_water_species()
		var spawner := main.get_node_or_null("Spawner") as WildSpawner if main != null else null
		if spawner != null and species != null:
			# Sale del agua donde estaba el corcho.
			spawner.spawn_species(species, Vector3(_target.x, _water_y, _target.z), _rng.randf() < 0.02, true)
			GameState.notice.emit("¡Algo tiró de la caña! Salió un %s." % species.display_name)
			_finish_after(0.4)
			return
	GameState.add_item("raw-fish", 1)
	GameState.notice.emit("¡Sacaste un Pescado Crudo!")
	AudioBus.play_jingle("me_item")
	# El pez salta del agua y llega a la mano de Nate.
	var fish := Sprite3D.new()
	fish.texture = Items.icon("raw-fish")
	fish.pixel_size = 0.04
	fish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fish.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fish.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	fish.shaded = false
	add_child(fish)
	var from := _target
	var to := _hand()
	var tween := fish.create_tween()
	tween.tween_method(func(t: float) -> void:
		fish.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 2.0
		_bobber.global_position = fish.global_position
		_draw_line(_bobber.global_position), 0.0, 1.0, 0.6)
	tween.tween_callback(queue_free)


func _finish_after(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_bobber, "global_position", _tip(), seconds)
	tween.tween_callback(queue_free)


## Pokémon de agua de la Pokédex regional: dulce (Caña Vieja) o salado (Caña Buena).
func _pick_water_species() -> SpeciesData:
	var habitat := SpeciesData.Habitat.SEA if rod_tier > 1 else SpeciesData.Habitat.FRESHWATER
	var pool: Array[SpeciesData] = []
	for species: SpeciesData in WildSpawner.ALL_SPECIES.species:
		if species.spawn_weight > 0.0 and not species.is_legendary and not species.is_mythical \
				and species.habitats.has(habitat) and Regions.allows(species):
			pool.append(species)
	if pool.is_empty():
		return null
	return pool[_rng.randi() % pool.size()]


func _end() -> void:
	state = State.DONE
	_finish_after(0.3)
