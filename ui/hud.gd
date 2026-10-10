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
var _companion_portrait: TextureRect
var _companion_species := ""
var _downed_panel: PanelContainer
var _downed_title: Label
var _downed_bar: ProgressBar
var _downed_info: Label
var _downed_controls: Label
var _downed_tint: ColorRect
var _legend: VBoxContainer
var _legend_tab: Button
var _ball_panel: PanelContainer
var _clock: Label
var _prompt: Label
var _ball_key := ""
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
	# Estilo del kit (UiKit): fuente del sistema y avisos en píldoras azul marino.
	for label: Label in [_toast, _balls, _blackout_label]:
		label.add_theme_font_override("font", UiKit.font(true))
		label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.14))
		label.add_theme_constant_override("outline_size", 4)
	_pill(_toast, UiKit.MINT)
	cards = NoticeCards.new()
	cards.name = "Cards"
	_root_control().add_child(cards)
	dialog = DialogBox.new()
	dialog.name = "Dialog"
	_root_control().add_child(dialog)
	missions = MissionPanel.new()
	missions.name = "Missions"
	_root_control().add_child(missions)
	GameState.pokemon_caught.connect(func(name: String, shiny: bool, location: String) -> void:
		show_toast("¡Atrapaste a %s%s! (va a tu %s)" % [name, " ✦" if shiny else "", location]))
	GameState.capture_failed.connect(func(name: String) -> void: show_toast("¡%s escapó de la Pokéball!" % name))
	_build_stamina_icon()
	_build_air_label()
	_build_companion_card()
	_build_downed_panel()
	_build_hints()
	_build_ball_panel()
	_build_clock()
	_prompt = _small_label("", 24)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.offset_top = -200
	_prompt.offset_bottom = -168
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_pill(_prompt, UiKit.GOLD)
	_prompt.visible = false
	add_child(_prompt)
	var gathering := get_node_or_null("../Gathering") as GatherManager
	if gathering != null:
		gathering.prompt_changed.connect(_set_prompt)
	_player.notice.connect(show_toast)
	GameState.notice.connect(show_toast)
	_build_location_banner()


## Estilo claro: los textos dentro de paneles y píldoras del HUD pasan a tinta oscura
## (se revisa cada medio segundo; los que flotan sobre el mundo se quedan claros).
var _ink_timer := 0.0


func _ink_panels() -> void:
	if not UiKit.light:
		return
	var roots: Array[Control] = [_companion_card, _ball_panel, _tip, _downed_panel, _prompt, _location, _clock]
	for root in roots:
		if root == null:
			continue
		var labels: Array = root.find_children("*", "Label", true, false)
		if root is Label:
			labels.append(root)
		for node in labels:
			var label := node as Label
			var current := label.get_theme_color("font_color")
			if label.has_meta("inked") and label.get_meta("inked") == current:
				continue
			var inked := UiKit.ink(current)
			label.add_theme_color_override("font_color", inked)
			label.add_theme_constant_override("outline_size", 0)
			label.set_meta("inked", inked)


func _process(delta: float) -> void:
	if missions != null:
		missions.set_top(_tip.position.y + _tip.size.y + 14.0 if _tip.visible else 24.0)
	_ink_timer -= delta
	if _ink_timer <= 0.0:
		_ink_timer = 0.5
		_ink_panels()
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
	_update_ball_panel()
	_clock.text = "%s Día %d · %s\n%s · %s" % ["☾" if GameState.is_night() else "☀", GameState.game_day() + 1, DayNight.clock_text(GameState.clock_hour()),
			Weather.NAMES[Weather.current], Weather.season_name(GameState.game_day())]
	_update_companion_card()
	_update_downed_panel()
	_update_hints()
	# Tinte azul si la cámara está bajo el agua.
	if _world == null:
		_world = get_tree().get_first_node_in_group(WorldBuilder.WORLD_GROUP) as WorldBuilder
		if _world != null and _world.structures != null:
			_world.structures.prompt_changed.connect(_set_prompt)
	_update_location(delta)
	var camera := get_viewport().get_camera_3d()
	_underwater.visible = camera != null and _world != null \
			and camera.global_position.y < _world.water_level_at(camera.global_position.x, camera.global_position.z)


var _location: Label
var _location_name := ""
var _location_timer := 0.0
var _location_show := 0.0


## Cartel con el nombre del lugar (pueblo, lugar especial o bioma) al llegar.
func _build_location_banner() -> void:
	_location = _small_label("", 30)
	_location.anchor_left = 0.5
	_location.anchor_right = 0.5
	_location.offset_left = -400
	_location.offset_right = 400
	_location.offset_top = 70
	_location.offset_bottom = 110
	_location.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location.add_theme_color_override("font_color", Color(1.0, 1.0, 0.92))
	_location.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.2))
	_location.add_theme_constant_override("outline_size", 6)
	_pill(_location, UiKit.WHITE, 34)
	_location.modulate.a = 0.0
	add_child(_location)


