class_name WorldEvents
extends Node3D
## Eventos del mundo que avisa el Rotom Móvil (noticias):
## - Brote masivo: cada mañana puede empezar uno; una especie sale muchísimo en una
##   zona de 90 m durante el día (WildSpawner.special_pick).
## - Lluvia de estrellas: algunas noches; estrellas fugaces en el cielo, salen Pokémon
##   del espacio y cae un fragmento brillante cerca de ti para recoger.
## - Pokémon dominante: a veces aparece uno enorme y fuerte cerca; al vencerlo da un premio.
## - Territorios Alfa: en cada lugar "alpha" vive un Alfa (grande, fuerte, con aura
##   roja) una vez por día del juego.

const OUTBREAK_RADIUS := 90.0
const OUTBREAK_CHANCE := 0.55
const METEOR_CHANCE := 0.3
const DOMINANT_CHANCE := 0.35
const ALPHA_RADIUS := 70.0
const SPACE_POOL := ["clefairy", "cleffa", "minior", "lunatone", "solrock", "staryu", "beldum", "elgyem", "chimecho", "bronzor"]

@export var world_path: NodePath
@export var player_path: NodePath
@export var spawner_path: NodePath

var _world: WorldBuilder
var _player: Node3D
var _spawner: WildSpawner
var _rng := RandomNumberGenerator.new()
var _last_day := -1
var _meteor_sky: GPUParticles3D
var _alphas := {}
var _dominant: PokemonActor
var _dominant_timer := 30.0


func _ready() -> void:
	add_to_group(&"world_events")
	_rng.randomize()
	_world = get_node(world_path) as WorldBuilder
	_player = get_node(player_path) as Node3D
	_spawner = get_node(spawner_path) as WildSpawner
	_meteor_sky = _make_meteors()
	add_child(_meteor_sky)
	_last_day = GameState.game_day()


func _flags() -> Dictionary:
	if not GameState.world_flags.has("events"):
		GameState.world_flags["events"] = {}
	return GameState.world_flags["events"]


func _process(delta: float) -> void:
	if GameState.party.is_empty() or _player == null:
		return
	var day := GameState.game_day()
	var hour := GameState.clock_hour()
	if day != _last_day:
		_last_day = day
		_new_day(day)
	if int(_flags().get("outbreak_day", -1)) != day and hour >= 7.0 and int(_flags().get("rolled_day", -1)) != day:
		_new_day(day)
	_update_meteors(day, hour)
	_update_alphas()
	_dominant_timer -= delta
	if _dominant_timer <= 0.0:
		_dominant_timer = 120.0
		_maybe_dominant()


## Sorteo de la mañana: brote masivo del día.
func _new_day(day: int) -> void:
	if int(_flags().get("rolled_day", -1)) == day:
		return
	_flags()["rolled_day"] = day
	if _rng.randf() < OUTBREAK_CHANCE:
		start_outbreak()
	_flags()["meteor_night"] = day if _rng.randf() < METEOR_CHANCE else -1
	if int(_flags()["meteor_night"]) == day:
		GameState.add_news("Rotom: ¡esta noche habrá lluvia de estrellas! Mira el cielo después de las 20:00.")


## Empieza un brote masivo cerca de un pueblo al azar (o de species en point, pruebas).
func start_outbreak(species: SpeciesData = null, point: Vector3 = Vector3.INF) -> Dictionary:
	if point == Vector3.INF:
		var settlements := _world.layout.settlements
		var s: Dictionary = settlements[_rng.randi() % settlements.size()]
		var angle := _rng.randf() * TAU
		var distance := float(s["radius"]) + _rng.randf_range(80.0, 220.0)
		var x := clampf(float(s["x"]) + cos(angle) * distance, -1900.0, 1900.0)
		var z := clampf(float(s["z"]) + sin(angle) * distance, -1900.0, 1900.0)
		point = Vector3(x, 0, z)
	if species == null:
		var habitat := _world.habitat_at(point.x, point.z)
		species = _spawner.pick_species(habitat, 0)
		if species == null:
			return {}
	var outbreak := {"species": species.identifier, "x": point.x, "z": point.z, "day": GameState.game_day()}
	_flags()["outbreak"] = outbreak
	_flags()["outbreak_day"] = GameState.game_day()
	GameState.add_news("Rotom: ¡brote masivo de %s cerca de %s! Solo por hoy." % [species.display_name, _world.location_name(point.x, point.z)])
	GameState.notice.emit("Rotom: ¡brote masivo de %s! (mira el mapa en el Rotom)" % species.display_name)
	return outbreak


## Especie del brote si point está en su zona (y es hoy), o null.
func outbreak_species_at(point: Vector3) -> SpeciesData:
	var outbreak: Dictionary = _flags().get("outbreak", {})
	if outbreak.is_empty() or int(outbreak["day"]) != GameState.game_day():
		return null
	if Vector2(point.x - float(outbreak["x"]), point.z - float(outbreak["z"])).length() > OUTBREAK_RADIUS:
		var night_meteor := int(_flags().get("meteor_night", -1)) == GameState.game_day() and GameState.is_night()
		return _space_species() if night_meteor and _rng.randf() < 0.3 else null
	return MenuStyle.species(outbreak["species"])


func current_outbreak() -> Dictionary:
	var outbreak: Dictionary = _flags().get("outbreak", {})
	return outbreak if not outbreak.is_empty() and int(outbreak["day"]) == GameState.game_day() else {}


func _space_species() -> SpeciesData:
	for attempt in 6:
		var species := MenuStyle.species(SPACE_POOL[_rng.randi() % SPACE_POOL.size()])
		if species != null:
			return species
	return null


