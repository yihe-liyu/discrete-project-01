extends CoroutineScript
## 非符1 弹幕：每隔一段时间射一圈特殊弹丸
## auto_stop = false

var _interval: float = 0.2  # 发射间隔（秒）

func _tick(p_ctx: StageContext):
	if not target: return p_ctx.clock.wait(_interval)

	var bullet := BulletData.new()\
		.tex("小玉")\
		.speed(1000)\
		.color(Color(0.0, 0.906, 1.353, 0.25))\
		.blend(true)\
		.enemy()\
		.behavior(preload("res://data/stages/stage01/phase/non_mid01/non_mid01_bullet.gd"))

	# 射一圈，随机初始旋转
	var rand_dir := Vector2.DOWN.rotated(RNG.randf() * TAU)
	p_ctx.bullets.shoot_spread(bullet, diff_pick([32, 48, 64, 72]), TAU, rand_dir, target.global_position)

	return p_ctx.clock.wait(_interval)
