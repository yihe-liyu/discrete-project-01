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
// 记忆值水面的彩色层：低频有机噪声，五段色相。
uniform float color_layer_strength : hint_range(0.0, 0.6) = 0.48;
uniform float color_layer_scale : hint_range(0.5, 8.0) = 3.2;

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

float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

vec3 memory_palette(float hue) {
	// 闭合调色板：末尾回到蓝色，fract 回绕时不会出现品红→蓝硬切。
	if (hue < 0.2)      return mix(vec3(0.20, 0.30, 1.00), vec3(0.10, 0.60, 0.90), hue / 0.2);
	else if (hue < 0.4) return mix(vec3(0.10, 0.60, 0.90), vec3(0.15, 0.75, 0.70), (hue - 0.2) / 0.2);
	else if (hue < 0.6) return mix(vec3(0.15, 0.75, 0.70), vec3(0.60, 0.65, 0.25), (hue - 0.4) / 0.2);
	else if (hue < 0.8) return mix(vec3(0.60, 0.65, 0.25), vec3(0.85, 0.40, 0.30), (hue - 0.6) / 0.2);
	else if (hue < 0.92) return mix(vec3(0.85, 0.40, 0.30), vec3(0.70, 0.20, 0.55), (hue - 0.8) / 0.12);
	else                return mix(vec3(0.70, 0.20, 0.55), vec3(0.20, 0.30, 1.00), (hue - 0.92) / 0.08);
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

	// 一层类似记忆值水面的彩色流动带：低频噪声，不画成硬色块。
	vec2 layer_uv = SCREEN_UV * vec2(1.6, 1.0) * color_layer_scale;
	float n1 = fbm2(layer_uv + vec2(TIME * 0.012, TIME * 0.006));
	float n2 = fbm2(layer_uv * 1.9 + vec2(-TIME * 0.008, TIME * 0.010) + 11.0);
	float hue = fract(n1 * 1.25 + n2 * 0.75 + TIME * 0.012);
	float mask = smoothstep(0.32, 0.82, n1 * 0.65 + n2 * 0.35);
	mask *= smoothstep(0.08, 0.30, h) * (1.0 - smoothstep(0.72, 0.96, h));
	col = mix(col, memory_palette(hue), mask * color_layer_strength);
	// 轻微静态抖动，避免暗部渐变色带。
	col += (hash(FRAGCOORD.xy + 17.0) - 0.5) / 255.0;

	ALBEDO = col;
}
