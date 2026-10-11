class_name OptionsTab
extends RefCounted
## Pestaña Opciones (nivel Dinero/Logros, pedido de Fernando el 2026-10-11): una tarjeta
## por categoría (ícono y color propio), deslizadores rojos e interruptores de píldora
## (ya vienen del tema, UiKit.theme()) y un tooltip en cada ajuste explicando su efecto.


## [título, ícono/emoji, color] por categoría.
const SECTIONS := [
	["Cámara y control", "🎮", Color(0.35, 0.55, 0.85)],
	["Video", "🖥", Color(0.4, 0.65, 0.5)],
	["Audio", "🔊", Color(0.8, 0.55, 0.25)],
	["Juego e interfaz", "🧭", Color(0.75, 0.3, 0.6)],
	["Accesibilidad", "♿", Color(0.3, 0.6, 0.65)],
	["Reasignar botones", "🕹", Color(0.55, 0.45, 0.75)],
]


static func build() -> Control:
	GameOptions.load_options()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# GridContainer con 2 columnas fijas: el ancho de HFlowContainer no se calcula bien
	## dentro de un ScrollContainer (se queda angosto); con columnas fijas es predecible.
	var columns := GridContainer.new()
	columns.columns = 2
	columns.add_theme_constant_override("h_separation", 16)
	columns.add_theme_constant_override("v_separation", 16)
	scroll.add_child(columns)

	columns.add_child(_section(SECTIONS[0], [
		_slider("Sensibilidad del mouse", "Qué tan rápido gira la cámara al mover el mouse.", 0.05, 0.4, GameOptions.mouse_sensitivity, func(v: float) -> void: GameOptions.mouse_sensitivity = v),
		_slider("Velocidad del stick", "Qué tan rápido gira la cámara con el stick derecho del mando.", 60.0, 300.0, GameOptions.stick_speed, func(v: float) -> void: GameOptions.stick_speed = v),
		_toggle("Invertir eje vertical", "Si lo activas, mover arriba la cámara la lleva hacia abajo (y viceversa).", GameOptions.invert_y, func(v: bool) -> void: GameOptions.invert_y = v),
	]))
	columns.add_child(_section(SECTIONS[1], [
		_toggle("Pantalla completa", "Oculta la barra de la ventana y usa toda la pantalla.", GameOptions.fullscreen, func(v: bool) -> void: GameOptions.fullscreen = v),
		_choice("Resolución (en ventana)", "Tamaño de la ventana cuando no está en pantalla completa.", GameOptions.RESOLUTIONS.map(func(r: Vector2i) -> String: return "%d × %d" % [r.x, r.y]), GameOptions.resolution, func(v: int) -> void: GameOptions.resolution = v),
		_choice("Calidad", "Sombras, nitidez y qué tan lejos se ve con detalle. Más alta pide más de la máquina.", GameOptions.QUALITY_NAMES, GameOptions.quality, func(v: int) -> void: GameOptions.quality = v),
	]))
	columns.add_child(_section(SECTIONS[2], [
		_slider("Música", "Volumen de la música de fondo.", 0.0, 1.0, GameOptions.music_volume, func(v: float) -> void: GameOptions.music_volume = v),
		_slider("Efectos", "Volumen de los sonidos (botones, combate, objetos).", 0.0, 1.0, GameOptions.effects_volume, func(v: float) -> void: GameOptions.effects_volume = v),
		_slider("Gritos de los Pokémon", "Volumen de los gritos (Pokédex, combate, al verlos).", 0.0, 1.0, GameOptions.cries_volume, func(v: float) -> void: GameOptions.cries_volume = v),
	]))
	columns.add_child(_section(SECTIONS[3], [
		_choice("Dificultad (de esta partida)", "Qué tan fuertes son los rivales. Se puede subir o bajar cuando quieras.", GameState.DIFFICULTIES.map(func(d: Dictionary) -> String: return d["name"]), GameState.difficulty, func(v: int) -> void: GameState.difficulty = v),
		_info("Se adapta a tu nivel", AdaptiveDifficulty.label(), "Sube o baja sola con tus rachas de victorias, desmayos y capturas (Fase 6)."),
		_choice("Pokémon en el mundo", "Cuántos salvajes aparecen a tu alrededor.", GameOptions.DENSITY_NAMES, GameOptions.density, func(v: int) -> void: GameOptions.density = v),
		_toggle("Mostrar la leyenda de botones", "La tira de controles abajo en pantalla (también se abre o cierra con H).", GameOptions.show_hints, func(v: bool) -> void: GameOptions.show_hints = v),
		_choice("Velocidad del texto y avisos", "Qué tan rápido aparece el texto en la caja de diálogo y los avisos.", GameOptions.TEXT_SPEED_NAMES, GameOptions.text_speed, func(v: int) -> void: GameOptions.text_speed = v),
		_choice("Idioma", "Idioma de los textos del juego.", GameOptions.LANGUAGES, GameOptions.language, func(v: int) -> void: GameOptions.language = v),
	]))
	columns.add_child(_section(SECTIONS[4], [
		_toggle("Reducir temblores y destellos", "Menos sacudidas de cámara y parpadeos fuertes.", GameOptions.reduce_shake, func(v: bool) -> void: GameOptions.reduce_shake = v),
		_choice("Filtro para daltonismo", "Ajusta los colores (tipos, vida, avisos) para verse mejor según el tipo de daltonismo.", GameOptions.COLORBLIND_NAMES, GameOptions.colorblind, func(v: int) -> void: GameOptions.colorblind = v),
	]))

	var remap_rows := VBoxContainer.new()
	remap_rows.add_theme_constant_override("separation", 8)
	remap_rows.add_child(UiKit.wrapped("Elige una acción y presiona la tecla, botón del mouse o del mando nuevo (Esc cancela). Se cambia solo el del mismo dispositivo.", 15, UiKit.TEXT_SOFT))
	for action: String in GameOptions.REMAPPABLE:
		remap_rows.add_child(_remap_row(action))
	var reset := UiKit.action_button("Restablecer los botones originales", UiIcons.section("Opciones"), Color(0.55, 0.45, 0.75))
	reset.tooltip_text = "Regresa todos los controles de teclado, mouse y mando a como venían de fábrica."
	reset.pressed.connect(func() -> void:
		GameOptions.reset_remaps()
		for child in remap_rows.get_children():
			if child.has_meta("remap_action"):
				_refresh_remap(child))
	remap_rows.add_child(reset)
	columns.add_child(_card(SECTIONS[5], remap_rows))
	return scroll


