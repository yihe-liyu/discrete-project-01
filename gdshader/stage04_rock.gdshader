shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

varying vec3 v_color;

void vertex() {
	v_color = COLOR.rgb;
}

void fragment() {
	// 固定方向“天空光”，不依赖场景方向光，也能让每个切面有明暗差。
	vec3 n = normalize(NORMAL);
	vec3 light_dir = normalize(vec3(0.35, 0.85, 0.25));
	float facet = 0.42 + 0.58 * max(dot(n, light_dir), 0.0);
	ALBEDO = v_color * facet;
	EMISSION = v_color * (0.04 + 0.10 * facet);
	ROUGHNESS = 0.95;
}
