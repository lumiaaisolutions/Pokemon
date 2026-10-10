class_name SpriteMaterials
extends RefCounted
## Materiales del shader sprite_billboard (de pie, se inclinan al mirar desde arriba),
## uno por textura y tinte, compartidos entre todos los sprites que la usan.

const SHADER := preload("res://world/effects/sprite_billboard.gdshader")

static var _cache := {}


static func for_texture(texture: Texture2D, tint: Color = Color.WHITE, glow: float = 0.0, seasonal: bool = false) -> ShaderMaterial:
	var key := "%d:%s:%.1f:%s" % [texture.get_instance_id(), tint.to_html(), glow, seasonal]
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("sprite_texture", texture)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("glow", glow)
	material.set_shader_parameter("seasonal", 1.0 if seasonal else 0.0)
	_cache[key] = material
	return material


## Configura un Sprite3D para el shader: pies en el origen del nodo.
static func apply(sprite: Sprite3D, foot_offset_px: int = 0) -> void:
	sprite.material_override = for_texture(sprite.texture)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	var cell_height := sprite.texture.get_height() / float(sprite.vframes)
	sprite.offset.y = cell_height * 0.5 - foot_offset_px
	sprite.position.y = 0.0
