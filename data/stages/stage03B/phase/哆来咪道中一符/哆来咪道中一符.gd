extends CoroutineScript
## 哆来咪道中一符

var 发射间隔: float = diff_pick([0.19, 0.16, 0.13, 0.1])
var 初速度: float = 50
var 重力加速度: float = diff_pick([125, 150, 175, 200])
var 激光长度: float = diff_pick([0, 0, 100, 250])

var 雨弹一阶段: SpawnSpec
var 雨弹二阶段: SpawnSpec
var 雨弹三阶段: SpawnSpec
var 二阶段模板: EmitTemplate
var 三阶段模板: EmitTemplate

func _on_start() -> void:
	# 先把三阶段模板都建好：一阶段的 emit 在 phase 结束才真正 flush，
	# 但模板引用在 _on_start 里就会入队，不能等到 emit 之后才初始化二阶段。
	雨弹一阶段 = SpawnSpec.new().tex("滴弹").color(Color.BLUE) \
						 .grace(3).speed(初速度).enemy().blend(true) \
						 .wrap_horizontal()
	雨弹二阶段 = SpawnSpec.new().tex("滴弹").color(Color.AQUA) \
						 .grace(3).enemy().blend(true) \
						 .wrap_horizontal()
	雨弹三阶段 = SpawnSpec.new().tex("滴弹").color(Color.GOLD) \
						 .grace(3).enemy().blend(true) \
						 .wrap_horizontal()

	二阶段模板 = EmitTemplate.new(&"哆来咪道中一符_stage2", 雨弹二阶段)
	三阶段模板 = EmitTemplate.new(&"哆来咪道中一符_stage3", 雨弹三阶段)

	# 二阶段：第一次 tick 从底部平移到顶部，然后受重力；Normal+ 到 y 阈值转三阶段。
	# 三阶段仍保留 lifecycle：Hard 的激光收尾还没进 outcome。
	var lifecycle := BulletLifecycle.new()
	lifecycle.offset_position(Vector2(0, -1000))
	lifecycle.until_elapsed(0.0)
	lifecycle.then()
	lifecycle.accel_world(Vector2(0, 重力加速度))
	if SaveData.selected_difficulty >= Difficulty.HARD:
		# 三阶段在 y≈1000 结束；at_current=true 时骨架要朝上，才在场地内。
		var 激光 := LaserPresets.straight(Vector2.ZERO, Vector2(0, 1500))

		lifecycle.sfx(&"lazer", -14)
		lifecycle.until_y(BulletLifecycle.CMP_GE, 1000)
		lifecycle.emit_laser_dir(激光, Color.GOLD,
							BulletLifecycle.velocity(),
							{
								"grow": true,
								"grow_speed": 重力加速度 * 3,
								"tail": 激光长度,

								"additive": true,
								"core_color": Color(1.0, 1.0, 0.9),
								"glow_color": Color(1.0, 0.75, 0.1)
							},
							Vector2(0, -1000), true)
		lifecycle.despawn_clear()
	雨弹三阶段.trajectory(lifecycle)

func _ensure_rain_behaviors(p_ctx: StageContext) -> bool:
	if 二阶段模板 == null or 三阶段模板 == null:
		return false
	if not p_ctx.bullets.has_emit_template(&"哆来咪道中一符_stage2"):
		if not p_ctx.bullets.register_emit_template(二阶段模板):
			push_error("[哆来咪道中一符] stage2 模板注册失败")
			return false
	if not p_ctx.bullets.has_emit_template(&"哆来咪道中一符_stage3"):
		if not p_ctx.bullets.register_emit_template(三阶段模板):
			push_error("[哆来咪道中一符] stage3 模板注册失败")
			return false
	if 雨弹一阶段.behavior_spec == null:
		雨弹一阶段.with_behavior(BulletBehaviors.rain_stage(
			二阶段模板, 重力加速度, 1000.0, 0.0, true, true))
	if 雨弹二阶段.behavior_spec == null:
		if SaveData.selected_difficulty >= Difficulty.NORMAL:
			雨弹二阶段.with_behavior(BulletBehaviors.rain_stage(
				三阶段模板, 重力加速度, 1000.0, -1000.0, true, true))
		else:
			雨弹二阶段.with_behavior(BulletBehaviors.rain_stage(
				null, 重力加速度, 1000.0, -1000.0, false, false))
	return true


func _tick(p_ctx: StageContext) -> Variant:
	if not _ensure_rain_behaviors(p_ctx):
		return false
	if not target:
		return p_ctx.clock.wait(发射间隔)

	var 随机角度 := Vector2.DOWN.rotated(deg_to_rad(RNG.randf_range(-45.0, 45.0)))
	var 随机位置 := Vector2(RNG.randi_range(64, 832), -32)

	p_ctx.audio.play_sfx(AssetRegistry.sounds["kira"])
	p_ctx.bullets.shoot_spread_spec(雨弹一阶段, 1, 0, 随机角度, 随机位置)

	return 发射间隔
