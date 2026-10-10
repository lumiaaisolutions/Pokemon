shader_type spatial;
// Sprite pixel art de pie (billboard en eje Y) que se inclina hacia atrás desde su base
// cuando la cámara mira desde arriba, para que nunca se vea aplastado (como en los
// juegos HD-2D). El pivote es el origen del objeto: los sprites deben tener los pies
// ahí (Sprite3D con offset o QuadMesh con center_offset). Lo usan el jugador, los
// Pokémon, árboles, rocas y la decoración (ver SpriteMaterials).
// Color del vértice: modulate del Sprite3D; su alfa < 1 se dibuja con tramado
// (semitransparencia que conserva el pixel art y no necesita ordenar).
render_mode unshaded, cull_disabled;

uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
// La inclinación empieza cuando la cámara mira más abajo de tilt_start grados.
uniform float tilt_start = 25.0;
uniform float tilt_amount = 0.9;
uniform float max_tilt = 50.0;
// Por instancia: altura local (m) bajo la cual no se dibuja (p. ej. lo que queda bajo
// el agua al nadar) e inclinación extra hacia atrás en radianes (nadar buceando).
instance uniform float cut_bottom = -1000.0;
instance uniform float extra_tilt = 0.0;

varying float local_y;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);
	// Eje +Z de la cámara: apunta de la escena hacia la cámara.
	vec3 back = INV_VIEW_MATRIX[2].xyz;
	vec3 flat_back = vec3(back.x, 0.0, back.z);
	flat_back = length(flat_back) > 0.0001 ? normalize(flat_back) : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), flat_back));
	float pitch = degrees(asin(clamp(back.y, -1.0, 1.0)));
	float tilt = radians(clamp((pitch - tilt_start) * tilt_amount, 0.0, max_tilt));
	tilt = clamp(tilt + extra_tilt, -1.4, 1.45);
	local_y = VERTEX.y * scale_y;
	vec3 up = cos(tilt) * vec3(0.0, 1.0, 0.0) - sin(tilt) * flat_back;
	vec3 world = origin + right * VERTEX.x * scale_x + up * VERTEX.y * scale_y + flat_back * VERTEX.z;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec4 texel = texture(sprite_texture, UV);
	if (texel.a < 0.5 || local_y < cut_bottom) {
		discard;
	}
	// Tramado 2×2 para la semitransparencia.
	float threshold = (mod(floor(FRAGCOORD.x), 2.0) * 2.0 + mod(floor(FRAGCOORD.y), 2.0)) / 4.0 + 0.125;
	if (COLOR.a < 0.99 && COLOR.a <= threshold) {
		discard;
	}
	ALBEDO = texel.rgb * COLOR.rgb * tint.rgb;
}
