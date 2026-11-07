shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 bottom_color : source_color = vec3(0.42, 0.52, 0.62);
uniform vec3 top_color : source_color = vec3(0.72, 0.8, 0.86);

varying float v_t;

void vertex() {
	v_t = UV.y;
}

void fragment() {
	ALBEDO = mix(bottom_color, top_color, v_t);
}
