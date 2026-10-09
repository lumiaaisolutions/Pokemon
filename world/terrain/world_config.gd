class_name WorldConfig
extends Resource
## Mundo abierto de 3 biomas conectados sin cargas: Pradera (centro y este),
## Bosque/humedal (oeste, con pantano), Montaña (norte) y costa con mar (sur).
## Un río nace en la montaña, cruza el bosque y la pradera, pasa por el lago y
## desemboca en el mar. Ejes: +X este, +Z sur.

@export_group("Terreno")
@export var size: float = 480.0
@export var cell_size: float = 2.0
@export var seed: int = 1
## Radio plano alrededor del origen para el punto de inicio (en la Pradera).
@export var spawn_flat_radius: float = 14.0
## Fronteras aproximadas (se deforman con ruido para que sean orgánicas).
@export var mountain_edge_z: float = -80.0
@export var forest_edge_x: float = -70.0
@export var shore_z: float = 150.0

@export_group("Biomas")
@export var meadow: BiomeConfig
@export var forest: BiomeConfig
@export var mountain: BiomeConfig
@export var beach_texture: Texture2D
@export var swamp_ground_texture: Texture2D

@export_group("Agua")
@export var water_texture: Texture2D
@export var swamp_water_texture: Texture2D
@export var sea_level: float = -1.5
## Puntos del río de la montaña al mar (x, z).
@export var river_points: PackedVector2Array = PackedVector2Array([
	Vector2(40, -235), Vector2(10, -170), Vector2(-40, -110), Vector2(-110, -60), Vector2(-150, 0),
	Vector2(-120, 60), Vector2(-50, 85), Vector2(40, 70), Vector2(75, 70), Vector2(95, 140), Vector2(110, 240)])
@export var river_width: float = 7.0
@export var lake_center: Vector2 = Vector2(70, 70)
@export var lake_radius: float = 22.0
@export var swamp_center: Vector2 = Vector2(-165, 95)
@export var swamp_radius: float = 50.0
@export var swamp_pond_count: int = 10

@export_group("Coherencia")
## Pisos de altura en la montaña (m): sin árboles y con roca desnuda arriba de
## rock_height; nieve arriba de snow_height.
@export var rock_height: float = 18.0
@export var snow_height: float = 32.0
## Caminos de tierra que unen los lugares importantes (polilíneas x, z).
@export var paths: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(0, 0), Vector2(25, 25), Vector2(42, 62)]),
	PackedVector2Array([Vector2(0, 0), Vector2(-40, 8), Vector2(-90, 22), Vector2(-135, 40), Vector2(-150, 70)]),
	PackedVector2Array([Vector2(0, 0), Vector2(12, -40), Vector2(4, -82), Vector2(22, -120), Vector2(38, -160)]),
	PackedVector2Array([Vector2(0, 0), Vector2(-12, 55), Vector2(2, 105), Vector2(-15, 150)]),
	PackedVector2Array([Vector2(95, 75), Vector2(70, 115), Vector2(45, 150)]),
]
@export var path_width: float = 2.6
## Ribera viva: árboles y plantas por cada 10 m de orilla.
@export var riparian_trees_per_10m: float = 0.8
@export var riparian_decor_per_10m: float = 4.0
## Borde del bosque: árboles sueltos en la pradera cercana (por cada 1,000 m²).
@export var forest_edge_trees_per_1000m2: float = 6.0
@export var dead_tree_texture: Texture2D
## Bruma del pantano: manchas por cada 1,000 m² del pantano.
@export var swamp_mist_per_1000m2: float = 6.0

@export_group("Sprites")
## Metros por píxel de todos los sprites del mundo; igual que el jugador.
@export var pixel_size: float = 0.057
## Cuánto se hunden en el suelo los obstáculos y la decoración.
@export var obstacle_sink: float = 0.15
@export var decor_sink: float = 0.05
@export_range(0.0, 1.0) var contact_shadow_alpha: float = 0.45
@export var props_seed: int = 7
## Distancia a la que se dejan de dibujar props y decoración (rendimiento).
@export var prop_view_distance: float = 140.0
@export var wall_height: float = 60.0
