extends SceneTree
## Configura project.godot de forma reproducible (Fase 0).
## Uso: godot --headless --path . -s tools/setup_project.gd

const AUTOLOADS: Dictionary[String, String] = {
	"GameState": "res://core/game_state.gd",
	"SaveSystem": "res://core/save_system.gd",
	"InputHints": "res://core/input_hints.gd",
	"AudioBus": "res://core/audio_bus.gd",
}

const DEADZONE := 0.2


func _initialize() -> void:
	_setup_application()
	_setup_display()
	_setup_rendering()
	_setup_shader_globals()
	_setup_navigation()
	_setup_import_defaults()
	_setup_autoloads()
	_setup_input_map()
	var err := ProjectSettings.save()
	if err != OK:
		push_error("No se pudo guardar project.godot: %s" % error_string(err))
		quit(1)
		return
	print("project.godot configurado")
	quit(0)


func _setup_application() -> void:
	ProjectSettings.set_setting("application/config/name", "Pokemon Mundo Abierto")
	ProjectSettings.set_setting("application/run/max_fps", 0)
	ProjectSettings.set_setting("application/run/main_scene", "res://ui/character_select/character_select.tscn")


func _setup_display() -> void:
	ProjectSettings.set_setting("display/window/size/viewport_width", 1920)
	ProjectSettings.set_setting("display/window/size/viewport_height", 1080)
	ProjectSettings.set_setting("display/window/vsync/vsync_mode", DisplayServer.VSYNC_ENABLED)
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")


func _setup_rendering() -> void:
	# Pixel art: filtro Nearest por defecto en 2D/UI. En 3D lo fija cada material o SpriteBase3D.
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", 0)
	ProjectSettings.set_setting("rendering/renderer/rendering_method", "forward_plus")
	# Bordes suaves en la geometría 3D (árboles, rocas, terreno) sin difuminar los sprites.
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_4X)
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/screen_space_aa", Viewport.SCREEN_SPACE_AA_SMAA)
	# Rendimiento (60 FPS a 1080p en M1): sombras y desenfoque más baratos.
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 2048)
	ProjectSettings.set_setting("rendering/camera/depth_of_field/depth_of_field_bokeh_quality", 0)
	ProjectSettings.set_setting("rendering/camera/depth_of_field/depth_of_field_bokeh_shape", 0)


## Uniformes globales de los shaders: tinte de la hora del día para lo que no recibe
## luz (sprites, hierba y agua); lo actualiza world/day_night.gd.
func _setup_shader_globals() -> void:
	ProjectSettings.set_setting("shader_globals/time_tint", {"type": "color", "value": Color(1, 1, 1, 1)})


func _setup_navigation() -> void:
	# Celdas de 0.5 m: suficiente para esquivar árboles y rocas y hornea rápido 200×200 m.
	ProjectSettings.set_setting("navigation/3d/default_cell_size", 0.5)
	ProjectSettings.set_setting("navigation/3d/default_cell_height", 0.25)


func _setup_import_defaults() -> void:
	# Preset pixel art para todas las texturas nuevas: sin mipmaps y sin compresión con pérdida.
	ProjectSettings.set_setting("importer_defaults/texture", {
		"compress/mode": 0, # Lossless
		"mipmaps/generate": false,
		"detect_3d/compress_to": 0, # No convertir a VRAM comprimido al usarse en 3D
		"process/fix_alpha_border": true,
	})


func _setup_autoloads() -> void:
	for autoload_name: String in AUTOLOADS:
		ProjectSettings.set_setting("autoload/" + autoload_name, "*" + AUTOLOADS[autoload_name])


func _setup_input_map() -> void:
	# Movimiento del jugador / criatura
	_action("move_forward", [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_back", [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("move_left", [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("move_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("run", [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_STICK)])

	# Cámara (el mouse se lee como InputEventMouseMotion en la cámara)
	_action("camera_left", [_key(KEY_LEFT), _axis(JOY_AXIS_RIGHT_X, -1.0)])
	_action("camera_right", [_key(KEY_RIGHT), _axis(JOY_AXIS_RIGHT_X, 1.0)])
	_action("camera_up", [_key(KEY_UP), _axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_action("camera_down", [_key(KEY_DOWN), _axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_action("zoom_in", [_mouse(MOUSE_BUTTON_WHEEL_UP), _button(JOY_BUTTON_DPAD_RIGHT)])
	_action("zoom_out", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _button(JOY_BUTTON_DPAD_LEFT)])

	# Exploración
	_action("interact", [_key(KEY_E), _button(JOY_BUTTON_A)])
	# Explorando: saltar (en combate, el mismo botón es la esquiva). Bucear: bajar al nadar.
	_action("jump", [_key(KEY_SPACE), _button(JOY_BUTTON_B)])
	_action("dive", [_key(KEY_CTRL), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_action("menu", [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	_action("map", [_key(KEY_M), _button(JOY_BUTTON_BACK)])
	# Meter o sacar al compañero de su Pokéball (explorando).
	_action("companion", [_key(KEY_Q), _button(JOY_BUTTON_Y)])
	# Cambiar de Pokéball (siguiente / anterior).
	_action("ball_next", [_key(KEY_R), _button(JOY_BUTTON_DPAD_UP)])
	_action("ball_prev", [_key(KEY_F), _button(JOY_BUTTON_DPAD_DOWN)])
	# Pestañas del menú.
	_action("menu_prev", [_key(KEY_Q), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_action("menu_next", [_key(KEY_E), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	# Ayuda: todos los controles en pantalla (teclado de Mac y control de PlayStation).
	_action("help", [_key(KEY_H), _button(JOY_BUTTON_TOUCHPAD)])

	# Combate
	_action("dodge", [_key(KEY_SPACE), _button(JOY_BUTTON_B)])
	_action("lock_on", [_key(KEY_TAB), _button(JOY_BUTTON_RIGHT_STICK)])
	# Movimientos del compañero: teclas 1-4; en el mando R1 (move_modifier) + □ △ ○ ✕.
	_action("attack_1", [_key(KEY_1), _button(JOY_BUTTON_X)])
	_action("attack_2", [_key(KEY_2), _button(JOY_BUTTON_Y)])
	_action("attack_3", [_key(KEY_3), _button(JOY_BUTTON_B)])
	_action("attack_4", [_key(KEY_4), _button(JOY_BUTTON_A)])
	_action("move_modifier", [_key(KEY_ALT), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("mega_evolve", [_key(KEY_G), _button(JOY_BUTTON_DPAD_UP)])
	_action("capture", [_key(KEY_C), _button(JOY_BUTTON_DPAD_DOWN)])

	# Captura en primera persona
	_action("aim", [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_action("throw", [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])


func _action(action_name: String, events: Array[InputEvent]) -> void:
	ProjectSettings.set_setting("input/" + action_name, {
		"deadzone": DEADZONE,
		"events": events,
	})


func _key(physical_keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.device = -1
	event.physical_keycode = physical_keycode
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.device = -1
	event.button_index = button
	return event


func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	return event


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = value
	return event
