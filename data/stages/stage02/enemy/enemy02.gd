extends CoroutineScript
## 大妖精（Stage 2）：先飞到第一站位，边自转边发米弹；3 秒后转场，7 秒退场。
##
## 两个站位由关卡脚本通过 `target_pos1` / `target_pos2` 注入，脚本本身不认识关卡。
## 米弹的 spin_then_slow 分两段：先按固定角速度旋转 2 秒，再反向减速并向后加速，最后自动清弹。

## 第一站位 / 第二站位（由关卡脚本注入）。
var target_pos1: Vector2
var target_pos2: Vector2
var 旋转方向: int = 1
var 开花弹贴图: String = "米弹"
var 开花弹颜色: Color = Color.RED
var 时间: float = 4

## 复用弹型实例：弹型缓存在 SpawnSpec 上，禁止每发 new。
var 开花弹1: SpawnSpec
var 开花弹2: SpawnSpec

## 当前发射方向；每次发射后旋转 22.5°，形成缓慢转动的弹幕。
var 发射方向 := Vector2.DOWN
## 每段 behavior 的自转角速度（弧度/秒）。
var 角速度: float = diff_pick([6.0, 5.0, 4.0, 3.0])

var 发射次数: int = 0


## 一次性初始化：ctx / target 已就绪，且 Enemy 已入树。
func _on_start() -> void:
	if not target:
		return

	# 移动：先减速到第一站位；tween 机制在 EnemyService，内容只给意图。
	ctx.enemies.move_to(target, target_pos1, 2.0)

	var timeline := start_timeline()

	# 米弹：红色、带拖尾；先转 2 秒，再反向转并沿 heading 减速。
	开花弹1 = SpawnSpec.new().enemy().blend(true).tex(开花弹贴图) \
	.color(开花弹颜色).grace(2).speed(350.0)
	开花弹1.with_behavior(BulletBehaviors.spin_then_slow(
	角速度 * 旋转方向, 2.0, -0.5, -500.0, 200.0, true, true))

	开花弹2 = SpawnSpec.new().enemy().blend(true).tex(开花弹贴图) \
	.color(Color.CRIMSON).grace(2).speed(350.0)
	开花弹2.with_behavior(BulletBehaviors.spin_then_slow(
	角速度 * 旋转方向, 2.0, 0.0, -500.0, 200.0, false, false))

	var 个数: int = diff_pick([3, 6, 9, 12])
	var 间隔: float = diff_pick([0.2, 0.15, 0.15, 0.1])
	var 频率: int = diff_pick([4, 4, 5, 6])

	# 0 秒起持续发射；每次把发射方向转 22.5°，让整圈慢慢扫过。
	timeline.at(0.0).every(间隔).do(func():
		ctx.audio.play_sfx(AssetRegistry.sounds["shoot"])
		if(发射次数 % 频率 == 0):
			ctx.bullets.shoot_spread_spec(
				开花弹2, 个数, TAU, 发射方向,
				target.global_position)
		else:
			ctx.bullets.shoot_spread_spec(
				开花弹1, 个数, TAU, 发射方向,
				target.global_position)
		发射方向 = 发射方向.rotated(PI / 8.0 * 旋转方向)

		发射次数 += 1
	)

	# 3 秒：转场到第二站位（n 秒，缓入）。
	timeline.at(3.0).do(func():
		ctx.enemies.move_to(target, target_pos2, 时间,
			Tween.EASE_IN, Tween.TRANS_QUAD)
	)

	# 7 秒：静默退场，不掉道具。
	timeline.at(3 + 时间).do(func():
		ctx.enemies.despawn(target)
	)
