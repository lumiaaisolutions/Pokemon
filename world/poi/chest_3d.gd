class_name Chest3D
extends RefCounted
## Cofre 3D propio estilo BW2 (decisión de Fernando, 2026-10-10): madera de pocas caras
## con textura pixel y herrajes; se abre con animación y brillo. Tres variantes: común
## (madera), raro (plata) y legendario (oro). Ver world/poi/points_of_interest.gd.

const BODY_SIZE := Vector3(0.9, 0.55, 0.55)
const LID_SIZE := Vector3(0.94, 0.3, 0.58)

const TIERS := {
	"common": {"wood": Color(0.52, 0.36, 0.22), "trim": Color(0.3, 0.28, 0.26), "glow": Color(0.9, 0.75, 0.4)},
	"rare": {"wood": Color(0.42, 0.44, 0.48), "trim": Color(0.82, 0.84, 0.88), "glow": Color(0.75, 0.85, 1.0)},
	"legendary": {"wood": Color(0.4, 0.3, 0.15), "trim": Color(1.0, 0.82, 0.2), "glow": Color(1.0, 0.85, 0.3)},
}


## Elige el nivel del cofre, fijo por su id (la mayoría común, algunos raros, pocos
## legendarios).
static func tier_for(id: String) -> String:
	var roll := absi(hash(id)) % 100
	if roll < 6:
		return "legendary"
	if roll < 26:
		return "rare"
	return "common"


## Arma el cofre cerrado en parent. Devuelve {"node", "lid", "glow", "tier"}.
static func build(parent: Node3D, at: Vector3, tier: String) -> Dictionary:
	var colors: Dictionary = TIERS.get(tier, TIERS["common"])
	var node := Node3D.new()
	node.name = "Chest"
	node.position = at
	parent.add_child(node)
	var wood := PropModels3D.solid_material(colors["wood"])
	var trim := StandardMaterial3D.new()
	trim.albedo_color = colors["trim"]
	trim.metallic = 0.6
	trim.roughness = 0.35
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := BoxMesh.new()
	body_mesh.size = BODY_SIZE
	body.mesh = body_mesh
	body.material_override = wood
	body.position.y = BODY_SIZE.y * 0.5
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.add_child(body)
	# Herrajes: franjas metálicas al frente y en las esquinas.
	for x in [-BODY_SIZE.x * 0.5 + 0.05, 0.0, BODY_SIZE.x * 0.5 - 0.05]:
		var band := MeshInstance3D.new()
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(0.06, BODY_SIZE.y + 0.04, BODY_SIZE.z + 0.02)
		band.mesh = band_mesh
		band.material_override = trim
		band.position = Vector3(x, BODY_SIZE.y * 0.5, 0.0)
		node.add_child(band)
	var lock := MeshInstance3D.new()
	var lock_mesh := BoxMesh.new()
	lock_mesh.size = Vector3(0.14, 0.14, 0.08)
	lock.mesh = lock_mesh
	lock.material_override = trim
	lock.position = Vector3(0.0, BODY_SIZE.y - 0.05, BODY_SIZE.z * 0.5 + 0.02)
	node.add_child(lock)
	# Tapa, con bisagra en el borde trasero (gira hacia atrás al abrir).
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(0.0, BODY_SIZE.y, -LID_SIZE.z * 0.5)
	node.add_child(hinge)
	var lid := MeshInstance3D.new()
	lid.name = "Lid"
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = LID_SIZE
	lid.mesh = lid_mesh
	lid.material_override = wood
	lid.position = Vector3(0.0, LID_SIZE.y * 0.5, LID_SIZE.z * 0.5)
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hinge.add_child(lid)
	# Brillo (apagado hasta abrirse).
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = colors["glow"]
	glow.light_energy = 0.0
	glow.omni_range = 2.5
	glow.position = Vector3(0.0, BODY_SIZE.y + 0.2, 0.0)
	node.add_child(glow)
	return {"node": node, "hinge": hinge, "glow": glow, "tier": tier}


## Abre el cofre: la tapa gira hacia atrás, un destello breve y chispas doradas.
static func open(chest: Dictionary) -> void:
	var hinge := chest["hinge"] as Node3D
	var glow := chest["glow"] as OmniLight3D
	var tween := hinge.create_tween()
	tween.tween_property(hinge, "rotation:x", -deg_to_rad(100.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var light_tween := glow.create_tween()
	light_tween.tween_property(glow, "light_energy", 2.2, 0.15)
	light_tween.tween_property(glow, "light_energy", 0.6, 0.6)
	var sparkle := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(1.0, 0.92, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = material
	sparkle.mesh = quad
	sparkle.amount = 12
	sparkle.lifetime = 0.9
	sparkle.one_shot = true
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkle.emission_sphere_radius = 0.25
	sparkle.gravity = Vector3(0, 0.6, 0)
	sparkle.initial_velocity_max = 1.0
	sparkle.position = Vector3(0.0, BODY_SIZE.y + 0.1, 0.0)
	(chest["node"] as Node3D).add_child(sparkle)
	sparkle.emitting = true
	var cleanup := sparkle.create_tween()
	cleanup.tween_interval(sparkle.lifetime + 0.1)
	cleanup.tween_callback(sparkle.queue_free)
