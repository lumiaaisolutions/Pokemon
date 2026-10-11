class_name PoiArt
extends RefCounted
## Pixel art de los puntos de interés (tablilla, boca de cueva, letrero), con el mismo
## contorno y escala que PropArt. El cofre y el pozo pasaron a 3D propio (Chest3D y
## PointsOfInterest._well, 2026-10-10: regla 1 de docs/reglas_calidad.md).

static var _cache := {}


static func _art(key: String, painter: Callable) -> Texture2D:
	if not _cache.has(key):
		var image: Image = painter.call()
		PropArt._outline(image)
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


static func tablet() -> Texture2D:
	return _art("tablet", func() -> Image:
		var image := Image.create_empty(16, 24, false, Image.FORMAT_RGBA8)
		PropArt._rect(image, 2, 2, 12, 22, Color(0.6, 0.6, 0.62))
		PropArt._rect(image, 3, 1, 10, 1, Color(0.6, 0.6, 0.62))
		for y in range(5, 20, 3):
			PropArt._rect(image, 4, y, 2 + (y % 5), 1, Color(0.35, 0.35, 0.4))
			PropArt._rect(image, 8, y, 3, 1, Color(0.35, 0.35, 0.4))
		return image)


static func cave_mouth() -> Texture2D:
	return _art("cave", func() -> Image:
		var image := Image.create_empty(30, 20, false, Image.FORMAT_RGBA8)
		for y in 20:
			var half := int(sqrt(maxf(0.0, 1.0 - pow((y - 20.0) / 18.0, 2.0))) * 12.0)
			PropArt._rect(image, 15 - half, y, half * 2, 1, Color(0.08, 0.07, 0.1) if y > 3 else Color(0.2, 0.18, 0.2))
		return image)


static func signpost() -> Texture2D:
	return _art("signpost", func() -> Image:
		var image := Image.create_empty(16, 22, false, Image.FORMAT_RGBA8)
		PropArt._rect(image, 7, 8, 2, 14, Color(0.45, 0.3, 0.18))
		PropArt._rect(image, 1, 2, 14, 7, Color(0.7, 0.52, 0.3))
		PropArt._rect(image, 3, 4, 10, 1, Color(0.4, 0.28, 0.16))
		PropArt._rect(image, 3, 6, 7, 1, Color(0.4, 0.28, 0.16))
		return image)
