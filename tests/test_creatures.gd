extends Node
## Prueba de las Fases 2 y 2.5 sobre world/main.tscn: navegación, compañero, aparición
## por hábitat, temperamentos, persecución con área, territorio, shiny, tamaños y legendarios.
## Uso: godot --headless --path . tests/test_creatures.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")
const POOL := preload("res://creatures/data/basic_pool.tres")

var _failures: Array[String] = []
var _main: Node3D
var _player: Player
var _world: WorldBuilder
var _spawner: WildSpawner


func _ready() -> void:
	# Combate en arena apagado: esta prueba revisa las peleas en el mundo (ver test_battle).
	BattleManager.enabled = false
	_main = MAIN_SCENE.instantiate() as Node3D
	# Sin ceremonia del inicial: compañero al azar (la ceremonia se prueba en test_starter).
	_main.set("starter_ceremony", false)
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_world = _main.get_node("World") as WorldBuilder
	_spawner = _main.get_node("Spawner") as WildSpawner
	await _run()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_creatures: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run() -> void:
	var navigation := _main.get_node("Navigation") as WorldNavigation
	var waited := 0
	while not navigation.is_baked and waited < 1800:
		await get_tree().physics_frame
		waited += 1
	_check(navigation.is_baked, "la navegación no terminó de hornearse en 30 s")
	_check(navigation.polygon_count() > 100, "la malla de navegación está casi vacía")
	await _frames(10)

	# Compañero: un básico del grupo que sigue al jugador.
	var companion: PokemonActor = _main.companion
	_check(companion != null and POOL.species.has(companion.species), "el compañero debe ser un básico del grupo de iniciales")
	Input.action_press("move_forward")
	await _frames(180)
	Input.action_release("move_forward")
	await _frames(180)
	var gap := companion.global_position.distance_to(_player.global_position)
	print("  compañero %s a %.1f m del jugador" % [companion.species.display_name, gap])
	_check(gap < 4.5, "el compañero debe seguir al jugador (quedó a %.1f m)" % gap)

	# Aparición por hábitat: 60 intentos repartidos por el mundo.
	_spawner.set_process(false)
	# Clima: en la nieve no hay Fuego, Planta ni Bicho; el Hielo no vive en zonas templadas.
	var world := _main.get_node("World") as WorldBuilder
	var snow := Vector3(0, world.config.snow_height + 1.0, 0)
	var warm := Vector3(0, 0.0, 0)
	var torchic := load("res://creatures/data/species/torchic.tres") as SpeciesData
	var snorunt := load("res://creatures/data/species/snorunt.tres") as SpeciesData
	_check(not _spawner.climate_ok(torchic, snow), "Torchic (Fuego) no debe aparecer en la nieve")
	_check(_spawner.climate_ok(snorunt, snow), "Snorunt (Hielo) sí vive en la nieve")
	_check(not _spawner.climate_ok(snorunt, warm), "Snorunt no debe aparecer en la pradera")
	(_main.get_node("Legendaries") as LegendaryManager).set_process(false)
	(_main.get_node("Ambushes") as Node).set_process(false)
	_clear_wild()
	var checked := 0
	# Seis puntos alrededor del inicio, dentro de las zonas cargadas.
	var o := _world.start_position()
	var spots: Array[Vector3] = []
	for k in 6:
		spots.append(o + Vector3(cos(k * 1.05) * (40.0 + k * 35.0), 0, sin(k * 1.05) * (40.0 + k * 35.0)))
	for spot in spots:
		_player.global_position = Vector3(spot.x, _world.surface_height_at(spot.x, spot.z) + 0.5, spot.z)
		for i in 10:
			var actor := _spawner.spawn_one()
			if actor == null:
				continue
			checked += 1
			_check_habitat_rules(actor)
	print("  apariciones revisadas: %d" % checked)
	_check(checked >= 20, "muy pocas apariciones en 60 intentos (%d)" % checked)
	_clear_wild()
	await _frames(2)

	# Tamaños por altura y shiny.
	var wailord := _spawner.spawn_species(_species("wailord"), o, false, false)
	var joltik := _spawner.spawn_species(_species("joltik"), o, true, false)
	await _frames(2)
	var wailord_sprite := wailord.get_node("Sprite") as Sprite3D
	# (Cada individuo tiene su talla: se compara sin ella.)
	var wailord_height := wailord_sprite.texture.get_height() / 4.0 * wailord_sprite.pixel_size / wailord.size_factor
	_check(is_equal_approx(wailord_height, 32.0 * 3.0 * PokemonActor.PIXEL_SIZE), "Wailord debe medir 32 px ×3 en el mundo (%.2f m)" % wailord_height)
	_check(is_equal_approx((joltik.get_node("Sprite") as Sprite3D).pixel_size / joltik.size_factor, PokemonActor.PIXEL_SIZE), "Joltik debe dibujarse ×1")
	_check(joltik.size_factor >= 0.75 and joltik.size_factor <= 1.3, "la talla de cada individuo va de 0.75 a 1.3")
	_check((joltik.get_node("Sprite") as Sprite3D).texture == _species("joltik").overworld_sheet_shiny, "un shiny debe usar su hoja variocolor")
	_check(joltik.has_node("ShinySparkles"), "un shiny debe tener destello")
	_check(is_equal_approx(WildSpawner.SHINY_CHANCE, 0.01), "la probabilidad de shiny debe ser 1 %")
	_clear_wild()
	await _frames(2)

	# Temperamentos con el jugador quieto en un claro. El compañero se aparta: su
	# defensa (ver test_fights) cambiaría con quién pelea cada salvaje.
	(_main.companion as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(_main.companion as Node3D).global_position = Vector3(0, -50, 0)
	var clearing := _clearing()
	_player.global_position = clearing + Vector3.UP * 0.5
	await _frames(20)
	# Agresivo: te alcanza (contacto) o ya llegó a distancia de golpe (el ataque sale
	# tras una espera al azar de 1.4 a 2.4 s).
	await _check_temperament("absol", 7.0, "agresivo", func(start: float, end: float, contact: bool) -> bool: return contact or end <= PokemonActor.MELEE_RANGE + 0.8)
	await _check_temperament("pidgeot", 6.0, "tímido", func(start: float, end: float, contact: bool) -> bool: return end > start + 4.0)
	await _check_temperament("ampharos", 7.0, "curioso", func(start: float, end: float, contact: bool) -> bool: return end < start - 2.0 and end > PokemonActor.CONTACT_RADIUS)
	await _check_temperament("venusaur", 7.0, "deambula", func(start: float, end: float, contact: bool) -> bool: return not contact and end > 3.0)
	await _check_temperament("aggron", 12.0, "territorial fuera de su zona", func(start: float, end: float, contact: bool) -> bool: return not contact and end > 8.0)

	# Persecución con área: si el jugador sale del área, el perseguidor se rinde.
	var chaser := _spawner.spawn_species(_species("absol"), _ground(6.0, 0.0), false, false)
	await _frames(30)
	_check(chaser.state == PokemonActor.State.CHASE or chaser.fight_target == _player, "el agresivo debe empezar a perseguir (estado %d)" % chaser.state)
	_check((chaser.get_node("ChaseRing") as Decal).visible, "al perseguir se muestra el área en el suelo")
	var leash := chaser.chase_leash()
	_check(leash >= 12.0 and leash <= 35.0, "el área de persecución debe estar entre 12 y 35 m (%.1f)" % leash)
	_player.global_position = chaser.chase_origin + Vector3(0, 0, -(leash + 6.0))
	_player.global_position.y = _world.surface_height_at(_player.global_position.x, _player.global_position.z) + 0.5
	# Si estaba a punto de atacar, primero termina el golpe y luego revisa el área.
	for i in 90:
		await get_tree().physics_frame
		if chaser.state == PokemonActor.State.RETURN:
			break
	_check(chaser.state == PokemonActor.State.RETURN, "fuera del área debe rendirse y regresar (estado %d)" % chaser.state)
	_clear_wild()
	await _frames(2)

	# Territorial: entra a su zona y lo persigue.
	_player.global_position = clearing + Vector3.UP * 0.5
	var guard := _spawner.spawn_species(_species("aggron"), _ground(4.0, 0.0), false, false)
	await _frames(30)
	# Persigue o pelea con Nate, o con su compañero si este salió a defenderlo.
	var defends: bool = guard.state == PokemonActor.State.CHASE or (guard.state == PokemonActor.State.FIGHT \
			and (guard.fight_target == _player or guard.fight_target == _main.companion))
	_check(defends, "el territorial debe perseguir o atacar si el jugador entra a su zona (estado %d)" % guard.state)
	_clear_wild()
	await _frames(2)

	# Cupo por zona: nunca más grupos que el cupo en una zona.
	_spawner.set_process(true)
	_player.global_position = clearing + Vector3.UP * 0.5
	for i in 900:
		await get_tree().physics_frame
	_spawner.set_process(false)
	var counts := _spawner.groups_per_zone()
	var over := 0
	for zone: Vector2i in counts:
		if counts[zone] > _spawner.zone_quota(zone):
			over += 1
	print("  zonas ocupadas: %d, grupos: %d, salvajes: %d" % [counts.size(), counts.values().reduce(func(a, b): return a + b, 0), get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP).size()])
	_check(over == 0, "%d zonas superan su cupo" % over)
	_clear_wild()
	await _frames(2)

	# Manadas: misma línea evolutiva, como mucho un líder evolucionado.
	var packs_ok := 0
	for i in 6:
		var leader := _spawner._spawn_pack(_species("pidgey"), _ground(20.0, 4.0 * i), SpeciesData.Habitat.MEADOW)
		await _frames(2)
		var members := get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP).filter(func(a: PokemonActor) -> bool: return a.group_id == leader.group_id)
		var evolved := members.filter(func(a: PokemonActor) -> bool: return a.species.evolution_stage > 1)
		var same_line := members.all(func(a: PokemonActor) -> bool: return a.species.evolution_chain == leader.species.evolution_chain)
		if members.size() >= 2 and same_line and evolved.size() <= 1:
			packs_ok += 1
		_clear_wild()
		await _frames(2)
	_check(packs_ok == 6, "las manadas deben ser de una línea con como mucho un líder evolucionado (%d de 6)" % packs_ok)

	# Especies de temporada (fase 5.8): por tipo y estación; las de temporada solo en la suya.
	var saved_time := GameState.play_time
	var day_of := func(season: int) -> float: return float(season * Weather.SEASON_DAYS) * GameState.DAY_SECONDS
	GameState.play_time = day_of.call(3)
	_check(WildSpawner.current_season() == 3, "el día 21 es invierno")
	_check(WildSpawner.in_season(_species("snover")) and WildSpawner.season_factor(_species("snover")) > 1.0, "en invierno sale Snover (y el Hielo pesa más)")
	_check(WildSpawner.season_factor(_species("caterpie")) < 1.0, "en invierno salen menos Bicho")
	GameState.play_time = day_of.call(1)
	_check(not WildSpawner.in_season(_species("snover")) and WildSpawner.season_factor(_species("snover")) == 0.0, "en verano no sale Snover")
	_check(WildSpawner.season_factor(_species("caterpie")) > 1.0, "en verano salen más Bicho")
	var snover_seen := false
	for i in 200:
		var picked := _spawner.pick_species(SpeciesData.Habitat.MOUNTAIN, 0)
		if picked != null and picked.identifier in ["snover", "abomasnow"]:
			snover_seen = true
	_check(not snover_seen, "pick_species nunca da una especie fuera de su estación")
	GameState.play_time = saved_time

	# Esconderse: al cumplir su tiempo sin interacción desaparece con efecto.
	var hider := _spawner.spawn_species(_species("bidoof"), _ground(25.0, 0.0), false, false)
	await _frames(2)
	hider._hide_after = 0.5
	var bursts_before := _count_bursts()
	var bursts_at_vanish := bursts_before
	for i in 600:
		await get_tree().physics_frame
		if not is_instance_valid(hider):
			bursts_at_vanish = _count_bursts()
			break
	_check(not is_instance_valid(hider), "debe esconderse y desaparecer tras su tiempo sin interacción")
	_check(bursts_at_vanish > bursts_before, "debe dejar un efecto al esconderse (%d -> %d)" % [bursts_before, bursts_at_vanish])

	# Legendarios: solo en santuarios, nunca provocan combate y escapan al verte.
	var legendaries := _main.get_node("Legendaries") as LegendaryManager
	_check(legendaries.sanctuaries.size() >= 8 and legendaries.sanctuaries.size() <= 12, "debe haber unos 10 santuarios (%d)" % legendaries.sanctuaries.size())
	_check(get_tree().get_nodes_in_group(LegendaryManager.LEGENDARY_GROUP).size() == 0, "no debe haber legendarios fuera de los santuarios")
	var mountain_index := 0
	var sanctuary_pos: Vector3 = legendaries.sanctuaries[mountain_index].position
	_player.global_position = sanctuary_pos + Vector3(0, 0.5, 30)
	await _frames(5)
	# Espera la navegación de esa zona (se hornea al llegar).
	for i in 600:
		if navigation.is_area_baked(sanctuary_pos):
			break
		await get_tree().physics_frame
	sanctuary_pos.y = _world.surface_height_at(sanctuary_pos.x, sanctuary_pos.z)
	# Un legendario de la cumbre que viva en esta región (están repartidos, ver Regions).
	var legend: PokemonActor = null
	var legend_id := ""
	for id: String in Regions.current()["legendaries"]:
		var candidate := _species(id)
		if candidate != null and candidate.habitats.has(SpeciesData.Habitat.MOUNTAIN) and not candidate.types.has(PokemonTypes.Type.FLYING):
			legend = legendaries.summon(mountain_index, id)
			if legend != null:
				legend_id = id
				break
	_check(legend != null and legend.legendary, "debe poder aparecer un legendario de la región en el santuario de la cumbre")
	if legend != null:
		var contacted := [false]
		legend.contact_with_player.connect(func(_a: PokemonActor) -> void: contacted[0] = true)
		await _frames(10)
		# El jugador corre hacia él: lo oye o lo ve, muestra "?" y escapa sin atacar.
		# Desde un costado: detrás del legendario está el santuario (modelo con colisión).
		_player.global_position = legend.global_position + Vector3(3.0, 0.5, 0.0)
		await _frames(20)
		_check(legend.state == PokemonActor.State.NOTICE or legend.state == PokemonActor.State.ESCAPE, "el legendario debe notar al jugador (estado %d)" % legend.state)
		_check((legend.get_node("QuestionMark") as Sprite3D).visible, "debe mostrar el signo de interrogación")
		var start := legend.global_position.distance_to(_player.global_position)
		await _frames(240)
		var end := legend.global_position.distance_to(_player.global_position)
		print("  legendario %s: %.1f m -> %.1f m, contacto=%s" % [legend_id, start, end, contacted[0]])
		_check(end > start + 10.0, "el legendario debe escapar lejos (%.1f -> %.1f m)" % [start, end])
		_check(not contacted[0], "un legendario nunca debe provocar combate")
		legend.queue_free()
	var flyer := legendaries.summon(mountain_index, "rayquaza")
	if flyer == null:
		flyer = _spawner.spawn_species(_species("rayquaza"), sanctuary_pos, false, false, true)
	await _frames(5)
	_player.global_position = flyer.global_position + Vector3(0, 0.5, 3.0)
	var max_height := flyer.global_position.y
	for i in 120:
		await get_tree().physics_frame
		max_height = maxf(max_height, flyer.global_position.y)
	_check(max_height > sanctuary_pos.y + 5.0, "un legendario volador debe escapar volando (subió %.1f m)" % (max_height - sanctuary_pos.y))
	GameState.mark_legendary_caught("groudon")
	_check(not GameState.is_legendary_available("groudon"), "un legendario capturado no reaparece sin la tirada del 2 %")


