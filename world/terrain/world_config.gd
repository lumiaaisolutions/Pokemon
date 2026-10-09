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
