extends CoroutineScript
## 卡摩瑞二非

var 波间隔: float = 3.0
var 开花弹次数: int = diff_pick([6, 10, 14, 18])
var 波内两次开花间隔: float = 0.01

var 距下一波计时: float = 2.4
var 波内距下次开花计时: float = 0.0
var 波内剩余开花弹次数: int = 0
var 本波已发圈数: int = 0
var 波次正负交替: int = 1
var 随机角度: Vector2

var 开花弹: BulletData
var 反弹弹: BulletData

func _on_start() -> void:
	开花弹 = BulletData.new().tex("米弹").color(Color.GOLD).blend(true).enemy()
	反弹弹 = BulletData.new().tex("棱弹").color(Color.AQUA).blend(true).enemy()

func _tick(p_ctx: StageContext):
	if not target:
		return p_ctx.clock.wait(波间隔)
	
	var dt := get_dt()
	
	if 波内剩余开花弹次数 > 0:
		波内距下次开花计时 += dt
		if 波内距下次开花计时 >= 波内两次开花间隔:
			波内距下次开花计时 = 0.0
			波内剩余开花弹次数 -= 1
			开花(p_ctx)
	else:
		# 无波进行：等下一波
		距下一波计时 += dt
		if 距下一波计时 >= 波间隔:
			波次正负交替 = -波次正负交替
			距下一波计时 = 0.0
			波内距下次开花计时 = 0.0
			波内剩余开花弹次数 = 开花弹次数
			本波已发圈数 = 0
			随机角度 = Vector2.DOWN.rotated(RNG.randf() * TAU)
			p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"])
	
	return true

func 开花(p_ctx: StageContext) -> void:
	var 个数: int = diff_pick([10, 15, 20, 25])
	var 速度: float = 5.0 + 本波已发圈数 * diff_pick([35, 30, 25, 20])
	本波已发圈数 += 1
	
	var lifecycle := BulletLifecycle.new()
	lifecycle.accel_heading(100 - 本波已发圈数 * 4)
	lifecycle.until_at_wall(BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP)
	lifecycle.sfx(&"kira")
	lifecycle.emit(反弹弹, BulletLifecycle.toward(BulletLifecycle.T_BOSS, 波次正负交替*本波已发圈数*(TAU/开花弹次数)), 150, BulletLifecycle.AT_PHASE_END)
	
	开花弹.speed(速度)
	开花弹.trajectory(lifecycle)
	
	p_ctx.bullets.shoot_spread(开花弹, 个数, TAU, 随机角度, target.global_position)
