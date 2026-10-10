class_name MegaEffect
extends RefCounted
## Animación de la megaevolución estilo X/Y (~2.6 s): rayo de la Piedra Llave a la
## megapiedra, esfera de luz arcoíris que envuelve al Pokémon y destello blanco.

const DURATION := 2.6


static func play(parent: Node, target: Node3D, trainer: Node3D) -> void:
	var tree := parent.get_tree()
	var center := target.global_position + Vector3.UP * 1.0
	# Rayo del entrenador al Pokémon.
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.06
	cylinder.bottom_radius = 0.06
	beam.mesh = cylinder
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = Color(1.0, 0.9, 1.0)
	beam_material.emission_enabled = true
	beam_material.emission = Color(1.0, 0.6, 1.0)
	beam_material.emission_energy_multiplier = 3.0
	beam.material_override = beam_material
	parent.add_child(beam)
	var from := trainer.global_position + Vector3.UP * 1.2 if trainer != null else center + Vector3(0, 3, 3)
	var length := from.distance_to(center)
	cylinder.height = length
	beam.global_position = (from + center) * 0.5
	# Rayo vertical (el entrenador megaevoluciona a su propio Pokémon): otro eje "arriba".
	beam.look_at(center, Vector3.UP if absf((center - from).normalized().y) < 0.99 else Vector3.FORWARD)
	beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	# Esfera arcoíris.
	var sphere := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	sphere.mesh = sphere_mesh
	var sphere_material := StandardMaterial3D.new()
	sphere_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_material.albedo_color = Color(1.0, 0.7, 1.0, 0.75)
	sphere_material.emission_enabled = true
	sphere_material.emission = Color(1.0, 0.5, 0.9)
	sphere.material_override = sphere_material
	parent.add_child(sphere)
	sphere.global_position = center
	# Destello en pantalla.
	var layer := CanvasLayer.new()
	layer.layer = 40
	parent.add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var symbol := Label.new()
	symbol.text = "✦ MEGAEVOLUCIÓN ✦"
	symbol.add_theme_font_size_override("font_size", 56)
	symbol.add_theme_color_override("font_color", Color(1.0, 0.85, 1.0))
	symbol.add_theme_color_override("font_outline_color", Color(0.35, 0.1, 0.45))
	symbol.add_theme_constant_override("outline_size", 14)
	symbol.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.modulate.a = 0.0
	layer.add_child(symbol)
	var tween := parent.create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(beam.queue_free)
	tween.tween_property(sphere, "scale", Vector3.ONE * 14.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_method(func(h: float) -> void:
		sphere_material.albedo_color = Color.from_hsv(fmod(h, 1.0), 0.45, 1.0, 0.7)
		sphere_material.emission = Color.from_hsv(fmod(h + 0.5, 1.0), 0.6, 1.0), 0.0, 3.0, 1.0)
	tween.tween_property(flash, "color:a", 1.0, 0.25)
	tween.parallel().tween_property(symbol, "modulate:a", 1.0, 0.25)
	tween.tween_callback(sphere.queue_free)
	tween.tween_property(flash, "color:a", 0.0, 0.6)
	tween.parallel().tween_property(symbol, "modulate:a", 0.0, 0.8)
	tween.tween_callback(layer.queue_free)
	await tree.create_timer(DURATION).timeout
