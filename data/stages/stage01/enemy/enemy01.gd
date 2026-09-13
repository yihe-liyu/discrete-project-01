extends CoroutineScript
## 红杂鱼: 向下减速 + 自机狙 + 散射

const GRAVITY_BULLET = preload("res://data/stages/stage01/bullet/gravity_bullet.gd")
const FLY_AWAY = preload("res://data/stages/stage01/enemy/fly_away.gd")

var target_y: float = 300
var heavy_wave: bool = true  ## 强化波：Hard+ 时额外发射金色重力弹
var rate: int = 1

## 复用弹型实例（M2：内核弹型缓存在 BulletData 实例上，禁止每发 new）
var _plain_bullet_data: BulletData
var _heavy_bullet_data: BulletData

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
		.tween_property(parent, "global_position",
			Vector2(parent.global_position.x, target_y), 1.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 弹幕（复用两个弹型实例：普通弹 / 强化弹）
	var timeline := start_timeline()

	timeline.at(0.0).every(2.5).times(3).do(func():
		if _plain_bullet_data == null:
			_plain_bullet_data = BulletData.new().enemy().blend(true).tex("小玉").color(Color.RED).grace(0)
		var player := ctx.player.get_player()
		var dir := Vector2.DOWN
		if is_instance_valid(player):
			dir = (player.global_position - target.position).normalized()
		var bullet_speed: int = 350

		for i in diff_pick([1, 3, 5, 8]) / rate:
			_plain_bullet_data.velocity = Vector2(0, bullet_speed + i * 50)
			ctx.bullets.shoot_spread(_plain_bullet_data, 1, 0, dir,
				target.global_position, AssetRegistry.sounds["shoot"])

		if ctx.diff.at_least(2) and heavy_wave:
			if _heavy_bullet_data == null:
				_heavy_bullet_data = BulletData.new().enemy().blend(true).tex("棱弹").color(Color.GOLD).grace(3)
				_heavy_bullet_data.coroutine_script = GRAVITY_BULLET
			for i in diff_pick([0, 0, 1, 2]):
				_heavy_bullet_data.velocity = Vector2(0, 175 + i * 25)
				ctx.bullets.shoot_spread(_heavy_bullet_data, diff_pick([0, 0, 3, 6]), PI / (3 - i), -dir,
					target.global_position)
	)

	# 射完后加速飘走退场
	timeline.at(5.0).do(func():
		var fly: CoroutineScript = FLY_AWAY.new()
		target.add_child(fly)
		fly.start(ctx, target)
		auto_stop = true
	)
