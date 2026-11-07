shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 valley_color : source_color = vec4(0.1, 0.18, 0.14, 1.0);

void fragment() {
	ALBEDO = valley_color.rgb;
}
