class_name Hud
extends CanvasLayer
## HUD de exploración: corazones de vida (estilo Minecraft), burbujas de aire (en
## el agua), barra de stamina con rayo (solo si no está llena), tinte azul al bucear,
## pantalla negra al desmayarse, mira al apuntar, contador de Pokéballs, avisos,
## tarjeta del compañero (vida y si está fuera, guardado o debilitado), panel de
## recuperación mientras Nate está desmayado y ayudas de botones según el contexto.

const HEARTS := 10
const BUBBLES := 10
const ICON_SCALE := 3

@export var player_path: NodePath

## Escena principal (para leer al compañero y su estado).
var main: Node

@onready var _bar: ProgressBar = $Stamina/Bar
@onready var _panel: Control = $Stamina
@onready var _hearts_box: HBoxContainer = $Hearts
@onready var _bubbles_box: HBoxContainer = $Bubbles
@onready var _underwater: ColorRect = $Underwater
@onready var _blackout: ColorRect = $Blackout
@onready var _blackout_label: Label = $Blackout/Label
@onready var _reticle: TextureRect = $Reticle
@onready var _balls: Label = $Balls
@onready var _toast: Label = $Toast

var _player: Player
var _fill: StyleBoxFlat
var _heart_full: Texture2D
var _heart_half: Texture2D
var _heart_empty: Texture2D
var _bubble: Texture2D
var _world: WorldBuilder
var _companion_card: PanelContainer
var _companion_name: Label
var _companion_state: Label
var _companion_bar: ProgressBar
var _companion_fill: StyleBoxFlat
var _companion_hint: Label
var _downed_panel: PanelContainer
var _downed_title: Label
var _downed_bar: ProgressBar
var _downed_info: Label
var _downed_controls: Label
var _downed_tint: ColorRect
var _legend: VBoxContainer
var _legend_context := ""
var _tip: PanelContainer
var _tip_queue: Array = []
var _help: HelpOverlay
const TIP_SECONDS := 7.0
var _air_label: Label
var _time: float = 0.0


func _ready() -> void:
	_player = get_node(player_path) as Player
	_fill = _bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_bar.add_theme_stylebox_override("fill", _fill)
	_heart_full = _heart_texture(Color(0.9, 0.15, 0.2), 1.0)
	_heart_half = _heart_texture(Color(0.9, 0.15, 0.2), 0.5)
	_heart_empty = _heart_texture(Color(0.25, 0.1, 0.12), 1.0)
	_bubble = _bubble_texture()
	for i in HEARTS:
		_hearts_box.add_child(_icon(_heart_full))
	for i in BUBBLES:
		_bubbles_box.add_child(_icon(_bubble))
	_blackout.visible = false
	_reticle.texture = _reticle_texture()
	_reticle.visible = false
	_toast.visible = false
	GameState.pokemon_caught.connect(func(name: String, shiny: bool, location: String) -> void:
		show_toast("¡Atrapaste a %s%s! (va a tu %s)" % [name, " ✦" if shiny else "", location]))
	GameState.capture_failed.connect(func(name: String) -> void: show_toast("¡%s escapó de la Pokéball!" % name))
	_build_stamina_icon()
	_build_air_label()
	_build_companion_card()
	_build_downed_panel()
	_build_hints()
	_player.notice.connect(show_toast)


