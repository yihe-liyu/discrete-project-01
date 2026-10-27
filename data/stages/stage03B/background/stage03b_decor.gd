extends CoroutineScript
## Stage03B 背景基础演出：现在只让背景保持运行，后续梦境装饰/雾动画在这里加。


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target

	var ground := ctx.background.get_node_or_null("Ground") as BackgroundPlane
	var ground_color: Color
	if ground:
		ground_color = ground.modulate
		ground.set_modulate(Color.BLACK)

	var timeline := start_timeline()

	timeline.at(2.0).do(func():
		ctx.background.move_camera_by(Vector3(0, 55, 0), 12.0, Tween.EASE_IN_OUT, Tween.TRANS_CUBIC)
	)

	timeline.at(6.0).do(func():
		ctx.background.tween_env_fog(Color(0.549, 0.479, 0.721, 1.0), 0.0, 10.0)
		ctx.background.tween_camera_rotation(Vector3(deg_to_rad(-60), 0, 0), 8.0, Tween.EASE_IN_OUT, Tween.TRANS_CUBIC)
	)

	timeline.at(14.0).do(func():
		if ground:
			ground.tween_modulate(ground_color, 1.5, Tween.EASE_IN, Tween.TRANS_QUAD)
	)

	super.start(ctx, target)
