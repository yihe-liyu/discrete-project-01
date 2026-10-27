extends CoroutineScript
## Stage03B 背景基础演出：现在只让背景保持运行，后续梦境装饰/雾动画在这里加。


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target

	var timeline := start_timeline()

	timeline.at(2.0).do(func():
		ctx.background.move_camera_by(Vector3(0, 75, 0), 12.0, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)
	)

	timeline.at(8.0).do(func():
		ctx.background.tween_env_fog(Color(0.8, 0.2, 0.7, 1.0), 0.001, 6.0)
		ctx.background.tween_camera_rotation(Vector3(deg_to_rad(-20), 0, 0), 6.0, Tween.EASE_IN_OUT, Tween.TRANS_SINE)
	)

	super.start(ctx, target)
