extends Node
## Prueba del inicio de partida (ronda de la noche, 2026-10-10): la cinemática del
## profesor existe y se puede saltar (Esc o Start/"menu"), produce 4 candidatos básicos
## de hábitats distintos, la ceremonia del inicial pone una pared invisible alrededor de
## la plaza que impide salir antes de elegir y deja salir después, el profesor habla en
## la caja de diálogo (al llegar y al acercarte a un candidato) y, tras elegir, se va a
## su rutina normal (el nodo Professor de main.gd sigue solo).
## Uso: godot --headless --path . tests/test_starter.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder


func _ready() -> void:
	# Combate en arena apagado: esta prueba revisa las peleas en el mundo (ver test_battle).
	BattleManager.enabled = false
	GameState.party.clear()
	_main = MAIN_SCENE.instantiate() as Node3D
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_world = _main.get_node("World") as WorldBuilder
	await _test_candidates_from_distinct_habitats()
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_starter: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


## Unidad: 4 candidatos básicos distintos, cada uno del hábitat del lugar que el
## profesor visitó (pradera, bosque, costa, montaña), de la Pokédex regional.
func _test_candidates_from_distinct_habitats() -> void:
	var cinematic := IntroCinematic.new()
	cinematic.world = _world
	add_child(cinematic)
	var candidates: Array[SpeciesData] = cinematic._pick_candidates()
	cinematic.queue_free()
	_check(candidates.size() == IntroCinematic.STOPS.size(), "deben salir 4 candidatos (salieron %d)" % candidates.size())
	var names := {}
	for species in candidates:
		names[species.identifier] = true
		_check(species.evolution_stage == 1, "%s debe ser un Pokémon básico" % species.display_name)
	_check(names.size() == candidates.size(), "los 4 deben ser especies distintas")
	for i in mini(candidates.size(), IntroCinematic.STOPS.size()):
		var stop: Dictionary = IntroCinematic.STOPS[i]
		var expected: SpeciesData.Habitat = RegionLayout.HABITAT[stop["biome"]]
		_check(candidates[i].habitats.has(expected) or Regions.allows(candidates[i]),
				"%s debe venir del hábitat de %s (o de la Pokédex regional)" % [candidates[i].display_name, stop["label"]])


