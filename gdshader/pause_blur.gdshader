shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float blur_strength : hint_range(0, 8) = 3.0;
uniform float darken : hint_range(0, 1) = 0.55;
uniform float amount : hint_range(0, 1) = 1.0;
uniform vec2 rect_min = vec2(0.0);
uniform vec2 rect_max = vec2(1.0);

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE * blur_strength;
	vec4 color = vec4(0.0);
	
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * ps;
			color += texture(SCREEN_TEXTURE, SCREEN_UV + offset);
		}
	}
	color /= 25.0;
	
	// 只在 SubViewport 区域内模糊，区域外正常显示
	float in_rect = step(rect_min.x, SCREEN_UV.x) * step(rect_min.y, SCREEN_UV.y)
	              * step(SCREEN_UV.x, rect_max.x) * step(SCREEN_UV.y, rect_max.y);
	vec4 original = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec4 filtered = vec4(color.rgb * (1.0 - darken), 1.0);
	COLOR = mix(original, filtered, in_rect * amount);
}
