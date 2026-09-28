extends CoroutineScript
## 卡摩瑞二符

var 波间隔: float = diff_pick([3.0, 2.0, 0.0, 0.0])
var 开花弹次数: int = diff_pick([12, 20, 28, 36])
var 开花弹条数: int = diff_pick([8, 12, 16, 20])
var 开花弹速度: float = diff_pick([350.0, 400.0, 450.0, 500.0])
var 波内两次开花间隔: float = diff_pick([0.25, 0.2, 0.15, 0.1])

var 距下一波计时: float = 2.4
var 波内距下次开花计时: float = 0.0
var 波内剩余开花弹次数: int = 0
var 随机角度: Vector2

var 开花弹: BulletData
var 反射弹: BulletData
var 开花弹2: BulletData
var 反射弹2: BulletData

func _on_start() -> void:
	var lifecycle: BulletLifecycle
	
	
	反射弹 = BulletData.new().tex("鳞弹").color(Color.RED).blend(true).enemy()
	lifecycle = BulletLifecycle.new()
	lifecycle.accel_heading(100)
	反射弹.trajectory(lifecycle)
	if SaveData.selected_difficulty >= 2:
		反射弹2 = BulletData.new().tex("鳞弹").color(Color.GOLD).blend(true).enemy()
		反射弹2.trajectory(lifecycle)
	
	开花弹 = BulletData.new().tex("鳞弹").blend(true).enemy().speed(开花弹速度) \
					  .color(Color.CORNFLOWER_BLUE)
	lifecycle = BulletLifecycle.new()
	lifecycle.until_at_wall(BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP)
	lifecycle.sfx(&"kira")
	lifecycle.emit(反射弹, BulletLifecycle.reflect(), 0.01, BulletLifecycle.AT_PHASE_END)
	lifecycle.despawn()
	开花弹.trajectory(lifecycle)
	if SaveData.selected_difficulty >= 2:
		开花弹2 = BulletData.new().tex("鳞弹").blend(true).enemy().speed(开花弹速度) \
						   .color(Color.GOLDENROD)
		lifecycle = BulletLifecycle.new()
		lifecycle.until_at_wall(BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP)
		lifecycle.sfx(&"kira")
		lifecycle.emit(反射弹2, BulletLifecycle.reflect(), 0.01, BulletLifecycle.AT_PHASE_END)
		lifecycle.despawn()
		开花弹2.trajectory(lifecycle)

func _tick(p_ctx: StageContext) -> Variant:
	if not target:
		return p_ctx.clock.wait(波间隔)
	
	if SaveData.selected_difficulty >= 2:
		随机角度 = Vector2.DOWN.rotated(RNG.randf() * TAU)
		p_ctx.bullets.shoot_spread(开花弹, 开花弹条数, TAU, Vector2.RIGHT.rotated(TAU/开花弹条数/2),
								   target.global_position,
								   AssetRegistry.sounds["shoot"])
		p_ctx.bullets.shoot_spread(开花弹2, 3, TAU, 随机角度, target.global_position)
		return p_ctx.clock.wait(波内两次开花间隔)
	else:
		var dt := get_dt()
		
		if 波内剩余开花弹次数 > 0:
			波内距下次开花计时 += dt
			if 波内距下次开花计时 >= 波内两次开花间隔:
				波内距下次开花计时 = 0.0
				波内剩余开花弹次数 -= 1
				p_ctx.bullets.shoot_spread(开花弹, 开花弹条数, TAU, 随机角度, target.global_position,
										   AssetRegistry.sounds["shoot"])
		else:
			距下一波计时 += dt
			if 距下一波计时 >= 波间隔:
				距下一波计时 = 0.0
				波内距下次开花计时 = 0.0
				波内剩余开花弹次数 = 开花弹次数
				随机角度 = Vector2.DOWN.rotated(RNG.randf() * TAU)
		return true
