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
varying vec3 v_normal_world;
varying vec2 v_uv;
varying vec3 v_world_pos;

void vertex() {
	v_uv = UV;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float h = UV.x;
	vec3 c = mix(low_color, rock_color, smoothstep(0.08, 0.45, h));
	c = mix(c, high_color, smoothstep(0.42, 0.68, h));
	c = mix(c, snow_color, smoothstep(0.955, 0.995, h));
	// 岩层横纹：轻微明暗，不喧宾夺主
	c *= 0.92 + 0.08 * sin(h * 90.0 + UV.y * 18.0);
	v_color = c;
}

void fragment() {
	vec3 n = normalize(v_normal_world);
	// 用真实 DirectionalLight3D 照明；这里只按坡度把陡壁推向岩色。
	float slope = 1.0 - clamp(n.y, 0.0, 1.0);
	vec3 c = mix(v_color, rock_color, smoothstep(0.42, 0.85, slope) * 0.7);
	// 谷底细碎纹理：用世界坐标做很轻的明暗，不让它是一整块纯色平面
	float floor_mask = smoothstep(0.7, 0.98, n.y);
	float grain = 0.5 + 0.5 * sin(v_world_pos.x * 0.11 + v_world_pos.z * 0.07);
	c = mix(c, c * (0.7 + 0.3 * grain), floor_mask);
	float haze = smoothstep(haze_start, haze_end, -v_world_pos.z);
	vec3 final_color = mix(c, haze_color, haze * 0.3);
	// 天空漫射光：越高越亮，低处压暗，形成“光从谷顶下来”的层次。
	float sky_lift = smoothstep(0.0, 520.0, v_world_pos.y);
	ALBEDO = final_color * 2.6;
	EMISSION = final_color * (0.42 + 1.1 * sky_lift) + haze_color * haze * 0.18;
	ROUGHNESS = 0.9;
	SPECULAR = 0.08;
}
