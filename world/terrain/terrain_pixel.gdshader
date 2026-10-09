shader_type spatial;
// Suelo HD-2D con texturas de B2W2. Todo se muestrea en coordenadas del mundo a la
// misma densidad de píxeles que los sprites (px_per_meter), y las transiciones entre
// pasto, camino y tierra se cuantizan a la rejilla de píxeles con dither ordenado,
// para que no aparezcan degradados borrosos.
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D grass_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D grass_light_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D path_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_nearest, repeat_enable;
// Ruidos en [0,1]: manchas de pasto claro y trazado de caminos (la línea media del ruido).
uniform sampler2D patch_noise : filter_linear, repeat_enable;
uniform sampler2D path_noise : filter_linear, repeat_enable;

uniform float px_per_meter = 17.5;
uniform float mask_scale = 0.008;
uniform float path_width = 0.035;
uniform float light_patch_threshold = 0.62;
uniform float slope_threshold = 0.22;
uniform float shade_steps = 4.0;

varying vec3 world_pos;
varying vec3 world_normal;

const float BAYER4[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float bayer(vec2 pixel) {
	ivec2 p = ivec2(mod(pixel, 4.0));
	return (BAYER4[p.y * 4 + p.x] + 0.5) / 16.0;
}

vec3 sample_tiled(sampler2D tex, vec2 meters) {
	vec2 size = vec2(textureSize(tex, 0));
	return texture(tex, meters * px_per_meter / size).rgb;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 meters = world_pos.xz;
	// Centro del píxel de mundo: las máscaras cambian por píxel, no por fragmento.
	vec2 pixel = floor(meters * px_per_meter);
	vec2 pixel_m = (pixel + 0.5) / px_per_meter;
	float dither = bayer(pixel) - 0.5;
	float patch = texture(patch_noise, pixel_m * mask_scale).r;
	float path_value = texture(path_noise, pixel_m * mask_scale).r;

	vec3 color = sample_tiled(grass_tex, meters);
	if (patch + dither * 0.08 > light_patch_threshold) {
		color = sample_tiled(grass_light_tex, meters);
	}
	float path = 1.0 - smoothstep(0.0, path_width, abs(path_value - 0.5));
	if (path + dither * 0.5 > 0.5) {
		color = sample_tiled(path_tex, meters);
	}
	float slope = 1.0 - world_normal.y;
	if (slope + dither * 0.06 > slope_threshold) {
		color = sample_tiled(dirt_tex, meters);
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
}

void light() {
	// Luz en escalones (cel) para que el sombreado del terreno no rompa el pixel art.
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float stepped = floor(n_dot_l * shade_steps + 0.5) / shade_steps;
	DIFFUSE_LIGHT += stepped * ATTENUATION * LIGHT_COLOR / PI;
}
