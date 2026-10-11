class_name TownIdentity
extends RefCounted
## Identidad de cada pueblo (acordado con Fernando el 2026-10-10): un tema según su bioma
## y tamaño decide el monumento de la plaza, la decoración de alrededor y el subtítulo
## del cartel del lugar ("Pueblo Raíz · pueblo agrícola").
## Costa → pesquero · montaña/tundra fría → minero o alpino · pradera/flores/sabana →
## agrícola · bosque/selva → leñador · desierto/cañón/volcán → oasis · ciudades → comercial.

const NAMES := {"fishing": "pueblo pesquero", "mining": "pueblo minero", "farm": "pueblo agrícola", "lumber": "pueblo leñador",
		"oasis": "pueblo del oasis", "alpine": "pueblo alpino", "commercial": "ciudad comercial"}

## Edificio único por tema (pueblos ×2 con identidad, 2026-10-11): 1–2 por pueblo con
## interior y función simple (ver Interiors._build_landmark_room).
const LANDMARK_OF := {"fishing": "aquarium", "mining": "factory", "farm": "market_hall", "lumber": "library",
		"oasis": "museum", "alpine": "observatory", "commercial": "casino"}
const LANDMARK_NAMES := {"aquarium": "Acuario", "factory": "Fábrica", "market_hall": "Mercado", "library": "Biblioteca",
		"museum": "Museo", "observatory": "Observatorio", "casino": "Casino de Juegos"}


static func theme_of(settlement: Dictionary) -> String:
	if settlement.get("kind", "") == "city":
		return "commercial"
	match int(settlement.get("biome", 0)):
		RegionLayout.Biome.BEACH, RegionLayout.Biome.SEA:
			return "fishing"
		RegionLayout.Biome.MOUNTAIN, RegionLayout.Biome.CANYON:
			return "mining"
		RegionLayout.Biome.TUNDRA:
			return "alpine"
		RegionLayout.Biome.FOREST, RegionLayout.Biome.JUNGLE, RegionLayout.Biome.DARK_FOREST, RegionLayout.Biome.MUSHROOM, RegionLayout.Biome.SWAMP, RegionLayout.Biome.TOXIC_SWAMP:
			return "lumber"
		RegionLayout.Biome.DESERT, RegionLayout.Biome.MESA, RegionLayout.Biome.VOLCANO:
			return "oasis"
	return "farm"