func _count_bursts() -> int:
	return PixelBurst.spawned_total


func _check_habitat_rules(actor: PokemonActor) -> void:
	var p := actor.global_position
	var species := actor.species
	var habitat := _world.habitat_at(p.x, p.z)
	var is_water_type := species.types.has(PokemonTypes.Type.WATER)
	_check(species.habitats.has(habitat), "%s apareció fuera de su hábitat (%d en %s)" % [species.display_name, habitat, p])
	_check(species.spawn_weight > 0.0, "%s no debería aparecer (peso 0)" % species.display_name)
	if actor.swimming:
		_check(species.swims and _world.water_depth_at(p.x, p.z) > 0.6, "%s nada fuera del agua" % species.display_name)
	elif is_water_type:
		_check(_world.water_depth_at(p.x, p.z) < 0.0, "%s (Agua) apareció dentro del agua sin nadar" % species.display_name)
	else:
		_check(_world.water_depth_at(p.x, p.z) < 0.0, "%s apareció dentro del agua" % species.display_name)


## Coloca un salvaje a distance m del jugador, espera 3 s y evalúa el criterio.
func _check_temperament(identifier: String, distance: float, label: String, passes: Callable) -> void:
	var actor := _spawner.spawn_species(_species(identifier), _ground(distance, 0.0), false, false)
	var contacted := [false]
	actor.contact_with_player.connect(func(_a: PokemonActor) -> void: contacted[0] = true)
	await _frames(5)
	var start := actor.global_position.distance_to(_player.global_position)
	await _frames(180)
	var end := actor.global_position.distance_to(_player.global_position)
	print("  %s (%s): %.1f m -> %.1f m, contacto=%s" % [label, identifier, start, end, contacted[0]])
	_check(passes.call(start, end, contacted[0]), "temperamento %s (%s): de %.1f m a %.1f m, contacto=%s" % [label, identifier, start, end, contacted[0]])
	actor.queue_free()
	await _frames(2)


