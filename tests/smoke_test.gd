extends Node
## Prueba de humo de la Fase 0: autoloads cargados y Input Map completo.
## Uso: godot --headless --path . tests/smoke_test.tscn  (sale con 0 si todo pasa)

const AUTOLOADS: Array[String] = ["GameState", "SaveSystem", "InputHints", "AudioBus"]
const ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "run",
	"camera_left", "camera_right", "camera_up", "camera_down", "zoom_in", "zoom_out",
	"interact", "menu", "map", "companion", "help", "jump", "dive",
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

	# Personajes: 5 chicos y 5 chicas, todos con hoja de 3 × 8 celdas de 32 px.
	if PlayerCharacters.by_gender("male").size() != 5 or PlayerCharacters.by_gender("female").size() != 5:
		failures.append("Deben ser 5 personajes de cada género")
	for entry in PlayerCharacters.LIST:
		var sheet := PlayerCharacters.sheet(entry["id"])
		if not ResourceLoader.exists("res://art/trainers/%s_overworld.png" % entry["id"]) or sheet.get_size() != Vector2(96, 256):
			failures.append("Hoja de %s ausente o con otro tamaño" % entry["id"])
	if GameState.difficulty_value("damage") != 1.0:
		failures.append("La dificultad por defecto debe ser Normal")
	if ProjectSettings.get_setting("application/run/main_scene") != "res://ui/character_select/character_select.tscn":
		failures.append("La partida debe empezar en la selección de personaje")
	# Megas: el catálogo carga completo y Mega Greninja trae datos y sprites.
	var megas := MegaCatalog.load_catalog()
	if megas == null or megas.megas.size() < 90:
		failures.append("El catálogo de megas no cargó completo")
	else:
		var greninja := megas.find("greninja-mega")
		if greninja == null or not greninja.has_battle_sprites() or greninja.base_total() != 630 or greninja.stone == "":
			failures.append("Mega Greninja incompleta")
	for failure: String in failures:
		printerr("FALLO: " + failure)
	print("smoke_test: %d autoloads, %d acciones, %d fallos" % [AUTOLOADS.size(), ACTIONS.size(), failures.size()])
	get_tree().quit(1 if failures.size() > 0 else 0)
