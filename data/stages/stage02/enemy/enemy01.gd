extends CoroutineScript
##

var target_pos: Vector2
var bullet_name: String
var bullet_color: Color
var bullet_l_or_r: int
var bullet_speed: int = 250

var 链弹: BulletData

## 延迟初始化（等父节点完成 add_child 链）
func _ready() -> void:
	call_deferred("_init_enemy")


func _init_enemy() -> void:
	var parent := get_parent()
	if not parent:
		return

	# 移动:向下减速
	parent.create_tween() \
		.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS) \
		.tween_property(parent, "global_position", target_pos, 1.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	var timeline := start_timeline()
	
	链弹 = BulletData.new().enemy().blend(true).tex(bullet_name) \
					.color(bullet_color)
	链弹.velocity = Vector2(0, bullet_speed)
	var player := ctx.player.get_player()
	var dir := Vector2.DOWN
	var count: int = diff_pick([9, 18, 18, 18])
	if is_instance_valid(player):
		dir = (player.global_position - target.position).normalized()
	for i in diff_pick([36, 72, 72, 144]):
		timeline.at(0.365 * i - 0.005 * i * i).do(func():
			ctx.bullets.shoot_spread(链弹, 1, 0,
			dir.rotated(PI / count * i * bullet_l_or_r),
			target.global_position, AssetRegistry.sounds["shoot"])
		)
	
	timeline.at(5).do(func():
		parent.create_tween() \
			.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS) \
			.tween_property(parent, "global_position", Vector2(target_pos.x, 1400), 3) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	)
	
	timeline.at(10).do(func():
		ctx.enemies.despawn(target)
	)
	