func _process(delta: float) -> void:
	if _player == null:
		return
	_time += delta
	var ratio := _player.stamina / _player.config.stamina_max
	_bar.value = ratio * 100.0
	_panel.visible = ratio < 0.999
	_fill.bg_color = Color(0.85, 0.25, 0.2) if _player.exhausted else Color(0.35, 0.8, 0.4)
	# Corazones: cada uno vale 2 de vida (medios corazones).
	var per_heart := _player.config.health_max / HEARTS
	for i in HEARTS:
		var heart_health := _player.health - i * per_heart
		var rect := _hearts_box.get_child(i) as TextureRect
		rect.texture = _heart_full if heart_health >= per_heart else (_heart_half if heart_health > 0.0 else _heart_empty)
	# Burbujas: en el agua o mientras le falte aire.
	var air_ratio := _player.air / _player.config.air_max
	var in_water := _player.mode == Player.Mode.SWIM or _player.mode == Player.Mode.DIVE
	_bubbles_box.visible = in_water or air_ratio < 0.999
	_air_label.visible = _bubbles_box.visible
	for i in BUBBLES:
		(_bubbles_box.get_child(i) as TextureRect).visible = air_ratio > float(i) / BUBBLES
	_reticle.visible = (_player.get_node("ThrowAim") as ThrowAim).is_aiming()
	_balls.text = "Pokéballs × %d" % GameState.pokeballs
	_update_companion_card()
	_update_downed_panel()
	_update_hints()
	# Tinte azul si la cámara está bajo el agua.
	if _world == null:
		_world = get_tree().get_first_node_in_group(WorldBuilder.WORLD_GROUP) as WorldBuilder
	var camera := get_viewport().get_camera_3d()
	_underwater.visible = camera != null and _world != null \
			and camera.global_position.y < _world.water_level_at(camera.global_position.x, camera.global_position.z)


## Pantalla negra de desmayo con el mensaje; dura seconds.
func show_blackout(message: String, seconds: float) -> void:
	_blackout_label.text = message
	_blackout.visible = true
	_blackout.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_blackout, "modulate:a", 1.0, 0.6)
	tween.tween_interval(seconds)
	tween.tween_property(_blackout, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: _blackout.visible = false)


## Mensaje breve arriba al centro.
func show_toast(message: String) -> void:
	_toast.text = message
	_toast.visible = true
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: _toast.visible = false)


func _reticle_texture() -> Texture2D:
	var rows := ["....W....", "....W....", ".........", ".........", "WW..K..WW", ".........", ".........", "....W....", "....W...."]
	var image := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 9:
			match rows[y][x]:
				"W":
					image.set_pixel(x, y, Color(1, 1, 1, 0.95))
				"K":
					image.set_pixel(x, y, Color(1, 0.3, 0.3, 1))
	return ImageTexture.create_from_image(image)


func _icon(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = Vector2(9, 9) * ICON_SCALE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	return rect


## Corazón pixel art de 9×9; fill = 0.5 deja vacía la mitad derecha (medio corazón).
func _heart_texture(color: Color, fill: float) -> Texture2D:
	var rows := [".XX...XX.", "XooX.XooX", "XoooXoooX", "XoooooooX", ".XoooooX.", "..XoooX..", "...XoX...", "....X....", "........."]
	var image := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 9:
			var c: String = rows[y][x]
			if c == "X":
				image.set_pixel(x, y, Color(0.08, 0.02, 0.03))
			elif c == "o":
				var filled := x < 4.5 or fill >= 1.0
				image.set_pixel(x, y, color if filled else Color(0.25, 0.1, 0.12))
	return ImageTexture.create_from_image(image)


func _bubble_texture() -> Texture2D:
	var rows := ["..XXXXX..", ".XoooooX.", "XoWoooooX", "XoWoooooX", "XoooooooX", "XoooooooX", ".XoooooX.", "..XXXXX..", "........."]
	var image := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 9:
			match rows[y][x]:
				"X":
					image.set_pixel(x, y, Color(0.1, 0.25, 0.5))
				"o":
					image.set_pixel(x, y, Color(0.45, 0.75, 1.0))
				"W":
					image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)


# --- Barras con ícono --------------------------------------------------------------

func _build_stamina_icon() -> void:
	var bolt := _icon(_pixel_texture(["...YY", "..YY.", ".YYYY", "...Y.", "..Y..", ".Y...", "Y...."], {"Y": Color(1.0, 0.85, 0.2)}))
	bolt.custom_minimum_size = Vector2(5, 7) * ICON_SCALE
	bolt.position = Vector2(-26, -4)
	_panel.add_child(bolt)