## Decora el pueblo: monumento al centro, aros de jardineras y bancas, y los objetos
## del tema entre los edificios (sin taparlos ni los caminos).
static func decorate(structures: Structures, parent: Node3D, settlement: Dictionary) -> void:
	var theme := theme_of(settlement)
	settlement["theme"] = theme
	var root := Node3D.new()
	root.name = "Identity_" + String(settlement["name"]).replace(" ", "")
	parent.add_child(root)
	var cx := float(settlement["x"])
	var cz := float(settlement["z"])
	var y := float(settlement["height"]) - 0.05
	var radius := float(settlement["radius"])
	root.position = Vector3(cx, y, cz)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(settlement["name"]) ^ 9173
	# El monumento va en el hueco angular mas grande entre los edificios, nunca sobre la
	# linea que une un edificio con el centro de la plaza (reportado por QA, 2026-10-11:
	# en el pueblo inicial el molino tapaba la puerta del Centro, ver _monument_spot()).
	var monument := Node3D.new()
	root.add_child(monument)
	monument.position = _monument_spot(settlement)
	_monument(structures, monument, theme)
	# Plaza: jardineras y bancas en aro alrededor del monumento.
	for i in 6:
		var angle := TAU * i / 6.0 + 0.3
		var at := Vector3(cos(angle), 0, sin(angle)) * 6.5
		if i % 2 == 0:
			# Macetón redondo de piedra con borde, tierra y un arbusto de flores (B2W2).
			structures._cylinder(root, 0.95, 0.55, at + Vector3(0, 0.27, 0), Color(0.78, 0.74, 0.68), 1.05, 16)
			structures._cylinder(root, 0.85, 0.06, at + Vector3(0, 0.56, 0), Color(0.42, 0.3, 0.2), -1.0, 16)
			var bush: Texture2D = load(["res://art/world/b2w2/flower_bush_pink.png", "res://art/world/b2w2/flowers_yellow.png", "res://art/world/b2w2/lavender.png"][i / 2 % 3])
			structures._decor_sprite(root, bush, at + Vector3(0, 0.55, 0))
			# Sólido (física de mobiliario, 2026-10-10): el jugador se para encima al saltar.
			structures._cylinder_collider(root, 1.0, 1.1, at + Vector3(0, 0.55, 0))
			structures._furniture(Vector2(cx, cz) + Vector2(at.x, at.z), 1.3)
		else:
			var bench := BuildingModels.instance("bench", i)
			if not bench.is_empty():
				var node: Node3D = bench["node"]
				node.position = at
				node.rotation.y = -angle + PI * 0.5
				root.add_child(node)
				var bench_size: Vector3 = bench["size"]
				# Colisión a la medida de la banca (hija del propio nodo: hereda su giro).
				structures._collider(node, Vector3(bench_size.x * 0.85, bench_size.y, bench_size.z * 0.85), Vector3(0, bench_size.y * 0.5, 0), false)
				structures._furniture(Vector2(cx, cz) + Vector2(at.x, at.z), maxf(bench_size.x, bench_size.z) * 0.55 + 0.2)
	# Objetos del tema entre los edificios: con los pueblos ×2 (más grandes) 16 piezas
	# fijas se veían como pasto liso con un edificio suelto (reportado por Fernando); la
	# cantidad ahora escala con el área del pueblo y se reparte desde cerca de la plaza
	# hasta el borde (antes solo en un aro delgado de afuera), con relleno genérico
	# (faroles, bancas, cercas, flores) además del propio del tema para que no queden
	# huecos vacíos.
	var buildings: Array = settlement["buildings"]
	var prop_count := clampi(roundi(radius * radius / 85.0), 16, 70)
	for i in prop_count:
		var angle := rng.randf() * TAU
		var distance := radius * rng.randf_range(0.22, 0.95)
		var local := Vector3(cos(angle), 0, sin(angle)) * distance
		var world_x := cx + local.x
		var world_z := cz + local.z
		if structures.world.layout.road_info(world_x, world_z).x < RegionLayout.ROAD_WIDTH + 1.5:
			continue
		if Vector2(local.x, local.z).length() < 9.0:
			continue # No tapar el monumento ni la plaza principal.
		var blocked := false
		for b: Dictionary in buildings:
			if Vector2(float(b["x"]) - world_x, float(b["z"]) - world_z).length() < maxf(float(b["w"]), float(b["d"])) * 0.75 + 2.5:
				blocked = true
				break
		if blocked:
			continue
		if rng.randf() < 0.3:
			_filler_prop(structures, root, local, rng)
		else:
			_theme_prop(structures, root, theme, local, rng)
	# Pueblos ×2 (2026-10-11): un segundo barrio con su propia plaza chica (aljibe y
	# bancas), del otro lado del pueblo, y la parada de transporte junto a la principal.
	if settlement["kind"] in ["city", "town"]:
		_barrio(structures, root, settlement, rng)
	TownTransport.place_booth(structures, parent, settlement)


