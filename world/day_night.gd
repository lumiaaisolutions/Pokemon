class_name DayNight
extends Node
## Ciclo de día y noche con el reloj del juego (1 minuto real = 1 hora; el día dura 24
## minutos). Mueve el sol, cambia su color y energía, el cielo, la niebla, la luz
## ambiente y el tinte de lo que no recibe luz (sprites, hierba y agua). De noche
## GameState.dark = true (Ocaso Ball, Pokémon nocturnos).

@export var sun_path: NodePath
@export var environment_path: NodePath

## [hora, color del sol, energía, cielo arriba, horizonte, tinte, ambiente]
const KEYS := [
	[0.0, Color(0.45, 0.55, 0.9), 0.3, Color(0.03, 0.05, 0.14), Color(0.08, 0.1, 0.22), Color(0.42, 0.48, 0.72), 0.5],
	[5.0, Color(0.5, 0.55, 0.85), 0.3, Color(0.06, 0.08, 0.2), Color(0.2, 0.18, 0.3), Color(0.5, 0.52, 0.75), 0.5],
	[6.5, Color(1.0, 0.6, 0.4), 0.55, Color(0.35, 0.45, 0.75), Color(0.95, 0.65, 0.45), Color(0.9, 0.78, 0.7), 0.45],
	[9.0, Color(1.0, 0.96, 0.88), 1.0, Color(0.38, 0.6, 0.9), Color(0.75, 0.85, 0.95), Color(1, 1, 1), 0.55],
	[16.5, Color(1.0, 0.95, 0.85), 0.95, Color(0.38, 0.6, 0.9), Color(0.75, 0.85, 0.95), Color(1, 1, 1), 0.55],
	[18.5, Color(1.0, 0.55, 0.35), 0.55, Color(0.3, 0.35, 0.65), Color(0.98, 0.55, 0.4), Color(0.92, 0.72, 0.66), 0.42],
	[20.0, Color(0.55, 0.5, 0.85), 0.3, Color(0.08, 0.08, 0.22), Color(0.3, 0.2, 0.35), Color(0.52, 0.52, 0.78), 0.5],
	[24.0, Color(0.45, 0.55, 0.9), 0.3, Color(0.03, 0.05, 0.14), Color(0.08, 0.1, 0.22), Color(0.42, 0.48, 0.72), 0.5],
]

## Luz en interiores (Interiors): 1 afuera, menos en edificios y mazmorras.
static var interior_light := 1.0

var _sun: DirectionalLight3D
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _base_fog := 0.0
var _lamps_on := false


## Fuerza de los faroles encendidos (ver Structures: alcance LAMP_RANGE).
const LAMP_ENERGY := 2.4

func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	var world_environment := get_node_or_null(environment_path) as WorldEnvironment
	if world_environment != null:
		_environment = world_environment.environment
		_sky = _environment.sky.sky_material as ProceduralSkyMaterial if _environment.sky != null else null
		_base_fog = _environment.fog_density
	if _sun != null:
		_sun.shadow_enabled = GameOptions.shadows_enabled()
	_apply(GameState.clock_hour())


func _process(_delta: float) -> void:
	_apply(GameState.clock_hour())


func _apply(hour: float) -> void:
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in range(KEYS.size() - 1):
		if hour >= KEYS[i][0] and hour <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t := inverse_lerp(float(a[0]), float(b[0]), hour)
	var tint: Color = (a[5] as Color).lerp(b[5], t)
	RenderingServer.global_shader_parameter_set("time_tint", tint)
	GameState.dark = hour < 5.5 or hour >= 20.0
	if _sun != null:
		# De día el sol recorre el cielo de este a oeste; de noche queda la luna (luz tenue y fría).
		var daylight := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
		var elevation := lerpf(12.0, 65.0, sin(daylight * PI)) if hour >= 6.0 and hour <= 18.0 else 35.0
		var azimuth := lerpf(-70.0, 70.0, daylight) if hour >= 6.0 and hour <= 18.0 else 150.0
		_sun.rotation_degrees = Vector3(-elevation, azimuth, 0.0)
		_sun.light_color = (a[1] as Color).lerp(b[1], t)
		var sun_energy := (lerpf(float(a[2]), float(b[2]), t) * Weather.light_factor + Weather.flash) * interior_light
		# Luz propia cálida en interiores (decisión de Fernando): nunca a oscuras de noche,
		# aunque el sol casi no aporte nada a esa hora. Afuera (interior_light = 1) no cambia.
		if interior_light < 1.0:
			sun_energy = maxf(sun_energy, 0.5)
			_sun.light_color = _sun.light_color.lerp(Color(1.0, 0.92, 0.78), 0.65)
		_sun.light_energy = sun_energy
	if _environment != null:
		var ambient := lerpf(float(a[6]), float(b[6]), t) * (1.0 if interior_light >= 1.0 else 0.8)
		if interior_light < 1.0:
			ambient = maxf(ambient, 0.5)
		_environment.ambient_light_energy = ambient
		_environment.fog_light_color = (a[4] as Color).lerp(b[4], t)
		_environment.fog_density = _base_fog + Weather.fog_extra
	# Faroles de los pueblos: se encienden de noche (más fuertes desde el 2026-10-10:
	# Fernando reportó que alumbraban poco).
	var lamps_on := hour < 6.5 or hour >= 18.5
	if lamps_on != _lamps_on:
		_lamps_on = lamps_on
		for light in get_tree().get_nodes_in_group(&"night_lights"):
			(light as Light3D).light_energy = LAMP_ENERGY if lamps_on else 0.0
		for material in BuildingModels.window_materials:
			material.emission_energy_multiplier = 0.35 if lamps_on else 0.0
	if _sky != null:
		_sky.sky_top_color = (a[3] as Color).lerp(b[3], t)
		_sky.sky_horizon_color = (a[4] as Color).lerp(b[4], t)
		_sky.ground_horizon_color = _sky.sky_horizon_color


## Texto de la hora para el HUD ("08:30").
static func clock_text(hour: float) -> String:
	return "%02d:%02d" % [int(hour) % 24, int(fmod(hour, 1.0) * 60.0)]
