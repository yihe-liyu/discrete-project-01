extends GutTest
## 反弹弹测试：碰框先转向 Boss 再旋转附加角 → 原地重新发射成直线弹（复用原弹）
## 通过 BulletManager 发真弹，手动驱动协程 tick
## 注意：行为脚本读取 GameState.get_boss()，测试里注册一个测试 Boss（448, 240）

const Bounce = preload("res://data/stages/stage01/bullet/bounce_bullet.gd")
const BOSS_CLASS = preload("res://scripts/enemy/boss.gd")

var _boss: Boss


func before_each():
	BulletManager.set_use_kernel(false)  # 本套件测旧 bounce_bullet 脚本（内核见 test_kernel_behavior）
	BulletManager.clear_all()
	_boss = BOSS_CLASS.new()
	_boss.setup(BossData.new().name("测试Boss"), null)
	add_child_autofree(_boss)
	_boss.global_position = Vector2(448, 240)
	if not GameState.active_enemies.has(_boss):
		GameState.active_enemies.append(_boss)


func after_each():
	GameState.active_enemies.erase(_boss)
	BulletManager.clear_all()
	BulletManager.set_use_kernel(true)
	# 无节点模式协程：clear_all 只 queue_free，等一帧让删除队列真正执行（防孤儿）
	await get_tree().process_frame


## 发一颗带反弹行为的真弹（经 BulletManager，走正常回收路径）
func _fire_bounce(pos: Vector2, dir: Vector2, bounce_angle: float = 0.0) -> Bullet:
	var data := BulletData.new()\
		.tex("棱弹")\
		.speed(dir.length())\
		.color(Color.AQUA)\
		.blend(true)\
		.enemy()\
		.behavior(Bounce)
	data.params = {"bounce_angle": bounce_angle}
	return BulletManager.shoot_enemy_bullet(data, pos, dir)


func _aim_from(pos: Vector2) -> Vector2:
	return (Vector2(448, 240) - pos).normalized()


## 左墙：原地重新发射成直线弹沿"朝 Boss"方向飞（默认保速，复用原弹）
func test_left_wall_splits_into_straight():
	var bullet := _fire_bounce(Vector2(GameConfig.FIELD_LEFT + 4, 400), Vector2(-200, 0))
	assert_not_null(bullet.coroutine_script, "应挂反弹行为")
	bullet.coroutine_script.tick_fast(0.02)  # 向左 4px → 触左墙 → 原地重新发射

	assert_eq(BulletManager.active_bullets.size(), 1, "原地重新发射后只剩 1 颗（复用原弹）")
	var straight: Bullet = BulletManager.active_bullets[0]
	assert_eq(straight, bullet, "应复用原弹（原地重新发射），不是新建")
	var expect := _aim_from(Vector2(GameConfig.FIELD_LEFT, 400)).rotated(0.0) * 200.0
	assert_almost_eq(straight.velocity.x, expect.x, 0.01, "直线弹应沿反弹后方向（朝 Boss）")
	assert_almost_eq(straight.velocity.y, expect.y, 0.01, "直线弹 y 应为朝 Boss 分量")
	assert_almost_eq(straight.velocity.length(), 200.0, 0.01, "默认 spawn_speed=0 → 沿用原速")


## 右墙 + 附加角：直线弹方向 = 朝 Boss 再旋转 bounce_angle
func test_right_wall_splits_with_angle():
	var bullet := _fire_bounce(Vector2(GameConfig.FIELD_RIGHT - 4, 400), Vector2(200, 0), -0.3)
	bullet.coroutine_script.tick_fast(0.02)

	assert_eq(BulletManager.active_bullets.size(), 1, "重新发射后只剩 1 颗")
	var straight: Bullet = BulletManager.active_bullets[0]
	var expect := _aim_from(Vector2(GameConfig.FIELD_RIGHT, 400)).rotated(-0.3) * 200.0
	assert_almost_eq(straight.velocity.x, expect.x, 0.01, "应带 bounce_angle 旋转")
	assert_almost_eq(straight.velocity.y, expect.y, 0.01, "应带 bounce_angle 旋转")


