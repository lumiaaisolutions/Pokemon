class_name BattleUI
extends CanvasLayer
## Interfaz del combate en arena: arriba la tarjeta del rival (nombre, tipos y vida);
## abajo a la izquierda tu Pokémon (retrato, vida y megaevolución) y a la derecha sus 4
## movimientos con tipo y recarga; una fila de ayudas con los botones.

var battle: BattleManager
var _root: Control
var _enemy_name: Label
var _enemy_types: HBoxContainer
var _enemy_bar: ProgressBar
var _own_name: Label
var _own_bar: ProgressBar
var _own_portrait: TextureRect
var _moves: Array[Dictionary] = []
var _hints: Label
var _mega: Label
var _charge: ProgressBar
var _charge_box: VBoxContainer


func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# Rival, arriba al centro.
	var enemy := _card(Color(0.95, 0.4, 0.35))
	enemy.anchor_left = 0.5
	enemy.anchor_right = 0.5
	enemy.offset_left = -240
	enemy.offset_right = 240
	enemy.offset_top = 18
	_root.add_child(enemy)
	var enemy_box := VBoxContainer.new()
	enemy.add_child(enemy_box)
	var row := HBoxContainer.new()
	enemy_box.add_child(row)
	_enemy_name = MenuStyle.label("", 24, Color.WHITE)
	_enemy_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_enemy_name)
	_enemy_types = HBoxContainer.new()
	row.add_child(_enemy_types)
	_enemy_bar = _bar()
	enemy_box.add_child(_enemy_bar)
	# Tu Pokémon, abajo a la izquierda.
	var own := _card(Color(0.4, 0.7, 1.0))
	own.anchor_top = 1.0
	own.anchor_bottom = 1.0
	own.offset_left = 24
	own.offset_right = 384
	own.offset_top = -150
	own.offset_bottom = -24
	_root.add_child(own)
	var own_row := HBoxContainer.new()
	own_row.add_theme_constant_override("separation", 12)
	own.add_child(own_row)
	_own_portrait = TextureRect.new()
	_own_portrait.custom_minimum_size = Vector2(88, 88)
	_own_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_own_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_own_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	own_row.add_child(_own_portrait)
	var own_box := VBoxContainer.new()
	own_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	own_row.add_child(own_box)
	_own_name = MenuStyle.label("", 22, Color.WHITE)
	own_box.add_child(_own_name)
	_own_bar = _bar()
	own_box.add_child(_own_bar)
	_mega = MenuStyle.label("", 16, Color(1.0, 0.7, 1.0))
	own_box.add_child(_mega)
	# Movimientos, abajo a la derecha.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.anchor_left = 1.0
	grid.anchor_right = 1.0
	grid.anchor_top = 1.0
	grid.anchor_bottom = 1.0
	grid.offset_left = -560
	grid.offset_right = -24
	grid.offset_top = -170
	grid.offset_bottom = -60
	_root.add_child(grid)
	for slot in 4:
		var panel := _card(Color(0.6, 0.6, 0.7))
		panel.custom_minimum_size = Vector2(260, 48)
		grid.add_child(panel)
		var line := HBoxContainer.new()
		panel.add_child(line)
		var key := MenuStyle.label("", 16, MenuStyle.ACCENT)
		line.add_child(key)
		var name := MenuStyle.label("", 18, Color.WHITE)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name)
		var cooldown := MenuStyle.label("", 16, MenuStyle.MUTED)
		line.add_child(cooldown)
		_moves.append({"panel": panel, "key": key, "name": name, "cooldown": cooldown})
	# Sobre el mundo (sin panel): texto claro con contorno.
	_hints = UiKit.label_on_dark("", 16, Color(0.95, 0.96, 1.0))
	_hints.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12))
	_hints.add_theme_constant_override("outline_size", 5)
	_hints.anchor_left = 0.0
	_hints.anchor_right = 1.0
	_hints.anchor_top = 1.0
	_hints.anchor_bottom = 1.0
	_hints.offset_top = -40
	_hints.offset_bottom = -12
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hints)
	# Potencia del lanzamiento (Fase 4): barra con la zona excelente marcada.
	_charge_box = VBoxContainer.new()
	_charge_box.anchor_left = 0.5
	_charge_box.anchor_right = 0.5
	_charge_box.anchor_top = 1.0
	_charge_box.anchor_bottom = 1.0
	_charge_box.offset_left = -220
	_charge_box.offset_right = 220
	_charge_box.offset_top = -170
	_charge_box.offset_bottom = -110
	_charge_box.visible = false
	_root.add_child(_charge_box)
	var charge_label := UiKit.label_on_dark("POTENCIA", 18, Color(1.0, 0.95, 0.7))
	charge_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12))
	charge_label.add_theme_constant_override("outline_size", 5)
	charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charge_box.add_child(charge_label)
	_charge = _bar()
	_charge.custom_minimum_size = Vector2(440, 20)
	_charge_box.add_child(_charge)
	var zone := ColorRect.new()
	zone.color = Color(1.0, 0.85, 0.3, 0.45)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.anchor_left = ThrowAim.EXCELLENT
	zone.anchor_right = 1.0
	zone.anchor_bottom = 1.0
	_charge.add_child(zone)


