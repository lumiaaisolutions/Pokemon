class_name FishingMinigame
extends Node
## Minijuego de pesca con la Caña (campamento, comida y hambre; acordado con Fernando
## el 2026-10-10): se lanza el anzuelo, se espera a que "muerda" (aviso "¡!") y hay que
## apretar Interactuar a tiempo; si se logra sale Pescado Crudo y, a veces, un Pokémon
## de agua que pelea. Se agrega como hijo de la escena principal y se destruye solo.

enum State { WAIT, BITE, DONE }

const WAIT_MIN := 1.5
const WAIT_MAX := 4.0
const BITE_WINDOW := 1.1
## Probabilidad de que salga un Pokémon de agua en vez del pescado (más con la Caña Buena).
const POKEMON_CHANCE := 0.28

var main: Node
var player: Player
var rod_tier: int = 1

var state: State = State.WAIT
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	GameState.notice.emit("Lanzas el anzuelo al agua...")
	state = State.WAIT
	_timer = _rng.randf_range(WAIT_MIN, WAIT_MAX)


func _process(delta: float) -> void:
	match state:
		State.WAIT:
			_timer -= delta
			if _timer <= 0.0:
				state = State.BITE
				_timer = BITE_WINDOW
				GameState.notice.emit("¡¡!! (%s para jalar)" % InputHints.hint("interact"))
				AudioBus.play_sfx("ui_select", 1.3)
		State.BITE:
			_timer -= delta
			if Input.is_action_just_pressed("interact"):
				_catch()
			elif _timer <= 0.0:
				GameState.notice.emit("Se escapó la pesca...")
				_end()


func _catch() -> void:
	AudioBus.play_sfx("ui_decide")
	if _rng.randf() < POKEMON_CHANCE * (1.4 if rod_tier > 1 else 1.0):
		var species := _pick_water_species()
		var spawner := main.get_node_or_null("Spawner") as WildSpawner if main != null else null
		if spawner != null and species != null and player != null:
			var at := player.global_position + Vector3(2.0, 0, 2.0)
			spawner.spawn_species(species, at, _rng.randf() < 0.02, true)
			GameState.notice.emit("¡Algo tiró de la caña! Salió un %s." % species.display_name)
			_end()
			return
	GameState.add_item("raw-fish", 1)
	GameState.notice.emit("¡Sacaste un Pescado Crudo!")
	AudioBus.play_jingle("me_item")
	_end()


## Pokémon de agua de la Pokédex regional: dulce (Caña Vieja) o salado (Caña Buena).
func _pick_water_species() -> SpeciesData:
	var habitat := SpeciesData.Habitat.SEA if rod_tier > 1 else SpeciesData.Habitat.FRESHWATER
	var pool: Array[SpeciesData] = []
	for species: SpeciesData in WildSpawner.ALL_SPECIES.species:
		if species.spawn_weight > 0.0 and not species.is_legendary and not species.is_mythical \
				and species.habitats.has(habitat) and Regions.allows(species):
			pool.append(species)
	if pool.is_empty():
		return null
	return pool[_rng.randi() % pool.size()]


func _end() -> void:
	state = State.DONE
	queue_free()
