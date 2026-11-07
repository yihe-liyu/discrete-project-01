shader_type spatial;
render_mode cull_disabled;

uniform vec3 low_color : source_color = vec3(0.08, 0.16, 0.13);
uniform vec3 rock_color : source_color = vec3(0.28, 0.28, 0.26);
uniform vec3 high_color : source_color = vec3(0.58, 0.6, 0.6);
uniform vec3 snow_color : source_color = vec3(0.92, 0.96, 1.0);

varying vec3 v_color;
varying vec3 v_normal_world;
varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	v_normal_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float h = UV.x;
	vec3 c = mix(low_color, rock_color, smoothstep(0.08, 0.45, h));
	c = mix(c, high_color, smoothstep(0.42, 0.68, h));
	c = mix(c, snow_color, smoothstep(0.62, 0.86, h));
	// 岩层横纹：轻微明暗，不喧宾夺主
	c *= 0.92 + 0.08 * sin(h * 90.0 + UV.y * 18.0);
	v_color = c;
}

void fragment() {
	vec3 n = normalize(v_normal_world);
	vec3 light_dir = normalize(vec3(-0.45, 0.8, 0.35));
	float ndl = max(dot(n, light_dir), 0.0);
	ALBEDO = v_color * (0.32 + 0.82 * ndl);
}
