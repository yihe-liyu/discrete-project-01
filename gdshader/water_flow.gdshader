// 记忆值水面背景，改自 Medieval Water（中世纪水）
// 作者：GuoXiaoYao
// 来源：https://godotshaders.com/shader/medieval-water%e4%b8%ad%e4%b8%96%e7%ba%aa%e6%b0%b4/
// 许可证：CC0 1.0
// 本项目修改：接入 memory 参数、配色与 UI 矩形适配。
shader_type canvas_item;

uniform float alpha_mult : hint_range(0, 1) = 1.0;
uniform vec4 border_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float border_width : hint_range(1.0, 10.0) = 2.0;
uniform vec2 rect_size = vec2(384.0, 256.0);

uniform float shader_time;  // ⚠ 代码驱动，编辑器中请勿手动改
uniform float memory : hint_range(-100.0, 200.0) = 50.0;
uniform float wave_angle : hint_range(0.0, 6.2832) = 0.0;

// ── 水体颜色 ── (由 wave 驱动，无需手动调)
// ── 波浪 ──
uniform float wave_scale : hint_range(1.0, 20.0) = 3.0;

// ── 泡沫 ──
uniform float foam_amount : hint_range(0.0, 1.0) = 0.15;
uniform vec3 foam_color : source_color = vec3(0.70, 0.80, 0.88);
uniform float foam_speed : hint_range(0.0, 5.0) = 1.5;
uniform float foam_detail : hint_range(10.0, 200.0) = 100.0;

// ── 噪声 ──
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
	           mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}

float fbm(vec2 uv) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 4; i++) {
		val += amp * noise(uv * freq);
		freq *= 2.1;
		amp *= 0.55;
	}
	return val;
}

void fragment() {
	// ── 边框 ──
	float dl = UV.x * rect_size.x, dr = (1.0 - UV.x) * rect_size.x;
	float dt = UV.y * rect_size.y, db = (1.0 - UV.y) * rect_size.y;
	if (min(min(dl, dr), min(dt, db)) <= border_width) {
		COLOR = vec4(border_color.rgb, border_color.a * alpha_mult);
	} else {

	// ── memory 驱动项 ──
	// -100=纯黑  0=灰白(结构可见)  100=全彩  200=纯白
	float mem_bright = smoothstep(-100.0, 100.0, memory);
	float mem_sat    = smoothstep(0.0, 100.0, memory);

	float t = shader_time;  // 已含速度，永不倒退
	float ms = 1.0;           // 频率固定，速度由 shader_time 管

	// ── 旋转 ──
	float a = wave_angle;
	vec2 centered = UV - 0.5;
	vec2 ruv = vec2(centered.x*cos(a) - centered.y*sin(a),
	                centered.x*sin(a) + centered.y*cos(a)) + 0.5;
	vec2 uv = ruv * wave_scale;

	// ── FBM 波浪 ──
	float s = 1.0 + mem_bright * 0.6;
	float wave1 = fbm(uv * 4.0 + vec2(t*ms*0.3, t*ms*0.25)) * s;
	float wave2 = fbm(uv * 5.5 + vec2(t*ms*0.2, t*ms*0.35)) * s * 0.7;
	float wave = (wave1 + wave2) - 0.85; // → -1~1 范围

	float normalized = clamp(wave * 0.5 + 0.5, 0.0, 1.0);

	// 削尖波峰
	float crest = normalized;
	if (normalized > 0.5) {
		crest = 0.5 + pow((normalized - 0.5) * 2.0, 3.0) * 0.5;
	} else {
		crest = pow(normalized * 2.0, 0.7) * 0.5;
	}

	// ── 颜色：波值驱动 5 段渐变 ──
	float hue = fract(wave1*0.7 + wave2*0.5 + t*ms*0.03);
	vec3 col;
	if (hue < 0.2)      col = mix(vec3(0.20,0.30,1.00), vec3(0.10,0.60,0.90), hue/0.2);
	else if (hue < 0.4) col = mix(vec3(0.10,0.60,0.90), vec3(0.15,0.75,0.70), (hue-0.2)/0.2);
	else if (hue < 0.6) col = mix(vec3(0.15,0.75,0.70), vec3(0.60,0.65,0.25), (hue-0.4)/0.2);
	else if (hue < 0.8) col = mix(vec3(0.60,0.65,0.25), vec3(0.85,0.40,0.30), (hue-0.6)/0.2);
	else                 col = mix(vec3(0.85,0.40,0.30), vec3(0.70,0.20,0.55), (hue-0.8)/0.2);
	
	// 波谷暗、波峰亮
	float depth_shade = mix(0.5, 1.2, crest);
	col *= depth_shade;

	// 泡沫：波峰 + 噪声纹理
	float foamy = fbm(uv * foam_detail / 30.0 + t * ms * foam_speed * 0.4);
	float foam_anim = smoothstep(0.4, 0.8, foamy);
	float foam_mask = smoothstep(0.7, 0.92, crest) * foam_anim * foam_amount;
	col = mix(col, foam_color, foam_mask);

	// 高光
	float spec = smoothstep(0.55, 0.78, crest) * (1.0 - foam_mask);
	col += spec * 0.07 * vec3(0.3, 0.5, 0.72);

	// ── 灰度过渡 ──
	vec3 gray_col = mix(vec3(0.05), vec3(0.4), crest);
	col = mix(gray_col, col, mem_sat);

	// ── 亮度 + 纯白 → 纯黑过渡 ──
	col = max(col, 0.0);
	vec3 white = vec3(1.0);
	vec3 black = vec3(0.0);
	// 0~200: 渐入纯白; -100~0: 渐入纯黑
	float toward_white = smoothstep(100.0, 200.0, memory);
	float toward_black = 1.0 - smoothstep(-100.0, 0.0, memory);
	col = mix(col, white, toward_white);
	col = mix(col, black, toward_black);

	COLOR = vec4(col, 0.92 * alpha_mult);
	}
}
