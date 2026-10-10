class_name HealthBar3D
extends Node3D
## Barra de vida flotante (billboard) sobre un actor: verde, amarilla o roja según
## lo que le queda, como en los juegos de Pokémon. Solo se ve si no está llena.

const WIDTH := 1.1
const HEIGHT := 0.14

var _fill: MeshInstance3D
var _fill_material: StandardMaterial3D


static func create(height: float) -> HealthBar3D:
	var bar := HealthBar3D.new()
	bar.name = "HealthBar"
	bar.position.y = height
	bar._build()
	bar.visible = false
	return bar


func _build() -> void:
	var background := MeshInstance3D.new()
	background.mesh = _quad(Vector2(WIDTH + 0.08, HEIGHT + 0.08), Color(0.08, 0.08, 0.1))
	add_child(background)
	_fill_material = _material(Color(0.3, 0.85, 0.35))
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	quad.material = _fill_material
	_fill = MeshInstance3D.new()
	_fill.mesh = quad
	_fill.position.z = 0.01
	add_child(_fill)


## Muy cerca de la cámara la barra taparía la vista: se oculta.
const HIDE_NEAR_CAMERA := 4.5

var _ratio := 1.0


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var near := camera != null and camera.global_position.distance_to(global_position) < HIDE_NEAR_CAMERA
	visible = _ratio < 0.999 and not near


## ratio en [0, 1]. La barra se encoge hacia la izquierda.
func set_ratio(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	_ratio = ratio
	visible = ratio < 0.999
	_fill.scale.x = maxf(ratio, 0.001)
	_fill.position.x = -WIDTH * (1.0 - ratio) * 0.5
	_fill_material.albedo_color = Color(0.3, 0.85, 0.35) if ratio > 0.5 else (Color(0.95, 0.8, 0.2) if ratio > 0.2 else Color(0.9, 0.25, 0.2))


func _quad(size: Vector2, color: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = _material(color)
	return quad


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.render_priority = 1
	return material
