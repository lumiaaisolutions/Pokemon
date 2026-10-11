class_name ToxicSwamp
extends Node
## Pantano tóxico (decisión de Fernando, 2026-10-10): pisar el agua morada del bioma
## "Pantano tóxico" envenena. Mientras sigues ahí y POISON_LINGER segundos después de
## salir pierdes vida poco a poco; igual tu Pokémon fuera y los salvajes que pasen. Los
## Pokémon tipo Veneno o Acero no se envenenan. El veneno deja con 1 de vida como mínimo
## (no desmaya, como en los juegos actuales). Se cura con Antídoto, en el Centro Pokémon
## o al dormir. Se ve: tinte morado que late y burbujas moradas sobre el envenenado, y
## los corazones del HUD morados.
## Estado: GameState.poison_until (jugador), party[i]["poison_until"] (equipo) y la meta
## "poison_until" de los salvajes (todo en GameState.play_time).

const TICK := 1.0
const POISON_LINGER := 20.0
## Vida que quita cada segundo: al jugador (en corazones de vida) y a los Pokémon (parte
## de su vida máxima).
const PLAYER_DAMAGE := 0.5
const POKEMON_DAMAGE := 0.03
const WILD_RADIUS := 60.0
const IMMUNE_TYPES := [PokemonTypes.Type.POISON, PokemonTypes.Type.STEEL]
const TINT := Color(1.25, 0.7, 1.45)

@export var world_path: NodePath
@export var player_path: NodePath

var _world: WorldBuilder
var _player: Player
var _tick := 0.0
var _time := 0.0


func _ready() -> void:
	add_to_group(&"toxic_swamp")
	_world = get_node(world_path) as WorldBuilder
	_player = get_node(player_path) as Player


## ¿El punto está en el agua del pantano tóxico?
func is_toxic(pos: Vector3) -> bool:
	return _world.region_biome_at(pos.x, pos.z) == RegionLayout.Biome.TOXIC_SWAMP and _world.water_depth_at(pos.x, pos.z) > 0.05


static func immune(species: SpeciesData) -> bool:
	return species != null and species.types.any(func(t: int) -> bool: return IMMUNE_TYPES.has(t))


## Los salvajes guardan su veneno en una meta; tu compañero, en su ficha del equipo (así
## lo cura el Centro Pokémon o dormir).
static func actor_poisoned(actor: PokemonActor) -> bool:
	if actor.role == PokemonActor.Role.COMPANION:
		return GameState.play_time < float(actor.party_entry.get("poison_until", -1.0))
	return GameState.play_time < float(actor.get_meta("poison_until", -1.0))


func _process(delta: float) -> void:
	_time += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_update_player()
		_update_pokemon()
	_update_visuals()


func _update_player() -> void:
	if _player == null or _player.mode == Player.Mode.DOWNED:
		return
	if is_toxic(_player.global_position):
		if not GameState.is_poisoned():
			GameState.notice.emit("¡Te envenenaste en el agua tóxica! Usa un Antídoto o sal de aquí.")
		GameState.poison_until = GameState.play_time + POISON_LINGER
	if GameState.is_poisoned() and _player.health > 1.0:
		_player.take_damage(minf(PLAYER_DAMAGE * TICK, _player.health - 1.0))


func _update_pokemon() -> void:
	var actors: Array = get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP)
	var companion := get_parent().get("companion") as PokemonActor
	if companion != null and is_instance_valid(companion) and companion.visible:
		actors.append(companion)
	for node in actors:
		var actor := node as PokemonActor
		if actor == null or not actor.visible or immune(actor.species):
			continue
		if actor.global_position.distance_to(_player.global_position) > WILD_RADIUS:
			continue
		if is_toxic(actor.global_position):
			if not actor_poisoned(actor) and actor == companion:
				GameState.notice.emit("¡%s se envenenó!" % actor.species.display_name)
			if actor == companion:
				actor.party_entry["poison_until"] = GameState.play_time + POISON_LINGER
			else:
				actor.set_meta("poison_until", GameState.play_time + POISON_LINGER)
		if actor_poisoned(actor) and actor.hp > 1.0:
			actor.hp = maxf(actor.hp - actor.hp_max * POKEMON_DAMAGE * TICK, 1.0)
			if actor == companion and not actor.party_entry.is_empty():
				actor.party_entry["hp_ratio"] = actor.hp / actor.hp_max


## Tinte morado que late y burbujas moradas sobre cada envenenado.
func _update_visuals() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var poisoned_nodes: Array[Node3D] = []
	if _player != null and GameState.is_poisoned():
		poisoned_nodes.append(_player)
	for node in get_tree().get_nodes_in_group(WildSpawner.WILD_GROUP):
		if actor_poisoned(node as PokemonActor):
			poisoned_nodes.append(node)
	var companion := get_parent().get("companion") as PokemonActor
	if companion != null and is_instance_valid(companion) and actor_poisoned(companion):
		poisoned_nodes.append(companion)
	for node in get_tree().get_nodes_in_group(&"poison_marked"):
		if not poisoned_nodes.has(node):
			_mark(node as Node3D, false, 0.0)
	for node in poisoned_nodes:
		_mark(node, true, pulse)


func _mark(node: Node3D, on: bool, pulse: float) -> void:
	var sprite := node.get_node_or_null("Sprite") as SpriteBase3D
	var bubbles := node.get_node_or_null("PoisonBubbles") as CPUParticles3D
	if not on:
		node.remove_from_group(&"poison_marked")
		if sprite != null:
			sprite.modulate = Color.WHITE
		if bubbles != null:
			bubbles.queue_free()
		return
	node.add_to_group(&"poison_marked")
	if sprite != null:
		sprite.modulate = Color.WHITE.lerp(TINT, pulse)
	if bubbles == null:
		node.add_child(_bubbles())


static func _bubbles() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "PoisonBubbles"
	particles.amount = 6
	particles.lifetime = 1.2
	particles.position = Vector3(0, 1.4, 0)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.35
	particles.direction = Vector3.UP
	particles.spread = 15.0
	particles.gravity = Vector3(0, 0.6, 0)
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.5
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var material := StandardMaterial3D.new()
	material.albedo_texture = PixelShapes.get_texture("ring", Color(0.7, 0.3, 0.9))
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = material
	particles.mesh = quad
	return particles
