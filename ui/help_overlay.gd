class_name HelpOverlay
extends Control
## Pantalla de Ayuda (H / Touchpad): todos los controles a la vez, con el ícono del
## teclado de Mac y el del control de PlayStation lado a lado. Pausa el juego.

## [acción o ícono libre de teclado, ícono libre de mando, texto]. Si la acción es del
## Input Map, sus íconos salen de él.
const SECTIONS := [
	["Explorar", [
		["@WASD", "@Stick izq.", "Caminar"],
		["@Mouse / flechas", "@Stick der.", "Mover la cámara"],
		["run", "", "Correr (gasta stamina)"],
		["jump", "", "Saltar"],
		["zoom_in", "", "Acercar la cámara"],
		["map", "", "Mapa completo"],
	]],
	["Captura", [
		["aim", "", "Apuntar (toca para fijar, mantén para sostener)"],
		["throw", "", "Lanzar Pokéball"],
	]],
	["Tu Pokémon", [
		["companion", "", "Guardarlo o sacarlo de su Pokéball"],
		["attack_1", "", "Desmayado: golpe físico"],
		["attack_2", "", "Desmayado: ataque especial"],
		["dodge", "", "Desmayado: esquivar"],
	]],
	["Agua", [
		["jump", "", "Mantener: flotar o subir"],
		["dive", "", "Bucear más rápido"],
	]],
	["Sistema", [
		["menu", "", "Liberar el mouse (el menú llegará pronto)"],
		["help", "", "Abrir o cerrar esta ayuda"],
	]],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.1, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help") or (visible and event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		toggle()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_build()


func _build() -> void:
	for child in get_children().slice(1):
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 120
	scroll.offset_right = -120
	scroll.offset_top = 60
	scroll.offset_bottom = -40
	add_child(scroll)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	scroll.add_child(layout)
	layout.add_child(_label("Controles", 44, Color(1.0, 0.9, 0.5)))
	var header := HBoxContainer.new()
	header.add_child(_column(_label("Teclado y mouse (Mac)", 22, Color(0.8, 0.85, 1.0)), 300))
	header.add_child(_column(_label("Control de PlayStation", 22, Color(0.8, 0.85, 1.0)), 300))
	layout.add_child(header)
	for section: Array in SECTIONS:
		layout.add_child(_label(section[0], 28, Color(1.0, 0.85, 0.4)))
		for entry: Array in section[1]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)
			row.add_child(_column(_glyph(entry[0], 0), 300))
			row.add_child(_column(_glyph(entry[1] if entry[1] != "" else entry[0], 1), 300))
			row.add_child(_label(entry[2], 22, Color.WHITE))
			layout.add_child(row)
	layout.add_child(_label("Cierra con %s o %s" % [InputHints.hint("help", 0), InputHints.hint("help", 1)], 18, Color(0.75, 0.8, 0.9)))


func _glyph(action: String, pad: int) -> Control:
	if action.begins_with("@"):
		return InputGlyph.text(action.substr(1), pad == 0)
	return InputGlyph.make(action, pad)


func _column(control: Control, width: float) -> Control:
	var box := HBoxContainer.new()
	box.custom_minimum_size.x = width
	box.add_child(control)
	return box


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label