func _species(identifier: String) -> SpeciesData:
	return load("res://creatures/data/species/%s.tres" % identifier) as SpeciesData


## Un claro cerca del inicio: tierra firme y plana, sin árboles, edificios ni caminos
## en 16 m, dentro de las zonas cargadas.
func _clearing() -> Vector3:
	var o := _world.start_position()
	var trees := get_tree().get_nodes_in_group(WorldBuilder.TREES_GROUP)
	for ring in range(4, 20):
		for k in 24:
			var angle := TAU * k / 24.0
			var x := o.x + cos(angle) * ring * 12.0
			var z := o.z + sin(angle) * ring * 12.0
			var p := Vector3(x, _world.surface_height_at(x, z), z)
			if not _world.is_near_loaded(p) or not _world._dry_land(x, z, 16.0) or not _world.settlement_at(x, z, 20.0).is_empty():
				continue
			if _world.distance_to_paths(x, z) < 8.0 or not _world.structures.place_at(x, z, 30.0).is_empty():
				continue
			var flat := true
			for j in 8:
				var a := TAU * j / 8.0
				if absf(_world.surface_height_at(x + cos(a) * 14.0, z + sin(a) * 14.0) - p.y) > 1.5:
					flat = false
			if not flat or trees.any(func(t: Node3D) -> bool: return t.global_position.distance_to(p) < 16.0):
				continue
			return p
	return o


## Punto en el suelo a (dx, dz) del jugador.
func _ground(dx: float, dz: float) -> Vector3:
	var x := _player.global_position.x + dx
	var z := _player.global_position.z + dz
	return Vector3(x, _world.surface_height_at(x, z), z)


func _clear_wild() -> void:
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		node.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