func _run() -> void:
	# Al empezar una partida nueva (equipo vacío) arranca la cinemática del profesor.
	var cinematic: IntroCinematic = null
	for i in 60:
		await get_tree().process_frame
		cinematic = _main.get_node_or_null("IntroCinematic") as IntroCinematic
		if cinematic != null:
			break
	_check(cinematic != null, "la cinemática arranca con la partida nueva")
	_check(not (_main.get_node("Spawner") as Node).is_processing(), "durante la cinemática no aparecen salvajes")
	if cinematic == null:
		return

	# Se deja correr un rato (el profesor ya viajó lejos) y luego se salta con Esc o
	# Start ("menu"). Bug de Fernando (2026-10-11): al terminar aparecía bajo el suelo.
	await get_tree().create_timer(8.0).timeout
	Input.action_press("menu")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("menu")
	var skipped := false
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not is_instance_valid(cinematic):
			skipped = true
			break
	_check(skipped, "Esc o Start debe saltar la cinemática")
	await get_tree().create_timer(3.0).timeout
	var ground := _world.surface_height_at(_player.global_position.x, _player.global_position.z)
	_check(_player.mode == Player.Mode.WALK and _player.global_position.y > ground - 0.5, "tras la cinemática el jugador queda sobre el suelo (modo %d, y %.1f, suelo %.1f)" % [_player.mode, _player.global_position.y, ground])
	_check(_player.health >= _player.config.health_max - 0.01, "tras la cinemática el jugador no pierde vida")

	# La ceremonia arranca en la plaza con los 4 candidatos que trajo el profesor (todo
	# síncrono dentro de StarterCeremony.start, antes de su primer await): no se avanza
	# ningún diálogo todavía, para poder comprobar que el profesor habla al llegar.
	var ceremony: StarterCeremony = null
	for i in 300:
		await get_tree().process_frame
		ceremony = _main.get_node_or_null("StarterCeremony") as StarterCeremony
		if ceremony != null:
			break
	_check(ceremony != null, "la ceremonia arranca tras la cinemática")
	if ceremony == null:
		return
	var candidates := _ceremony_actors()
	_check(candidates.size() == 4, "deben llegar 4 candidatos a la plaza (llegaron %d)" % candidates.size())
	if candidates.size() < 4:
		return
	var habitats := {}
	for actor in candidates:
		for h in actor.species.habitats:
			habitats[h] = true
	_check(habitats.size() > 1, "los candidatos deben venir de hábitats distintos")

	# El profesor habla en la caja de diálogo al llegar con los candidatos.
	var box := get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	_check(box != null and box.is_open(), "el profesor habla en la caja de diálogo al llegar con los candidatos")
	for i in 120:
		if box == null or not box.is_open():
			break
		box.advance()
		box.advance()
		await get_tree().process_frame
	_check(box == null or not box.is_open(), "la caja de diálogo del profesor se cierra al avanzarla")

	# Pared invisible: te regresa a la plaza mientras no eliges.
	var center: Vector2 = ceremony._center
	_player.global_position = Vector3(center.x, _player.global_position.y, center.y) + Vector3(StarterCeremony.PLAZA_RADIUS + 25.0, 0.0, 0.0)
	await _frames(5)
	_check(Vector2(_player.global_position.x, _player.global_position.z).distance_to(center) <= StarterCeremony.PLAZA_RADIUS + 0.5,
			"la pared invisible regresa al jugador a la plaza antes de elegir")

	# El profesor comenta tipo y carácter al acercarte a un candidato.
	_player.global_position = candidates[0].global_position + Vector3(0.4, 0.0, 0.0)
	var commented := false
	box = null
	for i in 60:
		await get_tree().process_frame
		box = get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
		if box != null and box.is_open():
			commented = true
			break
	_check(commented, "el profesor comenta tipo y carácter al acercarte a un candidato")
	if box != null:
		box.close()

	# Lanza una Pokéball sin resultado forzado al primero: la ceremonia la vuelve segura.
	_player.global_position = Vector3(center.x, _player.global_position.y, center.y)
	await _frames(5)
	var target := candidates[0]
	var species := target.species
	var ball := PokeballProjectile.create()
	ball.thrower = _player
	_main.add_child(ball)
	var from := _player.global_position + Vector3.UP * 1.4
	ball.global_position = from
	var to := target.global_position + Vector3.UP * 0.5
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	ball.linear_velocity = (to - from) / 0.5 + Vector3.UP * 0.5 * gravity * 0.5
	var caught := false
	var balls_before := int(GameState.bag.get("poke-ball", 0))
	for i in 600:
		await get_tree().physics_frame
		_advance_dialog()
		var companion := _main.get("companion") as PokemonActor
		if companion != null and companion.species == species:
			caught = true
			break
	_check(caught, "el elegido debe ser el compañero")
	_check(companion_species_matches(species), "el elegido sigue al jugador como compañero")
	_check(GameState.party.size() == 1 and GameState.party[0]["species"] == species.identifier, "el elegido entra al equipo")
	_check(int(GameState.bag.get("poke-ball", 0)) > balls_before, "el profesor regala Poké Balls al elegir compañero")
	await _frames(10)
	_check(_ceremony_actors().is_empty(), "los demás candidatos se van y no quedan en el mundo")
	_check((_main.get_node("Spawner") as Node).is_processing(), "tras elegir vuelven a aparecer salvajes")

	# El profesor vuelve a su rutina normal: la ceremonia termina y la pared ya no detiene.
	_check(_main.get_node_or_null("StarterCeremony") == null, "la ceremonia termina (el profesor vuelve a su rutina)")
	_player.global_position = Vector3(center.x, _player.global_position.y, center.y) + Vector3(StarterCeremony.PLAZA_RADIUS + 25.0, 0.0, 0.0)
	await _frames(10)
	_check(Vector2(_player.global_position.x, _player.global_position.z).distance_to(center) > StarterCeremony.PLAZA_RADIUS,
			"tras elegir, la pared invisible ya no detiene al jugador")


func companion_species_matches(species: SpeciesData) -> bool:
	var companion := _main.get("companion") as PokemonActor
	return companion != null and companion.species == species and companion.role == PokemonActor.Role.COMPANION


## Si hay una caja de diálogo bloqueante abierta, la avanza (como presionar E dos veces):
## una para mostrar la línea completa y otra para pasar a la siguiente o cerrar.
func _advance_dialog() -> void:
	var box := get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
	if box != null and box.is_open() and DialogBox.blocking:
		box.advance()
		box.advance()


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
