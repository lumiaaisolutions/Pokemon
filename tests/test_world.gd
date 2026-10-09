extends Node
## Prueba del mundo: el agua nunca flota (el borde de cada superficie queda bajo el
## terreno), la costa no se inunda tierra adentro y los biomas existen.
## Uso: godot --headless --path . tests/test_world.tscn  (sale con 0 si todo pasa)

const WORLD_CONFIG := preload("res://world/world_config.tres")

var _failures: Array[String] = []


func _ready() -> void:
	var world := WorldBuilder.new()
	world.config = WORLD_CONFIG
	add_child(world)

	# Borde del agua enterrado: el terreno en el borde está por encima del nivel.
	var floating := 0
	var worst := INF
	var samples := world.water_edge_samples()
	for sample in samples:
		var ground := world.surface_height_at(sample.x, sample.z)
		var margin := ground - sample.w
		worst = minf(worst, margin)
		if margin < 0.02:
			floating += 1
	print("  bordes de agua revisados: %d, peor margen %.2f m" % [samples.size(), worst])
	_check(floating == 0, "%d puntos del borde del agua quedan sobre el terreno (flotan)" % floating)

	# Tierra adentro de la costa no queda bajo el nivel del mar.
	var flooded := 0
	var half := WORLD_CONFIG.size * 0.5
	var x := -half + 4.0
	while x < half:
		var z := -half + 4.0
		while z < WORLD_CONFIG.shore_z - 5.0:
			if world.river_info(x, z).x > 15.0 and Vector2(x, z).distance_to(WORLD_CONFIG.lake_center) > WORLD_CONFIG.lake_radius + 12.0 \
					and Vector2(x, z).distance_to(WORLD_CONFIG.swamp_center) > WORLD_CONFIG.swamp_radius + 5.0:
				if world.surface_height_at(x, z) < WORLD_CONFIG.sea_level + 0.3:
					flooded += 1
			z += 4.0
		x += 4.0
	_check(flooded == 0, "%d puntos de tierra adentro quedan bajo el nivel del mar" % flooded)

	# Los tres biomas y la costa existen.
	for biome in [WorldBuilder.Biome.MEADOW, WorldBuilder.Biome.FOREST, WorldBuilder.Biome.MOUNTAIN, WorldBuilder.Biome.BEACH]:
		_check(world._biome_area(biome) > 5000.0, "el bioma %d casi no existe" % biome)

	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_world: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