## Segundo barrio (pueblos ×2, 2026-10-11): una plaza chica del lado opuesto al monumento
## principal, con un aljibe y 2 bancas; da la sensación de varias plazas y calles sin
## tapar ningún edificio ni camino.
static func _barrio(structures: Structures, root: Node3D, settlement: Dictionary, rng: RandomNumberGenerator) -> void:
	var cx := float(settlement["x"])
	var cz := float(settlement["z"])
	var radius := float(settlement["radius"])
	var buildings: Array = settlement["buildings"]
	var chosen := Vector3.ZERO
	var found := false
	for attempt in 10:
		var angle := rng.randf_range(0.0, TAU)
		var distance := radius * rng.randf_range(0.5, 0.7)
		var local := Vector3(cos(angle), 0, sin(angle)) * distance
		var world_x := cx + local.x
		var world_z := cz + local.z
		if structures.world.layout.road_info(world_x, world_z).x < RegionLayout.ROAD_WIDTH + 2.0:
			continue
		var blocked := false
		for b: Dictionary in buildings:
			if Vector2(float(b["x"]) - world_x, float(b["z"]) - world_z).length() < maxf(float(b["w"]), float(b["d"])) * 0.75 + 4.0:
				blocked = true
				break
		if not blocked:
			chosen = local
			found = true
			break
	if not found:
		return
	var plaza := Node3D.new()
	plaza.name = "Barrio_" + String(settlement["name"]).replace(" ", "")
	plaza.position = chosen
	root.add_child(plaza)
	structures._cylinder(plaza, 1.1, 0.75, Vector3(0, 0.37, 0), Color(0.55, 0.54, 0.5))
	structures._cylinder(plaza, 0.9, 0.08, Vector3(0, 0.78, 0), Color(0.3, 0.42, 0.6))
	structures._collider(plaza, Vector3(2.2, 1.0, 2.2), Vector3(0, 0.5, 0), false)
	structures._furniture(Vector2(cx, cz) + Vector2(chosen.x, chosen.z), 1.3)
	for i in 2:
		var angle := PI * i + 0.5
		var at := Vector3(cos(angle), 0, sin(angle)) * 2.4
		var bench := BuildingModels.instance("bench", i)
		if bench.is_empty():
			continue
		var node: Node3D = bench["node"]
		node.position = at
		node.rotation.y = -angle + PI * 0.5
		plaza.add_child(node)
		var bench_size: Vector3 = bench["size"]
		structures._collider(node, Vector3(bench_size.x * 0.85, bench_size.y, bench_size.z * 0.85), Vector3(0, bench_size.y * 0.5, 0), false)
		structures._furniture(Vector2(cx, cz) + Vector2(chosen.x + at.x, chosen.z + at.z), maxf(bench_size.x, bench_size.z) * 0.55 + 0.2)


## Dónde poner el monumento sin tapar ninguna puerta (QA, 2026-10-11): se busca el hueco
## angular más grande entre los edificios, visto desde el centro de la plaza, y el
## monumento se pone justo ahí; así nunca queda sobre la línea que une un edificio con
## el centro (por donde se ve su puerta desde la plaza, incluida la del Centro Pokémon).
static func _monument_spot(settlement: Dictionary) -> Vector3:
	var cx := float(settlement["x"])
	var cz := float(settlement["z"])
	var radius := float(settlement["radius"])
	var buildings: Array = settlement.get("buildings", [])
	var distance := minf(13.0, radius * 0.16)
	if buildings.is_empty():
		return Vector3(distance, 0, 0)
	var angles: Array[float] = []
	for b: Dictionary in buildings:
		angles.append(atan2(float(b["z"]) - cz, float(b["x"]) - cx))
	angles.sort()
	var best_angle: float = angles[0]
	var best_gap := -1.0
	for i in angles.size():
		var a: float = angles[i]
		var b: float = angles[(i + 1) % angles.size()]
		var gap: float = b - a
		if gap < 0.0:
			gap += TAU
		if gap > best_gap:
			best_gap = gap
			best_angle = a + gap * 0.5
	return Vector3(cos(best_angle), 0, sin(best_angle)) * distance


