class_name OptionsTab
extends RefCounted
## Pestaña Opciones: cámara y control, video, audio, juego e interfaz y accesibilidad.
## Se guardan al cambiar (GameOptions, user://options.cfg).


static func build() -> Control:
	GameOptions.load_options()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 680)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(MenuStyle.label("Cámara y control", 26, MenuStyle.ACCENT))
	box.add_child(_slider("Sensibilidad del mouse", 0.05, 0.4, GameOptions.mouse_sensitivity, func(v: float) -> void: GameOptions.mouse_sensitivity = v))
	box.add_child(_slider("Velocidad del stick", 60.0, 300.0, GameOptions.stick_speed, func(v: float) -> void: GameOptions.stick_speed = v))
	box.add_child(_toggle("Invertir eje vertical de la cámara", GameOptions.invert_y, func(v: bool) -> void: GameOptions.invert_y = v))
	box.add_child(MenuStyle.label("Video", 26, MenuStyle.ACCENT))
	box.add_child(_toggle("Pantalla completa", GameOptions.fullscreen, func(v: bool) -> void: GameOptions.fullscreen = v))
	var sizes: Array = GameOptions.RESOLUTIONS.map(func(r: Vector2i) -> String: return "%d × %d" % [r.x, r.y])
	box.add_child(_choice("Resolución (en ventana)", sizes, GameOptions.resolution, func(v: int) -> void: GameOptions.resolution = v))
	box.add_child(_choice("Calidad (sombras, nitidez y distancia)", GameOptions.QUALITY_NAMES, GameOptions.quality, func(v: int) -> void: GameOptions.quality = v))
	box.add_child(MenuStyle.label("Audio", 26, MenuStyle.ACCENT))
	box.add_child(_slider("Música", 0.0, 1.0, GameOptions.music_volume, func(v: float) -> void: GameOptions.music_volume = v))
	box.add_child(_slider("Efectos", 0.0, 1.0, GameOptions.effects_volume, func(v: float) -> void: GameOptions.effects_volume = v))
	box.add_child(_slider("Gritos de los Pokémon", 0.0, 1.0, GameOptions.cries_volume, func(v: float) -> void: GameOptions.cries_volume = v))
	box.add_child(MenuStyle.label("Juego e interfaz", 26, MenuStyle.ACCENT))
	box.add_child(_choice("Pokémon en el mundo", GameOptions.DENSITY_NAMES, GameOptions.density, func(v: int) -> void: GameOptions.density = v))
	box.add_child(_toggle("Mostrar la leyenda de botones", GameOptions.show_hints, func(v: bool) -> void: GameOptions.show_hints = v))
	box.add_child(_choice("Velocidad del texto y avisos", GameOptions.TEXT_SPEED_NAMES, GameOptions.text_speed, func(v: int) -> void: GameOptions.text_speed = v))
	box.add_child(_choice("Idioma", GameOptions.LANGUAGES, GameOptions.language, func(v: int) -> void: GameOptions.language = v))
	box.add_child(MenuStyle.label("Accesibilidad", 26, MenuStyle.ACCENT))
	box.add_child(_toggle("Reducir temblores y destellos", GameOptions.reduce_shake, func(v: bool) -> void: GameOptions.reduce_shake = v))
	box.add_child(_choice("Filtro para daltonismo", GameOptions.COLORBLIND_NAMES, GameOptions.colorblind, func(v: int) -> void: GameOptions.colorblind = v))
	box.add_child(MenuStyle.label("Reasignar botones", 26, MenuStyle.ACCENT))
	box.add_child(MenuStyle.wrapped("Elige una acción y presiona la tecla, botón del mouse o del mando nuevo (Esc cancela). Se cambia solo el del mismo dispositivo.", 17, MenuStyle.MUTED))
	for action: String in GameOptions.REMAPPABLE:
		box.add_child(_remap_row(action))
	var reset := MenuStyle.button("Restablecer los botones originales", 18)
	reset.pressed.connect(func() -> void:
		GameOptions.reset_remaps()
		for child in box.get_children():
			if child.has_meta("remap_action"):
				_refresh_remap(child))
	box.add_child(reset)
	return scroll


static func _remap_row(action: String) -> Control:
	var row := _row(GameOptions.ACTION_NAMES.get(action, action))
	row.set_meta("remap_action", action)
	var keys := MenuStyle.label("", 18, MenuStyle.MUTED)
	keys.name = "Keys"
	keys.custom_minimum_size.x = 260
	row.add_child(keys)
	var button := MenuStyle.button("Cambiar", 16)
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


static func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := MenuStyle.label(text, 20)
	label.custom_minimum_size.x = 420
	row.add_child(label)
	return row


static func _slider(text: String, minimum: float, maximum: float, value: float, setter: Callable) -> Control:
	var row := _row(text)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = (maximum - minimum) / 100.0
	slider.value = value
	slider.custom_minimum_size.x = 360
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		GameOptions.save_options())
	row.add_child(slider)
	return row


static func _toggle(text: String, value: bool, setter: Callable) -> Control:
	var row := _row(text)
	var check := CheckButton.new()
	check.button_pressed = value
	check.toggled.connect(func(v: bool) -> void:
		setter.call(v)
		GameOptions.save_options())
	row.add_child(check)
	return row


static func _choice(text: String, names: Array, value: int, setter: Callable) -> Control:
	var row := _row(text)
	var options := OptionButton.new()
	for name: String in names:
		options.add_item(name)
	options.selected = value
	options.add_theme_font_size_override("font_size", 20)
	options.item_selected.connect(func(v: int) -> void:
		setter.call(v)
		GameOptions.save_options())
	row.add_child(options)
	return row
