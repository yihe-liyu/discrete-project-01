shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 near_color : source_color = vec3(0.035, 0.12, 0.06);
uniform vec3 far_color : source_color = vec3(0.08, 0.22, 0.11);
uniform vec3 haze_color : source_color = vec3(0.62, 0.7, 0.78);
uniform float haze_start = 900.0;
uniform float haze_end = 3500.0;

varying float v_h;
varying vec3 v_world;

void vertex() {
	v_h = UV.y;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = mix(near_color, far_color, v_h);
	float haze = smoothstep(haze_start, haze_end, -v_world.z);
	ALBEDO = mix(c, haze_color, haze * 0.12);
}
