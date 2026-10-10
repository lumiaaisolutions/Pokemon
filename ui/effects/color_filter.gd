class_name ColorFilter
extends CanvasLayer
## Filtro de pantalla para daltonismo (Opciones > Accesibilidad): corrige los colores
## (daltonización) para protanopía, deuteranopía o tritanopía. Vive en la raíz y dura
## toda la sesión.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform int mode = 0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	if (mode > 0) {
		// Simulación LMS del tipo de daltonismo y redistribución del error a los canales visibles.
		mat3 rgb2lms = mat3(vec3(17.8824, 3.45565, 0.0299566), vec3(43.5161, 27.1554, 0.184309), vec3(4.11935, 3.86714, 1.46709));
		mat3 lms2rgb = inverse(rgb2lms);
		vec3 lms = rgb2lms * c;
		vec3 sim;
		if (mode == 1) {
			sim = vec3(2.02344 * lms.y - 2.52581 * lms.z, lms.y, lms.z);
		} else if (mode == 2) {
			sim = vec3(lms.x, 0.494207 * lms.x + 1.24827 * lms.z, lms.z);
		} else {
			sim = vec3(lms.x, lms.y, -0.395913 * lms.x + 0.801109 * lms.y);
		}
		vec3 error = c - lms2rgb * sim;
		vec3 shift = vec3(0.0, error.r * 0.7 + error.g, error.r * 0.7 + error.b);
		c = clamp(c + shift, 0.0, 1.0);
	}
	COLOR = vec4(c, 1.0);
}
"""

var _rect: ColorRect


static func ensure(root: Node) -> ColorFilter:
	var existing := root.get_node_or_null("ColorFilter") as ColorFilter
	if existing != null:
		return existing
	var filter := ColorFilter.new()
	filter.name = "ColorFilter"
	filter.layer = 100
	root.add_child.call_deferred(filter)
	return filter


func _init() -> void:
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	_rect.material = material
	_rect.visible = false
	add_child(_rect)


func set_mode(mode: int) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("mode", mode)
	_rect.visible = mode > 0


func get_mode() -> int:
	return int((_rect.material as ShaderMaterial).get_shader_parameter("mode")) if _rect.visible else 0
