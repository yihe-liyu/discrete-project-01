extends CoroutineScript
## 大妖精（Stage 2）：先飞到第一站位，边自转边发米弹；3 秒后转场，7 秒退场。
##
## 两个站位由关卡脚本通过 `target_pos1` / `target_pos2` 注入，脚本本身不认识关卡。
## 米弹的lifecycle分两段：先按固定角速度旋转 2 秒，再反向减速并向后加速，最后自动清弹。

## 第一站位 / 第二站位（由关卡脚本注入）。
var target_pos1: Vector2
var target_pos2: Vector2

## 复用弹型实例：弹型缓存在 BulletData 上，禁止每发 new。
var 开花弹: BulletData

## 当前发射方向；每次发射后旋转 22.5°，形成缓慢转动的弹幕。
var 发射方向 := Vector2.DOWN
## 每段lifecycle的自转角速度（弧度/秒）。
var 角速度: float = diff_pick([6.0, 5.0, 4.0, 3.0])
## 第二段反向旋转的持续时间（秒）。
var 二段角速度时间: float = diff_pick([0.5, 0.9, 1.3, 1.7])


## 一次性初始化：ctx / target 已就绪，且 Enemy 已入树。
func _on_start() -> void:
	if not target:
		return

	# 移动：先减速到第一站位；tween 机制在 EnemyService，内容只给意图。
	ctx.enemies.move_to(target, target_pos1, 2.0)

	var lifecycle: BulletLifecycle
	var timeline := start_timeline()

	# 米弹：红色、带拖尾；先转 2 秒，再反向转并向后加速，最后清弹。
	开花弹 = BulletData.new().enemy().blend(true).tex("米弹") \
		.color(Color.RED).grace(2)
	开花弹.velocity = Vector2(0.0, 350.0)
	lifecycle = BulletLifecycle.new()
	lifecycle.rotate(角速度)
	lifecycle.until_elapsed(2.0)
	lifecycle.then()
	lifecycle.rotate(-角速度 / 2.0)
	lifecycle.accel_heading(-500.0)
	lifecycle.until_elapsed(二段角速度时间)
	lifecycle.despawn_clear()
	开花弹.trajectory(lifecycle)

	var 个数: int = diff_pick([3, 6, 9, 12])
	var 间隔: float = diff_pick([0.2, 0.15, 0.15, 0.1])

	# 0 秒起持续发射；每次把发射方向转 22.5°，让整圈慢慢扫过。
	timeline.at(0.0).every(间隔).do(func():
		ctx.bullets.shoot_spread(
			开花弹, 个数, TAU, 发射方向,
			target.global_position,
			AssetRegistry.sounds["shoot"])
		发射方向 = 发射方向.rotated(PI / 8.0)
	)

	# 3 秒：转场到第二站位（4 秒，缓入）。
	timeline.at(3.0).do(func():
		ctx.enemies.move_to(target, target_pos2, 4.0,
			Tween.EASE_IN, Tween.TRANS_QUAD)
	)

	# 7 秒：静默退场，不掉道具。
	timeline.at(7.0).do(func():
		ctx.enemies.despawn(target)
	)
