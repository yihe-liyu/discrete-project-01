class_name BackgroundEnvPreset
extends Resource

## 背景环境预设：持有完整 Environment 模板（Godot 原生 Environment 编辑器调全部参数：
## 雾/天空/glow/体积雾/tonemap/adjustment 等全成员可用，无需维护参数镜像）
## - build_environment() 深拷贝 → 每次全新实例，根治共享污染（越重跑越暗）
## - 联动内建：build 时天球地面水平色强制跟随雾色（改雾色不露地平线）
## - environment 为 null 时自动构建默认暗环境（自愈）
## 用途：新建关卡背景 = 新建 .tres 预设（含 Environment）+ 场景拼装

@export var environment: Environment

## 联动开关：build 时天球地面水平色 = 雾色（默认开，防改雾色露地平线）
@export var link_ground_to_fog: bool = true


## 构建全新 Environment：深拷贝模板 + 联动规则（每次 new → 实例私有，无共享污染）
func build_environment() -> Environment:
	var e := environment.duplicate(true) if environment else _default_environment()
	if link_ground_to_fog and e.sky and e.sky.sky_material is ProceduralSkyMaterial:
		(e.sky.sky_material as ProceduralSkyMaterial).ground_horizon_color = e.fog_light_color
	return e


## 便捷读取：雾色（读自 environment.fog_light_color；无环境时返回默认值）
var fog_color: Color:
	get: return environment.fog_light_color if environment else Color(0.18, 0.20, 0.23)


## 默认暗环境（environment 未设置时的自愈值，对应 stage01 的暗蓝灰基调）
func _default_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.20, 0.24, 0.30)
	sky_mat.sky_horizon_color = Color(0.26, 0.28, 0.31)
	sky_mat.sky_curve = 0.35
	sky_mat.ground_horizon_color = Color(0.18, 0.20, 0.23)
	sky_mat.ground_bottom_color = Color(0.14, 0.15, 0.17)

	env.sky = Sky.new()
	env.sky.sky_material = sky_mat

	env.fog_enabled = true
	env.fog_light_color = Color(0.18, 0.20, 0.23)
	env.fog_density = 0.15
	env.fog_sky_affect = 0.0

	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	return env
