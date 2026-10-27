shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D base_texture : source_color;
uniform vec2 tiling = vec2(6.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec4 modulate : source_color = vec4(1.0);
uniform float glow_strength : hint_range(1.0, 8.0) = 2.5;

void fragment() {
	vec2 uv = UV * tiling + uv_offset;
	vec4 col = texture(base_texture, uv);
	// HDR 超亮 + Environment glow ⇒ 类似激光的泛光；透明边缘保留。
	ALBEDO = col.rgb * modulate.rgb * glow_strength;
	ALPHA = col.a * modulate.a;
}
