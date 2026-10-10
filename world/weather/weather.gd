class_name Weather
extends Node3D
## Clima por bioma y estación. Cada 2 horas del juego se decide el clima de cada bioma
## (determinista por semilla, día y bloque de horas) según su tabla y la estación; se
## muestra el del bioma donde está el jugador: lluvia, tormenta (con relámpagos),
## nieve, ventisca, tormenta de arena, ceniza volcánica, niebla, nublado o despejado.
## Cambia la luz y la niebla (ver DayNight) y el peso de aparición por tipo (WildSpawner).
## Estaciones de 7 días: Primavera, Verano, Otoño e Invierno.

enum Kind { CLEAR, CLOUDY, RAIN, STORM, SNOW, BLIZZARD, SAND, ASH, FOG }

const NAMES := ["Despejado", "Nublado", "Lluvia", "Tormenta", "Nieve", "Ventisca", "Tormenta de arena", "Ceniza", "Niebla"]
const ICONS := ["☀", "☁", "☂", "⚡", "❄", "❄", "≋", "≋", "≡"]
const SEASONS := ["Primavera", "Verano", "Otoño", "Invierno"]
const SEASON_DAYS := 7
const HOURS_PER_SLOT := 2.0
## Luz del sol y niebla extra por clima.
const LIGHT := [1.0, 0.7, 0.55, 0.38, 0.7, 0.5, 0.6, 0.5, 0.65]
const FOG := [0.0, 0.002, 0.004, 0.006, 0.006, 0.014, 0.012, 0.01, 0.02]

## Pesos por familia de clima: [despejado, nublado, lluvia, tormenta, nieve, ventisca, arena, ceniza, niebla].
const TABLES := {
	"temperate": [50, 15, 20, 7, 0, 0, 0, 0, 8],
	"jungle": [30, 10, 35, 15, 0, 0, 0, 0, 10],
	"dry": [60, 10, 3, 2, 0, 0, 25, 0, 0],
	"cold": [30, 15, 0, 0, 40, 12, 0, 0, 3],
	"volcano": [55, 5, 0, 0, 0, 0, 0, 40, 0],
	"gloom": [25, 15, 20, 5, 0, 0, 0, 0, 35],
	"coast": [50, 15, 18, 12, 0, 0, 0, 0, 5],
}

## Factores que leen DayNight y el resto del juego.
static var light_factor := 1.0
static var fog_extra := 0.0
static var current: Kind = Kind.CLEAR
## Clima forzado (capturas y pruebas; -1 = el que toca).
static var forced := -1
## Destello de un relámpago (energía extra del sol, se apaga sola).
static var flash := 0.0

@export var world_path: NodePath
@export var player_path: NodePath

var _world: WorldBuilder
var _player: Node3D
var _particles: Dictionary = {}
var _lightning := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"weather")
	_rng.randomize()
	_world = get_node(world_path) as WorldBuilder
	_player = get_node(player_path) as Node3D
	_particles[Kind.RAIN] = _make_particles(Color(0.7, 0.8, 1.0, 0.7), Vector2(0.03, 0.6), 900, Vector3(0, -22, 0), 1.2)
	_particles[Kind.SNOW] = _make_particles(Color(1, 1, 1, 0.9), Vector2(0.12, 0.12), 700, Vector3(0.6, -2.2, 0.3), 6.0)
	_particles[Kind.SAND] = _make_particles(Color(0.85, 0.7, 0.45, 0.7), Vector2(0.25, 0.08), 900, Vector3(14, -0.5, 3), 2.0)
	_particles[Kind.ASH] = _make_particles(Color(0.35, 0.33, 0.32, 0.8), Vector2(0.1, 0.1), 500, Vector3(0.5, -1.0, 0.2), 6.0)
	for kind: int in _particles:
		add_child(_particles[kind])


static func season(day: int) -> int:
	return (day / SEASON_DAYS) % 4


static func season_name(day: int) -> String:
	return SEASONS[season(day)]


static func _family(biome: RegionLayout.Biome) -> String:
	match biome:
		RegionLayout.Biome.JUNGLE:
			return "jungle"
		RegionLayout.Biome.DESERT, RegionLayout.Biome.CANYON, RegionLayout.Biome.MESA, RegionLayout.Biome.SAVANNA:
			return "dry"
		RegionLayout.Biome.TUNDRA, RegionLayout.Biome.MOUNTAIN:
			return "cold"
		RegionLayout.Biome.VOLCANO:
			return "volcano"
		RegionLayout.Biome.SWAMP, RegionLayout.Biome.TOXIC_SWAMP, RegionLayout.Biome.DARK_FOREST, RegionLayout.Biome.MUSHROOM:
			return "gloom"
		RegionLayout.Biome.BEACH, RegionLayout.Biome.SEA:
			return "coast"
	return "temperate"


