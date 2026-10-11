class_name HealAnimationUI
extends Control
## Curación clásica animada del Centro Pokémon (pedido de Fernando, 2026-10-10 noche):
## entregas tu equipo y sus Balls se encienden una a una con el jingle, durante unos 3
## segundos en total, antes de devolvértelas curadas. No pausa el juego (es solo una
## animación corta junto al mostrador).

signal finished

var ball_count := 1
## Duración total de la animación (se reparte entre las Balls que se enciendan).
var total_seconds := 3.0
var _icons: Array[TextureRect] = []


func play() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := MenuStyle.panel_container(Color(0.9, 0.4, 0.45))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position.y = -220
	panel.custom_minimum_size = Vector2(380, 130)
	panel.position.x = -panel.custom_minimum_size.x * 0.5
	add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(MenuStyle.label("Curando a tu equipo...", 20, MenuStyle.ACCENT))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var count := clampi(ball_count, 1, 6)
	for i in count:
		var icon := MenuStyle.texture_rect(Items.icon("poke-ball"), Vector2(32, 32))
		icon.modulate = Color(1, 1, 1, 0.25)
		row.add_child(icon)
		_icons.append(icon)
	_light_next(0)


func _light_next(index: int) -> void:
	if index >= _icons.size():
		await get_tree().create_timer(0.3).timeout
		AudioBus.play_jingle("bw1_heal")
		finished.emit()
		queue_free()
		return
	_icons[index].modulate = Color(1, 1, 1, 1)
	AudioBus.play_sfx("ui_select", 1.4)
	await get_tree().create_timer(total_seconds / maxf(_icons.size(), 1)).timeout
	_light_next(index + 1)
