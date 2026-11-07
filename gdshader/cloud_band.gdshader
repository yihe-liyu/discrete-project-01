shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D noise_tex;
uniform vec4 cloud_color : source_color = vec4(0.82, 0.88, 0.92, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.55;
uniform float scale = 1.6;
uniform float speed = 0.008;

void fragment() {
	vec2 uv = UV * scale + vec2(TIME * speed, TIME * speed * 0.35);
	float n = texture(noise_tex, uv).r;
	float mask = smoothstep(0.42, 0.78, n);
	// 四边形边缘淡出，避免云带露出矩形边界
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.12, 1.0 - UV.x)
		* smoothstep(0.0, 0.16, UV.y) * smoothstep(0.0, 0.16, 1.0 - UV.y);
	ALBEDO = cloud_color.rgb;
	ALPHA = mask * opacity * edge;
}
