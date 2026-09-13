extends CoroutineScript
## Stage01 背景演出 —— 时间线版（组件化：环境/太阳/蒙眼雾已抽成组件与基类 API）
## 环境预设 stage01_env.tres 管"初始状态"，tween_env_* 管"动态变化"，本脚本只做编排

@onready var bg: StageBackground = get_parent() as StageBackground
@onready var ground: BackgroundPlane = bg.get_node("Ground") as BackgroundPlane
@onready var sun: BackgroundSun = bg.get_node("Sun") as BackgroundSun
@onready var fog: ScreenFogFX = bg.get_node("FogFX") as ScreenFogFX

const OAK_LAYER = preload("res://data/stages/stage01/background/oak.tres")
const ENV_PRESET = preload("res://data/stages/stage01/background/stage01_env.tres")


func _ready() -> void:
	# practice 模式不调 start（无演出），但也要有环境 → 这里应用预设
	bg.apply_env_preset(ENV_PRESET)


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target

	# 重跑重置：全新环境 + 相机复位（防 tween 残留/越重跑越暗）
	bg.apply_env_preset(ENV_PRESET)
	bg.reset_camera()
	sun.setup()
	fog.setup(sun)
	ctx.decor.add_layer(OAK_LAYER)
	ctx.decor.batch_spawn("橡树", 160, Vector2(-90, 90), Vector2(-220, -50), ground)

	var tl := start_timeline()

	# ① 雾散光来 (0→6s, tween 12s)
	tl.at(0.0).do(func():
		bg.tween_env_fog(Color.DARK_GRAY, 0.02, 10.0)  # 雾散目标：暖橙（日食结束天光转暖）；密度 0.02：近处清晰远处融雾
		bg.tween_env_fov(68.0, 12.0)
	)

	# ② 相机移动 + 旋转 (6s)
	tl.at(6.0).do(func():
		bg.pan_camera(Vector3(0, 20, -3), 8.0, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)
		bg.rotate_camera(Vector3(deg_to_rad(-30), 0, 0), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	)

	# ③ 地面加速 (10s)
	tl.at(10.0).do(func():
		var t := bg.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		t.tween_method(_camera_accel, 1.0, 7.0, 32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	)

	tl.at(25.0).do(func():
		bg.tween_env_fog(Color(0.733, 0.572, 0.402, 1.0), 0.02, 20.0)
	)

	# ④ 每 4 帧喷一棵树（持续）
	tl.at(0.0).every(4.0 / Engine.physics_ticks_per_second).do(func():
		var x: float = RNG.randf_range(-100, 100)
		var z: float = RNG.randf_range(-220, -180)
		ctx.decor.spawn("橡树", Vector3(x, 8.0, z), Vector2.ZERO, ground)
	)

	tl.at(50.0).do(func():
		bg.tween_env_fog(Color(0.331, 0.58, 0.77, 1.0), 0.01, 35.0)
	)

	tl.at(60.0).do(func():
		var t := bg.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		t.tween_method(_camera_accel, 7.0, 4.0, 25.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		bg.rotate_camera(Vector3(deg_to_rad(-22), 0, 0), 25.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	)

	super.start(ctx, target)


func _camera_accel(mult: float):
	ground.scroll_speed = Vector2(0, -0.1 * mult)
