shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

varying vec3 v_color;

void vertex() {
	v_color = COLOR.rgb;
}

void fragment() {
	ALBEDO = v_color;
	EMISSION = v_color * 0.10;
	ROUGHNESS = 0.95;
}
