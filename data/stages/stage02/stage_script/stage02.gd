extends CoroutineScript
## 2面

const ENEMY01 = preload("res://data/stages/stage02/enemy/enemy01.gd")
const ENEMY02 = preload("res://data/stages/stage02/enemy/enemy02.gd")

var _stage_director: StageDirector

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target: target = p_target
	
	_stage_director = StageDirector.new(ctx)
	
	var timeline: Timeline = start_timeline()
	var logo_tex: Texture2D = preload("res://assets/Textures/front/logo/logo2.png")

	# 0s: BGM
	timeline.at(0.0).do(func(): _stage_director.stage_bgm())
	
	for i in 7:
		var x = GameConfig.FIELD_CENTER_X + 325 - i * 100
		timeline.at(1.0 + i * 0.2).do(func():
			ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)\
				.pos(Vector2(x, 0)).green_yin_yang_jade()\
				.param("target_pos", Vector2(x, 175+RNG.randi()%50))\
				.param("bullet_name", "苦无")\
				.param("bullet_color", Color.GREEN)\
				.param("bullet_l_or_r", -1)
			)
		)
	
	for i in 7:
		var x = GameConfig.FIELD_CENTER_X - 325 + i * 100
		timeline.at(3.5 + i * 0.2).do(func():
			ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)\
				.pos(Vector2(x, 0)).purple_yin_yang_jade()\
				.param("target_pos", Vector2(x, 175+RNG.randi()%50))\
				.param("bullet_name", "苦无")\
				.param("bullet_color", Color.PURPLE)\
				.param("bullet_l_or_r", 1)
			)
		)
	
	timeline.at(7.0).do(func():
		ctx.stage.show_logo(logo_tex, Vector2(GameConfig.FIELD_CENTER_X, 250))
	)
	
	timeline.at(10.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)\
			.pos(Vector2(0, 0)).red_big_fairy()\
			.param("target_pos1", Vector2(256, 128))\
			.param("target_pos2", Vector2(896, 960))
		)
	)
	
	timeline.at(13.0).every(0.3).times(5).do(func():
		var x = RNG.randi_range(96, 352)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)\
			.pos(Vector2(x, 0)).blue_yin_yang_jade()\
			.param("target_pos", Vector2(x, 175+RNG.randi()%50))\
			.param("bullet_name", "环玉")\
			.param("bullet_color", Color.BLUE)\
			.param("bullet_l_or_r", 1)
		)
	)
	
	timeline.at(18.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)\
			.pos(Vector2(896, 0)).blue_big_fairy()\
			.param("target_pos1", Vector2(640, 128))\
			.param("target_pos2", Vector2(0, 960))
		)
	)
	
	timeline.at(21.0).every(0.3).times(5).do(func():
		var x = RNG.randi_range(544, 800)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)\
			.pos(Vector2(x, 0)).red_yin_yang_jade()\
			.param("target_pos", Vector2(x, 175+RNG.randi()%50))\
			.param("bullet_name", "环玉")\
			.param("bullet_color", Color.RED)\
			.param("bullet_l_or_r", -1)
		)
	)
	
	timeline.at(26.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)\
			.pos(Vector2(0, 0)).red_big_fairy()\
			.param("target_pos1", Vector2(256, 128))\
			.param("target_pos2", Vector2(896, 860))
		)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)\
			.pos(Vector2(896, 0)).blue_big_fairy()\
			.param("target_pos1", Vector2(640, 128))\
			.param("target_pos2", Vector2(0, 860))
		)
	)
	
	for i in 10:
		var x1 = RNG.randi_range(96, 352)
		timeline.at(30.0 + i * 0.4).do(func():
			ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)\
				.pos(Vector2(x1, 0)).purple_yin_yang_jade()\
				.param("target_pos", Vector2(x1, 175+RNG.randi()%50))\
				.param("bullet_name", "点棱弹")\
				.param("bullet_color", Color.MEDIUM_PURPLE)\
				.param("bullet_l_or_r", 1)\
				.param("bullet_speed", 175)
			)
		)
		var x2 = RNG.randi_range(544, 800)
		timeline.at(30.0 + i * 0.4).do(func():
			ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)\
				.pos(Vector2(x2, 0)).green_yin_yang_jade()\
				.param("target_pos", Vector2(x2, 175+RNG.randi()%50))\
				.param("bullet_name", "点棱弹")\
				.param("bullet_color", Color.MEDIUM_SEA_GREEN)\
				.param("bullet_l_or_r", -1)\
				.param("bullet_speed", 200)
			)
		)
	
	timeline.at(38).do(func():
		ctx.enemies.despawn_all()
		ctx.bullets.clear_enemy_bullets()
	)
	
	super.start(ctx, target)


## 信号生命周期约定：场景 _exit_tree 统一断开 autoload 连接
func _exit_tree() -> void:
	if _stage_director:
		_stage_director.dispose()   # 断 dialogue_event 连接 + 清空本关命名槽位
