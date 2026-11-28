extends CoroutineScript
## Stage04 背景演出：把天空 shader 的颜色写进全局 shader 参数，供山壁/地面/石头共用。

@export_group("黄昏天空")
## 屏幕纵向 0=地平线，1=画面顶部。
@export_range(0.0, 1.0, 0.01) var dusk_gradient_start: float = 0.12
@export_range(0.0, 1.0, 0.01) var dusk_gradient_end: float = 0.82
## 暖色彩带中心高度；调大 = 橙色带往上移。
@export_range(0.0, 1.0, 0.01) var dusk_band_center: float = 0.30
@export_range(0.01, 0.6, 0.01) var dusk_band_width: float = 0.24
## 类似记忆值水面的彩色流动层强度。
@export_range(0.0, 0.6, 0.01) var dusk_color_layer_strength: float = 0.48
@export_range(0.5, 8.0, 0.1) var dusk_color_layer_scale: float = 3.2


func _on_start() -> void:
	if ctx == null or ctx.background == null:
		return
	var bg: StageBackground = ctx.background
	var we := bg.world_environment
	if we == null or we.environment == null or we.environment.sky == null:
		return
	var mat := we.environment.sky.sky_material
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		var top: Color = sm.get_shader_parameter("sky_top")
		var horizon: Color = sm.get_shader_parameter("sky_horizon")
		var tint_a: Color = sm.get_shader_parameter("tint_a")
		var tint_b: Color = sm.get_shader_parameter("tint_b")
		var sky := tint_a.lerp(tint_b, 0.45) if tint_a != null and tint_b != null else top.lerp(horizon, 0.55)
		RenderingServer.global_shader_parameter_set(
			"stage04_sky_light", Vector3(sky.r, sky.g, sky.b))
	_apply_dusk_sky_params()


## 方便运行时/Inspector 调分界线，不需要手动改 shader 参数名。
func _apply_dusk_sky_params() -> void:
	var dome := ctx.background.get_node_or_null("SkyDome") as MeshInstance3D
	if dome == null:
		return
	var mat := dome.material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("dusk_gradient_start", dusk_gradient_start)
	mat.set_shader_parameter("dusk_gradient_end", dusk_gradient_end)
	mat.set_shader_parameter("dusk_band_center", dusk_band_center)
	mat.set_shader_parameter("dusk_band_width", dusk_band_width)
	mat.set_shader_parameter("color_layer_strength", dusk_color_layer_strength)
	mat.set_shader_parameter("color_layer_scale", dusk_color_layer_scale)
