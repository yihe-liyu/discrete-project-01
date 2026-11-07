extends CoroutineScript

var _stage_director: StageDirector

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target: target = p_target

	_stage_director = StageDirector.new(ctx)

	var timeline: Timeline = start_timeline()

	# 0s: BGM
	timeline.at(0.0).do(func(): _stage_director.stage_bgm())

	super.start(ctx, target)
