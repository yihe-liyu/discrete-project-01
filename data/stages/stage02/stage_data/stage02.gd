extends CoroutineScript
## Stage 2：道中妖精波 → 大妖精 → 收尾。当前没有 Boss / 阶段，属于半关。

const ENEMY01 = preload("res://data/stages/stage02/enemy/enemy01.gd")
const ENEMY02 = preload("res://data/stages/stage02/enemy/enemy02.gd")
const ENEMY03 = preload("res://data/stages/stage02/enemy/enemy03.gd")

var _stage_director: StageDirector

var 无主弹幕: BulletData
var 无主弹幕速度: float
var 星弹次数: int = diff_pick([462, 617, 925, 1850])
var 颜色计数: int = 1

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target: target = p_target

	_stage_director = StageDirector.new(ctx)

	var timeline: Timeline = start_timeline()
	var 标题纹理: Texture2D = preload("res://assets/Textures/front/logo/logo2.png")

	# 0s: BGM
	timeline.at(0.0).do(func(): _stage_director.stage_bgm())

	for i in 7:
		var x = GameConfig.FIELD_CENTER_X + 325 - i * 100
		timeline.at(1.0 + i * 0.2).do(func():
			ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
				.pos(Vector2(x, 0)).green_yin_yang_jade()
				.param("target_pos", Vector2(x, 175+RNG.randi()%50))
				.param("bullet_name", "苦无")
				.param("bullet_color", Color.GREEN)
				.param("bullet_l_or_r", -1)
			)
		)

	for i in 7:
		var x = GameConfig.FIELD_CENTER_X - 325 + i * 100
		timeline.at(3.5 + i * 0.2).do(func():
			ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
				.pos(Vector2(x, 0)).purple_yin_yang_jade()
				.param("target_pos", Vector2(x, 175+RNG.randi()%50))
				.param("bullet_name", "苦无")
				.param("bullet_color", Color.PURPLE)
				.param("bullet_l_or_r", 1)
			)
		)

	timeline.at(7.0).do(func():
		ctx.stage.show_logo(标题纹理, Vector2(GameConfig.FIELD_CENTER_X, 250))
	)

	timeline.at(10.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)
			.pos(Vector2(0, 0)).red_big_fairy()
			.param("target_pos1", Vector2(256, 128))
			.param("target_pos2", Vector2(896, 960))
			.param("旋转方向", 1)
		)
	)

	timeline.at(13.0).every(0.3).times(5).do(func():
		var x = RNG.randi_range(96, 352)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(x, 0)).blue_yin_yang_jade()
			.param("target_pos", Vector2(x, 175+RNG.randi()%50))
			.param("bullet_name", "环玉")
			.param("bullet_color", Color.BLUE)
			.param("bullet_l_or_r", 1)
		)
	)

	timeline.at(18.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)
			.pos(Vector2(896, 0)).blue_big_fairy()
			.param("target_pos1", Vector2(640, 128))
			.param("target_pos2", Vector2(0, 960))
			.param("旋转方向", -1)
		)
	)

	timeline.at(21.0).every(0.3).times(5).do(func():
		var x = RNG.randi_range(544, 800)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(x, 0)).red_yin_yang_jade()
			.param("target_pos", Vector2(x, 175+RNG.randi()%50))
			.param("bullet_name", "环玉")
			.param("bullet_color", Color.RED)
			.param("bullet_l_or_r", -1)
		)
	)

	timeline.at(26.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)
			.pos(Vector2(0, 0)).red_big_fairy()
			.param("target_pos1", Vector2(256, 128))
			.param("target_pos2", Vector2(896, 860))
			.param("旋转方向", 1)
		)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)
			.pos(Vector2(896, 0)).blue_big_fairy()
			.param("target_pos1", Vector2(640, 128))
			.param("target_pos2", Vector2(0, 860))
			.param("旋转方向", -1)
		)
	)

	for i in 10:
		var x1 = RNG.randi_range(96, 352)
		timeline.at(30.0 + i * 0.4).do(func():
			ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
				.pos(Vector2(x1, 0)).purple_yin_yang_jade()
				.param("target_pos", Vector2(x1, 175+RNG.randi()%50))
				.param("bullet_name", "点棱弹")
				.param("bullet_color", Color.MEDIUM_PURPLE)
				.param("bullet_l_or_r", 1)
				.param("bullet_speed", 125)
			)
		)
		var x2 = RNG.randi_range(544, 800)
		timeline.at(30.0 + i * 0.4).do(func():
			ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
				.pos(Vector2(x2, 0)).green_yin_yang_jade()
				.param("target_pos", Vector2(x2, 175+RNG.randi()%50))
				.param("bullet_name", "点棱弹")
				.param("bullet_color", Color.MEDIUM_SEA_GREEN)
				.param("bullet_l_or_r", -1)
				.param("bullet_speed", 125)
			)
		)

	timeline.at(38).do(func():
		ctx.enemies.despawn_all()
		ctx.bullets.clear_enemy_bullets()

		无主弹幕速度 = diff_pick([40, 35, 30, 25])
		无主弹幕 = BulletData.new().enemy().tex("星弹").blend(false) \
							.color(Color.WHITE).speed(无主弹幕速度)
		var lifecycle := BulletLifecycle.new()
		lifecycle.spin_render(PI)
		lifecycle.until_elapsed(4)
		lifecycle.accel_heading(50)
		无主弹幕.trajectory(lifecycle)
	)

	timeline.at(38.5).every(diff_pick([0.08, 0.06, 0.04, 0.02]))\
					 .times(星弹次数).do(func():
		var 随机位置 := Vector2(RNG.randf_range(GameConfig.FIELD_LEFT, GameConfig.FIELD_RIGHT),
							RNG.randf_range(GameConfig.FIELD_TOP, GameConfig.FIELD_BOTTOM))
		if (随机位置.distance_squared_to(p_ctx.player.get_position()) > 60000):
			var 随机角度 := Vector2.ONE.rotated(RNG.randf() * TAU)
			p_ctx.audio.play_sfx(AssetRegistry.sounds["kira"])
			p_ctx.bullets.shoot_spread(无主弹幕, 1, 0, 随机角度, 随机位置)
		var 颜色: float = 1.0 - 1.0 / 星弹次数 * 颜色计数
		无主弹幕.color(Color(颜色, 颜色, 颜色, 1))
		颜色计数 += 1
		无主弹幕速度 += 0.2
		无主弹幕.speed(无主弹幕速度)
	)

	timeline.at(76.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)
			.pos(Vector2(GameConfig.FIELD_CENTER_X, 0))
			.white_huge_fairy()
			.param("target_pos1", Vector2(448, 256))
			.param("target_pos2", Vector2(448, 1000))
			.param("旋转方向", 1)
			.param("开花弹贴图", "火弹")
			.param("开花弹颜色", Color.GOLD)
			.param("时间", 5)
		)
	)

	timeline.at(78).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(864, 480)).red_yin_yang_jade()
			.param("target_pos", Vector2(224, 128+RNG.randi()%50))
			.param("bullet_name", "棱弹")
			.param("bullet_color", Color.RED)
			.param("bullet_l_or_r", -1)
		)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(32, 480)).red_yin_yang_jade()
			.param("target_pos", Vector2(672, 128+RNG.randi()%50))
			.param("bullet_name", "棱弹")
			.param("bullet_color", Color.RED)
			.param("bullet_l_or_r", 1)
		)
	)

	timeline.at(79).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(864, 440)).purple_yin_yang_jade()
			.param("target_pos", Vector2(244, 128+RNG.randi()%50))
			.param("bullet_name", "棱弹")
			.param("bullet_color", Color.PURPLE)
			.param("bullet_l_or_r", -1)
		)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(32, 440)).purple_yin_yang_jade()
			.param("target_pos", Vector2(652, 128+RNG.randi()%50))
			.param("bullet_name", "棱弹")
			.param("bullet_color", Color.PURPLE)
			.param("bullet_l_or_r", 1)
		)
	)

	timeline.at(80).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(864, 400)).blue_yin_yang_jade()
			.param("target_pos", Vector2(264, 128+RNG.randi()%50))
			.param("bullet_name", "棱弹")
			.param("bullet_color", Color.BLUE)
			.param("bullet_l_or_r", -1)
		)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(32, 400)).blue_yin_yang_jade()
			.param("target_pos", Vector2(632, 128+RNG.randi()%50))
			.param("bullet_name", "棱弹")
			.param("bullet_color", Color.BLUE)
			.param("bullet_l_or_r", 1)
		)
	)

	timeline.at(81).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(864, 360)).green_yin_yang_jade()
			.param("target_pos", Vector2(284, 128+RNG.randi()%50))
			.param("bullet_name", "棱弹")
			.param("bullet_color", Color.GREEN)
			.param("bullet_l_or_r", -1)
		)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(32, 360)).green_yin_yang_jade()
			.param("target_pos", Vector2(612, 128+RNG.randi()%50))
			.param("bullet_name", "棱弹")
			.param("bullet_color", Color.GREEN)
			.param("bullet_l_or_r", 1)
		)
	)

	timeline.at(84.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)
			.pos(Vector2(0, 0)).red_big_fairy()
			.param("target_pos1", Vector2(256, 128))
			.param("target_pos2", Vector2(896, 860))
			.param("旋转方向", 1)
			.param("开花弹贴图", "火弹")
			.param("开花弹颜色", Color.GOLD)
			.param("时间", 4)
		)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)
			.pos(Vector2(896, 0)).blue_big_fairy()
			.param("target_pos1", Vector2(640, 128))
			.param("target_pos2", Vector2(0, 860))
			.param("旋转方向", -1)
			.param("开花弹贴图", "火弹")
			.param("开花弹颜色", Color.GOLD)
			.param("时间", 4)
		)
	)

	timeline.at(92).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY03)
			.pos(Vector2(32, 256)).white_huge_fairy()
			.param("target_pos1", Vector2(224, 256))
			.param("target_pos2", Vector2(864, 480))
		)
	)

	timeline.at(99).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY03)
			.pos(Vector2(864, 256)).white_huge_fairy()
			.param("target_pos1", Vector2(672, 256))
			.param("target_pos2", Vector2(32, 480))
			.param("旋转方向", -1)
		)
	)

	timeline.at(105.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(448, 0)).red_yin_yang_jade()
			.param("target_pos", Vector2(448, 480))
			.param("bullet_name", "棱弹")
			.param("bullet_color", Color.RED)
			.param("bullet_l_or_r", 1)
		)
	)

	timeline.at(107.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)
			.pos(Vector2(448, 0)).white_huge_fairy()
			.param("target_pos1", Vector2(448, 480))
			.param("target_pos2", Vector2(448, -128))
			.param("旋转方向", 1)
			.param("开花弹贴图", "火弹")
			.param("开花弹颜色", Color.GOLD)
			.param("时间", 3)
		)
	)

	timeline.at(114.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(192, 0)).red_yin_yang_jade()
			.param("target_pos", Vector2(192, 480))
			.param("bullet_name", "棱弹")
			.param("bullet_color", Color.RED)
			.param("bullet_l_or_r", 1)
		)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)
			.pos(Vector2(704, 0)).red_yin_yang_jade()
			.param("target_pos", Vector2(704, 480))
			.param("bullet_name", "棱弹")
			.param("bullet_color", Color.RED)
			.param("bullet_l_or_r", -1)
		)
	)

	timeline.at(116.0).do(func():
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)
			.pos(Vector2(192, 0)).white_huge_fairy()
			.param("target_pos1", Vector2(192, 480))
			.param("target_pos2", Vector2(192, -128))
			.param("旋转方向", 1)
			.param("开花弹贴图", "火弹")
			.param("开花弹颜色", Color.GOLD)
			.param("时间", 5)
		)
		ctx.enemies.spawn(EnemyData.new().with_script(ENEMY02)
			.pos(Vector2(704, 0)).white_huge_fairy()
			.param("target_pos1", Vector2(704, 480))
			.param("target_pos2", Vector2(704, -128))
			.param("旋转方向", -1)
			.param("开花弹贴图", "火弹")
			.param("开花弹颜色", Color.GOLD)
			.param("时间", 5)
		)
	)

	super.start(ctx, target)


## 信号生命周期约定：场景 _exit_tree 统一断开 autoload 连接
func _exit_tree() -> void:
	if _stage_director:
		_stage_director.dispose()   # 断 dialogue_event 连接 + 清空本关命名槽位
