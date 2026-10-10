class_name ThrowAim
extends Node3D
## Apuntar y lanzar Pokéballs desde el jugador: con "aim" la cámara pasa al hombro y
## se dibuja el arco de la trayectoria; con "throw" se lanza la ball (física real).

const THROW_SPEED := 17.0
const THROW_LIFT := 3.0
const ARC_POINTS := 24
const ARC_STEP := 0.06

var _player: Player
var _rig: CameraRig
var _dots: Array[Sprite3D] = []
var _world: WorldBuilder


func _ready() -> void:
	_player = get_parent() as Player
	top_level = true
	var dot_texture := _dot_texture()
	for i in ARC_POINTS:
		var dot := Sprite3D.new()
		dot.texture = dot_texture
		dot.pixel_size = 0.04
		dot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		dot.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		dot.shaded = false
		dot.no_depth_test = true
		dot.layers = 2
		dot.visible = false
		add_child(dot)
		_dots.append(dot)


func is_aiming() -> bool:
	return _player.mode == Player.Mode.WALK and Input.is_action_pressed("aim")


## Punto de salida y velocidad inicial del lanzamiento según la cámara.
func throw_origin() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	return _player.global_position + Vector3.UP * 1.4 + right * 0.35


func throw_velocity() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var forward := -camera.global_basis.z if camera != null else Vector3.FORWARD
	return forward * THROW_SPEED + Vector3.UP * THROW_LIFT


## Lanza una Pokéball si quedan. Devuelve la ball o null.
func throw_ball() -> PokeballProjectile:
	if GameState.pokeballs <= 0:
		return null
	GameState.pokeballs -= 1
	var ball := PokeballProjectile.create()
	ball.thrower = _player
	_player.get_parent().add_child(ball)
	ball.global_position = throw_origin()
	ball.linear_velocity = throw_velocity()
	return ball


func _process(_delta: float) -> void:
	if _rig == null:
		_rig = get_tree().get_first_node_in_group(CameraRig.CAMERA_GROUP) as CameraRig
		_world = get_tree().get_first_node_in_group(WorldBuilder.WORLD_GROUP) as WorldBuilder
	var aiming := is_aiming()
	if _rig != null:
		_rig.aiming = aiming
	if aiming and Input.is_action_just_pressed("throw"):
		throw_ball()
	_update_arc(aiming)


## Arco de la trayectoria con la misma gravedad que la física.
func _update_arc(visible_arc: bool) -> void:
	if not visible_arc:
		for dot in _dots:
			dot.visible = false
		return
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var origin := throw_origin()
	var velocity := throw_velocity()
	var hidden := false
	for i in ARC_POINTS:
		var t := (i + 1) * ARC_STEP
		var point := origin + velocity * t + Vector3.DOWN * 0.5 * gravity * t * t
		if _world != null and point.y < _world.surface_height_at(point.x, point.z):
			hidden = true
		_dots[i].visible = not hidden
		_dots[i].global_position = point


func _dot_texture() -> Texture2D:
	var image := Image.create_empty(3, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0.9))
	image.set_pixel(0, 0, Color(0, 0, 0, 0))
	image.set_pixel(2, 0, Color(0, 0, 0, 0))
	image.set_pixel(0, 2, Color(0, 0, 0, 0))
	image.set_pixel(2, 2, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)
