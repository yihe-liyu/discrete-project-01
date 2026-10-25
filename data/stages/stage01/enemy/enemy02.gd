extends CoroutineScript

## 环玉散弹 + 米弹点射
## 扇形环玉（按难度 10~20 发）+ 3 次金色米弹点射；匀速下移出场。

const FLY_AWAY = preload("res://data/stages/stage01/enemy/fly_away.gd")

## 停靠位置（由关卡脚本注入）。
var target_pos: Vector2

## 复用弹型实例（M2）。
var _plain_bullet_data: BulletData
var _heavy_bullet_data: BulletData


## 一次性初始化：ctx / target 已就绪，且 Enemy 已入树。
func _on_start() -> void:
	if not target:
		return

	# 移动：减速到停靠位置；tween 机制在 EnemyService，内容只给意图。
	ctx.enemies.move_to(target, target_pos, 5.0)

	# 弹幕：复用两个弹型实例。
	var timeline := start_timeline()

	# 三波环玉，每波整体随机旋转；同一波内再按难度叠 1~3 层速度。
	timeline.at(1.0).every(2.4).times(3).do(func():
		if _plain_bullet_data == null:
			_plain_bullet_data = BulletData.new().enemy().blend(true).tex("环玉").color(Color.DARK_ORANGE)
		var 发射方向 := Vector2.ONE.rotated(RNG.randf_range(-PI, PI))
		for i in diff_pick([1, 2, 2, 3]):
			_plain_bullet_data.velocity = Vector2(0, 100 + i * 100)
			ctx.bullets.shoot_spread(
				_plain_bullet_data, diff_pick([10, 14, 20, 20]),
				TAU, 发射方向,
				target.global_position, AssetRegistry.sounds["shoot"])
	)

	# Hard 以上：三波金色米弹点射，每波在环玉之后补一轮。
	if ctx.diff.at_least(Difficulty.HARD):
		for i in 3:
			timeline.at(1.0 + i * 2.4).every(0.1).times(diff_pick([0, 0, 4, 8])).do(func():
				if _heavy_bullet_data == null:
					_heavy_bullet_data = BulletData.new().enemy().blend(true).tex("米弹").color(Color.GOLD)
					_heavy_bullet_data.lifecycle = BulletLifecycle.new().accel_world(Vector2(0, 200))
				_heavy_bullet_data.velocity = Vector2(0, 175)
				# 点射方向在正上方左右各偏 60°，形成窄扇。
				var 发射方向 := Vector2.UP.rotated(RNG.randf_range(-PI / 3, PI / 3))
				ctx.bullets.shoot_spread(
					_heavy_bullet_data, 1, 0, 发射方向,
					target.global_position, AssetRegistry.sounds["kira"])
			)

	# 退场：交给公共的随机飘走协程。
	timeline.at(8.0).do(func():
		var 退场协程: CoroutineScript = FLY_AWAY.new()
		target.add_child(退场协程)
		退场协程.start(ctx, target)
		auto_stop = true
	)
