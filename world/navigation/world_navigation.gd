class_name WorldNavigation
extends NavigationRegion3D
## Hornea la malla de navegación del bioma al iniciar (terreno + árboles, rocas y
## muros), en segundo plano. Los actores esperan la señal `baked` para moverse.

signal baked

@export var biome_path: NodePath

var is_baked := false


func _ready() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 3 # Terreno (1) y obstáculos (2).
	mesh.cell_size = ProjectSettings.get_setting("navigation/3d/default_cell_size")
	mesh.cell_height = ProjectSettings.get_setting("navigation/3d/default_cell_height")
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.5
	mesh.agent_max_climb = 0.5
	mesh.agent_max_slope = 45.0
	navigation_mesh = mesh
	# Espera un frame para que el bioma haya construido su terreno y props.
	await get_tree().process_frame
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, get_node(biome_path))
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, _on_baked)


func _on_baked() -> void:
	navigation_mesh = navigation_mesh # Reasigna para que el servidor tome la malla horneada.
	is_baked = true
	baked.emit()
