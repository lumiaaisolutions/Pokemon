class_name PlayerConfig
extends Resource
## Parámetros de movimiento y presentación del jugador.

@export_group("Movimiento")
@export var walk_speed: float = 4.5
@export var run_speed: float = 8.0
## Aceleración y frenado en m/s².
@export var acceleration: float = 30.0
@export var deceleration: float = 40.0
@export var gravity: float = 20.0

@export_group("Sprite overworld")
## Hoja generada por tools/copy_sprites.py: columnas = frames (parado, paso A, paso B);
## filas 0–3 caminar y 4–7 correr, en orden abajo, izquierda, derecha, arriba.
@export var sheet: Texture2D
@export var hframes: int = 3
@export var vframes: int = 8
## Metros por píxel (28 px de personaje × 0.057 ≈ 1.6 m).
@export var pixel_size: float = 0.057
## Pasos por segundo de la animación al caminar y al correr.
@export var walk_fps: float = 7.0
@export var run_fps: float = 10.0
