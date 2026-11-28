// Stage4 统一距离雾：地面 / 山壁 / 石头共用同一组参数。
uniform vec3 haze_color : source_color = vec3(0.6, 0.7, 0.79);
uniform float haze_start = 650.0;
uniform float haze_end = 3000.0;

float stage04_haze(float world_z) {
	return smoothstep(haze_start, haze_end, -world_z);
}
