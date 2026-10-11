class_name RestaurantUI
extends Control
## Restaurante, uno por ciudad (campamento, comida y hambre; acordado con Fernando el
## 2026-10-10): 3-4 platillos con precio; llenan mucho el hambre y dan un efecto. Se
## come ahí mismo (no ocupa espacio en la mochila). Pausa el juego, como la tienda.

const MENU := [
	{"name": "Curry de la casa", "price": 400, "feed": 7.0, "boost": {"kind": "speed", "seconds": 240}},
	{"name": "Estofado del chef", "price": 450, "feed": 7.5, "heal_hearts": 8.0},
	{"name": "Plato del pescador", "price": 500, "feed": 8.0, "heal_companion": 0.25},
	{"name": "Postre de la casa", "price": 250, "feed": 5.0},
]

var settlement_name := "la ciudad"
## Lo asigna quien la abre (Structures ya resuelve al jugador con su mismo respaldo).
var player: Player
var _money: Label
var _list: VBoxContainer


func open() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := MenuStyle.panel_container(Color(0.75, 0.3, 0.25))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 440)
	panel.position = -panel.custom_minimum_size * 0.5
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(MenuStyle.label("Restaurante de %s" % settlement_name, 24, MenuStyle.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_money = MenuStyle.label("", 18)
	header.add_child(_money)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)
	var close := MenuStyle.button("Salir (%s)" % InputHints.hint("menu"), 20)
	close.pressed.connect(_close)
	box.add_child(close)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _refresh() -> void:
	_money.text = "Dinero: $%d" % GameState.money
	for child in _list.get_children():
		child.queue_free()
	for dish: Dictionary in MENU:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(MenuStyle.label(String(dish["name"]), 18))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		row.add_child(MenuStyle.label("$%d" % int(dish["price"]), 18))
		var button := MenuStyle.button("Pedir", 18)
		button.pressed.connect(func() -> void:
			_buy(dish)
			_refresh())
		row.add_child(button)
		_list.add_child(row)


func _buy(dish: Dictionary) -> void:
	var price := int(dish["price"])
	if GameState.money < price:
		GameState.notice.emit("No alcanza.")
		return
	GameState.add_money(-price, "Restaurante: %s" % String(dish["name"]))
	GameState.feed(float(dish.get("feed", 0.0)))
	if dish.has("heal_hearts") and player != null:
		player.heal(float(dish["heal_hearts"]))
	if dish.has("heal_companion") and not GameState.party.is_empty():
		var entry: Dictionary = GameState.party[GameState.companion_index]
		entry["hp_ratio"] = minf(float(entry.get("hp_ratio", 1.0)) + float(dish["heal_companion"]), 1.0)
	if dish.has("boost"):
		var boost: Dictionary = dish["boost"]
		GameState.boosts[boost["kind"]] = GameState.play_time + float(boost["seconds"])
	GameState.notice.emit("¡Delicioso! Comiste %s." % String(dish["name"]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	get_tree().paused = false
	queue_free()
