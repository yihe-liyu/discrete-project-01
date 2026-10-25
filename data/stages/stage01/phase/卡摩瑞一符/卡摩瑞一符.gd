extends CoroutineScript
## 卡摩瑞一符「音符「定点扩散」」
##
## 三颗弹的分工：
## - 开花弹：红鳞弹，沿当前朝向加速，撞到左/右/上墙后向 Boss 反射一颗，再消失。
## - 反射弹：蓝鳞弹，Hard 以上额外受向下重力；由开花弹撞墙时生成。
## - 种子弹：中玉，飞行途中减速到 0，并在减速过程中向四周吐出开花弹。
##
## 难度分派：Hard 以上直接撒一圈开花弹；Easy / Normal 只发一颗种子弹，
## 让开花弹沿着种子弹的飞行路径自然展开。

## 两次发射的间隔（秒）。
var 发射间隔: float = diff_pick([2.0, 1.75, 1.5, 1.25])
## 临时演出试验：每次发射前画一颗代表弹的路径；多线稳定后再正式化。
const 显示未来路径 := true
## Hard 以上一圈开花弹的数量。
var 个数: int = diff_pick([25, 35, 45, 50])
## 开花弹沿当前朝向的加速度（像素/秒²）。
const 开花弹加速度: float = 200.0
## 开花弹撞墙后生成的反射弹速度。
const 反射弹速度: float = 150.0
## 种子弹初速度与总飞行距离；飞行时间由这两项算出。
const 种子弹速度: float = 260.0
const 种子弹飞行距离: float = 160.0

## 复用弹型实例：弹型缓存在 BulletData 上，禁止每发 new。
var 种子弹: BulletData
var 开花弹: BulletData
var 反射弹: BulletData


func _on_start() -> void:
	var lifecycle: BulletLifecycle

	# 反射弹：由开花弹撞墙时生成；Hard 以上带一点下坠。
	反射弹 = BulletData.new().tex("鳞弹").color(Color.CORNFLOWER_BLUE).blend(true).enemy()
	lifecycle = BulletLifecycle.new()
	if SaveData.selected_difficulty >= Difficulty.HARD:
		var 反射弹重力: float = diff_pick([0.0, 0.0, 25.0, 35.0])
		lifecycle.accel_world(Vector2(0.0, 反射弹重力))
	反射弹.trajectory(lifecycle)

	# 开花弹：沿发射方向加速，撞到左/右/上墙后向 Boss 反射一颗，再消失。
	# 不写底墙：弹从 Boss 位置向下发射，底部靠出界清理。
	开花弹 = BulletData.new().tex("鳞弹").color(Color.RED).blend(true).enemy()
	lifecycle = BulletLifecycle.new()
	lifecycle.accel_heading(开花弹加速度)
	lifecycle.until_at_wall(BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP)
	lifecycle.sfx(&"kira")
	lifecycle.emit(反射弹, BulletLifecycle.toward(BulletLifecycle.T_BOSS), 反射弹速度, BulletLifecycle.AT_PHASE_END)
	lifecycle.despawn()
	开花弹.trajectory(lifecycle)

	# 种子弹：速度线性降到 0；飞行时间 = 2 × 距离 / 初速度。
	# 减速期间按等角度向四周生成开花弹，形成“先聚后散”的观感。
	var 开花弹速度: float = diff_pick([50.0, 35.0, 20.0, 5.0])
	var 种子弹飞行时间: float = 2.0 * 种子弹飞行距离 / 种子弹速度
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
	if SaveData.selected_difficulty >= Difficulty.HARD:
		# Hard 以上：一圈开花弹；整圈随机旋转，避免每次都从同一角度开始。
		var 随机角度 := Vector2.DOWN.rotated(RNG.randf() * TAU)
		# 路径预测试验：绑定整圈真实弹；每颗 uid 稳定，死一颗掉一条。
		var ids: Array[int] = p_ctx.bullets.shoot_spread_ids(
			开花弹, 个数, TAU, 随机角度, target.global_position)
		if 显示未来路径 and not ids.is_empty():
			p_ctx.telegraph.add_tracked_bullets(ids, 开花弹.lifecycle)
	else:
		# Easy / Normal：只发一颗种子弹，落点略随机；开花弹由种子弹自己生成。
		var 随机角度 := Vector2.DOWN.rotated(deg_to_rad(RNG.randf_range(-30.0, 30.0)))
		var ids: Array[int] = p_ctx.bullets.shoot_spread_ids(
			种子弹, 1, 0.0, 随机角度, target.global_position)
		if 显示未来路径 and not ids.is_empty():
			p_ctx.telegraph.add_tracked_bullets([ids[0]], 种子弹.lifecycle)

	return p_ctx.clock.wait(发射间隔)
