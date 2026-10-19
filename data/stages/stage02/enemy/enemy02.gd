extends CoroutineScript
##

var target_pos1: Vector2
var target_pos2: Vector2

var 开花弹: BulletData

var dir := Vector2.DOWN
var 角速度: float = diff_pick([6, 5, 4, 3])
var 二段角速度时间: float = diff_pick([0.5, 0.9, 1.3, 1.7])

## 延迟初始化（等父节点完成 add_child 链）
func _ready() -> void:
	call_deferred("_init_enemy")


func _init_enemy() -> void:
	var parent := get_parent()
	if not parent:
		return
	
	parent.create_tween() \
		.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS) \
		.tween_property(parent, "global_position", target_pos1, 2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	var lifecycle: BulletLifecycle
	
	var timeline := start_timeline()
	
	开花弹 = BulletData.new().enemy().blend(true).tex("米弹") \
					.color(Color.RED).grace(2)
	开花弹.velocity = Vector2(0, 350)
	lifecycle = BulletLifecycle.new()
	lifecycle.rotate(角速度)
	lifecycle.until_elapsed(2)
	lifecycle.then()
	lifecycle.rotate(-角速度 / 2)
	lifecycle.accel_heading(-500)
	lifecycle.until_elapsed(二段角速度时间)
	lifecycle.despawn_clear()
	开花弹.trajectory(lifecycle)
	
	var 个数: int = diff_pick([3, 6, 9, 12])
	var 间隔: float = diff_pick([0.2, 0.15, 0.15, 0.1])
	
	timeline.at(0).every(间隔).do(func():
		ctx.bullets.shoot_spread(开花弹, 个数, TAU, dir,
								 target.global_position,
								 AssetRegistry.sounds["shoot"])
		dir = dir.rotated(PI / 8)
	)
	
	timeline.at(3).do(func():
		parent.create_tween() \
			.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS) \
			.tween_property(parent, "global_position", target_pos2, 4) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	)
	
	timeline.at(7).do(func():
		ctx.enemies.despawn(target)
	)
