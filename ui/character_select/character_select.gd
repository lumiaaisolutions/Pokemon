extends Control
## Pantalla de inicio de partida: chico o chica, uno de 5 personajes (con vista
## previa que camina y gira), nombre y dificultad. Al confirmar guarda la elección en
## GameState y carga el mundo. Funciona con mouse, teclado y mando (foco de botones;
## ui_cancel regresa al paso anterior).

const WORLD_SCENE := "res://world/main.tscn"
const CELL := 32
const PREVIEW_SCALE := 7
const CARD_SCALE := 3
## Orden en que gira la vista previa (filas de la hoja: abajo, izquierda, arriba, derecha).
const TURN_ROWS := [0, 1, 3, 2]
const STEP_CYCLE := [0, 1, 0, 2]

enum Step { GENDER, CHARACTER, NAME, DIFFICULTY, CONFIRM }

var _step: Step = Step.GENDER
var _gender := "male"
var _character: Dictionary = {}
var _difficulty := 1
var _time := 0.0
var _title: Label
var _subtitle: Label
var _content: Control
var _preview: TextureRect
var _preview_atlas: AtlasTexture
var _preview_name: Label
var _card_atlases: Array[AtlasTexture] = []
var _name_edit: LineEdit
var _back_hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.13, 0.2, 0.3)
	add_child(background)
	var stripes := _stripes()
	add_child(stripes)
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 80
	layout.offset_right = -80
	layout.offset_top = 60
	layout.offset_bottom = -50
	layout.add_theme_constant_override("separation", 18)
	add_child(layout)
	_title = _label("", 48, Color(1, 0.95, 0.7))
	layout.add_child(_title)
	_subtitle = _label("", 24, Color(0.85, 0.9, 1.0))
	layout.add_child(_subtitle)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 40)
	layout.add_child(body)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(_content as VBoxContainer).add_theme_constant_override("separation", 16)
	body.add_child(_content)
	var preview_panel := _panel()
	preview_panel.custom_minimum_size = Vector2(CELL * PREVIEW_SCALE + 60, CELL * PREVIEW_SCALE + 110)
	body.add_child(preview_panel)
	var preview_box := VBoxContainer.new()
	preview_box.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_panel.add_child(preview_box)
	_preview_atlas = AtlasTexture.new()
	_preview = TextureRect.new()
	_preview.texture = _preview_atlas
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.custom_minimum_size = Vector2.ONE * CELL * PREVIEW_SCALE
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview_box.add_child(_preview)
	_preview_name = _label("", 30, Color.WHITE)
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_box.add_child(_preview_name)
	_back_hint = _label("", 18, Color(0.75, 0.8, 0.9))
	layout.add_child(_back_hint)
	_select_character(PlayerCharacters.by_gender(_gender)[0])
	_show_step(Step.GENDER)


func _process(delta: float) -> void:
	_time += delta
	# Vista previa: camina en el lugar y gira cada 1.2 s.
	var row: int = TURN_ROWS[int(_time / 1.2) % TURN_ROWS.size()]
	var column: int = STEP_CYCLE[int(_time * 6.0) % STEP_CYCLE.size()]
	_preview_atlas.region = Rect2(column * CELL, row * CELL, CELL, CELL)
	for atlas in _card_atlases:
		atlas.region = Rect2(column * CELL, 0, CELL, CELL)
	_back_hint.text = "%s Regresar" % ("[○]" if InputHints.gamepad else "[Esc]") if _step != Step.GENDER else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _step != Step.GENDER:
		get_viewport().set_input_as_handled()
		_show_step(_step - 1 as Step)


