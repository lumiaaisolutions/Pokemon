class_name StarterCeremony
extends Node3D
## Inicio de partida: 5 huevos de Pokémon básicos al azar eclosionan frente al
## jugador. El primero al que le lanza una Pokéball queda capturado (sin fallar) y es
## su compañero de viaje; los demás se van al bosque y no se vuelven a ver. Sirve de
## práctica de apuntar y lanzar.

## Elegido: species y si es shiny, con la posición donde quedó la Pokéball.
signal chosen(species: SpeciesData, shiny: bool, at: Vector3)

const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")
const STARTER_POOL := preload("res://creatures/data/basic_pool.tres")
const EGGS := 5
const ARC_RADIUS := 6.5
const ARC_DEGREES := 100.0
const SHINY_CHANCE := 0.01

var player: Player
var world: WorldBuilder
var hud: Hud
var _eggs: Array[Sprite3D] = []
var _hatched: Array[PokemonActor] = []
var _rng := RandomNumberGenerator.new()
var _done := false


func start() -> void:
	_rng.randomize()
	var species_list := STARTER_POOL.pick_distinct(_rng, EGGS)
	# Arco frente a la cámara.
	var camera := get_viewport().get_camera_3d()
	var forward := Vector3.FORWARD
	if camera != null:
		forward = -camera.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
	for i in EGGS:
		var angle := deg_to_rad(lerpf(-ARC_DEGREES * 0.5, ARC_DEGREES * 0.5, float(i) / (EGGS - 1)))
		var dir := forward.rotated(Vector3.UP, angle)
		var p := player.global_position + dir * ARC_RADIUS
		p.y = world.surface_height_at(p.x, p.z)
		var egg := _make_egg(species_list[i])
		add_child(egg)
		egg.global_position = p
		egg.set_meta("species", species_list[i])
		_eggs.append(egg)
	hud.show_toast("¡Los huevos se están moviendo!")
	await _wobble(2.5)
	for i in EGGS:
		await _hatch(i)
		await get_tree().create_timer(0.35).timeout
	hud.show_tip("inicial", "Elige a tu compañero", [
		["aim", "Apunta (toca para fijar la mira)"],
		["throw", "Lánzale una Pokéball al que quieras"],
		[null, "El primero al que le atines será tu compañero de viaje. Los demás se irán."]])
	hud.show_toast("¡Elige a tu compañero lanzándole una Pokéball!")


## Huevos que se sacuden cada vez más fuerte.
func _wobble(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var strength := elapsed / seconds
		for egg in _eggs:
			var base: Vector3 = egg.get_meta("base", egg.position)
			egg.set_meta("base", base)
			egg.position = base + Vector3(sin(elapsed * 30.0 + egg.position.z) * 0.06 * strength, 0.0, 0.0)
			egg.scale = Vector3(1.0 + 0.06 * strength * sin(elapsed * 25.0), 1.0 - 0.06 * strength * sin(elapsed * 25.0), 1.0)
		await get_tree().process_frame
		elapsed += get_process_delta_time()


## El huevo se rompe con un destello y sale el Pokémon con su nombre encima.
func _hatch(index: int) -> void:
	var egg := _eggs[index]
	var species: SpeciesData = egg.get_meta("species")
	var tween := create_tween()
	tween.tween_property(egg, "modulate", Color(3, 3, 3), 0.25)
	await tween.finished
	PixelBurst.spawn(get_parent(), egg.global_position + Vector3.UP * 0.4, PixelBurst.Kind.SAND, 0.8)
	PixelBurst.spawn(get_parent(), egg.global_position + Vector3.UP * 0.5, PixelBurst.Kind.HEAL, 0.8)
	var actor := ACTOR_SCENE.instantiate() as PokemonActor
	actor.species = species
	actor.shiny = _rng.randf() < SHINY_CHANCE
	actor.player = player
	actor.world = world
	actor.ceremony = true
	get_parent().add_child(actor)
	actor.global_position = egg.global_position
	actor.vanished.connect(_on_vanished)
	var label := Label3D.new()
	label.text = species.display_name + (" ✦" if actor.shiny else "")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 12
	label.pixel_size = 0.006
	label.no_depth_test = true
	label.position.y = species.overworld_cell * actor.world_pixel_size() + 0.5
	actor.add_child(label)
	_hatched.append(actor)
	egg.queue_free()


## Un Pokémon de la ceremonia salió del mundo: si fue capturado, es el elegido.
func _on_vanished(actor: PokemonActor) -> void:
	if _done or not GameState.party.any(func(p: Dictionary) -> bool: return p["species"] == actor.species.identifier):
		return
	_done = true
	var at := actor.global_position
	for other in _hatched:
		if other != actor and is_instance_valid(other):
			_flee(other)
	chosen.emit(actor.species, actor.shiny, at)


## Los no elegidos se van al bosque con una nube de hojas.
func _flee(actor: PokemonActor) -> void:
	PixelBurst.spawn(get_parent(), actor.global_position + Vector3.UP * 0.4, PixelBurst.Kind.LEAVES, actor.species.size_scale)
	actor.ceremony = false
	actor.queue_free()


func _make_egg(species: SpeciesData) -> Sprite3D:
	var egg := Sprite3D.new()
	egg.texture = _egg_texture(AttackProjectile.TYPE_COLORS.get(species.types[0], Color(0.6, 0.8, 0.5)))
	egg.pixel_size = 0.07
	egg.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	egg.shaded = false
	egg.layers = 2
	egg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SpriteMaterials.apply(egg)
	return egg


## Huevo pixel art color crema con manchas del color del tipo de su Pokémon.
static func _egg_texture(spots: Color) -> Texture2D:
	var rows := [
		"....XXXX....",
		"...XccccX...",
		"..XccSSccX..",
		"..XcSSccSX..",
		".XccccccccX.",
		".XcSccccSSX.",
		"XccSSccccScX",
		"XcccccSSccX.",
		"XccSccccccSX",
		"XcSSccccccSX",
		".XcccSSccccX",
		".XccccSSccX.",
		"..XccccccX..",
		"...XXXXXX...",
	]
	var image := Image.create_empty(12, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in mini(row.length(), 12):
			match row[x]:
				"X":
					image.set_pixel(x, y, Color(0.2, 0.18, 0.15))
				"c":
					image.set_pixel(x, y, Color(0.98, 0.95, 0.85))
				"S":
					image.set_pixel(x, y, spots)
	return ImageTexture.create_from_image(image)
