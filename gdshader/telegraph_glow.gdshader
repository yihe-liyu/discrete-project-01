shader_type canvas_item;

// 路径段 quad：UV.y 横跨线宽；中心画亮核，两侧做外发光。
uniform vec4 line_color : source_color = vec4(1.0, 0.82, 0.35, 0.85);
uniform float core_ratio : hint_range(0.0, 1.0) = 0.4;
uniform float glow_power : hint_range(1.0, 8.0) = 2.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float d = abs(UV.y - 0.5) * 2.0;
	float core = smoothstep(core_ratio, 0.0, d);
	float glow = pow(max(1.0 - d, 0.0), glow_power) * glow_strength;
	float mask = clamp(core + glow, 0.0, 1.0);
	COLOR = vec4(line_color.rgb, line_color.a * mask);
}
