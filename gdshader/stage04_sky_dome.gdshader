shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 sky_top : source_color = vec3(0.16, 0.20, 0.38);
uniform vec3 sky_horizon : source_color = vec3(0.98, 0.58, 0.35);
uniform vec3 tint_a : source_color = vec3(0.94, 0.48, 0.44);
uniform vec3 tint_b : source_color = vec3(0.48, 0.32, 0.62);
uniform vec3 tint_c : source_color = vec3(1.0, 0.72, 0.34);
uniform float iridescence : hint_range(0.0, 1.0) = 0.42;
uniform vec3 sun_direction = vec3(0.0, 0.12, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.52, 0.20);
uniform float sun_glow : hint_range(0.0, 1.0) = 0.55;
// 黄昏颜色分界：屏幕纵向 0=地平线，1=画面顶部。
uniform float dusk_gradient_start : hint_range(0.0, 1.0) = 0.12;
uniform float dusk_gradient_end : hint_range(0.0, 1.0) = 0.82;
// 暖色彩带中心 / 宽度；想让橙色带更高就调大 center。
uniform float dusk_band_center : hint_range(0.0, 1.0) = 0.30;
uniform float dusk_band_width : hint_range(0.01, 0.6) = 0.24;

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
	// 天空只做屏幕纵向渐变：顶部靛蓝、靠近地平线橙红，保证黄昏分层可见。
	float h = clamp(1.0 - SCREEN_UV.y, 0.0, 1.0);
	vec3 col = mix(sky_horizon, sky_top, smoothstep(dusk_gradient_start, dusk_gradient_end, h));

	// 地平线附近的暖色彩带 + 高空冷紫。
	float band = exp(-pow((h - dusk_band_center) / dusk_band_width, 2.0));
	float drift = 0.5 + 0.5 * sin(h * 9.0 + TIME * 0.020);
	vec3 iri = mix(tint_a, tint_b, drift);
	iri = mix(iri, tint_c, smoothstep(0.18, 0.45, h) * 0.45);
	col = mix(col, iri, band * iridescence);
	col = mix(col, tint_b, smoothstep(0.55, 0.9, h) * 0.10);

	ALBEDO = col;
}
