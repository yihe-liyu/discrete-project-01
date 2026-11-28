shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec3 fog_color : source_color = vec3(0.58, 0.68, 0.78);
uniform float density : hint_range(0.0, 1.0) = 0.55;
uniform float y_softness : hint_range(0.01, 1.0) = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// QuadMesh: UV.y 0 底、1 顶；底部浓、顶部渐隐，像谷口的水汽/雾墙。
	float bottom_fade = smoothstep(0.0, y_softness, UV.y);
	float top_fade = 1.0 - smoothstep(0.55, 1.0, UV.y);
	float body = bottom_fade * top_fade;
	float grain = 0.9 + 0.1 * hash(vec2(floor(UV.x * 18.0), floor(UV.y * 9.0)));
	ALBEDO = fog_color;
	ALPHA = density * body * grain;
}
