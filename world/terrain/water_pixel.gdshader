shader_type spatial;
// Agua HD-2D con la textura de B2W2: muestreo en coordenadas del mundo a la misma
// densidad de píxeles que el resto, desplazamiento lento cuantizado a píxeles y
// espuma de píxel donde el agua es poco profunda (orilla).
render_mode unshaded, cull_disabled, depth_draw_always;
global uniform vec4 time_tint;

uniform sampler2D water_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float px_per_meter = 17.5;
uniform vec2 flow = vec2(0.6, 0.25);
uniform float alpha = 0.88;
uniform vec3 foam_color : source_color = vec3(0.92, 0.97, 1.0);
uniform float foam_depth = 0.35;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 size = vec2(textureSize(water_tex, 0));
	// El desplazamiento avanza de píxel en píxel para no difuminar la textura.
	vec2 offset = floor(TIME * flow * px_per_meter) / px_per_meter;
	vec2 pixel = floor((world_pos.xz + offset) * px_per_meter);
	ALBEDO = texture(water_tex, (pixel + 0.5) / size).rgb;
	ALPHA = alpha;

	// Profundidad del agua en este punto: distancia entre la superficie y el fondo.
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float water_depth = -view.z + VERTEX.z;
	if (water_depth < foam_depth) {
		ALBEDO = foam_color;
		ALPHA = 0.95;
	}
	ALBEDO *= time_tint.rgb;
}
