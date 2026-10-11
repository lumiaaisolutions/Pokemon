class_name WorldNavigation
extends NavigationRegion3D
## Navegación por zonas: cada zona cercana del mundo (ver WorldBuilder) se hornea en su
## propia región, en segundo plano, con el terreno, árboles, rocas, edificios y lugares
## que caen en ella; el agua profunda se excluye. Las regiones vecinas se unen por sus
## bordes. Al liberar una zona se libera su región. Los interiores tienen la suya.
## `baked` se emite cuando está lista la zona donde empieza el jugador.

signal baked

## Margen para unir los bordes de zonas vecinas (cada borde se erosiona el radio del agente).
const EDGE_MARGIN := 1.4

@export var world_path: NodePath

var is_baked := false
var _world: WorldBuilder
var _regions := {}
var _versions := {}
var _interior: NavigationRegion3D
var _first_key := Vector2i(1 << 20, 0)
## Mapa de navegación propio y aislado para los interiores: todos están en el mismo punto
## del mundo (Interiors.ORIGIN, muy lejos del mapa exterior) y antes compartían el mapa
## por defecto del World3D. Si el punto de salida/llegada de una consulta (p. ej. el
## segundo piso) no caía justo sobre el polígono del interior (el navmesh real de un
## modelo de B2W2 puede tener huecos pequeños), NavigationServer3D.map_get_path() lo
## resolvía "al polígono transitable más cercano de TODO el mapa", que podía terminar
## siendo una región del mundo exterior a cientos de metros (encontrado el 2026-10-11 al
## escribir la prueba que camina de verdad por las escaleras: la ruta devuelta apuntaba a
## un puente/plataforma real del mapa, no al interior). Con su propio mapa, una consulta
## sin punto de partida válido simplemente no encuentra ruta, en vez de una ruta ajena.
var _interior_map: RID
var _interior_map_ready := false


func _ready() -> void:
	navigation_mesh = _new_mesh()
	_world = get_node(world_path) as WorldBuilder
	NavigationServer3D.map_set_edge_connection_margin(get_world_3d().navigation_map, EDGE_MARGIN)
	_interior_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(_interior_map, true)
	NavigationServer3D.map_set_cell_size(_interior_map, ProjectSettings.get_setting("navigation/3d/default_cell_size"))
	_interior_map_ready = true
	# Donde va a empezar el jugador: el inicio o la posición de la partida cargada.
	var start := _world.start_position() if SaveSystem.pending_position == Vector3.INF else SaveSystem.pending_position
	_first_key = _world._chunk_key(start.x, start.z)
	_world.chunk_built.connect(_bake_chunk)
	_world.chunk_freed.connect(_free_chunk)
	var chunks := _world.near_chunks()
	for key: Vector2i in chunks:
		_bake_chunk(key, chunks[key])
	if not _regions.has(_first_key) and not chunks.has(_first_key):
		# El jugador no está sobre una zona (p. ej. cargado dentro de un interior).
		_mark_baked.call_deferred()


func _new_mesh() -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 3 # Terreno (1) y obstáculos (2).
	mesh.cell_size = ProjectSettings.get_setting("navigation/3d/default_cell_size")
	mesh.cell_height = ProjectSettings.get_setting("navigation/3d/default_cell_height")
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.5
	mesh.agent_max_climb = 0.5
	mesh.agent_max_slope = 45.0
	return mesh


