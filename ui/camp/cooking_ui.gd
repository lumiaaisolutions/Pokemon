class_name CookingUI
extends Control
## Cocinar en la fogata de la tienda de campaña (campamento, comida y hambre;
## acordado con Fernando el 2026-10-10): recetas según los ingredientes de la
## mochila (curry, sándwich, estofado de bayas, pescado asado…); se comen al
## instante (llenan mucho el hambre y dan un efecto extra) y tu equipo sale a
## comer contigo (sube su vínculo). Pausa el juego, como la Tienda Pokémon.

var main: Node
var _money: Label
var _list: VBoxContainer
var _message := ""


func open() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := MenuStyle.panel_container(Color(0.9, 0.55, 0.25))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 560)
	panel.position = -panel.custom_minimum_size * 0.5
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(MenuStyle.label("Cocinar en la fogata", 26, MenuStyle.ACCENT))
	_money = MenuStyle.label("", 16, MenuStyle.MUTED)
	box.add_child(_money)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var close := MenuStyle.button("Salir (%s)" % InputHints.hint("menu"), 20)
	close.pressed.connect(_close)
	box.add_child(close)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _refresh() -> void:
	_money.text = _message if _message != "" else "Elige una receta: se come al instante junto a tu equipo."
	for child in _list.get_children():
		child.queue_free()
	var recipes := Items.cook_recipes()
	if recipes.is_empty():
		_list.add_child(MenuStyle.label("Todavía no hay recetas de cocina.", 18, MenuStyle.MUTED))
	var first: Button
	for recipe: Dictionary in recipes:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(MenuStyle.texture_rect(Items.icon(String(recipe["result"])), Vector2(32, 32)))
		var needs: Array[String] = []
		for id: String in recipe["needs"]:
			needs.append("%s %d/%d" % [Items.display_name(id), GameState.item_count(id), int(recipe["needs"][id])])
		var name := MenuStyle.label("%s\n%s" % [Items.display_name(String(recipe["result"])), ", ".join(needs)], 16)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.tooltip_text = str(Items.get_item(String(recipe["result"])).get("desc", ""))
		row.add_child(name)
		var button := MenuStyle.button("Cocinar", 18)
		button.pressed.connect(func() -> void:
			_message = ItemEffects.cook(recipe, main)
			_refresh())
		MenuStyle.style_button(button, ItemEffects.can_craft(recipe))
		row.add_child(button)
		_list.add_child(row)
		if first == null:
			first = button
	if first != null:
		first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	get_tree().paused = false
	queue_free()
