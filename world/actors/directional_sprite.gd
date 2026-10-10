class_name DirectionalSprite
extends Sprite3D
## Sprite billboard en eje Y con hoja de 4 direcciones (filas: abajo, izquierda,
## derecha, arriba). La fila visible depende de hacia dónde mira el actor respecto
## a la cámara, así que al orbitar la cámara también cambia el lado visible.
## Lo usan el jugador y los Pokémon.

enum Facing { DOWN, LEFT, RIGHT, UP }

## Columnas de la hoja que forman el ciclo de pasos (p. ej. [0, 1, 0, 2]).
@export var step_cycle: PackedInt32Array = PackedInt32Array([0, 1])
## Pasos por segundo al caminar y al correr.
@export var walk_fps: float = 6.0
@export var run_fps: float = 10.0
## Filas extra para la animación de correr (4 si la hoja trae correr debajo; 0 si no).
@export var run_row_offset: int = 0
## Filas transparentes bajo los pies, para apoyar el dibujo en el suelo.
@export var foot_offset_px: int = 0

## Hacia dónde mira el actor en el mundo (horizontal, normalizado).
var facing_world := Vector3.FORWARD
var _anim_time: float = 0.0


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = false
	double_sided = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Capa visual de sprites: las sombras de contacto (Decal) no se proyectan sobre ellos.
	layers = 2
	place_on_ground()


## Configura la hoja y apoya los pies en el origen del actor.
func setup(sheet: Texture2D, columns: int, rows: int, size_per_pixel: float, feet_px: int = 0) -> void:
	texture = sheet
	hframes = columns
	vframes = rows
	pixel_size = size_per_pixel
	foot_offset_px = feet_px
	place_on_ground()


func place_on_ground() -> void:
	if texture == null:
		return
	var cell_height := texture.get_height() / float(vframes)
	position.y = (cell_height * 0.5 - foot_offset_px) * pixel_size


## Semitransparente (p. ej. cuando tapa al jugador). Con alpha cut no hay mezcla,
## así que al desvanecerse cambia a transparencia normal.
func set_faded(faded: bool, alpha: float = 0.3) -> void:
	if faded:
		alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		modulate.a = alpha
	else:
		alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		modulate.a = 1.0


## Avanza la animación. horizontal es la velocidad horizontal del actor.
func animate(horizontal: Vector3, delta: float, running: bool = false) -> void:
	var speed := horizontal.length()
	var moving := speed > 0.1
	if moving:
		facing_world = horizontal / speed
	var row := int(visible_facing()) + (run_row_offset if running else 0)
	var column := step_cycle[0]
	if moving:
		_anim_time += delta * (run_fps if running else walk_fps)
		column = step_cycle[int(_anim_time) % step_cycle.size()]
	else:
		_anim_time = 0.0
	frame = row * hframes + column


## Mira hacia un punto del mundo sin moverse (p. ej. hacia un Pokémon salvaje).
func look_at_point(point: Vector3) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		facing_world = to.normalized()


## Dirección visible ahora según la cámara activa.
func visible_facing() -> Facing:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Facing.UP
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var right := camera.global_basis.x
	right.y = 0.0
	if forward.length_squared() < 0.0001 or right.length_squared() < 0.0001:
		return Facing.DOWN
	var along := facing_world.dot(forward.normalized())
	var side := facing_world.dot(right.normalized())
	if absf(side) > absf(along):
		return Facing.RIGHT if side > 0.0 else Facing.LEFT
	return Facing.UP if along > 0.0 else Facing.DOWN
