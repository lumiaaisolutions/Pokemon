extends Control
## Pantalla de inicio de partida: chico o chica, uno de 5 personajes (con vista
## previa que camina y gira), nombre y dificultad. Al confirmar guarda la elección en
## GameState y carga el mundo. Funciona con mouse, teclado y mando (foco de botones;
## ui_cancel regresa al paso anterior).

const WORLD_SCENE := "res://world/main.tscn"
const CELL := 32
const PREVIEW_SCALE := 7
const CARD_SCALE := 4
## Orden en que gira la vista previa (filas de la hoja: abajo, izquierda, arriba, derecha).
const TURN_ROWS := [0, 1, 3, 2]
const STEP_CYCLE := [0, 1, 0, 2]

enum Step { TITLE, CONTINUE, OPTIONS, GENDER, CHARACTER, NAME, DIFFICULTY, CONFIRM }

var _step: Step = Step.TITLE
var _gender := "male"
var _character: Dictionary = {}
var _difficulty := 1
var _time := 0.0
var _title_row: HBoxContainer
var _progress: HBoxContainer
var _subtitle: Label
var _content: Control
var _content_panel: PanelContainer
var _preview_panel: PanelContainer
var _preview_region: Label
var _footer: HBoxContainer
var _floaters: Array[Control] = []
var _preview: TextureRect
var _preview_atlas: AtlasTexture
var _preview_name: Label
var _card_atlases: Array[AtlasTexture] = []
var _name_edit: LineEdit
var _seed_edit: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	add_child(UiKit.backdrop(1.0))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	add_child(UiKit.centered_margin(layout, 0.07, 0.06))
	# Encabezado: título del paso y avance (1 a 5).
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	layout.add_child(header)
	_title_row = HBoxContainer.new()
	_title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_row)
	_progress = HBoxContainer.new()
	_progress.add_theme_constant_override("separation", 8)
	_progress.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(_progress)
	_subtitle = UiKit.wrapped("", 24, UiKit.MUTED)
	layout.add_child(_subtitle)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 36)
	layout.add_child(body)
	_content_panel = UiKit.panel()
	_content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_content_panel)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	(_content as VBoxContainer).add_theme_constant_override("separation", 16)
	_content_panel.add_child(_content)
	# Vista previa del personaje en tarjeta blanca.
	_preview_panel = PanelContainer.new()
	_preview_panel.add_theme_stylebox_override("panel", UiKit.card_style(18))
	_preview_panel.custom_minimum_size = Vector2(CELL * PREVIEW_SCALE + 80, 0)
	body.add_child(_preview_panel)
	var preview_box := VBoxContainer.new()
	preview_box.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_box.add_theme_constant_override("separation", 10)
	_preview_panel.add_child(preview_box)
	preview_box.add_child(UiKit.header_chip("Tu personaje", UiIcons.section("Ficha")))
	_preview_atlas = AtlasTexture.new()
	_preview = TextureRect.new()
	_preview.texture = _preview_atlas
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.custom_minimum_size = Vector2.ONE * CELL * PREVIEW_SCALE
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview_box.add_child(_preview)
	_preview_name = UiKit.label("", 30, UiKit.INK, true)
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_box.add_child(_preview_name)
	_preview_region = UiKit.label("", 20, Color(0.3, 0.36, 0.5))
	_preview_region.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_box.add_child(_preview_region)
	# Pie con ayudas.
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 28)
	_footer.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(_footer)
	_select_character(PlayerCharacters.by_gender(_gender)[0])
	_show_step(Step.TITLE)
	AudioBus.play_music("bw2_title")


func _process(delta: float) -> void:
	_time += delta
	# Vista previa: camina en el lugar y gira cada 1.2 s.
	var row: int = TURN_ROWS[int(_time / 1.2) % TURN_ROWS.size()]
	var column: int = STEP_CYCLE[int(_time * 6.0) % STEP_CYCLE.size()]
	_preview_atlas.region = Rect2(column * CELL, row * CELL, CELL, CELL)
	for atlas in _card_atlases:
		atlas.region = Rect2(column * CELL, 0, CELL, CELL)
	# Los Pokémon del título flotan.
	for i in _floaters.size():
		var floater: Control = _floaters[i]
		if is_instance_valid(floater):
			floater.position.y = sin(_time * 1.6 + i * 1.3) * 8.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _step != Step.TITLE:
		get_viewport().set_input_as_handled()
		AudioBus.play_sfx("ui_cancel")
		if _step in [Step.CONTINUE, Step.OPTIONS, Step.GENDER]:
			if _step == Step.OPTIONS:
				GameOptions.save_options()
			_show_step(Step.TITLE)
		else:
			_show_step(_step - 1 as Step)


