class_name QuickWheel
extends CanvasLayer
## Rueda rápida de objetos (decisión de Fernando, 2026-10-10): mantener T (o la cruceta →
## en el mando; tocada sigue siendo zoom) abre una rueda con hasta 6 objetos favoritos que
## se eligen en la Mochila. Se apunta con el mouse o el stick y al soltar se usa el objeto.

const HOLD_SECONDS := 0.25
const RADIUS := 150.0
const SLOT := 92.0

var main: Node
var _held := 0.0
var _open := false
var _aim := Vector2.ZERO
var _selected := -1
var _root: Control
var _slots: Array[Control] = []
var _title: Label


func _ready() -> void:
	layer = 24
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)


func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	var holding := Input.is_action_pressed("quick_items")
	if holding and (_open or not DialogBox.blocking):
		_held += delta
		if not _open and _held >= HOLD_SECONDS:
			_show()
	elif _open:
		_use_selected()
		_hide()
	else:
		_held = 0.0
	if _open:
		# Stick o teclas de movimiento para apuntar (el jugador queda quieto mientras tanto).
		var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if stick.length() > 0.4:
			_aim = stick * RADIUS
		_update_selection()


func _input(event: InputEvent) -> void:
	if _open and event is InputEventMouseMotion:
		_aim = (_aim + (event as InputEventMouseMotion).relative).limit_length(RADIUS * 1.2)
		get_viewport().set_input_as_handled()


func _show() -> void:
	_open = true
	_aim = Vector2.ZERO
	_selected = -1
	DialogBox.blocking = true
	for child in _root.get_children():
		child.queue_free()
	_slots.clear()
	var center := _root.get_viewport_rect().size * 0.5
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.05, 0.1, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var items := GameState.quick_items
	for i in GameState.QUICK_MAX:
		var angle := TAU * i / GameState.QUICK_MAX - PI * 0.5
		var slot := PanelContainer.new()
		var style := UiKit.card_style(46)
		style.bg_color = UiKit.CREAM
		slot.add_theme_stylebox_override("panel", style)
		slot.custom_minimum_size = Vector2(SLOT, SLOT)
		slot.size = Vector2(SLOT, SLOT)
		slot.position = center + Vector2.from_angle(angle) * RADIUS - Vector2(SLOT, SLOT) * 0.5
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(box)
		if i < items.size():
			var id := String(items[i])
			box.add_child(MenuStyle.texture_rect(Items.icon(id), Vector2(44, 44)))
			box.add_child(UiKit.label("×%d" % GameState.item_count(id), 16, UiKit.TEXT, true))
		else:
			box.add_child(UiKit.label("—", 22, UiKit.TEXT_SOFT, true))
		_root.add_child(slot)
		_slots.append(slot)
	_title = UiKit.label("Rueda rápida · apunta y suelta T", 24, UiKit.TEXT, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = center + Vector2(-260, RADIUS + SLOT * 0.5 + 12.0)
	_title.size = Vector2(520, 36)
	_root.add_child(_title)
	_root.visible = true
	if items.is_empty():
		_title.text = "Agrega objetos desde la Mochila"


func _update_selection() -> void:
	var previous := _selected
	_selected = -1
	if _aim.length() > 40.0:
		var angle := fposmod(_aim.angle() + PI * 0.5 + PI / GameState.QUICK_MAX, TAU)
		_selected = int(angle / TAU * GameState.QUICK_MAX) % GameState.QUICK_MAX
	if _selected == previous:
		return
	for i in _slots.size():
		_slots[i].scale = Vector2.ONE * (1.18 if i == _selected else 1.0)
		_slots[i].pivot_offset = Vector2(SLOT, SLOT) * 0.5
		_slots[i].modulate = Color(1.15, 1.1, 0.85) if i == _selected else Color.WHITE
	if _selected >= 0 and _selected < GameState.quick_items.size():
		var id := String(GameState.quick_items[_selected])
		_title.text = "%s · %s" % [Items.display_name(id), ItemEffects.action_label(id)]
	elif _title != null:
		_title.text = "Rueda rápida · apunta y suelta T"


func _use_selected() -> void:
	if _selected < 0 or _selected >= GameState.quick_items.size():
		return
	var id := String(GameState.quick_items[_selected])
	DialogBox.blocking = false
	var result := ItemEffects.use(id, main)
	if result != "" and result != "map":
		GameState.notice.emit(result)


func _hide() -> void:
	_open = false
	_held = 0.0
	DialogBox.blocking = false
	_root.visible = false