## La zona key se acaba de construir: hornea su navegación.
func _bake_chunk(key: Vector2i, root: Node3D) -> void:
	var mesh := _new_mesh()
	var origin := Vector3(key.x * WorldBuilder.CHUNK, -300.0, key.y * WorldBuilder.CHUNK)
	mesh.filter_baking_aabb = AABB(origin, Vector3(WorldBuilder.CHUNK, 900.0, WorldBuilder.CHUNK))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, root)
	# Edificios y lugares que tocan la zona.
	if _world.structures != null:
		var center := Vector2((key.x + 0.5) * WorldBuilder.CHUNK, (key.y + 0.5) * WorldBuilder.CHUNK)
		for group in ["Buildings", "Landmarks"]:
			var parent := _world.structures.get_node_or_null(group)
			if parent == null:
				continue
			for child: Node3D in parent.get_children():
				if Vector2(child.global_position.x, child.global_position.z).distance_to(center) < WorldBuilder.CHUNK * 0.75 + 40.0:
					# Cada lectura reemplaza los datos: se lee aparte y se combina.
					var extra := NavigationMeshSourceGeometryData3D.new()
					NavigationServer3D.parse_source_geometry_data(mesh, extra, child)
					source.merge(extra)
	for outline in _world.deep_water_outlines(key):
		source.add_projected_obstruction(outline, -20.0, 80.0, true)
	var version := int(_versions.get(key, 0)) + 1
	_versions[key] = version
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, _on_chunk_baked.bind(key, mesh, version))


func _on_chunk_baked(key: Vector2i, mesh: NavigationMesh, version: int) -> void:
	if int(_versions.get(key, 0)) != version or not is_inside_tree():
		return
	var region: NavigationRegion3D = _regions.get(key)
	if region == null:
		region = NavigationRegion3D.new()
		region.name = "Nav_%d_%d" % [key.x, key.y]
		add_child(region)
		_regions[key] = region
	region.navigation_mesh = mesh
	if key == _first_key:
		_mark_baked()


func _mark_baked() -> void:
	if not is_baked:
		is_baked = true
		baked.emit()


func _free_chunk(key: Vector2i) -> void:
	_versions[key] = int(_versions.get(key, 0)) + 1
	var region: NavigationRegion3D = _regions.get(key)
	if region != null:
		region.queue_free()
		_regions.erase(key)


## Polígonos de todas las regiones horneadas (pruebas).
func polygon_count() -> int:
	var total := 0
	for key: Vector2i in _regions:
		total += (_regions[key] as NavigationRegion3D).navigation_mesh.get_polygon_count()
	return total


## ¿Ya está horneada la zona del punto?
func is_area_baked(point: Vector3) -> bool:
	return _regions.has(_world._chunk_key(point.x, point.z))


## Cuántas zonas cercanas ya tienen su navegación horneada (barra de la pantalla de carga).
func baked_near_count() -> int:
	return _regions.size()


## Hornea la navegación de un interior (sus pisos y muros).
func bake_interior(root: Node3D) -> void:
	free_interior()
	var mesh := _new_mesh()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, root)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	_interior = NavigationRegion3D.new()
	_interior.name = "NavInterior"
	add_child(_interior)
	# parse_source_geometry_data() recoge la geometría LOCAL a root (p. ej. x/y de unos
	# pocos metros, no los ~20000 de Interiors.ORIGIN); _interior nace como hijo de este
	# nodo (en el origen del mundo, no en el de root), así que sin igualar su transform al
	# de root, esos mismos vértices locales se reinterpretaban como si ya fueran globales:
	# una ruta con las coordenadas de la SALA, no del mundo (encontrado el 2026-10-11 al
	# escribir la prueba que camina de verdad por las escaleras, con el mapa aislado de
	# arriba: la ruta caía cerca de (12, 9, z), justo el tamaño de un interior, no del
	# punto real donde está construido).
	_interior.global_transform = root.global_transform
	_interior.navigation_mesh = mesh
	# Su propio mapa (ver _interior_map más arriba), no el del mundo exterior.
	NavigationServer3D.region_set_map(_interior.get_region_rid(), _interior_map)


func free_interior() -> void:
	if _interior != null and is_instance_valid(_interior):
		_interior.queue_free()
	_interior = null


## Mapa de navegación aislado donde vive el interior actual (Vector3.INF/RID inválido si
## no hay ninguno horneado): quien consulte una ruta DENTRO de un interior (compañero,
## pruebas) debe usar este, no get_world_3d().navigation_map (ver el porqué arriba).
func interior_navigation_map() -> RID:
	return _interior_map