static func _monument(structures: Structures, root: Node3D, theme: String) -> void:
	match theme:
		"commercial":
			# Fuente monumental con agua y estatua de Pokéball.
			structures._cylinder(root, 3.0, 0.7, Vector3(0, 0.35, 0), Color(0.75, 0.75, 0.78))
			structures._cylinder(root, 2.6, 0.1, Vector3(0, 0.72, 0), Color(0.35, 0.6, 0.9))
			structures._cylinder(root, 0.5, 1.6, Vector3(0, 1.4, 0), Color(0.78, 0.78, 0.8))
			var ball := structures._cylinder(root, 0.8, 0.8, Vector3(0, 2.6, 0), Color(0.9, 0.25, 0.25))
			ball.scale = Vector3(1, 1, 1)
			structures._collider(root, Vector3(6.0, 1.5, 6.0), Vector3(0, 0.75, 0), false)
			root.add_child(structures._steam(Color(0.8, 0.9, 1.0, 0.6)))
		"farm":
			var mill := BuildingModels.instance("windmill", 0)
			if not mill.is_empty():
				var node: Node3D = mill["node"]
				# El modelo de B2W2 es de escala de ruta: en la plaza va a 0.6.
				node.scale = Vector3.ONE * 0.6
				root.add_child(node)
				var size: Vector3 = (mill["size"] as Vector3) * 0.6
				structures._collider(root, Vector3(size.x * 0.6, size.y, size.z * 0.6), Vector3(0, size.y * 0.5, 0), false)
			else:
				_statue(structures, root, Color(0.55, 0.45, 0.3))
		"fishing":
			# Ancla gigante sobre una base, con boyas.
			structures._box(root, Vector3(2.4, 0.6, 2.4), Vector3(0, 0.3, 0), Color(0.6, 0.62, 0.66))
			structures._box(root, Vector3(0.35, 3.2, 0.35), Vector3(0, 2.2, 0), Color(0.3, 0.32, 0.38))
			structures._box(root, Vector3(2.2, 0.35, 0.35), Vector3(0, 3.4, 0), Color(0.3, 0.32, 0.38))
			structures._box(root, Vector3(2.6, 0.35, 0.35), Vector3(0, 0.95, 0), Color(0.3, 0.32, 0.38))
			for side in [-1.0, 1.0]:
				structures._cylinder(root, 0.35, 0.5, Vector3(side * 1.6, 0.85, 1.2), Color(0.95, 0.4, 0.3))
			structures._collider(root, Vector3(2.4, 3.6, 2.4), Vector3(0, 1.8, 0), false)
			# El pescador del pueblo regala la Caña Vieja (una vez por partida; pesca).
			structures.add_point(root.global_position + Vector3(2.6, 0.5, 0), "Hablar con el pescador", Callable(TownIdentity, "_give_rod"), 3.0)
		"mining":
			# Vagoneta con piedras brillantes sobre rieles.
			for side in [-0.5, 0.5]:
				structures._box(root, Vector3(0.12, 0.08, 5.0), Vector3(side, 0.05, 0), Color(0.45, 0.42, 0.4))
			structures._box(root, Vector3(1.6, 0.9, 2.0), Vector3(0, 0.75, 0), Color(0.45, 0.32, 0.2))
			structures._box(root, Vector3(1.3, 0.3, 1.7), Vector3(0, 1.25, 0), Color(0.55, 0.85, 0.95), 0.6)
			structures._collider(root, Vector3(1.6, 1.4, 2.2), Vector3(0, 0.7, 0), false)
		"lumber":
			# Tótem de madera tallado.
			for i in 4:
				structures._box(root, Vector3(1.0, 0.9, 1.0), Vector3(0, 0.45 + i * 0.9, 0), [Color(0.55, 0.38, 0.22), Color(0.45, 0.3, 0.18)][i % 2])
			structures._box(root, Vector3(2.4, 0.25, 0.4), Vector3(0, 3.2, 0), Color(0.6, 0.42, 0.25))
			structures._collider(root, Vector3(1.2, 3.8, 1.2), Vector3(0, 1.9, 0), false)
		"oasis":
			# Pozo con palmeras alrededor.
			structures._cylinder(root, 1.6, 0.9, Vector3(0, 0.45, 0), Color(0.82, 0.7, 0.5))
			structures._cylinder(root, 1.3, 0.1, Vector3(0, 0.88, 0), Color(0.3, 0.6, 0.85))
			for i in 3:
				var angle := TAU * i / 3.0
				structures._decor_sprite(root, PropArt.texture("palm"), Vector3(cos(angle) * 3.0, 0, sin(angle) * 3.0))
			structures._collider(root, Vector3(3.2, 1.0, 3.2), Vector3(0, 0.5, 0), false)
		"alpine":
			# Hoguera central con piedras y humo.
			for i in 8:
				var angle := TAU * i / 8.0
				structures._box(root, Vector3(0.5, 0.4, 0.5), Vector3(cos(angle) * 1.2, 0.2, sin(angle) * 1.2), Color(0.5, 0.5, 0.52))
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.6, 0.3)
			light.omni_range = 9.0
			light.light_energy = 1.2
			light.position = Vector3(0, 1.0, 0)
			root.add_child(light)
			root.add_child(structures._steam(Color(0.85, 0.85, 0.9, 0.5)))
			structures._collider(root, Vector3(2.8, 0.8, 2.8), Vector3(0, 0.4, 0), false)
		_:
			_statue(structures, root, Color(0.7, 0.7, 0.72))


