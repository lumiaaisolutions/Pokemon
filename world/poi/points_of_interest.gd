class_name PointsOfInterest
extends Node3D
## Puntos de interés en el campo abierto (acordado con Fernando el 2026-10-10): uno de
## cada ~3 zonas fuera de pueblos y caminos tiene algo que hacer. Fijos por semilla; se
## crean con la zona cercana (como la recolección) y se marcan en el mapa al descubrirlos.
## - Campamento abandonado: cofre con objetos (1 vez por día).
## - Pozo: tirar una moneda ($100) da un objeto o hace salir un Pokémon de agua raro.
## - Ruinas pequeñas: inscripción con lore; suma a la investigación de un legendario.
## - Árbol grande: bayas de varios tipos (1 vez por día) y Pokémon voladores posados.
## - Cueva chica: un Pokémon raro dormido adentro (1 vez por día).
## - Mirador: revela el mapa en 300 m y da un bonus de foto.

## Mundo más lleno (acordado con Fernando el 2026-10-10): "casetas de descanso" (rest_stop),
## "nidos y guaridas... a veces líder" (nest) y "lugares de entrenamiento" (training_spot).
const KINDS := ["camp", "well", "ruins", "big_tree", "small_cave", "lookout", "rest_stop", "nest", "training_spot"]
const TITLES := {"camp": "Campamento abandonado", "well": "Pozo de los deseos", "ruins": "Ruinas pequeñas",
		"big_tree": "Árbol grande", "small_cave": "Cueva chica", "lookout": "Mirador",
		"rest_stop": "Caseta de descanso", "nest": "Guarida", "training_spot": "Lugar de entrenamiento"}
## Densidad moderada (mundo más lleno, 2026-10-11): antes 0.35; con 3 tipos nuevos de
## lugar suben un poco las probabilidades para que algo nuevo salga cada ~300 m (ver
## tests/test_town.gd::_check_poi_density).
const CHANCE := 0.42
const CHEST_LOOT := ["potion", "super-potion", "great-ball", "ultra-ball", "repel", "nugget", "star-piece", "rare-candy"]
## Cofres en 3D (decisión de Fernando, 2026-10-10): común, raro y legendario, con mejor
## botín según el nivel (Chest3D.tier_for, fijo por el id del campamento).
const CHEST_LOOT_BY_TIER := {
	"common": ["potion", "super-potion", "great-ball", "repel", "nugget"],
	"rare": ["ultra-ball", "full-heal", "hyper-potion", "star-piece", "rare-candy", "big-pearl", "treasure-map"],
	"legendary": ["rare-candy", "fire-stone", "water-stone", "thunderstone", "moon-stone", "leaf-stone", "sun-stone", "nugget"],
}
const TREE_BERRIES := ["oran-berry", "sitrus-berry", "pecha-berry", "cheri-berry", "lum-berry"]
## Guarida (mundo más lleno, 2026-10-11): una especie fija por guarida (varios de la
## misma especie, a veces con un líder más fuerte, como pidió Fernando).
const NEST_POOL := ["combee", "wurmple", "zubat", "spearow", "rattata", "bidoof", "drowzee", "numel", "whismur", "ledyba"]
## Lugar de entrenamiento: contrincantes de nivel inicial para un combate amistoso.
const TRAINING_POOL := ["machop", "makuhita", "timburr", "scraggy", "riolu", "meditite"]
const REST_TIPS := [
	"Un viajero dejó un letrero: \"El agua tóxica se cura con Antídoto o durmiendo en el Centro.\"",
	"\"Si un entrenador te ve, no podrás huir: prepárate antes de acercarte.\"",
	"\"Las guaridas tienen varios Pokémon de la misma especie; a veces uno es más fuerte que el resto.\"",
	"\"El tablón de encargos del pueblo paga bien por objetos que sobran en la mochila.\"",
	"\"De noche conviene acampar: la fogata aleja a los salvajes curiosos... o los invita a acercarse.\"",
]
const LORE := [
	"«Cuando el cielo se partió, un guardián de escamas bajó a calmar los mares.»",
	"«Tres hermanos de piedra, hielo y acero duermen esperando al que los despierte.»",
	"«El que vigila el tiempo apareció entre las raíces del bosque más antiguo.»",
	"«Las alas de fuego y las alas de hielo se cruzan sobre la montaña al amanecer.»",
	"«Un ser de sueños camina entre los que duermen en la noche sin luna.»",
]
const LEGENDS := ["kyogre", "regirock", "celebi", "moltres", "darkrai", "lugia", "suicune", "latias"]

