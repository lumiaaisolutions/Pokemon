class_name ShelfPopupUI
extends Control
## Ventanita de un estante de la Tienda Pokémon (pedido de Fernando, 2026-10-10: "al
## acercarte dice qué es y su precio y lo compras ahí"): ícono, nombre, descripción,
## precio del día y existencias de hoy, con botones en píldora (ícono + texto, color por
## acción, se agrandan y brillan al pasar, con sonido). Pausa el juego mientras está abierta.

var item_id := ""
var price := 0
var left_today := -1
## (amount: int) -> bool; compra amount unidades. Si devuelve false, no alcanzó o no quedan.
var on_buy: Callable = Callable()

var _info: Label


func open() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := MenuStyle.panel_container(Color(0.4, 0.6, 1.0))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(440, 300)
	panel.position = -panel.custom_minimum_size * 0.5
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	header.add_child(MenuStyle.texture_rect(Items.icon(item_id), Vector2(48, 48)))
	var title_box := VBoxContainer.new()
	header.add_child(title_box)
	title_box.add_child(MenuStyle.label(Items.display_name(item_id), 24, MenuStyle.ACCENT))
	title_box.add_child(MenuStyle.label("$%d%s" % [price, "  ·  quedan %d hoy" % left_today if left_today >= 0 else ""], 18))
	_info = MenuStyle.label(str(Items.get_item(item_id).get("desc", "")), 16, MenuStyle.MUTED)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var sold_out := left_today == 0
	var buy1 := UiKit.pill_button("Comprar ×1  $%d" % price, Items.icon(item_id), UiKit.ACTION_BUY)
	buy1.disabled = sold_out
	buy1.pressed.connect(_try_buy.bind(1))
	row.add_child(buy1)
	if left_today < 0 or left_today >= 5:
		var buy5 := UiKit.pill_button("Comprar ×5  $%d" % (price * 5), Items.icon(item_id), UiKit.ACTION_BUY)
		buy5.pressed.connect(_try_buy.bind(5))
		row.add_child(buy5)
	var close := UiKit.pill_button("Cerrar", null, UiKit.ACTION_INFO)
	close.pressed.connect(_close)
	row.add_child(close)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	buy1.grab_focus.call_deferred()


func _try_buy(amount: int) -> void:
	if not on_buy.is_valid() or not on_buy.call(amount):
		GameState.notice.emit("No se pudo comprar (sin dinero o sin existencias).")
		return
	_close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	get_tree().paused = false
	queue_free()
