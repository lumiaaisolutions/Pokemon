extends Node
## Prueba del mundo grande (4 × 4 km por zonas, generado por semilla): el agua nunca
## flota, tierra adentro no queda bajo el mar, existen los biomas y familias de suelo,
## pueblos, ríos, lagos y lugares; la misma semilla da el mismo mundo y otra semilla otro;
## las zonas cercanas se construyen con colisión y los interiores responden suelo plano.
## Uso: godot --headless --path . tests/test_world.tscn  (sale con 0 si todo pasa)

const WORLD_CONFIG := preload("res://world/world_config.tres")

var _failures: Array[String] = []


func _ready() -> void:
	var world := WorldBuilder.new()
	world.config = WORLD_CONFIG
	add_child(world)
	var layout := world.layout

	# Borde del agua enterrado: el terreno en el borde está por encima del nivel.
	var floating := 0
	var worst := INF
	var samples := world.water_edge_samples(INF)
	for sample in samples:
		var margin := layout.height_at(sample.x, sample.z) - sample.w
		worst = minf(worst, margin)
		if margin < 0.02:
			floating += 1
	print("  bordes de agua revisados: %d, peor margen %.2f m" % [samples.size(), worst])
	_check(samples.size() > 50, "hay muy pocos bordes de agua (%d)" % samples.size())
	_check(floating == 0, "%d puntos del borde del agua quedan sobre el terreno (flotan)" % floating)

	# Tierra adentro (lejos de la costa, ríos y lagos) no queda bajo el nivel del mar.
	var flooded := 0
	var half := WORLD_CONFIG.size * 0.5
	var x := -half + 8.0
	while x < half:
		var z := -half + 8.0
		while z < half - RegionLayout.SEA_BAND - 150.0:
			var river := layout.river_info(x, z)
			var near_lake := layout._lakes_near(x, z).any(func(l: Vector4) -> bool: return Vector2(x - l.x, z - l.y).length() < l.z + RegionLayout.LAKE_BANK + 4.0)
			if river.x > river.z * 0.5 + RegionLayout.RIVER_BANK + 4.0 and not near_lake:
				if layout.height_at(x, z) < layout.sea_level + 0.3:
					flooded += 1
			z += 16.0
		x += 16.0
	_check(flooded == 0, "%d puntos de tierra adentro quedan bajo el nivel del mar" % flooded)

	# Familias de suelo y biomas de la región.
	for biome in [WorldBuilder.Biome.MEADOW, WorldBuilder.Biome.FOREST, WorldBuilder.Biome.MOUNTAIN, WorldBuilder.Biome.BEACH]:
		_check(world._biome_area(biome) > 50000.0, "la familia de suelo %d casi no existe" % biome)
	var found := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 6000:
		found[layout.biome_at(rng.randf_range(-half, half), rng.randf_range(-half, half))] = true
	print("  biomas encontrados: %d de %d" % [found.size(), RegionLayout.Biome.size()])
	_check(found.size() >= 13, "solo hay %d biomas distintos" % found.size())

	# Pueblos, caminos, ríos, lagos y lugares.
	_check(layout.settlements.size() >= 10, "pocos asentamientos (%d)" % layout.settlements.size())
	_check(layout.roads.size() >= layout.settlements.size() - 1, "faltan caminos entre pueblos")
	_check(layout.rivers.size() >= 3 and layout.lakes.size() >= 5, "faltan ríos o lagos (%d, %d)" % [layout.rivers.size(), layout.lakes.size()])
	var caves := layout.places_of("cave")
	_check(caves.size() >= 2 and caves[0].has("exit"), "las cuevas deben ir por pares")
	for kind in ["ruins", "sanctuary", "hot_spring", "alpha"]:
		_check(not layout.places_of(kind).is_empty(), "no hay lugares de tipo %s" % kind)
	var first: Dictionary = layout.settlements[0]
	_check(Vector2(float(first["x"]), float(first["z"])).distance_to(layout.start) < 5.0, "el inicio debe estar en la plaza del pueblo inicial")
	_check((first["buildings"] as Array).any(func(b: Dictionary) -> bool: return b["kind"] == "center"), "el pueblo inicial necesita Centro Pokémon")

	# Misma semilla, mismo mundo; otra semilla, otro.
	var again := RegionLayout.new(layout.seed, WORLD_CONFIG.size)
	_check(again.start == layout.start and again.settlements.size() == layout.settlements.size(), "la misma semilla debe dar el mismo mundo")
	var other := RegionLayout.new(layout.seed + 1234, WORLD_CONFIG.size)
	_check(other.start != layout.start, "otra semilla debe dar otro mundo")

	# Zonas cercanas con colisión alrededor del inicio, sin salirse del borde.
	var start := world.start_position()
	_check(world.is_near_loaded(start), "la zona del inicio debe estar construida")
	_check(world.near_chunks().size() == 25, "deben construirse 5 × 5 zonas cercanas (%d)" % world.near_chunks().size())
	_check(absf(world.surface_height_at(start.x, start.z) - world.height_at(start.x, start.z)) < 0.05, "la malla y la altura analítica deben coincidir")
	_check(world.water_depth_at(start.x, start.z) < -0.3, "el inicio no debe estar en el agua")

	# Interiores: suelo plano a y = 0, sin agua.
	_check(world.surface_height_at(WorldBuilder.INTERIOR_X + 50.0, 3.0) == 0.0, "el interior debe tener suelo en y = 0")
	_check(world.water_depth_at(WorldBuilder.INTERIOR_X + 50.0, 3.0) < -100.0, "el interior no debe tener agua")

	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_world: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
