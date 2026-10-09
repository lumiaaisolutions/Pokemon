class_name BiomeConfig
extends Resource
## Estilo de un bioma: texturas del suelo, árboles, rocas, decoración y hierba alta.
## Las cantidades son por cada 1,000 m² del bioma.

@export var biome_name: String = ""

@export_group("Suelo")
@export var grass_texture: Texture2D
@export var grass_light_texture: Texture2D
@export var path_texture: Texture2D
## Textura en pendientes fuertes.
@export var slope_texture: Texture2D
## Multiplica el color del suelo (p. ej. más oscuro en el bosque).
@export var ground_tint: Color = Color.WHITE

@export_group("Árboles y rocas")
@export var tree_textures: Array[Texture2D] = []
@export var trees_per_1000m2: float = 2.5
@export_range(0.0, 1.0) var big_tree_ratio: float = 0.3
@export var tree_collision_radius: float = 0.45
@export var rock_textures: Array[Texture2D] = []
@export var rocks_per_1000m2: float = 1.0
@export var rock_collision_radius: float = 0.7
## Multiplica el color de árboles y rocas.
@export var prop_tint: Color = Color.WHITE

@export_group("Decoración")
@export var decor_textures: Array[Texture2D] = []
## Cantidad de cada decoración por cada 1,000 m².
@export var decor_per_1000m2: float = 5.0

@export_group("Hierba alta")
@export var tall_grass_texture: Texture2D
@export var tall_grass_patch_count: int = 16
@export var tall_grass_radius_min: float = 5.0
@export var tall_grass_radius_max: float = 10.0
## Briznas por metro cuadrado.
@export var tall_grass_density: float = 8.0
@export var tall_grass_tint_bottom: Color = Color(0.32, 0.5, 0.3)
@export var tall_grass_tint_top: Color = Color(0.62, 0.82, 0.5)