func _update_location(delta: float) -> void:
	if _world == null or _location == null:
		return
	_location_show = maxf(_location_show - delta, 0.0)
	_location.modulate.a = clampf(_location_show, 0.0, 1.0)
	_location_timer -= delta
	if _location_timer > 0.0:
		return
	_location_timer = 0.5
	var where := _world.location_name(_player.global_position.x, _player.global_position.z)
	if where != _location_name:
		_location_name = where
		_location.text = where
		_location_show = 3.5


## Lugar actual (pruebas).
func location_text() -> String:
	return _location_name


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


var _toast_queue: Array[String] = []
## Avisos en tarjetas y caja de diálogo (estilo claro, 2026-10-10).
var cards: NoticeCards
var dialog: DialogBox
var missions: MissionPanel
var _speech := RegEx.create_from_string("^([A-ZÁÉÍÓÚÑ][\\wÁÉÍÓÚÑáéíóúñ.]*(?: [A-ZÁÉÍÓÚÑ\\w.]+){0,3}): (.+)$")
var _toast_tween: Tween


## Mensaje breve arriba al centro. Si hay uno en pantalla, espera su turno (cola de 4);
## dura según su largo y la velocidad de texto de Opciones.
func show_toast(message: String) -> void:
	_toast.text = message
	# "Nombre: texto" es alguien que habla (menos Rotom, que es un aviso del teléfono).
	var match := _speech.search(message)
	if match != null and not match.get_string(1).begins_with("Rotom") and not message.begins_with("["):
		dialog.say(match.get_string(1), match.get_string(2))
		return
	cards.show_notice(message.trim_prefix("[Rotom] ").trim_prefix("Rotom: "), "mission" if message.begins_with("[Rotom]") or message.begins_with("Rotom:") else "")


## Aviso antiguo (etiqueta arriba al centro): ya no se muestra; queda por compatibilidad.
func _old_toast(message: String) -> void:
	if _toast_tween != null and _toast_tween.is_running():
		if _toast_queue.size() < 4 and not _toast_queue.has(message) and _toast.text != message:
			_toast_queue.append(message)
		return
	_toast.text = message
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(GameOptions.notice_seconds(message))
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void:
		_toast.visible = false
		if not _toast_queue.is_empty():
			show_toast.call_deferred(_toast_queue.pop_front()))


## Último aviso mostrado (pruebas).
func toast_text() -> String:
	return _toast.text


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
	_companion_card.offset_right = 404
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_companion_card.add_child(row)
	var frame := PanelContainer.new()
	var frame_style := UiKit.card_style(10)
	frame_style.set_content_margin_all(4)
	frame_style.shadow_size = 0
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	_companion_portrait = TextureRect.new()
	_companion_portrait.custom_minimum_size = Vector2(76, 76)
	_companion_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_companion_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_companion_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_companion_portrait)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	_companion_name = _small_label("", 24)
	box.add_child(_companion_name)
	_companion_bar = ProgressBar.new()
	_companion_bar.custom_minimum_size = Vector2(0, 16)
	_companion_bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.03, 0.05, 0.12, 0.8)
	background.set_corner_radius_all(8)
	_companion_fill = StyleBoxFlat.new()
	_companion_fill.bg_color = Color(0.3, 0.85, 0.4)
	_companion_fill.set_corner_radius_all(8)
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
	var portrait_key := companion.species.identifier + str(companion.shiny)
	if portrait_key != _companion_species:
		_companion_species = portrait_key
		_companion_portrait.texture = MenuStyle.front_sprite(companion.species, companion.shiny)
	_companion_bar.value = ratio * 100.0
	_companion_fill.bg_color = UiKit.hp_color(ratio)
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
	var parts := PackedStringArray()
	if companion != null:
		for slot in mini(companion.moves.size(), 4):
			var id: String = companion.moves[slot]
			var wait := companion.move_cooldown_left(id)
			parts.append("[%s] %s%s" % [MoveInput.hint(slot), Moves.get_move(id)["name"], (" %.0fs" % ceil(wait)) if wait > 0.0 else ""])
	parts.append(InputHints.label("dodge", "Esquivar"))
	_downed_controls.text = "   ".join(parts) + "\nMantén %s: Fuerte · %s: Ágil" % [InputHints.hint("run"), InputHints.hint("dive")]


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
	_help.tapped.connect(toggle_legend)
	# Pestaña para desplegar u ocultar la leyenda (también con un toque de H).
	_legend_tab = Button.new()
	_legend_tab.anchor_left = 1.0
	_legend_tab.anchor_right = 1.0
	_legend_tab.anchor_top = 1.0
	_legend_tab.anchor_bottom = 1.0
	_legend_tab.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_legend_tab.offset_right = -24
	_legend_tab.offset_top = -436
	_legend_tab.offset_bottom = -400
	_legend_tab.focus_mode = Control.FOCUS_NONE
	_legend_tab.add_theme_font_override("font", UiKit.font(true))
	_legend_tab.add_theme_font_size_override("font_size", 17)
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Color(0.07, 0.11, 0.24, 0.8)
	tab_style.set_corner_radius_all(14)
	tab_style.content_margin_left = 14
	tab_style.content_margin_right = 14
	tab_style.content_margin_top = 4
	tab_style.content_margin_bottom = 6
	var tab_hover := tab_style.duplicate() as StyleBoxFlat
	tab_hover.bg_color = Color(0.2, 0.3, 0.55, 0.95)
	_legend_tab.add_theme_stylebox_override("normal", tab_style)
	_legend_tab.add_theme_stylebox_override("hover", tab_hover)
	_legend_tab.add_theme_stylebox_override("pressed", tab_hover)
	_legend_tab.pressed.connect(toggle_legend)
	add_child(_legend_tab)


