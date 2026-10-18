shader_type canvas_item;
render_mode blend_mix;

// 全屏蒙眼雾（2D 层）：玩家被蒙眼 → 整个画面蒙一层流动的暗雾
// 太阳屏幕位置处更浓（噪声扰动的不规则浓雾 = 专门遮太阳）
// 分层：双层噪声（大尺度慢漂+小尺度快漂）+ 边缘渐晕 + 呼吸感 + 太阳漏光亮环
// 全部 uniform 由 ScreenFogFX 组件 @export 注入 → 场景里选节点即可调参

uniform sampler2D noise_tex;                                    // 值噪声云斑纹理（512² 生成）
uniform float time = 0.0;                                       // 由 ScreenFogFX 按 delta 推进（不是 shader TIME，切页冻结不跳）
uniform float fog_dark : hint_range(0.0, 1.0) = 0.65;           // 整体蒙眼浓度
uniform vec2 sun_pos = vec2(0.5, 0.18);                         // 太阳屏幕位置（归一化）
uniform float sun_fog_radius : hint_range(0.0, 0.5) = 0.1;      // 太阳处雾团范围
uniform float sun_fog_extra : hint_range(0.0, 2.0) = 1.0;       // 太阳处额外浓度
uniform float flow_speed : hint_range(0.0, 0.5) = 0.03;         // 流动速度
uniform float noise_scale = 1.0;                                // 云斑大小
uniform vec3 fog_color : source_color = vec3(0.02, 0.02, 0.03); // 雾色（暗蓝灰）
uniform float detail_scale = 3.0;                               // 第二层噪声频率倍率
uniform float detail_strength : hint_range(0.0, 1.0) = 0.35;    // 第二层混合权重
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.15;  // 边缘渐晕（四角更暗）
uniform float breath_amplitude : hint_range(0.0, 0.2) = 0.03;   // 呼吸感（极慢明暗）
uniform float ring_strength : hint_range(0.0, 1.0) = 0.0;       // 太阳漏光亮环（0=关）
uniform float ring_radius = 0.16;                               // 亮环半径
uniform float ring_width = 0.03;                                // 亮环宽度

void fragment() {
	// 双层噪声：大尺度慢漂 + 小尺度反方向快漂（有机雾斑，非均匀平移）
	vec2 q1 = UV * noise_scale + vec2(time * flow_speed, time * flow_speed * 0.7);
	vec2 q2 = UV * noise_scale * detail_scale + vec2(-time * flow_speed * 0.5, time * flow_speed * 0.35);
	float n1 = texture(noise_tex, fract(q1)).r;
	float n2 = texture(noise_tex, fract(q2)).g;
	float n = mix(n1, n2, detail_strength);

	// 呼吸感：整体极慢明暗脉动（蒙眼/头罩的"闷"感）
	float breath = 1.0 + breath_amplitude * sin(time * 0.05);

	// 整体蒙眼：暗雾带云斑不均匀
	float fog = fog_dark * breath * (0.55 + 0.45 * n);

	// 太阳处更浓：半径带噪声扰动（不规则羽化）+ 第二层细节
	float ds = distance(UV, sun_pos);
	float sun_r = sun_fog_radius * (0.7 + 0.6 * n1);
	float sun_mask = exp(-ds * ds / max(sun_r * sun_r, 0.001));
	fog += sun_mask * sun_fog_extra * (0.55 + 0.45 * n2);

	// 太阳漏光亮环：雾里透光（日食边缘，默认关）
	float ring_d = abs(ds - ring_radius);
	float ring = exp(-ring_d * ring_d / max(ring_width * ring_width, 0.0001));
	fog -= ring * ring_strength * (0.5 + 0.5 * n1);

	// 边缘渐晕：四角更暗（蒙眼/头罩真实感）
	float vig = distance(UV, vec2(0.5));
	fog += vignette_strength * smoothstep(0.55, 1.1, vig);

	fog = clamp(fog, 0.0, 0.9);
	COLOR = vec4(fog_color, fog);
}
