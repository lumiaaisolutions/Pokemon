class_name FoliageMaterials
extends RefCounted
## Materiales del shader foliage_material (follaje 3D con luz normal y tinte de estación),
## uno por textura/tinte/estación/brillo, compartidos entre todas las mallas que lo usan
## (ver world/region/prop_models.gd).

const SHADER := preload("res://world/effects/foliage_material.gdshader")

static var _cache := {}


static func for_texture(texture: Texture2D, tint: Color = Color.WHITE, seasonal: bool = false, glow: bool = false) -> ShaderMaterial:
	var key := "%d:%s:%s:%s" % [texture.get_instance_id(), tint.to_html(), seasonal, glow]
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("albedo_tex", texture)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("seasonal", 1.0 if seasonal else 0.0)
	material.set_shader_parameter("glow", 1.0 if glow else 0.0)
	_cache[key] = material
	return material