## Despliega u oculta la leyenda de botones (y lo recuerda en Opciones).
func toggle_legend() -> void:
	GameOptions.show_hints = not GameOptions.show_hints
	GameOptions.save_options()
	AudioBus.play_sfx("ui_open" if GameOptions.show_hints else "ui_close")


func _update_hints() -> void:
	_legend_tab.text = ("Ocultar controles  ▸  [%s]" if GameOptions.show_hints else "◂  Controles  [%s]") % InputHints.hint("help")
	_legend_tab.visible = not (dialog != null and dialog.is_open())
	# Mientras alguien habla, la leyenda se oculta para no encimarse.
	_legend.visible = GameOptions.show_hints and not (dialog != null and dialog.is_open())
	var rows: Array = []
	var aim := _player.get_node("ThrowAim") as ThrowAim
	var context := ""
	match _player.mode:
		Player.Mode.WALK:
			if _player.ride == Player.Ride.FLY:
				context = "fly"
				rows = [["move_forward", "Volar hacia donde miras (la cámara inclina subir o bajar)"], ["jump", "Subir"], ["dive", "Bajar / aterrizar"],
						["run", "Volar rápido"], ["ride", "Bajarse (cerca del suelo)"]]
			elif _player.ride == Player.Ride.MOUNT or _player.ride == Player.Ride.BIKE:
				context = "ride%d" % _player.ride
				rows = [["run", "Más rápido"], ["ride", "Bajarse"]]
				if _player.ride == Player.Ride.MOUNT and _player.mount != null and Player.can_carry_flying(_player.mount):
					rows.push_front(["jump", "Despegar y volar"])
			elif aim.is_aiming():
				context = "aim%s" % aim.locked
				rows = [["throw", "Lanzar Pokéball"], ["aim", "Dejar de apuntar" if aim.locked else "Suelta para dejar de apuntar"], [null, "Mueve la cámara para subir o bajar la mira"]]
			else:
				var has_companion: bool = main != null and main.get("companion") != null
				context = "walk%s" % has_companion
				rows = [["aim", "Apuntar (toca para fijar)"], ["jump", "Saltar"], ["run", "Correr"]]
				if has_companion:
					rows.append(["companion", "Toca: guardar o sacar · Mantén: cambiar"])
					rows.append([null, "%s-%s: ordenar sus movimientos" % [MoveInput.hint(0), MoveInput.hint(3)]])
				rows += [["map", "Mapa"], ["help", "Toca: ocultar · Mantén: ayuda"]]
		Player.Mode.SWIM:
			context = "surf" if _player.riding != null else "swim"
			rows = [[null, "Surfeando sobre tu Pokémon"], ["help", "Mantén: ayuda"]] if _player.riding != null \
					else [["jump", "Mantener: flotar"], ["dive", "Bucear"], ["help", "Mantén: ayuda"]]
		Player.Mode.DIVE:
			context = "dive"
			rows = [["jump", "Mantener: subir"], [null, "Suelta para hundirte"], ["help", "Mantén: ayuda"]]
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


# --- Reloj ---------------------------------------------------------------------------

func _build_clock() -> void:
	_clock = _small_label("", 22)
	_clock.anchor_left = 1.0
	_clock.anchor_right = 1.0
	_clock.offset_left = -260
	_clock.offset_right = -40
	_clock.offset_top = 230
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pill(_clock, Color(0.5, 0.75, 1.0))
	add_child(_clock)


# --- Pokéball elegida -------------------------------------------------------------

