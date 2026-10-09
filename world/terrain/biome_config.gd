class_name BiomeConfig
extends Resource
## Parámetros de un bioma en greybox: terreno por ruido, props y límites.

@export var biome_name: String = ""

@export_group("Terreno")
## Lado del terreno cuadrado en metros, centrado en el origen.
@export var size: float = 200.0
## Tamaño de cada celda de la malla (más grande = facetas low-poly más visibles).
@export var cell_size: float = 4.0
@export var height_amplitude: float = 6.0
@export var noise_frequency: float = 0.012
@export var noise_seed: int = 1
## Radio plano alrededor del origen para el punto de inicio.
@export var flat_radius: float = 12.0
@export var ground_color_low: Color = Color(0.36, 0.58, 0.27)
@export var ground_color_high: Color = Color(0.55, 0.70, 0.33)

@export_group("Props")
@export var rock_count: int = 40
@export var tree_count: int = 70
@export var rock_color: Color = Color(0.52, 0.50, 0.48)
@export var trunk_color: Color = Color(0.42, 0.29, 0.19)
@export var leaves_color: Color = Color(0.20, 0.45, 0.22)
## Distancia mínima de los props al punto de inicio.
@export var props_clear_radius: float = 18.0
@export var props_seed: int = 7

@export_group("Límites")
@export var wall_height: float = 30.0
