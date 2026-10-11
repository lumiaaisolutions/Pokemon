class_name CookingUI
extends Control
## Cocinar en la fogata de la tienda de campaña (campamento, comida y hambre;
## acordado con Fernando el 2026-10-10): recetas según los ingredientes de la
## mochila (curry, sándwich, estofado de bayas, pescado asado…). Tiempo real de
## cocción con animación de vapor (completando la simplificación anotada en
## docs/decisiones_sin_preguntar.md: antes era instantáneo); la fogata mejorada del
## campamento cocina más rápido (ver CampManager.cook_seconds). Al estar listo, tu
## equipo sale a comer contigo (sube su vínculo). Pausa el juego, como la Tienda Pokémon.

var main: Node
## Campamento desde el que se abrió (si lo hay): al terminar de cocinar se ve el vapor,
## las burbujas y el platillo sobre el tronco (world/npc/camp.gd.cook_flourish, pedido de
## Fernando el 2026-10-10, ronda 3).
var camp: Camp
var _money: Label
var _list: VBoxContainer
var _message := ""
var _last_dish := ""
## Cocción en curso (tiempo real; ver _start_cooking/_process).
var _cooking := false
var _cook_remaining := 0.0
var _pending_recipe: Dictionary = {}
var _pending_eat_now := true


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
	for child in _list.get_children():
		child.queue_free()
	if _cooking:
		_money.text = "🔥 Cocinando %s... %ds" % [Items.display_name(String(_pending_recipe.get("result", ""))), int(ceil(_cook_remaining))]
		_list.add_child(MenuStyle.label("Espera a que esté listo junto a la fogata.", 16, MenuStyle.MUTED))
		return
	_money.text = _message if _message != "" else "Elige una receta: se cocina de verdad junto a la fogata."
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
		# Comer ahí o guardarlo en la Mochila (decisión de Fernando, 2026-10-10; caduca):
		# las dos opciones cocinan de verdad en la fogata (tiempo real, ver _start_cooking).
		var button := MenuStyle.button("Cocinar y comer", 18)
		button.pressed.connect(_start_cooking.bind(recipe, true))
		MenuStyle.style_button(button, ItemEffects.can_craft(recipe))
		row.add_child(button)
		var keep := MenuStyle.button("Guardar", 18)
		keep.pressed.connect(_start_cooking.bind(recipe, false))
		MenuStyle.style_button(keep, ItemEffects.can_craft(recipe))
		row.add_child(keep)
		_list.add_child(row)
		if first == null:
			first = button
	if first != null:
		first.grab_focus.call_deferred()


## Empieza la cocción de verdad (tiempo real, más corto con la fogata mejorada): el
## platillo no está listo hasta que pasa CampManager.cook_seconds(nivel).
func _start_cooking(recipe: Dictionary, eat_now: bool) -> void:
	if _cooking or not ItemEffects.can_craft(recipe):
		return
	_cooking = true
	_pending_recipe = recipe
	_pending_eat_now = eat_now
	var level := int(camp.level) if camp != null and is_instance_valid(camp) else 0
	_cook_remaining = CampManager.cook_seconds(level)
	if camp != null and is_instance_valid(camp):
		PixelBurst.spawn(main, camp.global_position + Camp.FIRE_OFFSET + Vector3(0, 1.3, 0), PixelBurst.Kind.SMOKE, 0.6)
	_refresh()


func _process(delta: float) -> void:
	if not _cooking:
		return
	_cook_remaining -= delta
	if _cook_remaining <= 0.0:
		_finish_cooking()
	else:
		_money.text = "🔥 Cocinando %s... %ds" % [Items.display_name(String(_pending_recipe.get("result", ""))), int(ceil(_cook_remaining))]


func _finish_cooking() -> void:
	_cooking = false
	_message = ItemEffects.cook(_pending_recipe, main, _pending_eat_now)
	var dish := String(_pending_recipe.get("result", ""))
	if _message.begins_with("¡Cocinaste"):
		_last_dish = dish
	if camp != null and is_instance_valid(camp):
		var companion := main.get("companion") as PokemonActor if main != null else null
		camp.cook_flourish(companion, Items.icon(dish))
	_pending_recipe = {}
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _cooking:
		GameState.notice.emit("Espera a que termine de cocinarse.")
		return
	get_tree().paused = false
	queue_free()
