class_name DizzyStars
extends Node3D
## Estrellitas pixel art girando sobre la cabeza (aturdido o desmayado). Las usan el
## jugador desmayado y los Pokémon debilitados.

const PIXEL := 0.057
const COUNT := 3
const RADIUS := 0.45
const SPEED := 3.5


## Crea las estrellas a height metros sobre el origen del dueño.
static func create(height: float, scale_factor: float = 1.0) -> DizzyStars:
	var stars := DizzyStars.new()
	stars.name = "DizzyStars"
	stars.position.y = height
	var rows := ["...Y...", "..YYY..", "YYYYYYY", ".YYYYY.", "..YYY..", ".YY.YY.", "YY...YY"]
	var image := Image.create_empty(7, 7, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 7:
			if rows[y][x] == "Y":
				image.set_pixel(x, y, Color(1.0, 0.9, 0.25))
	var texture := ImageTexture.create_from_image(image)
	for i in COUNT:
		var star := Sprite3D.new()
		star.texture = texture
		star.pixel_size = PIXEL * scale_factor
		star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		star.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		star.shaded = false
		star.layers = 2
		var angle := TAU * i / COUNT
		star.position = Vector3(cos(angle), 0.0, sin(angle)) * RADIUS * scale_factor
		stars.add_child(star)
	return stars


func _process(delta: float) -> void:
	rotate_y(delta * SPEED)
