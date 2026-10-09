extends Node3D
## Escena principal: al iniciar, un Pokémon básico al azar acompaña al jugador
## (hasta que exista la selección de inicial de la Fase 5).

const ACTOR_SCENE := preload("res://world/actors/pokemon_actor.tscn")
const STARTER_POOL := preload("res://creatures/data/basic_pool.tres")

var companion: PokemonActor

@onready var _player: Player = $Player
@onready var _navigation: WorldNavigation = $Navigation


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	companion = ACTOR_SCENE.instantiate() as PokemonActor
	companion.species = STARTER_POOL.pick_distinct(rng, 1)[0]
	companion.role = PokemonActor.Role.COMPANION
	companion.player = _player
	companion.world = $World
	companion.position = _player.position + Vector3(1.5, 0.3, 1.5)
	add_child(companion)
	$Spawner.wild_contact.connect(_on_wild_contact)


func _on_wild_contact(actor: PokemonActor) -> void:
	# El combate en tiempo real llega en la Fase 3.
	print("Encuentro con %s salvaje" % actor.species.display_name)
