class_name CompanionWheel
extends Control
## Rueda de cambio rápido de acompañante: al mantener Q / △ aparece el equipo en
## círculo, el tiempo pasa más lento y se elige con el mouse o el stick; al soltar,
## ese Pokémon pasa a ser el acompañante.

signal chosen(index: int)

const RADIUS := 210.0
const SLOW_TIME := 0.25

var _selected := -1
var _slots: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	for child in get_children():
		child.queue_free()
	_slots.clear()
	_selected = GameState.companion_index
	var center := get_viewport_rect().size * 0.5
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var count := GameState.party.size()
	for i in count:
		var entry: Dictionary = GameState.party[i]
		var species := MenuStyle.species(entry["species"])
		var angle := -PI * 0.5 + TAU * i / maxf(count, 1)
		var slot := MenuStyle.panel_container(MenuStyle.ACCENT if i == GameState.companion_index else Color(0.6, 0.65, 0.75))
		var box := VBoxContainer.new()
		slot.add_child(box)
		box.add_child(MenuStyle.texture_rect(MenuStyle.front_sprite(species, entry.get("shiny", false)), Vector2(96, 96)))
		box.add_child(MenuStyle.label(species.display_name, 18))
		box.add_child(MenuStyle.bar(float(entry.get("hp_ratio", 1.0)), 96, Color(0.3, 0.85, 0.4), 6))
		add_child(slot)
		slot.position = center + Vector2(cos(angle), sin(angle)) * RADIUS - Vector2(62, 80)
		_slots.append(slot)
	var hint := MenuStyle.label("Elige con el mouse o el stick y suelta %s" % InputHints.hint("companion"), 22, MenuStyle.ACCENT)
	add_child(hint)
	hint.position = center + Vector2(-260, RADIUS + 110)
	visible = true
	Engine.time_scale = SLOW_TIME
	_highlight()


func close() -> int:
	visible = false
	Engine.time_scale = 1.0
	return _selected


func _process(_delta: float) -> void:
	if not visible or _slots.is_empty():
		return
	var direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if direction.length() < 0.4:
		direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if direction.length() < 0.4 and not InputHints.gamepad:
		direction = (get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5) / RADIUS
	if direction.length() < 0.4:
		return
	var angle := fposmod(direction.angle() + PI * 0.5, TAU)
	var index := int(round(angle / (TAU / _slots.size()))) % _slots.size()
	if index != _selected:
		_selected = index
		_highlight()


func _highlight() -> void:
	for i in _slots.size():
		_slots[i].scale = Vector2.ONE * (1.2 if i == _selected else 1.0)
		_slots[i].modulate = Color.WHITE if i == _selected else Color(0.7, 0.7, 0.75)
