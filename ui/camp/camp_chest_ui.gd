class_name CampChestUI
extends Control
## Baúl del campamento (nivel 2 de la mejora), funcional de verdad (completando la
## simplificación anotada en docs/decisiones_sin_preguntar.md: antes era solo decorativo).
## Dos columnas: tu Mochila (lo que puedes guardar) y el Baúl (lo que ya guardaste, para
## sacarlo de vuelta). Pausa el juego, como la Tienda de campaña y Cocinar.

var camp_manager: CampManager
var entry: Dictionary

var _bag_list: VBoxContainer
var _chest_list: VBoxContainer


func open() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := MenuStyle.panel_container(Color(0.6, 0.46, 0.22))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(740, 560)
	panel.position = -panel.custom_minimum_size * 0.5
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(MenuStyle.label("Baúl del campamento", 26, MenuStyle.ACCENT))
	box.add_child(MenuStyle.wrapped("Guarda objetos aquí para llevar menos peso, o sácalos cuando los necesites.", 15, MenuStyle.MUTED))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	columns.add_child(_column("Mochila", true))
	columns.add_child(_column("Baúl", false))
	var close := MenuStyle.button("Salir (%s)" % InputHints.hint("menu"), 20)
	close.pressed.connect(_close)
	box.add_child(close)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _column(title: String, is_bag: bool) -> Control:
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(MenuStyle.label(title, 19, MenuStyle.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if is_bag:
		_bag_list = list
	else:
		_chest_list = list
	return side


func _refresh() -> void:
	for child in _bag_list.get_children():
		child.queue_free()
	for child in _chest_list.get_children():
		child.queue_free()
	var bag: Dictionary = GameState.bag
	var ids := bag.keys()
	ids.sort()
	var any_bag := false
	for id: String in ids:
		var amount := int(bag[id])
		if amount <= 0 or not Items.exists(id):
			continue
		any_bag = true
		_bag_list.add_child(_row(id, amount, "Guardar", func() -> void:
			if camp_manager.chest_store(entry, id, 1):
				_refresh()))
	if not any_bag:
		_bag_list.add_child(MenuStyle.label("No traes nada en la Mochila.", 15, MenuStyle.MUTED))
	var chest: Dictionary = camp_manager.chest_contents(entry)
	var chest_ids := chest.keys()
	chest_ids.sort()
	var any_chest := false
	for id: String in chest_ids:
		var amount := int(chest[id])
		if amount <= 0:
			continue
		any_chest = true
		_chest_list.add_child(_row(id, amount, "Sacar", func() -> void:
			if camp_manager.chest_take(entry, id, 1):
				_refresh()))
	if not any_chest:
		_chest_list.add_child(MenuStyle.label("El baúl está vacío.", 15, MenuStyle.MUTED))


func _row(id: String, amount: int, verb: String, action: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(MenuStyle.texture_rect(Items.icon(id), Vector2(28, 28)))
	var name := MenuStyle.label("%s ×%d" % [Items.display_name(id), amount], 15)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var button := MenuStyle.button(verb, 15)
	button.pressed.connect(action)
	row.add_child(button)
	return row


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	get_tree().paused = false
	queue_free()
