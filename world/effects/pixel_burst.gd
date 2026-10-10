class_name PixelBurst
extends CPUParticles3D
## Nube de cuadritos pixel art de un solo disparo: hojas, polvo, salpicadura, arena o
## humo. La usan los Pokémon al esconderse y al desaparecer debilitados. Se libera sola.

enum Kind { LEAVES, FOREST_LEAVES, DUST, ROCK, SPLASH, SAND, SMOKE, BUBBLES, HEAL }

const PIXEL := 0.057
const COLORS := {
	Kind.LEAVES: [Color(0.45, 0.78, 0.35), Color(0.62, 0.88, 0.45), Color(0.32, 0.6, 0.28)],
	Kind.FOREST_LEAVES: [Color(0.2, 0.45, 0.25), Color(0.3, 0.58, 0.3), Color(0.45, 0.35, 0.2)],
	Kind.DUST: [Color(0.66, 0.52, 0.36), Color(0.78, 0.66, 0.48), Color(0.55, 0.42, 0.3)],
	Kind.ROCK: [Color(0.55, 0.5, 0.46), Color(0.7, 0.66, 0.6), Color(0.42, 0.38, 0.35)],
	Kind.SPLASH: [Color(0.75, 0.9, 1.0), Color(0.45, 0.7, 0.95), Color(1, 1, 1)],
	Kind.SAND: [Color(0.93, 0.85, 0.62), Color(0.85, 0.75, 0.52), Color(1.0, 0.94, 0.78)],
	Kind.SMOKE: [Color(0.85, 0.85, 0.85), Color(0.7, 0.7, 0.7), Color(0.95, 0.95, 0.95)],
	Kind.BUBBLES: [Color(0.85, 0.95, 1.0), Color(0.6, 0.85, 1.0), Color(1, 1, 1)],
	Kind.HEAL: [Color(0.6, 1.0, 0.6), Color(1.0, 0.55, 0.65), Color(1, 1, 1)],
}


## Crea una nube en position (coordenadas del mundo) dentro de parent. size escala la nube.
static func spawn(parent: Node, position: Vector3, kind: Kind, size: float = 1.0) -> PixelBurst:
	var burst := PixelBurst.new()
	burst._setup(kind, size)
	parent.add_child(burst)
	burst.global_position = position
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
	return burst


func _setup(kind: Kind, size: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * PIXEL * 3.0 * clampf(size, 1.0, 2.0)
	quad.material = material
	mesh = quad
	one_shot = true
	amount = int(18 * clampf(size, 1.0, 3.0))
	lifetime = 0.9 if kind != Kind.SMOKE else 1.3
	explosiveness = 0.85
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 0.5 * size
	direction = Vector3.UP
	spread = 70.0
	initial_velocity_min = 1.0 * size
	initial_velocity_max = 2.6 * size
	gravity = Vector3(0, 1.2, 0) if kind == Kind.SMOKE else (Vector3(0, 3.0, 0) if kind in [Kind.BUBBLES, Kind.HEAL] else Vector3(0, -6.0, 0))
	if kind == Kind.HEAL:
		# Destellos de curación: suben despacio.
		lifetime = 1.2
		spread = 25.0
		initial_velocity_min = 0.3 * size
		initial_velocity_max = 0.9 * size
	damping_min = 1.0
	damping_max = 2.5
	var ramp := Gradient.new()
	var colors: Array = COLORS[kind]
	ramp.colors = PackedColorArray([colors[0], colors[1], Color(colors[2], 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	color_ramp = ramp
	color_initial_ramp = null
	layers = 2
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