@export var world_path: NodePath = NodePath("../World")

var _world: WorldBuilder
var _nodes := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"points_of_interest")
	_rng.randomize()
	_world = get_node(world_path) as WorldBuilder
	_world.chunk_built.connect(_populate)
	_world.chunk_freed.connect(_free)
	var chunks := _world.near_chunks()
	for key: Vector2i in chunks:
		_populate(key, chunks[key])


## Punto de interés de una zona ({} si no tiene): {id, kind, x, z}.
func plan(key: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ (_world.config.seed * 53 + 11)
	if rng.randf() >= CHANCE:
		return {}
	var kind: String = KINDS[rng.randi() % KINDS.size()]
	for attempt in 8:
		var x := (key.x + rng.randf_range(0.15, 0.85)) * WorldBuilder.CHUNK
		var z := (key.y + rng.randf_range(0.15, 0.85)) * WorldBuilder.CHUNK
		if not _world.is_inside(x, z, 20.0) or not _world._dry_land(x, z, 6.0):
			continue
		if not _world.settlement_at(x, z, 30.0).is_empty() or _world.distance_to_paths(x, z) < 8.0:
			continue
		if not _world.structures.place_at(x, z, 25.0).is_empty():
			continue
		if kind == "small_cave" and not _world.layout.biome_at(x, z) in [RegionLayout.Biome.MOUNTAIN, RegionLayout.Biome.CANYON, RegionLayout.Biome.MESA, RegionLayout.Biome.FOREST, RegionLayout.Biome.TUNDRA]:
			kind = "ruins"
		return {"id": "%d_%d" % [key.x, key.y], "kind": kind, "x": x, "z": z}
	return {}


func _populate(key: Vector2i, _root: Node3D) -> void:
	if _nodes.has(key):
		return
	var poi := plan(key)
	if poi.is_empty():
		return
	var node := Node3D.new()
	node.name = "POI_" + String(poi["id"])
	add_child(node)
	var at := Vector3(float(poi["x"]), _world.surface_height_at(float(poi["x"]), float(poi["z"])), float(poi["z"]))
	node.global_position = at
	_build(node, poi)
	if poi["kind"] == "rest_stop":
		# Caseta de descanso (mundo más lleno, 2026-10-11): recupera vida poco a poco
		# mientras estés cerca, igual que las aguas termales (TownServices.add_healing_spot).
		_world.structures.services.add_healing_spot(at + Vector3(0, 0.5, 0), 5.0, "Caseta de descanso")
	var point := _world.structures.add_point(at + Vector3(0, 0.5, 1.6), _prompt(poi), _interact.bind(poi, node), 2.6)
	_nodes[key] = {"node": node, "point": point, "poi": poi}


func _free(key: Vector2i) -> void:
	if not _nodes.has(key):
		return
	var entry: Dictionary = _nodes[key]
	_world.structures.remove_point(entry["point"])
	(entry["node"] as Node).queue_free()
	_nodes.erase(key)


func _process(_delta: float) -> void:
	# Descubrir: al acercarse a menos de 25 m queda marcado en el mapa.
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null:
		return
	for entry: Dictionary in _nodes.values():
		var poi: Dictionary = entry["poi"]
		if discovered(poi):
			continue
		if (entry["node"] as Node3D).global_position.distance_to(player.global_position) < 25.0:
			var seen: Dictionary = GameState.world_flags.get("poi_seen", {})
			seen[poi["id"]] = [poi["kind"], poi["x"], poi["z"]]
			GameState.world_flags["poi_seen"] = seen
			GameState.notice.emit("¡Descubriste un lugar nuevo! %s." % TITLES[poi["kind"]])


static func discovered(poi: Dictionary) -> bool:
	return (GameState.world_flags.get("poi_seen", {}) as Dictionary).has(poi["id"])


## Descubiertos (para el mapa): [{kind, x, z}].
static func seen_list() -> Array:
	var result: Array = []
	for id: String in GameState.world_flags.get("poi_seen", {}):
		var data: Array = GameState.world_flags["poi_seen"][id]
		result.append({"kind": data[0], "x": float(data[1]), "z": float(data[2])})
	return result


func _prompt(poi: Dictionary) -> String:
	match String(poi["kind"]):
		"camp":
			return "Abrir el cofre"
		"well":
			return "Tirar una moneda al pozo ($100)"
		"ruins":
			return "Leer la inscripción"
		"big_tree":
			return "Sacudir el árbol"
		"small_cave":
			return "Asomarse a la cueva"
		"rest_stop":
			return "Leer el letrero de la caseta"
		"nest":
			return "Acercarse a la guarida"
		"training_spot":
			return "Entrenar aquí"
	return "Mirar el paisaje"


# --- Rocas grandes en cuevas chicas (fase 5.8) ------------------------------------------

## La mitad de las cuevas chicas (fija por su id) tiene una roca grande en la entrada.
static func is_blocking_cave(poi: Dictionary) -> bool:
	return poi.get("kind", "") == "small_cave" and hash(String(poi["id"])) % 2 == 0


static func boulder_id(poi: Dictionary) -> String:
	return "poi:%s" % poi["id"]


## ¿Sigue tapada? (la roca no se ha roto)
static func blocked_by_boulder(poi: Dictionary) -> bool:
	return is_blocking_cave(poi) and not BreakableRock.boulder_broken(boulder_id(poi))


# --- Interacción ------------------------------------------------------------------------

func _daily(poi: Dictionary) -> bool:
	var key := "poi_used:%s" % poi["id"]
	if int(GameState.world_flags.get(key, -1)) == GameState.game_day():
		return false
	GameState.world_flags[key] = GameState.game_day()
	return true


func _give(item: String, amount: int) -> void:
	GameState.add_item(item, amount)
	AudioBus.play_jingle("me_item")
	GameState.notice.emit("Encontraste %s × %d." % [Items.display_name(item), amount])


func _interact(poi: Dictionary, node: Node3D = null) -> void:
	var at := Vector3(float(poi["x"]), _world.surface_height_at(float(poi["x"]), float(poi["z"])), float(poi["z"]))
	match String(poi["kind"]):
		"camp":
			if not _daily(poi):
				GameState.notice.emit("El cofre está vacío. Vuelve mañana.")
				return
			var tier := Chest3D.tier_for(String(poi["id"]))
			var chest: Dictionary = node.get_meta("chest") if node != null and node.has_meta("chest") else {}
			if not chest.is_empty():
				Chest3D.open(chest)
			var loot: Array = CHEST_LOOT_BY_TIER.get(tier, CHEST_LOOT)
			var amount := 1 + _rng.randi() % 2
			if tier == "legendary":
				amount += 1
			_give(loot[_rng.randi() % loot.size()], amount)
		"well":
			if GameState.money < 100:
				GameState.notice.emit("No tienes ni una moneda para tirar.")
				return
			GameState.add_money(-100, "Pozo de los deseos")
			AudioBus.play_sfx("ui_decide", 1.4)
			if _rng.randf() < 0.3:
				var spawner := get_parent().get_node_or_null("Spawner") as WildSpawner
				var species := MenuStyle.species(["lapras", "dratini", "feebas", "milotic", "corsola", "mantine"][_rng.randi() % 6])
				if spawner != null and species != null:
					spawner.spawn_species(species, at + Vector3(2.5, 0, 2.5), _rng.randf() < 0.05, false)
					GameState.notice.emit("¡Algo salió del pozo! Un %s." % species.display_name)
					return
			_give(["pearl", "big-pearl", "star-piece", "nugget", "rare-candy"][_rng.randi() % 5], 1)
		"ruins":
			var index := absi(hash(poi["id"]))
			var lines: Array = ["Hay una inscripción gastada en la piedra:", LORE[index % LORE.size()]]
			var legend: String = LEGENDS[index % LEGENDS.size()]
			if _daily(poi):
				GameState.dex_count(legend, "seen")
				lines.append("(Tu Pokédex registró datos sobre %s.)" % MenuStyle.species(legend).display_name)
			var dialog := get_tree().get_first_node_in_group(&"dialog_box") as DialogBox
			if dialog != null:
				dialog.open("Ruinas", lines)
		"big_tree":
			if not _daily(poi):
				GameState.notice.emit("Ya no quedan bayas. Mañana habrá más.")
				return
			PixelBurst.spawn(get_parent(), at + Vector3.UP * 3.0, PixelBurst.Kind.LEAVES, 1.2)
			for i in 3:
				_give(TREE_BERRIES[_rng.randi() % TREE_BERRIES.size()], 1)
			var spawner := get_parent().get_node_or_null("Spawner") as WildSpawner
			var bird := MenuStyle.species(["pidove", "pidgey", "starly", "rufflet", "hoothoot", "taillow"][_rng.randi() % 6])
			if spawner != null and bird != null and _rng.randf() < 0.6:
				spawner.spawn_species(bird, at + Vector3(1.5, 0, 1.5), false, false)
				GameState.notice.emit("¡Un %s cayó del árbol!" % bird.display_name)
		"small_cave":
			if blocked_by_boulder(poi):
				GameState.notice.emit("Una roca enorme tapa la cueva. Atácala con un compañero de tipo Lucha, Roca, Tierra o Acero, o que sepa Golpe Roca.")
				return
			# La primera vez tras abrirla: mejor premio (un fósil o una piedra evolutiva).
			var first_key := "poi_first:%s" % poi["id"]
			if is_blocking_cave(poi) and not GameState.world_flags.has(first_key):
				GameState.world_flags[first_key] = true
				var prizes: Array = TownServices.FOSSILS.keys() + BreakableRocks.STONES
				_give(String(prizes[_rng.randi() % prizes.size()]), 1)
			if not _daily(poi):
				GameState.notice.emit("La cueva está vacía. Quizá vuelva otro día.")
				return
			var spawner := get_parent().get_node_or_null("Spawner") as WildSpawner
			var rare := MenuStyle.species(["snorlax", "larvitar", "gible", "riolu", "axew", "deino", "bagon", "beldum"][_rng.randi() % 8])
			if spawner != null and rare != null:
				var actor := spawner.spawn_species(rare, at + Vector3(0, 0, 3.0), _rng.randf() < 0.05, false)
				GameState.notice.emit("¡Un %s dormía en la cueva y salió!" % rare.display_name)
				if actor != null and _rng.randf() < 0.1:
					actor.set_meta("Alfa", true)
		"lookout":
			var map_ui := get_parent().get_node_or_null("MapUi") as MapUi
			if map_ui != null:
				map_ui.data.reveal(at, 300.0)
			if _daily(poi):
				GameState.add_money(300, "Foto desde el mirador")
				GameState.notice.emit("¡Qué vista! Se reveló el mapa alrededor. Una buena foto aquí vale $300 para el profesor.")
			else:
				GameState.notice.emit("Se ve toda la zona desde aquí.")
		"rest_stop":
			var index := absi(hash(poi["id"]))
			GameState.notice.emit(REST_TIPS[index % REST_TIPS.size()])
		"nest":
			if not _daily(poi):
				GameState.notice.emit("La guarida está tranquila. Vuelve otro día.")
				return
			var index := absi(hash(poi["id"]))
			var species := MenuStyle.species(NEST_POOL[index % NEST_POOL.size()])
			var spawner := get_parent().get_node_or_null("Spawner") as WildSpawner
			if spawner == null or species == null:
				return
			var count := 2 + _rng.randi() % 3
			var leader := _rng.randf() < 0.15
			for i in count:
				var offset := Vector3(cos(TAU * i / count) * 2.5, 0, sin(TAU * i / count) * 2.5)
				var actor := spawner.spawn_species(species, at + offset, _rng.randf() < spawner.shiny_chance(), false)
				if actor != null and leader and i == 0:
					actor.set_meta("Alfa", true)
			GameState.notice.emit("¡Despertaste la guarida de %s! Salieron %d%s." % [species.display_name, count, " (uno más fuerte)" if leader else ""])
		"training_spot":
			_world.structures.services.training_spot_challenge(poi, at + Vector3(0, 0.3, 2.5))


# --- Aspecto -----------------------------------------------------------------------------

## Ícono pequeño sobre un objeto (p. ej. una baya flotando sobre el árbol grande): sigue
## siendo un sprite (sprite plano que acompaña a un objeto, igual que los objetos en mano o
## los íconos de la mochila; el objeto en sí ya es 3D, ver _build).
func _sprite(parent: Node3D, texture: Texture2D, at: Vector3, scale_factor: float = 1.0) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = _world.config.pixel_size * scale_factor
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.offset = Vector2(0, texture.get_height() * 0.5)
	sprite.position = at
	sprite.visibility_range_end = 180.0
	parent.add_child(sprite)
	return sprite


## Objeto del punto de interés en 3D: follaje 3D de verdad (tronco + copa) con su textura
## pixel, de pie en at (pie en el suelo). Sigue la luz y, si es follaje (seasonal), el tinte
## de estación. `shape` fuerza una forma (PropModels3D.foliage_mesh); por defecto se deduce.
func _prop(parent: Node3D, texture: Texture2D, at: Vector3, scale_factor: float = 1.0, seasonal: bool = true, shape: String = "") -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = PropModels3D.foliage_mesh(texture, _world.config.pixel_size * scale_factor, shape)
	mesh_instance.material_override = FoliageMaterials.for_texture(texture, Color.WHITE, seasonal, false)
	mesh_instance.position = at
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.visibility_range_end = 180.0
	parent.add_child(mesh_instance)
	return mesh_instance


## Roca o bulto de piedra del punto de interés: la misma malla de pocas caras que las
## rocas decorativas del mundo, con color plano.
func _rock_prop(parent: Node3D, at: Vector3, size: Vector3, color: Color, seed_key: String) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = PropModels3D.rock_mesh(seed_key, size)
	mesh_instance.material_override = PropModels3D.solid_material(color)
	mesh_instance.position = at + Vector3(0, size.y * 0.5, 0)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance)
	return mesh_instance