## Abajo a la derecha: ícono de la ball elegida, nombre, cuántas quedan y su efecto,
## con los botones para cambiar de ball. Se redibuja al cambiar la mochila.
func _build_ball_panel() -> void:
	_balls.visible = false
	_ball_panel = PanelContainer.new()
	_ball_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.9, 0.3, 0.3)))
	_ball_panel.anchor_left = 1.0
	_ball_panel.anchor_right = 1.0
	_ball_panel.anchor_top = 1.0
	_ball_panel.anchor_bottom = 1.0
	_ball_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ball_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ball_panel.offset_right = -24
	_ball_panel.offset_bottom = -20
	add_child(_ball_panel)
	_legend.offset_bottom = -130
	GameState.bag_changed.connect(func() -> void: _ball_key = "")
	InputHints.device_changed.connect(func(_pad: bool) -> void: _ball_key = "")


func _update_ball_panel() -> void:
	var id := GameState.selected_ball
	var key := "%s:%d:%s" % [id, GameState.item_count(id), InputHints.gamepad]
	if key == _ball_key:
		return
	_ball_key = key
	for child in _ball_panel.get_children():
		child.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_ball_panel.add_child(row)
	var arrows := VBoxContainer.new()
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	arrows.add_child(InputGlyph.make("ball_next"))
	arrows.add_child(InputGlyph.make("ball_prev"))
	row.add_child(arrows)
	var icon := TextureRect.new()
	icon.texture = Items.icon(id)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(48, 48)
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.modulate = Color(1, 1, 1, 1.0 if GameState.item_count(id) > 0 else 0.35)
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var count := GameState.item_count(id)
	var title := _small_label("%s × %d" % [Items.display_name(id), count], 22)
	title.add_theme_color_override("font_color", Color.WHITE if count > 0 else Color(1.0, 0.5, 0.5))
	text.add_child(title)
	var data: Dictionary = Items.get_item(id).get("ball", {})
	var effect := "Captura ×%s" % str(data.get("rate", 1.0)) if float(data.get("rate", 1.0)) < 100.0 else "Captura segura"
	if data.size() > 1:
		effect = Items.get_item(id).get("desc", effect)
	var detail := _small_label(effect, 15)
	detail.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	text.add_child(detail)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or _player.mode != Player.Mode.WALK:
		return
	if event.is_action_pressed("ball_next"):
		GameState.cycle_ball(1)
	elif event.is_action_pressed("ball_prev"):
		GameState.cycle_ball(-1)


# --- Utilidades --------------------------------------------------------------------

func _set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != ""


func _small_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiKit.font(true))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.14))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Panel del kit: azul marino translúcido, esquinas redondeadas y franja de color a la izquierda.
func _panel_style(border: Color = Color(0.95, 0.95, 0.9)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiKit.CREAM.r, UiKit.CREAM.g, UiKit.CREAM.b, 0.94) if UiKit.light else Color(0.07, 0.11, 0.24, 0.86)
	if UiKit.light and border.s < 0.2:
		border = UiKit.RED
	style.set_corner_radius_all(14)
	style.border_color = border
	style.border_width_left = 6
	style.set_content_margin_all(12)
	style.content_margin_left = 16
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 6
	return style


## Convierte una etiqueta en píldora del kit que se ajusta al texto (centrada en su ancla).
func _pill(label: Label, accent: Color, size: int = 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiKit.CREAM.r, UiKit.CREAM.g, UiKit.CREAM.b, 0.94) if UiKit.light else Color(0.07, 0.11, 0.24, 0.88)
	if UiKit.light and accent.s < 0.2:
		accent = UiKit.RED
	style.set_corner_radius_all(22)
	style.border_color = accent
	style.border_width_bottom = 3
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 5
	label.add_theme_stylebox_override("normal", style)
	if size > 0:
		label.add_theme_font_size_override("font_size", size)
	# Ajustarse al texto: sin ancho fijo, crece hacia ambos lados desde el ancla.
	var center := (label.offset_left + label.offset_right) * 0.5
	label.offset_left = center
	label.offset_right = center
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _pixel_texture(rows: Array, palette: Dictionary) -> Texture2D:
	var width: int = (rows[0] as String).length()
	var image := Image.create_empty(width, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in width:
			var c: String = rows[y][x]
			if palette.has(c):
				image.set_pixel(x, y, palette[c])
	return ImageTexture.create_from_image(image)


## Contenedor de pantalla completa para las tarjetas y el diálogo (el HUD es un CanvasLayer).
func _root_control() -> Control:
	var root := get_node_or_null("NoticeRoot") as Control
	if root == null:
		root = Control.new()
		root.name = "NoticeRoot"
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.theme = UiKit.theme()
		add_child(root)
	return root
