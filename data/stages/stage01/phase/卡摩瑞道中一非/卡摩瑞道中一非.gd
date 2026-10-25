extends CoroutineScript
## 卡摩瑞道中一非「道中非符」
##
## 声呐弹以高速向外铺开，靠近自机时折返、再飞回 Boss；回到 Boss 附近时
## 向四周炸开一圈水色小玉，Hard / Lunatic 还会额外向 Boss 背后甩出一串红色棱弹。
##
## 整段lifecycle只有一颗“声呐弹”模板：数量、折返半径、尾段开花数都由这里传入。

## 两轮声呐弹之间的间隔（秒）。
var 发射间隔: float = 0.2
## 每轮声呐弹的数量。
var 声呐弹个数: int = diff_pick([32, 48, 64, 72])
## 声呐弹回到 Boss 附近时炸开的小玉数量。
var 开花弹个数: int = diff_pick([2, 4, 6, 8])

## 复用弹型实例：弹型缓存在 BulletData 上，禁止每发 new。
var 声呐弹: BulletData
var 开花弹: BulletData
var 串型弹: BulletData


func _on_start() -> void:
	var lifecycle: BulletLifecycle

	# 尾段开花：水色小玉，从声呐弹的终点向四周均匀铺开。
	开花弹 = BulletData.new().tex("小玉").color(Color(0.35, 0.6, 0.8, 1.0)).blend(true).enemy()

	# Hard / Lunatic 追加的串型弹：红色棱弹，沿 Boss 背后甩出。
	串型弹 = BulletData.new().tex("棱弹").color(Color.RED).blend(true).enemy()

	# 声呐弹：高速、半透明、不起雾；靠近自机后折返，再飞回 Boss。
	声呐弹 = BulletData.new().tex("小玉").speed(1000.0) \
		.color(Color(0.0, 0.906, 1.353, 0.25)).blend(true).enemy().no_spawn_fog()

	lifecycle = BulletLifecycle.new()
	# 第一段：追向自机，进入 150px 后折返；每 3 tick 检查一次距离。
	lifecycle.until_near(BulletLifecycle.T_PLAYER, 150.0)
	lifecycle.every_ticks(3)
	lifecycle.on_end_heading(BulletLifecycle.away(BulletLifecycle.T_PLAYER))
	lifecycle.then()
	# 第二段：飞回 Boss，靠近后炸开；折返半径按难度收紧。
	lifecycle.until_near(BulletLifecycle.T_BOSS, diff_pick([175.0, 150.0, 125.0, 100.0]))
	lifecycle.every_ticks(3)
	lifecycle.sfx(&"kira")
	lifecycle.on_end_heading(BulletLifecycle.random_dir(PI))

	# 尾段开花：向四周均匀铺开一圈小玉。
	for i in 开花弹个数:
		lifecycle.emit(开花弹, BulletLifecycle.forward(TAU * i / 开花弹个数), 400.0)

	# Hard：Boss 背后甩出 4 颗红色棱弹，速度逐颗递增。
	if SaveData.selected_difficulty == Difficulty.HARD:
		for i in 4:
			lifecycle.emit(串型弹,
				BulletLifecycle.away(BulletLifecycle.T_BOSS),
				400.0 + i * 50.0)
	# Lunatic：左右各 8 颗，形成扇形夹击。
	elif SaveData.selected_difficulty == Difficulty.LUNATIC:
		for i in 8:
			lifecycle.emit(串型弹,
				BulletLifecycle.away(BulletLifecycle.T_BOSS, 1.0 / TAU / 6.0),
				400.0 + i * 50.0)
		for i in 8:
			lifecycle.emit(串型弹,
				BulletLifecycle.away(BulletLifecycle.T_BOSS, -1.0 / TAU / 6.0),
				400.0 + i * 50.0)

	lifecycle.despawn()
	声呐弹.trajectory(lifecycle)


func _tick(p_ctx: StageContext) -> Variant:
	if not target:
		return p_ctx.clock.wait(发射间隔)

	# 每轮整体随机旋转，避免声呐弹总从同一个方向起飞。
	var 随机角度 := Vector2.DOWN.rotated(RNG.randf() * TAU)
	p_ctx.bullets.shoot_spread(声呐弹, 声呐弹个数, TAU, 随机角度, target.global_position)

	return p_ctx.clock.wait(发射间隔)
