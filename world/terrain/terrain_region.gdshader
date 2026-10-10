shader_type spatial;
// Suelo HD-2D de la región grande (por zonas) con texturas de B2W2. Cada vértice trae:
// CUSTOM0 = pesos de familia (pasto, bosque, roca, arena), CUSTOM1 = (pantano, camino,
// nieve, pavimento) y COLOR = tinte del bioma. Todo se muestrea en coordenadas del
// mundo a la densidad de píxeles de los sprites, y las fronteras se deciden por píxel
// con dither ordenado.
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D meadow_grass : source_color, filter_nearest, repeat_enable;
uniform sampler2D meadow_grass_light : source_color, filter_nearest, repeat_enable;
uniform sampler2D meadow_path : source_color, filter_nearest, repeat_enable;
uniform sampler2D meadow_slope : source_color, filter_nearest, repeat_enable;
uniform sampler2D forest_grass : source_color, filter_nearest, repeat_enable;
uniform sampler2D forest_grass_light : source_color, filter_nearest, repeat_enable;
uniform sampler2D forest_slope : source_color, filter_nearest, repeat_enable;
uniform sampler2D mountain_grass : source_color, filter_nearest, repeat_enable;
uniform sampler2D mountain_grass_light : source_color, filter_nearest, repeat_enable;
uniform sampler2D mountain_slope : source_color, filter_nearest, repeat_enable;
uniform sampler2D beach_sand : source_color, filter_nearest, repeat_enable;
uniform sampler2D swamp_ground : source_color, filter_nearest, repeat_enable;
uniform vec3 swamp_tint = vec3(0.55, 0.62, 0.42);
// Pavimento de las ciudades (piedra gris).
uniform vec3 paving_color = vec3(0.72, 0.7, 0.68);
uniform sampler2D patch_noise : filter_linear, repeat_enable;
uniform float px_per_meter = 17.5;
uniform float mask_scale = 0.008;
uniform float light_patch_threshold = 0.62;
uniform float slope_threshold = 0.22;
uniform float shade_steps = 4.0;
uniform float rock_height = 45.0;
uniform float snow_height = 62.0;
uniform vec3 snow_color = vec3(0.9, 0.94, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 families;
varying vec4 extras;
varying vec3 tint;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	families = CUSTOM0;
	extras = CUSTOM1;
	tint = COLOR.rgb;
}

void fragment() {
	vec2 meters = world_pos.xz;
	vec2 pixel = floor(meters * px_per_meter);
	vec2 pixel_m = (pixel + 0.5) / px_per_meter;
	float dither = bayer(pixel) - 0.5;
	float patch = texture(patch_noise, pixel_m * mask_scale).r;
	float slope = 1.0 - world_normal.y;
	bool light = patch + dither * 0.08 > light_patch_threshold;
	bool steep = slope + dither * 0.06 > slope_threshold;

	vec4 f = families + vec4(dither, -dither, dither * 0.5, -dither * 0.5) * 0.25;
	int family = 0;
	float best = f.r;
	if (f.g > best) { best = f.g; family = 1; }
	if (f.b > best) { best = f.b; family = 2; }
	if (f.a > best) { best = f.a; family = 3; }

	vec3 color;
	if (family == 0) {
		color = steep ? tiled(meadow_slope, meters) : light ? tiled(meadow_grass_light, meters) : tiled(meadow_grass, meters);
	} else if (family == 1) {
		color = steep ? tiled(forest_slope, meters) : light ? tiled(forest_grass_light, meters) : tiled(forest_grass, meters);
	} else if (family == 2) {
		color = steep ? tiled(mountain_slope, meters) : light ? tiled(mountain_grass_light, meters) : tiled(mountain_grass, meters);
		if (world_pos.y + dither * 2.5 > rock_height) {
			color = tiled(mountain_slope, meters);
		}
	} else {
		color = tiled(beach_sand, meters);
	}
	color *= tint;
	// Nieve: por altura (salvo en biomas cálidos, extras.b < 0) o por el bioma (tundra).
	if ((world_pos.y + dither * 2.5 > snow_height && extras.b > -0.5) || extras.b + dither * 0.3 > 0.5) {
		vec3 rock = tiled(mountain_grass_light, meters);
		float lum = dot(rock, vec3(0.3, 0.59, 0.11));
		color = snow_color * (0.82 + 0.25 * lum);
	}
	if (extras.r + dither * 0.3 > 0.5) {
		color = tiled(swamp_ground, meters) * swamp_tint * tint;
	}
	// Caminos de tierra y pavimento de ciudad.
	if (extras.g + dither * 0.5 > 0.5) {
		color = extras.a > 0.5 ? paving_color * (0.85 + 0.3 * patch) : tiled(meadow_path, meters);
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
}

void light() {
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float stepped = floor(n_dot_l * shade_steps + 0.5) / shade_steps;
	DIFFUSE_LIGHT += stepped * ATTENUATION * LIGHT_COLOR / PI;
}
