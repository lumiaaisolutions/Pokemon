class_name TownIdentity
extends RefCounted
## Identidad de cada pueblo (acordado con Fernando el 2026-10-10): un tema según su bioma
## y tamaño decide el monumento de la plaza, la decoración de alrededor y el subtítulo
## del cartel del lugar ("Pueblo Raíz · pueblo agrícola").
## Costa → pesquero · montaña/tundra fría → minero o alpino · pradera/flores/sabana →
## agrícola · bosque/selva → leñador · desierto/cañón/volcán → oasis · ciudades → comercial.

const NAMES := {"fishing": "pueblo pesquero", "mining": "pueblo minero", "farm": "pueblo agrícola", "lumber": "pueblo leñador",
		"oasis": "pueblo del oasis", "alpine": "pueblo alpino", "commercial": "ciudad comercial"}


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
	# En el pueblo inicial apareces en el centro de la plaza: el monumento va a un lado.
	var monument := Node3D.new()
	root.add_child(monument)
	if structures.world.layout.settlements.find(settlement) == 0:
		monument.position = Vector3(13.0, 0, 0)
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
		else:
			var bench := BuildingModels.instance("bench", i)
			if not bench.is_empty():
				var node: Node3D = bench["node"]
				node.position = at
				node.rotation.y = -angle + PI * 0.5
				root.add_child(node)
	# Objetos del tema entre los edificios.
	var buildings: Array = settlement["buildings"]
	for i in 16:
		var angle := rng.randf() * TAU
		var distance := radius * rng.randf_range(0.55, 0.95)
		var local := Vector3(cos(angle), 0, sin(angle)) * distance
		var world_x := cx + local.x
		var world_z := cz + local.z
		if structures.world.layout.road_info(world_x, world_z).x < RegionLayout.ROAD_WIDTH + 1.5:
			continue
		var blocked := false
		for b: Dictionary in buildings:
			if Vector2(float(b["x"]) - world_x, float(b["z"]) - world_z).length() < maxf(float(b["w"]), float(b["d"])) * 0.75 + 2.5:
				blocked = true
				break
		if blocked:
			continue
		_theme_prop(structures, root, theme, local, rng)


static func _monument(structures: Structures, root: Node3D, theme: String) -> void:
	match theme:
		"commercial":
			# Fuente monumental con agua y estatua de Pokéball.
			structures._cylinder(root, 3.0, 0.7, Vector3(0, 0.35, 0), Color(0.75, 0.75, 0.78))
			structures._cylinder(root, 2.6, 0.1, Vector3(0, 0.72, 0), Color(0.35, 0.6, 0.9))
			structures._cylinder(root, 0.5, 1.6, Vector3(0, 1.4, 0), Color(0.78, 0.78, 0.8))
			var ball := structures._cylinder(root, 0.8, 0.8, Vector3(0, 2.6, 0), Color(0.9, 0.25, 0.25))
			ball.scale = Vector3(1, 1, 1)
			structures._collider(root, Vector3(6.0, 1.5, 6.0), Vector3(0, 0.75, 0))
			root.add_child(structures._steam(Color(0.8, 0.9, 1.0, 0.6)))
		"farm":
			var mill := BuildingModels.instance("windmill", 0)
			if not mill.is_empty():
				var node: Node3D = mill["node"]
				# El modelo de B2W2 es de escala de ruta: en la plaza va a 0.6.
				node.scale = Vector3.ONE * 0.6
				root.add_child(node)
				var size: Vector3 = (mill["size"] as Vector3) * 0.6
				structures._collider(root, Vector3(size.x * 0.6, size.y, size.z * 0.6), Vector3(0, size.y * 0.5, 0))
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
			structures._collider(root, Vector3(2.4, 3.6, 2.4), Vector3(0, 1.8, 0))
		"mining":
			# Vagoneta con piedras brillantes sobre rieles.
			for side in [-0.5, 0.5]:
				structures._box(root, Vector3(0.12, 0.08, 5.0), Vector3(side, 0.05, 0), Color(0.45, 0.42, 0.4))
			structures._box(root, Vector3(1.6, 0.9, 2.0), Vector3(0, 0.75, 0), Color(0.45, 0.32, 0.2))
			structures._box(root, Vector3(1.3, 0.3, 1.7), Vector3(0, 1.25, 0), Color(0.55, 0.85, 0.95), 0.6)
			structures._collider(root, Vector3(1.6, 1.4, 2.2), Vector3(0, 0.7, 0))
		"lumber":
			# Tótem de madera tallado.
			for i in 4:
				structures._box(root, Vector3(1.0, 0.9, 1.0), Vector3(0, 0.45 + i * 0.9, 0), [Color(0.55, 0.38, 0.22), Color(0.45, 0.3, 0.18)][i % 2])
			structures._box(root, Vector3(2.4, 0.25, 0.4), Vector3(0, 3.2, 0), Color(0.6, 0.42, 0.25))
			structures._collider(root, Vector3(1.2, 3.8, 1.2), Vector3(0, 1.9, 0))
		"oasis":
			# Pozo con palmeras alrededor.
			structures._cylinder(root, 1.6, 0.9, Vector3(0, 0.45, 0), Color(0.82, 0.7, 0.5))
			structures._cylinder(root, 1.3, 0.1, Vector3(0, 0.88, 0), Color(0.3, 0.6, 0.85))
			for i in 3:
				var angle := TAU * i / 3.0
				structures._decor_sprite(root, PropArt.texture("palm"), Vector3(cos(angle) * 3.0, 0, sin(angle) * 3.0))
			structures._collider(root, Vector3(3.2, 1.0, 3.2), Vector3(0, 0.5, 0))
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
			structures._collider(root, Vector3(2.8, 0.8, 2.8), Vector3(0, 0.4, 0))
		_:
			_statue(structures, root, Color(0.7, 0.7, 0.72))


