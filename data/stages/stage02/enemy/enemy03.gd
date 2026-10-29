extends CoroutineScript


## 第一站位 / 第二站位（由关卡脚本注入）。
var target_pos1: Vector2
var target_pos2: Vector2
var 旋转方向: int = 1
var 时间: float = 5

var 开花弹: BulletData

## 当前发射方向；每次发射后旋转 22.5°，形成缓慢转动的弹幕。
var 发射方向 := Vector2.DOWN

var 发射次数: int = 0


## 一次性初始化：ctx / target 已就绪，且 Enemy 已入树。
func _on_start() -> void:
	if not target:
		return

	# 移动：先减速到第一站位；tween 机制在 EnemyService，内容只给意图。
	ctx.enemies.move_to(target, target_pos1, 2.0)

	var timeline := start_timeline()

	# 米弹：红色、带拖尾；先转 2 秒，再反向转并向后加速，最后清弹。
	开花弹 = BulletData.new().enemy().blend(true).tex("鳞弹") \
		.color(Color.CRIMSON).grace(2).speed(200.0)

	var 个数: int = diff_pick([4, 8, 12, 16])
	var 间隔: float = diff_pick([0.3, 0.25, 0.25, 0.2])

	# 0 秒起持续发射；每次把发射方向转 22.5°，让整圈慢慢扫过。
	timeline.at(0.0).every(间隔).do(func():
		ctx.audio.play_sfx(AssetRegistry.sounds["shoot"])
		ctx.bullets.shoot_spread(
			开花弹, 个数, TAU, 发射方向,
			target.global_position)
		发射方向 = 发射方向.rotated(PI / 23.0 * 旋转方向)
		发射次数 += 1
		开花弹.speed(200 + 75 * sin(发射次数 / 2.0) * 旋转方向)
	)

	# n 秒：转场到第二站位（4 秒，缓入）。
	timeline.at(时间).do(func():
		ctx.enemies.move_to(target, target_pos2, 4,
			Tween.EASE_IN, Tween.TRANS_QUAD)
	)

	# 7 秒：静默退场，不掉道具。
	timeline.at(时间 + 4).do(func():
		ctx.enemies.despawn(target)
	)
