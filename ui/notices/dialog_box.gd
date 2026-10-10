class_name DialogBox
extends Control
## Caja de diálogo estilo BW2 con el estilo claro del juego (acordado con Fernando el
## 2026-10-10): abajo al centro, retrato y nombre del que habla en una etiqueta roja,
## el texto aparece letra por letra y E (o A) avanza. Al final puede mostrar opciones
## (Retar, Comprar, Adiós…) como píldoras. Mientras está abierta y "bloquea", el jugador
## no se mueve. Los avisos con forma "Nombre: texto" se muestran aquí sin bloquear.

signal closed
signal chosen(index: int)

## Hay un diálogo que bloquea el movimiento (lo lee Player).
static var blocking := false

const CHARS_PER_SECOND := 55.0

var _panel: PanelContainer
var _name_tag: PanelContainer
var _name_label: Label
var _portrait_holder: Control
var _text: Label
var _arrow: Label
var _options_row: HBoxContainer
var _lines: Array[String] = []
var _index := 0
var _options: Array = []
var _on_choice: Callable
var _shown := 0.0
var _auto_close := 0.0
var _blocking := false
var _time := 0.0


func _ready() -> void:
	add_to_group(&"dialog_box")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	# Entre la tarjeta del compañero (izquierda) y la leyenda (derecha), sobre los corazones.
	offset_left = -500
	offset_right = 500
	offset_top = -380
	offset_bottom = -150
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", -6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	# Opciones arriba a la derecha y etiqueta del nombre arriba a la izquierda.
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	_name_tag = PanelContainer.new()
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = UiKit.RED
	tag_style.set_corner_radius_all(14)
	tag_style.content_margin_left = 22
	tag_style.content_margin_right = 22
	tag_style.content_margin_top = 4
	tag_style.content_margin_bottom = 8
	_name_tag.add_theme_stylebox_override("panel", tag_style)
	_name_label = UiKit.label("", 22, Color.WHITE, true)
	_name_tag.add_child(_name_label)
	var tag_margin := MarginContainer.new()
	tag_margin.add_theme_constant_override("margin_left", 150)
	tag_margin.add_child(_name_tag)
	top.add_child(tag_margin)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_options_row = HBoxContainer.new()
	_options_row.add_theme_constant_override("separation", 10)
	top.add_child(_options_row)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.light_style(UiKit.RED, 22, 4))
	_panel.custom_minimum_size = Vector2(0, 150)
	column.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_panel.add_child(row)
	_portrait_holder = PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = UiKit.PAPER
	frame.set_corner_radius_all(16)
	frame.set_content_margin_all(6)
	_portrait_holder.add_theme_stylebox_override("panel", frame)
	_portrait_holder.custom_minimum_size = Vector2(118, 118)
	_portrait_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait_holder)
	_text = UiKit.label("", 25, UiKit.TEXT, true)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_text)
	_arrow = UiKit.label("▼", 22, UiKit.RED, true)
	_arrow.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_arrow)
	visible = false


func is_open() -> bool:
	return visible


## Abre un diálogo. lines: frases que se avanzan con E. options: textos de las opciones
## al final (on_choice recibe el índice). blocking: el jugador no se mueve mientras tanto.
func open(speaker: String, lines: Array, portrait: Texture2D = null, options: Array = [], on_choice: Callable = Callable(), blocking_dialog: bool = true) -> void:
	_lines.clear()
	for line in lines:
		_lines.append(String(line))
	_index = 0
	_options = options
	_on_choice = on_choice
	_blocking = blocking_dialog
	blocking = blocking_dialog
	_auto_close = 0.0 if blocking_dialog else GameOptions.notice_seconds(" ".join(_lines)) + 1.0
	_name_label.text = speaker
	_name_tag.visible = speaker != ""
	for child in _portrait_holder.get_children():
		child.queue_free()
	_portrait_holder.visible = portrait != null
	if portrait != null:
		var image := UiKit.icon_rect(portrait, Vector2(106, 106))
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_portrait_holder.add_child(image)
	_show_line()
	visible = true
	AudioBus.play_sfx("ui_message")


## Aviso con forma "Nombre: texto": se muestra sin bloquear y se cierra solo.
func say(speaker: String, text: String) -> void:
	if visible and _blocking:
		return
	# Retratos de personajes conocidos (el profesor, el rival).
	var portrait: Texture2D = null
	if speaker.begins_with("Prof."):
		portrait = Professor.portrait()
	elif speaker == GameState.rival and ResourceLoader.exists("res://art/portraits/hugh.png"):
		portrait = load("res://art/portraits/hugh.png")
	open(speaker, [text], portrait, [], Callable(), false)


func _show_line() -> void:
	_text.text = _lines[_index] if _index < _lines.size() else ""
	_text.visible_characters = 0
	_shown = 0.0
	_clear_options()


func _clear_options() -> void:
	for child in _options_row.get_children():
		child.queue_free()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _text.visible_characters >= 0 and _text.visible_characters < _text.text.length():
		_shown += delta * CHARS_PER_SECOND
		_text.visible_characters = int(_shown)
		if _text.visible_characters >= _text.text.length():
			_text.visible_characters = -1
			_line_done()
	_arrow.visible = _text.visible_characters == -1 and (_index < _lines.size() - 1 or _options.is_empty())
	_arrow.position.y = sin(_time * 6.0) * 3.0
	if _auto_close > 0.0:
		_auto_close -= delta
		if _auto_close <= 0.0:
			close()


func _line_done() -> void:
	if _index == _lines.size() - 1 and not _options.is_empty() and _options_row.get_child_count() == 0:
		for i in _options.size():
			var pill := _option_button(String(_options[i]), i)
			_options_row.add_child(pill)
		(_options_row.get_child(0) as Button).grab_focus.call_deferred()


func _option_button(text: String, index: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", UiKit.font(true))
	button.add_theme_font_size_override("font_size", 21)
	var normal := StyleBoxFlat.new()
	normal.bg_color = UiKit.CREAM
	normal.border_color = UiKit.RED
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(22)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = UiKit.RED
	focus.border_color = Color(1.0, 0.85, 0.3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", focus)
	button.add_theme_color_override("font_color", UiKit.RED_DARK)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.focus_entered.connect(func() -> void: AudioBus.play_sfx("ui_select"))
	button.mouse_entered.connect(button.grab_focus)
	button.pressed.connect(_choose.bind(index))
	return button


func _choose(index: int) -> void:
	AudioBus.play_sfx("ui_decide")
	var callback := _on_choice
	close()
	chosen.emit(index)
	if callback.is_valid():
		callback.call(index)


func _input(event: InputEvent) -> void:
	if not visible or not _blocking:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") and _options_row.get_child_count() == 0:
		get_viewport().set_input_as_handled()
		advance()
	elif event.is_action_pressed("ui_cancel") and _options.is_empty():
		get_viewport().set_input_as_handled()
		close()


## Completa la línea o pasa a la siguiente (o cierra al final).
func advance() -> void:
	if _text.visible_characters != -1:
		_text.visible_characters = -1
		_line_done()
		return
	if _index < _lines.size() - 1:
		_index += 1
		_show_line()
		AudioBus.play_sfx("ui_select")
		return
	if _options.is_empty():
		close()
	elif _options_row.get_child_count() > 0:
		# E sobre la opción con el foco la elige.
		for i in _options_row.get_child_count():
			if (_options_row.get_child(i) as Button).has_focus():
				_choose(i)
				return


func close() -> void:
	if not visible:
		return
	visible = false
	if _blocking:
		blocking = false
	_blocking = false
	_clear_options()
	closed.emit()
