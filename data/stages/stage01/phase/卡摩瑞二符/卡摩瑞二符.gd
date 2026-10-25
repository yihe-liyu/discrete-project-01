extends CoroutineScript
## 卡摩瑞二符「递符「定向传播」」
##
## 两张网：蓝鳞弹撞墙后原地反射，形成一层薄薄的“弹墙”；金鳞弹只在 Hard 以上出现，
## 让弹墙多一层颜色，也让难度差异一眼可见。
##
## 难度分派：
## - Easy / Normal：按波次发射蓝环，每波若干圈，圈与圈之间留固定间隔。
## - Hard / Lunatic：不再等波次，改成固定节奏连发蓝环；每次额外补 3 颗金环。

## Easy / Normal 两波之间的等待（秒）；Hard 以上不使用。
var 波间隔: float = diff_pick([3.0, 2.0, 0.0, 0.0])
## Easy / Normal 每波发射的圈数。
var 开花弹次数: int = diff_pick([12, 20, 28, 36])
## 一圈的弹数。
var 开花弹条数: int = diff_pick([8, 12, 16, 20])
## 环的飞行速度。
var 开花弹速度: float = diff_pick([350.0, 400.0, 450.0, 500.0])
## 圈与圈之间的间隔（秒）。
var 波内两次开花间隔: float = diff_pick([0.25, 0.2, 0.15, 0.1])

## Easy / Normal 的波次计时。
var 距下一波计时: float = 2.4
var 波内距下次开花计时: float = 0.0
var 波内剩余开花弹次数: int = 0
## 每一圈的整体旋转角，避免每圈从同一方向开始。
var 随机角度: Vector2

## 复用弹型实例：弹型缓存在 BulletData 上，禁止每发 new。
var 开花弹: BulletData
var 反射弹: BulletData
## Hard 以上的金色版本；Easy / Normal 保持为 null。
var 金开花弹: BulletData
var 金反射弹: BulletData


func _on_start() -> void:
	var lifecycle: BulletLifecycle

	# 红反射弹：撞墙后按镜面方向反弹，速度极低，主要用来“封路”。
	反射弹 = BulletData.new().tex("鳞弹").color(Color.RED).blend(true).enemy()
	lifecycle = BulletLifecycle.new()
	lifecycle.accel_heading(100.0)
	反射弹.trajectory(lifecycle)

	if SaveData.selected_difficulty >= Difficulty.HARD:
		金反射弹 = BulletData.new().tex("鳞弹").color(Color.GOLD).blend(true).enemy()
		lifecycle = BulletLifecycle.new()
		lifecycle.accel_heading(100.0)
		金反射弹.trajectory(lifecycle)

	# 蓝色环：撞到左/右/上墙后生成红反射弹，然后自己消失。
	开花弹 = BulletData.new().tex("鳞弹").blend(true).enemy().speed(开花弹速度) \
		.color(Color.CORNFLOWER_BLUE)
	lifecycle = BulletLifecycle.new()
	lifecycle.until_at_wall(BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP)
	lifecycle.sfx(&"kira")
	lifecycle.emit(反射弹, BulletLifecycle.reflect(), 0.01, BulletLifecycle.AT_PHASE_END)
	lifecycle.despawn()
	开花弹.trajectory(lifecycle)

	if SaveData.selected_difficulty >= Difficulty.HARD:
		# 金色环：和蓝色环同样的撞墙逻辑，只是换颜色与反射弹。
		金开花弹 = BulletData.new().tex("鳞弹").blend(true).enemy().speed(开花弹速度) \
			.color(Color.GOLDENROD)
		lifecycle = BulletLifecycle.new()
		lifecycle.until_at_wall(BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP)
		lifecycle.sfx(&"kira")
		lifecycle.emit(金反射弹, BulletLifecycle.reflect(), 0.01, BulletLifecycle.AT_PHASE_END)
		lifecycle.despawn()
		金开花弹.trajectory(lifecycle)


func _tick(p_ctx: StageContext) -> Variant:
	if not target:
		return p_ctx.clock.wait(波间隔)

	if SaveData.selected_difficulty >= Difficulty.HARD:
		# Hard / Lunatic：固定节奏连发。蓝环从半格偏移开始，金环每圈随机旋转 3 颗。
		随机角度 = Vector2.DOWN.rotated(RNG.randf() * TAU)
		p_ctx.bullets.shoot_spread(
			开花弹, 开花弹条数, TAU,
			Vector2.RIGHT.rotated(TAU / 开花弹条数 / 2.0),
			target.global_position,
			AssetRegistry.sounds["shoot"])
		p_ctx.bullets.shoot_spread(金开花弹, 3, TAU, 随机角度, target.global_position)
		return p_ctx.clock.wait(波内两次开花间隔)

	# Easy / Normal：按波次走。先等波间隔，再在波内按间隔逐圈发射。
	var dt := get_dt()
	if 波内剩余开花弹次数 > 0:
		波内距下次开花计时 += dt
		if 波内距下次开花计时 >= 波内两次开花间隔:
			波内距下次开花计时 = 0.0
			波内剩余开花弹次数 -= 1
			p_ctx.bullets.shoot_spread(
				开花弹, 开花弹条数, TAU, 随机角度,
				target.global_position,
				AssetRegistry.sounds["shoot"])
	else:
		距下一波计时 += dt
		if 距下一波计时 >= 波间隔:
			距下一波计时 = 0.0
			波内距下次开花计时 = 0.0
			波内剩余开花弹次数 = 开花弹次数
			随机角度 = Vector2.DOWN.rotated(RNG.randf() * TAU)

	return true
