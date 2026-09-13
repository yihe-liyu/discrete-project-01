extends CoroutineScript

const GRAVITY_BULLET = preload("res://data/stages/stage01/bullet/gravity_bullet.gd")
const FLY_AWAY = preload("res://data/stages/stage01/enemy/fly_away.gd")

var target_pos: Vector2

## 复用弹型实例（M2）
var _plain_bullet_data: BulletData
var _heavy_bullet_data: BulletData

## 延迟初始化（等父节点完成 add_child 链）
func _ready() -> void:
	call_deferred("_init_enemy")


func _init_enemy() -> void:
	var parent := get_parent()
	if not parent:
		return

	# 移动:减速到某位置
	parent.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_property(parent, "global_position",
		target_pos, 5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 弹幕（复用两个弹型实例）
	var timeline := start_timeline()

	timeline.at(1.0).every(2.4).times(3).do(func():
		if _plain_bullet_data == null:
			_plain_bullet_data = BulletData.new().enemy().blend(true).tex("环玉").color(Color.DARK_ORANGE)
		var dir = Vector2.ONE.rotated(RNG.randf_range(-PI, PI))
		for i in diff_pick([1, 2, 2, 3]):
			_plain_bullet_data.velocity = Vector2(0, 100 + i * 100)
			ctx.bullets.shoot_spread(_plain_bullet_data, diff_pick([10, 14, 20, 20]),
				TAU, dir,
				target.global_position, AssetRegistry.sounds["shoot"])
	)
	if ctx.diff.at_least(2):
		for i in 3:
			timeline.at(1.0 + i * 2.4).every(0.1).times(diff_pick([0, 0, 4, 8])).do(func():
				if _heavy_bullet_data == null:
					_heavy_bullet_data = BulletData.new().enemy().blend(true).tex("米弹").color(Color.GOLD)
					_heavy_bullet_data.coroutine_script = GRAVITY_BULLET
				_heavy_bullet_data.velocity = Vector2(0, 175)
				var dir = Vector2.UP.rotated(RNG.randf_range(-PI / 3, PI / 3))
				ctx.bullets.shoot_spread(_heavy_bullet_data, 1, 0, dir,
				target.global_position, AssetRegistry.sounds["kira"])
			)

	# 退场
	timeline.at(8.0).do(func():
		var fly: CoroutineScript = FLY_AWAY.new()
		target.add_child(fly)
		fly.start(ctx, target)
		auto_stop = true
	)
