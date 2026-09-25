extends CoroutineScript
## 卡摩瑞一符

var 发射间隔: float = diff_pick([2.0, 1.75, 1.5, 1.25])
var 个数: int = diff_pick([25, 35, 45, 50])

## 复用实例（弹型缓存在实例上；禁止每发 new）
var 种子弹: BulletData
var 开花弹: BulletData
var 反射弹: BulletData


func _on_start() -> void:
	var lifecycle: BulletLifecycle
	
	
	反射弹 = BulletData.new().tex("鳞弹").color(Color.CORNFLOWER_BLUE).blend(true).enemy()
	lifecycle = BulletLifecycle.new()
	if SaveData.selected_difficulty >= 2:
		lifecycle.accel_world(Vector2(0, diff_pick([0, 0, 25, 35])))
	反射弹.trajectory(lifecycle)


	var 开花弹沿速度方向的加速度: float = 200.0
	开花弹 = BulletData.new().tex("鳞弹").color(Color.RED).blend(true).enemy()
	lifecycle = BulletLifecycle.new()
	lifecycle.accel_heading(开花弹沿速度方向的加速度)
	lifecycle.until_at_wall(BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP)
	lifecycle.sfx(&"kira")
	lifecycle.emit(反射弹, BulletLifecycle.toward(BulletLifecycle.T_BOSS), 150, BulletLifecycle.AT_PHASE_END)
	lifecycle.despawn()
	开花弹.trajectory(lifecycle)
	
	
	var 种子弹速度: float = 260.0
	var 开花弹速度: float = diff_pick([50.0, 35.0, 20.0, 5.0])
	var 种子弹飞行距离: float = 160.0
	var 种子弹飞行时间: float = 2 * 种子弹飞行距离 / 种子弹速度
	种子弹 = BulletData.new().tex("中玉").speed(种子弹速度).color(Color.RED).blend(true).enemy()
	lifecycle = BulletLifecycle.new()
	lifecycle.speed_lerp(种子弹速度, 0.0, 种子弹飞行时间)
	lifecycle.until_elapsed(种子弹飞行时间)
	lifecycle.sfx(&"shoot")
	for i in 个数:
		lifecycle.emit(开花弹, BulletLifecycle.forward(TAU * i / 个数), 开花弹速度)
	lifecycle.despawn()
	种子弹.trajectory(lifecycle)


func _tick(p_ctx: StageContext) -> Variant:
	if not target:
		return p_ctx.clock.wait(发射间隔)
	
	p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"])
	if SaveData.selected_difficulty >= 2:
		var 随机角度 := Vector2.DOWN.rotated(RNG.randf() * TAU)
		p_ctx.bullets.shoot_spread(开花弹, 个数, TAU, 随机角度, target.global_position)
	else:
		var 随机角度 := Vector2.DOWN.rotated(deg_to_rad(RNG.randf_range(-30, 30)))
		p_ctx.bullets.shoot_spread(种子弹, 1, 0.0, 随机角度, target.global_position)
	
	return p_ctx.clock.wait(发射间隔)
