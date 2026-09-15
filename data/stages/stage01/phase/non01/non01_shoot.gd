extends CoroutineScript
## 非符1 弹幕：开花弹连射 —— 每隔 _burst_interval 秒来一波，
## 波内每 _shot_interval 秒开一朵花（一圈弹幕），共 _burst_count 朵
## 每朵花碰到游戏框只反弹一次，反弹附加角每圈递增 _bounce_step（下一圈加一点）
## 弹速带加速度（沿飞行方向加速）；弹数/速度随难度递增；RNG 可复现
## auto_stop = false（持续运行直到 phase 结束）

var _burst_interval: float = 2.4   # 波间隔（秒）：多久来一波
var _burst_count: Array = [3, 6, 9, 12]          # 每波开花次数（n 次）
var _shot_interval: float = 0.01    # 开花间隔（秒）：波内两次开花之间
var _bounce_step: Array = [0.1, 0.1, 0.075, 0.075]       # 反弹附加角递增步长（弧度/圈）：第 k 圈 = k × _bounce_step
var _bullet_accel: float = 100.0    # 弹速加速度（px/s²），沿飞行方向逐渐加速（0 = 匀速）

var _burst_t: float = 2.0    # 距下一波（仅在无波进行时累加）
var _shot_t: float = 0.0     # 波内距下次开花
var _shots_left: int = 0     # 波内剩余开花次数
var _rotate: float = 0.0     # 波内累积旋转（连续开花错开角度）
var _ring_index: int = 0     # 本波已发圈数 → 本圈附加角 = _bounce_step × (圈序 − 波数/2) × _wave_sign
var _wave_sign: int = 1  # 本波正负号（_fire_burst 开头翻转并定死，整波统一）
var _base_dir: Vector2

## 复用弹型实例（M2）
var _bullet_data: BulletData
## 反弹替换弹（米弹/GOLD）：**共享实例**（static）→ 同结构 program 跨实例共用
static var _bounce_spawn_bullet_data: BulletData


func _tick(p_ctx: StageContext):
	if not target:
		return p_ctx.clock.wait(_burst_interval)

	var dt := get_dt()

	if _shots_left > 0:
		# 波内：按短间隔连续开花
		_shot_t += dt
		if _shot_t >= _shot_interval:
			_shot_t = 0.0
			_shots_left -= 1
			_fire_ring(p_ctx)
	else:
		# 无波进行：等下一波
		_burst_t += dt
		if _burst_t >= _burst_interval:
			_fire_burst(p_ctx)

	return true


## 开一波：第一朵立即开，剩余按间隔补
func _fire_burst(p_ctx: StageContext) -> void:
	_wave_sign = -_wave_sign  # 波次正负交替：波开始时定死，整波统一（发射时即注入角度 → 之后碰框不受下一波影响）
	_burst_t = 0.0
	_shot_t = 0.0
	_shots_left = diff_pick(_burst_count) - 1
	_rotate = 0.0
	_ring_index = 0  # 每波从 0 圈重新递增
	_base_dir = Vector2.DOWN.rotated(RNG.randf() * TAU + _rotate)
	p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"], -8.0)  # 一波只响一次
	_fire_ring(p_ctx)


## 开花：一圈反弹弹，整圈共用一个反弹附加角（发射时定好）。
## 本圈附加角 = _bounce_step × _ring_index × _wave_sign → 圈序递增 + 按波次正负交替
func _fire_ring(p_ctx: StageContext) -> void:
	var count: int = diff_pick([15, 20, 25, 30])
	var speed: float = 25.0 + _ring_index * 25
	var bounce_angle: float = diff_pick(_bounce_step) * (_ring_index - diff_pick(_burst_count) / 2) * _wave_sign
	_ring_index += 1

	if _bullet_data == null:
		_bullet_data = BulletData.new().tex("棱弹").color(Color.AQUA).blend(true).enemy()
	if _bounce_spawn_bullet_data == null:
		_bounce_spawn_bullet_data = BulletData.new().tex("米弹").color(Color.GOLD).blend(true).enemy()
	_bullet_data.speed(speed)  # 速度随圈递增：每圈写一次（速度不属弹型）
	# 弹道每圈一份（accel / bounce_angle 随圈变）；替换弹是共享实例 → 同结构共用 program
	_bullet_data.trajectory(BulletLifecycle.bounce(
		_bullet_accel - _ring_index * 3, bounce_angle, 0.0, _bounce_spawn_bullet_data))

	p_ctx.bullets.shoot_spread(_bullet_data, count, TAU, _base_dir, target.global_position)