func _build_air_label() -> void:
	_air_label = _small_label("Aire", 18)
	_air_label.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
	_air_label.anchor_left = 0.5
	_air_label.anchor_right = 0.5
	_air_label.anchor_top = 1.0
	_air_label.anchor_bottom = 1.0
	_air_label.offset_left = -230
	_air_label.offset_right = -168
	_air_label.offset_top = -156
	_air_label.offset_bottom = -131
	_air_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_air_label)


# --- Tarjeta del compañero ----------------------------------------------------------

func _build_companion_card() -> void:
	_companion_card = PanelContainer.new()
	_companion_card.add_theme_stylebox_override("panel", _panel_style())
	_companion_card.anchor_top = 1.0
	_companion_card.anchor_bottom = 1.0
	_companion_card.offset_left = 24
	_companion_card.offset_top = -150
	_companion_card.offset_right = 344
	_companion_card.offset_bottom = -24
	add_child(_companion_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_companion_card.add_child(box)
	_companion_name = _small_label("", 24)
	box.add_child(_companion_name)
	_companion_bar = ProgressBar.new()
	_companion_bar.custom_minimum_size = Vector2(0, 16)
	_companion_bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.15, 0.15, 0.18)
	_companion_fill = StyleBoxFlat.new()
	_companion_fill.bg_color = Color(0.3, 0.85, 0.4)
	_companion_bar.add_theme_stylebox_override("background", background)
	_companion_bar.add_theme_stylebox_override("fill", _companion_fill)
	box.add_child(_companion_bar)
	_companion_state = _small_label("", 18)
	box.add_child(_companion_state)
	_companion_hint = _small_label("", 16)
	_companion_hint.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	box.add_child(_companion_hint)


func _update_companion_card() -> void:
	var companion := main.get("companion") as PokemonActor if main != null else null
	_companion_card.visible = companion != null
	if companion == null:
		return
	var state: int = main.get("companion_state")
	var ratio := companion.hp / companion.hp_max
	_companion_name.text = companion.species.display_name + (" ✦" if companion.shiny else "")
	_companion_bar.value = ratio * 100.0
	_companion_fill.bg_color = Color(0.3, 0.85, 0.4) if ratio > 0.5 else (Color(0.95, 0.8, 0.2) if ratio > 0.2 else Color(0.9, 0.25, 0.2))
	match state:
		0:
			_companion_state.text = "Bajo tu control" if companion.controlled else "Te acompaña"
			_companion_hint.text = "" if companion.controlled else InputHints.label("companion", "Guardar en su Pokéball")
			_companion_card.modulate = Color.WHITE
		1:
			_companion_state.text = "En su Pokéball"
			_companion_hint.text = InputHints.label("companion", "Sacarlo")
			_companion_card.modulate = Color(0.85, 0.85, 0.9)
		_:
			_companion_state.text = "Debilitado"
			_companion_hint.text = ""
			_companion_card.modulate = Color(1.0, 0.6, 0.6)


# --- Nate desmayado ----------------------------------------------------------------

func _build_downed_panel() -> void:
	_downed_tint = ColorRect.new()
	_downed_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_downed_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_downed_tint.color = Color(0.6, 0.05, 0.1, 0.0)
	add_child(_downed_tint)
	move_child(_downed_tint, 0)
	_downed_panel = PanelContainer.new()
	_downed_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.95, 0.45, 0.55)))
	_downed_panel.anchor_left = 0.5
	_downed_panel.anchor_right = 0.5
	_downed_panel.offset_left = -330
	_downed_panel.offset_right = 330
	_downed_panel.offset_top = 96
	_downed_panel.offset_bottom = 270
	add_child(_downed_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_downed_panel.add_child(box)
	_downed_title = _small_label("", 30)
	_downed_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_downed_title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.8))
	box.add_child(_downed_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(_icon(_heart_full))
	_downed_bar = ProgressBar.new()
	_downed_bar.custom_minimum_size = Vector2(0, 22)
	_downed_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_downed_bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.2, 0.08, 0.1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.35, 0.5)
	_downed_bar.add_theme_stylebox_override("background", background)
	_downed_bar.add_theme_stylebox_override("fill", fill)
	row.add_child(_downed_bar)
	_downed_info = _small_label("", 18)
	_downed_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_downed_info)
	_downed_controls = _small_label("", 18)
	_downed_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_downed_controls.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	box.add_child(_downed_controls)
	_downed_panel.visible = false


