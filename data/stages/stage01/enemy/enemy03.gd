extends CoroutineScript
## 红杂鱼：五秒缓降到停靠位置，停稳后向自机方向连射两波。
## Hard 以上额外追加金色重力弹；`start_time` 由关卡脚本控制开火时机。

const FLY_AWAY = preload("res://data/stages/stage01/enemy/fly_away.gd")

## 停靠位置（由关卡脚本注入）。
var target_pos: Vector2
## 强化波开关：Hard+ 且为 true 时追加金色重力弹。
var heavy_wave: bool = true
## 普通弹数量倍率；关卡脚本用 rate=4 把连射压成稀疏弹幕。
var rate: int = 1
## 普通弹颜色（默认红色；关卡脚本可覆盖）。
var bullet_color: Color = Color.RED
## 复用弹型实例（M2）。
var _plain_bullet_data: BulletData
var _heavy_bullet_data: BulletData
## 第一波开火时间（秒，由关卡脚本注入）。
var start_time: float = 2.0


## 一次性初始化：ctx / target 已就绪，且 Enemy 已入树。
func _on_start() -> void:
	if not target:
		return

	# 移动：减速到停靠位置；tween 机制在 EnemyService，内容只给意图。
	ctx.enemies.move_to(target, target_pos, 5.0)

	# 弹幕：复用两个弹型实例。
	var timeline := start_timeline()

	timeline.at(start_time).every(3.0).times(2).do(func():
		if _plain_bullet_data == null:
			_plain_bullet_data = BulletData.new().enemy().blend(true).tex("小玉").color(bullet_color).grace(0)

		# 自机方向：自机不在场时退化为向下。
		var 自机 := ctx.player.get_player()
		var 发射方向 := Vector2.DOWN
		if is_instance_valid(自机):
			发射方向 = (自机.global_position - target.position).normalized()
		var 普通弹速度: int = 350

		# 同一方向连成一条线；每颗比上一颗快 50，形成纵向拉开。
		for i in diff_pick([1, 3, 5, 8]) / rate:
			_plain_bullet_data.velocity = Vector2(0, 普通弹速度 + i * 50)
			ctx.bullets.shoot_spread(
				_plain_bullet_data, 1, 0, 发射方向,
				target.global_position, AssetRegistry.sounds["shoot"])

		# 强化波：金色重力弹，向下加速，并向两侧各偏一点。
		if ctx.diff.at_least(Difficulty.HARD) and heavy_wave:
			if _heavy_bullet_data == null:
				_heavy_bullet_data = BulletData.new().enemy().blend(true).tex("棱弹").color(Color.GOLD).grace(3)
				_heavy_bullet_data.lifecycle = BulletLifecycle.new().accel_world(Vector2(0, 200))
			for i in diff_pick([0, 0, 1, 2]):
				_heavy_bullet_data.velocity = Vector2(0, 200 + i * 25)
				ctx.bullets.shoot_spread(
					_heavy_bullet_data, diff_pick([0, 0, 2, 4]),
					PI / (3 - i), -发射方向,
					target.global_position)
	)

	# 射完后加速飘走退场。
	timeline.at(5.0).do(func():
		var 退场协程: CoroutineScript = FLY_AWAY.new()
		target.add_child(退场协程)
		退场协程.start(ctx, target)
		auto_stop = true
	)