func _set_title(text: String, icon: Texture2D) -> void:
	for child in _title_row.get_children():
		child.queue_free()
	_title_row.add_child(UiKit.title(text, icon, 40))


## Avance: chips 1–5 con el paso actual resaltado (solo al crear la partida).
func _set_progress(step: Step) -> void:
	for child in _progress.get_children():
		child.queue_free()
	if step < Step.GENDER:
		return
	var names := ["Chico o chica", "Personaje", "Nombre", "Dificultad", "Listo"]
	for i in names.size():
		var current := i == step - Step.GENDER
		var chip := PanelContainer.new()
		var style := UiKit.card_style(16) if current else UiKit.panel_style(false, 16)
		style.set_content_margin_all(8)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.shadow_size = 0
		chip.add_theme_stylebox_override("panel", style)
		var done := i < step - Step.GENDER
		chip.add_child(UiKit.label(("✓ " if done else "%d  " % (i + 1)) + (names[i] if current else ""), 18, UiKit.INK if current else (UiKit.MINT if done else UiKit.MUTED), true))
		_progress.add_child(chip)


func _set_footer(back: bool) -> void:
	for child in _footer.get_children():
		child.queue_free()
	_footer.add_child(UiKit.hint("ui_accept", "Elegir"))
	if back:
		_footer.add_child(UiKit.hint("ui_cancel", "Regresar"))


