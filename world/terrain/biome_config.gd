class_name BiomeConfig
extends Resource
## Parámetros de un bioma HD-2D: terreno por ruido con texturas pixel art de B2W2,
## árboles y decoración como sprites billboard, y límites.

@export var biome_name: String = ""

@export_group("Terreno")
## Lado del terreno cuadrado en metros, centrado en el origen.
@export var size: float = 200.0
@export var cell_size: float = 2.0
@export var height_amplitude: float = 5.0
@export var noise_frequency: float = 0.012
@export var noise_seed: int = 1
## Radio plano alrededor del origen para el punto de inicio.
@export var flat_radius: float = 12.0

@export_group("Texturas del suelo")
@export var grass_texture: Texture2D
@export var grass_light_texture: Texture2D
@export var path_texture: Texture2D
@export var dirt_texture: Texture2D
@export var path_seed: int = 3
@export var patch_seed: int = 5

@export_group("Sprites")
## Metros por píxel de todos los sprites del mundo; igual que el jugador para que
## todo comparta el mismo tamaño de píxel.
@export var pixel_size: float = 0.057
## Tipos de árbol; cada árbol elige uno al azar.
@export var tree_textures: Array[Texture2D] = []
@export var tree_count: int = 110
## Algunos árboles se dibujan al doble de escala (múltiplo entero: el píxel se mantiene cuadrado).
@export_range(0.0, 1.0) var big_tree_ratio: float = 0.3
@export var tree_collision_radius: float = 0.45
## Rocas: sprites billboard con colisión.
@export var rock_textures: Array[Texture2D] = []
@export var rock_count: int = 45
@export var rock_collision_radius: float = 0.7
## Decoración sin colisión (flores, arbustos, mechones), dibujada con MultiMesh.
@export var decor_textures: Array[Texture2D] = []
@export var decor_count_each: int = 220
## Distancia mínima de los props al punto de inicio.
@export var props_clear_radius: float = 18.0
@export var props_seed: int = 7

@export_group("Límites")
@export var wall_height: float = 30.0
