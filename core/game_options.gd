class_name GameOptions
extends RefCounted
## Opciones del jugador, guardadas aparte de la partida en user://options.cfg.

const PATH := "user://options.cfg"
const DENSITY_NAMES := ["Baja", "Media", "Alta"]
## Máximo de salvajes vivos por densidad.
const DENSITY_MAX_ALIVE := [7, 12, 18]

static var mouse_sensitivity := 0.15
static var stick_speed := 150.0
static var invert_y := false
static var show_hints := true
static var fullscreen := false
static var music_volume := 0.8
static var effects_volume := 0.9
static var cries_volume := 0.8
static var density := 1
static var reduce_shake := false
## Video: resolución de la ventana (índice de RESOLUTIONS) y calidad (0 baja, 1 media, 2 alta).
static var resolution := 0
static var quality := 1
## Velocidad de los textos y avisos (0 lenta, 1 normal, 2 rápida).
static var text_speed := 1
## Idioma (por ahora el juego está escrito en español).
static var language := 0
## Filtro de color: 0 ninguno, 1 protanopía, 2 deuteranopía, 3 tritanopía.
static var colorblind := 0
## Botones reasignados: acción -> [eventos serializados].
static var remaps := {}
static var _loaded := false

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const QUALITY_NAMES := ["Baja", "Media", "Alta"]
const TEXT_SPEED_NAMES := ["Lenta", "Normal", "Rápida"]
const TEXT_SPEED_FACTOR := [1.6, 1.0, 0.6]
const LANGUAGES := ["Español"]
const COLORBLIND_NAMES := ["Ninguno", "Protanopía (rojo)", "Deuteranopía (verde)", "Tritanopía (azul)"]
## Acciones que se pueden reasignar en Opciones.
const REMAPPABLE := ["move_forward", "move_back", "move_left", "move_right", "run", "jump", "dive", "interact", "companion",
		"ride", "aim", "throw", "ball_next", "ball_prev", "attack_1", "attack_2", "attack_3", "attack_4", "move_modifier", "map", "help", "menu", "bag", "photo"]
const ACTION_NAMES := {"move_forward": "Avanzar", "move_back": "Retroceder", "move_left": "Izquierda", "move_right": "Derecha",
		"run": "Correr", "jump": "Saltar / subir", "dive": "Bucear / bajar", "interact": "Interactuar", "companion": "Compañero (rueda)",
		"ride": "Montar / bicicleta", "aim": "Apuntar", "throw": "Lanzar", "ball_next": "Siguiente ball", "ball_prev": "Ball anterior",
		"attack_1": "Movimiento 1", "attack_2": "Movimiento 2", "attack_3": "Movimiento 3", "attack_4": "Movimiento 4",
		"move_modifier": "Modificador de movimientos", "map": "Mapa", "help": "Ayuda", "menu": "Menú", "bag": "Mochila", "photo": "Foto"}
static var _defaults := {}


static func load_options() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	mouse_sensitivity = config.get_value("control", "mouse_sensitivity", mouse_sensitivity)
	stick_speed = config.get_value("control", "stick_speed", stick_speed)
	invert_y = config.get_value("control", "invert_y", invert_y)
	show_hints = config.get_value("ui", "show_hints", show_hints)
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	music_volume = config.get_value("audio", "music", music_volume)
	effects_volume = config.get_value("audio", "effects", effects_volume)
	cries_volume = config.get_value("audio", "cries", cries_volume)
	density = config.get_value("game", "density", density)
	reduce_shake = config.get_value("access", "reduce_shake", reduce_shake)
	resolution = config.get_value("video", "resolution", resolution)
	quality = config.get_value("video", "quality", quality)
	text_speed = config.get_value("ui", "text_speed", text_speed)
	language = config.get_value("ui", "language", language)
	colorblind = config.get_value("access", "colorblind", colorblind)
	remaps = config.get_value("control", "remaps", {})
	apply()


static func save_options() -> void:
	var config := ConfigFile.new()
	config.set_value("control", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("control", "stick_speed", stick_speed)
	config.set_value("control", "invert_y", invert_y)
	config.set_value("ui", "show_hints", show_hints)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "effects", effects_volume)
	config.set_value("audio", "cries", cries_volume)
	config.set_value("game", "density", density)
	config.set_value("access", "reduce_shake", reduce_shake)
	config.set_value("video", "resolution", resolution)
	config.set_value("video", "quality", quality)
	config.set_value("ui", "text_speed", text_speed)
	config.set_value("ui", "language", language)
	config.set_value("access", "colorblind", colorblind)
	config.set_value("control", "remaps", remaps)
	config.save(PATH)
	apply()


## Aplica lo que no se lee cada cuadro: botones, pantalla, resolución, calidad y filtro.
static func apply() -> void:
	_apply_remaps()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		ColorFilter.ensure(tree.root).set_mode(colorblind)
		var viewport := tree.root
		viewport.scaling_3d_scale = [0.67, 0.85, 1.0][clampi(quality, 0, 2)]
		viewport.msaa_3d = Viewport.MSAA_DISABLED if quality < 2 else Viewport.MSAA_2X
	if DisplayServer.get_name() == "headless":
		return
	var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != wanted:
		DisplayServer.window_set_mode(wanted)
	if not fullscreen:
		var size: Vector2i = RESOLUTIONS[clampi(resolution, 0, RESOLUTIONS.size() - 1)]
		if DisplayServer.window_get_size() != size:
			DisplayServer.window_set_size(size)
			var screen := DisplayServer.screen_get_size()
			DisplayServer.window_set_position((screen - size) / 2)


## Sombras del sol según la calidad (lo llama DayNight al iniciar).
static func shadows_enabled() -> bool:
	return quality > 0


## Distancia de dibujo del mundo (zonas lejanas) según la calidad.
static func far_radius() -> int:
	return [4, 5, 6][clampi(quality, 0, 2)]


## Duración de un aviso según su largo y la velocidad de texto.
static func notice_seconds(text: String) -> float:
	return (1.8 + text.length() / 35.0) * TEXT_SPEED_FACTOR[clampi(text_speed, 0, 2)]


# --- Reasignar botones ---------------------------------------------------------------

static func _remember_defaults() -> void:
	if not _defaults.is_empty():
		return
	for action: String in REMAPPABLE:
		if InputMap.has_action(action):
			_defaults[action] = InputMap.action_get_events(action).duplicate()


## Cambia el botón de teclado/mouse (pad = false) o de mando (pad = true) de una acción.
static func remap(action: String, event: InputEvent) -> void:
	_remember_defaults()
	var pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var events: Array = []
	for existing: InputEvent in InputMap.action_get_events(action):
		var existing_pad := existing is InputEventJoypadButton or existing is InputEventJoypadMotion
		if existing_pad != pad:
			events.append(existing)
	events.append(event)
	remaps[action] = events.map(func(e: InputEvent) -> String: return var_to_str(e))
	_apply_remaps()
	save_options()


static func reset_remaps() -> void:
	_remember_defaults()
	remaps = {}
	for action: String in _defaults:
		InputMap.action_erase_events(action)
		for event: InputEvent in _defaults[action]:
			InputMap.action_add_event(action, event)
	save_options()


static func _apply_remaps() -> void:
	_remember_defaults()
	for action: String in remaps:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for text: String in remaps[action]:
			var event: Variant = str_to_var(text)
			if event is InputEvent:
				InputMap.action_add_event(action, event)
