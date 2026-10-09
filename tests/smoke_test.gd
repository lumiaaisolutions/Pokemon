extends Node
## Prueba de humo de la Fase 0: autoloads cargados y Input Map completo.
## Uso: godot --headless --path . tests/smoke_test.tscn  (sale con 0 si todo pasa)

const AUTOLOADS: Array[String] = ["GameState", "SaveSystem", "InputHints", "AudioBus"]
const ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "run",
	"camera_left", "camera_right", "camera_up", "camera_down", "zoom_in", "zoom_out",
	"interact", "menu", "jump", "dive",
	"dodge", "lock_on", "attack_1", "attack_2", "attack_3", "attack_4", "mega_evolve", "capture",
	"aim", "throw",
]


func _ready() -> void:
	var failures: Array[String] = []

	for autoload_name: String in AUTOLOADS:
		if get_tree().root.get_node_or_null(autoload_name) == null:
			failures.append("Falta el autoload %s" % autoload_name)

	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			failures.append("Falta la acción %s" % action)
			continue
		var events := InputMap.action_get_events(action)
		var has_kbm := events.any(func(e: InputEvent) -> bool: return e is InputEventKey or e is InputEventMouseButton)
		var has_pad := events.any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion)
		if not (has_kbm and has_pad):
			failures.append("La acción %s no tiene teclado/mouse y mando" % action)

	var material := load("res://art/materials/pixel_base.tres") as StandardMaterial3D
	if material == null or material.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST:
		failures.append("pixel_base.tres no usa filtro Nearest")

	if ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") != 0:
		failures.append("El filtro 2D por defecto no es Nearest")

	for failure: String in failures:
		printerr("FALLO: " + failure)
	print("smoke_test: %d autoloads, %d acciones, %d fallos" % [AUTOLOADS.size(), ACTIONS.size(), failures.size()])
	get_tree().quit(1 if failures.size() > 0 else 0)
