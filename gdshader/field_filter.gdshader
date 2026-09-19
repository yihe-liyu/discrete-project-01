shader_type canvas_item;
render_mode blend_mix, unshaded;

// 场地滤镜圆：以 center_uv（归一化）为心、radius（px）内铺 filter_color，softness 羽化。
// 只作用在挂它的 ColorRect（= 游戏框）内；alpha 是全局不透明度（渐显/渐隐）。
uniform vec2 rect_size = vec2(768.0, 896.0);
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform float radius = 0.0;
uniform float softness = 80.0;
uniform vec4 filter_color : source_color = vec4(1.0, 1.0, 1.0, 0.35);
uniform float alpha = 0.0;

void fragment() {
	vec2 px = UV * rect_size;
	float d = distance(px, center_uv * rect_size);
	float mask = 1.0 - smoothstep(radius - softness, radius + softness, d);
	COLOR = vec4(filter_color.rgb, filter_color.a * alpha * mask);
}