func _show_step(step: Step) -> void:
	_step = step
	for child in _content.get_children():
		child.queue_free()
	_card_atlases.clear()
	match step:
		Step.GENDER:
			_title.text = "¡Bienvenido al mundo Pokémon!"
			_subtitle.text = "¿Eres chico o chica?"
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 24)
			_content.add_child(row)
			for gender in ["male", "female"]:
				var button := _big_button("Chico" if gender == "male" else "Chica", PlayerCharacters.by_gender(gender))
				button.pressed.connect(func() -> void:
					_gender = gender
					_select_character(PlayerCharacters.by_gender(gender)[0])
					_show_step(Step.CHARACTER))
				button.focus_entered.connect(func() -> void: _select_character(PlayerCharacters.by_gender(gender)[0]))
				row.add_child(button)
			_focus_first()
		Step.CHARACTER:
			_title.text = "Elige a tu personaje"
			_subtitle.text = "Todos pueden hacer lo mismo: explorar, nadar, bucear y capturar."
			var grid := HBoxContainer.new()
			grid.add_theme_constant_override("separation", 16)
			_content.add_child(grid)
			for entry in PlayerCharacters.by_gender(_gender):
				var card := _card(entry)
				card.pressed.connect(func() -> void:
					_select_character(entry)
					_show_step(Step.NAME))
				card.focus_entered.connect(func() -> void: _select_character(entry))
				card.mouse_entered.connect(func() -> void: _select_character(entry))
				grid.add_child(card)
			_focus_first()
		Step.NAME:
			_title.text = "¿Cómo te llamas?"
			_subtitle.text = "Tu nombre aparecerá en el juego (máximo 12 letras)."
			_name_edit = LineEdit.new()
			_name_edit.text = _character["name"]
			_name_edit.max_length = 12
			_name_edit.custom_minimum_size = Vector2(520, 64)
			_name_edit.add_theme_font_size_override("font_size", 34)
			_name_edit.text_submitted.connect(func(_text: String) -> void: _confirm_name())
			_content.add_child(_name_edit)
			var next := _button("Continuar")
			next.pressed.connect(_confirm_name)
			_content.add_child(next)
			_name_edit.grab_focus.call_deferred()
			_name_edit.select_all.call_deferred()
		Step.DIFFICULTY:
			_title.text = "Elige la dificultad"
			_subtitle.text = "Cambia el daño de los salvajes, el dinero que pierdes al desmayarte y lo que tardas en recuperarte."
			for i in GameState.DIFFICULTIES.size():
				var data: Dictionary = GameState.DIFFICULTIES[i]
				var button := _button("%s — %s" % [data["name"], data["description"]])
				button.pressed.connect(func() -> void:
					_difficulty = i
					_show_step(Step.CONFIRM))
				_content.add_child(button)
			(_content.get_child(_difficulty) as Button).grab_focus.call_deferred()
		Step.CONFIRM:
			_title.text = "¿Todo listo?"
			_subtitle.text = ""
			var summary := _label("%s (%s, de %s)\nDificultad: %s" % [_player_name(), _character["name"], _character["region"], GameState.DIFFICULTIES[_difficulty]["name"]], 30, Color.WHITE)
			_content.add_child(summary)
			var start := _button("¡Comenzar la aventura!")
			start.pressed.connect(_start)
			_content.add_child(start)
			var change := _button("Cambiar algo")
			change.pressed.connect(func() -> void: _show_step(Step.GENDER))
			_content.add_child(change)
			start.grab_focus.call_deferred()


func _confirm_name() -> void:
	if _name_edit.text.strip_edges() == "":
		_name_edit.text = _character["name"]
	_show_step(Step.DIFFICULTY)


func _player_name() -> String:
	var typed := _name_edit.text.strip_edges() if _name_edit != null and is_instance_valid(_name_edit) else ""
	return typed if typed != "" else String(_character["name"])


## Guarda la elección y carga el mundo.
func _start() -> void:
	GameState.character_id = _character["id"]
	GameState.gender = _gender
	GameState.player_name = _player_name()
	GameState.difficulty = _difficulty
	get_tree().change_scene_to_file(WORLD_SCENE)


func _select_character(entry: Dictionary) -> void:
	_character = entry
	_preview_atlas.atlas = PlayerCharacters.sheet(entry["id"])
	_preview_name.text = "%s\n%s" % [entry["name"], entry["region"]]


func _focus_first() -> void:
	var first := _find_button(_content)
	if first != null:
		first.grab_focus.call_deferred()


func _find_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child
		var nested := _find_button(child)
		if nested != null:
			return nested
	return null


# --- Elementos visuales ---------------------------------------------------------------

func _card(entry: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(170, 210)
	_style_button(button)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var atlas := AtlasTexture.new()
	atlas.atlas = PlayerCharacters.sheet(entry["id"])
	atlas.region = Rect2(0, 0, CELL, CELL)
	_card_atlases.append(atlas)
	var icon := TextureRect.new()
	icon.texture = atlas
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2.ONE * CELL * CARD_SCALE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var name := _label("%s\n%s" % [entry["name"], entry["region"]], 22, Color.WHITE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name)
	return button


func _big_button(text: String, entries: Array[Dictionary]) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(460, 260)
	_style_button(button)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	for entry in entries:
		var atlas := AtlasTexture.new()
		atlas.atlas = PlayerCharacters.sheet(entry["id"])
		atlas.region = Rect2(0, 0, CELL, CELL)
		_card_atlases.append(atlas)
		var icon := TextureRect.new()
		icon.texture = atlas
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2.ONE * CELL * 2.6
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var label := _label(text, 40, Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return button


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 26)
	_style_button(button)
	return button


## Botón con borde pixel estilo B2W2: se ilumina al tener el foco o el mouse encima.
func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.13, 0.18, 0.92)
	normal.set_border_width_all(4)
	normal.border_color = Color(0.85, 0.88, 0.95)
	normal.set_content_margin_all(14)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.32, 0.5, 0.95)
	hover.border_color = Color(1.0, 0.85, 0.3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.9)
	style.set_border_width_all(4)
	style.border_color = Color(1.0, 0.85, 0.3)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Franjas diagonales suaves de fondo (como las pantallas de menú de B2W2).
func _stripes() -> TextureRect:
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			if (x + y) % 32 < 12:
				image.set_pixel(x, y, Color(1, 1, 1, 0.05))
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(image)
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