func _update_downed_panel() -> void:
	var down := _player.mode == Player.Mode.DOWNED
	_downed_panel.visible = down
	# Tinte rojo que late suave mientras está en el suelo.
	_downed_tint.color.a = (0.10 + 0.06 * sin(_time * 3.0)) if down else 0.0
	_hearts_box.modulate = Color(1.0, 0.75 + 0.25 * sin(_time * 6.0), 0.85) if down else Color.WHITE
	if not down:
		return
	var ratio := _player.health / _player.config.health_max
	var seconds := (_player.config.health_max - _player.health) / _player.config.health_max * _player.downed_duration()
	var companion := main.get("companion") as PokemonActor if main != null else null
	var name := companion.species.display_name if companion != null else "tu Pokémon"
	_downed_title.text = "¡%s está desmayad%s!" % [GameState.player_name, "a" if GameState.gender == "female" else "o"]
	_downed_bar.value = ratio * 100.0
	_downed_info.text = "Recuperándose... %d%%  ·  %d s  ·  ¡Protege a %s con %s!" % [int(ratio * 100.0), int(ceil(seconds)), GameState.player_name, name]
	_downed_controls.text = "%s   %s   %s" % [InputHints.label("attack_1", "Golpe"), InputHints.label("attack_2", "Ataque especial"), InputHints.label("dodge", "Esquivar")]


# --- Ayudas de botones -------------------------------------------------------------

func _build_hints() -> void:
	# Leyenda: filas [ícono] acción, abajo a la derecha, según el contexto.
	_legend = VBoxContainer.new()
	_legend.anchor_left = 1.0
	_legend.anchor_right = 1.0
	_legend.anchor_top = 1.0
	_legend.anchor_bottom = 1.0
	_legend.offset_left = -420
	_legend.offset_right = -24
	_legend.offset_top = -380
	_legend.offset_bottom = -70
	_legend.alignment = BoxContainer.ALIGNMENT_END
	_legend.add_theme_constant_override("separation", 6)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_legend)
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.85, 0.3)))
	_tip.position = Vector2(24, 24)
	_tip.custom_minimum_size = Vector2(430, 0)
	_tip.visible = false
	add_child(_tip)
	_help = HelpOverlay.new()
	add_child(_help)


func _update_hints() -> void:
	var rows: Array = []
	var aim := _player.get_node("ThrowAim") as ThrowAim
	var context := ""
	match _player.mode:
		Player.Mode.WALK:
			if aim.is_aiming():
				context = "aim%s" % aim.locked
				rows = [["throw", "Lanzar Pokéball"], ["aim", "Dejar de apuntar" if aim.locked else "Suelta para dejar de apuntar"], [null, "Mueve la cámara para subir o bajar la mira"]]
			else:
				context = "walk"
				rows = [["aim", "Apuntar (toca para fijar)"], ["jump", "Saltar"], ["run", "Correr"], ["companion", "Guardar o sacar a tu Pokémon"], ["map", "Mapa"], ["help", "Ayuda: todos los controles"]]
		Player.Mode.SWIM:
			context = "surf" if _player.riding != null else "swim"
			rows = [[null, "Surfeando sobre tu Pokémon"], ["help", "Ayuda"]] if _player.riding != null \
					else [["jump", "Mantener: flotar"], ["dive", "Bucear"], ["help", "Ayuda"]]
		Player.Mode.DIVE:
			context = "dive"
			rows = [["jump", "Mantener: subir"], [null, "Suelta para hundirte"], ["help", "Ayuda"]]
	context += str(InputHints.gamepad)
	if context == _legend_context:
		return
	_legend_context = context
	for child in _legend.get_children():
		child.queue_free()
	for entry: Array in rows:
		if entry[0] == null:
			var note := _small_label(entry[1], 17)
			note.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_legend.add_child(note)
		else:
			var row := InputGlyph.row(entry[0], entry[1], 19)
			row.alignment = BoxContainer.ALIGNMENT_END
			_legend.add_child(row)
	_update_tips()


