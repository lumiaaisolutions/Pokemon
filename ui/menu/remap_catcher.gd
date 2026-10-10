class_name RemapCatcher
extends Node
## Espera la siguiente tecla, botón del mouse o del mando y se la asigna a action
## (Opciones > Reasignar botones). Esc cancela.

signal done

var action := ""
var _listening := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func listen() -> void:
	# Se activa un cuadro después para no tomar el clic/botón que abrió la espera.
	await get_tree().process_frame
	_listening = true


func _input(event: InputEvent) -> void:
	if not _listening:
		return
	var accepted: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_ESCAPE:
			_finish()
			get_viewport().set_input_as_handled()
			return
		var clean := InputEventKey.new()
		clean.physical_keycode = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		accepted = clean
	elif event is InputEventMouseButton and event.pressed:
		var clean := InputEventMouseButton.new()
		clean.button_index = (event as InputEventMouseButton).button_index
		accepted = clean
	elif event is InputEventJoypadButton and event.pressed:
		var clean := InputEventJoypadButton.new()
		clean.button_index = (event as InputEventJoypadButton).button_index
		accepted = clean
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
		var motion := event as InputEventJoypadMotion
		var clean := InputEventJoypadMotion.new()
		clean.axis = motion.axis
		clean.axis_value = signf(motion.axis_value)
		accepted = clean
	if accepted != null:
		accepted.device = -1
		GameOptions.remap(action, accepted)
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	_listening = false
	done.emit()