## Tarjeta de una categoría: ícono + título en color propio y sus ajustes abajo.
static func _section(info: Array, rows: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	for row: Control in rows:
		box.add_child(row)
	return _card(info, box)


static func _card(info: Array, content: Control) -> Control:
	var color: Color = info[2]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.light_style(color, 20, 3))
	panel.custom_minimum_size = Vector2(380, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	head.add_child(_emoji_badge(String(info[1]), color, 38))
	head.add_child(UiKit.label(String(info[0]), 22, UiKit.ink(color), true))
	column.add_child(content)
	return panel


## Círculo de color con el emoji de la categoría centrado (más simple que dibujar un
## ícono pixel por categoría; mantiene la línea de "círculo de color" del resto del menú).
static func _emoji_badge(emoji: String, color: Color, diameter: float = 38.0) -> Control:
	var holder := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(diameter * 0.5))
	holder.add_theme_stylebox_override("panel", style)
	holder.custom_minimum_size = Vector2(diameter, diameter)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = emoji
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(diameter * 0.55))
	holder.add_child(label)
	return holder


static func _remap_row(action: String) -> Control:
	var row := _row(GameOptions.ACTION_NAMES.get(action, action), "")
	row.set_meta("remap_action", action)
	var keys := MenuStyle.label("", 17, MenuStyle.MUTED)
	keys.name = "Keys"
	keys.custom_minimum_size.x = 220
	row.add_child(keys)
	var button := MenuStyle.button("Cambiar", 15)
	button.name = "Change"
	var catcher := RemapCatcher.new()
	catcher.action = action
	catcher.done.connect(func() -> void:
		button.text = "Cambiar"
		_refresh_remap(row))
	row.add_child(catcher)
	button.pressed.connect(func() -> void:
		button.text = "Presiona…"
		catcher.listen())
	row.add_child(button)
	_refresh_remap(row)
	return row


static func _refresh_remap(row: Control) -> void:
	var action: String = row.get_meta("remap_action")
	(row.get_node("Keys") as Label).text = "%s   ·   %s" % [InputHints.hint(action, 0), InputHints.hint(action, 1)]


static func _row(text: String, tip: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := UiKit.label(text, 17, UiKit.INK)
	label.custom_minimum_size.x = 190
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	if tip != "":
		row.tooltip_text = tip
	return row


## Fila de solo lectura: etiqueta + valor corto, con el detalle en el tooltip (p. ej.
## la dificultad adaptable, que no se cambia a mano).
static func _info(text: String, value: String, tip: String) -> Control:
	var row := _row(text, tip)
	var label := UiKit.label(value, 15, UiKit.TEXT_SOFT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.tooltip_text = tip
	row.add_child(label)
	return row


static func _slider(text: String, tip: String, minimum: float, maximum: float, value: float, setter: Callable) -> Control:
	var row := _row(text, tip)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = (maximum - minimum) / 100.0
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 140
	slider.tooltip_text = tip
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		GameOptions.save_options())
	row.add_child(slider)
	return row


static func _toggle(text: String, tip: String, value: bool, setter: Callable) -> Control:
	var row := _row(text, tip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var check := CheckButton.new()
	check.button_pressed = value
	check.tooltip_text = tip
	check.toggled.connect(func(v: bool) -> void:
		setter.call(v)
		GameOptions.save_options())
	row.add_child(check)
	return row


static func _choice(text: String, tip: String, names: Array, value: int, setter: Callable) -> Control:
	var row := _row(text, tip)
	var options := OptionButton.new()
	for name: String in names:
		options.add_item(name)
	options.selected = value
	options.add_theme_font_size_override("font_size", 16)
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.tooltip_text = tip
	options.item_selected.connect(func(v: int) -> void:
		setter.call(v)
		GameOptions.save_options())
	row.add_child(options)
	return row