# --- Lluvia de estrellas ------------------------------------------------------------------

func meteor_tonight() -> bool:
	return int(_flags().get("meteor_night", -1)) == GameState.game_day() and GameState.is_night()


func _update_meteors(day: int, _hour: float) -> void:
	var active := meteor_tonight() and _player.global_position.x < WorldBuilder.INTERIOR_X
	_meteor_sky.emitting = active
	_meteor_sky.global_position = _player.global_position + Vector3(0, 120, 0)
	if active and int(_flags().get("meteor_gift", -1)) != day:
		_flags()["meteor_gift"] = day
		_drop_fragment()


## Cae un fragmento brillante cerca del jugador: se recoge con "interact".
func _drop_fragment() -> void:
	var angle := _rng.randf() * TAU
	var x := _player.global_position.x + cos(angle) * 25.0
	var z := _player.global_position.z + sin(angle) * 25.0
	var at := Vector3(x, _world.surface_height_at(x, z), z)
	var glow := Sprite3D.new()
	glow.texture = Items.icon("comet-shard")
	glow.pixel_size = 0.04
	glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glow.modulate = Color(1.3, 1.3, 1.6)
	add_child(glow)
	glow.global_position = at + Vector3.UP * 0.5
	var point: Dictionary = {}
	point = _world.structures.add_point(at + Vector3.UP * 0.5, "Recoger el fragmento caído", func() -> void:
		var item: String = ["star-piece", "comet-shard", "stardust", "moon-stone"][_rng.randi() % 4]
		GameState.add_item(item, 1)
		GameState.notice.emit("¡Recogiste %s del cielo!" % Items.display_name(item))
		glow.queue_free()
		_world.structures.remove_point(point), 2.2)
	GameState.notice.emit("¡Algo brillante cayó del cielo cerca de ti!")


func _make_meteors() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 24
	particles.lifetime = 1.6
	particles.emitting = false
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-300, -200, -300), Vector3(600, 400, 600))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(250, 10, 250)
	process.direction = Vector3(1, -0.5, 0.3).normalized()
	process.spread = 8.0
	process.initial_velocity_min = 140.0
	process.initial_velocity_max = 200.0
	process.gravity = Vector3.ZERO
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 9.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.95, 0.75)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = material
	particles.draw_pass_1 = quad
	return particles


# --- Dominantes y Alfas --------------------------------------------------------------------

## Hace a un salvaje grande y fuerte (Alfa o dominante), con aura y premio al vencerlo.
func empower(actor: PokemonActor, hp_scale: float, aura: Color, reward: String, label: String) -> void:
	actor.hp_max *= hp_scale
	actor._heal_to(1.0)
	actor.set_meta(label, true)
	var light := OmniLight3D.new()
	light.light_color = aura
	light.omni_range = 4.0
	light.light_energy = 1.5
	light.position.y = 1.0
	actor.add_child(light)
	actor.stunned.connect(func(_a: PokemonActor) -> void:
		GameState.add_item(reward, 1)
		GameState.notice.emit("¡Venciste al %s %s! Premio: %s" % [label, actor.species.display_name, Items.display_name(reward)]), CONNECT_ONE_SHOT)


func _update_alphas() -> void:
	if _player.global_position.x > WorldBuilder.INTERIOR_X:
		return
	var day := GameState.game_day()
	for place: Dictionary in _world.layout.places_of("alpha"):
		var id := int(place["id"])
		var center := Vector3(float(place["x"]), 0, float(place["z"]))
		var near := Vector2(center.x - _player.global_position.x, center.z - _player.global_position.z).length() < ALPHA_RADIUS
		var actor: PokemonActor = _alphas.get(id)
		if actor != null and not is_instance_valid(actor):
			_alphas.erase(id)
			actor = null
		if near and actor == null and int(_flags().get("alpha:%d" % id, -1)) != day and _world.is_near_loaded(center):
			_flags()["alpha:%d" % id] = day
			var habitat := _world.habitat_at(center.x, center.z)
			var species := _spawner.pick_species(habitat, 0)
			if species == null:
				continue
			var spot := Vector3(center.x, _world.surface_height_at(center.x, center.z), center.z)
			actor = _spawner.spawn_species(species, spot, _rng.randf() < _spawner.shiny_chance(), false, false, 1.7)
			empower(actor, 2.5, Color(1.0, 0.2, 0.2), "rare-candy", "Alfa")
			_alphas[id] = actor
			GameState.notice.emit("¡Un %s Alfa vigila este territorio!" % species.display_name)


func _maybe_dominant() -> void:
	if _dominant != null and is_instance_valid(_dominant):
		return
	if _player.global_position.x > WorldBuilder.INTERIOR_X or _rng.randf() > DOMINANT_CHANCE:
		return
	var angle := _rng.randf() * TAU
	var x := _player.global_position.x + cos(angle) * 55.0
	var z := _player.global_position.z + sin(angle) * 55.0
	if not _world.is_near_loaded(Vector3(x, 0, z)) or _world.water_depth_at(x, z) > -0.3:
		return
	var species := _spawner.pick_species(_world.habitat_at(x, z), 0)
	if species == null:
		return
	_dominant = _spawner.spawn_species(species, Vector3(x, _world.surface_height_at(x, z), z), false, false, false, 1.5)
	empower(_dominant, 2.0, Color(1.0, 0.75, 0.2), "nugget", "dominante")
	GameState.add_news("Rotom: un %s dominante apareció en %s." % [species.display_name, _world.location_name(x, z)])
	GameState.notice.emit("Rotom: ¡un %s dominante anda cerca!" % species.display_name)