## Regalo del pescador del pueblo pesquero: la Caña Vieja, una vez por partida (pesca;
## acordado con Fernando el 2026-10-10). Se guarda en GameState.world_flags.
static func _give_rod() -> void:
	if GameState.world_flags.get("fisherman_rod_given", false):
		GameState.notice.emit("Ya te regalé mi caña, ¡que tengas buena pesca!")
		return
	GameState.world_flags["fisherman_rod_given"] = true
	GameState.add_item("old-rod", 1)
	AudioBus.play_jingle("me_item")
	GameState.notice.emit("El pescador del pueblo te regala una Caña Vieja. ¡A pescar!")


static func _statue(structures: Structures, root: Node3D, color: Color) -> void:
	structures._box(root, Vector3(2.0, 1.0, 2.0), Vector3(0, 0.5, 0), color.darkened(0.2))
	structures._cylinder(root, 0.6, 2.0, Vector3(0, 2.0, 0), color)
	structures._collider(root, Vector3(2.0, 3.0, 2.0), Vector3(0, 1.5, 0), false)


## Relleno genérico entre los edificios (pueblos ×2 sin áreas vacías, pedido de
## Fernando con captura: "llena calles, plazas y barrios... sin dejar áreas vacías"): un
## farol, una banca, un tramo de cerca o flores, igual en cualquier pueblo sin depender
## de su tema (el tema ya pone lo suyo en _theme_prop).
static func _filler_prop(structures: Structures, root: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var world_xz := Vector2(root.position.x, root.position.z)
	var pick := rng.randi() % 4
	if pick == 0:
		var lamp := BuildingModels.instance("lamp", rng.randi())
		if lamp.is_empty():
			return
		var node: Node3D = lamp["node"]
		node.position = at
		root.add_child(node)
		structures._collider(root, Vector3(0.4, 3.0, 0.4), at + Vector3(0, 1.5, 0), false)
		structures._furniture(world_xz + Vector2(at.x, at.z), 0.5)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.55)
		light.omni_range = 11.0
		light.omni_attenuation = 1.1
		light.light_specular = 0.0
		light.light_energy = 0.0
		light.position = at + Vector3(0, (lamp["size"] as Vector3).y, 0)
		light.add_to_group(&"night_lights")
		root.add_child(light)
	elif pick == 1:
		var bench := BuildingModels.instance("bench", rng.randi())
		if bench.is_empty():
			return
		var node: Node3D = bench["node"]
		node.position = at
		node.rotation.y = rng.randf() * TAU
		root.add_child(node)
		var bench_size: Vector3 = bench["size"]
		structures._collider(node, Vector3(bench_size.x * 0.85, bench_size.y, bench_size.z * 0.85), Vector3(0, bench_size.y * 0.5, 0), false)
		structures._furniture(world_xz + Vector2(at.x, at.z), maxf(bench_size.x, bench_size.z) * 0.55 + 0.2)
	elif pick == 2:
		var fence := BuildingModels.instance("fence", rng.randi())
		if fence.is_empty():
			return
		var node: Node3D = fence["node"]
		node.position = at
		node.rotation.y = rng.randf() * TAU
		root.add_child(node)
		var fence_size: Vector3 = fence["size"]
		structures._collider(node, Vector3(fence_size.x, maxf(fence_size.y, 1.0), maxf(fence_size.z, 0.35)), Vector3(0, maxf(fence_size.y, 1.0) * 0.5, 0), false)
		structures._furniture(world_xz + Vector2(at.x, at.z), maxf(fence_size.x, fence_size.z) * 0.5 + 0.2)
	else:
		var flowers: Array = [load("res://art/world/b2w2/flowers_yellow.png"), load("res://art/world/b2w2/flower_bush_pink.png"), load("res://art/world/b2w2/lavender.png")]
		structures._decor_sprite(root, flowers[rng.randi() % flowers.size()], at)


