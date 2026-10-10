class_name RecallBeam
extends Node3D
## Rayo rojo de la Pokéball (como en el anime) y la Pokéball que lo dispara: al
## guardar, el rayo sale de la ball en la mano y el Pokémon se vuelve rojo y entra en
## ella; al sacar, la ball se lanza, se abre con un destello y el rayo forma al Pokémon.

const BEAM_COLOR := Color(1.0, 0.15, 0.15)

var ball: Sprite3D
var _beam: MeshInstance3D


func _ready() -> void:
	ball = Sprite3D.new()
	ball.texture = PokeballProjectile._ball_texture()
	ball.pixel_size = 0.05
	ball.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ball.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ball.shaded = false
	ball.layers = 2
	add_child(ball)
	_mesh = ImmediateMesh.new()
	_beam = MeshInstance3D.new()
	_beam.mesh = _mesh
	_beam.layers = 2
	_beam.top_level = true
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)
	_glow = _material(BEAM_COLOR, 0.85)
	_core = _material(Color(1.0, 0.92, 0.9), 1.0)


var _mesh: ImmediateMesh
var _glow: StandardMaterial3D
var _core: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	return material


## Relámpago de from a to (posiciones del mundo): línea quebrada que tiembla en cada
## llamada, rojo por fuera y blanco en el centro, siempre de cara a la cámara.
func set_beam(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	_beam.visible = length > 0.05
	if not _beam.visible:
		return
	var camera := get_viewport().get_camera_3d()
	var view := (camera.global_position - (from + to) * 0.5).normalized() if camera != null else Vector3.BACK
	var dir := (to - from) / length
	var side := dir.cross(view).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var bend := view.cross(dir).normalized()
	# Zigzag: cada quiebre cambia de lado (como un relámpago), con amplitud al azar.
	var count := clampi(int(length / 0.4), 3, 18)
	var amplitude := clampf(length * 0.12, 0.12, 0.38)
	var points := PackedVector3Array()
	var sign := 1.0 if _rng.randf() < 0.5 else -1.0
	for i in count + 1:
		var t := float(i) / count
		var inner := i != 0 and i != count
		var jitter := sign * _rng.randf_range(0.4, 1.0) * amplitude if inner else 0.0
		sign = -sign
		points.append(from.lerp(to, t) + side * jitter + bend * (_rng.randf_range(-0.1, 0.1) if inner else 0.0))
	_mesh.clear_surfaces()
	_ribbon(points, view, 0.22, _glow)
	_ribbon(points, view, 0.07, _core)


func _ribbon(points: PackedVector3Array, view: Vector3, width: float, material: Material) -> void:
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
	for i in points.size():
		var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var across := along.cross(view).normalized() * width * 0.5
		_mesh.surface_add_vertex(points[i] + across)
		_mesh.surface_add_vertex(points[i] - across)
	_mesh.surface_end()


func hide_beam() -> void:
	_beam.visible = false


## Destello blanco (la ball que se abre o el Pokémon que aparece).
func flash(at: Vector3, size: float = 1.0) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = _flash_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.pixel_size = 0.03 * size
	sprite.layers = 2
	sprite.top_level = true
	add_child(sprite)
	sprite.global_position = at
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector3.ONE * 2.2, 0.25).from(Vector3.ONE * 0.3)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(sprite.queue_free)


static var _flash_tex: Texture2D


static func _flash_texture() -> Texture2D:
	if _flash_tex == null:
		var image := Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
		for y in 48:
			for x in 48:
				var v := Vector2(x - 23.5, y - 23.5)
				var d := v.length()
				var rays := absf(sin(v.angle() * 4.0))
				var a := clampf(1.0 - d / 24.0, 0.0, 1.0) * (0.55 + 0.45 * rays)
				if a > 0.02:
					image.set_pixel(x, y, Color(1.0, 1.0, 0.95, a))
		_flash_tex = ImageTexture.create_from_image(image)
	return _flash_tex
