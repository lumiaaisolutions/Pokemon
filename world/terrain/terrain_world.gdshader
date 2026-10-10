shader_type spatial;
// Suelo HD-2D del mundo completo con texturas de B2W2. Todo se muestrea en
// coordenadas del mundo a la misma densidad de píxeles que los sprites, y las
// fronteras (biomas, caminos, pendientes, orillas) se deciden por píxel con dither
// ordenado, sin degradados borrosos.
render_mode diffuse_lambert, specular_disabled;

// Pradera
uniform sampler2D meadow_grass : source_color, filter_nearest, repeat_enable;
uniform sampler2D meadow_grass_light : source_color, filter_nearest, repeat_enable;
uniform sampler2D meadow_path : source_color, filter_nearest, repeat_enable;
uniform sampler2D meadow_slope : source_color, filter_nearest, repeat_enable;
uniform vec3 meadow_tint = vec3(1.0);
// Bosque
uniform sampler2D forest_grass : source_color, filter_nearest, repeat_enable;
uniform sampler2D forest_grass_light : source_color, filter_nearest, repeat_enable;
uniform sampler2D forest_path : source_color, filter_nearest, repeat_enable;
uniform sampler2D forest_slope : source_color, filter_nearest, repeat_enable;
uniform vec3 forest_tint = vec3(1.0);
// Montaña
uniform sampler2D mountain_grass : source_color, filter_nearest, repeat_enable;
uniform sampler2D mountain_grass_light : source_color, filter_nearest, repeat_enable;
uniform sampler2D mountain_path : source_color, filter_nearest, repeat_enable;
uniform sampler2D mountain_slope : source_color, filter_nearest, repeat_enable;
uniform vec3 mountain_tint = vec3(1.0);
// Costa y pantano
uniform sampler2D beach_sand : source_color, filter_nearest, repeat_enable;
uniform sampler2D swamp_ground : source_color, filter_nearest, repeat_enable;
uniform vec3 swamp_tint = vec3(1.0, 1.0, 1.0);

// Mapas del mundo (1 texel por celda): biome_map RGBA = pradera, bosque, montaña,
// costa; extra_map R = pantano, G = orilla de agua dulce.
// path_map (1 texel por metro) R = caminos trazados que unen los lugares importantes.
uniform sampler2D biome_map : filter_linear, repeat_disable;
uniform sampler2D extra_map : filter_linear, repeat_disable;
uniform sampler2D path_map : filter_linear, repeat_disable;
uniform float world_size = 480.0;
// Ruido en [0,1]: manchas de pasto claro.
uniform sampler2D patch_noise : filter_linear, repeat_enable;

uniform float px_per_meter = 17.5;
uniform float mask_scale = 0.008;
uniform float light_patch_threshold = 0.62;
uniform float slope_threshold = 0.22;
uniform float shade_steps = 4.0;
// Pisos de altura en la montaña: roca desnuda desde rock_height y nieve desde snow_height.
uniform float rock_height = 18.0;
uniform float snow_height = 32.0;
uniform vec3 snow_color = vec3(0.9, 0.94, 1.0);

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

vec3 tiled(sampler2D tex, vec2 meters) {
	vec2 size = vec2(textureSize(tex, 0));
	return texture(tex, meters * px_per_meter / size).rgb;
}

vec3 biome_ground(int biome, vec2 meters, float patch, float path, float slope, float dither) {
	// biome: 0 pradera, 1 bosque, 2 montaña.
	vec3 color;
	bool light = patch + dither * 0.08 > light_patch_threshold;
	bool on_path = path + dither * 0.5 > 0.5;
	bool steep = slope + dither * 0.06 > slope_threshold;
	if (biome == 0) {
		color = steep ? tiled(meadow_slope, meters) : on_path ? tiled(meadow_path, meters) : light ? tiled(meadow_grass_light, meters) : tiled(meadow_grass, meters);
		return color * meadow_tint;
	} else if (biome == 1) {
		color = steep ? tiled(forest_slope, meters) : on_path ? tiled(forest_path, meters) : light ? tiled(forest_grass_light, meters) : tiled(forest_grass, meters);
		return color * forest_tint;
	}
	color = steep ? tiled(mountain_slope, meters) : on_path ? tiled(mountain_path, meters) : light ? tiled(mountain_grass_light, meters) : tiled(mountain_grass, meters);
	return color * mountain_tint;
}

// Pisos de altura (solo en montaña): roca desnuda y nieve, con borde de píxel.
vec3 altitude_floor(vec3 color, vec2 meters, float height, float dither) {
	if (height + dither * 2.5 > snow_height) {
		// Nieve: blanco azulado que conserva el relieve (luminancia) de la roca.
		vec3 rock = tiled(mountain_grass_light, meters);
		float lum = dot(rock, vec3(0.3, 0.59, 0.11));
		return snow_color * (0.82 + 0.25 * lum);
	}
	if (height + dither * 2.5 > rock_height) {
		return tiled(mountain_slope, meters) * mountain_tint;
	}
	return color;
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
	vec2 map_uv = pixel_m / world_size + 0.5;
	vec4 biomes = texture(biome_map, map_uv);
	vec4 extra = texture(extra_map, map_uv);
	float patch = texture(patch_noise, pixel_m * mask_scale).r;
	float path = texture(path_map, map_uv).r;
	float slope = 1.0 - world_normal.y;

	// Bioma dominante con frontera de píxel: el dither desempata cerca del borde.
	vec4 jittered = biomes + vec4(dither, -dither, dither * 0.5, -dither * 0.5) * 0.25;
	int biome = 0;
	float best = jittered.r;
	if (jittered.g > best) { best = jittered.g; biome = 1; }
	if (jittered.b > best) { best = jittered.b; biome = 2; }
	vec3 color = biome_ground(biome, meters, patch, path, slope, dither);
	if (biome == 2 && path + dither * 0.5 <= 0.5) {
		color = altitude_floor(color, meters, world_pos.y, dither);
	}

	if (extra.r + dither * 0.3 > 0.5) {
		color = tiled(swamp_ground, meters) * swamp_tint;
	}
	if (jittered.a > best || extra.g + dither * 0.3 > 0.5) {
		color = tiled(beach_sand, meters);
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
