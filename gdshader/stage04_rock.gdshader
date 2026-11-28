shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://gdshader/stage04_atmosphere.gdshaderinc"

uniform float brightness = 1.0;


varying vec3 v_color;
varying vec3 v_world;

void vertex() {
	v_color = COLOR.rgb;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 固定方向“天空光”，不依赖场景方向光，也能让每个切面有明暗差。
	vec3 n = normalize(NORMAL);
	vec3 light_dir = normalize(vec3(0.35, 0.85, 0.25));
	float facet = 0.42 + 0.58 * max(dot(n, light_dir), 0.0);
	vec3 col = v_color * (1.15 + 0.45 * facet);
	float atmo = atmosphere_factor(length(VERTEX));
	ALBEDO = mix(col * 1.35 * brightness, stage04_atmosphere_color, atmo);
	// 少量自发光，让石头在雾里也有一点可读的亮部。
	EMISSION = mix(col * (0.12 + 0.10 * facet) * brightness,
		stage04_atmosphere_color * 0.04, atmo);
	ROUGHNESS = 0.95;
}
