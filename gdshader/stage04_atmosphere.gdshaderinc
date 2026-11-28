// Stage4 统一大气透视：山壁 / 地面 / 石头共用，远处平滑融进黄昏雾色。
uniform vec3 atmosphere_color : source_color = vec3(0.68, 0.55, 0.56);
uniform float atmosphere_start = 1000.0;
uniform float atmosphere_end = 4000.0;

// spatial fragment 里 VERTEX 是 view-space 位置，其长度就是到相机距离。
float atmosphere_factor(float view_distance) {
	return smoothstep(atmosphere_start, atmosphere_end, view_distance);
}
