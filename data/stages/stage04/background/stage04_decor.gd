extends CoroutineScript
## Stage04 背景演出：把天空 shader 的颜色写进全局 shader 参数，供山壁/地面/石头共用。

@export_group("亮度")
## 环境 Sky 环境光强度。
@export_range(0.0, 2.0, 0.01) var ambient_light_energy: float = 0.65
@export_range(0.2, 2.0, 0.01) var wall_brightness: float = 1.15
@export_range(0.2, 2.0, 0.01) var ground_brightness: float = 1.10
@export_range(0.2, 2.0, 0.01) var rock_brightness: float = 1.0

@export_group("大气透视")
## 基础雾色；会按 atmosphere_sky_blend 混入天空 horizon/tint。
@export var atmosphere_color: Color = Color(0.68, 0.55, 0.56)
@export_range(0.0, 1.0, 0.01) var atmosphere_sky_blend: float = 0.35
@export_range(0.0, 8000.0, 10.0) var atmosphere_start: float = 600.0
@export_range(1000.0, 8000.0, 10.0) var atmosphere_end: float = 4500.0
@export_range(0.0, 1.0, 0.01) var atmosphere_strength: float = 0.9

@export_group("前进速度")
## 山谷 / 地面 / 彩石统一前进速度。改这里三处一起变。
@export var forward_speed: float = 80.0
## 预计一局时长（秒）；连续山壁长度 = speed × duration + margin。
@export var run_duration_seconds: float = 480.0
@export var continuous_length_margin: float = 1600.0

@export_group("黄昏上升/下降")
## 道中开始时天空颜色分界线在高位，随后下降到下方终值。
@export var dusk_descent_enabled: bool = true
@export_range(1.0, 600.0, 1.0) var dusk_descent_duration: float = 90.0
## 高位起点：屏幕纵向 0=地平线，1=顶部。
@export_range(0.0, 1.0, 0.01) var dusk_high_gradient_start: float = 0.58
@export_range(0.0, 1.0, 0.01) var dusk_high_gradient_end: float = 0.96
@export_range(0.0, 1.0, 0.01) var dusk_high_band_center: float = 0.68

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

var _dusk_elapsed: float = 0.0
var _dusk_active: bool = false


func _on_start() -> void:
	if ctx == null or ctx.background == null:
		return
	_apply_motion()
	apply_brightness()
	apply_atmosphere()
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
	_dusk_elapsed = 0.0
	_dusk_active = dusk_descent_enabled and dusk_descent_duration > 0.01
	if _dusk_active:
		_apply_dusk_values(dusk_high_gradient_start, dusk_high_gradient_end,
			dusk_high_band_center, dusk_band_width,
			dusk_color_layer_strength, dusk_color_layer_scale)


func _tick(_ctx: StageContext) -> Variant:
	if not _dusk_active:
		return true
	_dusk_elapsed += get_dt()
	var t := clampf(_dusk_elapsed / dusk_descent_duration, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	_apply_dusk_values(
		lerpf(dusk_high_gradient_start, dusk_gradient_start, eased),
		lerpf(dusk_high_gradient_end, dusk_gradient_end, eased),
		lerpf(dusk_high_band_center, dusk_band_center, eased),
		dusk_band_width, dusk_color_layer_strength, dusk_color_layer_scale)
	if t >= 1.0:
		_dusk_active = false
	return true


## 统一大气透视入口：颜色会按比例受天空 horizon/tint 影响。
func apply_atmosphere() -> void:
	if ctx == null or ctx.background == null:
		return
	var bg: StageBackground = ctx.background
	var color := atmosphere_color
	if bg.world_environment and bg.world_environment.environment:
		var env := bg.world_environment.environment
		if env.sky and env.sky.sky_material is ShaderMaterial:
			var sm := env.sky.sky_material as ShaderMaterial
			var horizon: Color = sm.get_shader_parameter("sky_horizon")
			var tint_a: Color = sm.get_shader_parameter("tint_a")
			var tint_b: Color = sm.get_shader_parameter("tint_b")
			var sky_dusk := horizon.lerp(tint_a, 0.35).lerp(tint_b, 0.15)
			color = color.lerp(sky_dusk, atmosphere_sky_blend)
	RenderingServer.global_shader_parameter_set(
		"stage04_atmosphere_color", Vector3(color.r, color.g, color.b))
	RenderingServer.global_shader_parameter_set("stage04_atmosphere_start", atmosphere_start)
	RenderingServer.global_shader_parameter_set("stage04_atmosphere_end", atmosphere_end)
	RenderingServer.global_shader_parameter_set("stage04_atmosphere_strength", atmosphere_strength)


## 统一亮度入口：Inspector 或代码调完参数后可再次调用。
func apply_brightness() -> void:
	if ctx == null or ctx.background == null:
		return
	var bg: StageBackground = ctx.background
	if bg.world_environment and bg.world_environment.environment:
		bg.world_environment.environment.ambient_light_energy = ambient_light_energy

	var valley := bg.get_node_or_null("Valley")
	if valley and valley.has_method("set_wall_brightness"):
		valley.set_wall_brightness(wall_brightness)

	var ground := bg.get_node_or_null("Ground") as MeshInstance3D
	if ground and ground.material_override is ShaderMaterial:
		(ground.material_override as ShaderMaterial).set_shader_parameter("brightness", ground_brightness)

	var stones := bg.get_node_or_null("Stones")
	if stones and stones.has_method("set_brightness"):
		stones.set_brightness(rock_brightness)


func _apply_motion() -> void:
	var valley := ctx.background.get_node_or_null("Valley")
	if valley and valley.has_method("configure_motion"):
		valley.configure_motion(forward_speed, run_duration_seconds, continuous_length_margin)

	var stones := ctx.background.get_node_or_null("Stones")
	if stones:
		stones.scroll_speed = forward_speed

	var ground := ctx.background.get_node_or_null("Ground") as MeshInstance3D
	if ground and ground.material_override is ShaderMaterial:
		(ground.material_override as ShaderMaterial).set_shader_parameter("scroll_speed", forward_speed)


## 方便运行时/Inspector 调分界线，不需要手动改 shader 参数名。
func _apply_dusk_sky_params() -> void:
	_apply_dusk_values(dusk_gradient_start, dusk_gradient_end, dusk_band_center,
		dusk_band_width, dusk_color_layer_strength, dusk_color_layer_scale)


func _apply_dusk_values(gradient_start: float, gradient_end: float, band_center: float,
		band_width: float, layer_strength: float, layer_scale: float) -> void:
	if ctx == null or ctx.background == null:
		return
	var dome := ctx.background.get_node_or_null("SkyDome") as MeshInstance3D
	if dome == null:
		return
	var mat := dome.material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("dusk_gradient_start", gradient_start)
	mat.set_shader_parameter("dusk_gradient_end", gradient_end)
	mat.set_shader_parameter("dusk_band_center", band_center)
	mat.set_shader_parameter("dusk_band_width", band_width)
	mat.set_shader_parameter("color_layer_strength", layer_strength)
	mat.set_shader_parameter("color_layer_scale", layer_scale)
