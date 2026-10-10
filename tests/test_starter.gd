extends Node
## Prueba de la ceremonia del inicial: 5 huevos eclosionan, el primero que recibe una
## Pokéball se captura siempre y es el compañero; los demás se van.
## Uso: godot --headless --path . tests/test_starter.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player


func _ready() -> void:
	# Combate en arena apagado: esta prueba revisa las peleas en el mundo (ver test_battle).
	BattleManager.enabled = false
	GameState.party.clear()
	_main = MAIN_SCENE.instantiate() as Node3D
	add_child(_main)
	_player = _main.get_node("Player") as Player
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_starter: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	await _frames(30)
	_check(_main.get("companion") == null, "antes de elegir no hay compañero")
	_check(not (_main.get_node("Spawner") as Node).is_processing(), "durante la ceremonia no aparecen salvajes")
	# Eclosión: 2.5 s de sacudidas y 5 huevos que se abren uno tras otro.
	var hatched: Array[PokemonActor] = []
	for i in 600:
		await get_tree().physics_frame
		hatched = _ceremony_actors()
		if hatched.size() == StarterCeremony.EGGS:
			break
	_check(hatched.size() == StarterCeremony.EGGS, "deben eclosionar 5 Pokémon (salieron %d)" % hatched.size())
	var names := {}
	for actor in hatched:
		names[actor.species.identifier] = true
		_check(actor.species.evolution_stage == 1, "%s debe ser un Pokémon básico" % actor.species.display_name)
	_check(names.size() == hatched.size(), "los 5 deben ser especies distintas")
	if hatched.is_empty():
		return
	# Se queda quieto mirando al jugador hasta que lo eligen.
	var target := hatched[2]
	var before := target.global_position
	await _frames(60)
	_check(is_instance_valid(target) and target.global_position.distance_to(before) < 0.2, "el recién nacido se queda quieto")
	# Una Pokéball sin resultado forzado: la ceremonia la vuelve segura.
	var species := target.species
	var ball := PokeballProjectile.create()
	ball.thrower = _player
	_main.add_child(ball)
	var from := _player.global_position + Vector3.UP * 1.4
	ball.global_position = from
	var to := target.global_position + Vector3.UP * 0.5
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	ball.linear_velocity = (to - from) / 0.5 + Vector3.UP * 0.5 * gravity * 0.5
	await _frames(int((CaptureRules.SHAKES * PokeballProjectile.SHAKE_TIME + 2.0) * 60))
	var companion := _main.get("companion") as PokemonActor
	_check(companion != null and companion.species == species, "el elegido debe ser el compañero")
	_check(companion != null and companion.role == PokemonActor.Role.COMPANION, "el elegido sigue al jugador como compañero")
	_check(GameState.party.size() == 1 and GameState.party[0]["species"] == species.identifier, "el elegido entra al equipo")
	await _frames(10)
	_check(_ceremony_actors().is_empty(), "los demás se van y no quedan en el mundo")
	_check((_main.get_node("Spawner") as Node).is_processing(), "tras elegir vuelven a aparecer salvajes")


func _ceremony_actors() -> Array[PokemonActor]:
	var result: Array[PokemonActor] = []
	for child in _main.get_children():
		if child is PokemonActor and (child as PokemonActor).ceremony and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
