extends CoroutineScript
## 旋转发射器（发弹点轨迹实验 v5）
## 难度模式：
##   E/N：三段式循环（外扩 → 外圈保持 → 回卷随机起始角重开）
##   H/L：全程保持在外圈转（永不外扩/回卷），hold 加成与 15% 自机狙持续生效
## 弹幕：每发 probe_count 颗铺满 360°，挂往返探测弹行为（飞出→回点→分裂）
## auto_stop = false

const PROBE := preload("res://data/stages/stage03B/phase/spell03/orbit_probe.gd")

var orbit_speed: float = 12      # 初始角速度（弧度/秒，1.5 ≈ 每秒 86°）
var angle_accel: Array = [0.0, 0.0, 2.0, 4.0]    # 角加速度（弧度/秒²，正=加速、负=减速）
var radius_min: float = 0.0     # 起始半径（离 Boss 最近）
var radius_max: Array = [250.0, 300.0, 625.0, 600.0]   # 外扩上限
var radius_growth: float = 120.0 # 外扩初始速度（每秒，半径每秒外扩量）
var radius_accel: float = 15.0   # 外扩加速度（每秒²，正=越扩越快，负=越扩越慢）
var hold_time: float = 7.5      # 到达外圈后保持旋转的秒数（画外环）
var interval: Array = [0.07, 0.07, 0.06, 0.06]      # 发弹间隔（秒）
var bullet_speed: float = 175.0 # 青弹初速（往返探测弹起飞速度）
var probe_count: Array = [2, 4, 6, 10]  # 每发颗数
var min_fire_distance: float = 125.0  # 发弹点离自机低于此距离时不发（防近身糊脸；0 = 关闭）

var _angle: float = 0.0
var _angle_speed: float = -1.0  # 当前角速度（-1 哨兵：首帧取 orbit_speed）
var _radius: float = 60.0
var _growth: float = -1.0  # 当前外扩速度（-1 哨兵：首次取 radius_growth）
var _hold_left: float = 0.0  # 剩余保持时间（>0 = 外圈空转阶段）
var _inited: bool = false    # 难度模式初始化（首帧按当前难度决定）
var _always_hold: bool = false  # H/L：全程外圈转（永续 hold）


func _tick(p_ctx: StageContext):
	if not target:
		return p_ctx.clock.wait(diff_pick(interval))
	var dt := get_dt()
	var itv: float = diff_pick(interval)
	var hard: bool = p_ctx.diff.at_least(2)
	var rmax: float = diff_pick(radius_max)

	# ── 首帧初始化（哨兵统一在此，不再每帧判断）──
	if not _inited:
		_inited = true
		_angle_speed = orbit_speed
		_growth = radius_growth
		_always_hold = hard
		if _always_hold:
			_radius = rmax
			_hold_left = INF  # H/L：永续 hold（外扩分支永不进入）
			_angle = RNG.randf() * TAU  # H/L 开局随机起始角

	# ── 轨迹：角速度（可加速）──
	_angle_speed += diff_pick(angle_accel) * dt
	_angle += _angle_speed * dt

	if _hold_left > 0.0:
		# hold：外圈转（画外环）
		if not _always_hold:
			_hold_left -= dt
			if _hold_left <= 0.0:
				_radius = radius_min  # 回卷
				_growth = radius_growth  # 恢复初始外扩速度
				_angle = RNG.randf() * TAU  # 新一轮随机起始角
	else:
		# 外扩（E/N）：半径渐远（可加速）
		_growth += radius_accel * dt
		_radius += _growth * dt
		if _radius >= rmax:
			_radius = rmax
			_hold_left = hold_time

	# 发弹点 = Boss 中心 + 半径方向 × 当前半径（跟随 Boss 移动）
	var emit_pos := target.global_position \
		+ Vector2(cos(_angle), sin(_angle)) * _radius

	# 防近身：发弹点离自机太近 → 跳过这一发（等下一个 interval 再判）
	var p := p_ctx.player.get_player()
	if min_fire_distance > 0.0 and p and emit_pos.distance_to(p.global_position) < min_fire_distance:
		return p_ctx.clock.wait(itv)

	# ── 子弹定义（往返探测弹行为）──
	var bullet := BulletData.new() \
		.tex("环玉") \
		.speed(bullet_speed) \
		.color(Color.BLUE_VIOLET) \
		.blend(true) \
		.enemy() \
		.behavior(PROBE) \
		.grace(4)
	# hold 阶段（含 H/L 全程）发射的探测弹：注入标记 → 分裂时 15% 可转自机狙
	bullet.params["hold_aim_probe"] = _hold_left > 0.0 and hard

	# ── 主发射：probe_count 颗铺满圆（按难度取）；hold 阶段 + hold_count_bonus ──
	var count: int = diff_pick(probe_count)
	# 基准方向：E/N 指向 Boss；H/L 切向（发弹点前进方向）
	var dir: Vector2 = Vector2(-sin(_angle), cos(_angle)) if hard \
		else Vector2(-cos(_angle), -sin(_angle))
	if count > 0:
		p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"], -8.0)
		var step := TAU / count
		for i in count:
			p_ctx.bullets.shoot_spread(bullet, 1, 0.0, dir.rotated(step * i), emit_pos)

	return p_ctx.clock.wait(itv)
