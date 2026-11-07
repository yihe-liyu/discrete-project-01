shader_type spatial;
render_mode cull_disabled;

uniform vec3 low_color : source_color = vec3(0.035, 0.14, 0.06);
uniform vec3 rock_color : source_color = vec3(0.11, 0.26, 0.14);
uniform vec3 high_color : source_color = vec3(0.24, 0.36, 0.27);
uniform vec3 snow_color : source_color = vec3(0.92, 0.96, 1.0);
uniform vec3 haze_color : source_color = vec3(0.62, 0.7, 0.78);
uniform float haze_start = 900.0;
uniform float haze_end = 3500.0;
uniform vec3 sun_color : source_color = vec3(1.15, 1.02, 0.82);
uniform vec3 shade_color : source_color = vec3(0.28, 0.34, 0.46);

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
	c = mix(c, snow_color, smoothstep(0.88, 0.98, h));
	// 岩层横纹：轻微明暗，不喧宾夺主
	c *= 0.92 + 0.08 * sin(h * 90.0 + UV.y * 18.0);
	v_color = c;
}

void fragment() {
	vec3 n = normalize(v_normal_world);
	// 明确的侧上光：左侧受暖光，背光面偏冷，拉开山的体积
	vec3 light_dir = normalize(vec3(-0.85, 0.4, 0.25));
	float ndl = clamp(dot(n, light_dir), 0.0, 1.0);
	ndl = smoothstep(0.05, 0.95, ndl);
	vec3 light = mix(shade_color, sun_color, ndl);
	vec3 c = v_color * light;
	// 谷底细碎纹理：用世界坐标做很轻的明暗，不让它是一整块纯色平面
	float floor_mask = smoothstep(0.7, 0.98, n.y);
	float grain = 0.5 + 0.5 * sin(v_world_pos.x * 0.11 + v_world_pos.z * 0.07);
	c = mix(c, c * (0.7 + 0.3 * grain), floor_mask);
	float haze = smoothstep(haze_start, haze_end, -v_world_pos.z);
	ALBEDO = mix(c, haze_color, haze * 0.12);
}
