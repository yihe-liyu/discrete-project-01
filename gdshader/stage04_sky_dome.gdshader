shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 sky_top : source_color = vec3(0.34, 0.46, 0.64);
uniform vec3 sky_horizon : source_color = vec3(0.76, 0.84, 0.9);
uniform vec3 tint_a : source_color = vec3(0.48, 0.74, 0.8);
uniform vec3 tint_b : source_color = vec3(0.7, 0.58, 0.84);
uniform vec3 tint_c : source_color = vec3(0.9, 0.78, 0.56);
uniform float iridescence : hint_range(0.0, 1.0) = 0.22;

varying vec3 v_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(float x) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(vec2(x, float(i) * 7.13));
		x *= 2.07;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 相机在球心附近，可见天空的 UV.y 约 0.52–0.72；彩带就压在这个区间。
	float h = clamp(UV.y, 0.0, 1.0);
	float az = atan(v_world.x, v_world.z);
	vec3 col = mix(sky_horizon, sky_top, smoothstep(0.20, 0.56, h));

	float band = smoothstep(0.24, 0.30, h) * (1.0 - smoothstep(0.46, 0.62, h));
	float drift = 0.5 + 0.5 * sin(az * 1.7 + TIME * 0.025 + h * 5.0);
	float warp = fbm(az * 1.3 + TIME * 0.012 + 3.0);
	vec3 iri = mix(tint_a, tint_b, clamp(drift * 0.55 + warp * 0.45, 0.0, 1.0));
	iri = mix(iri, tint_c, smoothstep(0.62, 0.8, h) * 0.25);
	col = mix(col, iri, band * iridescence);

	// 顶部只留极淡冷色，避免整片天空发灰。
	col = mix(col, mix(tint_b, tint_a, 0.5), smoothstep(0.40, 0.58, h) * 0.08);

	ALBEDO = col;
}
