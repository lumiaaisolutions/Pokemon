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

@export_group("Salto y caídas")
@export var jump_velocity: float = 7.5
## Caer más que esto (m) hace daño: fall_damage por cada metro extra (estilo Minecraft).
@export var fall_safe_height: float = 4.0
@export var fall_damage_per_meter: float = 1.0

@export_group("Vida")
## Vida en medios corazones (20 = 10 corazones, como Minecraft).
@export var health_max: float = 20.0
## Al desmayarse, segundos que tarda en llenarse la vida mientras el compañero lo protege.
@export var downed_duration: float = 120.0

@export_group("Agua")
## Profundidad desde la que nada en vez de caminar.
@export var swim_depth: float = 1.1
@export var swim_speed: float = 2.6
@export var dive_speed: float = 2.0
## Cansancio al nadar moviéndose (stamina por segundo). Flotar quieto la recupera.
## Sin stamina nada más lento, pero no se hunde.
@export var swim_stamina_drain: float = 1.0
@export var swim_exhausted_speed_factor: float = 0.55
## Segundos de aire bajo el agua (10 burbujas) y recuperación por segundo al salir.
@export var air_max: float = 15.0
@export var air_refill: float = 6.0
## Daño por segundo al quedarse sin aire.
@export var drown_damage_per_second: float = 1.0

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
