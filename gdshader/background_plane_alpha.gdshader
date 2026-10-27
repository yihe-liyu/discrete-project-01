shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D base_texture : source_color;
uniform vec2 tiling = vec2(6.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec4 modulate : source_color = vec4(1.0);

void fragment() {
	vec2 uv = UV * tiling + uv_offset;
	vec4 col = texture(base_texture, uv);
	ALBEDO = col.rgb * modulate.rgb;
	ALPHA = col.a * modulate.a;
}
