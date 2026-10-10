class_name PokeballProjectile
extends RigidBody3D
## Pokéball lanzada en el mundo: vuela con física real. Si toca a un Pokémon salvaje
## lo encierra y hace la secuencia de captura (3 sacudidas); si cae al suelo rueda y
## desaparece a los pocos segundos.

const RADIUS := 0.15
const SHAKE_TIME := 0.7
const MISS_LIFETIME := 3.0

var thrower: Node3D
var ball_bonus: float = CaptureRules.POKEBALL
## Tipo de ball (id del catálogo); su multiplicador se calcula al tocar al Pokémon.
var ball_id := "poke-ball"
## Resultado forzado para las pruebas (-1 = al azar, 0 = falla, 1 = captura).
var forced_result: int = -1

var _target: PokemonActor
var _done := false
var _age: float = 0.0
var _sprite: Sprite3D
var _rng := RandomNumberGenerator.new()


static func create() -> PokeballProjectile:
	var ball := PokeballProjectile.new()
	ball.name = "Pokeball"
	ball.mass = 0.2
	ball.contact_monitor = true
	ball.max_contacts_reported = 4
	ball.continuous_cd = true
	ball.collision_layer = 0
	# Choca con terreno (1), obstáculos (2) y actores (3).
	ball.collision_mask = 1 | 2 | 4
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	ball._sprite = Sprite3D.new()
	ball._sprite.texture = _ball_texture()
	ball._sprite.pixel_size = 0.045
	ball._sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ball._sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ball._sprite.shaded = false
	ball._sprite.layers = 2
	ball.add_child(ball._sprite)
	return ball


func _ready() -> void:
	_rng.randomize()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _target == null and not _done and _age > MISS_LIFETIME:
		PixelBurst.spawn(get_parent(), global_position, PixelBurst.Kind.DUST, 0.5)
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _target != null or _done or not (body is PokemonActor):
		return
	var actor := body as PokemonActor
	if actor.role != PokemonActor.Role.WILD or actor.state == PokemonActor.State.DROP:
		return
	# El inicial de la ceremonia siempre se captura.
	if actor.ceremony:
		forced_result = 1
	start_capture(actor)


## Encierra al Pokémon y hace las sacudidas. Lo usan también las pruebas.
func start_capture(actor: PokemonActor) -> void:
	_target = actor
	var stunned := actor.state == PokemonActor.State.STUNNED
	var stealth := thrower != null and CaptureRules.is_stealthy(actor, thrower)
	ball_bonus = CaptureRules.ball_multiplier(ball_id, actor, thrower)
	var probability := CaptureRules.probability(actor.species, actor.hp / actor.hp_max, ball_bonus, stunned, stealth)
	# La ball queda en el suelo frente al Pokémon y él entra en ella.
	freeze = true
	global_position = actor.global_position + Vector3.UP * RADIUS
	PixelBurst.spawn(get_parent(), actor.global_position + Vector3.UP * 0.5, PixelBurst.Kind.SPLASH, 0.6)
	actor.set_inside_ball(true)
	var shake_chance := CaptureRules.shake_probability(probability)
	var held := 0
	for shake in CaptureRules.SHAKES:
		await _shake()
		var holds := _rng.randf() < shake_chance
		if forced_result >= 0:
			holds = forced_result == 1
		if not holds:
			break
		held += 1
	_done = true
	if not is_instance_valid(actor):
		queue_free()
		return
	if held == CaptureRules.SHAKES:
		var heals: bool = Items.get_item(ball_id).get("ball", {}).get("heals", false)
		var location := GameState.add_caught(actor.species, actor.shiny, 1.0 if heals else actor.hp / actor.hp_max, actor.gender, actor.size_factor)
		if stealth:
			GameState.dex_count(actor.species.identifier, "behind")
		PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.3, PixelBurst.Kind.SAND, 0.8)
		GameState.pokemon_caught.emit(actor.species.display_name, actor.shiny, location)
		actor.captured()
	else:
		PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.3, PixelBurst.Kind.SMOKE, 0.8)
		GameState.capture_failed.emit(actor.species.display_name)
		actor.set_inside_ball(false)
		actor.escape_from_ball(thrower)
	queue_free()


func _shake() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "rotation:z", 0.4, SHAKE_TIME * 0.25)
	tween.tween_property(_sprite, "rotation:z", -0.4, SHAKE_TIME * 0.5)
	tween.tween_property(_sprite, "rotation:z", 0.0, SHAKE_TIME * 0.25)
	await tween.finished


## Pokéball pixel art de 7×7: mitad roja, mitad blanca y franja negra con botón.
static func _ball_texture() -> Texture2D:
	var rows := ["..KKK..", ".KRRRK.", "KRRRRRK", "KKKWKKK", "KWWWWWK", ".KWWWK.", "..KKK.."]
	var image := Image.create_empty(7, 7, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 7:
			match rows[y][x]:
				"K":
					image.set_pixel(x, y, Color(0.08, 0.08, 0.1))
				"R":
					image.set_pixel(x, y, Color(0.9, 0.18, 0.18))
				"W":
					image.set_pixel(x, y, Color(0.96, 0.96, 0.96))
	return ImageTexture.create_from_image(image)
