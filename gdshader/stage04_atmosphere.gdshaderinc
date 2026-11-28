// Stage4 统一大气透视：山壁 / 地面 / 石头共用，远处平滑融进黄昏雾色。
// 全部由 stage04_decor 写入全局 shader 参数，改一处三层同步。
global uniform vec3 stage04_atmosphere_color = vec3(0.68, 0.55, 0.56);
global uniform float stage04_atmosphere_start = 600.0;
global uniform float stage04_atmosphere_end = 4500.0;
global uniform float stage04_atmosphere_strength = 0.9;

// spatial fragment 里 VERTEX 是 view-space 位置，其长度就是到相机距离。
float atmosphere_factor(float view_distance) {
	return smoothstep(stage04_atmosphere_start, stage04_atmosphere_end, view_distance)
		* stage04_atmosphere_strength;
}