static func _theme_prop(structures: Structures, root: Node3D, theme: String, at: Vector3, rng: RandomNumberGenerator) -> void:
	# Centro del asentamiento en el mundo (root no gira): posición de mobiliario para que
	# los habitantes lo rodeen (física de mobiliario, acordado con Fernando el 2026-10-10).
	var world_xz := Vector2(root.position.x, root.position.z)
	match theme:
		"farm":
			# Surcos de cultivo o pacas de heno.
			if rng.randf() < 0.5:
				for row in 4:
					structures._box(root, Vector3(4.0, 0.25, 0.5), at + Vector3(0, 0.12, row * 0.9), Color(0.45, 0.32, 0.2))
					structures._decor_sprite(root, PropArt.texture("tuft_green"), at + Vector3(-1.2 + row * 0.4, 0.25, row * 0.9))
			else:
				structures._cylinder(root, 0.6, 0.9, at + Vector3(0, 0.45, 0), Color(0.88, 0.75, 0.4))
				structures._collider(root, Vector3(1.2, 0.9, 1.2), at + Vector3(0, 0.45, 0), false)
				structures._furniture(world_xz + Vector2(at.x, at.z), 0.9)
		"fishing":
			# Barcas volteadas, redes y barriles.
			structures._box(root, Vector3(3.0, 0.6, 1.2), at + Vector3(0, 0.3, 0), Color(0.3, 0.5, 0.75))
			structures._cylinder(root, 0.4, 0.8, at + Vector3(2.0, 0.4, 0.6), Color(0.5, 0.35, 0.22))
			structures._collider(root, Vector3(3.0, 0.8, 1.4), at + Vector3(0, 0.4, 0), false)
			structures._furniture(world_xz + Vector2(at.x, at.z), 1.7)
		"mining":
			structures._decor_sprite(root, PropArt.texture("boulder"), at)
			structures._box(root, Vector3(1.0, 0.8, 1.0), at + Vector3(1.6, 0.4, 0), Color(0.5, 0.36, 0.22))
			# Caja sólida (física de mobiliario): el jugador se para encima al saltar.
			structures._collider(root, Vector3(1.0, 0.8, 1.0), at + Vector3(1.6, 0.4, 0), false)
			structures._furniture(world_xz + Vector2(at.x + 1.6, at.z), 0.9)
		"lumber":
			# Pilas de troncos.
			for i in 3:
				structures._decor_sprite(root, PropArt.texture("log"), at + Vector3(0, i * 0.35, i * 0.1))
			structures._collider(root, Vector3(2.0, 1.0, 1.0), at + Vector3(0, 0.5, 0), false)
			structures._furniture(world_xz + Vector2(at.x, at.z), 1.2)
		"oasis":
			# Puestos con toldo de colores.
			structures._box(root, Vector3(2.0, 0.9, 1.0), at + Vector3(0, 0.45, 0), Color(0.62, 0.45, 0.28))
			structures._box(root, Vector3(2.4, 0.1, 1.6), at + Vector3(0, 2.0, 0), [Color(0.9, 0.35, 0.3), Color(0.3, 0.6, 0.9), Color(0.95, 0.75, 0.25)][rng.randi() % 3])
			for side in [-1.0, 1.0]:
				structures._box(root, Vector3(0.1, 2.0, 0.1), at + Vector3(side * 1.1, 1.0, 0.7), Color(0.45, 0.3, 0.2))
			structures._collider(root, Vector3(2.0, 1.0, 1.0), at + Vector3(0, 0.5, 0), false)
			structures._furniture(world_xz + Vector2(at.x, at.z), 1.4)
		"alpine":
			structures._decor_sprite(root, PropArt.texture("snow_pile"), at)
			structures._box(root, Vector3(1.4, 0.3, 0.6), at + Vector3(1.5, 0.15, 0), Color(0.6, 0.3, 0.25))
			structures._collider(root, Vector3(1.4, 0.3, 0.6), at + Vector3(1.5, 0.15, 0), false)
			structures._furniture(world_xz + Vector2(at.x + 1.5, at.z), 0.9)
		"commercial":
			# Faroles y puestos de mercado.
			var lamp := BuildingModels.instance("lamp", rng.randi())
			if not lamp.is_empty():
				var node: Node3D = lamp["node"]
				node.position = at
				root.add_child(node)
				structures._collider(root, Vector3(0.4, 3.0, 0.4), at + Vector3(0, 1.5, 0), false)
			else:
				structures._box(root, Vector3(0.2, 3.0, 0.2), at + Vector3(0, 1.5, 0), Color(0.3, 0.3, 0.35))
				structures._collider(root, Vector3(0.4, 3.0, 0.4), at + Vector3(0, 1.5, 0), false)
			structures._furniture(world_xz + Vector2(at.x, at.z), 0.5)
