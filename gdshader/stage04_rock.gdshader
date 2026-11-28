shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://gdshader/stage04_fog.gdshaderinc"

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
	vec3 col = v_color * facet;
	// 与地面/山壁同一条距离雾，远处石头必须一起淡进雾色。
	float haze = stage04_haze(v_world.z);
	col = mix(col, haze_color, haze * 0.86);
	ALBEDO = col;
	EMISSION = col * (0.04 + 0.10 * facet);
	ROUGHNESS = 0.95;
}
