class_name Migrations
extends Node3D
## Migraciones (fase 5.8, decisiones de Fernando 2026-10-10):
## - Cada 2–3 días, por la mañana, el Rotom avisa que hoy pasará una bandada de una especie
##   de la estación (Wingull al atardecer, Swablu en primavera, Butterfree en verano…) y la
##   zona donde aterrizará. Puede ser de fuera de la Pokédex regional (viene de otra región).
## - A su hora cruza el cielo sobre el jugador en V, rumbo a donde aterriza; en el cielo
##   solo se ve.
## - Aterriza lejos (hay que buscarla; el Rotom solo dice la zona) y se queda el resto del
##   día: en LAND_RADIUS salen sobre todo de esa especie, con más probabilidad de shiny.
## Estado en GameState.world_flags["events"]["migration"] (se guarda con la partida).

## Por estación (0 Primavera, 1 Verano, 2 Otoño, 3 Invierno): [especie, hora de paso].
const POOL := [
	[["swablu", 9], ["pidove", 8], ["hoppip", 11], ["cottonee", 13]],
	[["butterfree", 10], ["beautifly", 11], ["vivillon", 12], ["wingull", 18]],
	[["starly", 9], ["ducklett", 16], ["murkrow", 19], ["wingull", 18]],
	[["delibird", 12], ["pidove", 9], ["starly", 10]],
]
const DAYS_MIN := 2
const DAYS_MAX := 3
const LAND_RADIUS := 70.0
const LAND_SHARE := 0.75
const SHINY_BOOST := 3.0
const MIN_DISTANCE := 450.0
const FLOCK_SIZE := 9
const FLOCK_SPEED := 14.0
## Altura sobre el suelo y distancia frente a la cámara por donde pasa (para que se vea
## con la cámara normal, que mira hacia abajo).
const FLOCK_HEIGHT := 12.0
const FLOCK_AHEAD := 30.0
const FLOCK_SECONDS := 20.0
const FLOCK_SCALE := 1.5
## La cámara mira al cielo cuando la bandada se acerca al punto frente a ella.
const SKY_LOOK_AT := 2.5
const SKY_LOOK_SECONDS := 4.0

@export var world_path: NodePath
@export var player_path: NodePath

var _world: WorldBuilder
var _player: Node3D
var _rng := RandomNumberGenerator.new()
var _flock: Node3D
var _flock_dir := Vector3.ZERO
var _flock_time := 0.0
var _sky_looked := false


func _ready() -> void:
	add_to_group(&"migrations")
	_rng.randomize()
	_world = get_node(world_path) as WorldBuilder
	_player = get_node(player_path) as Node3D


func _flags() -> Dictionary:
	if not GameState.world_flags.has("events"):
		GameState.world_flags["events"] = {}
	return GameState.world_flags["events"]


## La migración de hoy (o {} si no hay).
func current() -> Dictionary:
	var migration: Dictionary = _flags().get("migration", {})
	return migration if not migration.is_empty() and int(migration["day"]) == GameState.game_day() else {}


## ¿Ya aterrizó la bandada de hoy?
func landed() -> bool:
	var migration := current()
	return not migration.is_empty() and GameState.clock_hour() >= float(migration["hour"])


func _process(delta: float) -> void:
	if _flock != null:
		_move_flock(delta)
	if GameState.party.is_empty() or _player == null:
		return
	var day := GameState.game_day()
	if GameState.clock_hour() >= 6.0 and int(_flags().get("migration_rolled", -1)) != day:
		_flags()["migration_rolled"] = day
		if day >= int(_flags().get("migration_next", 1)):
			start_migration()
	var migration := current()
	# Pasa a su hora; si estás en combate, en un edificio o en un diálogo, espera a que salgas.
	if not migration.is_empty() and not bool(migration.get("flown", false)) and GameState.clock_hour() >= float(migration["hour"]) and _can_show():
		migration["flown"] = true
		fly_over()


func _can_show() -> bool:
	var battle := get_parent().get_node_or_null("Battle") as BattleManager
	if battle != null and battle.active:
		return false
	var interiors := _world.structures.services.interiors if _world.structures != null and _world.structures.services != null else null
	return not (interiors != null and interiors.is_inside()) and not DialogBox.blocking


## Empieza la migración de hoy (species y point al azar si no se dan; pruebas).
func start_migration(species: SpeciesData = null, point: Vector3 = Vector3.INF, hour: float = -1.0) -> Dictionary:
	var options: Array = POOL[WildSpawner.current_season()]
	var pick: Array = options[_rng.randi() % options.size()]
	if species == null:
		species = MenuStyle.species(pick[0])
		if species == null:
			return {}
	if hour < 0.0:
		hour = float(pick[1]) if pick[0] == species.identifier else float(_rng.randi_range(9, 17))
	if point == Vector3.INF:
		point = _landing_point()
		if point == Vector3.INF:
			return {}
	var migration := {"species": species.identifier, "x": point.x, "z": point.z, "day": GameState.game_day(), "hour": hour, "flown": false}
	_flags()["migration"] = migration
	_flags()["migration_next"] = GameState.game_day() + _rng.randi_range(DAYS_MIN, DAYS_MAX)
	var place := _world.location_name(point.x, point.z)
	GameState.add_news("Rotom: Hoy hacia las %d:00 pasará una bandada de %s y aterrizará por %s. ¡Búscala, se va al terminar el día!" % [int(hour), species.display_name, place])
	return migration