## Tablilla, letrero o boca de cueva: lámina de pie con grosor (PropModels3D.plaque_mesh),
## no un sprite plano.
func _plaque(parent: Node3D, texture: Texture2D, at: Vector3, scale_factor: float = 1.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = PropModels3D.plaque_mesh(texture, _world.config.pixel_size * scale_factor)
	mesh_instance.material_override = FoliageMaterials.for_texture(texture, Color.WHITE, false, false)
	mesh_instance.position = at
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance)
	return mesh_instance


func _solid(parent: Node3D, size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = WorldBuilder.LAYER_OBSTACLES | WorldBuilder.LAYER_CAMERA
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	body.add_child(collision)
	parent.add_child(body)


func _box(parent: Node3D, size: Vector3, center: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material_override = material
	mesh.position = center
	parent.add_child(mesh)


func _build(node: Node3D, poi: Dictionary) -> void:
	match String(poi["kind"]):
		"camp":
			# Campamento abandonado en 3D: tienda deslavada y fogata apagada (ver Camp).
			var tent := Camp.tent_model(Color(0.55, 0.5, 0.42))
			tent.position = Vector3(-1.5, 0, -1.4)
			tent.rotation.y = 0.3
			node.add_child(tent)
			var pit := Camp.firepit()
			pit.position = Vector3(1.4, 0, 0.4)
			for flame in pit.find_children("Flame*", "MeshInstance3D", true, false):
				(flame as Node3D).visible = false
			node.add_child(pit)
			# Cofre 3D propio (decisión de Fernando, 2026-10-10): común, raro o legendario
			# según el id del campamento; se abre con animación al recogerlo (ver _interact).
			var tier := Chest3D.tier_for(String(poi["id"]))
			var chest := Chest3D.build(node, Vector3(0, 0, 0.9), tier)
			node.set_meta("chest", chest)
			var log_mesh := MeshInstance3D.new()
			log_mesh.mesh = PropModels3D.log_mesh(0.7, 0.14, true)
			log_mesh.material_override = PropModels3D.solid_material(Color(0.5, 0.35, 0.22))
			log_mesh.position = Vector3(2.6, 0, -1.4)
			log_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			node.add_child(log_mesh)
		"well":
			_well(node)
			_solid(node, Vector3(1.8, 1.4, 1.8), Vector3(0, 0.7, 0))
		"ruins":
			for i in 4:
				var angle := TAU * i / 4.0 + 0.4
				_box(node, Vector3(0.7, 1.2 + (i % 3) * 0.8, 0.7), Vector3(cos(angle) * 2.6, 0.6 + (i % 3) * 0.4, sin(angle) * 2.6), Color(0.62, 0.6, 0.55))
				_solid(node, Vector3(0.7, 2.0, 0.7), Vector3(cos(angle) * 2.6, 1.0, sin(angle) * 2.6))
			_plaque(node, PoiArt.tablet(), Vector3(0, 0, 0), 1.2)
			_rock_prop(node, Vector3(1.4, 0, 1.6), Vector3(0.45, 0.3, 0.45), Color(0.5, 0.56, 0.46), "poi:" + String(poi["id"]) + ":ruins_rock")
		"big_tree":
			var tree := load("res://art/world/b2w2_leaf/puff_forest_dark.png") as Texture2D
			_prop(node, tree, Vector3(0, 0, -0.6), 2.6, true, "forest")
			for i in 6:
				var berry := _sprite(node, Items.icon(TREE_BERRIES[i % TREE_BERRIES.size()]), Vector3(-1.6 + i * 0.65, 3.2 + (i % 3) * 0.7, -0.2), 0.8)
				berry.offset = Vector2.ZERO
				berry.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_solid(node, Vector3(1.4, 4.0, 1.4), Vector3(0, 2.0, -0.6))
		"small_cave":
			_rock_prop(node, Vector3(0, 0, -1.0), Vector3(2.4, 1.8, 2.4), Color(0.55, 0.52, 0.5), "poi:" + String(poi["id"]) + ":cave_rock")
			_plaque(node, PoiArt.cave_mouth(), Vector3(0, 0, 0.1), 1.6)
			_solid(node, Vector3(4.0, 3.0, 2.0), Vector3(0, 1.5, -1.2))
			# La mitad de las cuevas chicas las tapa una roca grande (fase 5.8).
			if blocked_by_boulder(poi):
				BreakableRock.create(node, node.global_position + Vector3(0, 0, 1.4), boulder_id(poi), true)
		"lookout":
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				_box(node, Vector3(0.25, 3.2, 0.25), Vector3(corner.x * 1.1, 1.6, corner.y * 1.1), Color(0.5, 0.36, 0.22))
			_box(node, Vector3(2.8, 0.25, 2.8), Vector3(0, 3.2, 0), Color(0.62, 0.46, 0.3))
			_box(node, Vector3(2.8, 0.6, 0.12), Vector3(0, 3.6, -1.35), Color(0.55, 0.4, 0.25))
			_box(node, Vector3(0.6, 0.12, 2.4), Vector3(0, 1.6, 1.6), Color(0.55, 0.4, 0.25))
			_solid(node, Vector3(2.4, 3.2, 2.4), Vector3(0, 1.6, 0))
			var post := MeshInstance3D.new()
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.12, 1.0, 0.12)
			post.mesh = post_mesh
			post.material_override = PropModels3D.solid_material(Color(0.45, 0.3, 0.18))
			post.position = Vector3(1.8, 0.5, 1.8)
			node.add_child(post)
			_plaque(node, PoiArt.signpost(), Vector3(1.8, 0.75, 1.8))
		"rest_stop":
			# Caseta de madera con techo, banca y letrero (mundo más lleno, 2026-10-11).
			_box(node, Vector3(0.12, 2.0, 0.12), Vector3(-1.1, 1.0, -1.0), Color(0.45, 0.3, 0.18))
			_box(node, Vector3(0.12, 2.0, 0.12), Vector3(1.1, 1.0, -1.0), Color(0.45, 0.3, 0.18))
			_box(node, Vector3(2.6, 0.15, 2.0), Vector3(0, 2.1, -1.0), Color(0.55, 0.22, 0.2))
			_box(node, Vector3(1.6, 0.5, 0.6), Vector3(0, 0.28, 0.4), Color(0.5, 0.35, 0.22))
			_box(node, Vector3(1.6, 0.5, 0.1), Vector3(0, 0.55, 0.65), Color(0.5, 0.35, 0.22))
			_solid(node, Vector3(1.6, 0.5, 0.6), Vector3(0, 0.28, 0.4))
			_plaque(node, PoiArt.signpost(), Vector3(1.4, 0.75, -0.6))
		"nest":
			# Guarida: montículo de tierra con un hueco oscuro y un rastro de huellas.
			_rock_prop(node, Vector3(0, 0, 0), Vector3(2.2, 1.1, 2.0), Color(0.5, 0.38, 0.26), "poi:" + String(poi["id"]) + ":nest_mound")
			_box(node, Vector3(0.9, 0.5, 0.7), Vector3(0, 0.1, 1.0), Color(0.1, 0.08, 0.08))
			for i in 3:
				_box(node, Vector3(0.3, 0.05, 0.3), Vector3(-0.6 + i * 0.6, 0.02, 1.8 + i * 0.5), Color(0.35, 0.25, 0.18))
		"training_spot":
			# Muñeco de práctica de madera, como en la sala de entrenamiento del Centro.
			_box(node, Vector3(0.6, 1.4, 0.4), Vector3(0, 0.7, 0), Color(0.6, 0.42, 0.25))
			_box(node, Vector3(0.5, 0.5, 0.35), Vector3(0, 1.6, 0), Color(0.75, 0.6, 0.45))
			_solid(node, Vector3(0.7, 2.0, 0.5), Vector3(0, 1.0, 0))
			_plaque(node, PoiArt.signpost(), Vector3(1.4, 0.75, 0))


## Brocal de pozo: anillo de piedra (cilindro) con techo de madera a dos aguas (ya era 3D
## con _box/_solid salvo el brocal, que era un sprite plano).
func _well(node: Node3D) -> void:
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.9
	ring_mesh.bottom_radius = 1.0
	ring_mesh.height = 0.9
	ring_mesh.radial_segments = 12
	ring.mesh = ring_mesh
	ring.material_override = PropModels3D.solid_material(Color(0.56, 0.54, 0.52))
	ring.position.y = 0.45
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.add_child(ring)
	var water := MeshInstance3D.new()
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 0.75
	water_mesh.bottom_radius = 0.75
	water_mesh.height = 0.02
	water.mesh = water_mesh
	water.material_override = PropModels3D.solid_material(Color(0.2, 0.3, 0.5))
	water.position.y = 0.82
	node.add_child(water)
	for x in [-0.95, 0.95]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.1, 1.1, 0.1)
		post.mesh = post_mesh
		post.material_override = PropModels3D.solid_material(Color(0.42, 0.3, 0.2))
		post.position = Vector3(x, 1.0, 0.0)
		node.add_child(post)
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(2.2, 0.1, 1.1)
	roof.mesh = roof_mesh
	roof.material_override = PropModels3D.solid_material(Color(0.6, 0.22, 0.2))
	roof.position = Vector3(0, 1.6, 0)
	roof.rotation.x = deg_to_rad(18.0)
	node.add_child(roof)