func _card(border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.16, 0.88)
	if UiKit.light:
		style.bg_color = Color(UiKit.CREAM.r, UiKit.CREAM.g, UiKit.CREAM.b, 0.95)
		style.shadow_color = Color(0, 0, 0, 0.25)
		style.shadow_size = 6
	style.border_color = border
	style.set_border_width_all(2)
	style.border_width_left = 6
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.15) if UiKit.light else Color(0.15, 0.15, 0.2)
	background.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.85, 0.4)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _set_bar(bar: ProgressBar, ratio: float) -> void:
	bar.value = ratio * 100.0
	(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.3, 0.85, 0.4) if ratio > 0.5 else (Color(0.95, 0.8, 0.2) if ratio > 0.2 else Color(0.9, 0.25, 0.2))


## Datos que cambian al empezar o al cambiar de Pokémon.
func setup(manager: BattleManager) -> void:
	battle = manager
	if battle.opponent == null:
		return
	var enemy := battle.opponent
	_enemy_name.text = "%s%s salvaje" % [enemy.species.display_name, " ✦" if enemy.shiny else ""]
	for child in _enemy_types.get_children():
		child.queue_free()
	for type in enemy.species.types:
		_enemy_types.add_child(MenuStyle.type_pill(type))
	var own := battle.companion()
	if own != null:
		_own_name.text = own.species.display_name
		_own_portrait.texture = MenuStyle.front_sprite(own.species, own.shiny)
		for slot in 4:
			var move: Dictionary = _moves[slot]
			if slot < own.moves.size():
				var id := own.moves[slot]
				var data := Moves.get_move(id)
				(move["key"] as Label).text = InputHints.hint("attack_%d" % (slot + 1)) + "  "
				(move["name"] as Label).text = data["name"]
				var style := (move["panel"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
				style.border_color = AttackProjectile.TYPE_COLORS.get(int(data["type"]), Color.GRAY)
				move["id"] = id
				(move["panel"] as Control).visible = true
			else:
				(move["panel"] as Control).visible = false
	refresh()


func refresh() -> void:
	if battle == null or battle.opponent == null or not is_instance_valid(battle.opponent):
		return
	var aim := battle.player().get_node_or_null("ThrowAim") as ThrowAim if battle.player() != null else null
	_charge_box.visible = aim != null and aim.charging
	if _charge_box.visible:
		_charge.value = aim.charge * 100.0
		(_charge.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(1.0, 0.85, 0.3) if aim.charge >= ThrowAim.EXCELLENT else Color(0.5, 0.75, 1.0)
	_set_bar(_enemy_bar, battle.opponent.hp / battle.opponent.hp_max)
	var own := battle.companion()
	if own != null:
		_set_bar(_own_bar, own.hp / own.hp_max)
		for move: Dictionary in _moves:
			if move.has("id"):
				var left := own.move_cooldown_left(move["id"])
				(move["cooldown"] as Label).text = "%.1f s" % left if left > 0.0 else "Listo"
	var mega := battle.available_mega()
	_mega.text = ("✦ Megaevolución lista (%s)" % InputHints.hint("mega_evolve")) if mega != null else ("✦ Megaevolucionado" if battle.mega_used else "")
	if aim != null and aim.is_aiming():
		_hints.text = "Mantén %s y suelta en la zona dorada: lanzamiento excelente   ·   %s Esquivar (Nate)   ·   Suelta %s para volver a tu Pokémon" % [
				InputHints.hint("throw"), InputHints.hint("dodge"), InputHints.hint("aim")]
	else:
		_hints.text = "%s Mover   ·   %s Esquivar   ·   %s Fijar objetivo   ·   %s Apuntar Pokéball   ·   Mantén %s Cambiar   ·   %s Mochila   ·   Sal del círculo para huir" % [
				InputHints.hint("move_forward"), InputHints.hint("dodge"), InputHints.hint("lock_on"), InputHints.hint("aim"), InputHints.hint("companion"), InputHints.hint("bag")]
