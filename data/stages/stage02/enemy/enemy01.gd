extends CoroutineScript
## 阴阳玉（Stage 2）：缓降到停靠位置，沿一个方向逐颗甩出链弹。
##
## 链弹的发射方向每隔一颗偏转一点，形成一条弯曲的“链”；`bullet_l_or_r` 控制
## 链向哪一侧弯。参数全部由关卡脚本注入：
## `target_pos` / `bullet_name` / `bullet_color` / `bullet_l_or_r` / `bullet_speed`。

## 停靠位置（由关卡脚本注入）。
var target_pos: Vector2
## 弹型 key（AssetRegistry / data/bullets）。
var bullet_name: String
## 弹色。
var bullet_color: Color
## 链的弯曲方向：+1 / -1。
var bullet_l_or_r: int
## 链弹初速度。
var bullet_speed: int = 250

## 复用弹型实例：弹型缓存在 BulletData 上，禁止每发 new。
var 链弹: BulletData


## 一次性初始化：ctx / target 已就绪，且 Enemy 已入树。
func _on_start() -> void:
	if not target:
		return

	# 移动：向下减速到停靠位置；tween 机制在 EnemyService，内容只给意图。
	ctx.enemies.move_to(target, target_pos, 1.5)

	var timeline := start_timeline()

	链弹 = BulletData.new().enemy().blend(true).tex(bullet_name) \
		.color(bullet_color)
	链弹.velocity = Vector2(0, bullet_speed)

	# 初始瞄准：自机在场就指向自机，否则向下。
	var 自机 := ctx.player.get_player()
	var 发射方向 := Vector2.DOWN
	if is_instance_valid(自机):
		发射方向 = (自机.global_position - target.position).normalized()

	# 每颗链弹共享一个基准方向，再按序号偏转；序号越大，间隔越小。
	var 角度分段数: int = diff_pick([9, 18, 18, 18])
	for i in diff_pick([36, 72, 72, 144]):
		# 0.365i - 0.005i²：先快后慢，链弹在前段拉开、后段收密。
		timeline.at(0.365 * i - 0.005 * i * i).do(func():
			ctx.bullets.shoot_spread(
				链弹, 1, 0,
				发射方向.rotated(PI / 角度分段数 * i * bullet_l_or_r),
				target.global_position, AssetRegistry.sounds["shoot"])
		)

	# 5 秒：向屏幕下方飞出（第二站位在画面外）。
	timeline.at(5.0).do(func():
		ctx.enemies.move_to(target, Vector2(target_pos.x, 1400.0), 3.0,
			Tween.EASE_IN, Tween.TRANS_CUBIC)
	)

	# 10 秒：彻底离开后静默回收。
	timeline.at(10.0).do(func():
		ctx.enemies.despawn(target)
	)
