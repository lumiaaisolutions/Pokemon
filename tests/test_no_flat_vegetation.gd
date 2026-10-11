extends Node
## Prueba de que el mundo pasó a 3D (regla 1 de docs/reglas_calidad.md, 2026-10-10): los
## árboles, rocas, decoración, hierba alta, recolectables y lugares de interés del mundo ya
## no son Sprite3D/QuadMesh planos, salvo los íconos pequeños que acompañan a un objeto
## (como las bayas sobre el árbol grande, igual que un objeto en la mano) y, por supuesto,
## los Pokémon, los personajes y los NPC (que siguen siendo sprites de mundo).
## Uso: godot --headless --path . tests/test_no_flat_vegetation.tscn  (sale con 0 si todo pasa)

const MAIN_SCENE := preload("res://world/main.tscn")

var _failures: Array[String] = []
var _main: Node3D
var _world: WorldBuilder
var _gather: GatherManager
var _poi: PointsOfInterest


func _ready() -> void:
	BattleManager.enabled = false
	GameState.party = [{"species": "bidoof", "shiny": false, "hp_ratio": 1.0}]
	GameState.companion_index = 0
	GameState.world_flags = {}
	_main = MAIN_SCENE.instantiate() as Node3D
	_main.set("starter_ceremony", false)
	add_child(_main)
	_world = _main.get_node("World") as WorldBuilder
	_gather = _main.get_node_or_null("Gathering") as GatherManager
	_poi = _main.get_node_or_null("PointsOfInterest") as PointsOfInterest
	var navigation := _main.get_node("Navigation") as WorldNavigation
	while not navigation.is_baked:
		await get_tree().physics_frame
	await _frames(10)
	_check_world_chunks()
	_check_gather()
	_check_poi()
	_check_town_decor()
	for failure: String in _failures:
		printerr("FALLO: " + failure)
	print("test_no_flat_vegetation: %d fallos" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Árboles, rocas, decoración y hierba alta de las zonas cercanas: ninguno es Sprite3D; los
## árboles/rocas individuales traen una malla 3D real bajo "Visual" y la decoración/hierba
## va en MultiMeshInstance3D con una malla (nunca un QuadMesh con el shader de sprite).
func _check_world_chunks() -> void:
	var chunks := _world.near_chunks()
	_check(chunks.size() > 0, "no hay zonas cercanas cargadas para revisar")
	var trees := 0
	var rocks := 0
	var decor_groups := 0
	var grass_groups := 0
	for key: Vector2i in chunks:
		var root := chunks[key] as Node3D
		for child in root.get_children():
			if child is StaticBody3D and (String(child.name).begins_with("Tree") or String(child.name).begins_with("Rock")):
				var is_tree := String(child.name).begins_with("Tree")
				if is_tree:
					trees += 1
				else:
					rocks += 1
				_check(child.find_children("*", "Sprite3D", true, false).is_empty(), "%s en %s tiene un Sprite3D (debería ser una malla 3D)" % [child.name, key])
				var visual := child.get_node_or_null("Visual")
				_check(visual != null and not (visual.find_children("*", "MeshInstance3D", true, false).is_empty()), "%s en %s no tiene una malla 3D bajo Visual" % [child.name, key])
			elif child is MultiMeshInstance3D and String(child.name) == "Decor":
				decor_groups += 1
				var mesh := (child as MultiMeshInstance3D).multimesh.mesh
				_check(not (mesh is QuadMesh), "la decoración %s en %s sigue siendo un QuadMesh plano" % [child.name, key])
			elif child is MultiMeshInstance3D and String(child.name) == "TallGrass":
				grass_groups += 1
				var mesh := (child as MultiMeshInstance3D).multimesh.mesh
				_check(not (mesh is QuadMesh), "la hierba alta en %s sigue siendo un QuadMesh plano" % [key])
	print("  zonas: %d árboles, %d rocas, %d grupos de decoración, %d parches de hierba revisados" % [trees, rocks, decor_groups, grass_groups])
	_check(trees > 0, "no se encontraron árboles cerca del jugador para revisar")
	_check(rocks > 0, "no se encontraron rocas cerca del jugador para revisar")


## Arbusto de bayas, árbol de bonguri, seta y roca con minerales: su "Base" es una malla
## 3D (PropModels3D), no un Sprite3D.
func _check_gather() -> void:
	if _gather == null:
		return
	var nodes := _gather.nodes()
	_check(not nodes.is_empty(), "no hay puntos de recolección cerca del jugador para revisar")
	for node in nodes:
		var base := (node as Node3D).get_node_or_null("Base")
		if base == null:
			continue
		_check(base is MeshInstance3D, "la base de %s sigue siendo un Sprite3D" % node.name)


## Campamentos abandonados, pozos, ruinas, árbol grande y cuevas chicas: sin Sprite3D,
## salvo los íconos de baya sobre el árbol grande (igual que un objeto en la mano, ver
## docstring del archivo).
func _check_poi() -> void:
	if _poi == null:
		return
	var checked := {}
	for entry: Dictionary in (_poi.get("_nodes") as Dictionary).values():
		var node := entry["node"] as Node3D
		var kind := String((entry["poi"] as Dictionary)["kind"])
		checked[kind] = checked.get(kind, 0) + 1
		var sprites := node.find_children("*", "Sprite3D", true, false)
		if kind == "big_tree":
			_check(sprites.size() <= 6, "el árbol grande %s tiene objetos planos de más (%d sprites)" % [node.name, sprites.size()])
		else:
			_check(sprites.is_empty(), "el lugar de interés %s (%s) sigue teniendo %d objetos planos" % [node.name, kind, sprites.size()])
	print("  lugares de interés revisados: %s" % checked)
	_check(not checked.is_empty(), "no hay lugares de interés cerca del jugador para revisar")


## Flores y arbustos junto a los edificios del pueblo (Structures._decorate): malla 3D, no
## Sprite3D con esas texturas.
const TOWN_PLANT_FILES := ["flowers_yellow.png", "flower_bush_pink.png", "lavender.png", "bush.png"]


func _check_town_decor() -> void:
	var offenders := 0
	for sprite in _main.find_children("*", "Sprite3D", true, false):
		var texture := (sprite as Sprite3D).texture
		if texture == null:
			continue
		var file := texture.resource_path.get_file()
		if file in TOWN_PLANT_FILES:
			offenders += 1
	_check(offenders == 0, "quedan %d flores/arbustos de pueblo como Sprite3D" % offenders)