## Un lugar de tierra lejos del jugador y fuera de los pueblos.
func _landing_point() -> Vector3:
	var half := _world.config.size * 0.5 - 60.0
	for attempt in 60:
		var point := Vector3(_rng.randf_range(-half, half), 0, _rng.randf_range(-half, half))
		if _player != null and Vector2(point.x - _player.global_position.x, point.z - _player.global_position.z).length() < MIN_DISTANCE:
			continue
		if _world.water_depth_at(point.x, point.z) > 0.1 or not _world.settlement_at(point.x, point.z, 30.0).is_empty():
			continue
		return point
	return Vector3.INF


## Especie de la bandada si point está donde aterrizó (y ya aterrizó), o null.
func species_at(point: Vector3) -> SpeciesData:
	if not landed():
		return null
	var migration := current()
	if Vector2(point.x - float(migration["x"]), point.z - float(migration["z"])).length() > LAND_RADIUS:
		return null
	return MenuStyle.species(migration["species"])


## La bandada cruza el cielo sobre el jugador rumbo a donde aterriza (solo se ve).
func fly_over() -> void:
	var migration := current()
	if migration.is_empty() or _player == null:
		return
	var species := MenuStyle.species(migration["species"])
	if species == null or species.overworld_sheet == null:
		return
	if _flock != null:
		_flock.queue_free()
	var target := Vector3(float(migration["x"]), 0, float(migration["z"]))
	_flock_dir = Vector3(target.x - _player.global_position.x, 0, target.z - _player.global_position.z).normalized()
	if _flock_dir == Vector3.ZERO:
		_flock_dir = Vector3.FORWARD
	_flock = Node3D.new()
	_flock.name = "MigrationFlock"
	add_child(_flock)
	# Pasa por un punto frente a la cámara, rumbo a donde aterriza.
	var ahead := _player.global_position
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var forward := -camera.global_transform.basis.z
		forward.y = 0.0
		if forward.length() > 0.01:
			ahead += forward.normalized() * FLOCK_AHEAD
	ahead.y = _world.surface_height_at(ahead.x, ahead.z) + FLOCK_HEIGHT
	_flock.global_position = ahead - _flock_dir * FLOCK_SPEED * (SKY_LOOK_AT + 2.5)
	_flock.look_at(_flock.global_position + _flock_dir, Vector3.UP)
	# Formación en V: el primero adelante y los demás a los lados, más atrás.
	for i in FLOCK_SIZE:
		var row := (i + 1) / 2
		var side := 0.0 if i == 0 else (1.0 if i % 2 == 1 else -1.0)
		var sprite := DirectionalSprite.new()
		sprite.name = "Bird%d" % i
		_flock.add_child(sprite)
		sprite.setup(species.overworld_sheet, 2, 4, PokemonActor.PIXEL_SIZE * species.size_scale * FLOCK_SCALE * 32.0 / species.overworld_cell, species.foot_offset_px)
		sprite.position = Vector3(side * row * 2.6, _rng.randf_range(-0.6, 0.6), row * 2.8)
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_flock_time = 0.0
	_sky_looked = false
	GameState.notice.emit("¡Mira el cielo! Pasa una bandada de %s rumbo a %s." % [species.display_name, _world.location_name(target.x, target.z)])
	var npcs := get_tree().get_first_node_in_group(&"town_npcs") as TownNPCs
	if npcs != null:
		npcs.react(_player.global_position, ["¡Mira esa bandada!", "¡Una bandada en el cielo!"])


func _move_flock(delta: float) -> void:
	_flock_time += delta
	_flock.global_position += _flock_dir * FLOCK_SPEED * delta
	if not _sky_looked and _flock_time >= SKY_LOOK_AT:
		_sky_looked = true
		var rig := get_tree().get_first_node_in_group(CameraRig.CAMERA_GROUP) as CameraRig
		if rig != null:
			rig.look_at_sky(SKY_LOOK_SECONDS)
	for child in _flock.get_children():
		var sprite := child as DirectionalSprite
		sprite.position.y += sin(_flock_time * 3.0 + sprite.get_index()) * delta * 0.4
		sprite.animate(_flock_dir * FLOCK_SPEED, delta, true)
	if _flock_time >= FLOCK_SECONDS:
		_flock.queue_free()
		_flock = null


## ¿Hay una bandada en el cielo ahora? (pruebas)
func flock() -> Node3D:
	return _flock
