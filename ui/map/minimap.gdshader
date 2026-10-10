shader_type canvas_item;
// Minimapa circular: recorta el mapa alrededor del jugador, lo gira con la cámara y
// oscurece lo no explorado (niebla). Pixel art: muestreo nítido.

uniform sampler2D map_tex : filter_nearest;
uniform sampler2D fog_tex : filter_linear;
// Centro (UV del mapa), radio visible (en UV) y giro de la cámara (radianes).
uniform vec2 center_uv = vec2(0.5);
uniform float radius_uv = 0.12;
uniform float rotation = 0.0;
uniform vec4 border_color : source_color = vec4(0.95, 0.95, 0.9, 1.0);
uniform vec4 fog_color : source_color = vec4(0.1, 0.12, 0.16, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}
	if (d > 0.93) {
		COLOR = border_color;
	} else {
		float c = cos(rotation);
		float s = sin(rotation);
		vec2 rotated = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
		vec2 uv = center_uv + rotated * radius_uv;
		if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
			COLOR = fog_color;
		} else {
			vec3 map = texture(map_tex, uv).rgb;
			float seen = texture(fog_tex, uv).r;
			COLOR = vec4(mix(fog_color.rgb, map, step(0.5, seen)), 1.0);
		}
	}
}
