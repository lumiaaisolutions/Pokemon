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
	_beam = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07, 0.07, 1.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = BEAM_COLOR
	material.emission_enabled = true
	material.emission = BEAM_COLOR
	material.emission_energy_multiplier = 2.0
	mesh.material = material
	_beam.mesh = mesh
	_beam.layers = 2
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)


## Rayo de from a to (posiciones del mundo); vacío lo oculta.
func set_beam(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	_beam.visible = length > 0.05
	if not _beam.visible:
		return
	_beam.global_position = (from + to) * 0.5
	var up := Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	_beam.look_at(to, up)
	_beam.scale = Vector3(1.0, 1.0, length)


func hide_beam() -> void:
	_beam.visible = false
