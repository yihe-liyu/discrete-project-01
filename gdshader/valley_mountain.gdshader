shader_type spatial;
render_mode cull_disabled;

uniform vec3 low_color : source_color = vec3(0.08, 0.17, 0.13);
uniform vec3 rock_color : source_color = vec3(0.18, 0.3, 0.25);
uniform vec3 high_color : source_color = vec3(0.3, 0.42, 0.4);
uniform vec3 snow_color : source_color = vec3(0.92, 0.96, 1.0);
uniform vec3 haze_color : source_color = vec3(0.62, 0.7, 0.78);
uniform float haze_start = 650.0;
uniform float haze_end = 3000.0;
uniform vec3 sun_color : source_color = vec3(1.15, 1.02, 0.82);
uniform vec3 shade_color : source_color = vec3(0.28, 0.34, 0.46);
// 基础自发光：山谷背面/补光不足时也保留轮廓，不靠环境光硬撑。
uniform float ambient_lift : hint_range(0.0, 0.5) = 0.07;

varying vec3 v_color;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 3; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
varying vec3 v_normal_world;
varying vec2 v_uv;
varying vec3 v_world_pos;

void vertex() {
	v_uv = UV;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// 山壁颜色完全交给 fragment 的屏幕纵向渐变，vertex 只传稳定基色。
	v_color = mix(low_color, rock_color, 0.55);
}

void fragment() {
	float haze = smoothstep(haze_start, haze_end, -v_world_pos.z);
	// 天光按屏幕纵向渐变：不跟 6 列山壁三角面的插值走，避免长条亮暗带。
	float sky_lift = 1.0 - smoothstep(0.06, 0.94, SCREEN_UV.y);
	vec3 base = mix(low_color, rock_color, 0.55);
	// 大尺度岩体色差：用世界坐标的低频噪声，不跟三角面插值走。
	float rock_noise = fbm(v_world_pos.xz * 0.018);
	base = mix(base, rock_color, smoothstep(0.35, 0.72, rock_noise) * 0.45);
	// 低频岩层：只做非常缓的横向色差，不形成亮暗条纹。
	float strata = sin(v_world_pos.y * 0.012 + fbm(v_world_pos.xz * 0.01) * 3.0);
	base *= 0.94 + 0.06 * strata;
	vec3 final_color = mix(base, high_color, sky_lift * 0.45);
	final_color = mix(final_color, haze_color, haze * 0.3);
	ALBEDO = final_color * 2.4;
	EMISSION = final_color * (0.30 + 0.85 * sky_lift) + haze_color * haze * 0.18;
	ROUGHNESS = 0.9;
	SPECULAR = 0.08;
}
