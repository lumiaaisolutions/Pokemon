class_name AdaptiveDifficulty
extends RefCounted
## Dificultad adaptable (Fase 6, 2026-10-11, decisión de Fernando: "se adapta sola a tu
## nivel; si ganas mucho, los rivales se vuelven más listos"). No sustituye la elección
## manual de Fernando (GameState.difficulty / DIFFICULTIES, fija durante la partida):
## encima de esa base, un valor continuo GameState.performance (-1 floja, 0 neutral,
## +1 arrolladora) sube con rachas de victorias y vida alta al terminar los combates, y
## baja al desmayarte o con capturas fáciles sin pelear. Se usa en:
## - GameState.difficulty_value("damage"/"money_loss"/"recovery"): multiplica el valor
##   de la dificultad elegida (a performance 0 no cambia nada, por eso el valor por
##   defecto sigue siendo exactamente el de DIFFICULTIES).
## - BattleManager._smart_opponent (menos espera entre esquivas de los rivales listos).
## - town_services.gd (curaciones extra de líderes, Alto Mando y el jefe del equipo
##   villano) y BattleManager._win (objetos y dinero que sueltan los salvajes).

const STEP := 0.05
const MAX := 1.0
const MIN := -1.0


## Tras cada combate del jugador (salvaje o entrenador). hp_ratio_end: vida del
## compañero que terminó el combate (0.0 si perdió). streak: racha de victorias actual.
static func record_battle(won: bool, hp_ratio_end: float, streak: int) -> void:
	var delta := 0.0
	if not won:
		delta = -STEP * 2.0
	elif hp_ratio_end >= 0.75 and streak >= 2:
		delta = STEP
	elif hp_ratio_end <= 0.25:
		delta = -STEP * 0.5
	GameState.performance = clampf(GameState.performance + delta, MIN, MAX)


## Captura sin pelear (sigilo) o con la presa casi intacta: un reto menos, baja un poco.
static func record_easy_capture() -> void:
	GameState.performance = clampf(GameState.performance - STEP * 0.5, MIN, MAX)


## Multiplicador extra sobre GameState.DIFFICULTIES[...]["damage"] (daño que recibes).
static func damage_multiplier() -> float:
	return 1.0 + GameState.performance * 0.3


## Multiplicador extra sobre ["recovery"] (tiempo de recuperación del desmayo).
static func recovery_multiplier() -> float:
	return 1.0 - GameState.performance * 0.15


## Multiplicador extra sobre ["money_loss"] (dinero perdido al desmayarte).
static func money_loss_multiplier() -> float:
	return 1.0 + GameState.performance * 0.25


## Curaciones extra de un rival listo (gimnasio, Liga, jefe del equipo villano).
static func extra_heals() -> int:
	return maxi(0, int(round(GameState.performance * 2.0)))


## Qué tanto más seguido esquiva un rival listo (BattleManager._smart_opponent): más
## si vas arrollando, menos (incluso negativo) si vas flojo.
static func dodge_bonus() -> float:
	return clampf(GameState.performance * 0.15, -0.1, 0.15)


## Objetos y dinero que sueltan los salvajes al ganar: más si vas flojo (te ayuda a
## remontar), algo menos si vas arrollando.
static func reward_multiplier() -> float:
	return clampf(1.0 - GameState.performance * 0.3, 0.7, 1.3)


## Línea para Opciones y la Ficha de entrenador.
static func label() -> String:
	if GameState.performance > 0.4:
		return "Vas arrollando: los rivales están más listos, pegan algo más fuerte y sueltan un poco menos."
	if GameState.performance < -0.4:
		return "La estás pasando duro: los rivales aflojan un poco y sueltan más premios."
	return "Nivel equilibrado con tu forma de jugar."