func _show_step(step: Step) -> void:
	_step = step
	for child in _content.get_children():
		child.queue_free()
	_card_atlases.clear()
	_floaters.clear()
	_set_progress(step)
	_set_footer(step != Step.TITLE)
	_preview_panel.visible = step >= Step.GENDER
	_content.alignment = BoxContainer.ALIGNMENT_CENTER if step in [Step.TITLE, Step.GENDER, Step.CHARACTER] else BoxContainer.ALIGNMENT_BEGIN
	match step:
		Step.TITLE:
			_set_title("Pokémon", Items.icon("poke-ball"))
			_subtitle.text = "Mundo abierto · Una región nueva te espera"
			_content.add_child(_title_showcase())
			var column := VBoxContainer.new()
			column.add_theme_constant_override("separation", 14)
			var center := CenterContainer.new()
			center.add_child(column)
			_content.add_child(center)
			if _has_saves():
				var cont := UiKit.big_button("Continuar", UiIcons.section("Continuar"))
				cont.pressed.connect(func() -> void: _show_step(Step.CONTINUE))
				column.add_child(cont)
			var fresh := UiKit.big_button("Nueva partida", UiIcons.section("Nueva partida"))
			fresh.pressed.connect(func() -> void: _show_step(Step.GENDER))
			column.add_child(fresh)
			var options := UiKit.big_button("Opciones", UiIcons.section("Opciones"))
			options.pressed.connect(func() -> void: _show_step(Step.OPTIONS))
			column.add_child(options)
			var quit := UiKit.big_button("Salir", UiIcons.section("Salir"))
			quit.pressed.connect(func() -> void: get_tree().quit())
			column.add_child(quit)
			_focus_first()
		Step.CONTINUE:
			_set_title("Continuar", UiIcons.section("Continuar"))
			_subtitle.text = "Elige la partida guardada."
			_add_continue_buttons()
			_focus_first()
		Step.OPTIONS:
			_set_title("Opciones", UiIcons.section("Opciones"))
			_subtitle.text = "Se guardan al cambiar. La dificultad se elige al crear la partida y se puede cambiar mientras juegas (Menú → Opciones)."
			var options := OptionsTab.build()
			options.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_content.add_child(options)
			_focus_first()
		Step.GENDER:
			_set_title("Nueva partida", UiIcons.section("Nueva partida"))
			_subtitle.text = "¡Bienvenido al mundo Pokémon! ¿Eres chico o chica?"
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 28)
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
			_set_title("Tu personaje", UiIcons.section("Ficha"))
			_subtitle.text = "Todos pueden hacer lo mismo: explorar, nadar, bucear, montar y capturar."
			var grid := HFlowContainer.new()
			grid.alignment = FlowContainer.ALIGNMENT_CENTER
			grid.add_theme_constant_override("h_separation", 16)
			grid.add_theme_constant_override("v_separation", 16)
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
			_set_title("Tu nombre", UiIcons.section("Ficha"))
			_subtitle.text = "Tu nombre aparecerá en el juego (máximo 12 letras)."
			_content.add_child(UiKit.header_chip("Nombre del entrenador", UiIcons.section("Ficha")))
			_name_edit = LineEdit.new()
			_name_edit.text = _character["name"]
			_name_edit.max_length = 12
			_name_edit.custom_minimum_size = Vector2(560, 72)
			_name_edit.add_theme_font_override("font", UiKit.font(true))
			_name_edit.add_theme_font_size_override("font_size", 36)
			_name_edit.text_submitted.connect(func(_text: String) -> void: _confirm_name())
			_content.add_child(_name_edit)
			var next := UiKit.big_button("Continuar", UiIcons.section("Continuar"))
			next.pressed.connect(_confirm_name)
			_content.add_child(next)
			_name_edit.grab_focus.call_deferred()
			_name_edit.select_all.call_deferred()
		Step.DIFFICULTY:
			_set_title("Dificultad", UiIcons.section("Opciones"))
			_subtitle.text = "Cambia el daño de los salvajes, el dinero que pierdes al desmayarte y lo que tardas en recuperarte. Puedes cambiarla después en Menú → Opciones."
			var colors := [UiKit.MINT, Color(0.5, 0.75, 1.0), Color(1.0, 0.5, 0.45)]
			var first: Button = null
			for i in GameState.DIFFICULTIES.size():
				var data: Dictionary = GameState.DIFFICULTIES[i]
				var button := UiKit.slant_button("", colors[i], 22, i == _difficulty)
				button.custom_minimum_size = Vector2(0, 96)
				var box := VBoxContainer.new()
				box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				box.offset_left = 28
				box.alignment = BoxContainer.ALIGNMENT_CENTER
				box.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var name_label := UiKit.label(("★".repeat(i + 1)) + "  " + String(data["name"]), 28, colors[i], true)
				name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				box.add_child(name_label)
				var description := UiKit.label(data["description"], 19, UiKit.MUTED)
				description.mouse_filter = Control.MOUSE_FILTER_IGNORE
				box.add_child(description)
				button.add_child(box)
				_ink_on_focus(button, [name_label, description])
				button.pressed.connect(func() -> void:
					_difficulty = i
					_show_step(Step.CONFIRM))
				_content.add_child(button)
				if i == _difficulty:
					first = button
			first.grab_focus.call_deferred()
		Step.CONFIRM:
			_set_title("¿Todo listo?", UiIcons.section("Nueva partida"))
			_subtitle.text = "Revisa tu elección y comienza la aventura."
			var summary := GridContainer.new()
			summary.columns = 2
			summary.add_theme_constant_override("h_separation", 24)
			summary.add_theme_constant_override("v_separation", 10)
			for pair in [["Nombre", _player_name()], ["Personaje", "%s, de %s" % [_character["name"], _character["region"]]], ["Dificultad", GameState.DIFFICULTIES[_difficulty]["name"]]]:
				summary.add_child(UiKit.label(pair[0], 24, UiKit.MUTED))
				summary.add_child(UiKit.label(pair[1], 28, UiKit.WHITE, true))
			_content.add_child(summary)
			# Semilla del mundo: vacía = un mundo nuevo al azar; un número repite ese mundo.
			_content.add_child(UiKit.label("Semilla del mundo (opcional)", 20, UiKit.MUTED))
			_seed_edit = LineEdit.new()
			_seed_edit.placeholder_text = "Vacío = un mundo nuevo al azar"
			_seed_edit.custom_minimum_size = Vector2(560, 56)
			_seed_edit.add_theme_font_size_override("font_size", 24)
			_seed_edit.max_length = 10
			_content.add_child(_seed_edit)
			var start := UiKit.big_button("¡Comenzar la aventura!", UiIcons.section("Continuar"))
			start.pressed.connect(_start)
			_content.add_child(start)
			var change := UiKit.big_button("Cambiar algo", UiIcons.section("Ficha"))
			change.pressed.connect(func() -> void: _show_step(Step.GENDER))
			_content.add_child(change)
			start.grab_focus.call_deferred()


