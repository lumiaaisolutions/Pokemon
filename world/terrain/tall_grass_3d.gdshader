shader_type spatial;
// Hierba alta HD-2D en 3D (mata de 2 planos cruzados, PropModels3D.cross_mesh, en
// MultiMesh): mecida por el viento y apartada por los actores cercanos (jugador y
// Pokémon), igual que el shader anterior (world/terrain/tall_grass.gdshader) pero sobre
// una malla real en vez de un plano billboard (regla 1 de docs/reglas_calidad.md,
// 2026-10-10: nada plano).
render_mode unshaded, cull_disabled;

uniform sampler2D blade_tex : source_color, filter_nearest;
uniform vec3 tint_bottom = vec3(0.32, 0.5, 0.3);
uniform vec3 tint_top = vec3(0.62, 0.82, 0.5);
uniform float wind_strength = 0.06;
uniform float wind_speed = 1.6;
// Altura (m) de la mata: normaliza VERTEX.y a 0 (pie) .. 1 (punta) para el viento y el push.
uniform float blade_height = 0.5;
// Actores que apartan la hierba: xyz = posición en el mundo, w = radio (0 = vacío).
uniform vec4 actors[16];
uniform float push_strength = 0.45;
uniform float alpha_cutoff = 0.5;
global uniform vec4 time_tint;
global uniform vec4 season_tint;

varying float shade;
varying float v_top;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	// Las instancias del MultiMesh no tienen rotación ni escala (basis identidad): el
	// mundo es origin + VERTEX, igual que en el shader de hierba anterior.
	float top = clamp(VERTEX.y / max(blade_height, 0.01), 0.0, 1.0);
	v_top = top;
	vec3 offset = vec3(0.0);
	offset.x += sin(TIME * wind_speed + origin.x * 0.35 + origin.z * 0.2) * wind_strength * top;
	offset.z += cos(TIME * wind_speed * 0.8 + origin.z * 0.3) * wind_strength * 0.5 * top;
	float squash = 0.0;
	for (int i = 0; i < 16; i++) {
		if (actors[i].w <= 0.0) {
			continue;
		}
		vec3 away = origin - actors[i].xyz;
		away.y = 0.0;
		float dist = length(away);
		float influence = 1.0 - smoothstep(0.0, actors[i].w, dist);
		if (influence > 0.0) {
			vec3 dir = dist > 0.001 ? away / dist : vec3(1.0, 0.0, 0.0);
			offset += dir * influence * push_strength * top;
			squash = max(squash, influence);
		}
	}
	VERTEX.y *= 1.0 - squash * 0.3;
	VERTEX += offset;
	shade = 0.85 + 0.15 * fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 texel = texture(blade_tex, UV);
	if (texel.a < alpha_cutoff) {
		discard;
	}
	ALBEDO = texel.rgb * mix(tint_bottom, tint_top, v_top) * shade * time_tint.rgb * season_tint.rgb;
}
