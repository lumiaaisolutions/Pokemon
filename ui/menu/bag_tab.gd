class_name BagTab
extends RefCounted
## Pestaña Mochila: bolsillos a la izquierda, objetos del bolsillo en el centro y a la
## derecha la descripción con su acción (elegir ball, curar, comer, usar…). El
## bolsillo Fabricación muestra las recetas.

var _menu: GameMenu
var _pocket := "pokeballs"
var _selected := ""
var _message := ""


func _init(menu: GameMenu) -> void:
	_menu = menu


func build() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	# Bolsillos.
	var pockets := VBoxContainer.new()
	pockets.add_theme_constant_override("separation", 4)
	row.add_child(pockets)
	for pocket: Dictionary in Items.pockets():
		var count := _pocket_items(pocket["id"]).size()
		var button := MenuStyle.button("%s (%d)" % [pocket["name"], count] if pocket["id"] != "fabricacion" else pocket["name"], 18)
		button.custom_minimum_size.x = 270
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		MenuStyle.style_button(button, pocket["id"] == _pocket)
		button.pressed.connect(func() -> void:
			_pocket = pocket["id"]
			_selected = ""
			_message = ""
			_menu.show_tab(_menu.tab))
		pockets.add_child(button)
	# Lista.
	var list_panel := MenuStyle.panel_container()
	list_panel.custom_minimum_size.x = 560
	row.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(530, 640)
	list_panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	# Detalle.
	var detail := MenuStyle.panel_container(MenuStyle.ACCENT)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 12)
	detail.add_child(detail_box)
	if _pocket == "fabricacion":
		_recipes(list, detail_box)
		return row
	var ids := _pocket_items(_pocket)
	if ids.is_empty():
		list.add_child(MenuStyle.label("Este bolsillo está vacío.", 20, MenuStyle.MUTED))
	for id in ids:
		var button := Button.new()
		button.icon = Items.icon(id)
		button.text = "  %s   × %d" % [Items.display_name(id), GameState.item_count(id)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 20)
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		MenuStyle.style_button(button, id == _selected or (id == GameState.selected_ball and _selected == ""))
		button.pressed.connect(func() -> void:
			_selected = id
			_message = ""
			_menu.show_tab(_menu.tab))
		list.add_child(button)
	if _selected == "" and not ids.is_empty():
		_selected = GameState.selected_ball if ids.has(GameState.selected_ball) else ids[0]
	if _selected != "":
		_item_detail(detail_box, _selected)
	return row


func _pocket_items(pocket: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in GameState.bag:
		if GameState.item_count(id) > 0 and Items.get_item(id).get("pocket", "") == pocket:
			result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool: return Items.display_name(a) < Items.display_name(b))
	return result


func _item_detail(box: VBoxContainer, id: String) -> void:
	var item := Items.get_item(id)
	box.add_child(MenuStyle.texture_rect(Items.icon(id), Vector2(96, 96)))
	box.add_child(MenuStyle.label(item.get("name", id), 28, MenuStyle.ACCENT))
	box.add_child(MenuStyle.label("Tienes %d" % GameState.item_count(id), 18, MenuStyle.MUTED))
	box.add_child(MenuStyle.wrapped(item.get("desc", ""), 20))
	if item.has("sell"):
		box.add_child(MenuStyle.label("Se vende en las tiendas por $%d" % int(item["sell"]), 18, MenuStyle.MUTED))
	if id == GameState.selected_ball:
		box.add_child(MenuStyle.label("★ Es la ball que lanzas", 18, MenuStyle.ACCENT))
	var label := ItemEffects.action_label(id)
	if label != "":
		var use := MenuStyle.button(label, 22)
		use.pressed.connect(func() -> void:
			var result := ItemEffects.use(id, _menu.main)
			if result == "map":
				_menu.show_tab(GameMenu.TABS.find("Mapa"))
				return
			_message = result
			_menu.refresh_strip()
			_menu.show_tab(_menu.tab))
		box.add_child(use)
	if _message != "":
		box.add_child(MenuStyle.wrapped(_message, 20, Color(0.6, 1.0, 0.7)))


func _recipes(list: VBoxContainer, box: VBoxContainer) -> void:
	list.add_child(MenuStyle.label("Recetas", 24, MenuStyle.ACCENT))
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
	box.add_child(MenuStyle.label("Fabricación", 28, MenuStyle.ACCENT))
	box.add_child(MenuStyle.wrapped("Junta bonguris, setas, minerales y bayas en el mundo y fabrica Pokéballs, pociones y señuelos. Las recetas en amarillo ya tienen todos sus materiales.", 20))
	if _message != "":
		box.add_child(MenuStyle.wrapped(_message, 20, Color(0.6, 1.0, 0.7)))
