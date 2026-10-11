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

const KINDS := ["camp", "well", "ruins", "big_tree", "small_cave", "lookout"]
const TITLES := {"camp": "Campamento abandonado", "well": "Pozo de los deseos", "ruins": "Ruinas pequeñas",
		"big_tree": "Árbol grande", "small_cave": "Cueva chica", "lookout": "Mirador"}
const CHANCE := 0.35
const CHEST_LOOT := ["potion", "super-potion", "great-ball", "ultra-ball", "repel", "nugget", "star-piece", "rare-candy"]
const TREE_BERRIES := ["oran-berry", "sitrus-berry", "pecha-berry", "cheri-berry", "lum-berry"]
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
	var point := _world.structures.add_point(at + Vector3(0, 0.5, 1.6), _prompt(poi), _interact.bind(poi), 2.6)
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


func _interact(poi: Dictionary) -> void:
	var at := Vector3(float(poi["x"]), _world.surface_height_at(float(poi["x"]), float(poi["z"])), float(poi["z"]))
	match String(poi["kind"]):
		"camp":
			if not _daily(poi):
				GameState.notice.emit("El cofre está vacío. Vuelve mañana.")
				return
			_give(CHEST_LOOT[_rng.randi() % CHEST_LOOT.size()], 1 + _rng.randi() % 2)
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


# --- Aspecto -----------------------------------------------------------------------------

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
			_sprite(node, PoiArt.chest(), Vector3(0, 0, 0.9), 1.2)
			_sprite(node, PropArt.texture("log"), Vector3(2.6, 0, -1.4))
		"well":
			_sprite(node, PoiArt.well(), Vector3.ZERO, 1.3)
			_solid(node, Vector3(1.8, 1.4, 1.8), Vector3(0, 0.7, 0))
		"ruins":
			for i in 4:
				var angle := TAU * i / 4.0 + 0.4
				_box(node, Vector3(0.7, 1.2 + (i % 3) * 0.8, 0.7), Vector3(cos(angle) * 2.6, 0.6 + (i % 3) * 0.4, sin(angle) * 2.6), Color(0.62, 0.6, 0.55))
				_solid(node, Vector3(0.7, 2.0, 0.7), Vector3(cos(angle) * 2.6, 1.0, sin(angle) * 2.6))
			_sprite(node, PoiArt.tablet(), Vector3(0, 0, 0), 1.2)
			_sprite(node, PropArt.texture("mossy_rock"), Vector3(1.4, 0, 1.6))
		"big_tree":
			var tree := load("res://art/world/b2w2/tree_round.png") as Texture2D
			_sprite(node, tree, Vector3(0, 0, -0.6), 2.6)
			for i in 6:
				var berry := _sprite(node, Items.icon(TREE_BERRIES[i % TREE_BERRIES.size()]), Vector3(-1.6 + i * 0.65, 3.2 + (i % 3) * 0.7, -0.2), 0.8)
				berry.offset = Vector2.ZERO
				berry.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_solid(node, Vector3(1.4, 4.0, 1.4), Vector3(0, 2.0, -0.6))
		"small_cave":
			var rock := load("res://art/world/b2w2/mountain_rock.png") as Texture2D
			if rock != null:
				_sprite(node, rock, Vector3(0, 0, -1.0), 2.4)
			_sprite(node, PoiArt.cave_mouth(), Vector3(0, 0, -0.2), 1.6)
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
			_sprite(node, PoiArt.signpost(), Vector3(1.8, 0, 1.8))
