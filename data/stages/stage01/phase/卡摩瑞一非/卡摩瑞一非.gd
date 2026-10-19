extends AsyncCoroutineScript
## 卡摩瑞一非

## Pattern spike：true = 走 ring pattern；false = 旧 shoot_spread 路径（对比手感用，确认后删）。
const USE_RING := true
const RING := preload("res://data/patterns/ring.gd")
const RING_PARAMS := preload("res://scripts/patterns/pattern_params.gd")

var 波间隔: float = 2.4
var 开花弹次数: Array = [3, 5, 7, 9]
var 波内两次开花间隔: float = 0.01
var 反弹附加角递增: Array = [0.1, 0.1, 0.075, 0.075]

var 本波已发圈数: int = 0
var 波次正负交替: int = 1
var 随机角度: Vector2

var 开花弹: BulletData
var 反弹弹: BulletData
var _bullet_pattern: BulletPattern
var _pattern_params: PatternParams


func _on_start() -> void:
	开花弹 = BulletData.new().tex("棱弹").color(Color.AQUA).blend(true).enemy()
	反弹弹 = BulletData.new().tex("米弹").color(Color.GOLD).blend(true).enemy()
	_bullet_pattern = RING.new()
	_pattern_params = RING_PARAMS.new()


func run_async(p_ctx: StageContext) -> void:
	while p_ctx.active():
		if not await p_ctx.clock.delay(波间隔):
			return
		if not target:
			continue

		波次正负交替 = -波次正负交替
		本波已发圈数 = 0
		随机角度 = Vector2.DOWN.rotated(RNG.randf() * TAU)
		p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"])

		var 本波开花次数: int = diff_pick(开花弹次数)
		for _i in 本波开花次数:
			开花(p_ctx)
			if not await p_ctx.clock.delay(波内两次开花间隔):
				return


func 开花(p_ctx: StageContext) -> void:
	var 个数: int = diff_pick([15, 20, 25, 30])
	var 速度: float = 5.0 + 本波已发圈数 * diff_pick([55, 50, 45, 40])
	var 单圈反弹附加角: float = diff_pick(反弹附加角递增) * (本波已发圈数 - diff_pick(开花弹次数) / 2.0) * 波次正负交替
	本波已发圈数 += 1

	var lifecycle := BulletLifecycle.new()
	lifecycle.accel_heading(100 - 本波已发圈数 * 4)
	lifecycle.until_at_wall(BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP)
	lifecycle.sfx(&"kira")
	lifecycle.emit(反弹弹, BulletLifecycle.toward(BulletLifecycle.T_BOSS, 单圈反弹附加角), 0, BulletLifecycle.AT_PHASE_END)
	lifecycle.despawn()

	开花弹.speed(速度)
	开花弹.trajectory(lifecycle)

	if USE_RING:
		# 模板路径：保留 lifecycle / 颜色 / 阵营，只改本次的速度与数量。
		_pattern_params.template = 开花弹
		_pattern_params.count = 个数
		_pattern_params.speed = 速度
		_bullet_pattern.fire(p_ctx, _pattern_params, target.global_position, 随机角度)
	else:
		p_ctx.bullets.shoot_spread(开花弹, 个数, TAU, 随机角度, target.global_position)
