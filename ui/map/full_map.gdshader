shader_type canvas_item;
// Mapa completo con zoom: muestra la parte del mundo alrededor de view_center (UV del
// mundo) con view_size de ancho, la niebla de exploración, relieve suave y cuadrícula.

uniform sampler2D map_tex : filter_nearest;
uniform sampler2D fog_tex : filter_linear;
uniform vec4 fog_color : source_color = vec4(0.16, 0.18, 0.24, 1.0);
uniform vec2 view_center = vec2(0.5, 0.5);
uniform float view_size = 1.0;
uniform vec2 texel = vec2(0.002, 0.002);

void fragment() {
	vec2 uv = view_center + (UV - 0.5) * view_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		COLOR = vec4(fog_color.rgb * 0.7, 1.0);
	} else {
		vec3 map = texture(map_tex, uv).rgb;
		// Relieve: más claro hacia el noroeste, más oscuro al sureste (según el brillo vecino).
		float here = dot(map, vec3(0.33));
		float nw = dot(texture(map_tex, uv - texel).rgb, vec3(0.33));
		map *= 1.0 + clamp((here - nw) * 1.6, -0.18, 0.18);
		float seen = smoothstep(0.35, 0.65, texture(fog_tex, uv).r);
		// Niebla con trama diagonal para que se note que falta explorar.
		float hatch = step(0.5, fract((UV.x + UV.y) * 60.0)) * 0.04;
		vec3 color = mix(fog_color.rgb + hatch, map, seen);
		vec2 grid = abs(fract(uv * 16.0) - 0.5);
		if (min(grid.x, grid.y) > 0.497 - 0.002 * view_size) {
			color *= 0.88;
		}
		COLOR = vec4(color, 1.0);
	}
}
