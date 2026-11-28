shader_type sky;
render_mode use_debanding;

uniform vec3 sky_top : source_color = vec3(0.16, 0.20, 0.38);
uniform vec3 sky_horizon : source_color = vec3(0.98, 0.58, 0.35);
uniform vec3 ridge_near : source_color = vec3(0.18, 0.15, 0.23);
uniform vec3 ridge_far : source_color = vec3(0.38, 0.28, 0.4);
uniform vec3 snow_color : source_color = vec3(0.96, 0.78, 0.68);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.8, 0.66);
// 微弱泛彩：只在地平线上方形成极低饱和的色带
uniform vec3 tint_a : source_color = vec3(0.94, 0.48, 0.44);
uniform vec3 tint_b : source_color = vec3(0.48, 0.32, 0.62);
uniform vec3 tint_c : source_color = vec3(1.0, 0.72, 0.34);
uniform float iridescence : hint_range(0.0, 1.0) = 0.42;

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(vec2(x, float(i) * 7.13));
		x *= 2.07;
		a *= 0.5;
	}
	return v;
}

float ridge_height(float az, float seed, float scale, float amp) {
	return -0.035 + amp * (0.35 + 0.65 * fbm(az * scale + seed));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float elev = asin(clamp(d.y, -1.0, 1.0));
	float az = atan(d.x, d.z);

	float h_far = ridge_height(az, 11.0, 1.7, 0.105);
	float h_near = ridge_height(az, 31.0, 3.4, 0.075);

	vec3 col = mix(sky_horizon, sky_top, smoothstep(0.0, 0.75, elev));

	// 地平线附近的极淡彩带，慢速漂移；不是极光，只是空气里的一层颜色。
	float band = exp(-pow((elev - 0.16) / 0.30, 2.0));
	float warp = fbm(az * 1.6 + TIME * 0.012 + elev * 1.3);
	float warp2 = fbm(az * 3.1 - TIME * 0.008 + 4.0);
	vec3 iri = mix(tint_a, tint_b, smoothstep(0.25, 0.75, warp));
	iri = mix(iri, tint_c, smoothstep(0.55, 0.95, warp2) * 0.45);
	col = mix(col, iri, band * iridescence * (0.35 + 0.65 * warp));
	// 高一点的地方只留一层极淡的冷紫，保持天空不是纯灰
	float high_band = smoothstep(0.22, 0.58, elev) * (1.0 - smoothstep(0.78, 1.0, elev));
	col = mix(col, mix(tint_b, tint_a, 0.55), high_band * 0.12);

	// 远景山脊；越靠上越接近雪线
	if (elev < h_far) {
		float t = smoothstep(h_far - 0.10, h_far, elev);
		col = mix(ridge_far, snow_color, smoothstep(0.55, 0.95, t));
	}
	// 近一点的山脊压暗，形成空气透视层次
	if (elev < h_near) {
		col = mix(ridge_near, ridge_far, smoothstep(0.0, 0.6, elev + 0.10));
	}

	// 高空薄云
	float cloud = smoothstep(0.58, 0.72,
		fbm(az * 4.2 + 3.0) * 0.5 + fbm(az * 9.1 + 11.0) * 0.25 + elev * 0.25);
	col = mix(col, cloud_color, cloud * smoothstep(0.05, 0.35, elev) * 0.28);

	COLOR = col;
}
