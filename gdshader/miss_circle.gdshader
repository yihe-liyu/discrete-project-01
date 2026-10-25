shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 view_size = vec2(1280.0, 960.0);

uniform vec2 c0_pos = vec2(-1.0);
uniform float c0_radpx = 0.0;
uniform float c0_alpha = 0.0;
uniform vec2 c1_pos = vec2(-1.0);
uniform float c1_radpx = 0.0;
uniform float c1_alpha = 0.0;
uniform vec2 c2_pos = vec2(-1.0);
uniform float c2_radpx = 0.0;
uniform float c2_alpha = 0.0;
uniform vec2 c3_pos = vec2(-1.0);
uniform float c3_radpx = 0.0;
uniform float c3_alpha = 0.0;
uniform vec2 c4_pos = vec2(-1.0);
uniform float c4_radpx = 0.0;
uniform float c4_alpha = 0.0;
uniform vec2 c5_pos = vec2(-1.0);
uniform float c5_radpx = 0.0;
uniform float c5_alpha = 0.0;
uniform vec2 c6_pos = vec2(-1.0);
uniform float c6_radpx = 0.0;
uniform float c6_alpha = 0.0;
uniform vec2 c7_pos = vec2(-1.0);
uniform float c7_radpx = 0.0;
uniform float c7_alpha = 0.0;

uniform float edge_soft = 0.03;

#define ACCUM(i, pos, radpx, alp) \
	if (pos.x >= -0.5) { \
		float dx = (UV.x - pos.x) * view_size.x; \
		float dy = (UV.y - pos.y) * view_size.y; \
		float dist = sqrt(dx * dx + dy * dy); \
		float ci = 1.0 - smoothstep(radpx - edge_soft * radpx, radpx + edge_soft * radpx, dist); \
		raw_mask += ci * alp; \
	}

void fragment() {
	vec4 bg = texture(screen_tex, SCREEN_UV);
	float raw_mask = 0.0;
	
	ACCUM(0, c0_pos, c0_radpx, c0_alpha)
	ACCUM(1, c1_pos, c1_radpx, c1_alpha)
	ACCUM(2, c2_pos, c2_radpx, c2_alpha)
	ACCUM(3, c3_pos, c3_radpx, c3_alpha)
	ACCUM(4, c4_pos, c4_radpx, c4_alpha)
	ACCUM(5, c5_pos, c5_radpx, c5_alpha)
	ACCUM(6, c6_pos, c6_radpx, c6_alpha)
	ACCUM(7, c7_pos, c7_radpx, c7_alpha)
	
	// 反转区域（三角波：1圈=反转，2圈=复原，3圈=反转...）
	float inv_mask = 1.0 - abs(mod(raw_mask, 2.0) - 1.0);
	vec4 inverted = vec4(1.0 - bg.rgb, 1.0);
	vec4 result = mix(bg, inverted, inv_mask);
	
	COLOR = result;
}