## Tarjetas de tutorial: la primera vez que algo es posible, una tarjeta muestra qué
## botón pulsar (una sola vez por partida; se guardan en GameState.tips_seen).
func show_tip(id: String, title: String, rows: Array) -> void:
	if GameState.tips_seen.get(id, false):
		return
	GameState.tips_seen[id] = true
	_tip_queue.append([title, rows])
	if not _tip.visible:
		_next_tip()


func _next_tip() -> void:
	if _tip_queue.is_empty():
		_tip.visible = false
		return
	var data: Array = _tip_queue.pop_front()
	for child in _tip.get_children():
		child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_tip.add_child(box)
	var title := _small_label(data[0], 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	box.add_child(title)
	for entry: Array in data[1]:
		var glyph: Variant = entry[0]
		if glyph == null:
			var note := _small_label(entry[1], 17)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size.x = 400
			box.add_child(note)
			continue
		if glyph is String and String(glyph).begins_with("@"):
			glyph = InputGlyph.text(String(glyph).substr(1), not InputHints.gamepad)
		box.add_child(InputGlyph.row(glyph, entry[1], 19))
	_tip.visible = true
	_tip.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_tip, "modulate:a", 1.0, 0.3)
	tween.tween_interval(TIP_SECONDS)
	tween.tween_property(_tip, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_next_tip)


func _update_tips() -> void:
	if _player.mode == Player.Mode.WALK:
		show_tip("moverse", "¡Bienvenido! Así te mueves", [["@" + ("Stick izq." if InputHints.gamepad else "WASD"), "Caminar"], ["@" + ("Stick der." if InputHints.gamepad else "Mouse"), "Mover la cámara"], ["run", "Correr"], ["jump", "Saltar"], ["help", "Ver todos los controles"]])
	if _player.mode == Player.Mode.SWIM or _player.mode == Player.Mode.DIVE:
		if _player.riding != null:
			show_tip("surf", "¡Surfeas sobre tu Pokémon!", [[null, "Tu compañero de tipo Agua te lleva por el agua."]])
		else:
			show_tip("nadar", "Nadar y bucear", [["jump", "Mantener para flotar o subir"], ["dive", "Bucear más rápido"], [null, "Si no mantienes, te hundes poco a poco. Cuida tu aire."]])
	var aim := _player.get_node("ThrowAim") as ThrowAim
	if aim.is_aiming():
		show_tip("lanzar", "Lanzar una Pokéball", [["throw", "Lanzar"], ["aim", "Toca para fijar o soltar la mira"], [null, "Mueve la cámara para lanzar lejos o hacia arriba."]])


# --- Utilidades --------------------------------------------------------------------

func _small_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel_style(border: Color = Color(0.95, 0.95, 0.9)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.85)
	style.set_border_width_all(3)
	style.border_color = border
	style.set_content_margin_all(12)
	return style


func _pixel_texture(rows: Array, palette: Dictionary) -> Texture2D:
	var width: int = (rows[0] as String).length()
	var image := Image.create_empty(width, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in width:
			var c: String = rows[y][x]
			if palette.has(c):
				image.set_pixel(x, y, palette[c])
	return ImageTexture.create_from_image(image)
