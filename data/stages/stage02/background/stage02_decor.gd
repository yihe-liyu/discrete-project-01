extends CoroutineScript
## Stage02 背景演出（时间线版）
## 与 stage01 同口径：相机 / 环境 / 雾的动词走 [code]ctx.background[/code]；
## 不 [code]get_parent()[/code]（R2）、不自己 [code]create_tween()[/code]（渐变走意图动词）。
##
## 还没建 [code]oak.tres[/code]、[code]add_layer[/code] 也还注释着 ⇒ 下面 [code]batch_spawn[/code] / [code]spawn("橡树", …)[/code]
##    会走 [code]DecorManager._require_layer()[/code] 的响亮分支（报「未声明的层 '橡树'」）——树不会出现。
##    要出树：建 [code]oak.tres[/code] + 打开下面那行 [code]add_layer[/code]。

const OAK_LAYER = preload("res://data/stages/stage01/background/oak.tres")

var _background_plane: BackgroundPlane


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target

	# 开演 / 重跑复位：环境从**场景声明的预设**重建 + 相机回初始姿态
	# ⚠️ 相机旋转这里用**相对**动词 `rotate_camera_by`：原来 4 条 Y 是 −10/+25/−30/+15（**和 = 0**），
	#    本意就是「转过去再转回来」⇒ 只有相对动词才能自然回 0。
	#    （旧名 `rotate_camera` 是**绝对**：最后一条 +15° 就是终态 —— 2026-10-04 作者实测「Y 没回到 0」的根因。）
	ctx.background.reset()
	_background_plane = ctx.background.get_node("Ground") as BackgroundPlane
	ctx.decor.add_layer(OAK_LAYER)
	
	ctx.decor.batch_spawn("橡树", 120, Vector2(-80, -10), Vector2(-180, -10), _background_plane)
	ctx.decor.batch_spawn("橡树", 120, Vector2(10, 80), Vector2(-180, -10), _background_plane)

	var timeline := start_timeline()

	# 每 3.0 帧喷一棵树（持续）
	timeline.at(0.0).every(3.0 / Engine.physics_ticks_per_second).do(func():
		var x1: float = RNG.randf_range(-80, -12)
		var z: float = RNG.randf_range(-220, -180)
		ctx.decor.spawn("橡树", Vector3(x1, 8.0, z), Vector2.ZERO, _background_plane)
		var x2: float = RNG.randf_range(12, 80)
		ctx.decor.spawn("橡树", Vector3(x2, 8.0, z), Vector2.ZERO, _background_plane)
	)

	timeline.at(0.0).do(func():
		_background_plane.speed_ramp(2.0, 5.0, 7.0)
	)

	timeline.at(6.0).do(func():
		ctx.background.move_camera_by(Vector3(0, 10, 0), 8.0, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)
		ctx.background.rotate_camera_by(Vector3(deg_to_rad(10), deg_to_rad(-10), 0), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	)

	timeline.at(12.0).do(func():
		ctx.background.rotate_camera_by(Vector3(deg_to_rad(-15), deg_to_rad(35), 0), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	)

	timeline.at(24.0).do(func():
		ctx.background.rotate_camera_by(Vector3(0, deg_to_rad(-55), 0), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
		ctx.background.tween_camera_fov(110.0, 12.0)
	)

	timeline.at(30.0).do(func():
		ctx.background.rotate_camera_by(Vector3(deg_to_rad(20), deg_to_rad(30), 0), 7.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	)
	
	#timeline.at(25.0).do(func():
		#ctx.background.tween_env_fog(Color(0.733, 0.572, 0.402, 1.0), 0.02, 20.0)
	#)

	#timeline.at(50.0).do(func():
		#ctx.background.tween_env_fog(Color(0.331, 0.58, 0.77, 1.0), 0.01, 35.0)
	#)

	#timeline.at(60.0).do(func():
		#_background_plane.speed_ramp(7.0, 4.0, 25.0)
		#ctx.background.tween_camera_rotation(Vector3(deg_to_rad(-22), 0, 0), 25.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	#)

	super.start(ctx, target)
