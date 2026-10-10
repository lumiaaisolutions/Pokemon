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
static var _loaded := false


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
	config.save(PATH)
	apply()


## Aplica lo que no se lee cada cuadro (pantalla completa).
static func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != wanted:
		DisplayServer.window_set_mode(wanted)
