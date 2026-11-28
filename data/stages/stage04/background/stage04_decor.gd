extends CoroutineScript
## Stage04 背景演出：把天空 shader 的颜色写进全局 shader 参数，供山壁/地面/石头共用。


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
