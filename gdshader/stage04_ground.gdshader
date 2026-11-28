shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 deep_color : source_color = vec3(0.13, 0.21, 0.23);
uniform vec3 stone_color : source_color = vec3(0.3, 0.42, 0.43);
uniform vec3 sky_color : source_color = vec3(0.66, 0.76, 0.86);
uniform vec3 haze_color : source_color = vec3(0.58, 0.68, 0.79);
uniform float haze_start = 700.0;
uniform float haze_end = 3200.0;

varying vec3 v_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	float broad = fbm(p * 0.018);
	float detail = fbm(p * 0.11 + 7.0);
	float stone = smoothstep(0.2, 0.8, broad * 0.7 + detail * 0.3);
	vec3 col = mix(deep_color, stone_color, stone);

	// 远处融进雾色
	float haze = smoothstep(haze_start, haze_end, -v_world.z);
	col = mix(col, haze_color, haze * 0.72);

	// 掠射角把天空颜色带进来，像潮湿石面/薄雾的反光
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	float grazing = pow(1.0 - clamp(abs(view_dir.y), 0.0, 1.0), 2.0);
	col = mix(col, sky_color, grazing * 0.28);

	// 少量矿物斑点，近处可见、远处被雾吃掉
	float fleck = step(0.88, noise(p * 0.65 + 11.0));
	col += vec3(0.035, 0.05, 0.06) * fleck * (1.0 - haze);

	ALBEDO = col;
	EMISSION = col * 0.12;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