## Clima de un bioma en un momento (determinista): tabla del bioma con la estación.
static func weather_for(biome: RegionLayout.Biome, play_time: float, world_seed: int) -> Kind:
	var day := int(play_time / 1440.0)
	var hour := fmod(play_time / 60.0, 24.0)
	var slot := day * 12 + int(hour / HOURS_PER_SLOT)
	var weights: Array = (TABLES[_family(biome)] as Array).duplicate()
	match season(day):
		0: # Primavera: más lluvia.
			weights[Kind.RAIN] = int(weights[Kind.RAIN]) * 2
		1: # Verano: más sol y tormentas.
			weights[Kind.CLEAR] = int(weights[Kind.CLEAR]) * 2
			weights[Kind.STORM] = int(weights[Kind.STORM]) * 2
		2: # Otoño: niebla y nublado.
			weights[Kind.FOG] = int(weights[Kind.FOG]) * 2 + 5
			weights[Kind.CLOUDY] = int(weights[Kind.CLOUDY]) * 2
		3: # Invierno: la lluvia de las zonas templadas cae como nieve.
			if _family(biome) in ["temperate", "gloom", "coast"]:
				weights[Kind.SNOW] = int(weights[Kind.RAIN]) + 5
				weights[Kind.RAIN] = 0
				weights[Kind.STORM] = 0
			else:
				weights[Kind.SNOW] = int(weights[Kind.SNOW]) * 2
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(biome), slot, world_seed])
	var total := 0
	for w in weights:
		total += int(w)
	var roll := rng.randi_range(1, maxi(total, 1))
	for i in weights.size():
		roll -= int(weights[i])
		if roll <= 0:
			return i as Kind
	return Kind.CLEAR


func current_name() -> String:
	return NAMES[current]


func _process(delta: float) -> void:
	if _world == null or _player == null:
		return
	var pos := _player.global_position
	var indoors := pos.x > WorldBuilder.INTERIOR_X
	var kind := Kind.CLEAR if indoors else weather_for(_world.region_biome_at(pos.x, pos.z), GameState.play_time, _world.config.seed)
	if forced >= 0 and not indoors:
		kind = forced as Kind
	current = kind
	flash = move_toward(flash, 0.0, delta * 8.0)
	light_factor = move_toward(light_factor, LIGHT[kind], delta * 0.3)
	fog_extra = move_toward(fog_extra, FOG[kind], delta * 0.004)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position = camera.global_position + Vector3(0, 8, 0)
	for particle_kind: int in _particles:
		var on := not indoors and (particle_kind == kind or (particle_kind == Kind.RAIN and kind == Kind.STORM) \
				or (particle_kind == Kind.SNOW and kind == Kind.BLIZZARD))
		(_particles[particle_kind] as GPUParticles3D).emitting = on
	var snow := _particles[Kind.SNOW] as GPUParticles3D
	snow.amount_ratio = 1.0 if kind == Kind.BLIZZARD else 0.5
	# Relámpagos en tormenta.
	if kind == Kind.STORM and not indoors:
		_lightning -= delta
		if _lightning <= 0.0:
			_lightning = _rng.randf_range(4.0, 12.0)
			_flash()


func _flash() -> void:
	flash = 2.5


## Factor de aparición por tipo con el clima actual.
func type_factor(types: Array) -> float:
	var table: Dictionary = {}
	match current:
		Kind.CLEAR:
			table = {PokemonTypes.Type.FIRE: 1.5, PokemonTypes.Type.GRASS: 1.3}
		Kind.RAIN:
			table = {PokemonTypes.Type.WATER: 2.5, PokemonTypes.Type.BUG: 0.6, PokemonTypes.Type.FIRE: 0.5}
		Kind.STORM:
			table = {PokemonTypes.Type.ELECTRIC: 3.0, PokemonTypes.Type.WATER: 2.0, PokemonTypes.Type.FIRE: 0.4}
		Kind.SNOW, Kind.BLIZZARD:
			table = {PokemonTypes.Type.ICE: 4.0, PokemonTypes.Type.FIRE: 0.5}
		Kind.SAND:
			table = {PokemonTypes.Type.GROUND: 2.5, PokemonTypes.Type.ROCK: 2.0, PokemonTypes.Type.STEEL: 1.5}
		Kind.ASH:
			table = {PokemonTypes.Type.FIRE: 2.0, PokemonTypes.Type.ROCK: 1.5}
		Kind.FOG:
			table = {PokemonTypes.Type.GHOST: 2.5, PokemonTypes.Type.PSYCHIC: 1.5, PokemonTypes.Type.FAIRY: 1.5}
		Kind.CLOUDY:
			table = {PokemonTypes.Type.FAIRY: 1.3, PokemonTypes.Type.DARK: 1.2}
	var factor := 1.0
	for t in types:
		factor = maxf(factor, float(table.get(t, 1.0))) if float(table.get(t, 1.0)) >= 1.0 else factor * float(table.get(t, 1.0))
	return factor


func _make_particles(color: Color, size: Vector2, amount: int, velocity: Vector3, lifetime: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 60, 80))
	particles.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(28, 2, 28)
	process.direction = velocity.normalized()
	process.spread = 4.0
	process.initial_velocity_min = velocity.length() * 0.85
	process.initial_velocity_max = velocity.length() * 1.1
	process.gravity = Vector3.ZERO
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if size.y > size.x else BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = material
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles
