class_name CaptureRules
## Probabilidad de captura en el mundo (estilo Leyendas Arceus, basada en la fórmula
## de los juegos): ratio oficial de la especie, vida restante, Pokéball, temperamento,
## sigilo (no te vio) y aturdido.

## Bonos y castigos.
const POKEBALL := 1.0
const STUNNED_BONUS := 2.5
const STEALTH_BONUS := 2.0
const TEMPERAMENT := {
	SpeciesData.Temperament.WANDER: 1.0,
	SpeciesData.Temperament.CURIOUS: 1.15,
	SpeciesData.Temperament.SHY: 0.85,
	SpeciesData.Temperament.AGGRESSIVE: 0.9,
	SpeciesData.Temperament.TERRITORIAL: 0.9,
}
## Sacudidas de la Pokéball antes de confirmar la captura.
const SHAKES := 3


## Probabilidad de captura en [0, 1].
## a = (3·PSmax − 2·PS) · ratio · ball / (3·PSmax), como en los juegos; p = a / 255.
static func probability(species: SpeciesData, hp_ratio: float, ball: float, stunned: bool, stealth: bool) -> float:
	var hp_term := (3.0 - 2.0 * clampf(hp_ratio, 0.0, 1.0)) / 3.0
	var a := hp_term * species.capture_rate * ball
	a *= TEMPERAMENT.get(species.temperament, 1.0)
	if stunned:
		a *= STUNNED_BONUS
	if stealth:
		a *= STEALTH_BONUS
	return clampf(a / 255.0, 0.0, 1.0)


## Probabilidad de que la ball aguante cada sacudida (la captura necesita las 3).
static func shake_probability(capture_probability: float) -> float:
	return pow(capture_probability, 1.0 / SHAKES)


## ¿Lo tomas por sorpresa? Si no te ha visto: está tranquilo y Nate está fuera de su
## campo de visión (por la espalda o a un lado lejos).
static func is_stealthy(actor: PokemonActor, thrower: Node3D) -> bool:
	# De espaldas cuenta mientras no te está enfrentando (quieto, paseando, posado,
	# huyendo, escondiéndose o regresando a casa).
	if not actor.state in [PokemonActor.State.IDLE, PokemonActor.State.WANDER, PokemonActor.State.PERCHED,
			PokemonActor.State.FLEE, PokemonActor.State.HIDE, PokemonActor.State.RETURN]:
		return false
	var to_thrower := thrower.global_position - actor.global_position
	to_thrower.y = 0.0
	if to_thrower.length() < 0.01:
		return false
	return actor.facing_world().dot(to_thrower.normalized()) < 0.2
