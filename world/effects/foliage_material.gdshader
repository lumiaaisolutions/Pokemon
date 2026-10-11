shader_type spatial;
// Material del follaje 3D (árboles, arbustos, flores, hierba, cactus...): con luz normal
// (sigue el sol y las luces de noche, a diferencia del sprite_billboard que es unshaded),
// recorte de alfa nítido y el mismo tinte de estación que antes tenían los sprites
// (ver world/effects/sprite_billboard.gdshader y world/weather/weather.gd). Lo usan las
// mallas de PropModels3D.cross_mesh (world/region/prop_models.gd).
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
global uniform vec4 season_tint;
// 1 = follaje que cambia de color con la estación (no las rocas ni troncos).
uniform float seasonal = 0.0;
// 1 = brilla con luz propia (hongos luminosos, cristales): no se oscurece de noche.
uniform float glow = 0.0;

void fragment() {
	vec4 texel = texture(albedo_tex, UV);
	vec3 season = mix(vec3(1.0), season_tint.rgb, seasonal);
	vec3 color = texel.rgb * tint.rgb * season;
	ALBEDO = color;
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (glow > 0.5) {
		EMISSION = color * 0.7;
	}
}