## Logo del título: nombre grande y una fila de Pokémon que flotan.
func _title_showcase() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	var logo := UiKit.label_on_dark("MUNDO ABIERTO", 64, UiKit.GOLD, true)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_color_override("font_outline_color", UiKit.RED_DARK)
	logo.add_theme_constant_override("outline_size", 14)
	box.add_child(logo)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.custom_minimum_size = Vector2(0, 150)
	box.add_child(row)
	for id in ["snivy", "pikachu", "charizard", "lucario", "tepig", "oshawott"]:
		var data := MenuStyle.species(id)
		if data == null:
			continue
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(130, 130)
		var sprite := UiKit.icon_rect(MenuStyle.front_sprite(data), Vector2(130, 130))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		holder.add_child(sprite)
		_floaters.append(sprite)
		row.add_child(holder)
	return box


func _has_saves() -> bool:
	for slot in range(0, SaveSystem.SLOTS + 1):
		if SaveSystem.has_slot(slot):
			return true
	return false


## Partidas guardadas: una tarjeta por ranura (o el autoguardado).
func _add_continue_buttons() -> void:
	for slot in range(0, SaveSystem.SLOTS + 1):
		if not SaveSystem.has_slot(slot):
			continue
		var info := SaveSystem.slot_info(slot)
		var minutes := int(float(info.get("play_time", 0.0)) / 60.0)
		var button := UiKit.big_button("%s   ·   %s   ·   %d h %02d min" % ["Autoguardado" if slot == 0 else "Ranura %d" % slot, info.get("name", "?"), minutes / 60, minutes % 60], UiIcons.section("Guardar"))
		button.pressed.connect(func() -> void:
			if SaveSystem.load_slot(slot):
				get_tree().change_scene_to_file(WORLD_SCENE))
		_content.add_child(button)


func _confirm_name() -> void:
	if _name_edit.text.strip_edges() == "":
		_name_edit.text = _character["name"]
	_show_step(Step.DIFFICULTY)


func _player_name() -> String:
	var typed := _name_edit.text.strip_edges() if _name_edit != null and is_instance_valid(_name_edit) else ""
	return typed if typed != "" else String(_character["name"])


## Guarda la elección y carga el mundo (partida nueva: mochila y Pokédex desde cero).
func _start() -> void:
	GameState.party.clear()
	GameState.box.clear()
	GameState.dex.clear()
	GameState.bag = Items.starting_bag()
	GameState.play_time = 0.0
	# Cada partida nueva tiene su propio mundo.
	var typed := _seed_edit.text.strip_edges() if _seed_edit != null and is_instance_valid(_seed_edit) else ""
	GameState.world_seed = int(typed) if typed.is_valid_int() and int(typed) > 0 else randi_range(1, 1 << 30)
	GameState.world_flags = {}
	# Las regiones se crean al cargar el mundo, a partir de la semilla de la partida.
	GameState.regions = []
	GameState.region_index = 0
	GameState.character_id = _character["id"]
	GameState.gender = _gender
	GameState.player_name = _player_name()
	GameState.difficulty = _difficulty
	AudioBus.play_sfx("save")
	get_tree().change_scene_to_file(WORLD_SCENE)


func _select_character(entry: Dictionary) -> void:
	_character = entry
	_preview_atlas.atlas = PlayerCharacters.sheet(entry["id"])
	_preview_name.text = entry["name"]
	_preview_region.text = "de %s" % entry["region"]


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

## Tarjeta de un personaje: sprite que camina y su nombre (blanca al tener el foco).
func _card(entry: Dictionary) -> Button:
	var button := UiKit.side_button("", null, false)
	button.custom_minimum_size = Vector2(190, 230)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var name := UiKit.label(entry["name"], 22, UiKit.WHITE, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name)
	var region := UiKit.label(entry["region"], 17, UiKit.MUTED)
	region.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(region)
	_ink_on_focus(button, [name, region])
	return button


func _big_button(text: String, entries: Array[Dictionary]) -> Button:
	var button := UiKit.side_button("", null, false)
	button.custom_minimum_size = Vector2(480, 280)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var label := UiKit.label(text, 40, UiKit.WHITE, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	_ink_on_focus(button, [label])
	return button


## Los textos dentro de un botón se oscurecen cuando el botón se vuelve blanco.
func _ink_on_focus(button: Button, labels: Array) -> void:
	for item: Label in labels:
		item.set_meta("light_color", item.get_theme_color("font_color"))
	var paint := func(dark: bool) -> void:
		for item: Label in labels:
			if is_instance_valid(item):
				item.add_theme_color_override("font_color", UiKit.INK if dark else item.get_meta("light_color"))
				item.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0 if dark else 0.35))
	button.focus_entered.connect(paint.bind(true))
	button.focus_exited.connect(paint.bind(false))
	button.mouse_entered.connect(button.grab_focus)
