extends CoroutineScript
## Stage01 背景演出（时间线版）
## 组件化：环境/太阳/蒙眼雾已抽成组件；相机 / 环境 / 雾的动词一律走 **`ctx.background`**。
##
## ⚠️ 两条纪律（BGA，2026-10-04）：
##   ① **不许 `get_parent()`** —— 那是 R2 禁止的往上摸。要背景宿主就用 `ctx.background`；
##   ② **不许自己 `create_tween()`** —— 要"渐变"就用现成的意图动词（如 `ground.speed_ramp`）。
## 背景场景是**本内容自己的**场景 ⇒ 里面节点（Ground/Sun/FogFX）按名字访问**是允许的**。

const OAK_LAYER = preload("res://data/stages/stage01/background/oak.tres")

var _background_plane: BackgroundPlane


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target

	# 开演 / 重跑复位：环境从**场景声明的预设**重建 + 相机回初始姿态（防 tween 残留 / 越重跑越暗）
	ctx.background.reset()
	# ⚠️ 太阳 / 蒙眼雾**不需要在这里 setup**：它们"声明即显示"，相机与太阳由**宿主**
	#    （`StageBackground._resolve_showcase()`）按类型接线 —— "忘调就隐形且零报错"的老坑已废止。
	_background_plane = ctx.background.get_node("Ground") as BackgroundPlane
	ctx.decor.add_layer(OAK_LAYER)
	ctx.decor.batch_spawn("橡树", 160, Vector2(-90, 90), Vector2(-220, -50), _background_plane)

	var timeline := start_timeline()

	# ① 雾散光来 (0→6s, tween 12s)
	timeline.at(0.0).do(func():
		ctx.background.tween_env_fog(Color(0.25, 0.27, 0.30), 0.02, 10.0)  # 冷灰雾：近处清晰、远处渐淡进雾色
		# ⚠️ 别用 `Color.DARK_GRAY` —— 那是 **CSS darkgray (#A9A9A9, 亮度 0.663) 亮灰**，
		#    雾色亮灰 = 把远处**洗亮**（实测「远/近」= 1.15，看着发灰不真实；0.25/0.27/0.30 → 1.02）
		# ⚠️ 也别为"远处更渐淡"把密度整体调大（试过 0.08）：指数雾是**全局**加厚 ⇒ 背景被糊没
		ctx.background.tween_camera_fov(68.0, 12.0)
	)

	# ② 相机移动 + 旋转 (6s)
	timeline.at(6.0).do(func():
		ctx.background.move_camera_by(Vector3(0, 20, -3), 8.0, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)
		ctx.background.set_camera_rotation(Vector3(deg_to_rad(-30), 0, 0), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	)

	# ③ 地面加速 (10s)：**意图动词**，tween 归 `BackgroundPlane` 自己管
	timeline.at(10.0).do(func(): _background_plane.speed_ramp(1.0, 7.0, 32.0))

	timeline.at(25.0).do(func():
		ctx.background.tween_env_fog(Color(0.733, 0.572, 0.402, 1.0), 0.02, 20.0)
	)

	# ④ 每 4 帧喷一棵树（持续）
	timeline.at(0.0).every(4.0 / Engine.physics_ticks_per_second).do(func():
		var x: float = RNG.randf_range(-100, 100)
		var z: float = RNG.randf_range(-220, -180)
		ctx.decor.spawn("橡树", Vector3(x, 8.0, z), Vector2.ZERO, _background_plane)
	)

	timeline.at(50.0).do(func():
		ctx.background.tween_env_fog(Color(0.331, 0.58, 0.77, 1.0), 0.01, 35.0)
	)

	timeline.at(60.0).do(func():
		_background_plane.speed_ramp(7.0, 4.0, 25.0)
		ctx.background.set_camera_rotation(Vector3(deg_to_rad(-22), 0, 0), 25.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	)

	super.start(ctx, target)
