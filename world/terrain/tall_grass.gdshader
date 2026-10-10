shader_type spatial;
// Hierba alta HD-2D: briznas pixel art como billboard en eje Y (MultiMesh), mecidas
// por el viento y apartadas por los actores cercanos (jugador y Pokémon).
render_mode unshaded, cull_disabled;

uniform sampler2D blade_tex : source_color, filter_nearest;
// Base oscura y puntas claras, como la hierba de encuentros de B2W2.
uniform vec3 tint_bottom = vec3(0.32, 0.5, 0.3);
uniform vec3 tint_top = vec3(0.62, 0.82, 0.5);
uniform float wind_strength = 0.06;
uniform float wind_speed = 1.6;
// Actores que apartan la hierba: xyz = posición en el mundo, w = radio (0 = vacío).
uniform vec4 actors[16];
uniform float push_strength = 0.45;
uniform float alpha_cutoff = 0.5;
global uniform vec4 time_tint;
global uniform vec4 season_tint;

varying float shade;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	// Billboard en eje Y (igual que BILLBOARD_FIXED_Y de StandardMaterial3D).
	vec3 cam_forward = INV_VIEW_MATRIX[2].xyz;
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), cam_forward));
	vec3 forward = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	// Solo se mueve la parte de arriba de la brizna (UV.y = 0 arriba).
	float top = 1.0 - UV.y;

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
	vec3 local = VERTEX;
	local.y *= 1.0 - squash * 0.45;
	vec3 world_vertex = origin + right * local.x + vec3(0.0, local.y, 0.0) + forward * local.z + offset;
	// Las instancias no tienen rotación ni escala: volver a local es restar el origen.
	VERTEX = world_vertex - origin;
	// Variación de tono por instancia, para que el parche no se vea uniforme.
	shade = 0.85 + 0.15 * fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 texel = texture(blade_tex, UV);
	if (texel.a < alpha_cutoff) {
		discard;
	}
	ALBEDO = texel.rgb * mix(tint_top, tint_bottom, UV.y) * shade * time_tint.rgb * season_tint.rgb;
}
