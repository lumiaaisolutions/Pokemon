class_name AttackProjectile
extends Node3D
## Ataque a distancia en el mundo: un orbe pixel art del color del tipo que viaja en
## línea recta hacia donde estaba el objetivo al lanzarse (se puede esquivar). Al
## pasar cerca de un blanco válido le hace daño y se deshace en una nube.

const SPEED := 13.0
const HIT_RADIUS := 0.9
const MAX_DISTANCE := 22.0
const TYPE_COLORS := {
	PokemonTypes.Type.NORMAL: Color(0.85, 0.85, 0.75), PokemonTypes.Type.FIRE: Color(1.0, 0.45, 0.15),
	PokemonTypes.Type.WATER: Color(0.3, 0.6, 1.0), PokemonTypes.Type.ELECTRIC: Color(1.0, 0.9, 0.2),
	PokemonTypes.Type.GRASS: Color(0.4, 0.85, 0.3), PokemonTypes.Type.ICE: Color(0.7, 0.95, 1.0),
	PokemonTypes.Type.FIGHTING: Color(0.8, 0.3, 0.2), PokemonTypes.Type.POISON: Color(0.65, 0.3, 0.75),
	PokemonTypes.Type.GROUND: Color(0.85, 0.7, 0.4), PokemonTypes.Type.FLYING: Color(0.7, 0.75, 1.0),
	PokemonTypes.Type.PSYCHIC: Color(1.0, 0.4, 0.65), PokemonTypes.Type.BUG: Color(0.65, 0.8, 0.2),
	PokemonTypes.Type.ROCK: Color(0.7, 0.6, 0.35), PokemonTypes.Type.GHOST: Color(0.45, 0.35, 0.65),
	PokemonTypes.Type.DRAGON: Color(0.45, 0.3, 0.95), PokemonTypes.Type.DARK: Color(0.35, 0.28, 0.25),
	PokemonTypes.Type.STEEL: Color(0.75, 0.75, 0.82), PokemonTypes.Type.FAIRY: Color(1.0, 0.65, 0.85),
}

var attacker: PokemonActor
## Función que recibe el nodo alcanzado; devuelve true si el impacto cuenta.
var on_hit: Callable
var targets: Array[Node3D] = []
var _direction := Vector3.FORWARD
var _travelled := 0.0
## Forma propia (ver MoveFx): cuadros que se alternan (p. ej. el shuriken que gira),
## velocidad y efecto al impactar (recibe la posición).
var frames: Array[Texture2D] = []
var frame_fps := 16.0
var speed := SPEED
var on_impact: Callable
var _frame_time := 0.0
var _orb: Sprite3D


## Cambia el orbe por una forma pixel art (y su tamaño de píxel).
func set_look(texture_frames: Array[Texture2D], pixel_size: float) -> void:
	frames = texture_frames
	if _orb != null and not frames.is_empty():
		_orb.texture = frames[0]
		_orb.pixel_size = pixel_size


static func launch(parent: Node, from: Vector3, to: Vector3, type: PokemonTypes.Type, attacker_actor: PokemonActor, hit_targets: Array[Node3D], hit: Callable) -> AttackProjectile:
	var projectile := AttackProjectile.new()
	projectile.attacker = attacker_actor
	projectile.targets = hit_targets
	projectile.on_hit = hit
	var orb := Sprite3D.new()
	var image := Image.create_empty(5, 5, false, Image.FORMAT_RGBA8)
	var color: Color = TYPE_COLORS.get(type, Color.WHITE)
	for y in 5:
		for x in 5:
			var corner := (x == 0 or x == 4) and (y == 0 or y == 4)
			if not corner:
				image.set_pixel(x, y, color.lightened(0.4) if x == 1 and y == 1 else color)
	orb.texture = ImageTexture.create_from_image(image)
	orb.pixel_size = 0.09
	orb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	orb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	orb.shaded = false
	orb.layers = 2
	projectile.add_child(orb)
	projectile._orb = orb
	parent.add_child(projectile)
	projectile.global_position = from
	var flat := to - from
	projectile._direction = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	return projectile


func _physics_process(delta: float) -> void:
	if frames.size() > 1:
		_frame_time += delta * frame_fps
		_orb.texture = frames[int(_frame_time) % frames.size()]
	var step := speed * delta
	global_position += _direction * step
	_travelled += step
	# El atacante ya no existe (capturado o se fue): el ataque se desvanece.
	if not on_hit.is_valid():
		queue_free()
		return
	for target in targets:
		if not is_instance_valid(target):
			continue
		var center := target.global_position + Vector3.UP * 0.6
		if global_position.distance_to(center) <= HIT_RADIUS * maxf(1.0, scale.x) and on_hit.call(target):
			if on_impact.is_valid():
				on_impact.call(global_position)
			else:
				PixelBurst.spawn(get_parent(), global_position, PixelBurst.Kind.DUST, 0.6)
			queue_free()
			return
	if _travelled >= MAX_DISTANCE:
		queue_free()
