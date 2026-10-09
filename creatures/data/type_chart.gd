class_name TypeChart
## Tabla de efectividad oficial (Gen 6+) de los 18 tipos: ×2, ×0.5 y ×0. Lo que no
## aparece aquí es ×1. La usan las peleas en el mundo y el combate (Fase 3).

const T := PokemonTypes.Type

const SUPER := {
	T.NORMAL: [],
	T.FIRE: [T.GRASS, T.ICE, T.BUG, T.STEEL],
	T.WATER: [T.FIRE, T.GROUND, T.ROCK],
	T.ELECTRIC: [T.WATER, T.FLYING],
	T.GRASS: [T.WATER, T.GROUND, T.ROCK],
	T.ICE: [T.GRASS, T.GROUND, T.FLYING, T.DRAGON],
	T.FIGHTING: [T.NORMAL, T.ICE, T.ROCK, T.DARK, T.STEEL],
	T.POISON: [T.GRASS, T.FAIRY],
	T.GROUND: [T.FIRE, T.ELECTRIC, T.POISON, T.ROCK, T.STEEL],
	T.FLYING: [T.GRASS, T.FIGHTING, T.BUG],
	T.PSYCHIC: [T.FIGHTING, T.POISON],
	T.BUG: [T.GRASS, T.PSYCHIC, T.DARK],
	T.ROCK: [T.FIRE, T.ICE, T.FLYING, T.BUG],
	T.GHOST: [T.PSYCHIC, T.GHOST],
	T.DRAGON: [T.DRAGON],
	T.DARK: [T.PSYCHIC, T.GHOST],
	T.STEEL: [T.ICE, T.ROCK, T.FAIRY],
	T.FAIRY: [T.FIGHTING, T.DRAGON, T.DARK],
}

const NOT_VERY := {
	T.NORMAL: [T.ROCK, T.STEEL],
	T.FIRE: [T.FIRE, T.WATER, T.ROCK, T.DRAGON],
	T.WATER: [T.WATER, T.GRASS, T.DRAGON],
	T.ELECTRIC: [T.ELECTRIC, T.GRASS, T.DRAGON],
	T.GRASS: [T.FIRE, T.GRASS, T.POISON, T.FLYING, T.BUG, T.DRAGON, T.STEEL],
	T.ICE: [T.FIRE, T.WATER, T.ICE, T.STEEL],
	T.FIGHTING: [T.POISON, T.FLYING, T.PSYCHIC, T.BUG, T.FAIRY],
	T.POISON: [T.POISON, T.GROUND, T.ROCK, T.GHOST],
	T.GROUND: [T.GRASS, T.BUG],
	T.FLYING: [T.ELECTRIC, T.ROCK, T.STEEL],
	T.PSYCHIC: [T.PSYCHIC, T.STEEL],
	T.BUG: [T.FIRE, T.FIGHTING, T.POISON, T.FLYING, T.GHOST, T.STEEL, T.FAIRY],
	T.ROCK: [T.FIGHTING, T.GROUND, T.STEEL],
	T.GHOST: [T.DARK],
	T.DRAGON: [T.STEEL],
	T.DARK: [T.FIGHTING, T.DARK, T.FAIRY],
	T.STEEL: [T.FIRE, T.WATER, T.ELECTRIC, T.STEEL],
	T.FAIRY: [T.FIRE, T.POISON, T.STEEL],
}

const IMMUNE := {
	T.NORMAL: [T.GHOST],
	T.ELECTRIC: [T.GROUND],
	T.FIGHTING: [T.GHOST],
	T.POISON: [T.STEEL],
	T.GROUND: [T.FLYING],
	T.PSYCHIC: [T.DARK],
	T.GHOST: [T.NORMAL],
	T.DRAGON: [T.FAIRY],
}


## Multiplicador de un ataque de tipo attack contra un defensor con esos tipos.
static func effectiveness(attack: PokemonTypes.Type, defender_types: Array) -> float:
	var multiplier := 1.0
	for defender in defender_types:
		if IMMUNE.get(attack, []).has(defender):
			return 0.0
		if SUPER.get(attack, []).has(defender):
			multiplier *= 2.0
		elif NOT_VERY.get(attack, []).has(defender):
			multiplier *= 0.5
	return multiplier


## ¿Tiene alguno de los tipos de attacker ventaja (×2 o más) contra defender?
static func has_advantage(attacker_types: Array, defender_types: Array) -> bool:
	for attack in attacker_types:
		if effectiveness(attack, defender_types) >= 2.0:
			return true
	return false
