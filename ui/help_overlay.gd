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
		["throw", "", "Lanzar Pokéball (en combate: mantén para cargar potencia)"],
		["dodge", "", "En combate, apuntando: Nate esquiva"],
		["photo", "", "Sacar una foto (cuenta para la investigación)"],
	]],
	["Combate en arena", [
		["lock_on", "", "Fijar objetivo"],
		["mega_evolve", "", "Megaevolucionar (Piedra Llave y megapiedra)"],
		["companion", "", "Mantener: cambiar de Pokémon (2 s de espera)"],
		["bag", "", "Mochila (pausa el combate)"],
	]],
	["Tu Pokémon", [
		["companion", "", "Tocar: guardarlo o sacarlo · Mantener: rueda para cambiar"],
		["@1 2 3 4", "@R1 + □ △ ○ ✕", "Usar sus 4 movimientos (ordenar o, desmayado, controlarlo)"],
		["run", "", "Mantener al usar un movimiento: estilo Fuerte"],
		["dive", "", "Mantener al usar un movimiento: estilo Ágil"],
		["dodge", "", "Desmayado: esquivar"],
	]],
	["Agua", [
		["jump", "", "Mantener: flotar o subir"],
		["dive", "", "Bucear más rápido"],
	]],
	["Sistema", [
		["menu", "", "Abrir o cerrar el menú (equipo, mochila, Pokédex…)"],
		["bag", "", "Abrir la Mochila"],
		["missions", "", "Tablero de misiones (mando: mantener cruceta ↓)"],
		["menu_prev", "", "Menú: pestaña anterior"],
		["menu_next", "", "Menú: pestaña siguiente"],
		["ball_next", "", "Siguiente Pokéball"],
		["ball_prev", "", "Pokéball anterior"],
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


## Toque corto de "help" (despliega u oculta la leyenda de botones del HUD).
signal tapped

## Mantener "help" más que esto abre la ayuda completa; un toque más corto es "tapped".
const HOLD_TIME := 0.4
var _held := -1.0


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("help") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		toggle()
	elif not visible and event.is_action_pressed("help"):
		get_viewport().set_input_as_handled()
		_held = 0.0
	elif not visible and event.is_action_released("help") and _held >= 0.0:
		get_viewport().set_input_as_handled()
		_held = -1.0
		tapped.emit()


func _process(delta: float) -> void:
	if _held < 0.0 or visible:
		return
	_held += delta
	if _held >= HOLD_TIME:
		_held = -1.0
		toggle()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_build()


func _build() -> void:
	for child in get_children().slice(1):
		child.queue_free()
	var content := build_content()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 120
	content.offset_right = -120
	content.offset_top = 60
	content.offset_bottom = -40
	add_child(content)


## Lista de todos los controles (también la usa la pestaña Controles del menú).
static func build_content() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 700)
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
	return scroll


static func _glyph(action: String, pad: int) -> Control:
	if action.begins_with("@"):
		return InputGlyph.text(action.substr(1), pad == 0)
	return InputGlyph.make(action, pad)


static func _column(control: Control, width: float) -> Control:
	var box := HBoxContainer.new()
	box.custom_minimum_size.x = width
	box.add_child(control)
	return box


static func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label
