class_name ShopUI
extends Control
## Tienda Pokémon: comprar (×1 o ×10) y vender a mitad de precio. Pausa el juego.
## El surtido crece con las medallas y cada día ofrece 4 MT distintas.

const STOCK := ["poke-ball", "great-ball", "potion", "super-potion", "full-heal", "repel", "super-repel", "escape-rope", "honey",
		"lava-cookie", "poke-doll", "quick-ball", "dusk-ball", "net-ball", "dive-ball", "nest-ball", "heal-ball"]
## Objetos que se desbloquean con medallas: [medallas, id].
const BADGE_STOCK := [[2, "ultra-ball"], [2, "hyper-potion"], [3, "max-repel"], [4, "repeat-ball"], [5, "luxury-ball"], [6, "heavy-ball"]]
const TM_PER_DAY := 4

var title := "Tienda Pokémon"
## Surtido propio (comerciante viajero) y multiplicador de precio de compra.
var custom_stock: Array[String] = []
var price_factor := 1.0
var _selling := false
var _list: VBoxContainer
var _money: Label
var _tabs: Array[Button] = []


func open() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := MenuStyle.panel_container(Color(0.4, 0.6, 1.0))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 620)
	panel.position = -panel.custom_minimum_size * 0.5
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(MenuStyle.label(title, 28, MenuStyle.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_money = MenuStyle.label("", 22)
	header.add_child(_money)
	var tabs := HBoxContainer.new()
	box.add_child(tabs)
	for i in 2:
		var tab := MenuStyle.button(["Comprar", "Vender"][i], 20)
		tab.pressed.connect(func() -> void:
			_selling = i == 1
			_refresh())
		tabs.add_child(tab)
		_tabs.append(tab)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var close := MenuStyle.button("Salir (%s)" % InputHints.hint("menu"), 20)
	close.pressed.connect(_close)
	box.add_child(close)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


## Lo que vende hoy: surtido base, lo desbloqueado por medallas y 4 MT del día.
static func stock() -> Array[String]:
	var result: Array[String] = []
	result.assign(STOCK)
	var badges: int = (GameState.world_flags.get("badges", []) as Array).size()
	for entry: Array in BADGE_STOCK:
		if badges >= int(entry[0]):
			result.append(entry[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.game_day() * 7907 + GameState.world_seed
	var types := range(18)
	for i in TM_PER_DAY:
		var type: int = types.pop_at(rng.randi() % types.size())
		result.append("tm-%s" % ["normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel", "fire", "water",
				"grass", "electric", "psychic", "ice", "dragon", "dark", "fairy"][type])
	return result.filter(func(id: String) -> bool: return Items.exists(id))


## Con mala reputación (promedio menor a 30) todo cuesta 20 % más.
static func reputation_factor() -> float:
	if GameState.reputation.is_empty():
		return 1.0
	var total := 0.0
	for group: String in GameState.reputation:
		total += float(GameState.reputation[group])
	return 1.2 if total / GameState.reputation.size() < 30.0 else 1.0


static func sell_price(id: String) -> int:
	return int(Items.get_item(id).get("price", 0)) / 2


static func buy(id: String, amount: int, factor: float = 1.0) -> bool:
	var cost := int(Items.get_item(id).get("price", 0) * factor * reputation_factor()) * amount
	if cost <= 0 or GameState.money < cost:
		return false
	GameState.add_money(-cost, "Compra: %s × %d" % [Items.display_name(id), amount])
	GameState.add_item(id, amount)
	return true


static func sell(id: String, amount: int) -> bool:
	if GameState.item_count(id) < amount or sell_price(id) <= 0 or Items.get_item(id).get("pocket", "") == "clave":
		return false
	GameState.use_item(id, amount)
	GameState.add_money(sell_price(id) * amount, "Venta: %s × %d" % [Items.display_name(id), amount])
	return true


func _refresh() -> void:
	_money.text = "Dinero: $%d" % GameState.money
	for i in _tabs.size():
		MenuStyle.style_button(_tabs[i], (i == 1) == _selling)
	for child in _list.get_children():
		child.queue_free()
	var ids: Array[String] = []
	if _selling:
		for id: String in GameState.bag:
			if GameState.item_count(id) > 0 and sell_price(id) > 0 and Items.get_item(id).get("pocket", "") != "clave":
				ids.append(id)
	else:
		ids = custom_stock if not custom_stock.is_empty() else stock()
	if ids.is_empty():
		_list.add_child(MenuStyle.label("No tienes nada que vender." if _selling else "Sin surtido.", 18, MenuStyle.MUTED))
	var first: Button
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(MenuStyle.texture_rect(Items.icon(id), Vector2(32, 32)))
		var name := MenuStyle.label("%s  (tienes %d)" % [Items.display_name(id), GameState.item_count(id)], 18)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.tooltip_text = str(Items.get_item(id).get("desc", ""))
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(name)
		var price := sell_price(id) if _selling else int(Items.get_item(id).get("price", 0) * price_factor * reputation_factor())
		row.add_child(MenuStyle.label("$%d" % price, 18))
		for amount in [1, 10]:
			var button := MenuStyle.button(("Vender ×%d" if _selling else "Comprar ×%d") % amount, 16)
			button.pressed.connect(func() -> void:
				var ok := sell(id, amount) if _selling else buy(id, amount, price_factor)
				if not ok:
					GameState.notice.emit("No alcanza." if not _selling else "No tienes suficientes.")
				_refresh())
			row.add_child(button)
			if first == null:
				first = button
		_list.add_child(row)
	if first != null:
		first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	get_tree().paused = false
	queue_free()
