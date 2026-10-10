shader_type canvas_item;
// Mapa completo: el mundo entero con la niebla de exploración y una cuadrícula leve.

uniform sampler2D map_tex : filter_nearest;
uniform sampler2D fog_tex : filter_linear;
uniform vec4 fog_color : source_color = vec4(0.1, 0.12, 0.16, 1.0);

void fragment() {
	vec3 map = texture(map_tex, UV).rgb;
	float seen = step(0.5, texture(fog_tex, UV).r);
	vec3 color = mix(fog_color.rgb, map, seen);
	// Cuadrícula cada 1/8 del mapa.
	vec2 grid = abs(fract(UV * 8.0) - 0.5);
	if (min(grid.x, grid.y) > 0.495) {
		color *= 0.85;
	}
	COLOR = vec4(color, 1.0);
}