static func _statue(structures: Structures, root: Node3D, color: Color) -> void:
	structures._box(root, Vector3(2.0, 1.0, 2.0), Vector3(0, 0.5, 0), color.darkened(0.2))
	structures._cylinder(root, 0.6, 2.0, Vector3(0, 2.0, 0), color)
	structures._collider(root, Vector3(2.0, 3.0, 2.0), Vector3(0, 1.5, 0))


static func _theme_prop(structures: Structures, root: Node3D, theme: String, at: Vector3, rng: RandomNumberGenerator) -> void:
	match theme:
		"farm":
			# Surcos de cultivo o pacas de heno.
			if rng.randf() < 0.5:
				for row in 4:
					structures._box(root, Vector3(4.0, 0.25, 0.5), at + Vector3(0, 0.12, row * 0.9), Color(0.45, 0.32, 0.2))
					structures._decor_sprite(root, PropArt.texture("tuft_green"), at + Vector3(-1.2 + row * 0.4, 0.25, row * 0.9))
			else:
				structures._cylinder(root, 0.6, 0.9, at + Vector3(0, 0.45, 0), Color(0.88, 0.75, 0.4))
				structures._collider(root, Vector3(1.2, 0.9, 1.2), at + Vector3(0, 0.45, 0))
		"fishing":
			# Barcas volteadas, redes y barriles.
			structures._box(root, Vector3(3.0, 0.6, 1.2), at + Vector3(0, 0.3, 0), Color(0.3, 0.5, 0.75))
			structures._cylinder(root, 0.4, 0.8, at + Vector3(2.0, 0.4, 0.6), Color(0.5, 0.35, 0.22))
			structures._collider(root, Vector3(3.0, 0.8, 1.4), at + Vector3(0, 0.4, 0))
		"mining":
			structures._decor_sprite(root, PropArt.texture("boulder"), at)
			structures._box(root, Vector3(1.0, 0.8, 1.0), at + Vector3(1.6, 0.4, 0), Color(0.5, 0.36, 0.22))
		"lumber":
			# Pilas de troncos.
			for i in 3:
				structures._decor_sprite(root, PropArt.texture("log"), at + Vector3(0, i * 0.35, i * 0.1))
			structures._collider(root, Vector3(2.0, 1.0, 1.0), at + Vector3(0, 0.5, 0))
		"oasis":
			# Puestos con toldo de colores.
			structures._box(root, Vector3(2.0, 0.9, 1.0), at + Vector3(0, 0.45, 0), Color(0.62, 0.45, 0.28))
			structures._box(root, Vector3(2.4, 0.1, 1.6), at + Vector3(0, 2.0, 0), [Color(0.9, 0.35, 0.3), Color(0.3, 0.6, 0.9), Color(0.95, 0.75, 0.25)][rng.randi() % 3])
			for side in [-1.0, 1.0]:
				structures._box(root, Vector3(0.1, 2.0, 0.1), at + Vector3(side * 1.1, 1.0, 0.7), Color(0.45, 0.3, 0.2))
			structures._collider(root, Vector3(2.0, 1.0, 1.0), at + Vector3(0, 0.5, 0))
		"alpine":
			structures._decor_sprite(root, PropArt.texture("snow_pile"), at)
			structures._box(root, Vector3(1.4, 0.3, 0.6), at + Vector3(1.5, 0.15, 0), Color(0.6, 0.3, 0.25))
		"commercial":
			# Faroles y puestos de mercado.
			var lamp := BuildingModels.instance("lamp", rng.randi())
			if not lamp.is_empty():
				var node: Node3D = lamp["node"]
				node.position = at
				root.add_child(node)
				structures._collider(root, Vector3(0.4, 3.0, 0.4), at + Vector3(0, 1.5, 0))
			else:
				structures._box(root, Vector3(0.2, 3.0, 0.2), at + Vector3(0, 1.5, 0), Color(0.3, 0.3, 0.35))
