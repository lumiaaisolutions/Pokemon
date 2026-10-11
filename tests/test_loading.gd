extends Node
## Prueba de la pantalla de carga (Fernando, 2026-10-11): tapa el mundo al iniciar la
## partida hasta que las zonas cercanas están construidas, la navegación horneada y el
## jugador en el suelo, y se cierra con fundido cuando el mundo ya está listo; nunca se
## queda atascada.
## Uso: godot --headless --path . tests/test_loading.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	BattleManager.enabled = false
	GameState.party.clear()
	var main := MAIN_SCENE.instantiate() as Node3D
	main.set("starter_ceremony", false)
	add_child(main)

	# Aparece al instante, tapando el mundo mientras se construye.
	var loading := main.get_node_or_null("LoadingScreen") as LoadingScreen
	_check(loading != null, "la pantalla de carga aparece al iniciar la partida")
	_check(loading != null and loading.is_showing(), "la pantalla de carga tapa el mundo mientras no está listo")

	var navigation := main.get_node("Navigation") as WorldNavigation
	var player := main.get_node("Player") as Player
	var world := main.get_node("World") as WorldBuilder

	# No se queda atascada: termina antes del tope de seguridad de la propia pantalla.
	for i in int(LoadingScreen.MAX_WAIT_SECONDS * 60.0) + 60:
		await get_tree().physics_frame
		if loading == null or not loading.is_showing():
			break
	_check(world.near_chunks().size() == 25, "las 5 × 5 zonas cercanas quedan construidas (%d)" % world.near_chunks().size())
	_check(navigation.is_baked, "la navegación de la zona del jugador queda horneada")
	_check(player.is_on_floor(), "el jugador queda en el suelo")
	_check(loading == null or not loading.is_showing(), "la pantalla de carga se cierra cuando el mundo está listo")

	# El fundido de salida tarda un poco más: espera a que de verdad se quite del árbol.
	for i in 120:
		await get_tree().physics_frame
		if main.get_node_or_null("LoadingScreen") == null:
			break
	_check(main.get_node_or_null("LoadingScreen") == null, "la pantalla de carga se quita del árbol al terminar su fundido")

	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_loading: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
