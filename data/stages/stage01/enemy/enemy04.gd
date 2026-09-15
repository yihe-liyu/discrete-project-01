extends CoroutineScript


## 匀速下移速度（px/s），外部可用 param("move_speed", v) 覆盖
var move_speed: float = 120.0

## 复用弹型实例（M2）
var _radial_bullet_data: BulletData
## 换向替换弹（米弹/FUCHSIA）：共享实例（static）
static var _radial_spawn_bullet_data: BulletData

## 延迟初始化（等父节点完成 add_child 链）
func _ready() -> void:
	call_deferred("_init_enemy")


func _init_enemy() -> void:
	var parent := get_parent()
	if not parent:
		return

	# 弹幕（复用弹型实例）
	if _radial_bullet_data == null:
		if _radial_spawn_bullet_data == null:
			_radial_spawn_bullet_data = BulletData.new().enemy().blend(true).tex("米弹").color(Color.FUCHSIA)
		_radial_bullet_data = BulletData.new().enemy().blend(true).tex("棱弹").color(Color.FUCHSIA)
		# 沿各自发射角度加速扩散（替换弹共享实例）
		_radial_bullet_data.trajectory(BulletLifecycle.radial_accel(150.0, _radial_spawn_bullet_data, &"kira", -6.0))

	var timeline := start_timeline()

	timeline.at(1.5).every(2).times(2).do(func():
		var dir = Vector2.ONE.rotated(RNG.randf_range(-PI, PI))
		var count = diff_pick([15, 20, 20, 30])
		for i in diff_pick([1, 1, 2, 2]):
			_radial_bullet_data.velocity = Vector2(0, 50 + i * 50)
			ctx.bullets.shoot_spread(_radial_bullet_data, count,
				TAU, dir,
				target.global_position, AssetRegistry.sounds["shoot"])
			dir = dir.rotated(TAU / count / 2)
	)

	auto_stop = true


## 移动：匀速下移直到离开屏幕（弹幕 timeline 并行推进，发完后移动不中断）
func _tick(_ctx: StageContext) -> Variant:
	if target and is_instance_valid(target):
		target.global_position.y += move_speed * get_dt()
		# 离开屏幕（下缘 + 90px 宽限）：销毁
		if target.global_position.y > GameConfig.VIEW_HEIGHT + 32.0:
			target.queue_free()
			return false
	# 弹幕 timeline 照常推进（事件发完即停，但移动持续到出屏）
	if _timeline:
		_timeline.tick(get_dt())
	return true
