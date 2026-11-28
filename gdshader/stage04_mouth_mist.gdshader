shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 mist_color : source_color = vec4(0.70, 0.60, 0.64, 0.42);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	// 矩形边的软遮罩：上下左右都渐变到 0，不会出现雾墙硬边。
	float edge_x = smoothstep(0.0, 0.22, UV.x) * (1.0 - smoothstep(0.78, 1.0, UV.x));
	float edge_y = smoothstep(0.0, 0.30, UV.y) * (1.0 - smoothstep(0.68, 1.0, UV.y));
	float n = fbm(UV * vec2(3.2, 2.1) + vec2(TIME * 0.008, TIME * 0.004));
	float mask = edge_x * edge_y * (0.35 + 0.65 * n);
	ALBEDO = mist_color.rgb;
	ALPHA = mist_color.a * mask * opacity;
}
