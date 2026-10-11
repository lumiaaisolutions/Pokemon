class_name BagTab
extends RefCounted
## Sección Mochila (estilo Z-A): arriba los bolsillos con su ícono; a la izquierda la
## lista de objetos del bolsillo (ícono, nombre y cantidad); a la derecha el equipo (el
## objeto se usa en tu acompañante, marcado) y la ficha del objeto con su descripción y
## su acción (elegir ball, curar, comer, enseñar MT…). El bolsillo Fabricación muestra
## las recetas.

var _menu: GameMenu
var _pocket := "pokeballs"
var _selected := ""
var _message := ""


func _init(menu: GameMenu) -> void:
	_menu = menu


func build() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	# Bolsillos con ícono.
	var pockets := HBoxContainer.new()
	pockets.add_theme_constant_override("separation", 8)
	root.add_child(pockets)
	for pocket: Dictionary in Items.pockets():
		var id: String = pocket["id"]
		var count := _pocket_items(id).size()
		if count == 0 and id not in ["pokeballs", "curacion", "bayas", "fabricacion"]:
			continue
		var button := Button.new()
		button.icon = UiIcons.pocket(id)
		button.expand_icon = true
		button.custom_minimum_size = Vector2(64, 56)
		button.tooltip_text = "%s (%d)" % [pocket["name"], count]
		MenuStyle.style_button(button, id == _pocket)
		button.pressed.connect(func() -> void:
			_pocket = id
			_selected = ""
			_message = ""
			_menu.show_tab(_menu.tab))
		pockets.add_child(button)
	var pocket_name := ""
	for pocket: Dictionary in Items.pockets():
		if pocket["id"] == _pocket:
			pocket_name = pocket["name"]
	var chip := UiKit.label("  " + pocket_name, 22, UiKit.MINT, true)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pockets.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	# Lista.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 560
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	# Derecha: equipo y ficha.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)
	if not GameState.party.is_empty():
		var party := _menu.party_row(func(i: int) -> void:
			if _menu.main != null and _menu.main.has_method("swap_companion") and i != GameState.companion_index:
				_menu.main.swap_companion(i)
			_menu.show_tab(_menu.tab), GameState.companion_index)
		right.add_child(party)
		right.add_child(UiKit.label("Los objetos se usan en tu acompañante (marcado). Toca otro para cambiarlo.", 15, UiKit.MUTED))
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 0)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail)
	if _pocket == "fabricacion":
		_recipes(list, detail)
		return root
	var ids := _pocket_items(_pocket)
	if ids.is_empty():
		list.add_child(UiKit.label("Este bolsillo está vacío.", 20, UiKit.MUTED))
	# Si el objeto elegido se acabó (o es de otro bolsillo), su detalle desaparece.
	if not ids.has(_selected):
		_selected = ""
	if _selected == "" and not ids.is_empty():
		_selected = GameState.selected_ball if ids.has(GameState.selected_ball) else ids[0]
	for id in ids:
		var button := Button.new()
		button.icon = Items.icon(id)
		button.text = "  %s" % Items.display_name(id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", UiKit.font(true))
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_constant_override("icon_max_width", 40)
		button.custom_minimum_size.y = 56
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		MenuStyle.style_button(button, id == _selected)
		var count := UiKit.label("× %d" % GameState.item_count(id), 19, UiKit.INK if id == _selected else UiKit.WHITE, true)
		count.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		count.offset_left = -80
		count.offset_right = -14
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_child(count)
		button.pressed.connect(func() -> void:
			_selected = id
			_message = ""
			_menu.show_tab(_menu.tab))
		list.add_child(button)
	if _selected != "":
		_item_detail(detail, _selected)
	return root


func _pocket_items(pocket: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in GameState.bag:
		if GameState.item_count(id) > 0 and Items.get_item(id).get("pocket", "") == pocket:
			result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool: return Items.display_name(a) < Items.display_name(b))
	return result


func _card(box: VBoxContainer, icon: Texture2D, title: String, tag: String) -> VBoxContainer:
	var header := PanelContainer.new()
	var header_style := UiKit.card_style(10)
	header_style.corner_radius_bottom_left = 0
	header_style.corner_radius_bottom_right = 0
	header.add_theme_stylebox_override("panel", header_style)
	box.add_child(header)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	header.add_child(head)
	head.add_child(UiKit.icon_rect(icon, Vector2(40, 40)))
	var name := UiKit.label(title, 26, UiKit.INK, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	if tag != "":
		head.add_child(UiKit.label(tag, 18, Color(0.3, 0.4, 0.65), true))
	var body := PanelContainer.new()
	var body_style := UiKit.panel_style(true, 10)
	body_style.corner_radius_top_left = 0
	body_style.corner_radius_top_right = 0
	body.add_theme_stylebox_override("panel", body_style)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	body.add_child(content)
	return content


func _item_detail(box: VBoxContainer, id: String) -> void:
	var item := Items.get_item(id)
	var content := _card(box, Items.icon(id), item.get("name", id), "Tienes %d" % GameState.item_count(id))
	content.add_child(UiKit.wrapped(item.get("desc", ""), 21))
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 40)
	content.add_child(facts)
	if int(item.get("price", 0)) > 0:
		facts.add_child(_fact("Precio", "$%d" % int(item["price"])))
	if item.has("ball"):
		facts.add_child(_fact("Captura", "×%.1f" % float(item["ball"].get("rate", 1.0))))
	if item.has("tm"):
		facts.add_child(_fact("Tipo", MenuStyle.TYPE_NAMES[int(item["tm"])]))
	if id == GameState.selected_ball:
		content.add_child(UiKit.label("★ Es la ball que lanzas", 19, UiKit.GOLD, true))
	var label := ItemEffects.action_label(id)
	if label != "":
		var use := UiKit.slant_button(label, UiKit.MINT, 22)
		use.custom_minimum_size = Vector2(320, 54)
		use.pressed.connect(func() -> void:
			var result := ItemEffects.use(id, _menu.main)
			if result == "map":
				_menu.show_tab(GameMenu.TABS.find("Mapa"))
				return
			_message = result
			_menu.show_tab(_menu.tab))
		content.add_child(use)
		# Rueda rápida: agregar o quitar este objeto (hasta 6).
		var in_wheel := GameState.quick_items.has(id)
		var wheel := UiKit.slant_button("Quitar de la rueda rápida" if in_wheel else "Poner en la rueda rápida (T)", UiKit.GOLD, 20)
		wheel.custom_minimum_size = Vector2(320, 48)
		wheel.pressed.connect(func() -> void:
			if in_wheel:
				GameState.quick_items.erase(id)
				_message = "Quitaste %s de la rueda." % item.get("name", id)
			elif GameState.quick_items.size() >= GameState.QUICK_MAX:
				_message = "La rueda ya tiene %d objetos: quita uno primero." % GameState.QUICK_MAX
			else:
				GameState.quick_items.append(id)
				_message = "%s está en la rueda rápida (mantén T)." % item.get("name", id)
			_menu.show_tab(_menu.tab))
		content.add_child(wheel)
	if _message != "":
		content.add_child(UiKit.wrapped(_message, 20, UiKit.MINT))


func _fact(name: String, value: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(UiKit.label(name, 16, UiKit.MUTED, true))
	box.add_child(UiKit.label(value, 24, UiKit.WHITE, true))
	return box


func _recipes(list: VBoxContainer, box: VBoxContainer) -> void:
	for recipe: Dictionary in Items.recipes():
		var needs := PackedStringArray()
		for id: String in recipe["needs"]:
			needs.append("%s %d/%d" % [Items.display_name(id), GameState.item_count(id), int(recipe["needs"][id])])
		var button := Button.new()
		button.icon = Items.icon(recipe["result"])
		button.text = "  %d × %s\n  %s" % [int(recipe["amount"]), Items.display_name(recipe["result"]), ", ".join(needs)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 17)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		MenuStyle.style_button(button, ItemEffects.can_craft(recipe))
		button.pressed.connect(func() -> void:
			_message = ItemEffects.craft(recipe)
			_menu.show_tab(_menu.tab))
		list.add_child(button)
	var content := _card(box, UiIcons.pocket("fabricacion"), "Fabricación", "")
	content.add_child(UiKit.wrapped("Junta bonguris, setas, minerales, bayas y Fragmentos Místicos en el mundo y fabrica Pokéballs, pociones, señuelos y MT. Las recetas marcadas ya tienen todos sus materiales.", 20))
	if _message != "":
		content.add_child(UiKit.wrapped(_message, 20, UiKit.MINT))
