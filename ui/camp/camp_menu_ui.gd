class_name CampMenuUI
extends Control
## Menú de la tienda de campaña (pedido de Fernando el 2026-10-10, ronda 3: botones de
## ícono + texto en píldora, color propio, con sombra; se agrandan y brillan al pasar o
## elegir, con sonido). Reemplaza las píldoras genéricas de DialogBox para este menú, que
## ya tiene demasiadas opciones para esa fila pequeña: Dormir, Cocinar, Recoger, Convivir,
## Mejorar campamento, Ver las estrellas y Nada.

var camp_manager: CampManager
var entry: Dictionary


func open() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# No pausa el juego (la fogata y las luciérnagas se siguen viendo detrás); solo
	# congela al jugador mientras decide, como el resto de los diálogos del juego.
	DialogBox.blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := MenuStyle.panel_container(UiKit.RED)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(380, 0)
	panel.position = Vector2(-190, -260)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(MenuStyle.label("Tienda de campaña", 24, MenuStyle.ACCENT))
	box.add_child(MenuStyle.wrapped("¿Qué quieres hacer?", 16, MenuStyle.MUTED))
	var night := GameState.is_night()
	var today := GameState.game_day()
	var communed := int(GameState.world_flags.get("camp_commune_day", -1)) == today
	var level := int(entry.get("level", 0))
	_option(box, "Dormir" + ("" if night else " (de noche)"), "sleep", Color(0.25, 0.3, 0.55), night, func() -> void: camp_manager.sleep(entry))
	_option(box, "Cocinar", "cook", Color(0.85, 0.45, 0.15), true, func() -> void: camp_manager.open_cooking(entry))
	_option(box, "Recoger", "pack", Color(0.5, 0.38, 0.25), true, func() -> void: camp_manager.pack_tent(entry))
	_option(box, "Convivir" + (" (ya hoy)" if communed else ""), "commune", Color(0.8, 0.3, 0.45), not communed, func() -> void: camp_manager.commune(entry))
	_option(box, "Mejorar campamento" + (" (máximo)" if level >= 2 else " (%s)" % camp_manager.upgrade_cost_text(entry)), "upgrade", Color(0.2, 0.55, 0.5), level < 2, func() -> void: camp_manager.upgrade_camp(entry))
	if camp_manager.has_chest(entry):
		_option(box, "Baúl del campamento", "chest", Color(0.55, 0.42, 0.2), true, func() -> void: camp_manager.open_chest(entry))
	_option(box, "Ver las estrellas" + ("" if night else " (de noche)"), "stars", Color(0.3, 0.35, 0.6), night, func() -> void: camp_manager.stargaze())
	_option(box, "Nada", "none", Color(0.42, 0.42, 0.46), true, Callable())
	(box.get_child(2) as Button).grab_focus.call_deferred()


func _option(box: VBoxContainer, text: String, icon: String, color: Color, enabled: bool, action: Callable) -> void:
	var button := UiKit.action_button(text, UiIcons.action(icon), color, false, enabled)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void:
		_close()
		if action.is_valid():
			action.call())
	box.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	DialogBox.blocking = false
	queue_free()
