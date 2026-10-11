class_name LoadingScreen
extends CanvasLayer
## Pantalla de carga (pedido de Fernando, 2026-10-11): tapa la construcción del mundo al
## iniciar o cargar la partida y al llegar de un viaje entre regiones, hasta que está
## listo para jugar (zonas cercanas construidas, navegación horneada y el jugador en el
## suelo). Fondo borroso de la propia vista (difuminada y en tonos suaves, sin saturar;
## si todavía no hay nada que mostrar, el difuminado igual queda como un fondo suave) con
## una Pokéball pixel art (estilo BW2, filtro NEAREST) girando encima. Al terminar, la
## tapa de arriba se abre con bisagra atrás (la de abajo no se mueve), el botón brilla y
## sale la luz de adentro para revelar el mundo. Barra delgada y un consejo pequeño abajo,
## los dos discretos: la Pokéball es lo principal. Nunca se queda atascada: un tope de
## seguridad la cierra aunque algo tarde de más.
## Se usa desde world/main.gd: la crea, la agrega como hija y llama a start(self).
##
## El difuminado no usa SCREEN_TEXTURE/hint_screen_texture en vivo cada cuadro: en este
## proyecto esa vía solo captura el mundo 3D opaco y dejaba a los sprites (compañero,
## jugador, NPC) sin difuminar, encima de todo (probado con capturas en los dos
## renderizadores, GLES3 y Metal/Forward+). En vez de eso, al arrancar, esta pantalla se
## queda oculta un cuadro, deja que se vea (y se fotografíe) el mundo real ya construido
## con get_viewport().get_texture() —lo mismo que usan las capturas de tools/snapshot.gd—,
## y recién entonces aparece ya con esa foto difuminada por un shader propio de fondo:
## mismo resultado visual (la vista real, borrosa, en tonos suaves), sin el hueco.

const TIP_SECONDS := 3.0
## Tope de seguridad: si el mundo no avisa que está listo en este tiempo, se cierra igual.
const MAX_WAIT_SECONDS := 15.0
## Resolución de la textura de la bola (pixel art: se ve el píxel al escalarla) y tamaño
## final en pantalla.
const BALL_TEXTURE_SIZE := 32
const BALL_SCREEN_SIZE := 168.0
## Vuelta completa cada N segundos (giro tranquilo, nada chillón).
const SPIN_SECONDS := 2.2

## [plantilla con %s opcional, acción de InputHints o "" si no la necesita].
const TIP_TEMPLATES := [
	["Corre manteniendo %s para moverte más rápido (gasta resistencia).", "run"],
	["Usa 1, 2, 3 y 4 (o R1 + ◻ △ ○ ✕ en el mando) para ordenar los movimientos de tu compañero mientras explora.", ""],
	["Mantén %s para abrir la rueda y cambiar de Pokémon sin pelear.", "companion"],
	["Monta a tu compañero con %s si es grande, o usa la bicicleta si ya la tienes.", "ride"],
	["Si tu compañero es de tipo Agua, surfeas sobre él en cuanto entras al agua.", ""],
	["En tu campamento puedes dormir, cocinar y pescar: abre el menú de la tienda.", ""],
	["El vínculo con tu compañero sube mientras lo llevas fuera; desde el nivel 5 aguanta un golpe fatal.", ""],
	["Las rocas agrietadas se rompen con la ayuda de tu compañero.", ""],
	["El pantano tóxico envenena si te quedas en su agua morada: cúralo con un Antídoto.", ""],
	["Pulsa %s para ver todos los controles del juego.", "help"],
	["El mapa (%s) muestra lo que ya exploraste y tus objetivos marcados.", "map"],
	["La investigación de una especie se completa foto a foto y desbloquea un movimiento nuevo en los niveles 3, 6 y 9.", ""],
	["De un entrenador no se huye: prepárate antes de acercarte a los que patrullan los caminos.", ""],
	["La megaevolución necesita la Piedra Llave y la megapiedra de tu Pokémon.", ""],
	["Cada bioma favorece un tipo de Pokémon salvaje: fíjate en el hábitat antes de ir a atrapar algo.", ""],
	["Guarda a tu compañero antes de nadar si no es de tipo Agua: lo recuperas al llegar a tierra.", ""],
	["El tablero de misiones (%s) junta actividades del Rotom, megapiedras, la foto del día e investigación.", "missions"],
	["Las bayas, los hongos y los minerales se recogen de arbustos, árboles y rocas por todo el mundo.", ""],
	["Si te desmayas, corres al Centro Pokémon más cercano y pierdes algo de dinero en el camino.", ""],
	["La rueda rápida de objetos (mantener %s) deja usar objetos sin abrir la Mochila.", "quick_items"],
	["Los guardianes de bioma son enormes y pelean por fases: ve preparado antes de retarlos.", ""],
	["Cada 20 minutos acompañándolo, tu compañero sube un punto de vínculo.", ""],
	["El clima cambia según el bioma y la estación: la lluvia de estrellas solo se ve de noche.", ""],
	["Puedes guardar la partida desde el menú, o esperar el autoguardado cada pocos minutos.", ""],
]

