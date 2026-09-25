extends CoroutineScript
## 卡摩瑞道中非符

var 发射间隔: float = 0.2
var 声呐弹个数: int = diff_pick([32, 48, 64, 72])
var 开花弹个数: int = diff_pick([2, 4, 6, 8])
var 声呐弹: BulletData
var 开花弹: BulletData
var 串型弹: BulletData

func _on_start() -> void:
	var lifecycle: BulletLifecycle

	开花弹 = BulletData.new().tex("小玉").color(Color(0.35, 0.6, 0.8, 1.0)).blend(true).enemy()

	串型弹 = BulletData.new().tex("棱弹").color(Color.RED).blend(true).enemy()

	声呐弹 = BulletData.new().tex("小玉").speed(1000)\
			.color(Color(0.0, 0.906, 1.353, 0.25)).blend(true).enemy().no_spawn_fog()
	lifecycle = BulletLifecycle.new()
	lifecycle.until_near(BulletLifecycle.T_PLAYER, 150.0)
	lifecycle.every_ticks(3)
	lifecycle.on_end_heading(BulletLifecycle.away(BulletLifecycle.T_PLAYER))
	lifecycle.then()
	lifecycle.until_near(BulletLifecycle.T_BOSS, diff_pick([175.0, 150.0, 125.0, 100.0]))
	lifecycle.every_ticks(3)
	lifecycle.sfx(&"kira")
	for i in 开花弹个数:
		lifecycle.emit(开花弹, BulletLifecycle.forward(TAU * i / 开花弹个数), 400.0)
	if SaveData.selected_difficulty == 2:
		for i in 4:
			lifecycle.emit(串型弹,
						   BulletLifecycle.away(BulletLifecycle.T_BOSS),
						   400.0 + i * 50)
	elif SaveData.selected_difficulty == 3:
		for i in 8:
			lifecycle.emit(串型弹,
						   BulletLifecycle.away(BulletLifecycle.T_BOSS, 1 / TAU / 6),
						   400.0 + i * 50)
		for i in 8:
			lifecycle.emit(串型弹,
						   BulletLifecycle.away(BulletLifecycle.T_BOSS, -1 / TAU / 6),
						   400.0 + i * 50)
	lifecycle.despawn()
	声呐弹.trajectory(lifecycle)


func _tick(p_ctx: StageContext):
	if not target:
		return p_ctx.clock.wait(发射间隔)

	var 随机角度 := Vector2.DOWN.rotated(RNG.randf() * TAU)
	p_ctx.bullets.shoot_spread(声呐弹, 声呐弹个数, TAU, 随机角度, target.global_position)

	return p_ctx.clock.wait(发射间隔)
