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

@export_group("Stamina")
@export var stamina_max: float = 100.0
## Gasto por segundo al correr y recuperación por segundo al no correr.
@export var stamina_drain: float = 20.0
@export var stamina_regen: float = 15.0
## Segundos sin correr antes de empezar a recuperar.
@export var stamina_regen_delay: float = 0.6
## Si se agota, no se puede volver a correr hasta recuperar este porcentaje.
@export_range(0.0, 1.0) var stamina_recover_ratio: float = 0.25

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
