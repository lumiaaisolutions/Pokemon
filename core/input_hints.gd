extends Node
## Detecta el último dispositivo usado (teclado/mouse o mando) para que la UI
## muestre los botones correctos: teclas y clics, o los símbolos de PlayStation.

signal device_changed(gamepad: bool)

const PAD_NAMES := {
	JOY_BUTTON_A: "✕", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Share", JOY_BUTTON_START: "Options", JOY_BUTTON_TOUCHPAD: "Touchpad",
	JOY_BUTTON_DPAD_UP: "↑", JOY_BUTTON_DPAD_DOWN: "↓", JOY_BUTTON_DPAD_LEFT: "←", JOY_BUTTON_DPAD_RIGHT: "→",
}
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Clic izq.", MOUSE_BUTTON_RIGHT: "Clic der.",
	MOUSE_BUTTON_WHEEL_UP: "Rueda ↑", MOUSE_BUTTON_WHEEL_DOWN: "Rueda ↓",
}

## Último dispositivo usado: true si fue un mando.
var gamepad := false


func _input(event: InputEvent) -> void:
	var uses_pad := gamepad
	if event is InputEventJoypadButton:
		uses_pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4:
		uses_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		uses_pad = false
	if uses_pad != gamepad:
		gamepad = uses_pad
		device_changed.emit(gamepad)


## Nombre corto del botón de action en el dispositivo actual (p. ej. "Q" o "△").
## pad: -1 = el último usado, 0 = teclado y mouse, 1 = mando.
func hint(action: StringName, pad: int = -1) -> String:
	if not InputMap.has_action(action):
		return "?"
	var use_pad := gamepad if pad < 0 else pad == 1
	var keyboard := ""
	for event in InputMap.action_get_events(action):
		if use_pad:
			if event is InputEventJoypadButton:
				return PAD_NAMES.get((event as InputEventJoypadButton).button_index, "Botón")
			if event is InputEventJoypadMotion:
				var axis := (event as InputEventJoypadMotion).axis
				if axis == JOY_AXIS_TRIGGER_LEFT:
					return "L2"
				if axis == JOY_AXIS_TRIGGER_RIGHT:
					return "R2"
				return "Stick"
		elif keyboard == "":
			if event is InputEventKey:
				var key := event as InputEventKey
				var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
				keyboard = "Espacio" if code == KEY_SPACE else OS.get_keycode_string(code)
			elif event is InputEventMouseButton:
				keyboard = MOUSE_NAMES.get((event as InputEventMouseButton).button_index, "Clic")
	return keyboard if keyboard != "" else "?"


## "[Q] texto" con el botón del dispositivo actual.
func label(action: StringName, text: String) -> String:
	return "[%s] %s" % [hint(action), text]