## Difumina la foto de la vista (uniform "source", no la pantalla en vivo) y la deja en
## tonos suaves: menos saturada y con un tinte crema encima.
const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D source : filter_linear;
uniform vec4 tint : source_color = vec4(0.93, 0.9, 0.86, 0.4);

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(source, 0)) * 3.0;
	vec3 sum = vec3(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			sum += texture(source, UV + vec2(float(x), float(y)) * texel).rgb;
		}
	}
	vec3 color = sum / 25.0;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(gray), 0.3);
	color = mix(color, tint.rgb, tint.a);
	COLOR = vec4(color, 1.0);
}
"""

var _root: Control
var _blur_rect: TextureRect
var _blur_material: ShaderMaterial
var _ball_holder: Control
var _top_half: TextureRect
var _bottom_half: TextureRect
var _flash: TextureRect
var _bar: ProgressBar
var _tip_label: Label
var _tip_index := -1
var _tip_timer := 0.0
var _closed := false
var _opening := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


## Arranca la espera (no se espera su resultado: corre junto al resto de main.gd._ready()).
func start(main: Node3D) -> void:
	_rotate_tip()
	_reveal_with_snapshot()
	_wait_ready(main)


func _process(delta: float) -> void:
	if _closed:
		return
	if not _opening:
		_ball_holder.rotation += delta * TAU / SPIN_SECONDS
	_tip_timer += delta
	if _tip_timer >= TIP_SECONDS:
		_tip_timer = 0.0
		_rotate_tip()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Fondo de respaldo primero (si la captura de pantalla no está disponible, p. ej. en
	# pruebas sin salida de píxeles): un fondo suave, nunca se ve el mundo sin tapar. El
	# difuminado va encima y lo tapa en cuanto tiene una foto real que mostrar.
	_root.add_child(UiKit.backdrop(1.0))
	_blur_rect = TextureRect.new()
	_blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = BLUR_SHADER
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = shader
	_blur_rect.material = _blur_material
	_root.add_child(_blur_rect)
	# Oculta hasta tener la foto limpia del mundo (ver _reveal_with_snapshot): si se
	# capturara ya visible, se fotografiaría a sí misma (tapando el mundo) en vez del mundo.
	_root.visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(360, 0)
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	_ball_holder = Control.new()
	_ball_holder.custom_minimum_size = Vector2.ONE * BALL_SCREEN_SIZE
	_ball_holder.pivot_offset = Vector2.ONE * BALL_SCREEN_SIZE * 0.5
	_ball_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ball_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_ball_holder)
	# La de abajo no se mueve al abrirse: va primero (queda detrás del destello y la tapa).
	_bottom_half = _half_rect(false)
	_ball_holder.add_child(_bottom_half)
	_flash = TextureRect.new()
	_flash.texture = _flash_texture()
	_flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.stretch_mode = TextureRect.STRETCH_SCALE
	_flash.pivot_offset = Vector2.ONE * BALL_SCREEN_SIZE * 0.5
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ball_holder.add_child(_flash)
	# La tapa de arriba: bisagra en la línea central (el pivote ya queda ahí, ver
	# _half_rect), se abre encogiéndose hacia esa línea como si girara hacia atrás.
	_top_half = _half_rect(true)
	_ball_holder.add_child(_top_half)

	_bar = UiKit.bar(0.0, 220, Color(0.76, 0.36, 0.33), 6)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_bar)

	_tip_label = UiKit.label_on_dark("", 15, Color(0.92, 0.9, 0.86), false)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(360, 0)
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_tip_label)


## Se queda oculta un cuadro para fotografiar el mundo limpio (sin esta pantalla encima:
## si se capturara ya visible, se fotografiaría a sí misma tapando el mundo, no el mundo)
## y aparece ya con esa foto difuminada de fondo. En pruebas sin salida de píxeles
## ("dummy") no hay foto real: se queda el fondo de respaldo (UiKit.backdrop) tapando.
func _reveal_with_snapshot() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var viewport := get_viewport()
	var image := viewport.get_texture().get_image() if viewport != null else null
	if image != null and image.get_size() != Vector2i.ZERO:
		var texture := ImageTexture.create_from_image(image)
		# TextureRect solo dibuja (y corre su shader) si tiene una textura propia; el
		# shader igual lee de "source", no de esta, pero tiene que haber alguna para dibujar.
		_blur_rect.texture = texture
		_blur_material.set_shader_parameter("source", texture)
	if is_instance_valid(_root):
		_root.visible = true


func _half_rect(top: bool) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _ball_half_texture(top)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.pivot_offset = Vector2.ONE * BALL_SCREEN_SIZE * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Mitad (de arriba o de abajo) de la Pokéball en pixel art (estilo BW2), con una sombra
## ligera tipo esfera (más clara donde pega la luz, más oscura en el borde) para que no se
## vea plana. Colores sin saturar (pedido de Fernando): nada chillón.
static func _ball_half_texture(top: bool) -> ImageTexture:
	var size := BALL_TEXTURE_SIZE
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	var radius := size * 0.47
	var band := size * 0.09
	var button_r := size * 0.17
	var button_ring := size * 0.04
	var red := Color(0.78, 0.33, 0.3)
	var white := Color(0.91, 0.89, 0.85)
	var dark := Color(0.22, 0.2, 0.21)
	var light_dir := Vector2(-0.4, -0.55).normalized()
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) - center
			var d := p.length()
			if d > radius:
				continue
			# Un pelín de traslape en la franja para que no se note la costura al cerrarse.
			if top and p.y > band * 0.6:
				continue
			if not top and p.y < -band * 0.6:
				continue
			var color: Color
			if absf(p.y) <= band:
				color = dark
			elif p.y < 0:
				color = red
			else:
				color = white
			if d <= button_r:
				color = dark if d > button_r - button_ring else white
			var light_term := p.normalized().dot(light_dir) if d > 0.5 else 0.0
			var shade := clampf(0.6 + light_term * 0.4, 0.3, 1.0)
			var rim := clampf((radius - d) / (radius * 0.18), 0.0, 1.0)
			shade *= lerpf(0.55, 1.0, rim)
			color = color.darkened(clampf(1.0 - shade, 0.0, 0.85))
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## Destello suave y redondo (sin rayos, para que sea calmado): empieza chico, en el botón,
## y crece como si la luz saliera de adentro de la bola al abrirse.
static func _flash_texture(size: int = 160) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	var radius := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var a := clampf(1.0 - d / radius, 0.0, 1.0)
			a = pow(a, 1.6)
			if a > 0.01:
				image.set_pixel(x, y, Color(1.0, 0.99, 0.95, a))
	return ImageTexture.create_from_image(image)


func _rotate_tip() -> void:
	var next := _tip_index
	if TIP_TEMPLATES.size() > 1:
		while next == _tip_index:
			next = randi() % TIP_TEMPLATES.size()
	else:
		next = 0
	_tip_index = next
	var entry: Array = TIP_TEMPLATES[_tip_index]
	var template: String = entry[0]
	var action: String = entry[1]
	_tip_label.text = template % InputHints.hint(action) if action != "" else template


## Espera a que el mundo de main esté listo (zonas cercanas, navegación y jugador en el
## suelo), con la barra avanzando según el progreso real; se abre y se cierra al terminar
## o, como tope de seguridad, si se pasa MAX_WAIT_SECONDS.
func _wait_ready(main: Node3D) -> void:
	var navigation := main.get_node_or_null("Navigation") as WorldNavigation
	var player := main.get_node_or_null("Player") as Player
	var world := main.get_node_or_null("World") as WorldBuilder
	var expected := float((2 * WorldBuilder.NEAR_RADIUS + 1) * (2 * WorldBuilder.NEAR_RADIUS + 1))
	var start_ms := Time.get_ticks_msec()
	while is_instance_valid(self) and is_inside_tree():
		var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
		var chunk_ratio := 1.0
		if is_instance_valid(world):
			chunk_ratio = clampf(float(world.near_chunks().size()) / expected, 0.0, 1.0)
		var nav_done := not is_instance_valid(navigation) or navigation.is_baked
		var nav_ratio := 1.0 if nav_done else clampf(float(navigation.baked_near_count()) / expected, 0.0, 0.95)
		var ratio := clampf(chunk_ratio * 0.4 + nav_ratio * 0.6, 0.0, 1.0)
		if is_instance_valid(_bar):
			_bar.value = ratio * 100.0
		var grounded := not is_instance_valid(player) or player.is_on_floor()
		if (nav_done and grounded) or elapsed >= MAX_WAIT_SECONDS:
			break
		await get_tree().process_frame
	await _open_and_close()


## La bola deja de girar; la tapa de arriba se abre con bisagra en la línea central (la de
## abajo no se mueve), el botón brilla y la luz sale de adentro; todo se desvanece hasta
## ver el mundo real detrás.
func _open_and_close() -> void:
	if _closed or not is_instance_valid(self):
		return
	_closed = true
	if is_instance_valid(_bar):
		_bar.value = 100.0
	if is_instance_valid(_ball_holder):
		# Para antes de abrirse en vez de frenar de golpe a media vuelta.
		var target := roundf(_ball_holder.rotation / TAU) * TAU
		var align := create_tween()
		align.tween_property(_ball_holder, "rotation", target, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await align.finished
		_opening = true
		var open_tween := create_tween()
		open_tween.set_parallel(true)
		# La tapa se encoge hacia la bisagra (línea central) y se inclina, como si girara
		# hacia atrás y se alejara; la de abajo queda fija.
		open_tween.tween_property(_top_half, "scale:y", 0.08, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		open_tween.tween_property(_top_half, "scale:x", 0.8, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		open_tween.tween_property(_top_half, "position:y", -BALL_SCREEN_SIZE * 0.1, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		open_tween.tween_property(_top_half, "modulate:a", 0.15, 0.3).set_delay(0.08)
		if is_instance_valid(_flash):
			# Primero brilla el botón (chico, concentrado) y luego la luz sale de adentro.
			_flash.scale = Vector2.ONE * 0.22
			var flash_tween := create_tween()
			flash_tween.tween_property(_flash, "modulate:a", 0.9, 0.1)
			flash_tween.parallel().tween_property(_flash, "scale", Vector2.ONE * 2.0, 0.5).set_delay(0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.3)
		await open_tween.finished
	await _close()


func _close() -> void:
	if not is_instance_valid(self):
		return
	if is_instance_valid(_root):
		var tween := create_tween()
		tween.tween_property(_root, "modulate:a", 0.0, 0.45)
		await tween.finished
	if is_instance_valid(self):
		queue_free()


## ¿Sigue tapando la pantalla? (pruebas).
func is_showing() -> bool:
	return not _closed and is_instance_valid(self) and is_inside_tree()
