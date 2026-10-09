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

@export_group("Sprite")
@export var texture_front: Texture2D
@export var texture_back: Texture2D
## Metros por píxel del sprite (70 px × 0.024 ≈ 1.7 m).
@export var pixel_size: float = 0.024
## Rebote al caminar: altura en metros y pasos por segundo a velocidad de caminata.
@export var bob_height: float = 0.06
@export var bob_frequency: float = 2.2
