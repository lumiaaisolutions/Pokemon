class_name MoveInput
extends RefCounted
## Botones de los 4 movimientos del compañero: teclas 1-4; en el mando, mantener R1
## (move_modifier) y pulsar □ △ ○ ✕. Estilo: mantener correr = Fuerte, mantener
## bucear = Ágil.

const ACTIONS := ["attack_1", "attack_2", "attack_3", "attack_4"]


static func just_pressed(slot: int) -> bool:
	if not Input.is_action_just_pressed(ACTIONS[slot]):
		return false
	# En el mando, los botones de cara solo cuentan con R1 (si no, son saltar, etc.).
	return not InputHints.gamepad or Input.is_action_pressed("move_modifier")


static func style() -> int:
	if Input.is_action_pressed("run"):
		return Moves.Style.STRONG
	if Input.is_action_pressed("dive"):
		return Moves.Style.AGILE
	return Moves.Style.NORMAL


## Texto del botón de un espacio ("1" o "R1+□").
static func hint(slot: int) -> String:
	if InputHints.gamepad:
		return "R1+" + InputHints.hint(ACTIONS[slot])
	return InputHints.hint(ACTIONS[slot])
