class_name MoveHazard
extends Node3D
## Trampas en el suelo (Púas, Trampa Rocas, Púas Tóxicas, Red Viscosa; decisión de
## Fernando, 2026-10-10): quedan en la arena y dañan (o frenan) al Pokémon que las pisa,
## salvo al que las puso. Duran LIFETIME segundos.

const LIFETIME := 40.0
const RADIUS := 0.9
const COOLDOWN := 2.0

var owner_actor: PokemonActor
var kind := "spikes"
var _age := 0.0
var _touched := {}


func _process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group(&"wild_pokemon") + get_tree().get_nodes_in_group(&"companion") + get_tree().get_nodes_in_group(&"trainer_pokemon"):
		var actor := node as PokemonActor
		if actor == null or actor == owner_actor or not is_instance_valid(actor):
			continue
		if Vector2(actor.global_position.x - global_position.x, actor.global_position.z - global_position.z).length() > RADIUS:
			continue
		var last := float(_touched.get(actor.get_instance_id(), -99.0))
		if _age - last < COOLDOWN:
			continue
		_touched[actor.get_instance_id()] = _age
		if kind == "sticky-web":
			actor.daze(0.8)
		else:
			actor.receive_hit(actor.hp_max * (0.06 if kind != "stealth-rock" else 0.1), owner_actor if is_instance_valid(owner_actor) else null)
		PixelBurst.spawn(get_parent(), global_position + Vector3.UP * 0.2, PixelBurst.Kind.ROCK if kind == "stealth-rock" else PixelBurst.Kind.DUST, 0.5)