## 上墙：Boss 在正下方 → 直线弹竖直向下（保速）
func test_top_wall_splits_down():
	var bullet := _fire_bounce(Vector2(448, GameConfig.FIELD_TOP + 6), Vector2(0, -300))
	bullet.coroutine_script.tick_fast(0.02)

	var straight: Bullet = BulletManager.active_bullets[0]
	assert_almost_eq(straight.velocity.x, 0.0, 0.01, "上墙重新发射：朝下（Boss 在正下方）")
	assert_almost_eq(straight.velocity.y, 300.0, 0.01, "上墙重新发射：保速朝下")


## 无 Boss 时退化为竖直向下（不崩）
func test_no_boss_split_goes_down():
	GameState.active_enemies.erase(_boss)
	var bullet := _fire_bounce(Vector2(GameConfig.FIELD_LEFT + 4, 400), Vector2(-200, 0))
	bullet.coroutine_script.tick_fast(0.02)

	var straight: Bullet = BulletManager.active_bullets[0]
	assert_almost_eq(straight.velocity.x, 0.0, 0.01, "无 Boss 退化为竖直向下")
	assert_almost_eq(straight.velocity.y, 200.0, 0.01, "无 Boss 退化为竖直向下")


## 下墙：不反弹不重新发射（设计：从下边界直接穿出）
func test_bottom_wall_passes_through():
	var bullet := _fire_bounce(Vector2(448, GameConfig.FIELD_BOTTOM - 6), Vector2(0, 300))
	bullet.coroutine_script.tick_fast(0.02)  # 向下 6px → 到下墙
	bullet.coroutine_script.tick_fast(0.02)  # 继续穿出
	assert_almost_eq(bullet.velocity.y, 300.0, 0.01, "下墙不反弹：y 保持向下")
	assert_gt(bullet.global_position.y, GameConfig.FIELD_BOTTOM, "下墙不反弹：直接穿出")
	assert_eq(BulletManager.active_bullets.size(), 1, "下墙不分裂")


## spawn_speed > 0：直线弹用指定速度
func test_spawn_speed_override():
	var bullet := _fire_bounce(Vector2(GameConfig.FIELD_LEFT + 4, 400), Vector2(-200, 0))
	bullet.coroutine_script.spawn_speed = 400.0
	bullet.coroutine_script.tick_fast(0.02)

	var straight: Bullet = BulletManager.active_bullets[0]
	assert_almost_eq(straight.velocity.length(), 400.0, 0.01, "spawn_speed > 0 时用指定速度")


## 加速度：沿当前飞行方向逐渐加速（0 = 匀速）
func test_acceleration_speeds_up():
	var cs: CoroutineScript = Bounce.new()
	autofree(cs)
	cs.accel = 100.0
	var bullet := Bullet.new()
	autofree(bullet)
	bullet.velocity = Vector2(0, 200)
	bullet.global_position = Vector2(448, 500)  # 远离四边，不触发反弹
	cs.start_fast(null, bullet)
	var v0: float = bullet.velocity.length()
	cs.tick_fast(0.1)  # 0.1s → 速度 +100×0.1 = +10
	assert_almost_eq(bullet.velocity.length(), v0 + 10.0, 0.01, "速度应随时间增加")
	cs.tick_fast(0.1)  # 再 +10
	assert_almost_eq(bullet.velocity.length(), v0 + 20.0, 0.01, "持续加速")


## 无加速度 = 匀速（方向/速度都不变）
func test_no_accel_keeps_velocity():
	var cs: CoroutineScript = Bounce.new()
	autofree(cs)
	cs.accel = 0.0
	var bullet := Bullet.new()
	autofree(bullet)
	bullet.velocity = Vector2(0, 200)
	bullet.global_position = Vector2(448, 500)
	cs.start_fast(null, bullet)
	cs.tick_fast(0.1)
	assert_almost_eq(bullet.velocity.length(), 200.0, 0.01, "accel=0 时速度不变")
