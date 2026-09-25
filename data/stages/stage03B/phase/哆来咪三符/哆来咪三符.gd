extends CoroutineScript
## 哆来咪三符

var 往返弹加速度: float = 150.0
var 夹角弹初速度: float = 60.0
var 夹角弹加速度: float = 40.0
var 变自机狙概率: float = 0.075

var 难度高于Hard: bool = SaveData.selected_difficulty >= 2

var 发弹点角速度: float = 12	# （弧度/秒，1.5 ≈ 每秒 86°）
var 发弹点角加速度: float = diff_pick([0.0, 0.0, 4.0, 8.0])	# （弧度/秒²，正=加速、负=减速）
var 发弹点起始半径: float = 0.0
var 发弹点半径上限: float = diff_pick([250.0, 300.0, 625.0, 625.0])
var 发弹安全距离: float = 125.0
var 发弹点半径增加速度: float = 120.0
var 发弹点半径增加加速度: float = 15.0
var 保持旋转时间: float = 7.5
var 发弹间隔: float = diff_pick([0.07, 0.07, 0.06, 0.06])
var 个数: int = diff_pick([2, 4, 6, 10])
var 往返弹初速度: float = 175.0

var 发弹点当前角度: float = 0.0
var 发弹点当前角速度: float = -1.0
var 发弹点当前半径: float = 60.0
var 发弹点当前半径增加速度: float = -1.0
var 剩余保持时间: float = 0.0

var 往返弹: BulletData
var 夹角弹: BulletData
var 夹角狙: BulletData

func _on_start() -> void:
	发弹点当前角速度 = 发弹点角速度
	发弹点当前半径增加速度 = 发弹点半径增加速度
	if 难度高于Hard:
		发弹点当前半径 = 发弹点半径上限
		剩余保持时间 = INF
		发弹点当前角度 = RNG.randf() * TAU
	
	var lifecycle: BulletLifecycle
	
	夹角弹 = BulletData.new().tex("环玉").blend(true).enemy() \
					  .grace(4) \
					  .color(Color.AQUA)
	lifecycle = BulletLifecycle.new()
	lifecycle.accel_heading(夹角弹加速度)
	if 难度高于Hard:
		lifecycle.until_elapsed(diff_pick([0, 0, 3, 3]))
		lifecycle.despawn_clear()
	夹角弹.trajectory(lifecycle)
	
	夹角狙 = BulletData.new().tex("环玉").blend(true).enemy() \
					  .grace(4) \
					  .color(Color.RED)
	lifecycle = BulletLifecycle.new()
	lifecycle.accel_heading(夹角弹加速度)
	if 难度高于Hard:
		lifecycle.until_elapsed(diff_pick([0, 0, 5, 6]))
		lifecycle.despawn_clear()
	夹角狙.trajectory(lifecycle)
	
	往返弹 = BulletData.new().tex("环玉").speed(往返弹初速度) \
			.color(Color.BLUE_VIOLET).blend(true).enemy() \
			.grace(4)
	lifecycle = BulletLifecycle.new()
	lifecycle.accel_heading(-往返弹加速度)
	lifecycle.until_elapsed(2.0 * 往返弹初速度 / 往返弹加速度)
	lifecycle.sfx(&"kira")
	lifecycle.emit_variant([夹角弹, 夹角狙],
						   BulletLifecycle.chance_toward(BulletLifecycle.T_PLAYER, 变自机狙概率 if 难度高于Hard else 0.0, TAU / 个数 / 2),
						   夹角弹初速度)
	lifecycle.despawn()
	往返弹.trajectory(lifecycle)

func _tick(p_ctx: StageContext):
	if not target:
		return p_ctx.clock.wait(发弹间隔)
	var dt := get_dt()

	发弹点当前角速度 += 发弹点角加速度 * dt
	发弹点当前角度 += 发弹点当前角速度 * dt

	if 剩余保持时间 > 0.0:
		if not 难度高于Hard:
			剩余保持时间 -= dt
			if 剩余保持时间 <= 0.0:
				发弹点当前半径 = 发弹点起始半径
				发弹点当前半径增加速度 = 发弹点半径增加速度
				发弹点当前角度 = RNG.randf() * TAU
	else:
		发弹点当前半径增加速度 += 发弹点半径增加加速度 * dt
		发弹点当前半径 += 发弹点当前半径增加速度 * dt
		if 发弹点当前半径 >= 发弹点半径上限:
			发弹点当前半径 = 发弹点半径上限
			剩余保持时间 = 保持旋转时间

	# 发弹点 = Boss 中心 + 半径方向 × 当前半径（跟随 Boss 移动）
	var 发弹点坐标: Vector2 = target.global_position \
		+ Vector2(cos(发弹点当前角度), sin(发弹点当前角度)) * 发弹点当前半径

	# 防近身
	var player := p_ctx.player.get_player()
	if player and 发弹点坐标.distance_to(player.global_position) < 发弹安全距离:
		return p_ctx.clock.wait(发弹间隔)

	# ── 主发射：probe_count 颗铺满圆（按难度取）；hold 阶段 + hold_count_bonus ──
	# 基准方向：E/N 指向 Boss；H/L 切向（发弹点前进方向）
	var 往返弹方向: Vector2
	if 难度高于Hard:
		往返弹方向 = Vector2(-sin(发弹点当前角度), cos(发弹点当前角度))
	else: 
		往返弹方向 = Vector2(-cos(发弹点当前角度), -sin(发弹点当前角度))
	p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"])
	var 夹角弹角度间隔 := TAU / 个数
	for i in 个数:
		p_ctx.bullets.shoot_spread(往返弹, 1, 0.0, 往返弹方向.rotated(夹角弹角度间隔 * i), 发弹点坐标)

	return p_ctx.clock.wait(发弹间隔)
